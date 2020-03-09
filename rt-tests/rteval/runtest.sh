#!/bin/bash

# Source rt common functions
. ../include/runtest.sh

function RprtRslt ()
{
    result=$1

    # File the results in the database
    if [ $result = "PASS" ]; then
        rstrnt-report-result $TEST $result 0
    else
        if [ $result = "WARN" ]; then
            rstrnt-report-result $TEST $result 2
        else
            rstrnt-report-result $TEST $result 1
        fi
    fi
}

NOXMLRPC=${NOXMLRPC:-1}
DURATION=${DURATION:-900}

function RunTest ()
{
    # Default result to Fail
    export result_r="FAIL"

    echo Test Start Time: `date` | tee -a $OUTPUTFILE

    RTREPORTSRV=${RTREPORTSRV:-rtserver.farm.hsv.redhat.com}

    if [ "$NOXMLRPC" != "1" ]; then
        XMLRPCARGS="--xmlrpc-submit=$RTREPORTSRV"
        echo "-- INFO -- XML-RPC report server: $RTREPORTSRV"
    else
        echo "-- INFO -- No XML-RPC reporting will be done (NOXMLRPC parameter used)"
        XMLRPCARGS=""
    fi

    echo "-- INFO -- Default run time: $DURATION seconds"

    echo "-- INFO -- Mounting debugfs to/sys/kernel/debug "
    mount -t debugfs none /sys/kernel/debug

    echo "-- INFO -- Using command line: rteval $XMLRPCARGS --duration=$DURATION"

    # Lets rock'n'roll
    rteval $XMLRPCARGS --duration=$DURATION | tee -a $OUTPUTFILE
    retcode="$?"

    for rep in $(find -type f -name "rteval-????????-*.tar.bz2"); do
        echo "-- INFO -- Attaching report: $rep"
        rstrnt-report-log -l $rep
    done

    if [ ${retcode} -eq 0 ] ; then
        echo "rteval Passed: " | tee -a $OUTPUTFILE
        result_r="PASS"
    else
        if [ ${retcode} -eq 2 ] ; then
            echo "rteval Passed: " | tee -a $OUTPUTFILE
            echo "xmlrpc Failed: " | tee -a $OUTPUTFILE
            result_r="WARN"
        else
            echo "rteval Failed: " | tee -a $OUTPUTFILE
            result_r="FAIL"
        fi
    fi

    echo Test End Time: `date` | tee -a $OUTPUTFILE
    RprtRslt $result_r
}

# ---------- Start Test -------------
rt_env_setup
RunTest
exit 0
