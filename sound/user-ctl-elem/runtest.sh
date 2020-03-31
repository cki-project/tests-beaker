#!/bin/bash

#--------------------------------------------------------------------------------
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
#---------------------------------------------------------------------------------

# Source the common test script helpers
. ../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

TEST_ROOT=$(dirname $(readlink -f $BASH_SOURCE))

rlJournalStart

  rlPhaseStartSetup
    rlRun -l "modprobe snd-dummy" 0 "Load kernel module snd-dummy"
  rlPhaseEnd

  rlPhaseStartTest user-ctl
    rlRun -l "alsactl -f dummy.state restore" 0,99 "Create new CTL elemenents"
    rlRun -l "amixer -c Dummy cset name='User CTL Switch' 0,0"
    rlRun -l "amixer -c Dummy cget name='User CTL Switch'"
    rlRun -l "amixer -c Dummy cset name='User CTL Switch' 1,1"
    rlRun -l "amixer -c Dummy cget name='User CTL Switch'"
    rlRun -l "amixer -c Dummy cset name='User CTL Volume' 10,11"
    rlRun -l "amixer -c Dummy cget name='User CTL Volume'"
    rlRun -l "amixer -c Dummy cset name='User CTL Volume' 80,90"
    rlRun -l "amixer -c Dummy cget name='User CTL Volume'"
  rlPhaseEnd

  #rlPhaseStartCleanup
  #  rlRun -l "rmmod snd-dummy"
  #rlPhaseEnd

rlJournalEnd

rlJournalPrintText
