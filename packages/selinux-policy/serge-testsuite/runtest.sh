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

typeset -l debug=${_DEBUG}
[[ $debug =~ (yes|true) ]] && \
    export PS4='[${FUNCNAME}@${BASH_SOURCE}:${LINENO}|${SECONDS}]+ ' && set -x

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

# Include tests-specific libraries
. lib/common.sh || exit 1
. lib/concheck.sh || exit 1

PACKAGE="selinux-policy"

# Default commit to checkout from the repo.
# This should be updated as needed after verifying that the new version
# doesn't break testing and after applying all necessary tweaks in the TC.
# Run with GIT_BRANCH=master to run the latest upstream version.
DEFAULT_COMMIT="ea941e0a1f25be1cc8d1c51be920ead3428b5f93"
# Default pull requests to merge before running the test.
# If non-empty, then after checking out GIT_BRANCH the listed upstream pull
# requests (by number) are merged, creating a new temporay local branch.
DEFAULT_PULLS="54"

# Optional test parametr - location of testuite git.
GIT_URL=${GIT_URL:-"git://github.com/SELinuxProject/selinux-testsuite"}

# Optional test paramenter - branch containing tests.
if [ -z "$GIT_BRANCH" ]; then
    GIT_BRANCH="$DEFAULT_COMMIT"
    # Use default cherries only if branch is default and they are not overriden
    GIT_PULLS="${GIT_PULLS:-"$DEFAULT_PULLS"}"
fi

# Check if pipefail is enabled to restore original setting.
# See: https://unix.stackexchange.com/a/73180
if false | true; then
    PIPEFAIL_ENABLE="set -o pipefail"
    PIPEFAIL_DISABLE="set +o pipefail"
else
    PIPEFAIL_ENABLE=""
    PIPEFAIL_DISABLE=""
fi

function version_le() {
    { echo "$1"; echo "$2"; } | sort -V | tail -n 1 | grep -qx "$2"
}

