#!/bin/bash

# Kernel Testing Include File:
#  This include file contains common variables and
#  functions for "KT1" and "Secondary" kernel testing tasks.

#
# Variables
#
# control where to log debug messages to:
# devnull = 1 : log to /dev/null
# devnull = 0 : log to file specified in ${DEBUGLOG}
devnull=0

# Create debug log
DEBUGLOG=`mktemp -p /mnt/testarea -t DeBug.XXXXXX`
K_DEBUGLOG=`mktemp -p /mnt/testarea -t K_DeBug.XXXXXX`

# In the event your not running automated Beaker job
if [ -z "$OUTPUTFILE" ]; then
    echo ""
    echo "***** \$OUTPUTFILE is not defined *****"
    echo "*****  This is generally do to a *****"
    echo "*****    manual testing setup    *****"
    echo "*****   Creating: \$OUTPUTFILE    *****"
    echo ""
    export OUTPUTFILE=`mktemp /mnt/testarea/tmp.XXXXXX`
fi
# ToDo: $RESULT_SERVER $TESTID also need workaround

OUTPUTDIR=/mnt/testarea
if [ ! -d "$OUTPUTDIR" ]; then

    echo ""
    echo "***** OUTPUTDIR is not defined  *****"
    echo "*****   Creating: $OUTPUTDIR    *****"
    echo ""
    mkdir -p $OUTPUTDIR
fi

# locking to avoid races
lck=$OUTPUTDIR/$(basename $0).lck
K_LCK=$OUTPUTDIR/$(basename $0).lck

TESTAREA="/mnt/testarea"
K_TESTAREA="/mnt/testarea"
TEST_VER=$(rpm -qf $0)
K_TEST_VER=$(rpm -qf $0)

# Kernel Variables
K_NAME=`rpm -q --queryformat '%{name}\n' -qf /boot/config-$(uname -r)`
#   example output: kernel
K_VER=`rpm -q --queryformat '%{version}\n' -qf /boot/config-$(uname -r)`
#   example output: 2.6.32
K_VARIANT=$(echo $K_NAME | sed -e "s/kernel//g")
#   are we a DEBUG kernel?
K_REL=`rpm -q --queryformat '%{release}\n' -qf /boot/config-$(uname -r)`
#   example output: 220.el6
K_SRC=`rpm -q --queryformat '%{sourcerpm}\n' -qf /boot/config-$(uname -r)`
#   example output: kernel-2.6.32-220.el6.src.rpm
K_BASE=`rpm -q --queryformat '%{name}-%{version}-%{release}.%{arch}\n' -qf /boot/config-$(uname -r)`
#   example output: kernel-2.6.32-220.el6.x86_64
K_ARCH=$(rpm -q --queryformat '%{arch}' -f /boot/config-$(uname -r))
#   example output: x86_64
#   example output: armv7hl
#   example output: armv7l
K_RUNNING=$(uname -r)
#   example output: 2.6.32-220.el6.x86_64
#   We removed the dot between release and variant because kernels built
#   under rhel5 did not include this dot and will make comparing difficult.
#   Release and variant on fedora kernels can use also + sign,
#   example input: 3.15.0-0.rc5.git0.1.el7.x86_64+debug
K_RUNNING_VR=$(uname -r | sed -e "s/\.${K_ARCH}[.+]*//")
#   example output: 3.6.10-8.fc18highbank
K_DOWNLOAD="http://download.lab.bos.redhat.com/brewroot/packages/kernel/"
#
RH_REL=`cat /etc/redhat-release | cut -d" " -f7`
#   example output: 6.2
K_CONFIG="kernel-$K_VER-$K_ARCH$K_VARIANT.config"
#   example output: kernel-2.6.32-x86_64.config

# This is a little cryptic, in practice it takes the full src rpm file
# name and strips everytihng after (including) the version, leaving just
# the src rpm package name.
# Needed when the kernel rpm comes from of e.g. kernel-pegas src rpm.
K_SPEC_NAME=${K_SRC%%-${K_VER}*}

#
# Functions
#
# Log a message to the ${DEBUGLOG} or to /dev/null
function DeBug ()
{
    local msg=$1
    local timestamp=$(date '+%F %T')
    if [ "$devnull" = "0" ]; then
        (
            flock -x 200 2>/dev/null
            echo -n "${timestamp}: " >> $DEBUGLOG 2>&1
            echo "${msg}" >> $DEBUGLOG 2>&1
        )   200>$lck
    else
        echo "${msg}" > /dev/null 2>&1
    fi
}

