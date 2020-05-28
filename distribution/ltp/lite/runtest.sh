#!/bin/bash

. ../../../cki_lib/libcki.sh || exit 1
. ../include/runtest.sh      || exit 1
. ../include/knownissue.sh   || exit 1

#export AVC_ERROR=+no_avc_check
#export RHTS_OPTION_STRONGER_AVC=

core_pattern="$(cat /proc/sys/kernel/core_pattern)"
core_pattern_ltp_dir="/mnt/testarea/ltp/cores"

# prepare_aiodio_scratchspace
# exports:
#   SCRATCH_MNT
#   BIG_FILE
#   BUF_ALIGN
function prepare_aiodio_scratchspace()
{
	export SCRATCH_MNT=/mnt/scratchspace
	echo "Preparing scratchspace at: $SCRATCH_MNT" | tee -a $OUTPUTFILE
	if [ ! -e $SCRATCH_MNT ]; then
		echo "Creating $SCRATCH_MNT"           | tee -a $OUTPUTFILE
		mkdir $SCRATCH_MNT
	fi

	mkdir -p $SCRATCH_MNT/aiodio/junkdir
	export BIG_FILE="$SCRATCH_MNT/bigfile"

	block_size=0
	mntpoint=`df "$SCRATCH_MNT" | tail -n +2 | head -1`
	if [ -n "$mntpoint" ]; then
		block_size=`blockdev --getbsz $mntpoint`
		echo "$SCRATCH_MNT's mount point is: $mntpoint" | tee -a $OUTPUTFILE
		echo "$mntpoint's block size is: $block_size"   | tee -a $OUTPUTFILE
	fi
	if [ "$block_size" -ge 512 ]; then
		export BUF_ALIGN=$block_size
	else
		export BUF_ALIGN=4096
	fi

	echo "SCRATCH_MNT: $SCRATCH_MNT" | tee -a $OUTPUTFILE
	echo "BIG_FILE:    $BIG_FILE"    | tee -a $OUTPUTFILE
	echo "BUF_ALIGN:   $BUF_ALIGN"   | tee -a $OUTPUTFILE
}

function clean_aiodio_scratchspace()
{
	rm -rf $SCRATCH_MNT/aiodio
}

function tolerate_s390_high_steal_time()
{
	local runtest=$1

	uname -m | grep -q s390
	if [ $? -ne 0 ]; then
		return
	fi

	sed -i 's/nanosleep01 nanosleep01/nanosleep01 timeout 300 sh -c "nanosleep01 || true"/' "$runtest"
	sed -i 's/clock_nanosleep01 clock_nanosleep01/clock_nanosleep01 timeout 300 sh -c "clock_nanosleep01 || true"/' "$runtest"
	sed -i 's/clock_nanosleep02 clock_nanosleep02/clock_nanosleep02 timeout 300 sh -c "clock_nanosleep02 || true"/' "$runtest"
	sed -i 's/futex_wait_bitset01 futex_wait_bitset01/futex_wait_bitset01 timeout 30 sh -c "futex_wait_bitset01 || true"/' "$runtest"
	sed -i 's/futex_wait05 futex_wait05/futex_wait05 timeout 30 sh -c "futex_wait05 || true"/' "$runtest"
	sed -i 's/epoll_pwait01 epoll_pwait01/epoll_pwait01 timeout 30 sh -c "epoll_pwait01 || true"/' "$runtest"
	sed -i 's/poll02 poll02/poll02 timeout 30 sh -c "poll02 || true"/' "$runtest"
	sed -i 's/pselect01 pselect01/pselect01 timeout 30 sh -c "pselect01 || true"/' "$runtest"
	sed -i 's/pselect01_64 pselect01_64/pselect01_64 timeout 30 sh -c "pselect01_64 || true"/' "$runtest"
	sed -i 's/select04 select04/select04 timeout 30 sh -c "select04 || true"/' "$runtest"
}

