#!/bin/bash
. ../../cki_lib/libcki.sh || exit 1

export ACCEL=kvm
unset ARCH
unset STANDALONE
cpus=$(grep -c ^processor /proc/cpuinfo)

function check_platform_support
{
    typeset hwpf=${1?"*** what hardware-platform?, e.g. x86_64"}
    [[ $hwpf == "x86_64" ]] && return 0
    [[ $hwpf == "aarch64" ]] && return 0
    [[ $hwpf == "ppc64" ]] && return 0
    [[ $hwpf == "ppc64le" ]] && return 0
    [[ $hwpf == "s390x" ]] && return 0
    return 1
}

function check_virt_support
{
    typeset hwpf=${1?"*** what hardware-platform?, e.g. x86_64"}
    if [[ $hwpf == "x86_64" ]]; then
        egrep -q '(vmx|svm)' /proc/cpuinfo
        return $?
    elif [[ $hwpf == "aarch64" ]]; then
        dmesg | egrep -iq "kvm"
        if (( $? == 0 )); then
            dmesg | egrep -iq "kvm.*: (Hyp|VHE) mode initialized successfully"
        else
            #
            # XXX: Note that the harness (i.e. beaker) does clear dmesg, hence
            #      we have to fetch the output of kernel buffer from
            #      "journalctl -k"
            #
            journalctl -k | \
                egrep -iq "kvm.*: (Hyp|VHE) mode initialized successfully"
        fi
        return $?
    elif [[ $hwpf == "ppc64" || $hwpf == "ppc64le" ]]; then
        grep -q 'platform.*PowerNV' /proc/cpuinfo
        return $?
    elif [[ $hwpf == "s390x" ]]; then
        grep -q 'features.*sie' /proc/cpuinfo
        return $?
    else
        return 1
    fi
}

# test is only supported on x86_64, aarch64, ppc64 and s390x
hwpf=$(uname -i)
check_platform_support $hwpf
if (( $? == 0 )); then
    echo "Running on supported arch ($hwpf)" | tee -a $OUTPUTFILE

    # test can only run on hardware that supports virtualization
    check_virt_support $hwpf
    if (( $? == 0 )); then
        echo "Hardware supports virtualization, proceeding" | tee -a $OUTPUTFILE
    else
        echo "Skipping test, CPU doesn't support virtualization" | tee -a $OUTPUTFILE
        rstrnt-report-result $TEST SKIP $OUTPUTFILE
        exit
    fi
else
    echo "Skipping test, test is only supported on x86_64, aarch64, ppc64 or s390x" | tee -a $OUTPUTFILE
    rstrnt-report-result $TEST SKIP $OUTPUTFILE
    exit
fi

# test should only run on a system with 1 or more cpus
if [ "$cpus" -gt 1 ]; then
    echo "You have sufficient CPU's to run the test" | tee -a $OUTPUTFILE
else
    echo "Skipping test, system requires > 1 CPU" | tee -a $OUTPUTFILE
    rstrnt-report-result $TEST SKIP $OUTPUTFILE
    exit
fi

KVM_SYSFS=/sys/module/kvm/parameters/
KVM_OPTIONS_X86="enable_vmware_backdoor force_emulation_prefix"
KVM_ARCH=""
if (egrep -q 'vmx' /proc/cpuinfo); then
    KVM_ARCH="kvm_intel"
elif (egrep -q 'svm' /proc/cpuinfo); then
    KVM_ARCH="kvm_amd"
fi
KVM_ARCH_SYSFS=/sys/module/${KVM_ARCH}/parameters/
KVM_ARCH_OPTIONS_X86="nested"

if [[ $hwpf == "x86_64" ]]; then
    # set the virt kernel parameters
    echo -e "options kvm force_emulation_prefix=1\noptions kvm enable_vmware_backdoor=1" > /etc/modprobe.d/kvm-ci.conf
    echo -e "options ${KVM_ARCH} nested=1" >> /etc/modprobe.d/kvm-ci.conf
    # reload the modules
    if (egrep -q 'vmx' /proc/cpuinfo); then
        rmmod kvm_intel kvm
        modprobe kvm_intel kvm
    elif (egrep -q 'svm' /proc/cpuinfo); then
        rmmod kvm_amd kvm
        modprobe kvm_amd kvm
    fi
    for opt in $KVM_OPTIONS_X86; do
        if [ ! -f "$KVM_SYSFS/$opt" ]; then
            echo "kernel option $opt not set" | tee -a $OUTPUTFILE
            rstrnt-report-result $TEST WARN
            rstrnt-abort -t recipe
        else
            echo "kernel option $opt is set" | tee -a $OUTPUTFILE
        fi
    done
    for opt in $KVM_ARCH_OPTIONS_X86; do
        if [ ! -f "$KVM_ARCH_SYSFS/$opt" ]; then
            echo "kernel option $opt not set" | tee -a $OUTPUTFILE
            rstrnt-report-result $TEST WARN
            rstrnt-abort -t recipe
        else
            echo "kernel option $opt is set" | tee -a $OUTPUTFILE
        fi
    done