function kver_ge() { version_le "$1" "$(uname -r)"; }
function kver_lt() { ! kver_ge "$1"; }
function kver_le() { version_le "$(uname -r)" "$1"; }
function kver_gt() { ! kver_le "$1"; }

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlAssertRpm audit
        rlAssertRpm kernel
        rlFileBackup /etc/selinux/semanage.conf
        # running the testsuite in /tmp causes permission denied messages
        # rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        # rlRun "pushd $TmpDir"

        # version_le() sanity check:
        rlRun "version_le 4.10 4.10"
        rlRun "version_le 4.10 4.10.0"
        rlRun "version_le 4.10 4.10.1"
        rlRun "! version_le 4.10 4.9"
        rlRun "! version_le 4.10.0 4.10"

        # make sure the right version of kernel[-rt]-modules-extra is installed
        if rlRun "yum=\$(which yum) || yum=\$(which dnf)"; then
            rlRun "$yum install -y kernel-modules-extra-$(uname -r)" 0-255
            rlRun "$yum install -y kernel-rt-modules-extra-$(uname -r)" 0-255
        fi

        # test turns this boolean off
        rlSEBooleanBackup allow_domain_fd_use
        # test expects that domains cannot map files by default
        rlSEBooleanOff domain_can_mmap_files

        rlRun "setenforce 1"
        rlRun "sestatus"
        rlRun "sed -i 's/^expand-check[ ]*=.*$/expand-check = 0/' /etc/selinux/semanage.conf"
        if [ ! -d selinux-testsuite ] ; then
            rlRun "git clone $GIT_URL" 0
            rlRun "pushd selinux-testsuite"
            rlRun "git checkout $GIT_BRANCH" 0
            for _ in $GIT_PULLS; do
                rlRun "git config --global user.email nobody@redhat.com"
                rlRun "git config --global user.name 'Nemo Nobody'"
                rlRun "git checkout -b testing-cherry-picks" 0
                break
            done
            for pull in $GIT_PULLS; do
                ref="refs/pull/$pull/head"
                if ! rlRun "git fetch origin $ref:$ref" 0; then
                    rlRun "git checkout $GIT_BRANCH" 0
                    rlLog "PR merge failed, falling back to GIT_BRANCH"
                    break
                fi
                if ! rlRun "git merge --no-edit $ref" 0; then
                    rlRun "git merge --abort" 0
                    rlRun "git checkout $GIT_BRANCH" 0
                    rlLog "PR merge failed, falling back to GIT_BRANCH"
                    break
                fi
            done
        else
            rlRun "pushd selinux-testsuite"
        fi

        # backup code before making tweaks
        rlFileBackup "."

        exclude_tests=""
        for file in ./tests/nnp*/execnnp.c; do
            rlRun "sed -i 's/3.18/3.9/' $file" 0 \
                "Fix up kernel version in nnp test"
        done
        if rlIsRHEL 6 ; then
            # the dev_rw_infiniband_dev macro is not defined in RHEL-6 policy
            # test_policy module compilation fails because of syntax error
            rlRun "sed -i 's/test_ibpkey.te//' ./policy/Makefile" 0 \
                "Disable test_ibpkey.te on RHEL6"
        fi
        if ! [ -x /usr/bin/python3 ]; then
            # to avoid error messages like runcon: ‘overlay/access’: No such file or directory
            rlRun "rpm -qa | grep python | sort"
            rlRun "sed -i 's/python3\$/python2/' tests/overlay/access" 0 \
                "Fix up Python shebang in overlay test"
        fi

        if kver_lt "3.10.0-349"; then
            # c4684bbdac07 [security] selinux: Permit bounded transitions under NO_NEW_PRIVS or NOSUID
            # da74590f6501 [security] selinux: reject setexeccon() on MNT_NOSUID applications with -EACCES
            exclude_tests+=" nnp_nosuid"
        fi

        if kver_lt "3.10.0-693"; then
            # I don't know when exactly this test starts passing, so I'm just
            # disabling it for anything below the RHEL-7.4 kernel...
            exclude_tests+=" inet_socket"
        fi

        if kver_lt "3.10.0-875"; then
            rlLog "No xperms support => disable xperms testing"
            rlRun "sed -i '/TARGETS += test_ioctl_xperms\.te/d' policy/Makefile"
            rlRun "sed -i 's/\$kernver >= 30/\$kernver >= 999999/' tests/ioctl/test"
        fi
        # workaround for https://bugzilla.redhat.com/show_bug.cgi?id=1613056
        # (if running kernel version sorts inside the known-bug window, then
        # we need to apply the workaround)
        if kver_ge "3.10.0-875" && kver_lt "3.10.0-972"; then
            rlLog "Applying workaround for BZ 1613056..."
            rlRun "cat >>policy/test_ipc.te <<<'allow_map(ipcdomain, tmpfs_t, file)'"
            rlRun "cat >>policy/test_mmap.te <<<'allow_map(test_execmem_t, tmpfs_t, file)'"
            rlRun "cat >>policy/test_mmap.te <<<'allow_map(test_no_execmem_t, tmpfs_t, file)'"
        fi

        if kver_lt "4.18.0-80.19"; then
            exclude_tests+=" cgroupfs_label"
        fi

        if [ -n "$exclude_tests" ] ; then
            rlRun "sed -i '/^[^[:space:]]*:\(\| .*\)\$/i SUBDIRS:=\$(filter-out $exclude_tests, \$(SUBDIRS))' tests/Makefile" 0 \
                "Exclude not applicable tests: $exclude_tests"
        fi

        if ! modprobe sctp 2>/dev/null; then
            script1='s/runcon -t test_sctp_socket_t/true/g'
            script2='s/runcon -t test_no_sctp_socket_t/false/g'
            rlRun "sed -i -e '$script1' -e '$script2' ./tests/extended_socket_class/test" 0 \
                "No SCTP support => fix up extended_socket_class test"
        fi

        # on aarch64 and s390x the kernel support for Bluetooth is turned
        # off so we disable the Bluetooth socket tests there
        case "$(rlGetPrimaryArch)" in
            aarch64|s390x)
                script1='s/runcon -t test_bluetooth_socket_t/true/g'
                script2='s/runcon -t test_no_bluetooth_socket_t/false/g'
                rlRun "sed -i -e '$script1' -e '$script2' ./tests/extended_socket_class/test" 0 \
                    "No Bluetooth support => fix up extended_socket_class test"
                ;;
        esac

        # Initialize report.
        rlRun "echo 'Remote: $GIT_URL' >results.log" 0
        rlRun "echo 'Branch: $GIT_BRANCH' >>results.log" 0
        rlRun "echo 'Commit: $(git rev-parse $GIT_BRANCH)' >>results.log" 0
        rlRun "echo 'GH PRs: ${GIT_PULLS:-"(none)"}' >>results.log" 0
        rlRun "echo 'Kernel: $(uname -r)' >>results.log" 0
        rlRun "echo 'Policy: $(rpm -q selinux-policy)' >>results.log" 0
        rlRun "echo '        $(rpm -q checkpolicy)' >>results.log" 0
        rlRun "echo '        $(rpm -q libselinux)' >>results.log" 0
        rlRun "echo '        $(rpm -q libsemanage)' >>results.log" 0
        rlRun "echo '        $(rpm -q libsepol)' >>results.log" 0
        rlRun "echo '        $(rpm -q policycoreutils)' >>results.log" 0
        rlRun "echo '' >>results.log" 0

    rlPhaseEnd

    rlPhaseStartTest
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
        # rlSEBooleanRestore
        # rlSEBooleanRestore allow_domain_fd_use
        # none of above-mentioned commands is able to correctly restore the value in the boolean
        rlRun "setsebool allow_domain_fd_use on"

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

