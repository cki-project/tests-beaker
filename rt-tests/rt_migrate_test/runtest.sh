#!/bin/bash

# Source rt common functions
. ../include/runtest.sh

function RprtRslt ()
{
    test_item=$1
    result=$2

    # File the results in the database
    if [ $result = "PASS" ]; then
	    rstrnt-report-result $test_item $result 0
    else
        rstrnt-report-result $test_item $result 1
    fi
}

function RunTest ()
{
    # Default result to Fail
    export result_r="FAIL"

    PROCS=$1

    echo Test Start Time: `date` >> $OUTPUTFILE

    rt-migrate-test $PROCS 2>&1 >> $OUTPUTFILE
    grep -q " Failed!" $OUTPUTFILE
    if [ $? -eq 0 ]; then
        echo "rt-migrate-test balance Failed: " | tee -a $OUTPUTFILE
        result_r="FAIL"
    else
        echo "rt_migrate balance Passed: " | tee -a $OUTPUTFILE
        result_r="PASS"
    fi

    echo Test End Time: `date` >> $OUTPUTFILE
    RprtRslt Balancing $result_r
}

function RunStress ()
{
    # Default result to Fail
    export result_r="FAIL"

    PROCS=$1

    echo Test Start Time: `date` >> $OUTPUTFILE

    rt-migrate-test $PROCS -l 1000 2>&1 >> $OUTPUTFILE
    grep -q " Failed!" $OUTPUTFILE
    if [ $? -eq 0 ]; then
        echo "rt_migrate stress Failed: " | tee -a $OUTPUTFILE
        result_r="FAIL"
    else
        echo "rt_migrate stress Passed: " | tee -a $OUTPUTFILE
        result_r="PASS"
    fi

    echo Test End Time: `date` >> $OUTPUTFILE
    RprtRslt Stress $result_r
}

# ---------- Start Test -------------
rt_env_setup

# set default variables
NUMBERPROCS=$(/bin/cat /proc/cpuinfo | /bin/grep processor | wc -l)
SYSCPUS=$(expr `/bin/cat /proc/cpuinfo | /bin/grep processor | wc -l` + 1)

echo "Number of Procs: $NUMBERPROCS / Running test with Procs: $SYSCPUS" | tee -a $OUTPUTFILE
RunTest $SYSCPUS
RunStress $SYSCPUS
exit 0
