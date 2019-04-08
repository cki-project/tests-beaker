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
PACKAGE="kernel"
TMPDIR=/var/tmp/$(date +"%Y%m%d%H%M%S")

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
    rlAssertExists $tests_srcdir

    #
    # XXX: Apply a patch because case 'dirty_log_test' fails to be built, which
    #      is because patch [1] is missed when backporting to RHEL8 repo. Note
    #      we should remove the workaround if the case is fixed.
    #      [1] https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=07a262cc
    #
    rlRun "patch -d $linux_srcdir -p1 < patches/bitmap.h.patch" 0 \
          "Patching via patches/bitmap.h.patch"

    rlRun "pushd '.'"
    rlRun "cd $tests_srcdir && make TARGETS=kvm run_tests" 0 \
          "Running kvm selftests"
    (( $? == 0 )) && rlPass $TEST || rlFail $TEST

    rlRun "popd"

    rlPhaseEnd
}

function setup
{
    typeset pkg=$PACKAGE

    rlPhaseStartSetup

    check

    rlRun "rm -rf $TMPDIR && mkdir $TMPDIR"

    rlRun "pushd '.'"

    rlRun "cd $TMPDIR"
    rlFetchSrcForInstalled $pkg
    typeset rpmfile=$(ls -1 $TMPDIR/${pkg}*.src.rpm)
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
