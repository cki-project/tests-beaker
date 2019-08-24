#!/bin/bash
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

export CPUCOUNT=$(grep -c -w  processor /proc/cpuinfo)

BZLIST=${BZLIST:-}
SKIPLIST=${SKIPLIST:-}

crash_cmd=crash_ksymbol.cmd
this_arch=$(uname -m)

function pkg_install_try
{
	typeset pkgmgr=$(dnf --version > /dev/null 2>&1 && \
			 echo dnf || echo yum)
	typeset pkg=""
	for pkg in "$@"; do
		rpm -q $pkg && return 0
		$pkgmgr -y install $pkg && return 0
	done
	return 1
}

function pkg_install
{
	typeset pkg=$1
	pkg_install_try $pkg
	return $?
}

function abort_task
{
	typeset reason="$*"
	rlLog "Aborting task because $reason"
	rstrnt-abort --server $RSTRNT_RECIPE_URL/tasks/$TASKID/status
	exit 0
}

function skip_task
{
	typeset reason="$*"
	rlLog "Skipping task because $reason"
	rhts-report-result "$TEST" SKIP "$OUTPUTFILE"
	exit 0
}

function run_crash()
{
	pkg_install kernel-debuginfo || \
		abort_task "fail to install pkg kernel-debuginfo"

	rm -f page_offset_base vmemmap

	case $this_arch in
	x86_64)
    cat > $crash_cmd << EOF
sym vmemmap_base > vmemmap_base
sym page_offset_base > page_offset_base
exit
EOF
	crash -i $crash_cmd
	! test -s page_offset_base && rlDie "failed to get symbol addr"
	;;
	esac
}

function slub_freelist_random()
{
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

function run_kaslr_x8664()
{
	local phase=""
	if test -f reboot_kaslr2; then
		return
	fi

	if ! grep nokaslr /proc/cmdline; then
		phase="kaslr"
	else
		phase="nokaslr"
	fi

	rlPhaseStartTest $phase

	rlRun "awk '/Kernel/ {print}' /proc/iomem" -l
	run_crash

	case "$phase" in
	kaslr)
		rlAssertNotEquals "PAGEOFFSET should be non-default" "#ffff880000000000" "#$(cat page_offset_base)"
		rlAssertNotEquals "vmemmap should be non-default" "#ffffea0000000000" "#$(cat vmemmap)"
		rlAssertNotEquals "_text should be non-default" "#ffffffff81000000" "#$(grep -w _text /proc/kallsyms  | awk '{print $1}')"
		local i=0
		test -f reboot_kaslr1 && ((i++))
		slub_freelist_random 0 $i
		! test -f reboot_kaslr1 &&  touch reboot_kaslr1 && rhts-reboot
		;;
	nokaslr)
		rlAssertEquals "PAGEOFFSET should be default" "#ffff880000000000" "#$(awk '! /crash/ {print $1}' page_offset_base)"
		rlAssertEquals "vmemmap should be default" "#ffffea0000000000" "#$(awk '! /crash/ {print $1}' vmemmap)"
		rlAssertEquals "_text should be default" "#ffffffff81000000" "#$(grep -w _text /proc/kallsyms  | awk '{print $1}')"
		local i=0
		test -f reboot_kaslr2 && ((i++))
		slub_freelist_random 1 $i
		! test -f reboot_kaslr2 &&  touch reboot_kaslr2 && rhts-reboot
		;;
	esac

	rlPhaseEnd
}


rlJournalStart
	rlPhaseStartSetup
		uname -r | grep debug
		if (( $? == 0 )); then
			pkg="kernel-devel-debug"
			pkg_install $pkg || abort_task "fail to install pkg $pkg"
		fi

		pkg_install_try elfutils-libelf-devel \
				libelf-devel \
				libelf-dev
		(( $? != 0 )) && abort_task "fail to install pkg related to elfutils"

		# slub freelist random testing
		pushd slub_random_test
		rlRun "make" 0 "Compile slub random test kernel test module"
		popd

		run_crash
	rlPhaseEnd

	case $this_arch in
		x86_64)
			run_kaslr_x8664
			;;
		*)
			rlPhaseStart "SKIP"
			rlPhaseEnd
		;;
	esac

	rlPhaseStartCleanup
	rlPhaseEnd
rlJournalEnd
rlJournalPrintText
