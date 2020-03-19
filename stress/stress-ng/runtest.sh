#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/stress/stress-ng
#   Description: Run stress-ng test
#   Author: Jeff Bastian <jbastian@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc. All rights reserved.
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

# Mustangs have a hardware flaw which causes kernel warnings under stress:
#    list_add corruption. prev->next should be next
if type -p dmidecode >/dev/null ; then
    if dmidecode -t1 | grep -q 'Product Name:.*Mustang.*' ; then
        rstrnt-report-result $TEST SKIP $OUTPUTFILE
        exit
    fi
fi

rlJournalStart

BUILDDIR="stress-ng"

# task parameters
# stress-ng git location
GIT_URL=${GIT_URL:-"git://kernel.ubuntu.com/cking/stress-ng.git"}
# current release
GIT_BRANCH=${GIT_BRANCH:-"tags/V0.09.56"}

CLASSES="interrupt cpu cpu-cache memory os"

rlPhaseStartSetup
    # if stress-ng triggers a panic and reboot, then abort the test
    if [ $REBOOTCOUNT -ge 1 ] ; then
        rlDie "Aborting due to system crash and reboot"
        rstrnt-abort -t recipe
    fi

    rlLog "Downloading stress-ng from source"
    rlRun "git clone $GIT_URL" 0
    if [ $? != 0 ]; then
        echo "Failed to git clone $GIT_URL." | tee -a $OUTPUTFILE
        rstrnt-report-result $TEST WARN $OUTPUTFILE
        rstrnt-abort -t recipe
    fi

    # build
    rlLog "Building stress-ng from source"
    rlRun "pushd stress-ng" 0
    rlRun "git checkout $GIT_BRANCH" 0
    rlRun "make" 0 "Building stress-ng"
    rlRun "popd" 0 "Done building stress-ng"

    # disable systemd-coredump collection
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
        if systemctl list-units --all | grep -qw systemd-coredump.socket ; then
            rlRun "systemctl mask --now systemd-coredump.socket" 0 "Masking and stopping systemd-coredump.socket"
        fi
    fi

    # blacklist tests on certain arch or RHEL release
    if [ "$(uname -i)" = "ppc64le" ]; then
        # TODO: open BZ: vforkmany triggers kernel "BUG: soft lockup" on ppc64le
        sed -ie '/vforkmany/d' os.stressors
    fi

    if [[ "$(uname -r)" =~ 3.10.0.*rt.*el7 ]]; then
        # https://bugzilla.redhat.com/show_bug.cgi?id=1789039
        sed -ie '/af-alg/d' cpu.stressors
    fi

rlPhaseEnd

rlPhaseStartTest
    for CLASS in ${CLASSES} ; do
        while read STRESSOR ; do
            [[ ${STRESSOR} =~ ^# ]] && continue
            LOG=$(grep -o '[[:alnum:]]*\.log' <<<${STRESSOR})
            rlRun "${BUILDDIR}/stress-ng ${STRESSOR}" 0,2,3
            [ $? -eq 0 -o $? -eq 2 -o $? -eq 3 ] && RESULT="PASS" || RESULT="FAIL"
            rlReport "${CLASS}: ${STRESSOR}" ${RESULT} 0 ${LOG}
        done < ${CLASS}.stressors
    done
rlPhaseEnd

rlPhaseStartCleanup
    # restore default systemd-coredump config
    if [ -f /lib/systemd/systemd ] ; then
        rm -f /etc/systemd/coredump.conf.d/stress-ng.conf
        if systemctl list-units --all | grep -qw systemd-coredump.socket ; then
            rlRun "systemctl unmask systemd-coredump.socket" 0 "Unmasking systemd-coredump.socket"
        fi
    fi
rlPhaseEnd

rlJournalPrintText
rlJournalEnd
