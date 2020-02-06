#!/bin/bash
#
# Common helper functions and global variables to be used by all CKI tests
#
# NOTE: To make coding style consistent, conventions in the following should be
#       followed:
#       1) All helper functions start with 'cki_';
#       2) All global variables start with 'CKI_'.
#

source /usr/bin/rhts_environment.sh
source /usr/share/beakerlib/beakerlib.sh

CKI_RC_POS=0
CKI_RC_NEG="1-255"
CKI_RC_ANY="0-255" # To assist rlRun() to support any return code

# Result code definitions
CKI_PASS=0        # should go to rlPass()
CKI_FAIL=1        # should go to rlFail()
CKI_UNSUPPORTED=2 # should go to cki_skip_task()
CKI_UNINITIATED=3 # should go to cki_abort_task()

# Status code definitions
CKI_STATUS_COMPLETED=0 # task is completed
CKI_STATUS_ABORTED=1   # task is aborted

# Wrapper function to write log
function cki_log()
{
    rlLog "$*"
}

#
# When a serious problem occurs and we cannot proceed any further, we abort
# this recipe with an error message.
#
# Arguments:
#   $1 - the message to print in the log
#   $2 - 'WARN' or 'FAIL'
#
function cki_abort_recipe()
{
    typeset failure_message=$1
    typeset failure_type=${2:-"FAIL"}

    echo "❌ ${failure_message}"
    if [[ $failure_type == 'WARN' ]]; then
        report_result ${TEST} WARN 99
    else
        report_result ${TEST} FAIL 1
    fi
    rhts-abort -t recipe
    exit $CKI_STATUS_ABORTED
}

function cki_abort_task()
{
    typeset reason="$*"
    [[ -z $reason ]] && reason="unknown reason"
    cki_log "Aborting current task: $reason"
    rstrnt-abort --server $RSTRNT_RECIPE_URL/tasks/$TASKID/status
    exit $CKI_STATUS_ABORTED
}

function cki_skip_task()
{
    typeset reason="$*"
    [[ -z $reason ]] && reason="unknown reason"
    cki_log "Skipping current task: $reason"
    rhts-report-result "$TEST" SKIP "$OUTPUTFILE"
    exit $CKI_STATUS_COMPLETED
}

function cki_report_result
{
    typeset rc=${1?"*** result code"}
    typeset cleanup=$2
    shift 2
    typeset argv="$*"
    case $rc in
        $CKI_PASS)
            rlPass "$argv"
            ;;
        $CKI_FAIL)
            rlFail "$argv $g_reason_fail"
            ;;
        #
        # NOTE: If a task is aborted or skipped, its cleanup should be done,
        #       or succeeding tasks may be impacted.
        #
        $CKI_UNSUPPORTED)
            if [[ -n $cleanup ]]; then
                cki_log "Now go to cleanup because task is UNSUPPORTED ..."
                eval $cleanup
            fi
            typeset reason=$g_reason_unsupported
            [[ -z $reason ]] && reason="UNKNOWN REASON"
            cki_skip_task "$reason"
            ;;
        $CKI_UNINITIATED)
            if [[ -n $cleanup ]]; then
                cki_log "Now go to cleanup because task is UNINITIATED ..."
                eval $cleanup
            fi
            typeset reason=$g_reason_uninitiated
            [[ -z $reason ]] && reason="UNKNOWN REASON"
            cki_abort_task "$reason"
            ;;
        *)
            cki_abort_task "$g_reason_other #$argv#"
            ;;
    esac
}

#
# Set reason for according to result code, once function cki_report_result() is
# invoked, the related reason will be used when calling cki_log()
#
function cki_set_reason()
{
    typeset rc=${1?"*** result code"}
    shift
    case $rc in
        $CKI_FAIL) g_reason_fail="$@" ;;
        $CKI_UNSUPPORTED) g_reason_unsupported="$@" ;;
        $CKI_UNINITIATED) g_reason_uninitiated="$@" ;;
        *) g_reason_other="$rc is an invalid result code" ;;
    esac
}

