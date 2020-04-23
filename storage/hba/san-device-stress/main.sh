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
. ../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

YUM=$(cki_get_yum_tool)

#find all the disks on the system in test
sd=$(lsblk -nd --output NAME)

#Function to install FIO
function install_fio() {
    rlRun "rpm -q fio || $YUM -y install fio"
}

#Function to Generate I/O with FIO
function fio_device_level_test
{
    local test_dev=$1
    local ret=0
    local size=2G

    rlLog "INFO: Executing fio_device_level_test() with device: $test_dev"

    rlRun "fio -filename=$test_dev -iodepth=16 -rw=write -ioengine=libaio -bssplit=4K -direct=1 -size=$size -group_reporting -name=mytest -verify=crc32c"
    if [ $? -ne 0 ]; then
        rlLog "FAIL: fio device level write testing for $test_dev failed"
        ret=1
    fi
    rlRun "fio -filename=$test_dev -iodepth=16 -rw=randwrite -ioengine=libaio -bssplit=4K -direct=1 -size=$size -group_reporting -name=mytest -verify=crc32c"
    if [ $? -ne 0 ]; then
        rlLog "FAIL: fio device level randwrite testing for $test_dev failed"
        ret=1
    fi
    rlRun "fio -filename=$test_dev -iodepth=16 -rw=read -ioengine=libaio -bssplit=4K -direct=1 -size=$size -group_reporting -name=mytest -verify=crc32c"
    if [ $? -ne 0 ]; then
        rlLog "FAIL: fio device level read testing for $test_dev failed"
        ret=1
    fi
    rlRun "fio -filename=$test_dev -iodepth=16 -rw=randread -ioengine=libaio -bssplit=4K -direct=1 -size=$size -group_reporting -name=mytest -verify=crc32c"
    if [ $? -ne 0 ]; then
        rlLog "FAIL: fio device level randread testing for $test_dev failed"
        ret=1
    fi

    return $ret
}

#function to find non-boot disks and run FIO
function get_disk_and_FIO { 
    for d in $sd; do
        boot_drv_check=$(lsblk /dev/$d | grep -E "boot|SWAP|home|rom" | grep -v grep | wc -l)
        if [ $boot_drv_check -gt 0 ]; then
            rlLog "Skipping disk /dev/$d"
        else
            fio_device_level_test "/dev/$d"
        fi
    done

}

rlJournalStart
    rlPhaseStartSetup
        install_fio
    rlPhaseEnd
    rlPhaseStartTest
        get_disk_and_FIO
    rlPhaseEnd
rlJournalEnd
rlJournalPrintText
