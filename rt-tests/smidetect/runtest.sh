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
        rstrnt-report-result $TEST $result 1
    fi
}

DURATION=${DURATION:-10m}

function RunTest ()
{
    # Default result to Fail
    export result_r="FAIL"

    echo Test Start Time: `date` | tee -a $OUTPUTFILE

    hwlatdetect \
        --duration=$DURATION \
        --window=1s --width=500ms \
        --threshold=10us --hardlimit=200us \
        --debug | tee -a $OUTPUTFILE

    if [ $? -ne 0 ] ; then
        echo "smidetect Failed: " | tee -a $OUTPUTFILE
        result_r="FAIL"
    else
        echo "smidetect Passed: " | tee -a $OUTPUTFILE
        result_r="PASS"
    fi

    echo Test End Time: `date` | tee -a $OUTPUTFILE
    RprtRslt $result_r
}

# ---------- Start Test -------------
rt_env_setup
RunTest
exit 0
