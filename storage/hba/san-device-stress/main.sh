#!/bin/bash
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

dbg_flag=${dbg_flag:-"set +x"}
$dbg_flag

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1


function fio_device_level_test() {
        EX_USAGE=64 # Bad arg format
        if [ $# -lt 1 ]; then
                echo 'Usage: fio_device_level_test $test_dev'
                exit "${EX_USAGE}"
        fi
        # variable definitions
        local ret=0
        local tmp_dev=$1
        local runtime=180
        local numjobs=60
        if [ "${tmp_dev:0:5}" = "/dev/" ]; then
                test_dev=$tmp_dev
        else
                test_dev="/dev/${tmp_dev}"

        fi
        rlLog "INFO: Executing fio_device_level_test() with device: $test_dev"

        #fio testing
        rlRun "fio -filename=$test_dev -iodepth=1 -thread -rw=write -ioengine=psync -bssplit=5k/10:9k/10:13k/10:17k/10:21k/10:25k/10:29k/10:33k/10:37k/10:41k/10 -direct=1 -runtime=$runtime -size=-group_reporting -name=mytest -numjobs=$numjobs"
        if [ $? -ne 0 ]; then
                rlLog "FAIL: fio device level write testing for $test_dev failed"
                ret=1
        fi
        rlRun "fio -filename=$test_dev -iodepth=1 -thread -rw=randwrite -ioengine=psync -bssplit=5k/10:9k/10:13k/10:17k/10:21k/10:25k/10:29k/10:33k/10:37k/10:41k/10 -direct=1 -runtime=$runtime -size=-group_reporting -name=mytest -numjobs=$numjobs"
        if [ $? -ne 0 ]; then
                rlLog "FAIL: fio device level randwrite testing for $test_dev failed"
                ret=1
        fi
        rlRun "fio -filename=$test_dev -iodepth=1 -thread -rw=read -ioengine=psync -bssplit=5k/10:9k/10:13k/10:17k/10:21k/10:25k/10:29k/10:33k/10:37k/10:41k/10 -direct=1 -runtime=$runtime -size=-group_reporting -name=mytest -numjobs=$numjobs"
        if [ $? -ne 0 ]; then
                rlLog "FAIL: fio device level read testing for $test_dev failed"
                ret=1
        fi
        rlRun "fio -filename=$test_dev -iodepth=1 -thread -rw=randread -ioengine=psync -bssplit=5k/10:9k/10:13k/10:17k/10:21k/10:25k/10:29k/10:33k/10:37k/10:41k/10 -direct=1 -runtime=$runtime -size=-group_reporting -name=mytest -numjobs=$numjobs"
        if [ $? -ne 0 ]; then
                rlLog "FAIL: fio device level randread testing for $test_dev failed"
                ret=1
        fi

        return $ret
}


#Find a suitable disk to run FIO
boot_disk=$(lsblk |grep boot | awk '{print $1}' | grep -oE [a-Z]{3\,})
for i in $(lsblk |grep disk | awk '{print $1}');do
    if [ $i == $boot_disk ];then
        continue
    else
        sd=$i
        break
   fi
done

if [ ! $sd ];then
    rlLog "no free disk available" | tee -a $OUTPUTFILE
    rhts-report-result $TEST SKIP $OUTPUTFILE
    exit 0
fi


device="/dev/${sd}"



rlJournalStart
    rlPhaseStartTest
        fio_device_level_test "$device"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
