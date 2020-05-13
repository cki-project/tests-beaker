#!/bin/bash
. ../../cki_lib/libcki.sh || exit 1

unset ARCH
unset STANDALONE
cpus=$(grep -c ^processor /proc/cpuinfo)
BINDIR=./tests
LOGDIR=./logs
GICVERSION=""
MACHINES=("pc")
CPUTYPE=""
OSVERSION=""
KVMPARAMFILE=/etc/modprobe.d/kvm-ci.conf
REPOS=("default")
SETUPS=("setupDF")
CLEANUPS=("cleanupDF")
ACCEL="kvm"

source /usr/share/beakerlib/beakerlib.sh

function checkPlatformSupport
{
    typeset hwpf=${1?"*** what hardware-platform?, e.g. x86_64"}
    [[ $hwpf == "x86_64" ]] && return 0
    [[ $hwpf == "aarch64" ]] && return 0
    [[ $hwpf == "ppc64" ]] && return 0
    [[ $hwpf == "ppc64le" ]] && return 0
    [[ $hwpf == "s390x" ]] && return 0
    return 1
}

function checkVirtSupport
{
    typeset hwpf=${1?"*** what hardware-platform?, e.g. x86_64"}

    if grep -q "Red Hat Enterprise Linux release 8." /etc/redhat-release; then
        OSVERSION="RHEL8"
    else
        OSVERSION="ARK"
    fi

    if [[ $OSVERSION == "RHEL8" ]] && dnf repolist --all | grep -q rhel8-advvirt; then
        REPOS+=("rhel8-advvirt")
        SETUPS+=("setupAV")
        CLEANUPS+=("cleanupAV")
    fi

    if [[ $OSVERSION == "RHEL8" ]] && dnf repolist --all | grep -q virt-weeklyrebase; then
        REPOS+=("virt-weeklyrebase")
        SETUPS+=("setupWR")
        CLEANUPS+=("cleanupWR")
    fi

    if [[ $hwpf == "x86_64" ]]; then
        MACHINES+=("q35")
        if (egrep -q 'vmx' /proc/cpuinfo); then
            CPUTYPE="INTEL"
        elif (egrep -q 'svm' /proc/cpuinfo); then
            CPUTYPE="AMD"
        fi
        egrep -q '(vmx|svm)' /proc/cpuinfo
        return $?
    elif [[ $hwpf == "aarch64" ]]; then
        if journalctl -k | egrep -qi "disabling GICv2" ; then
            GICVERSION="3"
        else
            GICVERSION="2"
        fi
        CPUTYPE="ARMGICv$GICVERSION"
        journalctl -k | egrep -iq "kvm.*: (Hyp|VHE) mode initialized successfully"
        return $?
    elif [[ $hwpf == "ppc64" || $hwpf == "ppc64le" ]]; then
        ACCEL+=",cap-ccf-assist=off"
        if (egrep -q 'POWER9' /proc/cpuinfo); then
            CPUTYPE="POWER9"
        else
            CPUTYPE="POWER8"
        fi
        grep -q 'platform.*PowerNV' /proc/cpuinfo
        return $?
    elif [[ $hwpf == "s390x" ]]; then
        CPUTYPE="S390X"
        grep -q 'features.*sie' /proc/cpuinfo
        return $?
    else
        return 1
    fi
}

function getTests
{
    # List of tests to run on all architectures
    ALL_TESTS=()
    while IFS=  read -r -d $'\0'; do
        ALL_TESTS+=("$REPLY")
    done < <(find $BINDIR/ -maxdepth 1 -type f -executable -printf "%f\0")
}

function disableTests
{
    typeset hwpf=$(uname -i)

    # Disable tests for RHEL8 Kernel (4.18.X)
    if [[ $OSVERSION == "RHEL8" ]]; then
        # Disabled x86_64 tests for Intel & AMD machines due to bugs
            # Disabled x86_64 tests for pc qemu machine type
        if [[ $hwpf == "x86_64" ]] && [[ $MACHINE == "pc" ]]; then
            # Disable test hyperv_synic, hyperv_connections, hyperv_stimer
            # due to https://bugzilla.redhat.com/show_bug.cgi?id=1668573
            mapfile -d $'\0' -t ALL_TESTS < <(printf '%s\0' "${ALL_TESTS[@]}" | grep -Pzv "hyperv_synic")
            mapfile -d $'\0' -t ALL_TESTS < <(printf '%s\0' "${ALL_TESTS[@]}" | grep -Pzv "hyperv_connections")
            mapfile -d $'\0' -t ALL_TESTS < <(printf '%s\0' "${ALL_TESTS[@]}" | grep -Pzv "hyperv_stimer")
        fi
    fi
}

