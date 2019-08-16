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
NAME=$(basename $FILE)
CDIR=$(dirname $FILE)
RPATH=${RELATIVE_PATH:-"networking/vnic/ipvlan/basic"}

# Include Beaker environment
source ${CDIR%/$RPATH}/networking/common/include.sh || exit 1

# Functions

ipvlan_get_test_netid()
{
	netid=$(host -4 $(echo $SERVERS |cut -d' ' -f1)| awk -F. '{print $(NF-1)$NF}' | awk '{print $1 % 255}' | head -n 1)
}

multihost_netns()
{
rlPhaseStartTest "multihost_netns"
	local dev_features[0]="gso off gro off"
	local dev_features[1]="gso on gro on"
	rlRun "get_test_iface_and_addr"
	rlRun "ipvlan_get_test_netid"
	if i_am_server
	then
		rlRun "ip netns add ns_s"
		rlRun "ip link add link $TEST_IFACE name ipvlan_s type ipvlan mode l2"
		rlRun "ip link add link $TEST_IFACE name ipvlan_s type ipvlan mode l2" "0-255"
		rlRun "ip link set ipvlan_s netns ns_s"
		rlRun "ip netns exec ns_s ip link set lo up"
		rlRun "ip netns exec ns_s ip link set ipvlan_s up"
		rlRun "ip netns exec ns_s ip addr add 192.168.$netid.171/24 dev ipvlan_s"
		rlRun "ip netns exec ns_s ip addr add 5010:$netid::171/64 dev ipvlan_s"
		rlRun "ip netns exec ns_s ip route add default dev ipvlan_s"
		rlRun "ip netns exec ns_s ip -6 route add default dev ipvlan_s"

		rhts-sync-block -s IPVLAN_MULTIHOST_CLIENT_READY $CLIENTS
		for flag in vepa private bridge
		do
			rlLog "mode l2 $flag"
			rlRun "ip netns exec ns_s ip link set ipvlan_s type ipvlan $flag"
			rlRun "ip netns exec ns_s ip link set ipvlan_s type ipvlan $flag" "0-255"

			rlRun "ip netns exec ns_s ping 192.168.$netid.172 -c 5"
			rlRun "ip netns exec ns_s ping6 5010:$netid::172 -c 5"
			rlRun "ip netns exec ns_s ping $REMOTE_ADDR4 -c 5"
			rlRun "ip netns exec ns_s ping6 $REMOTE_ADDR6 -c 5"
			rlRun "ip netns exec ns_s netperf -4 -H 192.168.$netid.172 -t UDP_STREAM -l 1 -- -R 1"
			rlRun "ip netns exec ns_s netperf -4 -H 192.168.$netid.172 -t TCP_STREAM -l 1 -- -m 16k"
			rlRun "ip netns exec ns_s netperf -4 -H 192.168.$netid.172 -t SCTP_STREAM -l 1 -- -m 16k"
			rlRun "ip netns exec ns_s netperf -6 -H 5010:$netid::172 -t UDP_STREAM -l 1 -- -R 1"
			rlRun "ip netns exec ns_s netperf -6 -H 5010:$netid::172 -t TCP_STREAM -l 1 -- -m 16k"
			rlRun "ip netns exec ns_s netperf -6 -H 5010:$netid::172 -t SCTP_STREAM -l 1 -- -m 16k"
		done

		rhts-sync-set -s IPVLAN_MULTIHOST_MODE2_FINISH

		#rlRun "ip netns exec ns_s ip route add default dev ipvlan_s"
		#rlRun "ip netns exec ns_s ip -6 route add default dev ipvlan_s"
		rlRun "ip route add 192.168.$netid.172 via $REMOTE_ADDR4"
		rlRun "ip -6 route add 5010:$netid::172 via $REMOTE_ADDR6"

		for mode in l3 l3s
		do
			rlRun "ip netns exec ns_s ip link set ipvlan_s type ipvlan mode $mode"
			rlRun "ip netns exec ns_s ip link set ipvlan_s type ipvlan mode $mode" "0-255"
			rhts-sync-block -s IPVLAN_MULTIHOST_${mode}_READY $CLIENTS
			for flag in vepa private bridge
			do
				rlLog "mode $mode $flag"
				rlRun "ip netns exec ns_s ip link set ipvlan_s type ipvlan $flag"
				rlRun "ip netns exec ns_s ip link set ipvlan_s type ipvlan $flag" "0-255"

				for feature_id in ${!dev_features[@]}
				do
					rlRun "ip netns exec ns_s ethtool -K ipvlan_s ${dev_features[$feature_id]}"
					rlRun "ip netns exec ns_s ethtool -k ipvlan_s"
					rlRun "ping 192.168.$netid.172 -c 5"
					rlRun "ping6 5010:$netid::172 -c 5"
					rlRun "ip netns exec ns_s ping 192.168.$netid.172 -c 5"
					rlRun "ip netns exec ns_s ping6 5010:$netid::172 -c 5"
					rlRun "ip netns exec ns_s ping $REMOTE_ADDR4 -c 5"
					rlRun "ip netns exec ns_s ping6 $REMOTE_ADDR6 -c 5"
					rlRun "ip netns exec ns_s netperf -4 -H 192.168.$netid.172 -t UDP_STREAM -l 1 -- -R 1"
					rlRun "ip netns exec ns_s netperf -4 -H 192.168.$netid.172 -t TCP_STREAM -l 1 -- -m 16k"
					rlRun "ip netns exec ns_s netperf -4 -H 192.168.$netid.172 -t SCTP_STREAM -l 1 -- -m 16k"
					rlRun "ip netns exec ns_s netperf -6 -H 5010:$netid::172 -t UDP_STREAM -l 1 -- -R 1"
					rlRun "ip netns exec ns_s netperf -6 -H 5010:$netid::172 -t TCP_STREAM -l 1 -- -m 16k"
					rlRun "ip netns exec ns_s netperf -6 -H 5010:$netid::172 -t SCTP_STREAM -l 1 -- -m 16k"
				done
			done
			rhts-sync-set -s IPVLAN_MULTIHOST_${mode}_FINISH

		done

		rlRun "ip netns exec ns_s ip link del ipvlan_s"
		rlRun "ip netns del ns_s"
		rlRun "ip route del 192.168.$netid.172 via $REMOTE_ADDR4"
		rlRun "ip -6 route del 5010:$netid::172 via $REMOTE_ADDR6"
	elif i_am_client
	then
		rlRun "ip netns add ns_c"
		rlRun "ip link add link $TEST_IFACE name ipvlan_c type ipvlan mode l2"
		rlRun "ip link set ipvlan_c netns ns_c"
		rlRun "ip netns exec ns_c ip link set lo up"
		rlRun "ip netns exec ns_c ip link set ipvlan_c up"
		rlRun "ip netns exec ns_c ip addr add 192.168.$netid.172/24 dev ipvlan_c"
		rlRun "ip netns exec ns_c ip addr add 5010:$netid::172/64 dev ipvlan_c"
		rlRun "ip netns exec ns_c netserver -d"
		rlRun "ip route add 192.168.$netid.171 dev $TEST_IFACE"
		rlRun "ip -6 route add 5010:$netid::171 dev $TEST_IFACE"

		rhts-sync-set -s IPVLAN_MULTIHOST_CLIENT_READY
		rhts-sync-block -s IPVLAN_MULTIHOST_MODE2_FINISH $SERVERS
		rlRun "ip route del 192.168.$netid.171 dev $TEST_IFACE"
		rlRun "ip -6 route del 5010:$netid::171 dev $TEST_IFACE"

		rlRun "ip netns exec ns_c ip route add default dev ipvlan_c"
		rlRun "ip netns exec ns_c ip -6 route add default dev ipvlan_c"
		rlRun "ip route add 192.168.$netid.171 via $REMOTE_ADDR4"
		rlRun "ip -6 route add 5010:$netid::171 via $REMOTE_ADDR6"

		for mode in l3 l3s
		do
			rlRun "ip netns exec ns_c ip link set ipvlan_c type ipvlan mode $mode"
			rhts-sync-set -s IPVLAN_MULTIHOST_${mode}_READY
			rhts-sync-block -s IPVLAN_MULTIHOST_${mode}_FINISH $SERVERS
		done

		rlRun "ip netns exec ns_c pkill netserver" "0-255"
		rlRun "ip netns del ns_c"
		rlRun "ip route del 192.168.$netid.171 via $REMOTE_ADDR4"
		rlRun "ip -6 route del 5010:$netid::171 via $REMOTE_ADDR6"
	else
		rlLog "not client or server"
	fi
rlPhaseEnd

}