function RprtRslt ()
{
    echo "" | tee -a $OUTPUTFILE
    echo "***** End of runtest.sh *****" | tee -a $OUTPUTFILE

    local task=$1

    # Default result to FAIL
    local result="FAIL"

    # score of 0 is PASS. score of 99 is PASS, as test is skipped
    # If no score is given, default to fail and count the reported fails
    # Then post-process the results to find the regressions
    if [ -z "$2" ]; then
      local score=`cat $OUTPUTFILE | grep "FAILED: " | wc -l`
    else
      local score=$2
    fi

    if [ ! -s "$OUTPUTFILE" ]; then
        local result="FAIL"
    else
        if [ "$score" -eq "0" ] || [ "$score" -eq "99" ]; then
            local result="PASS"
        else
            local result="FAIL"
        fi
    fi

    # File the results in the database
    report_result $task $result $score
    SubmitLog $DEBUGLOG
    exit 0
}

function SubmitLog ()
{
    local log=$1
    rstrnt-report-log -S $RESULT_SERVER -T $TESTID -l $log
}

function EstatusReport ()
{

    if [ "$?" -ne "0" ]; then
        local report=$1
        local concern=$2

        ReportStatus "$report" "$concern"
    fi
}

function EstatusFail ()
{

    if [ "$?" -ne "0" ]; then
        local problem=$1

        DisplayFailandBail "$problem"
    fi
}

function DisplayFailandBail ()
{
    # Display the fail in a informative format and feed RprtRslt

    local issue=$1

    DeBug "Failed: $issue"
    echo  "***** FAILED: $issue *****" | tee -a $OUTPUTFILE

    RprtRslt
}

function ReportStatus ()
{
    # Report test status
    # $3 is optional and enhances functionality

    local status=$1
    local message=$2

    DeBug "$status: $message"
    echo  "***** $status: $message *****" | tee -a $OUTPUTFILE

    # If $3 is provided, report_result and continue testing
    if [ ! -z "$3" ]; then
        local string=/$3

        # Default to FAIL
        if [ "$status" = "Passed" ]; then
            local result="PASS"
        else
            local result="FAIL"
        fi

        # Then file the results in the database
        report_result ${TEST}${string} $result
    fi
}

######################################################
# Below is a copy of the functions using new
# naming scheme: K_FunctionName
# If accepted tasks using kernel/include will
# be updated and old function names removed.


# REBOOTCOUNT is a Beaker env variable set equal to 0
# Any test that reboots by design needs a workaround
# Suggestion: define ExpectedRebootCount in test
# then we can update this function to check variables
function K_CheckRebootCount ()
{
    if [ -n "$REBOOTCOUNT" ]; then
        if [ "$REBOOTCOUNT" -gt "0" ]; then
            echo "" | tee -a $OUTPUTFILE
            echo "***** System rebooted *****" | tee -a $OUTPUTFILE
            echo "***** Check logs for oops or panic *****" | tee -a $OUTPUTFILE
            echo "***** End of runtest.sh *****" | tee -a $OUTPUTFILE
            report_result "system_rebooted" "WARN"
            K_SubmitLog "$K_DEBUGLOG"
            exit 0
        fi
    fi
}

# This is a temporary function.
# ToDo: PBunyan needs modify a few tests to use new function name scheme
function checkRebootCount ()
{
    K_CheckRebootCount
}

function K_DeBug ()
{
    local msg="$1"
    local timestamp="$(date '+%F %T')"

    if [ "$devnull" = "0" ]; then
        (
            flock -x 200 2>/dev/null
            echo -n "${timestamp}: " >> $K_DEBUGLOG 2>&1
            echo "${msg}" >> $K_DEBUGLOG 2>&1
        )   200>$K_LCK
    else
        echo "${msg}" > /dev/null 2>&1
    fi
}

function K_SubmitLog ()
{
    local log="$1"

    rstrnt-report-log -S "$RESULT_SERVER" -T "$TESTID" -l "$log"
}