function setupRepo
{
    # clone the kvm-unit-tests repo
    rlRun "rm -rf kvm-unit-tests"
    rlRun "git clone https://gitlab.com/mcondotta/kvm-unit-tests.git > /dev/null 2>&1"
    rlRun "cd kvm-unit-tests > /dev/null 2>&1"
    rlRun "git checkout mcondotta_fixes > /dev/null 2>&1"

    if [[ $hwpf == "ppc64" || $hwpf == "ppc64le" ]]; then
        rlRun "./configure --endian=little"
    else
        rlRun "./configure"
    fi

    rlRun "make standalone > /dev/null 2>&1"
}

function setup
{
    rlPhaseStartSetup
    rlRun "pushd '.'"

    # tests are currently supported on x86_64, aarch64, ppc64 and s390x
    hwpf=$(uname -i)
    checkPlatformSupport $hwpf
    if (( $? == 0 )); then
        # test can only run on hardware that supports virtualization
        checkVirtSupport $hwpf
        rlLog "[$OSVERSION][$hwpf][$CPUTYPE] Running on supported arch"
        if (( $? == 0 )); then
            rlLog "[$OSVERSION][$hwpf][$CPUTYPE] Hardware supports virtualization, proceeding"
        else
            rlLog "Skipping test, CPU doesn't support virtualization"
            rstrnt-report-result $TEST SKIP $OUTPUTFILE
            exit
        fi
    else
        rlLog "Skipping test, test is only supported on x86_64, aarch64, ppc64 or s390x"
        rstrnt-report-result $TEST SKIP $OUTPUTFILE
        exit
    fi

    # test should only run on a system with 1 or more cpus
    if [ "$cpus" -gt 1 ]; then
        rlLog "[$OSVERSION][$hwpf][$CPUTYPE] You have sufficient CPU's to run the test"
    else
        rlLog "Skipping test, system requires > 1 CPU"
        rstrnt-report-result $TEST SKIP $OUTPUTFILE
        exit
    fi

    rlLog "[$OSVERSION][$hwpf][$CPUTYPE] Running tests for OSVERSION: $OSVERSION"
    rlLog "[$OSVERSION][$hwpf][$CPUTYPE] Running tests for ARCH: $hwpf"
    rlLog "[$OSVERSION][$hwpf][$CPUTYPE] Running tests for CPUTYPE: $CPUTYPE"
    rlLog "[$OSVERSION][$hwpf][$CPUTYPE] Running tests for MACHINES: ${MACHINES[*]}"
    rlLog "[$OSVERSION][$hwpf][$CPUTYPE] Running tests for REPOS: ${REPOS[*]}"

    KVM_SYSFS=/sys/module/kvm/parameters/
    KVM_OPTIONS=""
    if [[ $hwpf == "x86_64" ]]; then
        KVM_OPTIONS+=("enable_vmware_backdoor")
        KVM_OPTIONS+=("force_emulation_prefix")
    elif [[ $hwpf == "s390x" ]]; then
        KVM_OPTIONS+=("nested")
    fi

    KVM_ARCH=""
    KVM_MODULES=()
    KVM_ARCH_OPTIONS=()
    if [[ $CPUTYPE == "INTEL" ]]; then
        KVM_ARCH="kvm_intel"
        KVM_ARCH_OPTIONS+=("nested")
    elif [[ $CPUTYPE == "AMD" ]]; then
        KVM_ARCH="kvm_amd"
        KVM_ARCH_OPTIONS+=("nested")
    elif [[ $hwpf == "ppc64" || $hwpf == "ppc64le" ]]; then
        KVM_ARCH="kvm_hv"
        KVM_MODULES+=("kvm_pr")
        KVM_ARCH_OPTIONS+=("nested")
    fi
    KVM_MODULES+=("$KVM_ARCH")
    KVM_MODULES+=("kvm")
    KVM_ARCH_SYSFS=/sys/module/$KVM_ARCH/parameters/

    # Set the KVM parameters needed for the tests
    > $KVMPARAMFILE
    for opt in ${KVM_OPTIONS[*]}; do
        echo -e "options kvm $opt=1\n" >> $KVMPARAMFILE
    done
    for opt in ${KVM_ARCH_OPTIONS[*]}; do
        echo -e "options $KVM_ARCH $opt=1\n" >> $KVMPARAMFILE
    done

    # Export env variables used by KVM Unit Tests
    export ACCEL=$ACCEL
    export TIMEOUT=3000s

    # Reload the modules
    for mod in ${KVM_MODULES[*]}; do rmmod -f $mod > /dev/null 2>&1; done
    modprobe -a kvm $KVM_ARCH

    # Test if the KVM parameters were set correctly
    for opt in ${KVM_OPTIONS[*]}; do
        if ! cat $KVM_SYSFS/$opt | egrep -q "Y|y|1"; then
            rlLog "[$OSVERSION][$hwpf][$CPUTYPE] kvm module option $opt not set"
            rstrnt-report-result $TEST WARN
            rstrnt-abort -t recipe
        else
            rlLog "[$OSVERSION][$hwpf][$CPUTYPE] kvm module option $opt is set"
        fi
    done
    for opt in ${KVM_ARCH_OPTIONS[*]}; do
        if ! cat $KVM_ARCH_SYSFS/$opt | egrep -q "Y|y|1"; then
            rlLog "[$OSVERSION][$hwpf][$CPUTYPE] $KVM_ARCH module option $opt not set"
            rstrnt-report-result $TEST WARN
            rstrnt-abort -t recipe
        else
            rlLog "[$OSVERSION][$hwpf][$CPUTYPE] $KVM_ARCH module option $opt is set"
        fi
    done

    # set the qemu-kvm path
    if [ -e /usr/libexec/qemu-kvm ]; then
        export QEMU="/usr/libexec/qemu-kvm"
    elif [ -e /usr/bin/qemu-kvm ]; then
        export QEMU="/usr/bin/qemu-kvm"
    fi

    if [ -z "$QEMU" ]; then
        rlLog "[$OSVERSION][$hwpf][$CPUTYPE] Can't find qemu binary"
        rstrnt-report-result $TEST WARN
        rstrnt-abort -t recipe
    fi

    # if running on rhel8, use python3
    if [[ $OSVERSION == "RHEL8" ]] && [ ! -f /usr/bin/python ]; then
        ln -s /usr/libexec/platform-python /usr/bin/python
    fi

    # enable nmi_watchdog since some unit tests depend on this
    if test -f "/proc/sys/kernel/nmi_watchdog"; then
        echo 0 > /proc/sys/kernel/nmi_watchdog
    fi

    setupRepo

    rlRun "popd"
    rlPhaseEnd
}

