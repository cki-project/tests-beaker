# /bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of memory kaslr test
#   Description: TestCaseComment
#   Author: Chunyu Hu <chuhu@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2018 Red Hat, Inc.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

trap 'rlFileRestore; exit' SIGHUP SIGINT SIGQUIT SIGTERM

SLUB_RANDOM=${SLUB_RANDOM:-0}

# First  reboot(up) - compare symbol addr with pre-reboot snapshot
# Seond  reboot(up) - nokaslr in kernel cmdline, snapshot symbol addr
# Third  reboot(up) - compare symbol addr with pre-reboot snapshot
# Fourth reboot(up) - remove nokaslr in cmdline

this_arch=$(uname -m)

function get_symbol_addr_snapshot()
{
	case $this_arch in
	x86_64)
		if test -f page_offset_base; then
			for f in $cmp_file_list; do
				mv $f ${f}.old
			done
		fi

		grep -w _text /proc/kallsyms  | awk '{print $1}' > _text
		grep -w page_offset_base /proc/kallsyms  | awk '{print $1}' > page_offset_base
		grep -w vmemmap_base /proc/kallsyms  | awk '{print $1}' > vmemmap_base
		awk '/Kernel code/ {gsub("-.*", "", $1); print $1}' /proc/iomem > Kernel_code
		awk '/Kernel data/ {gsub("-.*", "", $1); print $1}' /proc/iomem > Kernel_data
		awk '/Kernel bss/ {gsub("-.*", "", $1); print $1}' /proc/iomem > Kernel_bss

		for f in $cmp_file_list; do
			echo -e "$f: $(cat $f)"
			echo -e "${f}.old: $(cat ${f}.old)"
		done

		! test -s page_offset_base && rlDie "failed to get symbol addr"
	;;
	esac
}

function slub_freelist_random()
{
	[ "$SLUB_RANDOM" -eq 0 ] && echo "Skip $FUNCNAME" && return
	uname -r | grep debug && echo "Skip debug kernel" && return
	local kaslr=${1:-0}
	local index=$2
	if ((kaslr)); then
		local t="enabled.$index"
	else
		local t="disabled.$index"
	fi
	pushd slub_random_test
	rlLog "clean dmesg to empty..."
	dmesg -C > /dev/null
	rlRun "insmod slub_random_test.ko"
	rlRun "dmesg > slub_random_test.kaslr.$t"
	rlFileSubmit slub_random_test.kaslr.$t
	rlLog "you need to check slub_random_test.kaslr.$t manually"
	rlRun "rmmod slub_random_test"
	popd
}

function x86_kaslr_phase_prep()
{
	current_state="$(sed -n '1p' TEST_STATE)"
	phase=""
	case "$current_state" in
		before_r_kaslr_snapshot) 	phase="kaslr-snapshot";;
		after_r_kaslr_compare) 		phase="kaslr-compare";;
		after_r_nokaslr_snapshot) 	phase="nokaslr-snapshot";;
		after_r_nokaslr_compare) 	phase="nokaslr-compare";;
		after_r_nokaslr_cleanup) 	phase="nokaslr-cleanup";;
		before_r_nokaslr_snapshot) 	phase="nokaslr-snapshot";;
		after_r_kaslr_snapshot) 	phase="kaslr-snapshot";;
		after_r_kaslr_cleanup)		phase="kaslr-cleanup";;
	esac
	echo "debug: current_state=$current_state"
	echo "debug: phase=$phase"
}

function check_x86_paging_level()
{
	if grep -q la57 /proc/cpuinfo 2>/dev/null; then
		echo "Detected la57 cpu support"
		SUPPORT_LA57=1
	fi

	if grep -q no5lvl /proc/cmdline 2>/dev/null; then
		echo "Detected no5lvl kernel parameter"
		SUPPORT_NO5LVL=1
	fi

	if grep -q CONFIG_X86_5LEVEL=y /boot/config-"$(uname -r)" 2>/dev/null  ; then
		echo "Detected 5lvl config"
		SUPPORT_CONFIG_5LVL=1
	fi
	if [[ $SUPPORT_LA57 -eq 1 &&  $SUPPORT_NO5LVL -eq 0 && $SUPPORT_CONFIG_5LVL -eq 1 ]] ; then
		EXPECT_LVL=5
	else
		EXPECT_LVL=4
	fi
}

