#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/distribution/ltp/include
#   Description: Linux Test Project - include part
#   Author: Caspar Zhang <czhang@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
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

# Source the common test script helpers
. /usr/bin/rhts_environment.sh

# Set unique log file.
OUTPUTDIR=/mnt/testarea
if ! [ -d $OUTPUTDIR ]; then
    echo "Creating $OUTPUTDIR"
    mkdir -p $OUTPUTDIR
fi
LTPDIR=$OUTPUTDIR/ltp
OPTS=""

# Helper functions

# control where to log debug messages to:
# devnull = 1 : log to /dev/null
# devnull = 0 : log to file specified in ${DEBUGLOG}
devnull=0

# Create debug log.
DEBUGLOG=`mktemp -p /mnt/testarea -t DeBug.XXXXXX`

# locking to avoid races
lck=$OUTPUTDIR/$(basename $0).lck

if [ -z ${ARCH} ]; then
    ARCH=$(uname -i)
fi

if grep -q "release 4" /etc/redhat-release; then
    RHEL4=1
fi

# by jstancek
check_cpu_cgroup ()
{
    # Move us to root cpu cgroup
    # see: Bug 773259 - tests don't run in root cpu cgroup with systemd

    if [ -e /proc/self/cgroup ]; then
        grep -i "cpu[,:]" /proc/self/cgroup | grep -q ":/$"
        ret=$?
    else
        echo "Couldn't find /proc/self/cgroup." | tee -a $OUTPUTFILE
        ret=1
    fi

    if [ $ret -eq 0 ]; then
        echo "Running in root cpu cgroup" | tee -a $OUTPUTFILE
    else
        echo "cat /proc/self/cgroup" | tee -a $OUTPUTFILE
        cat /proc/self/cgroup | tee -a $OUTPUTFILE
        cpu_cgroup_mntpoint=$(mount | grep "type cgroup (.*cpu[,)]" | awk '{print $3}')
        if [ -e "$cpu_cgroup_mntpoint/tasks" ]; then
            echo "Found root cpu cgroup tasks at: $cpu_cgroup_mntpoint/tasks" | tee -a $OUTPUTFILE
            echo $$ > $cpu_cgroup_mntpoint/tasks
            ret=$?
            if [ $ret -eq 0 ]; then
                echo "Succesfully moved (pid: $$) to root cpu cgroup." | tee -a $OUTPUTFILE
            else
                echo "Failed to move (pid: $$), ret code: $ret" | tee -a $OUTPUTFILE
            fi
        fi

        if [ $ret -ne 0 ]; then
            echo "Couldn't verify that we run in root cpu cgroup." | tee -a $OUTPUTFILE
            echo "Note that some tests (on RHEL7) may fail, see Bug 773259." | tee -a $OUTPUTFILE
        fi
    fi
}
check_cpu_cgroup

# Log a message to the ${DEBUGLOG} or to /dev/null.
DeBug ()
{
    local msg="$1"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    if [ "$devnull" = "0" ]; then
        lockfile -r 1 $lck
        if [ "$?" = "0" ]; then
            echo -n "${timestamp}: " >>$DEBUGLOG 2>&1
            echo "${msg}" >>$DEBUGLOG 2>&1
            rm -f $lck >/dev/null 2>&1
        fi
    else
        echo "${msg}" >/dev/null 2>&1
    fi
}

DebugInfo ()
{
    DeBug "******* Requested Information $1 *******"
    DeBug "** IPCS Information **"
    /usr/bin/ipcs -a >> $DEBUGLOG
    DeBug "** msgmni Information **"
    cat /proc/sys/kernel/msgmni >> $DEBUGLOG
    DeBug "******* End Requested Information $1 *******"

    # Just for easy reading
    echo >> $DEBUGLOG
    if [ "$1" = "After" ] || [ "$1" = "AfterIPCRMCleanUp" ]; then
        echo >> $DEBUGLOG
    fi

}

RprtRslt ()
{
    TEST=$1
    result=$2

    # File the results in the database
    if [ "$result" = "PASS" ]; then
        # I want to see the succeeded running log as well
        SubmitLog "$OUTPUTDIR/$TEST.run.log"
        rstrnt-report-result $TEST $result
    else
        SubmitLog "$OUTPUTDIR/$TEST.run.log"
        score=$(cat $OUTPUTDIR/$RUNTEST.log | grep "Total Failures:" |cut -d ' ' -f 3)
        rstrnt-report-result $TEST $result $score
    fi
}

SubmitLog ()
{
    LOG=$1

    rhts_submit_log -S $RESULT_SERVER -T $TESTID -l $LOG
}

CleanUp ()
{
    LOGFILE=$1

    if [ -e $OUTPUTDIR/$LOGFILE.run.log ]; then
        rm -f $OUTPUTDIR/$LOGFILE.run.log
    fi

    if [ -e $OUTPUTDIR/$LOGFILE.log ]; then
        rm -f $OUTPUTDIR/$LOGFILE.log
    fi
}

IPCRMCleanup ()
{
    # Clean up msgid
    DeBug "******* Start msgmni cleanup $1 *******"
    for i in `ipcs -q | cut -f2 -d' '`; do
        ipcrm -q $i
    done
    DeBug "******* End msgmni cleanup $1 *******"
    echo >> $DEBUGLOG
}

ChkTime ()
{
    local timestamp=$(date '+%F %T')
    logger -p local0.notice -t TEST.INFO: "$timestamp -> $1"
}

