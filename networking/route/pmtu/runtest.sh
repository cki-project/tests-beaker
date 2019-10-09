#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of kernel/networking/route/mr
#   Description:  Multicast routing testing
#   Author: Jianlin Shi<jishi@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc.
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
. ./common/include.sh || exit 1
. ./common/network.sh || exit 1
. ./common/service.sh || exit 1
. ./common/install.sh || exit 1
. ../../../cki_lib/libcki.sh || exit 1

YUM=$(cki_get_yum_tool)

kernel_name=$(uname -r)
if [[ $kernel_name =~ "rt" ]]; then
     echo "running the $kernel_name" | tee -a $OUTPUTFILE
     $YUM install -y kernel-rt-modules-extra
fi

# Functions



# Parameters
TEST_TYPE=${TEST_TYPE:-"netns"}
TEST_TOPO=${TEST_TOPO:-"default"}
SEC_TYPE=${SEC_TYPE:-"nosec ipsec"}
TESTMASK="yes"

. ./include.sh || exit 1


TEST_ITEMS=${TEST_ITEMS:-$TEST_ITEMS_ALL}
rlJournalStart

rlPhaseStartSetup

    rlRun "lsmod | grep sctp || modprobe sctp" "0-255"
    rlRun "iproute_upstream_install"

    rlRun "netperf_install"


    rlLog "items include:$TEST_ITEMS"
rlPhaseEnd

for DO_SEC in $SEC_TYPE
do
    pmtu_test
done

rlJournalEnd
