#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/vm/hugepage/libhugetlbfs
#   Description: Test libhugetlbfs with upstream testsuite
#   Author: Caspar Zhang <czhang@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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

FILE=$(readlink -f $BASH_SOURCE)
NAME=$(basename $FILE)
CDIR=$(dirname $FILE)

# Include beaker environment
source $CDIR/../../../cki_lib/libcki.sh || exit 1
source $CDIR/lib/kvercmp.sh

function setup
{
	bash $CDIR/utils/build.sh
}

setup

PACKAGE="libhugetlbfs"
if grep -q "release [5-7].*" /etc/redhat-release; then
	TESTVERSION=2.18
else
	TESTVERSION=2.21
fi

TARGET=${PACKAGE}-${TESTVERSION}
TESTAREA=/mnt/testarea
WORK_DIR=${TARGET}/tests

cat /proc/filesystems | grep -q hugetlbfs
if [ $? -ne 0 ]; then
	# Bug 1143877 - hugetlbfs: disabling because there are no supported hugepage sizes
	echo "hugetlbfs not found in /proc/filesystems, skipping test"
	rstrnt-report-result Test_Skipped PASS 99
	exit 0
fi

# we need at least 6 hugepages and at least ~128M of memory
hpagesz=$(cat /proc/meminfo | grep Hugepagesize | awk '{print $2}')
if [ -z "$hpagesz" ]; then
	echo "Failed to get Hugepagesize from /proc/meminfo" | tee -a $OUTPUTFILE
	cat /proc/meminfo | tee -a $OUTPUTFILE
	rstrnt-report-result Hugepagesize_parse_failed FAIL 1
	exit 0
fi
target_mem=${TESTARGS:-131072}

HMEMSZ=$(($target_mem / 1024))
HPCOUNT=$(($target_mem / $hpagesz))
if [ "$HPCOUNT" -lt 6 ]; then
	HPCOUNT=6
	HMEMSZ=$((HPCOUNT * $hpagesz / 1024))
fi

if [ -n "$hpagesz" -a "$hpagesz" -gt 0 ]; then
	HPSIZE="$(($hpagesz / 1024))M"
else
	HPSIZE=0
fi

echo "HMEMSZ: $HMEMSZ" | tee -a $OUTPUTFILE
echo "HPSIZE: $HPSIZE" | tee -a $OUTPUTFILE
echo "HPCOUNT: $HPCOUNT" | tee -a $OUTPUTFILE

# KNOWN ISSUES
#  If you're adding new issue, then please reference a BZ, and exclude it *only*
#  for specific architecture and kernel version. Matching on distro major/minor
#  is usually not needed because this test carries its own version of libhugetlbfs.
cver=$(uname -r)

if grep -q "release 6.[0-9] " /etc/redhat-release; then
	# legacy known issue
	# TODO: BZ
	if uname -r | grep -q 686; then
		KNOWNISSUE_32="$KNOWNISSUE_32 -e \"truncate_above_4GB.*mmap() offset 4GB\""
	fi
fi

# single CPU hosts, like KVM make some test fail with "Bad configuration"
# TODO: fix upstream
cpus=$(cat /proc/cpuinfo  | grep ^processor | wc -l)
if [ "$cpus" -lt 2 ]; then
	KNOWNISSUE_32="$KNOWNISSUE_32 -e \"Bad configuration: sched_setaffinity\""
	KNOWNISSUE_64="$KNOWNISSUE_64 -e \"Bad configuration: sched_setaffinity\""
fi

kvercmp "$cver" '4.3'
if [ $kver_ret -le 0 ]; then
       KNOWNISSUE_32="$KNOWNISSUE_32 -e \"no fallocate support in kernels before 4.3.0\""
       KNOWNISSUE_64="$KNOWNISSUE_64 -e \"no fallocate support in kernels before 4.3.0\""
fi

# Bug 1006253 libhugetlbfs counters testcase occasionally fails on NUMA systems
if grep -q "release 7.[0-9]" /etc/redhat-release; then
	kvercmp "$cver" '4.10'
	if [ $kver_ret -le 0 ]; then
		KNOWNISSUE_32="$KNOWNISSUE_32 -e \"^counters.sh.*Bad HugePages\""
		KNOWNISSUE_64="$KNOWNISSUE_64 -e \"^counters.sh.*Bad HugePages\""
	fi
fi

# Bug 1161661 - s390x: zero_filesize_segment (64bit) testcase crashing -> CANTFIX
# impacts all distros / all kernel versions
if uname -r | grep -q s390x; then
	KNOWNISSUE_64="$KNOWNISSUE_32 -e \"zero_filesize_segment (1024K: 64):\""
fi

# https://bugzilla.redhat.com/show_bug.cgi?id=1628794#c8
if egrep -q "Fedora|.*release 8" /etc/redhat-release; then
	KNOWNISSUE_32="$KNOWNISSUE_32 -e \"brk_near_huge\""
	KNOWNISSUE_64="$KNOWNISSUE_64 -e \"brk_near_huge\""
fi

# Bug 859906 - open() on tmpfs file with O_DIRECT fails with EINVAL -> WONTFIX
# impacts all distros / all kernel versions, if /tmp is tmpfs
if df -T /tmp | tail | grep -q tmpfs; then
	KNOWNISSUE_32="$KNOWNISSUE_32 -e \"^direct .*Bad configuration\""
	KNOWNISSUE_64="$KNOWNISSUE_64 -e \"^direct .*Bad configuration\""
fi

