#!/bin/bash
# Copyright (c) 2014 Red Hat, Inc.
#
# This copyrighted material is made available to anyone wishing
# to use, modify, copy, or redistribute it subject to the terms
#  and conditions of the GNU General Public License version 2.
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
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

. ../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

g_rc_any="0-255" # XXX: make sure rlRun supports any return code

function setup_mp(){
    rlRun "rpm -q device-mapper-multipath" 0 "check the device-mapper-multipath if installed"
    rlRun "rpm -q sg3_utils" 0 "check the sg3_utils if installed"
    rlRun "mpathconf --enable --find_multipaths y --with_module y --with_multipathd y"
    rlServiceStop multipathd && rlServiceStart multipathd
    rlRun "multipath -l"
    rlRun "lsmod |grep scsi_debug && rmmod scsi_debug" $g_rc_any "remove scsi_debug"
}

function get_scsi_debug_devices (){
    ls /sys/block/sd* -d 2>/dev/null | while read dev; do
        dev=$(basename $dev)
        grep -qw scsi_debug /sys/block/$dev/device/model && echo "/dev/$dev" && return 0
    done
}

function scsi_level(){
    local major
    local minor
    local stat
    local dev
    local mpath_name
    local flag=0

    for i in 4 5 6 7;do
        rlLog "add scsi_debug level $i"
        rlLog "Start test using scsi_level $i"
        rlRun "modprobe scsi_debug scsi_level=$i"
        dev=$(get_scsi_debug_devices)
        if [[ -z $dev  ]];then
            rlLog "Can not get test device at level $i, skip it"
            continue
        fi
        (( $flag += 1 ))
        rlLog "Checking if VPD for "$dev" is exported correctly"
        rlRun "sg_inq $dev" 0  "get message by sg_ing"
        rlRun "sg_vpd --page=0x80 $dev" 0 "get mesage by page=0x80"
        rlRun "sg_vpd --page=0x83 $dev" 0 "get message by page=0x83"
        rlLog "VPD exported successfuly for $dev scsi_level $i"
        rlLog "remove $dev from multipath"
        rlRun "multipath -l |grep 'scsi_debug'" "$g_rc_any" "try to remove scsi_debug from mp"
        if [[ $? == 0 ]];then
            rlRun "multipath -l"
            rlRun "dmsetup deps"
            major=$(ls -l "$dev" |awk '{print ($5)}')
            minor=$(ls -l "$dev" |awk '{print ($6)}')
            disk="($major $minor)"
            rlLog "$major $minor, $disk get disk parameter"
            mpath_name=$(dmsetup deps |grep "$disk" |awk -F : '{print $1}')
            rlLog "$mpath_name,get disk's mp name and rm it"
            rlRun "multipath -f $mpath_name "
            sleep 5
            rlRun "multipath -f $mpath_name"
        fi
        rlRun "multipath -F"
        rlServiceStop multipathd
        rlRun "systemctl disable multipathd"
        rlRun "multipath -F"
        rlRun "multipath  -l |grep $mpath_name" "$g_rc_any" "test scsi_debug if removed "
        rlRun "rmmod scsi_debug" "$g_rc_any" "remove scsi_debug"
        stat=$?
        while [[ $stat != 0 ]];do
            rlLog "can not remove scsi_debug"
            sleep 1
            rlRun "multipath -F"
            rlServiceStop multipathd
            rlRun "dmsetup remove_all"
            rlRun "echo -1 > /sys/bus/pseudo/drivers/scsi_debug/add_host"
            rLrun "modprobe -r scsi_debug" "$g_rc_any" "remove scsi_debug"
            stat=$?
        done
        rlLog "test passed scsi_debug $i level vpd "
    done

    if (( $flag == 0 )); then
        rlLog "Skipping test because test device not found"
        rstrnt-report-result $TEST SKIP $OUTPUTFILE
        exit 0
    fi
}

function check_log(){
    rlRun "dmesg | grep -i 'Call Trace:'" 1 "check the errors"
}

rlJournalStart
    rlPhaseStartTest
        rlRun "uname -a"
        rlLog "$0"
        setup_mp
        scsi_level
        check_log
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