function exclude_disruptive_for_kt1()
{
	local runtest=$1

	if is_rhel7; then
		if [ "$osver" -le 705 ]; then
			# Bug 1261799 - ltp/oom1 cause the system hang
			sed -i 's/oom01 oom01/#DISABLED oom01 oom01/' "$runtest"
			sed -i 's/oom02 oom02/#DISABLED oom02 oom02/' "$runtest"

			# Bug 1223391 OOM sporadically triggers when process tries to malloc and dirty 80% of RAM+swap
			sed -i 's/mtest01w mtest01 -p80 -w/mtest01w sh -c "mtest01 -p80 -w || true"/' "$runtest"
		fi
	fi
}

function runtest_prepare()
{
	t="RHELKT1LITE.FILTERED"
	cp -f RHELKT1LITE "$t"

	case $SKIP_LEVEL in
	   "0")
		knownissue_exclude  "none"  "$t"
		;;
	   "1")
		knownissue_exclude  "fatal" "$t"
		;;
	     *)
		# skip all the issues by default
		knownissue_exclude  "all"   "$t"
		;;
	esac

	tolerate_s390_high_steal_time "$t"

	exclude_disruptive_for_kt1 "$t"

	cp -fv "$t" $LTPDIR/runtest/
}

function ltp_lite_begin()
{
	# disable NTP and chronyd
	tservice=""
	pgrep chronyd > /dev/null
	if [ $? -eq 0 ]; then
		tservice="chronyd"
		service chronyd stop
	fi
	DisableNTP

	# make sure there's enough entropy for getrandom tests
	rngd -r /dev/urandom

	prepare_aiodio_scratchspace

	runtest_prepare

	echo "ulimit -c unlimited" | tee -a $OUTPUTFILE
	ulimit -c unlimited
	mkdir -p $core_pattern_ltp_dir
	echo "$core_pattern_ltp_dir/core" > /proc/sys/kernel/core_pattern
	echo 1 > /proc/sys/kernel/core_uses_pid

	echo "numactl --hardware" | tee -a $OUTPUTFILE
	echo "-----" | tee -a $OUTPUTFILE
	numactl --hardware >> ./numactl.txt 2>&1
	cat ./numactl.txt | tee -a $OUTPUTFILE
	echo "-----" | tee -a $OUTPUTFILE

	echo "Using config file: $t" | tee -a $OUTPUTFILE
	ss -antup >> $OUTPUTFILE 2>&1

	cp -f $OUTPUTFILE ./setup.txt
	SubmitLog ./setup.txt
}

ltp_lite_run()
{
	RunFiltTest && return

	rm -f /mnt/testarea/$t.*
	rm -f /mnt/testarea/ltp/output/*
	CleanUp $t

	OUTPUTFILE=`mktemp /tmp/tmp.XXXXXX`
	service cgconfig stop

	RunTest $t
}

ltp_lite_end()
{
	echo "$core_pattern" > /proc/sys/kernel/core_pattern

	clean_aiodio_scratchspace

	# restore either NTP or chronyd
	if [ -n "$tservice" ]; then
		service chronyd start
	else
		EnableNTP
	fi

	./grab_corefiles.sh >> $DEBUGLOG 2>&1
	SubmitLog $DEBUGLOG
}

# ---------- Start Test -------------
if [ "${REBOOTCOUNT}" -ge 1 ]; then
	echo "===== Test has already been run,
	Check logs for possible failures ======"
	rstrnt-report-result CHECKLOGS FAIL 99
	exit 0
fi

# report patch errors from ltp/include
grep -i -e "FAIL" -e "ERROR" patchinc.log > /dev/null 2>&1
if [ $? -eq 0 ]; then
	rstrnt-abort -t recipe
fi

# Sometimes it takes too long to waiting for syscalls
# finish and I want to know whether the compilation is
# finish or not.
rstrnt-report-result "install" "PASS"

ltp_lite_begin

ltp_lite_run

ltp_lite_end

if [ "$result_r" = "PASS" ]; then
       exit 0
else
       exit 1
fi