function runtest { :; }
function startup { :; }
function cleanup { :; }
function cki_main
{
    typeset hook_runtest=${1:-"runtest"}
    typeset hook_startup=${2:-"startup"}
    typeset hook_cleanup=${3:-"cleanup"}
    typeset -i rc=0

    rlJournalStart

    rlPhaseStartSetup $hook_startup
    $hook_startup
    typeset -i rc1=$?
    cki_log "$hook_startup(): rc=$rc1"
    (( rc += rc1 ))
    cki_report_result $rc1 "$hook_cleanup" "$hook_startup()"
    rlPhaseEnd

    if (( rc == 0 )); then
        typeset tfunc=""
        for tfunc in $(echo $hook_runtest | tr ',' ' '); do
            rlPhaseStartTest $tfunc
            $tfunc
            typeset -i rc2=$?
            cki_log "$tfunc(): rc=$rc2"
            (( rc += rc2 ))
            cki_report_result $rc2 "$hook_cleanup" "$tfunc()"
            rlPhaseEnd
        done
    fi

    rlPhaseStartCleanup $hook_cleanup
    $hook_cleanup
    typeset -i rc3=$?
    cki_log "$hook_cleanup(): rc=$rc3"
    (( rc += rc3 ))
    cki_report_result $rc3 "" "$hook_cleanup()"
    rlPhaseEnd

    cki_log "OVERALL RESULT CODE: $rc"

    rlJournalEnd

    #
    # XXX: Don't return the overall result code (i.e. $rc) but always return 0
    #      (i.e. CKI_STATUS_COMPLETED) to make sure beaker task is not marked
    #      as 'Aborted' if test result is marked as 'Fail'
    #
    return $CKI_STATUS_COMPLETED
}

#
# Wrapper functions to run a single cmd
# o cki_run_cmd_pos(): $? must be 0
# o cki_run_cmd_neg(): $? must be !0
# o cki_run_cmd_neu(): don't care about $?
#
function cki_run_cmd_pos()
{
    typeset cmd="$@"
    (( ${#cmd} > 64 )) && cmd="${cmd:0:63}..."
    typeset msg="[ POS ] run '$cmd', expect to pass"
    rlRun -l "$@" "$CKI_RC_POS" "$msg"
    return $?
}

function cki_run_cmd_neg()
{
    typeset cmd="$@"
    (( ${#cmd} > 64 )) && cmd="${cmd:0:63}..."
    typeset msg="[ NEG ] run '$cmd', expect to fail"
    rlRun -l "$@" "$CKI_RC_NEG" "$msg"
    (( $? == 0 )) && return 1 || return 0
}

function cki_run_cmd_neu()
{
    typeset cmd="$@"
    (( ${#cmd} > 64 )) && cmd="${cmd:0:63}..."
    typeset msg="[ NEU ] run '$cmd', expect nothing"
    rlRun -l "$@" "$CKI_RC_ANY" "$msg"
    return $?
}

# Wrapper function to change working directory
function cki_cd()
{
    rlRun "pushd $(pwd)"
    rlRun "cd $1"
}

# Wrapper function to return to original working directory
function cki_pd()
{
    rlRun "popd"
}

#
# Enable to debug bash script by resetting PS4. If user wants to turn debug
# switch on, just set env DEBUG, e.g.
# $ export DEBUG=yes
#
function cki_debug
{
    typeset -l s=$DEBUG
    if [[ "$s" == "yes" || "$s" == "true" ]]; then
        export PS4='__DEBUG__: [$FUNCNAME@$BASH_SOURCE:$LINENO|$SECONDS]+ '
        set -x
    fi
}

function cki_get_yum_tool()
{
    if [[ -x /usr/bin/dnf ]]; then
        echo /usr/bin/dnf
    elif [[ -x /usr/bin/yum ]]; then
        echo /usr/bin/yum
    else
        echo "No tool to download kernel from a repo" >&2
        rhts-abort -t recipe
        exit 0
    fi
}

# Print an informational message with a friendly emoji.
function cki_print_info()
{
    echo "ℹ️ ${1}"
}

# Print a success message with a friendly emoji.
function cki_print_success()
{
    echo "✅ ${1}"
}

# Print an warning message with a friendly emoji.
function cki_print_warning()
{
    echo "⚠️ ${1}"
}
