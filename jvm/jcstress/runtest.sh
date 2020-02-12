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
# This script downloads a jar test file
# and executes the test against localhost

# See https://github.com/guozheng/jmh-tutorial/blob/master/README.md
# for more information.
#---------------------------------------------------------------------------------

# Source the common test script helpers
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
# Run jcstress test
  rlPhaseStartTest
    rlRun -l "mvn archetype:generate  -DinteractiveMode=false  -DarchetypeGroupId=org.openjdk.jcstress \
              -DarchetypeArtifactId=jcstress-java-test-archetype  -DgroupId=org.sample \
              -DartifactId=test  -Dversion=1.0"
    if [ $? -ne 0 ]; then
        rstrnt-abort -t recipe
        exit 0
    fi
    rlRun -l "cd test"
    rlRun -l "mvn clean install"
    if [ $? -ne 0 ]; then
        rstrnt-abort -t recipe
        exit 0
    fi
    rlRun -l "java -jar target/jcstress.jar"
  rlPhaseEnd

rlJournalEnd
rlJournalPrintText
