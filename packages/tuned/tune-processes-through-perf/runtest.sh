#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/tuned/Sanity/tune-processes-through-perf
#   Description: Test if we can tune new process via perf
#   Author: Branislav Blaskovic <bblaskov@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2015 Red Hat, Inc.
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
. ../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1
. ../basic/lib.sh || exit 1

PACKAGE="tuned"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlServiceStart "tuned"
        tunedProfileBackup

        rlFileBackup "/usr/lib/tuned/balanced/tuned.conf"

        rlRun "cp test-tuned-perf /usr/bin/test-tuned-perf"

# Format is: <groupname>:<sched>:<prio>:affinity:<regex>
# group.GROUPNAME=RULE_PRIO:SCHED:PRIO:AFFINITY:REGEX
# SCHED must be one of:
#   'f' for FIFO,
#   'b' for batch,
#   'r' for round robin,
#   'o' for other,
#   '*' means not to change.
# AFFINITY is a hex number, see taskset(1) for details about number of CPUs. The '*' means not to change.
# REGEX is Python regex. It must match against output of
# ps -eo cmd

        echo "
[scheduler]
group.my=0:r:1:*:^sleep 33m$

" >> /usr/lib/tuned/balanced/tuned.conf
        rlRun "cat /usr/lib/tuned/balanced/tuned.conf"

        rlRun "systemctl restart tuned"
        rlRun "tuned-adm profile balanced"
        sleep 5

    rlPhaseEnd

    rlPhaseStartTest
        rlLog "Run 'test' script in background"
        sleep 33m &
        test_pid=$!
        rlLog "PID of 'test' is $test_pid"
        rlRun "ps -eo cmd | grep sleep"
        sleep 5
        rlRun "chrt -p $test_pid"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "kill $test_pid"
        rlFileRestore
        tunedProfileRestore
        rlServiceRestore "tuned"
        rlRun "rm /usr/bin/test-tuned-perf"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