local_netns()
{
rlPhaseStartTest "local_netns"
	local dev_features[0]="gso off gro off"
	local dev_features[1]="gso on gro on"
	rlRun "ip netns add client"
	rlRun "ip netns add server"
	rlRun "ip link add link $TEST_IFACE name ipvlan_c type ipvlan mode l3"
	rlRun "ip link add link $TEST_IFACE name ipvlan_s type ipvlan mode l3"
	rlRun "ip link set ipvlan_c netns client"
	rlRun "ip link set ipvlan_s netns server"

	rlRun "ip netns exec client ip link set lo up"
	rlRun "ip netns exec client ip link set ipvlan_c up"
	rlRun "ip netns exec server ip link set lo up"
	rlRun "ip netns exec server ip link set ipvlan_s up"

	rlRun "ip netns exec client ip addr add 1.1.1.171/24 dev ipvlan_c"
	rlRun "ip netns exec client ip -6 addr add 1111::171/64 dev ipvlan_c"
	rlRun "ip netns exec client ip route add 2.2.2.0/24 dev ipvlan_c"
	rlRun "ip netns exec client ip -6 route add 2222::/64 dev ipvlan_c"

	rlRun "ip netns exec server ip addr add 2.2.2.171/24 dev ipvlan_s"
	rlRun "ip netns exec server ip -6 addr add 2222::171/64 dev ipvlan_s"
	rlRun "ip netns exec server ip route add 1.1.1.0/24 dev ipvlan_s"
	rlRun "ip netns exec server ip -6 route add 1111::/64 dev ipvlan_s"

	rlRun "ip netns exec server netserver -d"
	rlRun "ip netns exec client ping 2.2.2.171 -c 5"
	rlRun "ip netns exec client ping6 2222::171 -c 5"
	rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t TCP_STREAM -l 2 -- -m 16k"
	rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t SCTP_STREAM -l 2 -- -m 16k"
	rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t UDP_STREAM -l 2 -- -R 1"

	rlRun "ip netns exec client netperf -6 -H 2222::171 -t TCP_STREAM -l 2 -- -m 16k"
	rlRun "ip netns exec client netperf -6 -H 2222::171 -t SCTP_STREAM -l 2 -- -m 16k"
	rlRun "ip netns exec client netperf -6 -H 2222::171 -t UDP_STREAM -l 2 -- -R 1"

	for mode in l2 l3s
	do
		rlRun "ip netns exec client ip link set ipvlan_c type ipvlan mode $mode"
		for feature_id in ${!dev_features[@]}
		do
			rlRun "ip netns exec server ethtool -K ipvlan_s ${dev_features[$feature_id]}"
			rlRun "ip netns exec server ethtool -k ipvlan_s"
			rlRun "ip netns exec client ping 2.2.2.171 -c 5"
			rlRun "ip netns exec client ping6 2222::171 -c 5"
			rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t TCP_STREAM -l 2 -- -m 16k"
			rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t SCTP_STREAM -l 2 -- -m 16k"
			rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t UDP_STREAM -l 2 -- -R 1"

			rlRun "ip netns exec client netperf -6 -H 2222::171 -t TCP_STREAM -l 2 -- -m 16k"
			rlRun "ip netns exec client netperf -6 -H 2222::171 -t SCTP_STREAM -l 2 -- -m 16k"
			rlRun "ip netns exec client netperf -6 -H 2222::171 -t UDP_STREAM -l 2 -- -R 1"
		done

	done

	rlRun "ip netns exec client ip link set ipvlan_c netns 1"
	rlRun "ip netns exec server pkill netserver" "0-255"
	rlRun "ip netns del client"
	rlRun "ip netns del server"
	rlRun "ip link del ipvlan_c"
	rlRun "ip link del ipvlan_s" "0-255"

rlPhaseEnd
}

