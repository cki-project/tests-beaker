#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/ipmi/stress/ipmitool-loop
#   Description: IPMItool loop stress test 
#   Author: Rachel Sibley <rasibley@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2015 Red Hat, Inc. All rights reserved.
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

# Set the full test name
TEST="/kernel/ipmi/stress/ipmitool-loop"

rlJournalStart
    # Exit if not ipmi compatible
    rlPhaseStartSetup
        if [[ $(uname -m) != "ppc64le" ]]; then
            rlRun -l "dmidecode --type 38 > /tmp/dmidecode.log"
                if grep -i ipmi /tmp/dmidecode.log ; then
                    rlPass "Moving on, host is ipmi compatible"
                else
                    rlLog "Exiting, host is not ipmi compatible"
                    rstrnt-report-result $TEST SKIP
                    exit
                fi
        fi

        # Reload ipmi modules
        modules="ipmi_ssif ipmi_devintf ipmi_poweroff ipmi_watchdog ipmi_si"
        rlRun "modprobe -r $modules" 0,1
        for i in $modules; do
            rlRun -l "modprobe $i" 0,1
        done
    rlPhaseEnd

    rlPhaseStartTest
    # Execute various ipmitool commands in a loop
    for i in $(seq 0 10); do
        if [[ $(uname -m) != "ppc64le"]]; then
            rlRun "ipmitool sel clear"
            rlRun "ipmitool sel list" 0,1
            rlRun "ipmitool chassis selftest"
            rlRun "ipmitool mc selftest"
            rlRun "ipmitool mc getenables"
            rlRun "ipmitool mc guid"
            rlRun "ipmitool mc getenables system_event_log"
        fi
        rlRun "ipmitool chassis status"
        rlRun "ipmitool chassis bootparam"
        rlRun "ipmitool chassis identify"
        rlRun "ipmitool sensor list -v"
        rlRun "ipmitool mc info"
        rlRun "ipmitool sdr"
        rlLogInfo "Loop $i Complete"
    done
    rlPhaseEnd

    # Verify no errors are aseen in the logs
    rlPhaseStartTest
        rlRun "journalctl -b -p err | grep ipmi  > /tmp/error.log" 0,1
        rlRun "cat /tmp/error.log"
        rlAssertNotGrep "error|fail|warn" /tmp/error.log -i
    rlPhaseEnd
rlJournalEnd

# Print the test report
rlJournalPrintText
