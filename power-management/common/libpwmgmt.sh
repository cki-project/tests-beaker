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

source $(dirname $(readlink -f $BASH_SOURCE))/../../cki_lib/libcki.sh

#
# Check CPU vendor is Intel or not
#
function is_intel
{
    typeset vendor=$(grep vendor /proc/cpuinfo | uniq | awk '{print $3}')
    [[ $vendor == "GenuineIntel" ]] && return 0 || return 1
}

#
# Check the system is kvm or not
#
function is_kvm
{
    [[ $(virt-what) == "kvm" ]] && return 0 || return 1
}

#
# Check kernel module 'intel-rapl' is available because power management
# features require Xeon CPU
#
function has_kmod_intel_rapl
{
    # Always try to load kernel module 'intel-rapl' in case it is not loaded
    cki_run_cmd_neu "modprobe intel-rapl"

    # Check 'intel_rapl' has been loaded
    cki_run_cmd_pos "lsmod | egrep '^intel_rapl '"
    return $?
}
