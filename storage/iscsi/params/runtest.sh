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

source $CDIR/../../../storage/include/libstqe.sh

function startup
{
    stqe_init_fwroot "master"
}

function cleanup
{
    stqe_fini_fwroot
}

function runtest
{
    typeset fwroot=$(stqe_get_fwroot)
    cki_cd $fwroot
    cki_run_cmd_pos "stqe-test run -t iscsi/iscsi_params.py"
    typeset -i rc=$?
    cki_pd
    (( rc != 0 )) && return $CKI_FAIL || return $CKI_PASS
}

cki_debug
cki_main
exit $?
