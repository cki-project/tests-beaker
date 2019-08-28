#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/ipmi/stress/driver
#   Description: IPMI driver installation loop
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
TEST="/kernel/ipmi/stress/driver"

rlJournalStart
    # Exit if not ipmi compatible
    rlPhaseStartSetup
        rlRun -l "dmidecode --type 38 > /tmp/dmidecode.log"
            if grep -i ipmi /tmp/dmidecode.log ; then
                rlPass "Moving on, host is ipmi compatible"
            else
		rlLog "Exiting, host is not ipmi compatible"
                rhts-report-result $TEST SKIP
                exit
            fi
    rlPhaseEnd

 rlPhaseStartTest
        # Load and unload ipmi drivers in a loop
    	modules="ipmi_ssif ipmi_devintf ipmi_poweroff ipmi_watchdog ipmi_si"
        rlRun -l "modprobe -r $modules"
        for i in $(seq 0 10); do
            for i in $modules; do
                rlRun -l "modprobe $i"
                rlRun -l "lsmod | grep ipmi"
            done
            rlRun -l "modprobe -r $modules"
            rlLogInfo "Loop $i Complete"
        done
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
