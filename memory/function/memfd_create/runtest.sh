#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/tmp/Regression/shudemo
#   Description: my lnl
#   Author: Shu Wang <shuwang@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc.
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

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1
. ../../../cki_lib/libcki.sh || exit 1

gcc t_memfd_create.c -o t_memfd_create &&
gcc t_get_seals.c -o t_get_seals
if [ $? != 0 ]; then
    rlLog "memfd_create is not supported."
    rstrnt-report-result $TEST SKIP
    exit
fi

function sanity_memfd_create()
{
    rlRun "./t_memfd_create memf 1024 gswS &"
    rlRun "./t_get_seals /proc/$!/fd/3 > seals"
    rlRun "cat ./seals"
    rlAssertGrep "SEAL GROW WRITE SHRINK" ./seals
    rlRun "pkill t_memfd_create"
}


rlJournalStart
    rlPhaseStartTest "sanity"
        sanity_memfd_create
    rlPhaseEnd
rlJournalEnd
rlJournalPrintText
