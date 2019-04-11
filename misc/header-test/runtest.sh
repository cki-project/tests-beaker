#!/bin/bash

# the $? check below cares about the return value from python, not tee,
# so enable pipefail
set -o pipefail

# RHEL7 and older use /usr/bin/python
# RHEL8 and newer use /usr/libexec/platform-python
PYTHON=/usr/bin/python
if grep -q "release 8" /etc/redhat-release ; then
    PYTHON=/usr/libexec/platform-python
fi
export PYTHON

# Source the common test script helpers
. /usr/bin/rhts_environment.sh

# Assume the test will fail.
result=FAIL

# ---------- Start Test -------------

# Setup some variables
echo "***** Starting the runtest.sh script *****" | tee -a $OUTPUTFILE
echo "***** Current Running Kernel Package = "$kernbase" *****" | tee -a $OUTPUTFILE
echo "***** Current Running Distro = "$installeddistro" *****" | tee -a $OUTPUTFILE


TEST_DIR=/tmp/header-test
echo "Generating header test files" | tee -a $OUTPUTFILE
$PYTHON header-test-gen.py $TEST_DIR | tee -a $OUTPUTFILE
if [ $? -eq 0 ]; then
    pushd .
    cd $TEST_DIR
    rm -f output.log
    echo "Compiling header test files" | tee -a $OUTPUTFILE
    ./compile.sh &> output.log
    ret=$?
    cat output.log | tee -a $OUTPUTFILE
    if [ $ret -eq 0 ]; then
        echo "ALL OK -> PASS" | tee -a $OUTPUTFILE
        report_result $TEST PASS $(grep --count PASS $OUTPUTFILE)
        exit 0
    fi
    popd
    if [ "$VERIFY" = "yes" ]; then
        $PYTHON report-verify.py < $OUTPUTFILE 2>&1 | tee $TEST_DIR/verify-all.log
        rhts-submit-log -l $TEST_DIR/verify-all.log
        $PYTHON report-verify.py --pass < $OUTPUTFILE 2>&1 | tee $TEST_DIR/verify-pass.log
        rhts-submit-log -l $TEST_DIR/verify-pass.log
    fi
fi

report_result $TEST FAIL $(grep --count FAIL $OUTPUTFILE)