local_stress_netns()
{
rlPhaseStartTest "local_stress_netns"
	rlRun "ip link add dummy0 type dummy" "0-255"
	rlRun "ip link set dummy0 up"
	for i in {1..10}
	do
		for j in {1..100}
		do
			let netns_num=(i-1)*100+j
			ip netns add netns$netns_num
			ip link add link dummy0 name ipvlan$netns_num type ipvlan mode l2
			ip link add link dummy0 name ipvlan$netns_num type ipvlan mode l2
			ip netns exec netns$netns_num ip link set lo up
			ip link set ipvlan$netns_num netns netns$netns_num
			ip netns exec netns$netns_num ip link set ipvlan$netns_num up
			ip netns exec netns$netns_num ip addr add 192.$i.$j.1/24 dev ipvlan$netns_num
			ip netns exec netns$netns_num ip route add 192.1.1.0/24 dev ipvlan$netns_num
			ip netns exec netns$netns_num ip -6 addr add 7777:$i:$j::1/64 dev ipvlan$netns_num
			ip netns exec netns$netns_num ip -6 route add 7777:1:1::/64 dev ipvlan$netns_num
			if [ $netns_num -ne 1 ]
			then
				ip netns exec netns1 ip route add 192.$i.$j.0/24 dev ipvlan1
				ip netns exec netns1 ip -6 route add 7777:$i:$j::/64 dev ipvlan1
			fi
		done
	done
	rlRun -l "ip netns exec netns1 ip a"

	rlRun "ip netns exec netns1 netserver -d"

	for mode in l2 l3 l3s
	do
		rlRun "ip netns exec netns1 ip link set ipvlan1 type ipvlan mode $mode"
		rlLog "start mode: $mode"
		rlRun "sleep 5"

		for i in {1..10}
		do
			for j in {1..100}
			do
				let netns_num=(i-1)*100+j
				if ! ip netns exec netns$netns_num ping -q 192.1.1.1 -c 1 &> /dev/null
				then
					rlLog "$netns_num ping fail"
					rlRun -l "ip netns exec netns$netns_num ping 192.1.1.1 -c 2"
					rlRun "ip netns exec netns$netns_num ip a"
				fi
				if ! ip netns exec netns$netns_num ping6 -q 7777:1:1::1 -c 1 &> /dev/null
				then
					rlLog "$netns_num ping6 fail"
					rlRun -l "ip netns exec netns$netns_num ping6 7777:1:1::1 -c 2"
					rlRun "ip netns exec netns$netns_num ip a"
				fi
			done
		done

		for i in {1..10}
		do
			for j in {1..100}
			do
				let netns_num=(i-1)*100+j
				ip netns exec netns$netns_num netperf -4 -H 192.1.1.1 -t UDP_STREAM -l 5 -- -R 1 &> ip4-netns$netns_num-udp.log &
				ip netns exec netns$netns_num netperf -4 -H 192.1.1.1 -t TCP_STREAM -l 5 -- -m 16k &> ip4-netns$netns_num-tcp.log &
				ip netns exec netns$netns_num netperf -4 -H 192.1.1.1 -t SCTP_STREAM -l 5 -- -m 16k &> ip4-netns$netns_num-sctp.log &
			done
		done
		rlWatchdog "wait" 300
		rlRun -l "grep errno ip4-netns*" "1"
		for i in {1..10}
		do
			for j in {1..100}
			do
				let netns_num=(i-1)*100+j
				ip netns exec netns$netns_num netperf -6 -H 7777:1:1::1 -t UDP_STREAM -l 5 -- -R 1 &> ip6-netns$netns_num-udp.log &
				ip netns exec netns$netns_num netperf -6 -H 7777:1:1::1 -t TCP_STREAM -l 5 -- -m 16k &> ip6-netns$netns_num-tcp.log &
				ip netns exec netns$netns_num netperf -6 -H 7777:1:1::1 -t SCTP_STREAM -l 5 -- -m 16k &> ip6-netns$netns_num-sctp.log &
			done
		done
		rlWatchdog "wait" 300
		rlLog "end mode: $mode"
		rlRun -l "grep errno ip6-netns*" "1"
	done

	rlRun "netns_clean.sh"
	rlRun "modprobe -r ipvlan"
	rlRun "ip link del dummy0"
rlPhaseEnd
}

ethtool_test()
{
rlPhaseStartTest "ethtool_test"
	local ethtool_setting=(-i -k -s -T -P)
	rlRun "ip netns add client"
	rlRun "ip netns add server"
	rlRun "ip link add link $TEST_IFACE name ipvlan_c type ipvlan mode l3"
	rlRun "ip link add link $TEST_IFACE name ipvlan_s type ipvlan mode l3"
	rlRun "ip link set ipvlan_c netns client"
	rlRun "ip link set ipvlan_s netns server"

	rlRun "ip netns exec client ip link set lo up"
	rlRun "ip netns exec client ip link set ipvlan_c up"
	rlRun "ip netns exec server ip link set lo up"
	rlRun "ip netns exec server ip link set ipvlan_s up"

	rlRun "ip netns exec client ip addr add 1.1.1.171/24 dev ipvlan_c"
	rlRun "ip netns exec client ip -6 addr add 1111::171/64 dev ipvlan_c"
	rlRun "ip netns exec client ip route add 2.2.2.0/24 dev ipvlan_c"
	rlRun "ip netns exec client ip -6 route add 2222::/64 dev ipvlan_c"

	rlRun "ip netns exec server ip addr add 2.2.2.171/24 dev ipvlan_s"
	rlRun "ip netns exec server ip -6 addr add 2222::171/64 dev ipvlan_s"
	rlRun "ip netns exec server ip route add 1.1.1.0/24 dev ipvlan_s"
	rlRun "ip netns exec server ip -6 route add 1111::/64 dev ipvlan_s"

	rlRun "ip netns exec server ethtool ipvlan_s"

	rlRun "ip netns exec server netserver -d"
	rlRun "ip netns exec client ping 2.2.2.171 -c 3"
	rlRun "ip netns exec client ping6 2222::171 -c 3"
	rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t TCP_STREAM -l 1 -- -m 16k"
	rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t SCTP_STREAM -l 1 -- -m 16k"
	rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t UDP_STREAM -l 1 -- -R 1"

	rlRun "ip netns exec client netperf -6 -H 2222::171 -t TCP_STREAM -l 1 -- -m 16k"
	rlRun "ip netns exec client netperf -6 -H 2222::171 -t SCTP_STREAM -l 1 -- -m 16k"
	rlRun "ip netns exec client netperf -6 -H 2222::171 -t UDP_STREAM -l 1 -- -R 1"

	for setting_para in ${!ethtool_setting[@]}
	do
		rlRun "ip netns exec server ethtool ${ethtool_setting[$setting_para]} ipvlan_s "
		rlRun "ip netns exec client ping 2.2.2.171 -c 1"
		rlRun "ip netns exec client ping6 2222::171 -c 1"
		rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t TCP_STREAM -l 1 -- -m 16k"
		rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t SCTP_STREAM -l 1 -- -m 16k"
		rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t UDP_STREAM -l 1 -- -R 1"

		rlRun "ip netns exec client netperf -6 -H 2222::171 -t TCP_STREAM -l 1 -- -m 16k"
		rlRun "ip netns exec client netperf -6 -H 2222::171 -t SCTP_STREAM -l 1 -- -m 16k"
		rlRun "ip netns exec client netperf -6 -H 2222::171 -t UDP_STREAM -l 1 -- -R 1"
	done

	rlRun "ip netns exec client ip link set ipvlan_c netns 1"
	rlRun "ip netns exec server pkill netserver" "0-255"
	rlRun "ip netns del client"
	rlRun "ip netns del server"
	rlRun "ip link del ipvlan_c"
	rlRun "ip link del ipvlan_s" "0-255"

rlPhaseEnd
}