function K_ReportResult ()
{
    local task="$1"

    # Default result to FAIL
    local result="FAIL"

    echo "" | tee -a $OUTPUTFILE
    echo "***** End of runtest.sh *****" | tee -a $OUTPUTFILE

    # score of 0 is PASS. score of 99 is PASS, as test is skipped
    # If no score is given, default to fail and count the reported fails
    # Then post-process the results to find the regressions
    if [ -z "$2" ]; then
        local score=`cat $OUTPUTFILE | grep "FAILED: " | wc -l`
    else
        local score="$2"
    fi

    if [ ! -s "$OUTPUTFILE" ]; then
        local result="FAIL"
    else
        if [ "$score" -eq "0" ] || [ "$score" -eq "99" ]; then
            local result="PASS"
        else
            local result="FAIL"
        fi
    fi

    # File the results in the database
    report_result "$task" "$result" "$score"
    K_SubmitLog "$K_DEBUGLOG"
    exit 0
}

function K_ReportStatus ()
{
    # Report test status
    # $3 is optional, as its inclusion triggers report_result

    local status="$1"
    local message="$2"

    K_DeBug " $status: $message"
    echo "***** $status: $message *****" | tee -a $OUTPUTFILE

    # If $3 is provided, report_result and continue testing
    if [ ! -z "$3" ]; then
        local task=/"$3"

        # Default result to FAIL
        case $status in
        Passed)
            local result="PASS"
        ;;
        Warn)
            local result="WARN"
        ;;
        *)
            local result="FAIL"
        ;;
        esac

        # Then file the results in the database
        report_result "${TEST}${task}" "$result"
    fi
}

function K_EchoAll ()
{
    # echo an entry for debugging
    # echo output

    local text="$1"

    K_DeBug " $text"
    echo "***** $text *****" | tee -a $OUTPUTFILE
}

function K_ReportFailandBail ()
{
    # Display the fail in a informative format and feed K_ReportResult

    local issue="$1"
    local task="$2"

    K_DeBug " FAILED: $issue"
    echo "***** FAILED: $issue *****" | tee -a $OUTPUTFILE

    K_ReportResult "$task"
}

function K_EstatusFail ()
{
    # Check the exit status
    # If command fails, report the issue and exit the test

    if [ "$?" -ne "0" ]; then
        local issue="$1"
        local task="$2"

        K_ReportFailandBail "$issue" "$task"
    fi
}

function K_EstatusWarn ()
{
    # Check the exit status
    # If command fails, report Warn and continue testing

    if [ "$?" -ne "0" ]; then
        local concern="$1"
        local task="$2"
        local report="Warn"

        K_ReportStatus "$report" "$concern" "$task"
    fi
}

# K_Vercmp() returns one of the following values in the global K_KVERCMP_RET:
#   -1 if kernel version from argument $1 is older
#    0 if kernel version from argument $1 is the same as $2
#    1 if kernel version from argument $1 is newer
K_KVERCMP_RET=0
function K_Vercmp ()
{
    local ver1=`echo $1 | sed 's/-/./'`
    local ver2=`echo $2 | sed 's/-/./'`

    local ret=0
    local i=1
    while [ 1 ]; do
        local digit1=`echo $ver1 | cut -d . -f $i`
        local digit2=`echo $ver2 | cut -d . -f $i`

        if [ -z "$digit1" ]; then
            if [ -z "$digit2" ]; then
                ret=0
                break
            else
                ret=-1
                break
            fi
        fi

        if [ -z "$digit2" ]; then
            ret=1
            break
        fi

        if [ "$digit1" != "$digit2" ]; then
            if [ "$digit1" -lt "$digit2" ]; then
               ret=-1
               break
            fi
            ret=1
            break
        fi

        i=$((i+1))
    done
    K_KVERCMP_RET=$ret
}
function K_VercmpTest ()
{
    K_Vercmp '2.6.32-100.el6' '2.6.32-100.el6'
    K_Vercmp '2.6.32-100.el6' '2.6.32-101.el6'
    K_Vercmp '2.6.32-101.el6' '2.6.32-100.el6'
    K_Vercmp '2.6.32-101.el6' '3.1.4-0.2.el7.x86_64'
    K_Vercmp '3.1.4-0.2.el7.x86_64' `uname -r`
    K_Vercmp `uname -r` '3.1.4-0.1.el7.x86_64'
}

# EndFile
