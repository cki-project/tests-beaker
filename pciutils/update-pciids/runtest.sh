#!/bin/bash
# vim: set dictionary=/usr/share/rhts-library/dictionary.vim cpt=.,w,b,u,t,i,k:
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Michal Nowak <mnowak@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright © 2009 Red Hat, Inc. All rights reserved.
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
#
# Include rhts environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/rhts-library/rhtslib.sh || exit 1
. ../../cki_lib/libcki.sh || exit 1

PACKAGE="pciutils"
PCI_IDS="/usr/share/hwdata/pci.ids"

YUM=$(cki_get_yum_tool)
kernel_name=$(uname -r)

rlJournalStart
    rlPhaseStartSetup Setup
        rlAssertRpm ${PACKAGE}
        rlFileBackup ${PCI_IDS}
        if [[ $kernel_name =~ "rt" ]]; then
            echo "running the $kernel_name"
            $YUM install -y kernel-rt-modules-extra
        fi
    rlPhaseEnd

    rlPhaseStartTest Testing
        rlRun "lspci > lspci.old"
	cat lspci.old
        rlRun "update-pciids" 0 "Successfully ran pciids update"
        rlRun "lspci > lspci.new"
	cat lspci.new
	diff -pruN lspci.old lspci.new
    rlPhaseEnd

    rlPhaseStartCleanup Cleanup
        rlBundleLogs "$PACKAGE-outputs" lspci.old lspci.new /usr/share/hwdata/pci.ids
        rlFileRestore
	rm lspci.old lspci.new
    rlPhaseEnd
rlJournalPrintText
