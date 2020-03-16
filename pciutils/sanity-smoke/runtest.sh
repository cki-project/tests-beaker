#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of pciutils sanity smoke
#   Description: test whether lspci works
#   Author: Michal Nowak <mnowak@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 3 of
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

# include libraries
. /usr/share/beakerlib/beakerlib.sh || exit 1
. ../../cki_lib/libcki.sh || exit 1

PACKAGE="pciutils"

YUM=$(cki_get_yum_tool)
kernel_name=$(uname -r)

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        if [[ $kernel_name =~ "rt" ]]; then
            echo "running the $kernel_name" | tee -a $OUTPUTFILE
            $YUM install -y kernel-rt-modules-extra
        fi
    rlPhaseEnd

    rlPhaseStartTest
    if [ "$(ls -A /sys/bus/pci/devices)" ]; then #system does have pci bus
        lspci -nn | grep '\[[[:xdigit:]]\{4\}:[[:xdigit:]]\{4\}\]' > lspci.out
        cat lspci.out | tee -a $OUTPUTFILE
        rlAssertGreater "lspci works" "$(cat lspci.out | wc -l)" 0
        rm lspci.out
    else
        echo "System does not have PCI BUS" | tee -a $OUTPUTFILE
        rstrnt-report-result $TEST SKIP $OUTPUTFILE
        exit 0
    fi
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
