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

function runtest
{
    cki_run_cmd_pos "bash $CDIR/utils/idle-power-test.sh $CDIR/utils/busy.sh"
    status=$?
    if [ $status -eq 0 ]; then
	return $CKI_PASS
    elif [ $status -eq 2 ]; then
	# maps to SKIP
	return $CKI_UNSUPPORTED
    fi
    return $CKI_FAIL
}

function startup
{
    cki_run_cmd_pos "lscpu | grep ' monitor '"
    [ $? -ne 0 ] && cki_skip_task "system does not support mwait"

    if [[ ! -d $TMPDIR ]]; then
        cki_run_cmd_pos "mkdir -p -m 0755 $TMPDIR"
        [ $? -ne 0 ] && return $CKI_UNINITIATED
    fi

    # setup msr tools as package 'msr-tools' is not installed by default
    msr_tools_setup
    if [ $? -ne 0 ]; then
        cki_set_reason $CKI_UNINITIATED "fail to setup msr tools"
        return $CKI_UNINITIATED
    fi

    # check this test is supported by CPU
    cki_run_cmd_pos "rdmsr 0x606"
    [ $? -ne 0 ] && cki_skip_task "su access is not available"

    return $CKI_PASS
}

function cleanup
{
    msr_tools_cleanup
    cki_run_cmd_neu "rm -rf $TMPDIR"
    return $CKI_PASS
}

cki_main
exit $?
