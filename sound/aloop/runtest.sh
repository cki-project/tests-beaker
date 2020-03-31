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

PYTHON=${PYTHON:-python}
if [[ -x /usr/bin/python ]]; then
        PYTHON=/usr/bin/python
elif [[ -x /usr/bin/python2 ]]; then
        PYTHON=/usr/bin/python2
elif [[ -x /usr/bin/python3 ]]; then
        PYTHON=/usr/bin/python3
elif [[ -x /usr/libexec/platform-python ]]; then
        PYTHON=/usr/libexec/platform-python
fi

function dummy() {
  rlPhaseStartTest $1
    rlRun -l "aplay -D hw:Dummy $2 -f dat -d 12 s.raw" 0 "Playing test wave"
  rlPhaseEnd
}

function aloop() {
  rlPhaseStartTest $1
    arecord -D hw:Loopback,1 $2 -f dat -t raw -d 12 a.raw &
    if [ $? -ne 0 ]; then
      rstrnt-abort -t recipe
      exit 0
    fi
    rlLog "Recording started"
    PID=$!
    rlRun -l "aplay -D hw:Loopback $2 -f dat -d 12 s.raw" 0 "Playing test wave"
    rlWait $PID
    size=$(stat --printf="%s" a.raw)
    rlLog "Recording finished ($size bytes)"
    rlRun -l "$PYTHON data.py check s.raw" 0 "Testing recorded samples"
  rlPhaseEnd
}

rlJournalStart

  rlPhaseStartSetup
    rlRun -l "modprobe snd-dummy" 0 "Load kernel module snd-dummy"
    rlRun -l "modprobe snd-aloop" 0 "Load kernel module snd-aloop"
    rlRun -l "$PYTHON data.py generate s.raw" 0 "Generate test samples"
  rlPhaseEnd

  dummy "dummy-rw" ""
  dummy "dummy-rw-nonblock" "--nonblock"
  dummy "dummy-mmap" "--mmap"
  dummy "dummy-mmap-nonblock" "--mmap --nonblock"

  aloop "aloop-rw" ""
  aloop "aloop-rw-nonblock" "--nonblock"
  aloop "aloop-mmap" "--mmap"
  aloop "aloop-mmap-nonblock" "--mmap --nonblock"

  rlPhaseStartCleanup
    rlRun -l "rm -f s.raw a.raw"
    #rlRun -l "rmmod snd-aloop"
    #rlRun -l "rmmod snd-dummy"
  rlPhaseEnd

rlJournalEnd

rlJournalPrintText
