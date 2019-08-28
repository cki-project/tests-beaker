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

#  This scripts performs the following functions and provides results
#  as described:
#
#  - Verify that the OS in question supports die enumeration
#     o returns SKIP if not supported
#
#  - Determine if the system in question is multidie or not
#     o report findings
#
#  - Perform sysfs /sys/devices/system/cpu/cpu*/topology validation
#     o For All Systems verify the following:
#       - core_siblings matches package_cpus
#       - core_siblings_list matches package_cpus_list
#       - thread_siblings matches core_cpus
#       - thread_siblings_list matches core_cpus_list
#
#     o For systems which are not multidie verify the following:
#       -  die_cpus matches package_cpus
#       -  die_cpus_list matches package_cpus_list
#
#  - Use lscpu to compile NUMA node information
#     o failure to parse will not cause the test to terminate, but it
#       will cause a FAIL result
#
#  - Perform per die actions
#     o verify each die cpu is in the same package/die
#     o output the dies_cpu_list
#     o verify that dies_cpu_list matches the numactl data for the given node
#     o output the die_id and the physical_package_id
#
#  - Output a result
#     o PASS if all verification is successful
#     o FAIL otherwise (log examination should yield the cause of the failure)
#
global_error=false
[ ! -z "$BEAKER_JOB_WHITEBOARD" ] && beaker=true || beaker=false

package_count=0
process_packages()
{
    packages=$(cat /sys/devices/system/cpu/cpu*/topology/physical_package_id | sort -u)

    for package in $packages; do
	package_count=$((package_count+1))
    done

    echo "physical packages: $package_count"
}

multidie=false
process_dies()
{
    dies=$(cat /sys/devices/system/cpu/cpu*/topology/die_id | sort -u)

    count=0
    for die in $dies; do
	count=$((count+1))
    done

    if [ $count -gt 1 ]; then
	echo "this is a multi-die system"
	multidie=true
    else
	echo "this is not a multi-die system"
    fi
}

logical_die_count=0
process_logical_dies()
{
    logical_die_count=$((package_count))

    if [ "$beaker" = "false" ]; then
	output=$(dmesg | grep Converting | grep "to logical die" | tail -1)
    else
	output=$(grep Converting /var/log/messages | \
	         grep "to logical die" | tail -1)
    fi

    if [ ! -z "$output" ]; then
	logical_die_count=$(echo $output | awk '{print $NF}')
	logical_die_count=$((logical_die_count+1))
    fi

    echo "logical_die_count: $logical_die_count"
}

verify_data()
{
    old=$1
    new=$2

    [ ! -e $old ] && echo "$verify_dir: file not found: $old" && global_error=true
    [ ! -e $new ] && echo "$verify_dir: file not found: $new" && global_error=true

    diff $old $new &> /dev/null

    if [ $? -ne 0 ]; then
	echo "$verify_dir: $old does not match $new"
	global_error=true
    fi
}

cpu_count=0
first_verify=true
verify_topology_dir()
{
    cpu_count=$((cpu_count+1))
    verify_dir=${1}/topology
    cd $verify_dir &>/dev/null
    [ $? -ne 0 ] && echo "unable to verify cpu: $1" && global_error=true

    verify_data core_siblings package_cpus
    verify_data core_siblings_list package_cpus_list

    verify_data thread_siblings core_cpus
    verify_data thread_siblings_list core_cpus_list

    if [ "$multidie" = "false" ]; then
	# on a non-multidie system the dies cpu list
	# should match the package cpu list
	if [ "$first_verify" = "true" ]; then
	    echo "Note: non-multidie system - die and package cpus should match"
	fi
	verify_data die_cpus package_cpus
	verify_data die_cpus_list package_cpus_list
    fi

    first_verify=false
}

process_cpus()
{
    dirs=$(ls -dv1 /sys/devices/system/cpu/cpu*[0-9])

    for dir in $dirs; do
	verify_topology_dir $dir
    done

    echo "cpu_count: $cpu_count"
    if [ $(nproc --all) -ne $cpu_count ]; then
	echo "mismatch nproc=$(nproc --all) dirs=$cpu_count"
	global_error=true
    fi
}