TimeSyncNTP ()
{
    local timestamp=$(date '+%F %T')
    logger -p local0.notice -t TEST.INFO: \
        "$timestamp -> Sync time with clock.redhat.com"

    if [ "$RHEL4" ]; then
        # Avoid AVC denial in RHEL 4.
        # Required policy modification,
        # allow ntpd_t initrc_tmp_t:file append;
        runcon -u root -r system_r -t initrc_t -- \
            ntpdate clock.redhat.com
    else
        ntpdate clock.redhat.com
    fi
}

EnableNTP ()
{
    local timestamp=$(date '+%F %T')
    logger -p local0.notice -t TEST.INFO: "$timestamp -> Enable NTP"
    service ntpd start
}

DisableNTP ()
{
    local timestamp=$(date '+%F %T')
    logger -p local0.notice -t TEST.INFO: "$timestamp -> Disable NTP"
    service ntpd stop
}

EnableKsmd ()
{
    local timestamp=$(date '+%F %T')
    logger -p local0.notice -t TEST.INFO: "$timestamp -> Enable ksmd and ksmtuned"
    service ksm start
    service ksmtuned start
}

DisableKsmd ()
{
    local timestamp=$(date '+%F %T')
    logger -p local0.notice -t TEST.INFO: "$timestamp -> Disable ksmd and ksmtuned"
    service ksm stop
    service ksmtuned stop
}

# Workaround for Bug 1263712 - OOM is sporadically killing more than just expected process
ProtectHarnessFromOOM ()
{
    for pid in $(pgrep beah) $(pgrep rhts) $(pgrep ltp) $(pgrep dhclient) $(pgrep NetworkManager); do
        echo -16 > /proc/$pid/oom_adj
    done

    # make sure children of this process are not protected
    # as those include also OOM tests
    echo 0 > /proc/self/oom_adj
}

# Modify the $RUNTEST.log for eassier identifying KnownIssue case
LogDeceiver ()
{
    if ! [ -f ${LTPDIR}/KNOWNISSUE ]; then
        return
    fi

    for k in $(cat ${LTPDIR}/KNOWNISSUE | grep -v '^#'); do
        sed -i '/'$k'/ s/FAIL/KNOW/' $OUTPUTDIR/$RUNTEST.log
    done
}

RunTest ()
{
    RUNTEST=$1
    OPTIONS=$2 # pass other options here, like "-b /dev/sda5 -B xfs"

    ProtectHarnessFromOOM

    # disable AVC check only in CGROUP tests
    if echo $RUNTEST | grep -q CGROUP; then
        export AVC_ERROR='+no_avc_check'
    fi

    ChkTime $RUNTEST

    # Default result to Fail
    export result_r="FAIL"

    # Sync the time with the time server. Tests may change the time
    TimeSyncNTP

    if [ -n "$FILTERTESTS" ]; then
        FILTERTESTS="$(echo $FILTERTESTS | sed 's/\w\+/-e &/g')"
        time -p ${LTPDIR}/runltp -p -d $OUTPUTDIR -l $OUTPUTDIR/$RUNTEST.log \
            -o $OUTPUTDIR/$RUNTEST.run.log $OPTIONS -s "$FILTERTESTS"
    else
        DebugInfo Before
        DeBug "Command Line:"
        DeBug "${LTPDIR}/runltp -p -d $OUTPUTDIR -l $OUTPUTDIR/$RUNTEST.log \
            -o $OUTPUTDIR/$RUNTEST.run.log -f $RUNTEST $OPTIONS"
        time -p ${LTPDIR}/runltp -p -d $OUTPUTDIR -l $OUTPUTDIR/$RUNTEST.log \
            -o $OUTPUTDIR/$RUNTEST.run.log -f $RUNTEST $OPTIONS
    fi

    DebugInfo After
    if [ $RUNTEST = "ipc" ]; then
        IPCRMCleanup
        DebugInfo AfterIPCRMCleanup
    fi

    LogDeceiver

    if ! [ -e $OUTPUTDIR/$RUNTEST.log ] || grep -q FAIL $OUTPUTDIR/$RUNTEST.log; then
        echo "$RUNTEST Failed: " | tee -a $OUTPUTFILE
        result_r="FAIL"
    else
        echo "$RUNTEST Passed: " | tee -a $OUTPUTFILE
        result_r="PASS"
    fi

    cat $OUTPUTDIR/$RUNTEST.log >> $OUTPUTFILE
    echo Test End Time: `date` >> $OUTPUTFILE

    # If REPORT_FAILED_RESULT set to "yes", report every failed test to beaker
    # so that it's easier to see which tests failed.
    if [ "$REPORT_FAILED_RESULT" == "yes" -a "$result_r" == "FAIL" ]; then
        while read test res ret; do
            if [ "$res" != "FAIL" ]; then
                continue
            fi
            RprtRslt $RUNTEST/$test $res $ret
        done < $OUTPUTDIR/$RUNTEST.log
    fi
    RprtRslt $RUNTEST $result_r

    # Restore AVC check
    if echo $RUNTEST | grep -q CGROUP; then
        export AVC_ERROR=''
    fi
}

RunFiltTest ()
{
    if [ -n "$FILTERTESTS" ]; then
        rm -f $OUTPUTDIR/filtered_runtest.log
        rm -f $OUTPUTDIR/filtered_runtest.run.log

        RunTest filtered_runtest "$OPTS"
        return 0
    fi

    return 1
}
