#!/bin/bash

# Copyright (c) 2011 Red Hat, Inc. All rights reserved. This copyrighted material 
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Zhouping Liu <zliu@redhat.com> 

. /usr/bin/rhts-environment.sh		|| exit 1
. /usr/share/beakerlib/beakerlib.sh	|| exit 1
. ../include/runtest.sh			|| exit 1
. ../include/knownissue.sh		|| exit 1

TARGET_DIR=/mnt/testarea/ltp
GIT_USER_ADDR=${GIT_USER_ADDR:-0}
RUNTESTS=${RUNTESTS:-"sched syscalls can commands containers dio fs fsx math hugetlb mm nptl pty ipc tracing"}
CPUS_NUM=$(getconf _NPROCESSORS_ONLN || echo 1)

function test_msg()
{
	case $1 in
		pass)
			echo "PASS: $2"
			;;
		warn)
			echo "WARN: $2"
			;;
		fail)
			echo "FAIL: $2"; exit -1
			;;
		log)
			echo "LOG : $2"
			;;
		*)
			echo "EXIT: Wrong parameters"; exit -2
			;;
	esac
}

function ltp_test_build()
{
	# workaround for the beaker issue when arch is ppc64:
	# Makefile:495: /mnt/tests/kernel/distribution/upstream-kernel/install/linux/arch/ppc64/Makefile: No such file or directory
	if [ ${ARCH} = ppc64 -o ${ARCH} = ppc -o ${ARCH} = s390x -o ${ARCH} = s390 ]; then
		unset ARCH
	fi

	if [ -f ltp/.git/config ]; then
		pushd ltp; git pull  > /dev/null 2>&1; popd
	else
		if [ $GIT_USER_ADDR = 0 ]; then
			git clone https://github.com/linux-test-project/ltp ltp \
				> /dev/null 2>&1 || test_msg fail "git clone ltp upstream failed"

			test_msg pass "git clone LTP upstream"
		else
			git clone git://git.engineering.redhat.com/users/${GIT_USER_ADDR} ltp  \
				> /dev/null 2>&1 || test_msg fail "git clone ltp ${GIT_USER_ADDR} failed"

			test_msg pass "git clone LTP ${GIT_USER_ADDR}"
		fi

	fi

	pushd ltp > /dev/null 2>&1
	git checkout baf4ca1653a945bfa2e9db44205502887c85ac40
	make autotools                      &> configlog.txt || if cat configlog.txt; then test_msg fail "config  ltp failed"; fi
	./configure --prefix=${TARGET_DIR}  &> configlog.txt || if cat configlog.txt; then test_msg fail "config  ltp failed"; fi
	make -j$CPUS_NUM                    &> buildlog.txt  || if cat buildlog.txt;  then test_msg fail "build   ltp failed"; fi
	make install                        &> buildlog.txt  || if cat buildlog.txt;  then test_msg fail "install ltp failed"; fi
	# Timing on systems with shared resources (and high steal time) is not accurate, apply patch for non bare-metal machines
	patch -p1 < ../patches/ltp-include-relax-timer-thresholds-for-non-baremetal.patch
	popd > /dev/null 2>&1

	test_msg pass "LTP build/install successful"
}

function knownissue_handle()
{
	case $SKIP_LEVEL in
	   "0")
		knownissue_exclude "none"  $LTPDIR/runtest/*
		;;
	   "2")
		knownissue_exclude "all"   $LTPDIR/runtest/*
		;;
	     *)
		# Skip the fatal cases by default
		knownissue_exclude "fatal" $LTPDIR/runtest/*
		;;
	esac
}

function ltp_test_pre()
{
	# disable NTP and chronyd
	tservice=""
	pgrep chronyd > /dev/null
	if [ $? -eq 0 ]; then
		tservice="chronyd"
		service chronyd stop || test_msg warn "chronyd stop failed"
	fi
	DisableNTP || test_msg warn "Disable NTP failed"

	ulimit -c unlimited && echo "ulimit -c unlimited"

	if [ "$TESTARGS" ]; then
		# We can specify lists of tests to run. If the list file provided,
		# copy/replace it. For example, we can provide a customized list of
		# tests in `RHEL6KT1LITE', Then, we can set TESTARGS="RHEL6KT1LITE"
		for file in $TESTARGS; do
			if [ -f "$file" ]; then
				cp "$file" $TARGET_DIR/runtest/
			else
				test_msg warn "$file not found." | tee -a $OUTPUTFILE
			fi
		done
		RUNTESTS=$TESTARGS
	fi

	# if FSTYP is set, we're testing filesystem, enable fs related requirements
	# to get larger test coverage and test the correct fs.
	# overlayfs is special, no mkfs.overlayfs is available, and tests need LTP_DEV
	# is not designed for overlayfs, so they can be skipped
	if [ -n "$FSTYP" ] && [ "$FSTYP" != "overlayfs" ]; then
		# prepare test device for fs tests and pass it to RunTest()
		LOOP_IMG=ltp-$FSTYP.img
		dd if=/dev/zero of=$LOOP_IMG bs=1M count=1024
		LOOP_DEV=`losetup -f`
		losetup $LOOP_DEV $LOOP_IMG
		export LTP_DEV=$LOOP_DEV
		export LTP_DEV_FS_TYPE=$FSTYP
		export LTP_BIG_DEV=$LOOP_DEV
		export LTP_BIG_DEV_FS_TYPE=$FSTYP
		export OPTS="$OPTS -b $LTP_DEV -B $LTP_DEV_FS_TYPE -z $LTP_BIG_DEV -Z $LTP_BIG_DEV_FS_TYPE"
	fi

	knownissue_handle
}

function ltp_test_run()
{
	for RUNTEST in $RUNTESTS; do
		CleanUp $RUNTEST

		OUTPUTFILE=`mktemp /tmp/tmp.XXXXXX`
		RunTest $RUNTEST "$OPTS"
	done
}

function ltp_test_end()
{
	# restore either NTP or chronyd
	if [ -n "$tservice" ]; then
		service chronyd start || test_msg warn "chronyd start failed"
	else
		EnableNTP || test_msg warn "Enable NTP failed"
	fi

	SubmitLog $DEBUGLOG
}

# ------- Test Start --------
[ -z "${REBOOTCOUNT##*[!0-9]*}" ] && REBOOTCOUNT=0
if [ "${REBOOTCOUNT}" -ge 1 ]; then
    test_msg log "======= Test has already been run, Check logs for possible failures ========="
    report_result CHECKLOGS FAIL 99
    exit 0
fi

rlJournalStart

    rlPhaseStartSetup
	rlRun "ltp_test_build"
    rlPhaseEnd

	ltp_test_pre
	ltp_test_run

    rlPhaseStartCleanup
	rlRun "ltp_test_end"
    rlPhaseEnd

rlJournalEnd