declare -a numa_node_cpus
declare numa_index=0
build_numa_entry()
{
    numa_node_cpus[$numa_index]=$(echo $1)
    numa_index=$((numa_index+1))
}

build_numa_list()
{
    numa_count=$(lscpu | grep "NUMA node(s)" | cut -d : -f 2)

    output=$(lscpu | grep "NUMA node" | grep CPU)
    while read -r line; do
	data=$(echo $line | cut -d : -f 2)
	build_numa_entry "$data"
    done <<< "$output"

    if [ $numa_index -eq 0 ] || [ $numa_index -ne $numa_count ]; then
	echo "unable to parse NUMA data"
	numa_index=0 # don't bother to compare bad data
	global_error=true
    fi

    echo
}

verify_die_cpu()
{
    start=$(echo $1 | cut -d-  -f 1)
    end=$(echo $1 | cut -d- -f 2)

    for ((i=$start; i <= $end; ++i)); do
	die=$(cat /sys/devices/system/cpu/cpu${i}/topology/die_id)
	pkg=$(cat /sys/devices/system/cpu/cpu${i}/topology/physical_package_id)
	if [ "$first" = "true" ]; then
	    die_id=$die
	    physical_package_id=$pkg
	    first=false
	else
	    if [[ $die_id -ne $die ]] || [[ $physical_package_id -ne $pkg ]]
	    then
		echo "error die/package mismatch for cpu $i"
		error=true
		break
	    fi
	fi
    done
}

curr_index=0
verify_die_cpu_list()
{
    die_cpus=$(echo $1 | sed 's/,/ /g')
    first=$(echo $die_cpus | cut -d ' ' -f 1 | cut -d - -f1)

    pkg=$(cat /sys/devices/system/cpu/cpu${first}/topology/physical_package_id)
    die=$(cat /sys/devices/system/cpu/cpu${first}/topology/die_id)

    echo "physical_package_id: $pkg die_id: $die"
    echo "die_cpu_list: $1"

    first=true
    error=false
    for dies in $die_cpus; do
	verify_die_cpu $dies
    done

    if [ "$error" = "false" ]; then
	echo "all cpus verified"
    else
	global_error=true
    fi

    # make sure we match numactl --hardware output
    if [ $curr_index -lt $numa_index ]; then
	if [ "${numa_node_cpus[$curr_index]}" != "$1" ]; then
	    echo "curr_index=$curr_index"
	    echo "fails to match numa node data: ${numa_node_cpus[$curr_index]}"
	    global_error=true
	else
	    echo "numa node data: match"
	fi
	curr_index=$((curr_index+1))
    else
	echo "missing numa node data"
	global_error=true
    fi

    echo
}

process_die_cpus_list()
{
    die_cpus_lists=$(cat /sys/devices/system/cpu/cpu*/topology/die_cpus_list | sort -u)

    n=0
    for die_cpu_list in $die_cpus_lists; do
	verify_die_cpu_list $die_cpu_list
	n=$((n+1))
    done

    if [ $n -ne $logical_die_count ]; then
	echo "logical_die_count: $logical_die_count mismatch found $n"
	global_error=true
    fi
}

log_result()
{
    echo "$1"
    if [ "$beaker" = "true" ]; then
	[ "$1" = "PASS" ] && exit 0 || exit 1
    fi
    echo "$1" > .result
}


if [ ! -e /sys/devices/system/cpu/cpu0/topology/die_id ]; then
    echo "this system does not have die support"
    log_result "SKIP"
    exit
fi

DIR=$(pwd)

process_packages
process_dies
process_logical_dies
process_cpus
build_numa_list
process_die_cpus_list

cd $DIR

[ "$global_error" = "false" ] && result="PASS" || result="FAIL"
log_result "$result"
