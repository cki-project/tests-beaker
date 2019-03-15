#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/iotop/Sanity/basic-functionality
#   Description: verifies that iotop can detect heavy disk load simulated by dd
#   Author: Ales Zelinka <azelinka@redhat.com>
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

# Include rhts environment
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh

PACKAGE="iotop"

rlJournalStart
rlPhaseStartTest
    rlAssertRpm $PACKAGE
    rlLog "running io load generation sscript"
    ./loadgen &
    LOADGEN_PID=$!
    echo "pid: $LOADGEN_PID"
    rlLog "running iotop in batch mode fro a while..."
    LOGFILE=`mktemp`
    iotop -b -o  |tee - $LOGFILE &
    IOTOP_PID=$!
    sleep 10
    rlRun "grep tmp-iotop $LOGFILE" 0 "load generation process found in iotop logs"
    rlRun "kill $LOADGEN_PID" 0 "stopping load generation script"
    rlRun "kill $IOTOP_PID" 0 "stopping iotop"
rlPhaseEnd
rlJournalPrintText
rlJournalEnd