link_test()
{
rlPhaseStartTest "link_test"
	local link_setting[0]="numtxqueues 1"
	local link_setting[1]="numrxqueues 1"
	local link_setting[2]="txqueuelen 1000"
	rlRun "ip netns add client"
	rlRun "ip netns add server"
	rlRun "ip link add link $TEST_IFACE mtu 1300 index 111 numtxqueues 4 numrxqueues 4 txqueuelen 100 name ipvlan_c type ipvlan mode l3"
	rlRun "mtu_val=`cat /sys/class/net/ipvlan_c/mtu`"
	rlRun "qlen_val=`cat /sys/class/net/ipvlan_c/tx_queue_len`"
	rlRun "index_val=`cat /sys/class/net/ipvlan_c/ifindex`"
	rlRun "txqueue_val=`ls -l /sys/class/net/ipvlan_c/queues | grep -c tx`"
	rlRun "rxqueue_val=`ls -l /sys/class/net/ipvlan_c/queues | grep -c rx`"

	rlAssertEquals "mtu:$mtu_val should be 1300" $mtu_val 1300
	rlAssertEquals "qlen:$qlen_val should be 100" $qlen_val 100
	rlAssertEquals "index:$index_val should be 111" $index_val 111
	rlAssertEquals "txqueue:$txqueue_val should be 4" $txqueue_val 4
	rlAssertEquals "rxqueue:$rxqueue_val should be 4" $rxqueue_val 4

	rlRun "ip link set ipvlan_c mtu 1500"

	rlRun "ip link add link $TEST_IFACE name ipvlan_s type ipvlan mode l3"
	rlRun "ip link set ipvlan_c netns client"
	rlRun "ip link set ipvlan_s netns server"

	rlRun "ip netns exec client ip link set lo up"
	rlRun "ip netns exec client ip link set ipvlan_c up"
	rlRun "ip netns exec server ip link set lo up"
	rlRun "ip netns exec server ip link set ipvlan_s up"

	rlRun "ip netns exec client ip addr add 1.1.1.171/24 dev ipvlan_c"
	rlRun "ip netns exec client ip -6 addr add 1111::171/64 dev ipvlan_c"
	rlRun "ip netns exec client ip route add 2.2.2.0/24 dev ipvlan_c"
	rlRun "ip netns exec client ip -6 route add 2222::/64 dev ipvlan_c"

	rlRun "ip netns exec server ip addr add 2.2.2.171/24 dev ipvlan_s"
	rlRun "ip netns exec server ip -6 addr add 2222::171/64 dev ipvlan_s"
	rlRun "ip netns exec server ip route add 1.1.1.0/24 dev ipvlan_s"
	rlRun "ip netns exec server ip -6 route add 1111::/64 dev ipvlan_s"

	rlRun "ip netns exec server ethtool ipvlan_s"

	rlRun "ip netns exec server netserver -d"
	rlRun "ip netns exec client ping 2.2.2.171 -c 3"
	rlRun "ip netns exec client ping6 2222::171 -c 3"
	rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t TCP_STREAM -l 1 -- -m 16k"
	rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t SCTP_STREAM -l 1 -- -m 16k"
	rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t UDP_STREAM -l 1 -- -R 1"

	rlRun "ip netns exec client netperf -6 -H 2222::171 -t TCP_STREAM -l 1 -- -m 16k"
	rlRun "ip netns exec client netperf -6 -H 2222::171 -t SCTP_STREAM -l 1 -- -m 16k"
	rlRun "ip netns exec client netperf -6 -H 2222::171 -t UDP_STREAM -l 1 -- -R 1"

	for setting_para in ${!link_setting[@]}
	do
		rlRun "ip netns exec client ip link set ipvlan_c ${link_setting[$setting_para]}"
		rlRun "ip netns exec client ping 2.2.2.171 -c 1"
		rlRun "ip netns exec client ping6 2222::171 -c 1"
		rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t TCP_STREAM -l 1 -- -m 16k"
		rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t SCTP_STREAM -l 1 -- -m 16k"
		rlRun "ip netns exec client netperf -4 -H 2.2.2.171 -t UDP_STREAM -l 1 -- -R 1"

		rlRun "ip netns exec client netperf -6 -H 2222::171 -t TCP_STREAM -l 1 -- -m 16k"
		rlRun "ip netns exec client netperf -6 -H 2222::171 -t SCTP_STREAM -l 1 -- -m 16k"
		rlRun "ip netns exec client netperf -6 -H 2222::171 -t UDP_STREAM -l 1 -- -R 1"
	done

	rlRun "ip netns exec client ip link set ipvlan_c netns 1"
	rlRun "ip netns exec server pkill netserver" "0-255"
	rlRun "ip netns del client"
	rlRun "ip netns del server"
	rlRun "ip link del ipvlan_c"
	rlRun "ip link del ipvlan_s" "0-255"

rlPhaseEnd
}

abnormal_test()
{
rlPhaseStartTest "abnormal_test"
	rlRun "ip link add dummy0 type dummy" "0-255"
	rlRun "ip link set dummy0 up"
	# add same addr for two ipvlan over one device
	rlLog "add same addr for two ipvlan over one device"
	rlRun "ip link add link dummy0 name ipvlan1 type ipvlan mode l3"
	rlRun "ip link add link dummy0 name ipvlan2 type ipvlan mode l3"
	rlRun "ip link set ipvlan1 up"
	rlRun "ip link add link ipvlan1 name ipvlan1.3 type vlan id 3" "0-255"
	rlRun "ip link set ipvlan1.3 up" "0-255"
	rlRun "ip link del ipvlan1.3" "0-255"
	rlRun "ip link set ipvlan2 up"
	rlRun "ip addr add 1.1.1.1/24 dev ipvlan1"
	rlRun "ip addr add 1.1.1.1/24 dev ipvlan2" "1-255"
	rlRun "ip addr add 1.1.1.1/24 dev ipvlan2" "1-255"

	for id in {3..1000}
	do
		ip link add link ipvlan$((id-1)) name ipvlan$id type ipvlan mode l3
		ip link set ipvlan$id up
	done

	rlRun "ip link del dummy0"
	rlRun "modprobe -r ipvlan"

	rlRun "netns_clean.sh"
	rlRun "modprobe -r ipvlan"
rlPhaseEnd
}

