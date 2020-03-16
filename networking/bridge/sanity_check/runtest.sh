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

FILE=$(readlink -f $BASH_SOURCE)
NAME=$(basename $FILE)
CDIR=$(dirname $FILE)
RPATH=${RELATIVE_PATH:-"networking/bridge/sanity_check"}

# Include Beaker environment
. ../../../cki_lib/libcki.sh || exit 1
source ${CDIR%/$RPATH}/networking/common/include.sh || exit 1
source ${CDIR%/$RPATH}/networking/bridge/common/lib.sh || exit 1

rhel_version=$(GetDistroRelease)
rlJournalStart
    rlPhaseStartSetup
        rlRun -l "modinfo bridge"
	modprobe -r dummy
	rlRun "modprobe -nv dummy | grep 'numdummies=0'>/dev/null && spare_param='Y'" "0,1"
	if [ $spare_param = "Y" ];then
        	rlRun "modprobe dummy numdummies=1"
	else
		rlRun "modprobe dummy"
	fi
        rlRun "BRIDGE=br0"
        rlRun "IFACE=dummy0"
    rlPhaseEnd

    rlPhaseStartTest "load unload bridge module"
        for i in `seq 50`; do
            rlRun "modprobe bridge"
            sleep 1
            rlRun "modprobe -r bridge"
            sleep 1
        done
    rlPhaseEnd

    rlPhaseStartTest "test bridge-utils"
                    if [ $(GetDistroRelease) -le 7 ];then
                        rlRun "brctl addbr $BRIDGE"
                        rlRun "brctl addif $BRIDGE $IFACE"
                        rlRun "ip link set $BRIDGE up"
                        rlRun "ip link set $IFACE up"
                        rlRun "brctl show | grep $BRIDGE | grep $IFACE"
                    else
                        rlRun "ip link add dev $BRIDGE  type bridge"
                        rlRun "ip link set dev $IFACE master $BRIDGE"
                        rlRun "ip link set $BRIDGE up"
                        rlRun "ip link set $IFACE up"
                        rlRun "ip -d link show master $BRIDGE|grep $IFACE"
                    fi

                    if  [ $(GetDistroRelease) -eq 7 ]; then
                        rlRun "brctl setageing $BRIDGE 100"
                        rlRun "brctl showstp $BRIDGE | grep 'ageing time' | grep 100"
                        rlRun "cat /sys/class/net/$BRIDGE/bridge/ageing_time | grep 10000"
                        rlRun "brctl setbridgeprio $BRIDGE 88"
                        rlRun "brctl showstp $BRIDGE | grep 'bridge id' | grep 0058"
                        rlRun "cat /sys/class/net/$BRIDGE/bridge/bridge_id | grep 0058"
                        rlRun "brctl setfd $BRIDGE 20"
                        rlRun "brctl showstp $BRIDGE | grep 'forward delay' | grep 20"
                        rlRun "brctl sethello $BRIDGE 6"
                        rlRun "brctl showstp $BRIDGE | grep 'hello time' | grep 6"
                        rlRun "brctl setmaxage $BRIDGE 30"
                        rlRun "brctl showstp $BRIDGE | grep 'max age' | grep 30"
                    elif  [ $(GetDistroRelease) -gt 7 ];then
                        rlRun "ip link set dev $BRIDGE type bridge ageing_time 10000"
                        rlRun "ip -d link show $BRIDGE | grep 'ageing_time' | grep 10000"
                        rlRun "cat /sys/class/net/$BRIDGE/bridge/ageing_time | grep 10000"
                        rlRun "ip link set dev $BRIDGE type bridge priority 88"
                        rlRun "ip -d link show $BRIDGE | grep 'bridge_id' | grep 0058"
                        rlRun "cat /sys/class/net/$BRIDGE/bridge/bridge_id | grep 0058"
                        rlRun "ip link set dev $BRIDGE type bridge forward_delay 2000"
                        rlRun "ip -d link show $BRIDGE | grep 'forward_delay' | grep 2000"
                        rlRun "ip link set dev $BRIDGE type bridge hello_time 600"
                        rlRun "ip -d link show $BRIDGE | grep 'hello_time' | grep 600"
                        rlRun "ip link set dev $BRIDGE type bridge max_age 3000"
                        rlRun "ip -d link show $BRIDGE | grep 'max_age' | grep 3000"

                    fi

                    if [ $(GetDistroRelease) -le 7 ];then
                        rlRun "brctl setpathcost $BRIDGE  $IFACE 1"
                        rlRun "brctl showstp $BRIDGE | grep 'path cost' | grep 1"
                        rlRun "brctl setportprio $BRIDGE  $IFACE 1"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/priority | grep 1"
                        rlRun "brctl stp $BRIDGE off"
                        rlRun "brctl show $BRIDGE | grep 'br0' | grep no"
                        rlRun "brctl stp $BRIDGE on"
                    else
                        rlRun "ip link set dev $IFACE type bridge_slave cost 1"
                        rlRun "ip -d link show master $BRIDGE | grep 'cost' | grep 1"
                        rlRun "ip link set dev $IFACE type bridge_slave priority 1"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/priority | grep 1"
                        rlRun "ip link set dev $BRIDGE type bridge stp_state 0"
                        rlRun "ip -d link show $BRIDGE |grep stp_state |grep 0"
                        rlRun "ip link set dev $BRIDGE type bridge stp_state 1"
                    fi



                    if [ $(GetDistroRelease) -eq 7 ]; then
                        rlRun "brctl hairpin $BRIDGE $IFACE on"
                        rlRun "brctl showstp $BRIDGE | grep hairpin | grep 1"
                        rlRun "brctl hairpin $BRIDGE $IFACE off"
                        rlRun "brctl showstp $BRIDGE | grep hairpin" 1
                        rlRun "brctl show $BRIDGE | grep br0 | grep yes"
                        rlRun "brctl showmacs $BRIDGE | grep yes"
                    elif [ $(GetDistroRelease) -gt 7 ];then
                        rlRun "ip link set dev $IFACE type bridge_slave hairpin on"
                        rlRun "ip -d link show master $BRIDGE | grep hairpin | grep on"
                        rlRun "ip link set dev $IFACE type bridge_slave hairpin off"
                        rlRun "ip -d link show master $BRIDGE | grep hairpin | grep off"
                        rlRun "ip -d link show $BRIDGE |grep stp_state |grep 0"
                        rlRun "bridge fdb  |grep '$BRIDGE permanent'"
                    fi
                    check_call_trace
    rlPhaseEnd

