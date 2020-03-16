#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/redhat-rpm-config/Regression/bz1619235-Incorrect-kernel-module-symbol-Requires
#   Description: Test for BZ#1619235 (Incorrect kernel module symbol Requires generation)
#   Author: Eva Mrakova <emrakova@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2018 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. ../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="redhat-rpm-config"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlIsRHEL '<8' || rlAssertRpm kernel-rpm-macros
        rlRun "TmpDir=\$(mktemp -d)" 0 "Create tmp directory"
        rlRun "cp test* $TmpDir"
        rlRun "pushd $TmpDir"
        rlRun "mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS"
        rlRun "mv *.tar.gz ~/rpmbuild/SOURCES"
        rlRun "mv *.spec ~/rpmbuild/SPECS"
    rlPhaseEnd

    rlPhaseStartTest
        # for proper rebuild of non-x86_64 arches ARCH has to be unset
        ARCHBACKUP=$ARCH
        unset ARCH
        uname -a
        rpm -q kernel kernel-devel
        KVER=$(uname -r)
        rlRun "rpmbuild -bp ~/rpmbuild/SPECS/testprov-kmod.spec"
        rlRun "rpmbuild -bp --nodeps ~/rpmbuild/SPECS/testreq-kmod.spec"
        # adjust sources to the proper kernel version
        rlRun "sed -i 's/4.18.0/$KVER/g' ~/rpmbuild/SPECS/testprov-kmod.spec ~/rpmbuild/SPECS/testreq-kmod.spec"
        rlRun -s "rpmbuild -bb ~/rpmbuild/SPECS/testprov-kmod.spec"
        TESTPROVRPM=$( awk '/Wrote:/ { print $2 }' $rlRun_LOG)
        rlRun -s "rpm -qp --provides $TESTPROVRPM" 0 "Get the testprov-kmod provides"
	    rlIsRHEL '<8' || rlAssertGrep "^kmod(testprov.ko)" $rlRun_LOG
        rlAssertGrep "^ksym(saa7146_vmalloc_build_pgtable) =" $rlRun_LOG
        rlRun "rpm -i $TESTPROVRPM"
        rlRun -s "rpmbuild -bb ~/rpmbuild/SPECS/testreq-kmod.spec"
        TESTREQRPM=$( awk '/Wrote:/ { print $2 }' $rlRun_LOG)
        rlRun -s "rpm -qp --requires $TESTREQRPM" 0 "Get the testreq-kmod requires"
        rlAssertNotGrep "^kernel(saa7146_vmalloc_build_pgtable) =" $rlRun_LOG
        rlAssertGrep "^ksym(saa7146_vmalloc_build_pgtable) =" $rlRun_LOG
        export ARCH=$ARCHBACKUP
        rlRun "rpm -i $TESTREQRPM"
        rlRun "modprobe testreq"
        rlRun "lsmod | grep testreq"
        rlRun "lsmod | grep testprov"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rmmod testreq"
        rlRun "rmmod testprov"
        rlRun "rpm -e testprov-kmod testreq-kmod" 0,1
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Remove tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
