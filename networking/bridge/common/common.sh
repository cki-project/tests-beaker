#!/bin/bash
#
# Copyright (c) 2013 Red Hat, Inc. All rights reserved.
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

. /usr/bin/rhts_environment.sh

log()
{
        echo $@ | tee -a $OUTPUTFILE
}

br_setup() 
{
        br=${1:-br0}
        ETH_1=${2:-eth0}
        ETH_2=${3:-}
        ETH_3=${4:-}
        brctl addbr $br
        ifconfig $br up
        for eth in $ETH_1 $ETH_2 $ETH_3
        do
                del_ip $eth
                ifconfig $eth up
        done
        brctl addif $br $ETH_1 $ETH_2 $ETH_3
}

br_del()
{
        br=${1:-br0}
        ifconfig $br down
        brctl delbr $br
}

add_ip()
{
        ip=${1:-0}
        mask=${2:-24}
        dev=${3:br0}
        ip a a $ip/$mask dev $dev
}
del_ip()
{
        dev=${1:br0}
        ifconfig $dev 0
}
br_check()
{
        br=${1:-br0}
        #ip route check
        ip route | grep $br

        #mtu check
        ifconfig $br mtu 1400
        mtu=`cat /sys/class/net/$br/mtu`
        if [ $mtu = 1400 ]; then
                report_result $TEST/decrease_mtu "PASS" 0
        fi
        for eth in `ls /sys/class/net/$br/brif/`
        do
                ifconfig $eth mtu 1800
        done
        mtu=`cat /sys/class/net/$br/mtu`
        if [ $mtu = 1800 ]; then
                report_result $TEST/increase_mtu "PASS" 0
        fi



}