ipvlan_o_ipvlan_test()
{
rlPhaseStartTest "ipvlan_o_ipvlan_test"
	rlRun "ip link add dummy0 type dummy" "0-255"
	rlRun "ip link set dummy0 up"

	for ipvlan_mode in l2 l3 l3s
	do
		rlRun "ip link add link dummy0 name ipvlan1 type ipvlan mode $ipvlan_mode"

		for internal_mode in l2 l3 l3s
		do
			rlRun "ip link add link ipvlan1 name ipvlan11 type ipvlan mode $ipvlan_mode"
			rlRun "ip link add link ipvlan1 name ipvlan12 type ipvlan mode $ipvlan_mode"

			rlRun "ip netns add client"
			rlRun "ip netns add server"

			rlRun "ip link set ipvlan11 netns client"
			rlRun "ip link set ipvlan12 netns server"

			rlRun "ip netns exec client ip link set lo up"
			rlRun "ip netns exec client ip link set ipvlan11 up"
			rlRun "ip netns exec server ip link set lo up"
			rlRun "ip netns exec server ip link set ipvlan12 up"

			rlRun "ip netns exec client ip addr add 1.1.1.1/24 dev ipvlan11"
			rlRun "ip netns exec client ip addr add 1111::1/64 dev ipvlan11"
			rlRun "ip netns exec server ip addr add 1.1.1.2/24 dev ipvlan12"
			rlRun "ip netns exec server ip addr add 1111::2/64 dev ipvlan12"

			rlRun "ip netns exec server netserver -d"
			rlRun "ip netns exec client ping 1.1.1.2 -c 3"
			rlRun "ip netns exec client ping6 1111::2 -c 3"
			rlRun "ip netns exec client netperf -4 -H 1.1.1.2 -t TCP_STREAM -l 1 -- -m 16k"
			rlRun "ip netns exec client netperf -4 -H 1.1.1.2 -t SCTP_STREAM -l 1 -- -m 16k"
			rlRun "ip netns exec client netperf -4 -H 1.1.1.2 -t UDP_STREAM -l 1 -- -R 1"
			rlRun "ip netns exec client netperf -6 -H 1111::2 -t TCP_STREAM -l 1 -- -m 16k"
			rlRun "ip netns exec client netperf -6 -H 1111::2 -t SCTP_STREAM -l 1 -- -m 16k"
			rlRun "ip netns exec client netperf -6 -H 1111::2 -t UDP_STREAM -l 1 -- -R 1"

			rlRun "ip netns exec server pkill netserver" "0-255"
			rlRun "ip netns exec client ip link del ipvlan11"
			rlRun "ip netns del client"
			rlRun "ip netns del server"
			rlRun "ip link del ipvlan12" "0-255"
		done

		rlRun "ip link del ipvlan1"
	done
	# add same addr for two ipvlan over one device

	rlRun "netns_clean.sh"
	rlRun "modprobe -r ipvlan"
rlPhaseEnd
}

