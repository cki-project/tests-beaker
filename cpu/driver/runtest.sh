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

NON_PSTATE_PROCESSORS="26 31 46"
check_pstate_support()
{
    for m in $NON_PSTATE_PROCESSORS; do
	if [ $m -eq $1 ]; then
	    cki_log "model: $model - does not support intel_pstate"
	    return 1
	fi
    done

    return 0
}

function verify_intel_cpufreq_driver
{
    typeset driver=$1

    cki_log "Start to verify intel cpu freq driver"

    typeset vendor=$(dmidecode -t 0 | grep Vendor: | \
                     cut -d: -f 2 | awk '{print tolower($1)}')

    typeset model=$(lscpu | grep Model: | awk '{print $2}')
    if [ -z "$model" ]; then
	cki_log "unable to determine cpu model"
	return $CKI_FAIL
    fi

    # make sure the given system supports p-state
    check_pstate_support $model
    if [ $? -ne 0 ]; then
	# older systems do not support intel pstate
	if [ $driver != "acpi-cpufreq" ]; then
	    cki_log "intel (non-pstate) system is running: $driver"
	    # maps to SKIP
	    return $CKI_UNSUPPORTED
	fi
	cki_log "intel system is running: $driver"
	return $CKI_PASS
    fi

    if [[ $driver != "intel_pstate" ]]; then
	if [ "$vendor" = "lenovo" ]; then
	    cki_log "lenovo intel system is running: $driver"
	    cki_log "PASS"
	    return $CKI_PASS
	fi
        cki_set_reason $CKI_FAIL \
            "intel system is running: $driver"
        return $CKI_FAIL
    fi

    cki_run_cmd_neu "lscpu | grep 'hwp '"
    if (( $? == 0 )); then
        cki_run_cmd_pos "rdmsr 0x770"
        if (( $? != 0 )); then
            cki_set_reason $CKI_UNSUPPORTED \
                "intel system has HWP, but it is not enabled"
            return $CKI_UNSUPPORTED
        fi
    else
        cki_run_cmd_pos "ls /sys/devices/system/cpu/intel_pstate/"
        if (( $? != 0 )); then
            cki_set_reason $CKI_FAIL \
                "intel system does not have HWP, intel_pstate is not active"
            return $CKI_FAIL
        fi
    fi

    cki_log "PASS"
    return $CKI_PASS
}

function verify_amd_cpufreq_driver
{
    typeset driver=$1

    cki_log "Start to verify amd cpu freq driver"

    typeset family=$(cat /proc/cpuinfo | grep family | \
                     sort -u | awk '{print $4}')

    # verify family is >= 15h
    if (( $family >= 0x15 )); then
        if [[ $driver != "acpi-cpufreq" ]]; then
            cki_set_reason $CKI_FAIL \
                "amd system is running: $driver"
            return $CKI_FAIL
        fi
    else
        cki_set_reason $CKI_UNSUPPORTED \
            "this test is not valid for the AMD family"
        return $CKI_UNSUPPORTED
    fi

    cki_log "PASS"
    return $CKI_PASS
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
        cki_set_reason $CKI_UNSUPPORTED \
            "it is an unsupported vendor: $vendor_str"
        typeset -i ret=$CKI_UNSUPPORTED
        ;;
    esac

    return $ret
}

function startup
{
    if [[ $(virt-what) == "kvm" ]]; then
        cki_set_reason $CKI_UNSUPPORTED \
            "this test is unsupported in kvm"
        return $CKI_UNSUPPORTED
    fi

    if [[ ! -d $TMPDIR ]]; then
        cki_run_cmd_pos "mkdir -p -m 0755 $TMPDIR" || return $CKI_UNINITIATED
    fi

    # setup msr tools as package 'msr-tools' is not installed by default
    msr_tools_setup
    if (( $? != 0 )); then
        cki_set_reason $CKI_UNINITIATED "fail to setup msr tools"
        return $CKI_UNINITIATED
    fi

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
