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

typeset -a g_load_pids # A global arrary to save pids of workload
function load_start
{
    typeset ncpus=$(lscpu -p=cpu | grep -v '^#' | wc -l)
    typeset nload=$((ncpus * 1 + ncpus / 2))
    # XXX: Make sure no running "dd" processes are on the system under test
    cki_run_cmd_neu "pkill dd"
    typeset -i i
    for ((i = 0; i < nload; i++)); do
        dd if=/dev/zero of=/dev/null 2>/dev/null &
        typeset pid=$!
        cki_log "$i:\ta load is running, pid=$pid"
        g_load_pids[$i]=$pid
    done
}

function load_stop
{
    typeset -i i
    for ((i = 0; i < ${#g_load_pids[@]}; i++)); do
        typeset pid=${g_load_pids[$i]}
        kill -9 $pid
        cki_log "$i:\ta load is stopped, pid=$pid"
    done
    unset g_load_pids
}

function runtest
{
    cki_log "This test tests if CPU frequency is changing between idle" \
        "on powersave governor and full load on performance governor"

    # Dump sysinfo
    cki_run_cmd_neu "uname -srvm"
    cki_run_cmd_neu "lscpu"
    cki_run_cmd_neu "dmidecode | grep -A 3 'BIOS Information'"

    typeset cpufreq_dir="/sys/devices/system/cpu/cpu0/cpufreq"
    typeset file1="$cpufreq_dir/scaling_available_governors"
    typeset file2="$cpufreq_dir/scaling_governor"
    typeset file3="$cpufreq_dir/cpuinfo_cur_freq"
    ls $file3 > /dev/null 2>&1 || \
            file3="$cpufreq_dir/scaling_cur_freq"

    cki_run_cmd_neu "cat $file1"
    cki_run_cmd_neu "cat $file2"
    typeset scaling_governor=$(cat $file2)

    typeset file_freq1=$TMPDIR/curfreq1
    typeset file_freq2=$TMPDIR/curfreq2
    cki_log "write 'powersave' to file $file2"
    cki_run_cmd_pos "echo powersave > $file2 && cat $file2" || \
        return $CKI_FAIL
    cki_log "sleep a while then get current cpu frequency"
    cki_run_cmd_neu "sleep 20"
    cki_run_cmd_neu "cat $file3 > $file_freq1 && cat $file_freq1"
    typeset cur_freq_pows=$(cat $file_freq1)

    cki_log "write 'performance' to file $file2"
    cki_run_cmd_pos "echo performance > $file2 && cat $file2" || \
        return $CKI_FAIL
    cki_log "start workloads then get current cpu frequency"
    load_start
    cki_run_cmd_neu "sleep 20"
    cki_run_cmd_neu "cat $file3 > $file_freq2 && cat $file_freq2"
    typeset cur_freq_perf=$(cat $file_freq2)
    load_stop

    typeset msg_governor="CPU scaling governor"
    typeset msg_freq_pows="CPU scaling frequency with powersave"
    typeset msg_freq_perf="CPU scaling frequency with performance"
    cki_log "$msg_governor:\t\t\t$scaling_governor"
    cki_log "$msg_freq_pows:\t$cur_freq_pows"
    cki_log "$msg_freq_perf:\t$cur_freq_perf"
    #
    # NOTE: CPU scaling frequency with powersave should be less than
    #       CPU scaling frequency with performance
    #
    typeset msg2fail="($cur_freq_pows) >= ($cur_freq_perf)"
    typeset msg2pass="($cur_freq_pows) <  ($cur_freq_perf)"
    if (( $cur_freq_pows >= $cur_freq_perf )); then
        cki_log "FAIL: $msg_freq_pows $msg2fail $msg_freq_perf"
        return $CKI_FAIL
    fi
    cki_log "PASS: $msg_freq_pows $msg2pass $msg_freq_perf"
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
