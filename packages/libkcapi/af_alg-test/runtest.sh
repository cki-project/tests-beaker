#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc.
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

. /usr/share/beakerlib/beakerlib.sh

GIT_URL="https://github.com/smuellerDD/libkcapi"
GIT_REF="v1.2.0"

rlJournalStart
    rlPhaseStartSetup
        rlRun "git clone '$GIT_URL' libkcapi"
        rlRun "(cd libkcapi && git checkout $GIT_REF)"
        rlRun "(cd libkcapi && autoreconf -i)"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "sed -i 's/^exec_test$/exec_test; exit \$?/' libkcapi/test/test-invocation.sh" 0 \
            "Skip the compilation and 32-bit tests"
        # NOTE: we could enable the fuzz tests with ENABLE_FUZZ_TEST=1, but
        # they take a veeeery long time to run and so far I haven't seen
        # them actually uncover a bug... Let's just keep them off for now.
        rlRun "./libkcapi/test/test-invocation.sh"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -rf libkcapi"
        rlFileSubmit "/proc/crypto" "proc-crypto.txt"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
