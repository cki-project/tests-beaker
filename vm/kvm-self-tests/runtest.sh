#!/bin/bash
#
# Copyright (c) 2019 Red Hat, Inc. All rights reserved.
#
# This copyrighted material is made available to anyone wishing
# to use, modify, copy, or redistribute it subject to the terms
# and conditions of the GNU General Public License version 2.
#
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
#

NAME=$(basename $0)
CDIR=$(dirname $0)
TEST=${TEST:-"$0"}
RELEASE=$(uname -r | sed s/\.`arch`//)
PACKAGE="kernel-${RELEASE}"
TMPDIR=/var/tmp/$(date +"%Y%m%d%H%M%S")
BINDIR=${TMPDIR}-bin

function getTests
{
    # List of tests to run on all architectures
    ALLARCH_TESTS=()
    while IFS=  read -r -d $'\0'; do
        ALLARCH_TESTS+=("$REPLY")
    done < <(find ${BINDIR} -maxdepth 1 -type f -executable -printf "%f\0")

    # List of tests to run on x86_64 architecture
    X86_64_TESTS=()
    while IFS=  read -r -d $'\0'; do
        X86_64_TESTS+=("$REPLY")
    done < <(find ${BINDIR}/x86_64 -maxdepth 1 -type f -executable -printf "x86_64/%f\0")

    # List of tests to run on aarch64 architecture
    AARCH64_TESTS=()

    # List of tests to run on ppc64 architecture
    PPC64_TESTS=()

    # List of tests to run on s390x architecture
    S390X_TESTS=()
}

function disableTests
{
    # Disable tests for RHEL8 Kernel (4.18.X)
    if uname -r | grep --quiet '^4'; then
        # Disable test clear_dirty_log_test
        # due to https://bugzilla.redhat.com/show_bug.cgi?id=1718479
        mapfile -d $'\0' -t ALLARCH_TESTS < <(printf '%s\0' "${ALLARCH_TESTS[@]}" | grep -Pzv "clear_dirty_log_test")

        # Disabled x86_64 tests for AMD machines due to bugs
        if lsmod | grep --quiet kvm_amd; then
            # Disable test x86_64/platform_info_test
            # due to https://bugzilla.redhat.com/show_bug.cgi?id=1718499
            mapfile -d $'\0' -t X86_64_TESTS < <(printf '%s\0' "${X86_64_TESTS[@]}" | grep -Pzv "x86_64/platform_info_test")
        fi
    fi

    # Disable tests for ARK Kernel (5.X)
    if uname -r | grep --quiet '^5'; then
        # Disable x86_64/sync_regs_test
        # due to https://bugzilla.redhat.com/show_bug.cgi?id=1719397
        mapfile -d $'\0' -t X86_64_TESTS < <(printf '%s\0' "${X86_64_TESTS[@]}" | grep -Pzv "x86_64/sync_regs_test")

        # Disabled x86_64 tests for AMD machines due to bugs
        if lsmod | grep --quiet kvm_amd; then
            # Disable test x86_64/platform_info_test
            # due to https://bugzilla.redhat.com/show_bug.cgi?id=1719387
            mapfile -d $'\0' -t X86_64_TESTS < <(printf '%s\0' "${X86_64_TESTS[@]}" | grep -Pzv "x86_64/platform_info_test")
            # Disable x86_64/state_test
            # due to https://bugzilla.redhat.com/show_bug.cgi?id=1719401
            mapfile -d $'\0' -t X86_64_TESTS < <(printf '%s\0' "${X86_64_TESTS[@]}" | grep -Pzv "x86_64/state_test")
            # Disable x86_64/smm_test
            # due to https://bugzilla.redhat.com/show_bug.cgi?id=1719402
            mapfile -d $'\0' -t X86_64_TESTS < <(printf '%s\0' "${X86_64_TESTS[@]}" | grep -Pzv "x86_64/smm_test")
        fi

        # Disabled x86_64 tests for Intel machines due to bugs
        if lsmod | grep --quiet kvm_intel; then
            # Disable x86_64/evmcs_test
            # due to https://bugzilla.redhat.com/show_bug.cgi?id=1719400
            mapfile -d $'\0' -t X86_64_TESTS < <(printf '%s\0' "${X86_64_TESTS[@]}" | grep -Pzv "x86_64/evmcs_test")
        fi
    fi
}

source /usr/share/beakerlib/beakerlib.sh

#
# A simple wrapper function to skip a test because beakerlib doesn't support
# such an important feature, right here we just leverage 'rhts'. Note we
# don't call function report_result() as it directly invoke command
# rhts-report-result actually
#
function rlSkip
{
    source /usr/bin/rhts_environment.sh

    rlLog "Skipping test because $*"
    rhts-report-result $TEST SKIP $OUTPUTFILE

    #
    # As we want result="Skip" status="Completed" for all scenarios, right here
    # we always exit 0, otherwise the test will skip/abort
    #
    exit 0
}

function check_platform_support
{
    typeset hwpf=${1?"*** what hardware-platform?, e.g. x86_64"}
    [[ $hwpf == "x86_64" ]] && return 0
    [[ $hwpf == "aarch64" ]] && return 0
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
            dmesg | egrep -iq "kvm.*: Hyp mode initialized successfully"
        else
            #
            # XXX: Note that the harness (i.e. beaker) does clear dmesg, hence
            #      we have to fetch the output of kernel buffer from
            #      "journalctl -k"
            #
            journalctl -k | \
                egrep -iq "kvm.*: Hyp mode initialized successfully"
        fi
        return $?
    else
        return 1
    fi
}

function check
{
    # test is only supported on x86_64 and aarch64
    typeset hwpf=$(uname -i)
    check_platform_support $hwpf
    if (( $? == 0 )); then
        rlLog "Running on supported arch (x86_64 or aarch64)"

        # test can only run on hardware that supports virtualization
        check_virt_support $hwpf
        if (( $? == 0 )); then
            rlLog "Hardware supports virtualization, proceeding"
        else
            rlSkip "CPU doesn't support virtualization"
        fi
    else
        rlSkip "test is only supported on x86_64 and aarch64"
    fi

    # test should only run on a system with 1 or more cpus
    typeset cpus=$(grep -c ^processor /proc/cpuinfo)
    if (( $cpus > 1 )); then
        rlLog "You have sufficient CPU's to run the test"
    else
        rlSkip "system requires > 1 CPU"
    fi
}

function runtest
{
    rlPhaseStartTest

    typeset linux_srcdir=$(find $TMPDIR -type d -a -name "linux-*")
    typeset tests_srcdir="$linux_srcdir/tools/testing/selftests/kvm"
    typeset outputdir="${BINDIR}"
    typeset hwpf=$(uname -i)

    rlAssertExists $tests_srcdir
    rlAssertExists ${outputdir}

    rlRun "pushd '.'"

    # Build tests
    rlRun "make -C ${tests_srcdir} OUTPUT=${outputdir} TARGETS=kvm"

    # Prepare lists of tests to run
    getTests
    disableTests

    # Run tests
    for test in ${ALLARCH_TESTS[*]}; do rlRun "${outputdir}/${test}" 0,4; done
    [[ $hwpf == "x86_64" ]] && for test in ${X86_64_TESTS[*]}; do rlRun "${outputdir}/${test}" 0,4;  done
    [[ $hwpf == "aarch64" ]] && for test in ${AARCH64_TESTS[*]}; do rlRun "${outputdir}/${test}" 0,4;  done
    [[ $hwpf == "ppc64" || $hwpf == "ppc64le" ]] && for test in ${PPC64_TESTS[*]}; do rlRun "${outputdir}/${test}" 0,4; done
    [[ $hwpf == "s390x" ]] &&  for test in ${S390X_TESTS[*]}; do rlRun "${outputdir}/${test}" 0,4; done

    rlRun "popd"

    rlPhaseEnd
}

function setup
{
    typeset pkg=$PACKAGE

    rlPhaseStartSetup

    check

    if lsmod | grep --quiet kvm_intel; then
        rmmod kvm_intel; rmmod kvm
        modprobe kvm; modprobe kvm_intel
    elif lsmod | grep --quiet kvm_amd; then
        rmmod kvm_amd; rmmod kvm
        modprobe kvm; modprobe kvm_amd
    fi
    rlRun "rm -rf $TMPDIR && mkdir $TMPDIR"
    rlRun "rm -rf ${BINDIR} && mkdir -p ${BINDIR}/x86_64"

    rlRun "pushd '.'"

    # if running on rhel8, use python3
    if grep --quiet "release 8." /etc/redhat-release && [ ! -x /usr/bin/python ];then
        ln -s /usr/libexec/platform-python /usr/bin/python
    fi

    rlRun "cd $TMPDIR"
    if [ -x /usr/bin/dnf ]; then
        dnf download ${pkg} --source
    elif [ -x /usr/bin/yum ]; then
        yum download ${pkg} --source
    fi
    if [ ! -f $TMPDIR/${pkg}.src.rpm ]; then
        rlFetchSrcForInstalled $pkg
    fi
    typeset rpmfile=$(ls -1 $TMPDIR/${pkg}.src.rpm)
    rlAssertExists $rpmfile
    rlRun "ls -l $rpmfile"

    rlRun "rpm -ivh --define '_topdir $TMPDIR' $rpmfile" 0

    typeset linux_tarball=$(find $TMPDIR -name "linux*.tar.xz")
    rlAssertExists $linux_tarball
    rlRun "ls -l $linux_tarball"

    typeset tarball_dirname=$(dirname $linux_tarball)
    rlRun "cd $tarball_dirname"
    rlRun "tar Jxf $linux_tarball"

    rlRun "popd"

    rlPhaseEnd
}

function cleanup
{
    rlPhaseStartCleanup

    rlRun "rm -rf $TMPDIR"
    rlRun "rm -rf ${BINDIR}"

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
