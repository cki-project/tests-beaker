#!/bin/bash

# Source the common test script helpers
. ../../../cki_lib/libcki.sh || exit 1
. ../include/runtest.sh      || exit 1
. ../include/kvercmp.sh      || exit 1

#export AVC_ERROR=+no_avc_check
#export RHTS_OPTION_STRONGER_AVC=

if [ -z "$REBOOTCOUNT" ]; then
    REBOOTCOUNT=0
fi

cver=$(uname -r)
echo "Current kernel is: $cver" | tee -a $OUTPUTFILE

# ---------- Start Test -------------
if [ "${REBOOTCOUNT}" -ge 1 ]; then
    echo "============ Test has already been run, Check logs for possible failures ============" | tee -a $OUTPUTFILE
    rstrnt-report-result CHECKLOGS  WARN/ABORTED
    rstrnt-abort -t recipe
    exit
fi

# report patch errors from ltp/include
grep -i -e "FAIL" -e "ERROR" patchinc.log > /dev/null 2>&1
if [ $? -eq 0 ]; then
    rstrnt-report-result "ltp-include-patch-errors" WARN/ABORTED
    rstrnt-abort -t recipe
    exit
fi

# Sometimes it takes too long to waiting for syscalls finish and I want
# to know whether the compilation is finish or not.
rstrnt-report-result "install" "PASS"

echo "ulimit -c unlimited" | tee -a $OUTPUTFILE
ulimit -c unlimited

echo "numactl --hardware" | tee -a $OUTPUTFILE
echo "-----" | tee -a $OUTPUTFILE
numactl --hardware > ./numactl.txt 2>&1
cat ./numactl.txt | tee -a $OUTPUTFILE
rm -f ./numactl.txt > /dev/null 2>&1
echo "-----" | tee -a $OUTPUTFILE

# disable NTP and chronyd
tservice=""
pgrep chronyd > /dev/null
if [ $? -eq 0 ]; then
    tservice="chronyd"
    service chronyd stop
fi
DisableNTP

# START TEST
opt_dir="$(pwd)/ltp-full-*/testcases/open_posix_testsuite"
opt_dir="$(ls -1 -d $opt_dir | head -1)"
echo "Open POSIX testsuite is at: $opt_dir" | tee -a $OUTPUTFILE

# give more slack to known issues with high steal time on s390x
if uname -r | grep -q s390; then
    echo "s390: patching ACCEPTABLEDELTA for timer_settime testcases" | tee -a $OUTPUTFILE
    sed -i 's/#define ACCEPTABLEDELTA 1/#define ACCEPTABLEDELTA 9/' $opt_dir/conformance/interfaces/timer_settime/*.c
fi

# disable unsupported/known to fail testcases
DISABLED_LIST='disabled.common'

# Data written beyond the end of partial-page mmap can be seen by subsequent
# maps when using tmpfs so this test fails. See mmap(2) man page for more info.
if grep -q '/tmp tmpfs' /proc/mounts; then
    echo './conformance/interfaces/mmap/11-4.c' >> ${DISABLED_LIST}
fi

echo "Disabling testcases" | tee -a $OUTPUTFILE
for entry in $(cat $DISABLED_LIST); do
    first_char=$(echo $entry | cut -b1)
    if [ "$first_char" == "#" ]; then
        continue
    fi
    echo "Disabling: $entry" | tee -a $OUTPUTFILE
    rm -rf $opt_dir/$entry >> $OUTPUTFILE 2>&1
done

# build
echo "Building testcases" | tee -a $OUTPUTFILE
env CFLAGS="-g3" time make -C $opt_dir all > buildlog.txt 2>&1
if [ $? -ne 0 ]; then
    bzip2 buildlog.txt
    SubmitLog buildlog.txt.bz2
    rstrnt-report-result build WARN/ABORTED
    rstrnt-abort -t recipe
    exit
else
    rstrnt-report-result build PASS
fi

OUTPUTFILE="$OUTPUTFILE.2"
echo "Executing testcases" | tee -a $OUTPUTFILE
time make -C $opt_dir test > logfile.runall 2>&1

# log failed TESTCASES
grep -e FAILED -e SIGNALED -e ABNORMALLY logfile.runall | sed 's/:.*//' > failed_list

# Some testcases are testing for conditions which can happen
# in very limited time window, for example: attempt to cancel
# ongoing aio operation, depending on timing such operation
# can complete asynchronously before testcase issues cancel.
# In this case testcase ends with UNRESOLVED, do not report
# it as failure.
grep -e UNRESOLVED logfile.runall | sed 's/:.*//' > unresolved_list
sed -i '/.*aio_error_2-1/d' unresolved_list
sed -i '/.*aio_cancel_4-1/d' unresolved_list
sed -i '/.*aio_cancel_5-1/d' unresolved_list
sed -i '/.*aio_cancel_6-1/d' unresolved_list
sed -i '/.*aio_cancel_7-1/d' unresolved_list
sed -i '/.*aio_suspend_1-1/d' unresolved_list
cat unresolved_list >> failed_list

# ignore known failures
uname -m | grep -q s390
if [ $? -eq 0 ]; then
    # s390x high steal time can cause higher than expected times
    # it takes for syscalls like nanosleep to complete
    sed -i '/.*timer_getoverrun_2-3/d' failed_list
    sed -i '/.*timer_create_11-1/d' failed_list
    sed -i '/.*timer_gettime_1-3/d' failed_list
fi

failed_no=$(cat failed_list | wc -l)
if [ "$failed_no" -gt 0 ]; then
    SubmitLog logfile.runall
    echo "Failed testcases:" | tee -a $OUTPUTFILE
    cat failed_list | tee -a $OUTPUTFILE
    # if there is failure, submit all logs
    SubmitLog $opt_dir/logfile.conformance-test
    SubmitLog $opt_dir/logfile.functional-test
    SubmitLog $opt_dir/logfile.stress-test
    rstrnt-report-result testcases FAIL 1
else
    echo "All testcases passed." | tee -a $OUTPUTFILE
    rstrnt-report-result testcases PASS
fi

# if testcase on excluded list failed, remove it, so we get core
cp -f grab_corefiles_excluded_bins grab_corefiles_excluded_bins.filtered
for failed_case in $(cat failed_list); do
    failed_case_dir=$(dirname $failed_case)
    failed_case_name="$(basename $failed_case_dir)/$(basename $failed_case)"
    sed -i '/failed_case_name[.$]/d' grab_corefiles_excluded_bins.filtered
done

# some testcases send signals which result in corefiles by design
# these are not interesting, unless the testcase failed
echo "Grabbing core files" | tee -a $DEBUGLOG
./grab_corefiles.sh $opt_dir $(pwd)/grab_corefiles_excluded_bins.filtered >> $DEBUGLOG 2>&1
SubmitLog $DEBUGLOG
echo "Submitted $DEBUGLOG" | tee -a $DEBUGLOG

# restore either NTP or chronyd
if [ -n "$tservice" ]; then
    service chronyd start
else
    EnableNTP
fi

exit 0