# Bug 1631911 - [ALT-7.6] vm/hugepage/libhugetlbfs -fails Page size is too large for configured
if [ "x${HPSIZE}" == "x512M" ]; then
	KNOWNISSUE_32="$KNOWNISSUE_32 -e \"Page size is too large for configured SEGMENT_SIZE\""
	KNOWNISSUE_64="$KNOWNISSUE_64 -e \"Page size is too large for configured SEGMENT_SIZE\""
fi

RunTest()
{
    r_test=$1
    testlog=${TESTAREA}/$r_test.log

    rlRun "./run_tests.py -t $r_test 2>&1 > $testlog"

    rlLog "========== SHOW RUNNING STATISTICS: =========="
        rlRun "tail -n 13 $testlog" 0
    rlLog "==========  END RUNNING STATISTICS  =========="

    rlLog "========== SHOW FAILED CASES IN 32-BIT: =========="
    rlRun "grep \"$HPSIZE: 32\" $testlog | grep -v -e PASS -e SKIP $KNOWNISSUE_32" 1
    rlLog "==========  END FAILED CASES IN 32-BIT  =========="

if [ x"${ARCH}" != "xi386" ]; then
    rlLog "========== SHOW FAILED CASES IN 64-BIT: =========="
    rlRun "grep \"$HPSIZE: 64\" $testlog | grep -v -e PASS -e SKIP $KNOWNISSUE_64" 1
    rlLog "==========  END FAILED CASES IN 64-BIT  =========="
fi

    rlFileSubmit $testlog
}

# ------ Start Testing ------

#Grace Period
sleep 60

# RHEL7 would fails huge_page_setup_helper.py if no /etc/sysctl.conf
if [ ! -e "/etc/sysctl.conf" ]; then
    echo "Making empty /etc/sysctl.conf" | tee -a $OUTPUTFILE
    touch /etc/sysctl.conf
    restorecon /etc/sysctl.conf
fi

rlJournalStart
    rlPhaseStartSetup
        # increase our chances of getting huge pages
        rlRun "echo 3 > /proc/sys/vm/drop_caches"
        # Support hugetlbfs?
        rlAssertGrep "hugetlbfs" "/proc/filesystems"
        rlAssertGrep "HugePages_Total" "/proc/meminfo"
        rlLog "Hugepage to allocate: ${HMEMSZ}MB"
        # pre-cleanup
        rlRun "umount -a -t hugetlbfs"
        rlRun "hugeadm --pool-pages-max ${HPSIZE}:0"

        # Set up hugepage
	python2 /usr/bin/huge_page_setup_helper.py > hpage_setup.txt <<EOF
${HMEMSZ}
hugepages
hugepages root
EOF
        ret=$?
        cat hpage_setup.txt | tee -a $OUTPUTFILE
        if [ $ret -ne 0 ]; then
                mem_free=$(cat /proc/meminfo | grep MemFree | awk '{print $2}')
                grep -q "Refusing to allocate .*, you must leave at least .* for the system" hpage_setup.txt
                # If we get message about low memory and free ram is not at least
                # 10x what the test needs, assume we have low memory or the memory
                # is too fragmented. Skip the test and exit with PASS.
                if [ $? -eq 0 -a $mem_free -lt $(($HMEMSZ * 1024 * 10)) ]; then
                        cat /proc/meminfo | tee -a $OUTPUTFILE
                        rstrnt-report-result Test_Skipped PASS 99
                        exit 0
                fi

                # If we fail for any other reason, report FAIL and exit.
                rstrnt-report-result huge_page_setup FAIL $ret
                exit $ret
        fi
        rlRun "hugeadm --create-mount" 0
        rlRun "pushd ${WORK_DIR}" 0
    rlPhaseEnd

    free_hugepages=`cat /proc/meminfo | grep HugePages_Free | awk '{ print $2 }'`
    if [[ x"${ARCH}" == "xaarch64" ]]; then
       if [[ x"${HPSIZE}" == "x512M" && ${free_hugepages} -lt $HPCOUNT && ( -z "${REBOOTCOUNT}" || ${REBOOTCOUNT} -eq 0 ) ]]; then
	  rlLog "Have ${free_hugepages} free hugepages of ${HPCOUNT} needed.  Rebooting with 2M hugepages"
	  grubby --args="default_hugepagesz=2M" --update-kernel /boot/vmlinuz-$(uname -r)
	  rstrnt-reboot
       fi
       sed -i '/mremap-expand-slice-collision/d' run_tests.py
    fi
    if [ $free_hugepages -ge $HPCOUNT ]; then
        rlPhaseStartTest "func"
            RunTest func
        rlPhaseEnd

	# stress test takes too long on aarch64
	if [ x"${ARCH}" != "xaarch64" ]; then
	   rlPhaseStartTest "stress"
	       RunTest stress
	   rlPhaseEnd
	fi
    else
        mem_total=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
        hpsize=$(cat /proc/meminfo | grep Hugepagesize | awk '{print $2}')
	if [ ${mem_total} -gt $((1024 * ${HMEMSZ} * 10)) ]; then
	   rlPhaseStart WARN "not_enough_huge_pages"
	       rlAssertGreaterOrEqual "Need $HPCOUNT hugepages for test, have: $free_hugepages" $free_hugepages $HPCOUNT
	   rlPhaseEnd
	else
	   rstrnt-report-result Test_Skipped PASS 99
	fi
    fi

    rlPhaseStartCleanup
        rlRun "popd" 0
        rlRun "umount -a -t hugetlbfs"
        rlRun "hugeadm --pool-pages-max ${HPSIZE}:0"
        rlRun "mv /etc/sysctl.conf.backup /etc/sysctl.conf"
    rlPhaseEnd
rlJournalEnd
