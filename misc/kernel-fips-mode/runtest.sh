#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of kernel-fips-mode
#   Description: Test kernel FIPS 140 mode.
#   Author: Ondrej Moris <omoris@redhat.com>
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

# Include Beaker environment
. /usr/bin/rhts-environment.sh
. /usr/share/beakerlib/beakerlib.sh

rlJournalStart

    # Before first reboot (FIPS mode is disabled).
    if [ ! -e /var/tmp/fips-enabled ] && [ ! -e /var/tmp/fips-disabled ]; then

        # SETUP.
        rlPhaseStartSetup
        
            # Woraround for kernel hmac missing on CKI kernel.
            kernel="vmlinuz-$(uname -r)"
            if ! [ -s "/boot/.${kernel}.hmac" ]; then
                rlRun "cp /boot/.${kernel}.hmac /boot/.${kernel}.hmac.backup" 0
                rlRun "sha512hmac /boot/$kernel > /boot/.${kernel}.hmac" 0
            fi

            # Enable FIPS mode.
            rlRun "fips-mode-setup --enable" 0

            # Create reboot indication file.
            rlRun "touch /var/tmp/fips-enabled" 0

        rlPhaseEnd

        # Reboot.
        rstrnt-reboot

    # After second reboot (FIPS mode is disabled again).
    elif [ -e /var/tmp/fips-disabled ]; then

        # VERIFICATION (2/2).
        rlPhaseStartTest

            rlRun -s "fips-mode-setup --check" 0
            rlAssertGrep "disabled" $rlRun_LOG

        rlPhaseEnd

        # CLEAN-UP (2/2).
        rlPhaseStartCleanup

            # Remove reboot indication file.
            rlRun "touch /var/tmp/fips-disabled" 0

        rlPhaseEnd

        rlJournalPrintText

        rlJournalEnd

        exit 0
    fi

    # VERIFICATION (1/2).
    rlPhaseStartTest

        # Check the state of FIPS mode.
        rlRun -s "fips-mode-setup --check" 0
        rlAssertGrep "enabled" $rlRun_LOG

    rlPhaseEnd

    # CLEAN-UP (1/2).
    rlPhaseStartCleanup

        # Remove reboot indication file.
        rlRun "rm -f /var/tmp/fips-enabled" 0

        # Woraround for kernel hmac missing on CKI kernel - restore.
        kernel="vmlinuz-$(uname -r)"
        if [ -e "/boot/.${kernel}.hmac.backup" ]; then
            rlRun "mv /boot/.${kernel}.hmac.backup /boot/.${kernel}.hmac" 0
        fi
        
        # Disable FIPS mode.
        rlRun "fips-mode-setup --disable" 0
        rlRun "rm -f /etc/dracut.conf.d/40-fips.conf /etc/system-fips && dracut -v -f" 0

        # Create reboot indication file.
        rlRun "touch /var/tmp/fips-disabled" 0

    rlPhaseEnd

    rstrnt-reboot

rlJournalPrintText

rlJournalEnd
