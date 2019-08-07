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

source ${CDIR%/cpu/driver}/cpu/common/libbkrm.sh
source ${CDIR%/cpu/driver}/cpu/common/libutil.sh

function verify_intel_cpufreq_driver
{
    typeset driver=$1

    rlLog "Start to verify intel cpu freq driver"

    if [[ $driver != "intel_pstate" ]]; then
        rlSetReason $BKRM_FAIL \
            "intel system is running: $driver"
        return $BKRM_FAIL
    fi

    rlRun "lscpu | grep 'hwp'" $BKRM_RC_ANY
    if (( $? == 0 )); then
        rlRun "rdmsr 0x770"
        if (( $? != 0 )); then
            rlSetReason $BKRM_UNSUPPORTED \
                "intel system has HWP, but it is not enabled"
            return $BKRM_UNSUPPORTED
        fi
    else
        rlRun "ls /sys/devices/system/cpu/intel_pstate/"
        if (( $? != 0 )); then
            rlSetReason $BKRM_FAIL \
                "intel system does not have HWP, intel_pstate is not active"
            return $BKRM_FAIL
        fi
    fi

    rlLog "PASS"
    return $BKRM_PASS
}

function verify_amd_cpufreq_driver
{
    typeset driver=$1

    rlLog "Start to verify amd cpu freq driver"

    typeset family=$(cat /proc/cpuinfo | grep family | \
                     sort -u | awk '{print $4}')

    # verify family is >= 15h
    if (( $family >= 0x15 )); then
        if [[ $driver != "acpi-cpufreq" ]]; then
            rlSetReason $BKRM_FAIL \
                "amd system is running: $driver"
            return $BKRM_FAIL
        fi
    else
        rlSetReason $BKRM_UNSUPPORTED \
            "this test is not valid for the AMD family"
        return $BKRM_UNSUPPORTED
    fi

    rlLog "PASS"
    return $BKRM_PASS
}

function runtest
{
    typeset vendor_str=$(cat /proc/cpuinfo | grep vendor | \
                         sort -u | awk '{print $3}')

    if [[ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver ]]; then
        typeset driver=$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_driver | uniq)
    else
        typeset driver="NONE"
    fi

    case $vendor_str in
    GenuineIntel)
        verify_intel_cpufreq_driver $driver
        typeset -i ret=$?
        ;;

    AuthenticAMD)
        verify_amd_cpufreq_driver $driver
        typeset -i ret=$?
        ;;

    *) # UNSUPPORTED
        rlSetReason $BKRM_UNSUPPORTED \
            "it is an unsupported vendor: $vendor_str"
        typeset -i ret=$BKRM_UNSUPPORTED
        ;;
    esac

    return $ret
}

function startup
{
    if [[ $(virt-what) == "kvm" ]]; then
        rlSetReason $BKRM_UNSUPPORTED \
            "this test is unsupported in kvm"
        return $BKRM_UNSUPPORTED
    fi

    if [[ ! -d $TMPDIR ]]; then
        rlRun "mkdir -p -m 0755 $TMPDIR" || return $BKRM_UNINITIATED
    fi

    # setup msr tools as package 'msr-tools' is not installed by default
    msr_tools_setup
    if (( $? != 0 )); then
        rlSetReason $BKRM_UNINITIATED "fail to setup msr tools"
        return $BKRM_UNINITIATED
    fi

    return $BKRM_PASS
}

function cleanup
{
    msr_tools_cleanup
    rlRun "rm -rf $TMPDIR" $BKRM_RC_ANY
    return $BKRM_PASS
}

main
exit $?
