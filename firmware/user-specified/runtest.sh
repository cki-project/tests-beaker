#!/bin/bash
# Copyright (c) 2019 Red Hat, Inc. All rights reserved. This copyrighted material
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

# Include rhts environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

# source fwts include/library
. ../include/runtest.sh || exit 1

# Include cki library
. ../../cki_lib/libcki.sh

# Default  Firmware tests
FWTSTESTS=${FWTSTESTS:-"--utils --batch --acpitests --acpicompliance"}

rlJournalStart
   if [[ -n $FWTSTESTS ]]; then	
       rlPhaseStartSetup
           fwtsSetup
       rlPhaseEnd

       rlPhaseStartTest
           rlLog "Running fwts with these tests: $FWTSTESTS"
           rlRun "fwts $FWTSTESTS" 0,1 "run fwts  tests: ${FWTSTESTS}"
           if [ $? -gt 1 ]; then
               fwtsCleanup
               cki_abort_task "Failed to run: fwts $FWTSTESTS"
           fi 
       rlPhaseEnd
       
       fwtsReportResults
       
       rlPhaseStartCleanup
           fwtsCleanup
       rlPhaseEnd
   else
       cki_abort_task "FWTSTESTS parameter is invalid, must be: --utils, --batch. --acpitests, or/and --acpicompliance"
   fi
rlJournalEnd
rlJournalPrintText
