#!/bin/bash
#
# Copyright (c) 2019 Red Hat, Inc. All rights reserved.
#
# This copyrighted material is made available to anyone wishing
# to use, modify, copy, or redistribute it subject to the terms
# and conditions of the GNU General Public License version 2.
#
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
#

FILE=$(readlink -f ${BASH_SOURCE})
NAME=$(basename $FILE)
CDIR=$(dirname $FILE)
TEST=${TEST:-"$0"}
TMPDIR=/var/tmp/$(date +"%Y%m%d%H%M%S")

source $CDIR/../../cpu/common/libutil.sh

rlJournalStart
    # Setup phase: Prepare test directory
    rlPhaseStartSetup
    if [ ! -e /sys/devices/system/cpu/cpu0/topology/die_id ]; then
        cki_skip_task "the operating system does not have die support"
    fi
    rlPhaseEnd

    # Test phase: verifying die layout
    rlPhaseStartTest
        cki_run_cmd_pos "bash $CDIR/utils/verify-x86-die-support.sh"
    rlPhaseEnd

    # Cleanup phase: Remove test directory
    rlPhaseStartCleanup
        cki_run_cmd_neu "rm -f $TMPDIR"
    rlPhaseEnd
rlJournalEnd

# Print the test report
rlJournalPrintText
