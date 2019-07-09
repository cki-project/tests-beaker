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

source ${CDIR%/cpu/idle}/cpu/common/libbkrm.sh
source ${CDIR%/cpu/idle}/cpu/common/libutil.sh

function runtest
{
    rlRun "bash $CDIR/utils/idle-power-test.sh $CDIR/utils/busy.sh" || \
          return $BKRM_FAIL
    return $BKRM_PASS
}

function startup
{
    if [[ ! -d $TMPDIR ]]; then
        rlRun "mkdir -p -m 0755 $TMPDIR" || return $BKRM_FAIL
    fi

    # setup msr tools as package 'msr-tools' is not installed by default
    msr_tools_setup || return $?
    if (( $? != 0 )); then
        rlSetReason $BKRM_FATAL "fail to setup msr tools"
        return $BKRM_FATAL
    fi

    # check this test is supported by CPU
    rlRun "rdmsr 0x606" || rlSkip "su access is not available"
    if (( $? != 0 )); then
        rlSetReason $BKRM_UNSUPPORTED \
            "su access is not available"
        return $BKRM_UNSUPPORTED
    fi

    return $BKRM_PASS
}

function cleanup
{
    msr_tools_cleanup || return $BKRM_FAIL
    rlRun "rm -rf $TMPDIR" $BKRM_RC_ANY
    return $BKRM_PASS
}

main
exit $?
