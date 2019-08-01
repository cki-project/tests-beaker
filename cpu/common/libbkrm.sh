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

BKRM_RC_ANY="0-255" # To assist rlRun() to support any return code

#
# Result code definitions
#
BKRM_PASS=0        # should go to rlPass()
BKRM_FAIL=1        # should go to rlFail()
BKRM_UNSUPPORTED=2 # should go to rlSkip()
BKRM_UNINITIATED=3 # should go to rlAbort()

#
# Status code definitions
#
BKRM_STATUS_COMPLETED=0 # task is completed
BKRM_STATUS_ABORTED=1   # task is aborted

#
# A simple wrapper function to report result
#
function rlReportResult
{
    typeset rc=${1?"*** result code"}
    shift
    typeset argv="$*"
    case $rc in
        $BKRM_PASS) rlPass $argv ;;
        $BKRM_FAIL) rlFail "$g_reason_fail #$argv#" ;;
        $BKRM_UNSUPPORTED) rlSkip "$g_reason_unsupported #$argv#" ;;
        $BKRM_UNINITIATED) rlAbort "$g_reason_uninitiated #$argv#" ;;
        *) ;;
    esac
}

#
# Set reason for according to result code, once function rlReportResult() is
# invoked, the related reason will be used when calling rlLog()
#
function rlSetReason
{
    typeset rc=${1?"*** result code"}
    shift
    case $rc in
        $BKRM_FAIL) g_reason_fail="$@" ;;
        $BKRM_UNSUPPORTED) g_reason_unsupported="$@" ;;
        $BKRM_UNINITIATED) g_reason_uninitiated="$@" ;;
        *) ;;
    esac
}

#
# A simple wrapper function to skip a test because beakerlib doesn't support
# such an important feature, right here we just leverage 'rhts'. Note we
# don't call function report_result() as it directly invoke command
# rhts-report-result actually
#
function rlSkip
{
    rlLog "Skipping test because $*"
    #
    # XXX: Result will be marked as "Warn" although we use word "SKIP"
    #      because of beaker's implementation
    #
    rhts-report-result "$TEST" SKIP "$OUTPUTFILE"
    exit $BKRM_STATUS_COMPLETED
}

#
# A simple wrapper function to abort a test
#
function rlAbort
{
    rlLog "Aborting test because $*"
    #
    # XXX: Result will be marked as "Warn" although we use word "ABORTED"
    #      because of beaker's implementation
    #
    rhts-report-result "$TEST" ABORTED "$OUTPUTFILE"
    exit $BKRM_STATUS_ABORTED
}

#
# A simple wrapper function to change working directory
#
function rlCd
{
    rlRun "pushd $(pwd)"
    rlRun "cd $1"
}

#
# A simple wrapper function to return to original working directory
#
function rlPd
{
    rlRun "popd"
}

#
# A simple wrapper function to invoke startup(), runtest() and cleanup()
#
function main
{
    typeset hook_runtest=${1:-"runtest"}
    typeset hook_startup=${2:-"startup"}
    typeset hook_cleanup=${3:-"cleanup"}
    typeset -i rc=0

    rlJournalStart

    rlPhaseStartSetup
    $hook_startup
    typeset -i rc1=$?
    (( rc += rc1 ))
    rlReportResult $rc1 "$hook_startup()"
    rlPhaseEnd

    if (( rc == 0 )); then
        rlPhaseStartTest
        $hook_runtest
        typeset -i rc2=$?
        (( rc += rc2 ))
        rlReportResult $rc2 "$hook_runtest()"
        rlPhaseEnd
    fi

    rlPhaseStartCleanup
    $hook_cleanup
    typeset -i rc3=$?
    (( rc += rc3 ))
    rlReportResult $rc3 "$hook_cleanup()"
    rlPhaseEnd

    rlLog "OVERALL RESULT CODE: $rc"

    rlJournalEnd

    rlJournalPrintText

    #
    # XXX: Don't return the overall result code (i.e. $rc) but always return 0
    #      (i.e. BKRM_STATUS_COMPLETED) to make sure beaker task is not marked
    #      as 'Aborted' if test result is marked as 'Fail'
    #
    return $BKRM_STATUS_COMPLETED
}
