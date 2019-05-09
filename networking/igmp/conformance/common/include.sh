#!/bin/bash

# variables to control some default action
NM_CTL=${NM_CTL:-"no"}
FIREWALL=${FIREWALL:-"no"}
AVC_CHECK=${AVC_CHECK:-"yes"}
if [ ! "$JOBID" ]; then
    RED='\E[1;31m'
    GRN='\E[1;32m'
    YEL='\E[1;33m'
    RES='\E[0m'
fi

new_outputfile()
{
    mktemp /mnt/testarea/tmp.XXXXXX
}


test_pass()
{
    #SCORE=${2:-$PASS}
    echo -e "\n:: [  PASS  ] :: Test '"$1"'" | tee -a $OUTPUTFILE
    # we don't care how many test passed
    if [ $JOBID ]; then
       report_result "${TEST}/$1" "PASS"
    else
        echo -e "\n::::::::::::::::"
        echo -e ":: [  ${GRN}PASS${RES}  ] :: Test '"${TEST}/$1"'"
        echo -e "::::::::::::::::\n"
    fi
}

test_fail()
{
    SCORE=${2:-$FAIL}
    echo -e ":: [  FAIL  ] :: Test '"$1"'" | tee -a $OUTPUTFILE
    # we only care how many test failed
    if [ $JOBID ]; then
        report_result "${TEST}/$1" "FAIL" "$SCORE"
    else
        echo -e "\n:::::::::::::::::"
        echo -e ":: [  ${RED}FAIL${RES}  ] :: Test '"${TEST}/$1"' FAIL $SCORE"
        echo -e ":::::::::::::::::\n"
    fi
}

test_warn()
{
    echo -e "\n:: [  WARN  ] :: Test '"$1"'" | tee -a $OUTPUTFILE
    if [ $JOBID ]; then
        report_result "${TEST}/$1" "WARN"
    else
        echo -e "\n:::::::::::::::::"
        echo -e ":: [  ${YEL}WARN${RES}  ] :: Test '"${TEST}/$1"'"
        echo -e ":::::::::::::::::\n"
    fi
}

# We only care the main distro
GetDistroRelease()
{
        #version=`sed 's/[^0-9\.]//g' /etc/redhat-release`
        cut -f1 -d. /etc/redhat-release | sed 's/[^0-9]//g'
}