function x86_get_default_addr()
{
	cmp_file_list="_text page_offset_base vmemmap_base Kernel_code Kernel_data Kernel_bss"
	stable_file_list="_text Kernel_code"
	_text=ffffffff81000000
	Kernel_code=01000000

	check_x86_paging_level
	if [ "$EXPECT_LVL" = 5 ]; then
		_text=ffffffff81000000
		Kernel_code=01000000
	fi
}

function x86_kaslr_test()
{

	if [[ ! $phase =~ cleanup ]]; then
		get_symbol_addr_snapshot
		for f in $stable_file_list; do
			rlAssertNotEquals "$f should be non-default" "${!f}" "$(cat $f)"
		done
	fi

	local i=0
	if [ "$current_state" = "after_r_kaslr_compare" ]; then
		rlReport "reboot" PASS
		rlAssertNotGrep nokaslr /proc/cmdline || rlDie "unexpedted test state!"

		((i++))
		for f in $cmp_file_list; do
			rlAssertNotEquals "$f should be changed" "$(cat ${f}.old)" "$(cat $f)"
		done
		slub_freelist_random 1 $i
		rlRun "grubby --args nokaslr --update-kernel ALL" 0
		rlPhaseEnd
		rstrnt-reboot
	elif [ "$current_state" = "after_r_kaslr_cleanup" ]; then
		rlAssertGrep nokaslr /proc/cmdline || rlDie "unexpedted test state!"
	elif [ "$current_state" = "after_r_kaslr_snapshot" ]; then
		rlReport "reboot" PASS
		rlAssertNotGrep nokaslr /proc/cmdline || rlDie "unexpedted test state!"
		rlPhaseEnd
		rstrnt-reboot
	else
		rlAssertNotGrep nokaslr /proc/cmdline || rlDie "unexpedted test state!"
		slub_freelist_random 1 $i
		rlPhaseEnd
		rstrnt-reboot
	fi
}

function x86_nokaslr_test()
{
	if [ "$current_state" = "after_r_nokaslr_snapshot" ]; then
			rlReport "reboot" PASS
	fi

	if [[ ! $phase =~ cleanup ]]; then
		get_symbol_addr_snapshot
		for f in $stable_file_list; do
			rlAssertEquals "$f should be default" "${!f}" "$(cat $f)"
		done
	fi

	local i=0
	if [ "$current_state" = "after_r_nokaslr_compare" ]; then
		rlReport "reboot" PASS
		rlAssertGrep nokaslr /proc/cmdline
		((i++))
		for f in $cmp_file_list; do
			rlAssertEquals "$f should be same" "$(cat ${f}.old)" "$(cat $f)"
		done
		slub_freelist_random 0 $i
		rlRun "grubby --remove-args nokaslr --update-kernel ALL"
		rlPhaseEnd
		rstrnt-reboot
	elif [ "$current_state" = "after_r_nokaslr_cleanup" ]; then
		rlReport "reboot" PASS
		rlAssertNotGrep nokaslr /proc/cmdline
	elif [ "$current_state" = "before_r_nokaslr_snapshot" ]; then
		rlAssertGrep nokaslr /proc/cmdline
		rlPhaseEnd
		rstrnt-reboot
	else
		rlAssertGrep nokaslr /proc/cmdline
		slub_freelist_random 0 $i
		rlPhaseEnd
		rstrnt-reboot
	fi
}