elif [[ $hwpf == "ppc64" || $hwpf == "ppc64le" ]]; then
    for mod in kvm_hv kvm_pr kvm ; do
        if (lsmod | grep -q $mod); then
            rmmod $mod
        fi
    done
    modprobe kvm_hv
else
    # reload the modules
    if (lsmod | grep -q kvm); then
        rmmod kvm
    fi
    modprobe kvm
fi

# set the qemu-kvm path
if [ -e /usr/libexec/qemu-kvm ]; then
    export QEMU="/usr/libexec/qemu-kvm"
elif [ -e /usr/bin/qemu-kvm ]; then
    export QEMU="/usr/bin/qemu-kvm"
fi

if [ -z "$QEMU" ]; then
    echo "Can't find qemu binary" | tee -a $OUTPUTFILE
    rstrnt-report-result $TEST WARN
    rstrnt-abort -t recipe
fi

# if running on rhel8, use python3
if grep --quiet "release 8." /etc/redhat-release && [ ! -f /usr/bin/python ];then
    ln -s /usr/libexec/platform-python /usr/bin/python
fi

# enable nmi_watchdog since some unit tests depend on this
echo 0 > /proc/sys/kernel/nmi_watchdog

# clone the upstream kvm-unit-tests
git clone git://git.kernel.org/pub/scm/virt/kvm/kvm-unit-tests.git
cd kvm-unit-tests
git checkout dc9841d08fa1796420a64ad5d5ef652de337809d
if [ $? -ne 0 ]; then
    echo "Failed to clone and checkout commit from kvm-unit-tests" | tee -a $OUTPUTFILE
    rstrnt-report-result $TEST WARN
    rstrnt-abort -t recipe
fi

# update unittests.cfg to exclude known failures
cp ../x86_unittests.cfg x86/unittests.cfg
cp ../aarch64_unittests.cfg arm/unittests.cfg
cp ../s390x_unittests.cfg s390x/unittests.cfg
cp ../ppc64le_unittests.cfg powerpc/unittests.cfg

# run the tests
if [[ $hwpf == "ppc64" || $hwpf == "ppc64le" ]]; then
    ./configure --endian=little
else
    ./configure
fi
make
./run_tests.sh -v > test.log 2>&1
cat test.log | tee -a $OUTPUTFILE

# check for any new failures
grep FAIL test.log >> failures.txt

# Run KVM Unit tests with Advanced Virt (qemu-4.0) if possible
if dnf repolist --all | grep rhel8-advvirt; then
    dnf module -y reset virt
    dnf module -y --enablerepo=rhel8-advvirt enable virt:8.1
    dnf update -y --enablerepo=rhel8-advvirt qemu-*

    git clean -fdx
    git reset --hard

    cp ../x86_adv_unittests.cfg x86/unittests.cfg
    cp ../aarch64_unittests.cfg arm/unittests.cfg
    cp ../s390x_unittests.cfg s390x/unittests.cfg

    # run the tests
    if [[ $hwpf == "ppc64" || $hwpf == "ppc64le" ]]; then
        ./configure --endian=little
    else
        ./configure
    fi
    make
    ./run_tests.sh -v > testadv.log 2>&1
    cat testadv.log | tee -a $OUTPUTFILE

    # check for any new failures
    grep FAIL testadv.log >> failures.txt

    # cleanup Advanced VIRT repo and downgrade QEMU version
    dnf module -y reset virt
    dnf module -y enable virt
    dnf downgrade -y qemu-*
fi

# submit logs to beaker
which rstrnt-report-log > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    logs=$(ls logs/*.log)
    testlog="tests_run.log"
    if [[ $? -ne 0 ]]; then
        exit 0
    fi
    > ${testlog}
    for log in $logs
    do
        printf "[START ${log} LOG]\n" >> ${testlog}
        cat ${log} >> ${testlog}
        printf "[END ${log} LOG]\n\n" >> ${testlog}
    done
    echo "Submitting the following log to beaker: ${testlog}"
    rstrnt-report-log -l ${testlog}
fi

# number of failures is our return code
ret=$(wc -l failures.txt  | awk '{print $1}')
if [ $ret -gt 0 ]; then
        rstrnt-report-result "done" "FAIL" 1
else
        rstrnt-report-result "done" "PASS" 0
fi
exit 0
