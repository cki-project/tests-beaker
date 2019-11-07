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

FILE=$(readlink -f $BASH_SOURCE)
CDIR=$(dirname $FILE)
TMPDIR=/var/tmp/$(date +"%Y%m%d%H%M%S")

source $CDIR/../../common/libpwmgmt.sh

function runtest
{
    cki_log "This test checks that current frequency is between min and max" \
            "frequency and these two has plausible values"

    # Dump sysinfo
    cki_run_cmd_neu "uname -srvm"
    cki_run_cmd_neu "lscpu"
    cki_run_cmd_neu "dmidecode | grep -A 3 'BIOS Information'"

    # Dump cpu0/cpufreq/cpuinfo_{max,cur,min}_freq
    typeset file1="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"
    typeset file2="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq"
    ls $file2 > /dev/null 2>&1 ||
            file2="/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
    typeset file3="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq"
    typeset filex=""
    for filex in $file1 $file2 $file3; do
        cki_run_cmd_neu "cat $filex"
    done

    typeset max_freq=$(egrep [0-9] $file1)
    typeset cur_freq=$(egrep [0-9] $file2)
    typeset min_freq=$(egrep [0-9] $file3)
    cki_log "CPU max     frequency: $max_freq"
    cki_log "CPU min     frequency: $min_freq"
    cki_log "CPU current frequency: $cur_freq"

    #
    # Verify max/min/current frequency, and the rules are:
    # 1. current frequency should not less    than min frequency
    # 2. current frequency should not greater than max frequency
    # 3. lowest  frequency would be at least 300MHz
    # 4. highest frequency would be at most    8GHz
    #
    (( $cur_freq < $min_freq )) && return $CKI_FAIL
    cki_log "+OK: current frequency ($cur_freq) >= min frequency ($min_freq)"
    (( $cur_freq > $max_freq )) && return $CKI_FAIL
    cki_log "+OK: current frequency ($cur_freq) <= max frequency ($max_freq)"
    (( $min_freq < 300000    )) && return $CKI_FAIL
    cki_log "+OK: min frequency ($min_freq) >= 300MHz (300000)"
    (( $max_freq > 8000000   )) && return $CKI_FAIL
    cki_log "+OK: max frequency ($max_freq) <= 8GHz (8000000)"

    return $CKI_PASS
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

    has_kmod_intel_rapl
    if (( $? != 0 )); then
        cki_set_reason $CKI_UNSUPPORTED \
            "kernel module 'intel-rapl' is not loaded"
        return $CKI_UNSUPPORTED
    fi

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

cki_main
exit $?
