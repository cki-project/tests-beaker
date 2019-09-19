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

source $CDIR/../../../cki_lib/libcki.sh

#
# Check CPU vendor is Intel or not
#
function is_intel
{
    typeset vendor=$(grep vendor /proc/cpuinfo | sort -u | awk '{print $3}')
    [[ $vendor == "GenuineIntel" ]] && return 0 || return 1
}

#
# Check the system is kvm or not
#
function is_kvm
{
    [[ $(virt-what) == "kvm" ]] && return 0 || return 1
}

function do_sanity_test
{
    cki_run_cmd_pos "bash $CDIR/utils/cpupower_sanity_test.sh" || return 1
    return 0
}

function startup
{
    is_kvm
    if (( $? == 0 )); then
        cki_set_reason $CKI_UNSUPPORTED "kvm is unsupported"
        return $CKI_UNSUPPORTED
    fi

    is_intel
    if (( $? != 0 )); then
        cki_set_reason $CKI_UNSUPPORTED "non-intel CPU is unsupported"
        return $CKI_UNSUPPORTED
    fi

    cpupower -c 0 frequency-info | egrep "Active:.*yes" > /dev/null 2>&1
    if (( $? != 0 )); then
        cki_set_reason $CKI_UNSUPPORTED "cpufreq driver is not active"
        return $CKI_UNSUPPORTED
    fi

    cki_run_cmd_neu "uname -srvm"
    cki_run_cmd_neu "cpupower -c 0 frequency-info"

    if [[ ! -d $TMPDIR ]]; then
        cki_run_cmd_pos "mkdir -p -m 0755 $TMPDIR" || return $CKI_UNINITIATED
    fi

    return $CKI_PASS
}

function cleanup
{
    cki_run_cmd_neu "rm -rf $TMPDIR"
    return $CKI_PASS
}

function runtest
{
    do_sanity_test || return $CKI_FAIL
    return $CKI_PASS
}

cki_main
exit $?