if (($rhel_version >= 7)); then

    rlPhaseStartTest "check netlink command"

                        rlRun "ip link set dev $BRIDGE type bridge stp_state 0"
                        rlRun "bridge link set dev $IFACE cost 4"
                        rlRun "bridge link show dev $IFACE | grep 'cost 4'"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/path_cost | grep 4"
                        rlRun "bridge link set dev $IFACE priority 16"
                        rlRun "bridge link show dev $IFACE | grep 'priority 16'"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/priority | grep 16"
                        rlRun "bridge link set dev $IFACE state 0"
                        rlRun "bridge link show dev $IFACE | grep disabled"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/state | grep 0"
                        rlRun "bridge link set dev $IFACE state 1"
                        rlRun "bridge link show dev $IFACE | grep listening"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/state | grep 1"
                        rlRun "bridge link set dev $IFACE state 2"
                        rlRun "bridge link show dev $IFACE | grep learning"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/state | grep 2"
                        rlRun "bridge link set dev $IFACE state 3"
                        rlRun "bridge link show dev $IFACE | grep forwarding"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/state | grep 3"
                        rlRun "bridge link set dev $IFACE state 3"
                        rlRun "bridge link show dev $IFACE | grep forwarding"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/state | grep 3"
                        rlRun "ip link set dev $BRIDGE type bridge stp_state 1"
                        rlRun "bridge link set dev $IFACE guard on"
                        sleep 15
                       # rlRun "bridge link show dev $IFACE | grep disabled"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/bpdu_guard | grep 1"
                        rlRun "bridge link set dev $IFACE guard off"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/bpdu_guard | grep 0"
                        rlRun "ip link set $IFACE down"
                        rlRun "ip link set $IFACE up"
                        sleep 60
                        rlRun "bridge link show dev $IFACE | grep forwarding"
                        rlRun "bridge link set dev $IFACE hairpin on"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/hairpin_mode | grep 1"
                        rlRun "bridge link set dev $IFACE hairpin off"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/hairpin_mode | grep 0"
                        rlRun "bridge link set dev $IFACE fastleave on"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/multicast_fast_leave | grep 1"
                        rlRun "bridge link set dev $IFACE fastleave off"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/multicast_fast_leave | grep 0"
                        rlRun "bridge link set dev $IFACE root_block on"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/root_block | grep 1"
                        rlRun "bridge link set dev $IFACE root_block off"
                        rlRun "cat /sys/class/net/$BRIDGE/brif/$IFACE/root_block | grep 0"
                        rlRun "ip link set $BRIDGE down"
                        rlRun "ip link del $BRIDGE"

                        check_call_trace
    rlPhaseEnd