function run_kaslr_x8664()
{
	grep CONFIG_RANDOMIZE_MEMORY=y /boot/config-"$(uname -r)" 2>/dev/null || { rlReport "Skip-not-support" PASS; return; }
	get_kernel_version
	if  [ "$kver_major" -lt 3 ]; then
		rlReport "Skip-not-support" PASS
		return
	elif [ "$kver_major" -eq 3 ] && [ "$kver_minor" -eq 10 ]; then
		if [ "$krel_major" -lt 705 ]; then
			rlReport "Skip-not-support" PASS
			return
		fi
	fi
	rlPhaseStartTest $phase
		rlRun "sed -i '1d' TEST_STATE" 0 "to next state $(sed -n '2p' TEST_STATE)"
		case "$phase" in
		kaslr*)
			x86_kaslr_test
			;;
		nokaslr*)
			x86_nokaslr_test
			;;
		esac

	rlPhaseEnd
}

function prepare_state_q()
{
	touch TEST_STATE
	if grep nokaslr /proc/cmdline; then
		echo "default cmdline: $(cat /proc/cmdline)"
		echo "before_r_nokaslr_snapshot" > TEST_STATE
		echo "after_r_nokaslr_compare" >> TEST_STATE
		echo "after_r_kaslr_snapshot" >> TEST_STATE
		echo "after_r_kaslr_compare" >> TEST_STATE
		echo "after_r_kaslr_cleanup" >> TEST_STATE
	else
		echo "before_r_kaslr_snapshot" > TEST_STATE
		echo "after_r_kaslr_compare" >> TEST_STATE
		echo "after_r_nokaslr_snapshot" >> TEST_STATE
		echo "after_r_nokaslr_compare" >> TEST_STATE
		echo "after_r_nokaslr_cleanup" >> TEST_STATE
	fi
	rlRun -l "cat TEST_STATE" 0 "states we are goting to handle."
}

function get_kernel_version()
{
    kver_major=$(uname -r | cut -d- -f1 | cut -d. -f 1) # 3
    kver_minor=$(uname -r | cut -d- -f1 | cut -d. -f 2) # 10
    kver_mminor=$(uname -r | cut -d- -f1 | cut -d. -f 3) # 0
    krel_major=$(uname -r | cut -d- -f2 | cut -d. -f 1) # 514
}

function select_yum_tool()
{
	if [ -x /usr/bin/dnf ]; then
		YUM=/usr/bin/dnf
		ALL="--all"
		${YUM} install -y dnf-plugins-core
	elif [ -x /usr/bin/yum ]; then
		YUM=/usr/bin/yum
		ALL="all"
		${YUM} install -y yum-plugin-copr
	else
		echo "No tool to download kernel from a repo" | tee -a ${OUTPUTFILE}
		rstrnt-report-result ${TEST} WARN 99
		rstrnt-abort -t recipe
		exit 0
	fi
}

rlJournalStart
	if ! test -f SETUP_FINISH; then
		rlPhaseStartSetup
			select_yum_tool
			prepare_state_q
			grep nokaslr /proc/cmdline && rlLogInfo "nokaslr in cmdline: $(cat /proc/cmdline)"
			unset ARCH
			if [ "$SLUB_RANDOM" -ne 0 ]; then
				uname -r | grep debug && { rpm -q kernel-devel-debug || ${YUM} -y install kernel-devel-debug; }
				# slub freelist random testing
				${YUM} -y install libelf-dev || ${YUM} -y install libelf-devel || ${YUM} -y install elfutils-libelf-devel
				rpm -q kernel-devel | grep $(uname -r) || ${YUM} -y install kernel-devel
				pushd slub_random_test
				rlRun "make" 0 "Compile slub random test kernel test module"
				popd
			fi
			touch SETUP_FINISH
		rlPhaseEnd
	fi

	case $this_arch in
		x86_64)
			x86_kaslr_phase_prep
			x86_get_default_addr
			run_kaslr_x8664
			;;
		*)
			rlPhaseStartTest "SKIP"
			rlPhaseEnd
			;;
	esac

	rlPhaseStartCleanup
		rlRun "rm TEST_STATE SETUP_FINISH -f"
	rlPhaseEnd
rlJournalEnd
rlJournalPrintText
