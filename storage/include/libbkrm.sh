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

source /usr/bin/rhts_environment.sh
source /usr/share/beakerlib/beakerlib.sh

#
# A simple wrapper function to skip a test because beakerlib doesn't support
# such an important feature, right here we just leverage 'rhts'. Note we
# don't call function report_result() as it directly invoke command
# rhts-report-result actually
#
function rlSkip
{
    rlLog "Skipping test because $*"
    rhts-report-result "$TEST" SKIP "$OUTPUTFILE"

    #
    # As we want result="Skip" status="Completed" for all scenarios, right here
    # we always exit 0, otherwise the test will skip/abort
    #
    exit 0
}

#
# A simple wrapper function to skip a test
#
function rlAbort
{
    rlLog "Aborting test because $*"
    rhts-report-result "$TEST" ABORTED "$OUTPUTFILE"
    rhts-abort -t recipe
    exit 1
}

function tc_hook_init
{
    g_startup_hook=${1?"*** startup hook, e.g. startup"}
    g_cleanup_hook=${2?"*** cleanup hook, e.g. cleanup"}
    g_runtest_hook=${3?"*** runtest hook, e.g. runtest"}
}

function tc_hook_fini
{
    unset g_startup_hook
    unset g_cleanup_hook
    unset g_runtest_hook
}

function _startup
{
    rlPhaseStartSetup
    [[ -n $g_startup_hook ]] && eval $g_startup_hook
    rlPhaseEnd
}

function _cleanup
{
    rlPhaseStartCleanup
    [[ -n $g_cleanup_hook ]] && eval $g_cleanup_hook
    rlPhaseEnd
}

function _runtest
{
    rlPhaseStartTest
    [[ -n $g_runtest_hook ]] && eval $g_runtest_hook
    rlPhaseEnd
}

function tc_main
{
    rlJournalStart
    _startup
    _runtest
    _cleanup
    rlJournalEnd
}
