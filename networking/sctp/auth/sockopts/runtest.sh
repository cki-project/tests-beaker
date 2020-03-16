#!/bin/sh

# Copyright (c) 2015 Red Hat, Inc. All rights reserved. This copyrighted material 
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Jianwen Ji: <jiji@redhat.com> 

# include common  and Beaker environments
. ../../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1
. ./common/include.sh || exit 1

rlJournalStart

########################## Setup ################################
OUTPUTFILE=$(new_outputfile)

rlPhaseStartSetup
    YUM=$(cki_get_yum_tool)
    kernel_name=$(uname -r)
    if [[ $kernel_name =~ "rt" ]]; then
        echo "running the $kernel_name" | tee -a $OUTPUTFILE
        $YUM install -y kernel-rt-modules-extra
    fi
    rlRun "$YUM install -y lksctp-tools-devel gcc" 0
    rlRun "lsmod | grep sctp || modprobe sctp" "0-255"
    rlRun "sysctl -w net.sctp.auth_enable=1" 0
    rlRun "sysctl -w net.sctp.addip_enable=1" 0
    rlRun "./make_register_tests.sh test_cases.c test_sctp_sockopts.c" 0
    rlRun "gcc -I ./lib -o api_tests ./lib/sctp_utilities.c test_sctp_sockopts.c test_cases.c api_tests.c -lsctp" 0
rlPhaseEnd

##################### Start Test #################################
rlPhaseStartTest
    run "./api_tests" 0 "Done running API tests"
    grep 'FAILED' $OUTPUTFILE && rlReport $TEST FAIL || \
		rlReport $TEST PASS 
    rstrnt-report-log -l $OUTPUTFILE
rlPhaseEnd

####################### Restore #################################
rlPhaseStartCleanup
    rlRun "sysctl -w net.sctp.addip_enable=0" 0
    rlRun "sysctl -w net.sctp.auth_enable=0" 0
    make clean
rlPhaseEnd

rlJournalPrintText
rlJournalEnd
