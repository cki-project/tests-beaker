#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/stress/stress-ng
#   Description: Run stress-ng test
#   Author: Jeff Bastian <jbastian@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc. All rights reserved.
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

# include beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1


rlJournalStart

BUILDDIR="stress-ng"

# task parameters
TIMEOUT=${TIMEOUT:-30}
EXTRA_FLAGS=${EXTRA_FLAGS:-}
CLASSES=${CLASSES:-interrupt cpu cpu-cache memory os}

# stress-ng git location
GIT_URL=${GIT_URL:-"git://kernel.ubuntu.com/cking/stress-ng.git"}
# current release
GIT_BRANCH=${GIT_BRANCH:-"tags/V0.09.56"}

# initialize test exclusion lists
# NOTE: be sure to use the += operator to append to the exclusion list!!!
EXCLUDE=""
# cpu hotplug testing is handled in other Beaker tasks
EXCLUDE+=",cpu-online"
# RHEL uses SELinux, not AppArmor
EXCLUDE+=",apparmor"
# tests which trigger SELinux AVCs
EXCLUDE+=",mmapaddr,mmapfixed"
# tests which report fail
EXCLUDE+=",dnotify"
# tests which report error
EXCLUDE+=",bind-mount,dirdeep,daemon,exec,inode-flags,mlockmany,oom-pipe,spawn,swap,watchdog"
# systemd-coredump does not like these stressors
EXCLUDE+=",bad-altstack,opcode"
# fanotify fails on systems with many CPUs (>128?):
#     cannot initialize fanotify, errno=24 (Too many open files)
EXCLUDE+=",fanotify"
# sigsuspend often triggers slow path warnings until killed by the watchdog
EXCLUDE+=",sigsuspend"

ARCH=`uname -m`
# RHEL specific excludes
if rlIsRHEL 7 ; then
    EXCLUDE+=",chroot,idle-page,rtc"
    #rhel7 architecture specific excludes
    case ${ARCH} in
        ppc64)
            # fnctl invokes failed Interrupted system call
            EXCLUDE+=",fcntl"
            # kcmp reports SHIM_KCMP_FILE not implemented
            EXCLUDE+=",kcmp" 
        ;;
    esac
fi
# architecture specific excludes
case ${ARCH} in
    aarch64)
        # clone invokes oom-killer loop
        EXCLUDE+=",clone"
        # efivar with all CPUs triggers kernel panics, but works ok with 1 CPU?
        EXCLUDE+=",efivar"
        # fcntl returns Interrupted system call error"
        EXCLUDE+=",fcntl"
        ;;
    ppc64|ppc64le)
        # POWER does not have UEFI firmware
        EXCLUDE+=",efivar"
        # kill locks up the kernel on ppc64(le)
        EXCLUDE+=",kill"
        ;;
    s390x)
        # System z does not have UEFI firmware
        EXCLUDE+=",efivar"
        # dev test gets stuck in uninterruptible I/O (state D)
        EXCLUDE+=",dev"
        ;;
    x86_64)
        # x86 may have either UEFI or Legacy BIOS
        if [ ! -d /sys/firmware/efi/vars ] ; then
            EXCLUDE+=",efivar"
        fi
        ;;
esac
# finally, strip any leading or trailing commas
EXCLUDE=$(sed -e 's/^,//' -e 's/,$//' <<<$EXCLUDE)

rlPhaseStartSetup
    # if stress-ng triggers a panic and reboot, then abort the test
    if [ $REBOOTCOUNT -ge 1 ] ; then
        rlDie "Aborting due to system crash and reboot"
    fi

    rlLog "Downloading stress-ng from source"
    rlRun "git clone $GIT_URL" 0
    if [ $? != 0 ]; then
        echo "Failed to git clone $GIT_URL." | tee -a $OUTPUTFILE
        rhts-report-result $TEST WARN $OUTPUTFILE
        rhts-abort -t recipe
    fi

    # build
    rlLog "Building stress-ng from source"
    rlRun "pushd stress-ng" 0 
    rlRun "git checkout $GIT_BRANCH" 0
    rlRun "make" 0 "Building stress-ng"
    rlRun "popd" 0 "Done building stress-ng"

    #disable systemd-coredump collection
    if [ -f /lib/systemd/systemd ] ; then
        rlLog "Disabling systemd-coredump collection"
        if [ ! -d /etc/systemd/coredump.conf.d ] ; then
            mkdir /etc/systemd/coredump.conf.d
        fi
        cat >/etc/systemd/coredump.conf.d/stress-ng.conf <<EOF
[Coredump]
Storage=none
ProcessSizeMax=0
EOF
        rlRun "systemctl mask --now systemd-coredump.socket" 0 "Masking and stopping systemd-coredump.socket"
    fi
rlPhaseEnd

rlPhaseStartTest
    for CLASS in ${CLASSES} ; do
        FLAGS="--class ${CLASS} --sequential 0 --timeout ${TIMEOUT} --log-file ${CLASS}.log ${EXTRA_FLAGS}"
        if [ -n "${EXCLUDE}" ]; then
            FLAGS="${FLAGS} --exclude ${EXCLUDE}"
        fi

        rlRun "${BUILDDIR}/stress-ng ${FLAGS}" \
            0,2,3 "Running stress-ng on class ${CLASS} for ${TIMEOUT} seconds per stressor"
        RET=$?

        RESULT="FAIL"
        if [ $RET -eq 0 -o $RET -eq 2 -o $RET -eq 3  ] ; then
            RESULT="PASS"
        fi

        rlReport "Class ${CLASS}" ${RESULT} 0 ${CLASS}.log
    done
rlPhaseEnd

rlPhaseStartCleanup
    # restore default systemd-coredump config
    if [ -f /lib/systemd/systemd ] ; then
        rm -f /etc/systemd/coredump.conf.d/stress-ng.conf
        rlRun "systemctl unmask systemd-coredump.socket" 0 "Unmasking systemd-coredump.socket"
    fi
rlPhaseEnd

rlJournalPrintText
rlJournalEnd
