#!/bin/bash
. /usr/bin/rhts_environment.sh

export ACCEL=kvm
unset ARCH
unset STANDALONE
cpus=$(grep -c ^processor /proc/cpuinfo)

# test can only run on hardware that supports virtualization 
if egrep -q '(vmx|svm)' /proc/cpuinfo; then
    echo "Hardware supports virtualization, proceeding" | tee -a $OUTPUTFILE
else
    echo "Skipping test, CPU doesn't support virtualization" | tee -a $OUTPUTFILE
    rhts-report-result $TEST SKIP $OUTPUTFILE
    exit
fi

# test should only run on a system with 1 or more cpus
if [ "$cpus" > 1 ]; then
    echo "You have sufficient CPU's to run the test" | tee -a $OUTPUTFILE
else
    echo "Skipping test, system requires > 1 CPU" | tee -a $OUTPUTFILE
    rhts-report-result $TEST SKIP $OUTPUTFILE
    exit
fi

# test is only supported on x86_64 and aarch64
if [ "$(uname -i)" == "x86_64" ] || [ "$(uname -i)" == "aarch64" ] ; then
    echo "Running on supported arch (x86_64 or aarch64)" | tee -a $OUTPUTFILE
else
    echo "Skipping test, test is only supported on x86_64 and aarch64" | tee -a $OUTPUTFILE
    rhts-report-result $TEST SKIP $OUTPUTFILE
    exit
fi

# set the virt kernel parameters
echo -e "options kvm force_emulation_prefix=1\noptions kvm enable_vmware_backdoor=1" > /etc/modprobe.d/kvm-ci.conf

# reload the modules
rmmod kvm_intel kvm_amd kvm
modprobe kvm_intel kvm_amd kvm

KVM_SYSFS=/sys/module/kvm/parameters/
KVM_OPTIONS="enable_vmware_backdoor force_emulation_prefix"

for opt in $KVM_OPTIONS; do
    if [ ! -f "$KVM_SYSFS/$opt" ]; then
        echo "kernel option $opt not set" | tee -a $OUTPUTFILE
        report_result $TEST WARN
        rhts-abort -t recipe
    else
        echo "kernel option $opt is set" | tee -a $OUTPUTFILE
    fi
done

# set the qemu-kvm path
if [ -e /usr/libexec/qemu-kvm ]; then
    export QEMU="/usr/libexec/qemu-kvm"
fi

if [ -z "$QEMU" ]; then
    echo "Can't find qemu binary" | tee -a $OUTPUTFILE
    report_result $TEST WARN
    rhts-abort -t recipe
fi

# if running on rhel8, use python3
if grep --quiet 8.0 /etc/redhat-release;then
    ln -s /usr/libexec/platform-python /usr/bin/python
fi

# enable nmi_watchdog since some unit tests depend on this
echo 0 > /proc/sys/kernel/nmi_watchdog

# clone the upstream kvm-unit-tests
git clone git://git.kernel.org/pub/scm/virt/kvm/kvm-unit-tests.git
cd kvm-unit-tests
git checkout d481ff76642365cb8605c27224bcb771e639b6ee
if [ $? -ne 0 ]; then
    echo "Failed to clone and checkout commit from kvm-unit-tests" | tee -a $OUTPUTFILE
    report_result $TEST WARN
    rhts-abort -t recipe
fi

# update unittests.cfg to exclude known failures
cp ../unittests.cfg x86/unittests.cfg

# run the tests
./configure
make
./run_tests.sh -v > test.log 2>&1 
cat test.log | tee -a $OUTPUTFILE

# check for any new failures
grep FAIL test.log >> failures.txt

# submit logs to beaker
which rhts-submit-log > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    logs=$(ls logs/)
    if [[ $? -ne 0 ]]; then
        exit 0
    fi
    for log in $logs
    do
        echo "Submitting the following log to beaker: $log"
        rhts-submit-log -l logs/$log
    done
fi

# number of failures is our return code
ret=$(wc -l failures.txt  | awk '{print $1}')
if [ $ret -gt 0 ]; then
        report_result "done" "FAIL" 1
else
        report_result "done" "PASS" 0
fi
exit 0
