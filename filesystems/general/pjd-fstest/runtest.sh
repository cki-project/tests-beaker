#!/bin/bash
# vim: dict=/usr/share/rhts-library/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/filesystems/general/pjd-fstest
#   Description: Tests POSIX features of file system
#   Author: Zorro Lang <zlang@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc. All rights reserved.
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

# Include environment and beaker library
. ../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

# Test command, not the pipe (tee ...)
set -o pipefail

#prepare global values
TEST="filesystems/general/pjd-fstest"
test -z "$TEST_PARAM_DEVICE" || TEST_DEV="${TEST_PARAM_DEVICE}"
test -z "$TEST_PARAM_TESTMNT" || TEST_MNT="${TEST_PARAM_TESTMNT}"
test -z "$TEST_PARAM_FSTYPE" && TEST_PARAM_FSTYPE="$TEST_PARAM_FSTYP" # Backwards compatiblity
if [ -n "$TEST_PARAM_FSOPTS" ];then
	FSOPTS="-o $TEST_PARAM_FSOPTS"
fi
if [ -n "$TEST_PARAM_FSTYPE" ]; then
	FSTYPES="$TEST_PARAM_FSTYPE"
else
	FSTYPES="ext3 ext4 xfs"
fi
FSTYPE=""
TestsDir=""
TmpDir=""

# make sure the arguments all lower
FSTYPES=$(echo ${FSTYPES}|tr [:upper:] [:lower:])
FSOPTS=$(echo ${FSOPTS}|tr [:upper:] [:lower:])

RHEL_DISTRO=$(rlGetDistroRelease)
RHEL_DISTRO=${RHEL_DISTRO:0:1}
LOCAL_ARCH=`uname -m`


check_supported_fs() {
	local fstype=$1
	case ${fstype} in
		ext*|xfs)
			:;;
		*)
		rlReport "Can't support $FSTYPE filesystem test" WARN
		rstrnt-report-result $TEST WARN
		# Abort the task
		rstrnt-abort --server $RSTRNT_RECIPE_URL/tasks/$TASKID/status
		exit 0
		;;
	esac
	return 0
}


build_pjd_fstest()
{
	local workdir=$1
	pushd $workdir
	rlRun -l "git clone git://git.code.sf.net/p/ntfs-3g/pjd-fstest" "0-255" "Cloning pjd-fstest repo"
	if [ $? -ne 0 ]; then
		echo "WARN : Failed cloning pjd-fstest" | tee -a $OUTPUTFILE
		rstrnt-report-result $TEST WARN
		# Abort the task
		rstrnt-abort --server $RSTRNT_RECIPE_URL/tasks/$TASKID/status
		exit 0
	fi
	rlRun "pushd pjd-fstest"
	rlRun "make" "0-255" "Building test suite"
	if [ $? -ne  0 ] ; then
		echo "WARN : Failed compiling pjd-fstest" | tee -a $OUTPUTFILE
		rstrnt-report-result $TEST WARN
		# Abort the task
		rstrnt-abort --server $RSTRNT_RECIPE_URL/tasks/$TASKID/status
		exit 0
	fi
	rlRun "popd"
	rlRun "TestsDir=\`ls -d $workdir/pjd-fstest/tests\`" 0 "Looking for tests"
	rlAssertExists "$TestsDir"
}


pjd_fstest_prepare() {
	rlPhaseStartSetup ${TEST}:Build
		rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
		build_pjd_fstest $TmpDir
	rlPhaseEnd
}

localfs_prepare()
{
	rlPhaseStartSetup ${TEST}:Setup:$FSTYPE
                # prepare for local fstest
		rlRun "echo -e \"os=Linux\nfs=${FSTYPE}\" > $TestsDir/conf" 0 "Setting up environment"

		# we have a pre-mount test partition, grab it
		if test -n "$TEST_MNT"; then
			rlRun "TEST_DEV=`cat /proc/mounts | grep "$TEST_MNT" | awk '{print $1}'`"
			# Remove entry in fstab
			rlRun "cp /etc/fstab{,.bak}"
			rlRun "cat /etc/fstab.bak | grep -v $TEST_MNT > /etc/fstab"
			rlRun "umount $TEST_DEV" 0 "umount device for re-creating filesystem"
		fi

		if test -z "${TEST_DEV}"; then
			# Check for a pre-prepared lvm device
			TMP_DEV="$(echo /dev/mapper/*-xfstest)"
			echo "TMP_DEV=$TMP_DEV"
			if test -b "$TMP_DEV";then
				TEST_DEV="$TMP_DEV"
				dd if=/dev/zero of="$TEST_DEV" bs=1M count=1
			fi
		fi

		if test -z "${TEST_DEV}"; then
			if [ $RHEL_DISTRO -ge 5 ] || rlIsFedora ;then
				TEST_DEV=`losetup -f`
			else
				i=0
				# rhel 4 doesn't support losetup -f
				while true; do
					if [ ! -e /dev/loop${i} ];then
						TEST_DEV=/dev/loop${i}
						break
					fi
					let i++
				done
			fi
			TEST_DEV_LOOP=1
			rlRun "dd if=/dev/zero of=test.img bs=1M count=500"
			rlRun "losetup $TEST_DEV test.img"
		fi

		local flags="f"
		if [[ $FSTYPE =~ ext ]] ; then
			flags="F"
		fi
		rlRun "/sbin/mkfs -t $FSTYPE -$flags $TEST_DEV $MKFS_OPTS" 0 "Creating filesystem on image"
		rlRun "mkdir -p mnt && mount -t $FSTYPE $TEST_DEV mnt $FSOPTS" 0 "Mounting filesystem \"${FSTYPE}\" with options \"${FSOPTS}\""
		rlRun "pushd mnt"
	rlPhaseEnd
}

localfs_test()
{
	for testFeature in $TestsDir/*/; do
		feature=`basename $testFeature`
		rlPhaseStartTest "$feature: fs=\"$FSTYPE\" options=\"$FSOPTS\""
		# prove in RHEL 5 and less does not support -f option
                local flags="rv"
                if [ $RHEL_DISTRO -ge 5 ] || rlIsFedora ;then
			flags="rf"
		fi
		rlRun "prove -$flags $testFeature 2>&1|tee output.log" 0 "Testing feature $feature"
		rlFileSubmit "output.log" "$FSTYPE-output-$feature.log"
		rlPhaseEnd
	done

	rlPhaseStartCleanup "Unmounted $TEST_DEV"
                rlRun "popd"
		rlRun "umount $TEST_DEV" 0 "Umounting workdir"
	rlPhaseEnd
}



prepare_test_device()
{
	localfs_prepare
}

test_main()
{
	localfs_test
}

cleanup()
{
	rlPhaseStartCleanup
		test $TEST_DEV_LOOP -eq 1 && rlRun "losetup -d $TEST_DEV" 0 "Discarding block device"
		rlRun "rm -rf $TmpDir" 0 "Removing tmp directory"
		# mount pre-set TEST_MNT back for next case
		test -n "$TEST_MNT" && rlRun "mount $TEST_DEV $TEST_MNT" 0 "Mount preset partition back"

	rlPhaseEnd

}


# ------------------Start test -----------------
rlJournalStart
pjd_fstest_prepare
for FSTYPE in $FSTYPES
do
	check_supported_fs ${FSTYPE}
	prepare_test_device
	test_main
done
cleanup
rlJournalPrintText
rlJournalEnd