fi

    rlPhaseStartTest "test iproute2"
        [ $(GetDistroRelease) = 6 ] && {
        ip link set $BRIDGE down
        #brctl delbr $BRIDGE
        ip link del $BRIDGE
        }

        [ $(GetDistroRelease) = 7 ] && {
        rlRun "ip link add $BRIDGE type bridge"
        rlRun "ip link set $IFACE  master $BRIDGE "
        } || {
        #rlRun "brctl addbr $BRIDGE"
        #rlRun "brctl addif $BRIDGE $IFACE"
        ip link add dev $BRIDGE type bridge
        ip link set $IFACE master $BRIDGE
        }

        rlRun "ip link set $IFACE  up"
        rlRun "ip link set $BRIDGE up"

        rlRun "bridge link show"
        rlRun "bridge fdb show"
        rlRun "bridge mdb show"
        rlRun "bridge vlan show"

        rlRun "ip link set $IFACE  down"
        rlRun "ip link set $BRIDGE down"
        [ $(GetDistroRelease) = 7 ] && {
        rlRun "ip link set $IFACE  nomaster"
        rlRun "ip link del $BRIDGE"
        } || {
        rlRun "ip link set dev $IFACE nomaster"
        rlRun "ip link del $BRIDGE"
        }
        check_call_trace
    rlPhaseEnd

    rlPhaseStartTest "check procfs sysfs"
        rlRun "ip link add dev $BRIDGE type bridge"
        rlRun "ip link set dev $IFACE master $BRIDGE"
        sleep 2
        rlRun -l "grep -rH '' /proc/sys/net/bridge/" 0-100
        rlRun -l "grep -rH '' /sys/class/net/$BRIDGE/bridge/" 0-100
    rlPhaseEnd

    rlPhaseStartTest "fault injection"
        rlRun "CMD_ARRAY=(
            'modprobe bridge'
            'modprobe -r bridge'
            'ip link add dev $BRIDGE type bridge'
            'ip link set dev $IFACE master $BRIDGE'
            'ip link del $BRIDGE'
            'ip link set dev $IFACE nomaster'
            'ip link  show type bridge'
            'bridge link'
            'bridge fdb'
            'bridge mdb'
            'bridge vlan'
        )"
        rlRun "CMD_CNT=${#CMD_ARRAY[@]}"

        # run the command in disorder, system should not panic"
        for i in `seq 300`; do
            index=$((RANDOM % CMD_CNT))
            rlRun "eval ${CMD_ARRAY[index]}" 0-255
        done
        check_call_trace
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "reset_network_env"
        rlRun "ip link del dummy0" "0-255"
        rlRun "modprobe -r dummy" "0-255"
        check_call_trace
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
