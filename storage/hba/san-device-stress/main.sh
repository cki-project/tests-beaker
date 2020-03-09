#!/bin/bash
#
# Copyright (c) 2019 Red Hat, Inc. All rights reserved.
#
# This copyrighted material is made available to anyone wishing
# to use, modify, copy, or redistribute it subject to the terms
# and conditions of the GNU General Public License version 2.
#
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
#

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

function fio_setup
{
        # check fio is installed
        fio --help 2>&1 | egrep -q "axboe" && return 0

        # else install it via its source code
        typeset src_git="https://git.kernel.org/pub/scm/linux/kernel/git/axboe/fio.git"
        typeset dst_dir="/tmp/fio.$$"

        rm -rf $dst_dir
        git clone $src_git $dst_dir || return 1

        pushd $(pwd)
        cd $dst_dir
        ./configure || return 1
        make || return 1
        make install || return 1
        popd

        return 0
}

function fio_device_level_test
{
        local test_dev=$1
        local ret=0
        local runtime=180
        local numjobs=60

        rlLog "INFO: Executing fio_device_level_test() with device: $test_dev"

	rlRun "fio -filename=$test_dev -iodepth=1 -thread -rw=write -ioengine=psync -bssplit=5k/10:9k/10:13k/10:17k/10:21k/10:25k/10:29k/10:33k/10:37k/10:41k/10 -direct=1 -runtime=$runtime -time_based -size=1G -group_reporting -name=mytest -numjobs=$numjobs"
        if [ $? -ne 0 ]; then
                rlLog "FAIL: fio device level write testing for $test_dev failed"
                ret=1
        fi
        rlRun "fio -filename=$test_dev -iodepth=1 -thread -rw=randwrite -ioengine=psync -bssplit=5k/10:9k/10:13k/10:17k/10:21k/10:25k/10:29k/10:33k/10:37k/10:41k/10 -direct=1 -runtime=$runtime -time_based -size=1G -group_reporting -name=mytest -numjobs=$numjobs"
	if [ $? -ne 0 ]; then
                rlLog "FAIL: fio device level randwrite testing for $test_dev failed"
                ret=1
        fi
        rlRun "fio -filename=$test_dev -iodepth=1 -thread -rw=read -ioengine=psync -bssplit=5k/10:9k/10:13k/10:17k/10:21k/10:25k/10:29k/10:33k/10:37k/10:41k/10 -direct=1 -runtime=$runtime -time_based -size=1G -group_reporting -name=mytest -numjobs=$numjobs"
	if [ $? -ne 0 ]; then
                rlLog "FAIL: fio device level read testing for $test_dev failed"
                ret=1
        fi
        rlRun "fio -filename=$test_dev -iodepth=1 -thread -rw=randread -ioengine=psync -bssplit=5k/10:9k/10:13k/10:17k/10:21k/10:25k/10:29k/10:33k/10:37k/10:41k/10 -direct=1 -runtime=$runtime -time_based -size=1G -group_reporting -name=mytest -numjobs=$numjobs"
	if [ $? -ne 0 ]; then
                rlLog "FAIL: fio device level randread testing for $test_dev failed"
                ret=1
        fi

        return $ret
}

function get_test_disk
{
        typeset sd=${_TEST_DISK:-""}
        typeset boot_disk=$(lsblk | grep boot | awk '{print $1}' | \
                            grep -oE [a-Z]{3\,})
        typeset disk=""
        for disk in $(lsblk | grep disk | awk '{print $1}'); do
                [[ $disk == $boot_disk ]] && sd=$disk && break
        done

        [[ -z $sd ]] && echo $sd
        return 0
}

#
# XXX: A hard disk is required by this test case, we can create a loop device
#      to do unit testing in system which doesn't have more than one disk.
#      Hence, we introduce env _XXX_TEST_DISK on purpose, e.g.
#
#      root# dd if=/dev/zero of=/home/disk0 bs=100M count=1
#      root# mkfs.ext4 /home/disk0 <<< y
#      root# losetup /dev/loop1 /home/disk0
#      root# export _XXX_TEST_DISK=loop1
#

# Find a suitable disk to run FIO
sd=${_XXX_TEST_DISK}
[[ -z $sd ]] && sd=$(get_test_disk)
if [[ -z $sd ]]; then
        rlLog "no free disk available" | tee -a $OUTPUTFILE
        rstrnt-report-result $TEST SKIP $OUTPUTFILE
        exit 0
fi

rlJournalStart
        rlPhaseStartSetup
                fio_setup
                if (( $? != 0 )); then
                        rlLog "failed to setup fio" | tee -a $OUTPUTFILE
                        rstrnt-report-result $TEST ABORT $OUTPUTFILE
                        exit 1
                fi
        rlPhaseEnd
        rlPhaseStartTest
                fio_device_level_test "/dev/$sd"
        rlPhaseEnd
rlJournalEnd
rlJournalPrintText
