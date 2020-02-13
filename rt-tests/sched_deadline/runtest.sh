#!/bin/bash

# Source rt common functions
. ../include/runtest.sh

function runtest()
{
    result_r="PASS"

    which deadline_test || yum install -y rt-tests

    echo "clean the dmesg log" | tee -a $OUTPUTFILE
    dmesg -c

    deadline_test -t 1 | tee -a $OUTPUTFILE
    deadline_test -t 1 -i 10000 | tee -a $OUTPUTFILE

    dmesg | grep 'Call Trace'
    if [ $? -eq 0 ]; then
        rstrnt-report-result $TEST "FAIL" "1"
    else
        rstrnt-report-result $TEST "PASS" "0"
    fi
}

rt_env_setup
runtest
exit 0
