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
die_count=0
process_dies()
{
    dies=$(cat /sys/devices/system/cpu/cpu*/topology/die_id | sort -u)

    for die in $dies; do
	die_count=$((die_count+1))
    done

    if [ $die_count -gt 1 ]; then
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

    output=$(dmesg | grep Converting | grep "to logical die" | tail -1)

    if [ -z "$output" ]; then
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
declare -a numa_node_verified
declare numa_max=0
build_numa_entry()
{
    numa_node_cpus[$numa_max]=$(echo $1)
    numa_node_verified[$numa_max]=false
    numa_max=$((numa_max+1))
}

build_numa_list()
{
    numa_count=$(lscpu | grep "NUMA node(s)" | cut -d : -f 2)

    output=$(lscpu | grep "NUMA node" | grep CPU)
    while read -r line; do
	data=$(echo $line | cut -d : -f 2)
	build_numa_entry "$data"
    done <<< "$output"

    if [ $numa_max -eq 0 ] || [ $numa_max -ne $numa_count ]; then
	echo "unable to parse NUMA data"
	numa_max=0 # don't bother to compare bad data
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

    match=false
    for ((j=0; j<$numa_max; ++j)); do
	# make sure we match numactl --hardware output
	if [ "${numa_node_cpus[$j]}" = "$1" ]; then
	    echo "match numa_index=$j"
	    numa_node_verified[$j]=true
	    match=true
	fi
    done

    if [ "$match" = "false" ]; then
	echo "ERROR: does not match any numa node data"
	global_error=true
    fi

    echo
}

process_die_cpus_list()
{
    path='/sys/devices/system/cpu/cpu*/topology/die_cpus_list'
    die_array=($(cat $path | sort -u))
    array_len=${#die_array[@]}

    for ((k=0; k < $array_len; ++k)); do
	verify_die_cpu_list ${die_array[$k]}
    done

    if [ $array_len -ne $logical_die_count ]; then
	echo "logical_die_count: $logical_die_count mismatch found $array_len"
	global_error=true
    fi
}

process_numa_list()
{
    match_fail=false
    for ((i=0; i < $numa_max; ++i)); do
	if [ "${numa_node_verified[$i]}" != "true" ]; then
	    match_fail=true
	    echo "no match for numa index $i"
	fi
    done
    [ "$match_fail" = "true" ] && global_error=true
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
process_numa_list

cd $DIR

[ "$global_error" = "false" ] && result="PASS" || result="FAIL"
log_result "$result"
