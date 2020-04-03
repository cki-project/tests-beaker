#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/storage/dt_stress/dt_stress_panic
#   Description: This test verifies that kdump is active, installs FIO if necessary, then generates I/O with dt. While generating I/O, it triggers a panic. It will then verify that the server reboots properly and that a crash dump was generated.
#   Author: Marco Patalano <mpatalan@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
dbg_flag=${dbg_flag:-"set +x"}
$dbg_flag

# Include Beaker environment
. ../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1


YUM=$(cki_get_yum_tool)

DATE=$(date +"%Y-%m-%d")
crashDir=(/var/crash/127.0.0.1-$DATE-*)

#function to install or start kdump:
kdump_prepare()
{
    rlRun "$YUM -y install kexec-tools"
    k_dump=$(systemctl status kdump.service |grep Active: |awk '{print $2}')
    if [ $k_dump == "active" ]; then
        rlLog "kdump is $k_dump"
    else
        rlLog "kdump is $k_dump - starting kdump service"
        rlRun "systemctl start kdump.service"
    fi
}

#Function to install FIO
function install_fio() {
    rlRun "rpm -q fio || $YUM -y install fio"
}

#Function to generate I/O with FIO
function FIO_Test() {
    EX_USAGE=64 # Bad arg format
    if [ $# -lt 1 ]; then
        echo 'Usage: FIO_Test $test_file'
        exit "${EX_USAGE}"
    fi
    # variable definitions
    local runtime=180
    local numjobs=60
    local test_file="/home/test1G.img"

    rlLog "INFO: Executing FIO_Test() with on: $test_file"

    #fio testing
    rlRun "fio -filename=$test_file -iodepth=1 -thread -rw=write -ioengine=psync -bssplit=5k/10:9k/10:13k/10:17k/10:21k/10:25k/10:29k/10:33k/10:37k/10:41k/10 -direct=1 -runtime=$runtime -time_based -size=1G -group_reporting -name=mytest -numjobs=$numjobs &"
    if [ $? -ne 0 ]; then
        rlLog "FAIL: fio write testing for $test_file failed"
        ret=1
    fi
    return $ret
}

#Function to set next boot if EFI system
PrepareReboot()
{
    # IA-64 needs nextboot set.
    if [ -e "/usr/sbin/efibootmgr" ]; then
        EFI=$(efibootmgr -v | grep BootCurrent | awk '{ print $2}')
        if [ -n "$EFI" ]; then
            rlLog "- Updating efibootmgr next boot option to $EFI according to BootCurrent"
            efibootmgr -n $(efibootmgr -v | grep BootCurrent | awk '{ print $2}')
        elif [[ -z "$EFI" && -f /root/EFI_BOOT_ENTRY.TXT ]] ; then
            os_boot_entry=$(</root/EFI_BOOT_ENTRY.TXT)
            rlLog "- Updating efibootmgr next boot option to $os_boot_entry according to EFI_BOOT_ENTRY.TXT"
            efibootmgr -n $os_boot_entry
        else
            Log "- Could not determine value for BootNext!"
        fi
    fi
}

#Function to clear next boot if on EFI based system
RemoveBootNext()
{
    if [ -e "/usr/sbin/efibootmgr" ]; then
        EFI=$(efibootmgr -v | grep BootNext | awk '{ print $2}')
        if [ -n "$EFI" ]; then
            rlLog "Deleting efibootmgr Boot Next option"
            efibootmgr -N
        else
            rlLog "BootNext not set - continue"
        fi
    fi
}    

#function to trigger panic
trigger_panic()
{
    #First, enable sysrq:
    rlRun -l 'echo "1" > /proc/sys/kernel/sysrq'
    #trigger panic:
    rstrnt-report-result PANIC PASS 0
    rlRun -l "echo c > /proc/sysrq-trigger"
}

#function to load kernel, gracefully shutdown and restart to loaded kernel
kexec_boot_graceful()
{
    rlRun "unr=$(uname -r)"
    rlRun "initrd=/boot/initramfs-$unr.img"
    rlRun "kexec -l /boot/vmlinuz-$unr --initrd=$initrd --reuse-cmdline"
    rlWatchdog "reboot" 600
}

#function to load kernel, then abruptly start the new kernel without issuing a shutdown
kexec_boot_exec()
{
    rlRun "unr=$(uname -r)"
    rlRun "initrd=/boot/initramfs-$unr.img"
    rlRun "kexec -l /boot/vmlinuz-$unr --initrd=$initrd --reuse-cmdline"
    rlRun "kexec -e -d"
}

rlJournalStart
    rlPhaseStartSetup
        echo "REBOOTCOUNT=$REBOOTCOUNT"
        if [ "$REBOOTCOUNT" -eq 0 ] ; then
            install_fio
            PrepareReboot
            kdump_prepare
            sleep 5
            FIO_Test "$device"
            sleep 5
            trigger_panic
        elif [ "$REBOOTCOUNT" -eq 1 ] ; then
            FIO_Test "$device"
            sleep 5
            kexec_boot_graceful
        elif [ "$REBOOTCOUNT" -eq 2 ] ; then
            FIO_Test "$device"
            sleep 5
            kexec_boot_exec
        else
            RemoveBootNext
            echo "Continue to Asserts"
        fi
    rlPhaseEnd

rlPhaseStartTest
    rlAssertEquals "System should reboot successfully" $REBOOTCOUNT 3
    rlAssertExists  "$crashDir/vmcore"
rlPhaseEnd
rlJournalPrintText
rlJournalEnd
