#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Sanity/serge-testsuite
#   Description: functional test suite for the LSM-based SELinux security module
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"

# Optional test parametr - location of testuite git.
GIT_URL=${GIT_URL:-"git://github.com/SELinuxProject/selinux-testsuite"}

# Optional test paramenter - branch containing tests.
GIT_BRANCH=${GIT_BRANCH:-"master"}

# Check if pipefail is enabled to restore original setting.
# See: https://unix.stackexchange.com/a/73180
if false | true; then
    PIPEFAIL_ENABLE="set -o pipefail"
    PIPEFAIL_DISABLE="set +o pipefail"
else
    PIPEFAIL_ENABLE=""
    PIPEFAIL_DISABLE=""
fi

rlJournalStart
    rlPhaseStartSetup
        rlImport "selinux-policy/common"
        rlAssertRpm ${PACKAGE}
        rlAssertRpm audit
        rlAssertRpm kernel
        rlFileBackup /etc/selinux/semanage.conf
        # running the testsuite in /tmp causes permission denied messages
        # rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        # rlRun "pushd $TmpDir"

        # test turns this boolean off
        rlSEBooleanBackup allow_domain_fd_use
        # test expects that domains cannot map files by default
        rlSEBooleanOff domain_can_mmap_files

        rlRun "setenforce 1"
        rlRun "sestatus"
        rlRun "sed -i 's/^expand-check[ ]*=.*$/expand-check = 0/' /etc/selinux/semanage.conf"
        if [ ! -d selinux-testsuite ] ; then
            rlRun "git clone $GIT_URL" 0
        fi
        rlRun "pushd selinux-testsuite"
        rlRun "git checkout $GIT_BRANCH" 0 
        if [ -f ./tests/nnp/execnnp.c ] ; then
            rlRun "sed -i 's/3.18/3.9/' ./tests/nnp/execnnp.c"
        fi
        if rlIsRHEL 6 ; then
            # the dev_rw_infiniband_dev macro is not defined in RHEL-6 policy
            # test_policy module compilation fails because of syntax error
            rlRun "sed -i 's/test_ibpkey.te//' ./policy/Makefile"
        fi
        if rlIsRHEL 8 ; then
            # to avoid error messages like runcon: ‘overlay/access’: No such file or directory
            rlRun "rpm -qa | grep python | sort"
            if ! grep -q python3 tests/overlay/access ; then
                rlRun "sed -i 's/python/python3/' tests/overlay/access"
            fi
        fi

        # Initialize report.
        rlRun "echo 'Remote: $GIT_URL' >results.log" 0
        rlRun "echo 'Branch: $GIT_BRANCH' >>results.log" 0
        rlRun "echo 'Commit: $(git rev-parse HEAD)' >>results.log" 0
        rlRun "echo 'Kernel: $(uname -r)' >>results.log" 0
        rlRun "echo 'Policy: $(rpm -q selinux-policy)' >>results.log" 0
        rlRun "echo '        $(rpm -q checkpolicy)' >>results.log" 0
        rlRun "echo '        $(rpm -q libselinux)' >>results.log" 0
        rlRun "echo '        $(rpm -q libsemanage)' >>results.log" 0
        rlRun "echo '        $(rpm -q libsepol)' >>results.log" 0
        rlRun "echo '        $(rpm -q policycoreutils)' >>results.log" 0
        rlRun "echo '        $(rpm -q secilc)' >>results.log" 0
        rlRun "echo '' >>results.log" 0

    rlPhaseEnd

    rlPhaseStartTest
        rlRun "modprobe sctp" 0,1
        if pwd | grep selinux-testsuite ; then
            MYTMP="$DISTRO"
            unset DISTRO
            rlRun "make" 0
            rlRun "cat results.log" 0
            $PIPEFAIL_ENABLE
            rlRun "LANG=C unbuffer make -s test 2>&1 | tee -a results.log" 0
            $PIPEFAIL_DISABLE
            export DISTRO="$MYTMP"
        else
            rlLog "GIT was unable to clone the testsuite repo"
            report_result $TEST WARN
            rhts-abort -t recipe
        fi
    rlPhaseEnd

    rlPhaseStartCleanup

        rlSEBooleanRestore

        # Submit report to beaker.
        rlFileSubmit "results.log" "selinux-testsuite.results.$(uname -r).txt"
        rlRun "make clean" 0-2
        rlRun "popd"
        rlRun "semodule -r test_policy" 0,1
        sleep 5
        rlRun "dmesg | grep -i \"rcu_sched detected stalls\"" 1
        rlFileRestore
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

