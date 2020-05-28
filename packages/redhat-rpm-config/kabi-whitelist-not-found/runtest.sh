#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/redhat-rpm-config/Regression/bz1126086-kabi-whitelist-not-found
#   Description: Test for BZ#1126086 (KERNEL ABI COMPATIBILITY WARNING when building any)
#   Author: Karel Srot <ksrot@redhat.com>
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
. ../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="redhat-rpm-config"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlAssertRpm kernel-abi-whitelists
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
    rlPhaseEnd

    rlPhaseStartTest "Checking validity of current path"
	grep kabi_file= /usr/lib/rpm/redhat/find-requires.ksyms
	rlRun "arch=\$( uname -i | sed 's/i386/i686/' )"
	KABIFILE=`grep 'kabi_file=' /usr/lib/rpm/redhat/find-requires.ksyms | cut -d = -f 2 | sed 's/"//g'`
	echo $KABIFILE
	rlRun "ls `echo $KABIFILE | sed 's/\\\$arch/*/'`"
	rlAssertExists `echo $KABIFILE | sed "s/\\\$arch/$arch/"`
    rlPhaseEnd

    rlPhaseStartTest "Checking if we are using kabi-current symlink"
	rlAssertGrep 'kabi_file="/lib/modules/kabi-current/kabi_whitelist_$arch"' /usr/lib/rpm/redhat/find-requires.ksyms
	rlAssertExists /lib/modules/kabi-current/kabi_whitelist_$arch
	ls -ld /lib/modules/kabi-*
        rlRun "test -L /lib/modules/kabi-current"
	rlRun "TARGET=\$( readlink -f /lib/modules/kabi-current )"
	rlAssertExists $TARGET
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