multicast_test()
{
rlPhaseStartTest "multicast_test"
	rlRun "mtools_install"
	rlRun "rm -f mdump_v* -f" "0-255"
if i_am_server
then
	if [ -z "$IFACE_NAME" ]
	then
		NAY=yes
		rlRun "get_test_iface"
		IFACE_NAME=$TEST_IFACE
		rlRun "dhclient -v $IFACE_NAME"
	fi
	for i in `seq 1 100`
	do
		ip netns add test$i
		ip link add link $IFACE_NAME name ipvlan$i type ipvlan mode l2
		ip link set ipvlan$i netns test$i
		ip netns exec test$i ip link set lo up
		ip netns exec test$i ip link set ipvlan$i up
		ip netns exec test$i ip addr add 1.1.1.$i/24 dev ipvlan$i
		ip netns exec test$i ip addr add 1111::$i/64 dev ipvlan$i
		ip netns exec test$i sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=0
		ip netns exec test$i ip route add default dev ipvlan$i
		ip netns exec test$i ip -6 route add default dev ipvlan$i
	done

	for i in `seq 1 100`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_1.log -s 224.9.10.1 12961 ipvlan$i &
	done
	for i in `seq 1 90`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_2.log -s 224.9.10.2 12962 ipvlan$i &
	done
	for i in `seq 1 80`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_3.log -s 224.9.10.3 12963 ipvlan$i &
	done
	for i in `seq 1 70`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_4.log -s 224.9.10.4 12964 ipvlan$i &
	done
	for i in `seq 1 60`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_5.log -s 224.9.10.5 12965 ipvlan$i &
	done
	for i in `seq 1 50`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_6.log -s 224.9.10.6 12966 ipvlan$i &
	done
	for i in `seq 1 40`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_7.log -s 224.9.10.7 12967 ipvlan$i &
	done
	for i in `seq 1 30`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_8.log -s 224.9.10.8 12968 ipvlan$i &
	done
	for i in `seq 1 20`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_9.log -s 224.9.10.9 12969 ipvlan$i &
	done
	for i in `seq 1 10`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_10.log -s 224.9.10.10 12970 ipvlan$i &
	done
	rlRun "sleep 5"
	rhts-sync-set -s IPVLAN_BASIC_MULTICAST_SERVER_V4_MDUMP_READY
	rhts-sync-block -s IPVLAN_BASIC_MULTICAST_CLIENT_V4_MSEND_DONE $CLIENTS

	rlRun "sleep 5"
	if [ "`grep '0.000000% loss' mdump_v4*_1.log | wc -l`" -ne 100 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_1.log"
		rlFail "group 224.9.10.1 fail, not 100 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_2.log | wc -l`" -ne 90 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_2.log"
		rlFail "group 224.9.10.2 fail, not 90 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_3.log | wc -l`" -ne 80 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_3.log"
		rlFail "group 224.9.10.3 fail, not 80 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_4.log | wc -l`" -ne 70 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_4.log"
		rlFail "group 224.9.10.4 fail, not 70 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_5.log | wc -l`" -ne 60 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_5.log"
		rlFail "group 224.9.10.5 fail, not 60 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_6.log | wc -l`" -ne 50 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_6.log"
		rlFail "group 224.9.10.6 fail, not 50 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_7.log | wc -l`" -ne 40 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_7.log"
		rlFail "group 224.9.10.7 fail, not 40 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_8.log | wc -l`" -ne 30 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_8.log"
		rlFail "group 224.9.10.8 fail, not 30 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_9.log | wc -l`" -ne 20 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_9.log"
		rlFail "group 224.9.10.9 fail, not 20 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_10.log | wc -l`" -ne 10 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_10.log"
		rlFail "group 224.9.10.10 fail, not 10 0.000000% loss"
	fi

	rlLog "ipv6 multicast"

	for i in `seq 1 100`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_1.log -s ff0e:1234::1 12961 ipvlan$i &
	done
	for i in `seq 1 90`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_2.log -s ff0e:1234::2 12962 ipvlan$i &
	done
	for i in `seq 1 80`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_3.log -s ff0e:1234::3 12963 ipvlan$i &
	done
	for i in `seq 1 70`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_4.log -s ff0e:1234::4 12964 ipvlan$i &
	done
	for i in `seq 1 60`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_5.log -s ff0e:1234::5 12965 ipvlan$i &
	done
	for i in `seq 1 50`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_6.log -s ff0e:1234::6 12966 ipvlan$i &
	done
	for i in `seq 1 40`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_7.log -s ff0e:1234::7 12967 ipvlan$i &
	done
	for i in `seq 1 30`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_8.log -s ff0e:1234::8 12968 ipvlan$i &
	done
	for i in `seq 1 20`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_9.log -s ff0e:1234::9 12969 ipvlan$i &
	done
	for i in `seq 1 10`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_10.log -s ff0e:1234::10 12970 ipvlan$i &
	done
	rlRun "sleep 5"
	rhts-sync-set -s IPVLAN_BASIC_MULTICAST_SERVER_V6_MDUMP_READY
	rhts-sync-block -s IPVLAN_BASIC_MULTICAST_CLIENT_V6_MSEND_DONE $CLIENTS
	rlRun "sleep 5"

	if [ "`grep '0.000000% loss' mdump_v6*_1.log | wc -l`" -ne 100 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_1.log"
		rlFail "group 224.9.10.1 fail, not 100 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_2.log | wc -l`" -ne 90 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_2.log"
		rlFail "group 224.9.10.2 fail, not 90 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_3.log | wc -l`" -ne 80 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_3.log"
		rlFail "group 224.9.10.3 fail, not 80 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_4.log | wc -l`" -ne 70 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_4.log"
		rlFail "group 224.9.10.4 fail, not 70 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_5.log | wc -l`" -ne 60 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_5.log"
		rlFail "group 224.9.10.5 fail, not 60 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_6.log | wc -l`" -ne 50 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_6.log"
		rlFail "group 224.9.10.6 fail, not 50 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_7.log | wc -l`" -ne 40 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_7.log"
		rlFail "group 224.9.10.7 fail, not 40 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_8.log | wc -l`" -ne 30 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_8.log"
		rlFail "group 224.9.10.8 fail, not 30 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_9.log | wc -l`" -ne 20 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_9.log"
		rlFail "group 224.9.10.9 fail, not 20 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_10.log | wc -l`" -ne 10 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_10.log"
		rlFail "group 224.9.10.10 fail, not 10 0.000000% loss"
	fi


	rlRun "netns_clean.sh"
	rlRun "modprobe -r ipvlan" "0-255"

elif i_am_client
then
	if [ -z "$IFACE_NAME" ]
	then
		NAY=yes
		rlRun "get_test_iface"
		IFACE_NAME=$TEST_IFACE
		rlRun "dhclient -v $IFACE_NAME"
	fi
	rhts-sync-block -s IPVLAN_BASIC_MULTICAST_SERVER_V4_MDUMP_READY $SERVERS
	rlRun "sleep 5"

	port_num=12960
	for i in `seq 1 10`
	do
		let port_num++
		rlRun "msend -qq -1 224.9.10.$i $port_num 15 $IFACE_NAME"
	done
	rhts-sync-set -s IPVLAN_BASIC_MULTICAST_CLIENT_V4_MSEND_DONE
	rhts-sync-block -s IPVLAN_BASIC_MULTICAST_SERVER_V6_MDUMP_READY $SERVERS
	rlRun "sleep 5"

	port_num=12960
	for i in `seq 1 10`
	do
		let port_num++
		rlRun "msend -qq -f 6 -1 ff0e:1234::$i $port_num 15 $IFACE_NAME"
	done
	rhts-sync-set -s IPVLAN_BASIC_MULTICAST_CLIENT_V6_MSEND_DONE

else
	rlRun "ip link add dummy1 type dummy"
	rlRun "ip link set dummy1 up"
	for i in `seq 1 100`
	do
		ip netns add test$i
		ip link add link dummy1 name ipvlan$i type ipvlan mode l2
		ip link set ipvlan$i netns test$i
		ip netns exec test$i ip link set lo up
		ip netns exec test$i ip link set ipvlan$i up
		ip netns exec test$i ip addr add 1.1.1.$i/24 dev ipvlan$i
		ip netns exec test$i ip addr add 1111::$i/64 dev ipvlan$i
		ip netns exec test$i sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=0
	done

	for i in `seq 1 100`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_1.log -s 224.9.10.1 12961 ipvlan$i &
	done
	for i in `seq 1 90`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_2.log -s 224.9.10.2 12962 ipvlan$i &
	done
	for i in `seq 1 80`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_3.log -s 224.9.10.3 12963 ipvlan$i &
	done
	for i in `seq 1 70`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_4.log -s 224.9.10.4 12964 ipvlan$i &
	done
	for i in `seq 1 60`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_5.log -s 224.9.10.5 12965 ipvlan$i &
	done
	for i in `seq 1 50`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_6.log -s 224.9.10.6 12966 ipvlan$i &
	done
	for i in `seq 1 40`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_7.log -s 224.9.10.7 12967 ipvlan$i &
	done
	for i in `seq 1 30`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_8.log -s 224.9.10.8 12968 ipvlan$i &
	done
	for i in `seq 1 20`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_9.log -s 224.9.10.9 12969 ipvlan$i &
	done
	for i in `seq 1 10`
	do
		ip netns exec test$i mdump -q -omdump_v4_${i}_10.log -s 224.9.10.10 12970 ipvlan$i &
	done
	rlRun "sleep 10"
	rlRun "ip netns add test0"
	rlRun "ip link add link dummy1 name ipvlan0 type ipvlan mode l2"
	rlRun "ip link set ipvlan0 netns test0"
	rlRun "ip netns exec test0 ip link set lo up"
	rlRun "ip netns exec test0 ip link set ipvlan0 up"
	rlRun "ip netns exec test0 ip addr add 1.1.1.200/24 dev ipvlan0"
	rlRun "ip netns exec test0 ip addr add 1111::200/64 dev ipvlan0"

	port_num=12960
	for i in `seq 1 10`
	do
		let port_num++
		rlRun "ip netns exec test0 msend -qq -1 224.9.10.$i $port_num 15 ipvlan0"
	done

	rlRun "sleep 5"
	if [ "`grep '0.000000% loss' mdump_v4*_1.log | wc -l`" -ne 100 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_1.log"
		rlFail "group 224.9.10.1 fail, not 100 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_2.log | wc -l`" -ne 90 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_2.log"
		rlFail "group 224.9.10.2 fail, not 90 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_3.log | wc -l`" -ne 80 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_3.log"
		rlFail "group 224.9.10.3 fail, not 80 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_4.log | wc -l`" -ne 70 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_4.log"
		rlFail "group 224.9.10.4 fail, not 70 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_5.log | wc -l`" -ne 60 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_5.log"
		rlFail "group 224.9.10.5 fail, not 60 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_6.log | wc -l`" -ne 50 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_6.log"
		rlFail "group 224.9.10.6 fail, not 50 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_7.log | wc -l`" -ne 40 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_7.log"
		rlFail "group 224.9.10.7 fail, not 40 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_8.log | wc -l`" -ne 30 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_8.log"
		rlFail "group 224.9.10.8 fail, not 30 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_9.log | wc -l`" -ne 20 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_9.log"
		rlFail "group 224.9.10.9 fail, not 20 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v4*_10.log | wc -l`" -ne 10 ]
	then
		rlRun "grep '0.000000% loss' mdump_v4*_10.log"
		rlFail "group 224.9.10.10 fail, not 10 0.000000% loss"
	fi

	rlLog "ipv6 multicast"

	for i in `seq 1 100`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_1.log -s ff0e:1234::1 12961 ipvlan$i &
	done
	for i in `seq 1 90`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_2.log -s ff0e:1234::2 12962 ipvlan$i &
	done
	for i in `seq 1 80`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_3.log -s ff0e:1234::3 12963 ipvlan$i &
	done
	for i in `seq 1 70`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_4.log -s ff0e:1234::4 12964 ipvlan$i &
	done
	for i in `seq 1 60`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_5.log -s ff0e:1234::5 12965 ipvlan$i &
	done
	for i in `seq 1 50`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_6.log -s ff0e:1234::6 12966 ipvlan$i &
	done
	for i in `seq 1 40`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_7.log -s ff0e:1234::7 12967 ipvlan$i &
	done
	for i in `seq 1 30`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_8.log -s ff0e:1234::8 12968 ipvlan$i &
	done
	for i in `seq 1 20`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_9.log -s ff0e:1234::9 12969 ipvlan$i &
	done
	for i in `seq 1 10`
	do
		ip netns exec test$i mdump -q -f 6 -omdump_v6_${i}_10.log -s ff0e:1234::10 12970 ipvlan$i &
	done
	rlRun "sleep 10"

	port_num=12960
	for i in `seq 1 10`
	do
		let port_num++
		rlRun "ip netns exec test0 msend -qq -f 6 -1 ff0e:1234::$i $port_num 15 ipvlan0"
	done

	rlRun "sleep 5"
	if [ "`grep '0.000000% loss' mdump_v6*_1.log | wc -l`" -ne 100 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_1.log"
		rlFail "group 224.9.10.1 fail, not 100 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_2.log | wc -l`" -ne 90 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_2.log"
		rlFail "group 224.9.10.2 fail, not 90 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_3.log | wc -l`" -ne 80 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_3.log"
		rlFail "group 224.9.10.3 fail, not 80 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_4.log | wc -l`" -ne 70 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_4.log"
		rlFail "group 224.9.10.4 fail, not 70 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_5.log | wc -l`" -ne 60 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_5.log"
		rlFail "group 224.9.10.5 fail, not 60 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_6.log | wc -l`" -ne 50 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_6.log"
		rlFail "group 224.9.10.6 fail, not 50 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_7.log | wc -l`" -ne 40 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_7.log"
		rlFail "group 224.9.10.7 fail, not 40 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_8.log | wc -l`" -ne 30 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_8.log"
		rlFail "group 224.9.10.8 fail, not 30 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_9.log | wc -l`" -ne 20 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_9.log"
		rlFail "group 224.9.10.9 fail, not 20 0.000000% loss"
	fi

	if [ "`grep '0.000000% loss' mdump_v6*_10.log | wc -l`" -ne 10 ]
	then
		rlRun "grep '0.000000% loss' mdump_v6*_10.log"
		rlFail "group 224.9.10.10 fail, not 10 0.000000% loss"
	fi

	rlRun "netns_clean.sh"
	rlRun "ip link del dummy1"
	rlRun "modprobe -r ipvlan" "0-255"

fi
rlPhaseEnd
}

dhcp_test()
{
rlPhaseStartTest "dhcp_test"
	rlRun "ip netns add client"
	rlRun "ip netns add server"
	rlRun "ip link add veth0_c type veth peer name veth0_s"
	rlRun "ip link set veth0_c netns client"
	rlRun "ip link set veth0_s netns server"
	rlRun "ip netns exec client ip link set lo up"
	rlRun "ip netns exec client ip link set veth0_c up"
	rlRun "ip netns exec server ip link set veth0_s up"
	rlRun "ip netns exec server ip addr add 1.1.1.1/24 dev veth0_s"
	rlRun "ip netns exec server ip addr add 1111::1/64 dev veth0_s"
	rlRun "yum install dhcp-server -y" "0-255"
	rlRun "cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak"
	cat > /etc/dhcp/dhcpd.conf << EOF
default-lease-time 600;
max-lease-time 7200;

if exists dhcp-client-identifier {
	    option dhcp-client-identifier = option dhcp-client-identifier;
	}

subnet 1.1.1.0 netmask 255.255.255.0 {
	    range 1.1.1.10 1.1.1.240;
	}
EOF
	rlRun "cat /etc/dhcp/dhcpd.conf"
	rlRun "ip netns exec client ip link add link veth0_c name ipvlan1 type ipvlan mode l2"
	rlRun "ip netns exec client ip link set ipvlan1 up"
	rlRun "ip netns exec server dhcpd -cf /etc/dhcp/dhcpd.conf -user dhcpd -group dhcpd --no-pid veth0_s"
	rlRun "sleep 2"
	rlRun "ip netns exec client dhclient -B -v ipvlan1 --request-options dhcp-client-identifier --no-pid"
	rlRun "ip netns exec client ip addr show ipvlan1 | grep 1.1.1"
	rlRun "ip netns exec client dhclient -r ipvlan1"
	rlRun "ip netns exec server pkill dhcpd"
	rlRun "ip netns exec client pkill dhclient"
	rlRun "rm -f /etc/dhcp/dhcpd.conf && mv /etc/dhcp/dhcpd.conf.bak /etc/dhcp/dhcpd.conf"

	rlRun "cp /etc/dhcp/dhcpd6.conf /etc/dhcp/dhcpd6.conf.bak"
	cat > /etc/dhcp/dhcpd6.conf << EOF
default-lease-time 2592000;
preferred-lifetime 604800;

if exists dhcp-client-identifier {
	    option dhcp-client-identifier = option dhcp-client-identifier;
	}

subnet6 1111::/64 {
	    range6 1111::100 1111::1111;
	}
EOF
	rlRun "ip netns exec server dhcpd -6 -cf /etc/dhcp/dhcpd6.conf -user dhcpd -group dhcpd --no-pid veth0_s"
	rlRun "sleep 2"
	rlRun "ip netns exec client dhclient -6 -B -v ipvlan1 --request-options dhcp-client-identifier --no-pid"
	rlRun "ip netns exec client ip -6 addr sh ipvlan1 | grep 1111::"
	rlRun "ip netns exec client pkill dhclient"
	rlRun "ip netns exec server pkill dhcpd"
	rlRun "rm -f /etc/dhcp/dhcpd6.conf && cp /etc/dhcp/dhcpd6.conf.bak /etc/dhcp/dhcpd6.conf"

	rlRun "netns_clean.sh"
rlPhaseEnd

}

# a single mac address is seen by the peer of an arbitrary large ipvlan netns set
mac_pollution()
{
rlPhaseStartTest "mac_pollution"
if i_am_server
then
	rlRun "get_test_iface_and_addr"
	for i in {1..10}
	do
		rlRun "ip netns add netns$i"
		rlRun "ip link add link $TEST_IFACE name ipvlan$i type ipvlan mode l2"
		rlRun "ip link set ipvlan$i netns netns$i"
		rlRun "ip netns exec netns$i ip link set lo up"
		rlRun "ip netns exec netns$i ip link set ipvlan$i up"
		rlRun "ip netns exec netns$i ip addr add 1.1.1.$i/24 dev ipvlan$i"
		rlRun "ip netns exec netns$i ip -6 addr add 1111::$i/64 dev ipvlan$i"
		rlRun "ip netns exec netns$i ip route add default dev ipvlan$i"
		rlRun "ip netns exec netns$i ip -6 route change default dev ipvlan$i || \
			ip netns exec netns$i ip -6 route add default dev ipvlan$i"
	done
	rhts-sync-set -s IPVLAN_MAC_POLLUTION_SERVER_READY
	rhts-sync-block -s IPVLAN_MAC_POLLUTION_CLIENT_DONE $CLIENTS
	rlRun "netns_clean.sh"
	rlRun "modprobe -r ipvlan"
elif i_am_client
then
	rlRun "get_test_iface_and_addr"
	rlRun "ip route add 1.1.1.0/24 dev $TEST_IFACE"
	rlRun "ip -6 route add 1111::/64 dev $TEST_IFACE"
	rhts-sync-block -s IPVLAN_MAC_POLLUTION_SERVER_READY $SERVERS
	rlRun "ping 1.1.1.1 -c 2"
	rlRun "ipvlan_mac=`ip neigh show | grep 1.1.1.1 | grep -o "lladdr [^ ]*" | awk '{print $2}'`"
	for i in {2..10}
	do
		rlRun "ping 1.1.1.$i -c 2"
		rlRun "ip neigh show | grep \"1.1.1.$i.*$ipvlan_mac\""
		[ $? -ne 0 ] && rlRun -l "ip neigh show"
	done
	rlRun "ping6 1111::1 -c 2"
	rlRun "ipvlan_mac=`ip -6 neigh show | grep 1111::1 | grep -o "lladdr [^ ]*" | awk '{print $2}'`"
	for i in {2..10}
	do
		rlRun "ping6 1111::$i -c 2"
		rlRun "ip -6 neigh show | grep \"1111::$i.*$ipvlan_mac\""
		[ $? -ne 0 ] && rlRun -l "ip -6 neigh show"
	done
	rhts-sync-set -s IPVLAN_MAC_POLLUTION_CLIENT_DONE
	rlRun "ip route del 1.1.1.0/24 dev $TEST_IFACE"
	rlRun "ip -6 route del 1111::/64 dev $TEST_IFACE"
else
	rlRun "ip link del dummy0" "0-255"
	rlRun "ip link add dummy0 type dummy"
	rlRun "ip link set dummy0 up"
	rlRun "dummy_mac=`ip link sh dummy0 | grep link/ether | awk '{print $2}'`"
	for i in {1..10}
	do
		rlRun "ip netns add netns$i"
		rlRun "ip link add link dummy0 name ipvlan$i type ipvlan mode l2"
		rlRun "ip link set ipvlan$i netns netns$i"
		rlRun "ip netns exec netns$i ip link set lo up"
		rlRun "ip netns exec netns$i ip link set ipvlan$i up"
		rlRun "ip netns exec netns$i ip addr add 1.1.1.$i/24 dev ipvlan$i"
		rlRun "ip netns exec netns$i ip addr add 1111::$i/64 dev ipvlan$i"
	done

	for i in {2..10}
	do
		rlRun "ip netns exec netns1 ping 1.1.1.$i -c 2"
		rlRun "ip netns exec netns1 ip neigh sh | grep \"1.1.1.$i.*$dummy_mac\""
		[ $? -ne 0 ] && rlRun -l "ip netns exec netns1 ip neigh sh"
		rlRun "ip netns exec netns1 ping6 1111::$i -c 2"
		rlRun "ip netns exec netns1 ip -6 neigh show | grep \"1111::$i.*$dummy_mac\""
		[ $? -ne 0 ] && rlRun -l "ip netns exec netns1 ip -6 neigh sh"
	done
	dummy_mac_new="00:11:11:11:11:11"
	rlRun "ip link set dummy0 address $dummy_mac_new"
	for i in {2..10}
	do
		rlRun "ip netns exec netns1 ping 1.1.1.$i -c 2"
		rlRun "ip netns exec netns1 ip neigh sh | grep \"1.1.1.$i.*$dummy_mac_new\""
		[ $? -ne 0 ] && rlRun -l "ip netns exec netns1 ip neigh sh"
		rlRun "ip netns exec netns1 ping6 1111::$i -c 2"
		rlRun "ip netns exec netns1 ip -6 neigh show | grep \"1111::$i.*$dummy_mac_new\""
		[ $? -ne 0 ] && rlRun -l "ip netns exec netns1 ip -6 neigh sh"
	done
	rlRun "ip link set dummy0 address $dummy_mac"

	rlRun "netns_clean.sh"
	rlRun "ip link del dummy0"
fi

rlPhaseEnd
}


# Parameters
# not run local_stress as it cost too much time
TEST_ITEMS_ALL="local_netns multihost_netns ethtool_test link_test abnormal_test ipvlan_o_ipvlan_test multicast_test dhcp_test mac_pollution"
TEST_ITEMS=${TEST_ITEMS:-$TEST_ITEMS_ALL}

rlJournalStart
	rlPhaseStartSetup
	rlRun "get_test_iface"
	rlRun "netperf_install"
	rlPhaseEnd

if ip link add link $TEST_IFACE name ipvlan1 type ipvlan mode l3
then
	ip link del ipvlan1
	for test_item in $TEST_ITEMS
	do
		$test_item
	done
else
	rlLog "not support"
	rhts-report-result "$TEST" SKIP "$OUTPUTFILE"
	exit 0
fi

	rlPhaseStartCleanup
	rlPhaseEnd
rlJournalEnd
