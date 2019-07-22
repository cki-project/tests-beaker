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

source ${CDIR%/power-management/rapl/powercap}/cpu/common/libbkrm.sh

# XXX: This function is from power-management/rapl/powercap/cap.sh
function set_cap
{
    typeset energy=${1?"*** energy_in_microjoules***"}
    typeset cpu_sockets=$(lscpu | grep 'Socket(s):' | \
                          sed 's/^Socket(s):[^0-9]*\([0-9]*\)/\1/')
    typeset cap_energy=$(( energy / cpu_sockets ))
    typeset rapl_path="/sys/devices/virtual/powercap/intel-rapl"
    typeset rapl=$(ls -1 $rapl_path | grep 'intel-rapl:')
    typeset cpu=""
    for cpu in $rapl; do
        echo $cap_energy > $rapl_path/$cpu/constraint_0_power_limit_uw
    done
}

# XXX: This function is from power-management/rapl/powercap/read_cap.sh
function get_cap
{
    typeset rapl_path="/sys/devices/virtual/powercap/intel-rapl"
    typeset rapl=$(ls -1 "$rapl_path" | grep 'intel-rapl:')

    typeset cpu=""
    typeset e=0
    for cpu in $rapl; do
        e_cpu=$(cat $rapl_path/$cpu/constraint_0_power_limit_uw)
        (( e += e_cpu ))
    done

    echo $e
}

# XXX: This function is from power-management/rapl/powercap/energy.sh
function get_energy
{
    typeset time=${1:-"30"} # Default is 30 secs
    typeset rapl_path="/sys/devices/virtual/powercap/intel-rapl"
    typeset rapl=$(ls -1 "$rapl_path" | grep 'intel-rapl:')

    typeset cpu=""
    typeset e1=0
    for cpu in $rapl; do
        typeset e_cpu=$(cat "$rapl_path/$cpu/energy_uj"*)
        (( e1 += e_cpu ))
    done

    sleep $time

    typeset e2=0
    for cpu in $rapl; do
        typeset e_cpu=$(cat "$rapl_path/$cpu/energy_uj"*)
        (( e2 += e_cpu ))
    done

    typeset e=$(( (e2 - e1) / time ))
    echo $e
}

# XXX: This function is from power-management/rapl/powercap/load1.sh
function load1
{
    typeset sleeptime=${1:-"1"}

    # do some load
    dd if=/dev/zero > /dev/null 2>&1 &
    typeset loadpid=$!

    sleep $sleeptime
    # wait a bit longer, than length of test
    sleep 10

    # kill the load
    kill -9 $loadpid
}

# XXX: This function is from power-management/rapl/powercap/load_m.sh
function loadm
{
    typeset -i timeout=$1
    typeset -i nthreads=$2
    typeset -i i
    for (( i = 0; i < $nthreads; i++ )); do
        (load1 $timeout) > /dev/null 2>&1 &
        typeset pid=$!
        rlLog "load1[$i] is started, pid=$pid"
    done
}

# XXX: This function is from power-management/rapl/powercap/test_capping.sh
function test_capping
{
    # measurement time should be bigger than
    # cat /sys/devices/virtual/powercap/intel-rapl/intel-rapl\:0/constraint_0_time_window_us
    # which is 1 sec by default (at least on systems I have seen so far).
    typeset measurement_time=30
    typeset load_time=$(( measurement_time + 20 ))

    # 1. no load, no cap
    typeset e_no_no=$(get_energy $measurement_time)
    rlLog "Power consumtion on uncapped system with no load: $e_no_no microwatts"

    # 2. load, no cap
    typeset cpus=$(lscpu | grep '^CPU(s):' | \
                   sed 's/^CPU(s):[^0-9]*\([0-9]*\)/\1/')
    loadm $load_time $cpus
    typeset e_full_no=$(get_energy $measurement_time)
    rlLog "Power consumtion on uncapped system with full load: $e_full_no microwatts"

    # 3. cap to average between full load and no load
    typeset e_mid=$(( (e_no_no + e_full_no) / 2 ))
    rlLog "Going to cap the system to: $e_mid microwatts"

    typeset old_cap=$(get_cap)
    set_cap $e_mid
    loadm $load_time $cpus
    typeset e_full_cap=$(get_energy $measurement_time)
    rlLog "Power consumtion on capped system with full load: $e_full_cap microwatts"

    #
    # measured_max is maximal measured value which will not cause fail
    # measured_min is minimal measured value which will not cause fail
    # *11/10 - add 10% in bash which works in integers only - we're
    # using microwatts, so numbers are milions to hundreds of milions,
    # so tehre is no problem with rounding error
    # *9/10 - substract 10%
    #
    typeset measured_max=$(( e_mid * 11 / 10 ))
    typeset measured_min=$(( e_mid *  9 / 10 ))

    rlLog "capping back to $old_cap"
    set_cap $old_cap

    rlLog "e_no_no      = $e_no_no"
    rlLog "e_full_no    = $e_full_no"
    rlLog "e_mid        = $e_mid"
    rlLog "e_full_cap   = $e_full_cap"
    rlLog "measured_max = $measured_max"
    rlLog "measured_min = $measured_min"
    if (( e_full_cap > measured_max || e_full_cap < measured_min )); then
        rlLog "FAIL: measured energy consumption doesn't match capped value"
        return 1
    fi

    return 0
}

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

function startup
{
    is_kvm
    if (( $? == 0 )); then
        rlSetReason $BKRM_UNSUPPORTED "kvm is unsupported"
        return $BKRM_UNSUPPORTED
    fi

    is_intel
    if (( $? != 0 )); then
        rlSetReason $BKRM_UNSUPPORTED "non-intel CPU is unsupported"
        return $BKRM_UNSUPPORTED
    fi

    if [[ ! -d $TMPDIR ]]; then
        rlRun "mkdir -p -m 0755 $TMPDIR" || return $BKRM_UNINITIATED
    fi

    return $BKRM_PASS
}

function cleanup
{
    rlRun "rm -rf $TMPDIR" $BKRM_RC_ANY
    return $BKRM_PASS
}

function runtest
{
    # For debugging
    rlRun -l "find /sys/devices/ -name *rapl*" $BKRM_RC_ANY
    rlRun -l "lsmod" $BKRM_RC_ANY
    rlRun -l "modprobe intel-rapl" || return $BKRM_UNINITIATED

    # Check if capping works, it should take approx 1.5 - 2 minutes
    test_capping || return $BKRM_FAIL
    return $BKRM_PASS
}

main
exit $?