function setupDF
{
    rlLog "[$OSVERSION][$hwpf][$CPUTYPE][$mach][$repo] Installing qemu-kvm version from given repository"
    dnf module -y reset virt > /dev/null 2>&1
    dnf module -y enable virt > /dev/null 2>&1
    dnf install -y qemu-kvm > /dev/null 2>&1
    rlLog "[$OSVERSION][$hwpf][$CPUTYPE][$mach][$repo] QEMU version installed: `rpm -q qemu-kvm`"
}

function cleanupDF
{
    return
}

function setupAV
{
    rlLog "[$OSVERSION][$hwpf][$CPUTYPE][$mach][$repo] Installing qemu-kvm version from given repository"
    dnf remove -y qemu-* > /dev/null 2>&1
    dnf module -y reset virt > /dev/null 2>&1
    dnf module -y --enablerepo=rhel8-advvirt enable virt:8.3  > /dev/null 2>&1
    dnf install -y --enablerepo=rhel8-advvirt qemu-kvm > /dev/null 2>&1
    rlLog "[$OSVERSION][$hwpf][$CPUTYPE][$mach][$repo] QEMU version installed: `rpm -q qemu-kvm`"
}

function cleanupAV
{
    rlLog "[$OSVERSION][$hwpf][$CPUTYPE][$mach][$repo] Removing qemu-kvm version installed from repository"
    dnf remove -y qemu-* > /dev/null 2>&1
    dnf module -y reset virt > /dev/null 2>&1
    dnf module -y enable virt > /dev/null 2>&1
}

function setupWR
{
    rlLog "[$OSVERSION][$hwpf][$CPUTYPE][$mach][$repo] Installing qemu-kvm version from given repository"
    dnf remove -y qemu-* > /dev/null 2>&1
    dnf install -y --enablerepo=virt-weeklyrebase qemu-kvm > /dev/null 2>&1
    rlLog "[$OSVERSION][$hwpf][$CPUTYPE][$mach][$repo] QEMU version installed: `rpm -q qemu-kvm`"
}

function cleanupWR
{
    rlLog "[$OSVERSION][$hwpf][$CPUTYPE][$mach][$repo] Removing qemu-kvm version installed from repository"
    dnf remove -y qemu-* > /dev/null 2>&1
}

function runtest
{
    rlPhaseStartTest
    rlRun "pushd '.'"

    rlRun "cd kvm-unit-tests"

    rm -rf $LOGDIR
    mkdir $LOGDIR

    for mach in ${MACHINES[*]}; do
        export MACHINE=$mach

        # Prepare lists of tests to run
        getTests
        disableTests

        i=0
        for repo in ${REPOS[*]}; do
            ${SETUPS[$i]}
            # Run tests
            for test in ${ALL_TESTS[*]}; do rlRun "yes | $BINDIR/$test > $LOGDIR/${mach}_${repo}_$test.log 2>&1" 0,2,77; done
            ${CLEANUPS[$i]}
            i=$i+1
        done
    done

    rlRun "popd"
    rlPhaseEnd
}

function cleanup
{
    rlPhaseStartCleanup
    rlRun "pushd '.'"

    dnf remove -y qemu-* > /dev/null 2>&1
    dnf module -y reset virt > /dev/null 2>&1
    dnf module -y enable virt > /dev/null 2>&1
    dnf install -y qemu-kvm > /dev/null 2>&1

    rlRun "popd"
    rlPhaseEnd
}

function main
{
    rlJournalStart

    setup
    runtest
    cleanup

    rlJournalEnd
}

main
exit $?
