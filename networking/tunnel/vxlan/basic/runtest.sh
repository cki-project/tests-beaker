#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of networking/tunnel/vxlan/basic
#   Description: vxlan basic test
#   Author: Jianlin Shi<jishi@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment

# for CKI
[ ! -f /usr/local/bin/netns_clean.sh ] && rm /dev/shm/network_common_initalized -f

. ../../../common/include.sh || exit 1
. ../../common/include.sh || exit 1
. ../../../../cki_lib/libcki.sh || exit 1

YUM=$(cki_get_yum_tool)

kernel_name=$(uname -r)
if [[ $kernel_name =~ "rt" ]]; then
     echo "running the $kernel_name" | tee -a $OUTPUTFILE
     $YUM install -y kernel-rt-modules-extra
fi

# Functions

basic()
{
	local gre_devname=vxlan1
	local gre_c_ip4="192.168.6.2"
	local gre_c_ip4net="192.168.6.0/24"
	local gre_c_ip6="6001:db8:ac10:fe01::2"
	local gre_c_ip6net="6001:db8:ac10:fe01::0/64"
	local gre_s_ip4="192.168.7.2"
	local gre_s_ip4net="192.168.7.0/24"
	local gre_s_ip6="7001:db8:ac10:fe01::2"
	local gre_s_ip6net="7001:db8:ac10:fe01::0/64"
	local mcast_group[4]="239.1.1.1"
	local mcast_group[6]="ff03::1"
	local remote_type=""
	local ipversion_type=""
	if uname -r | grep "^2"
	then
		remote_type="mcast"
		ipversion_type="4"
	else
		remote_type="unicast mcast"
		ipversion_type="4 6"
	fi

rlPhaseStartTest "basic_$TOPO"
if i_am_server
then
	rlRun "get_test_iface_and_addr"

	for ipversion in $ipversion_type
	do
		for remote in $remote_type
		do
			if [ $remote == "mcast" ]
			then
				rlRun "ip link add $gre_devname type vxlan id 42 group ${mcast_group[$ipversion]} dev $TEST_IFACE"
			else
				if [ $ipversion == "4" ]
				then
					rlRun "ip link add $gre_devname type vxlan id 42 remote $REMOTE_ADDR4 local $LOCAL_ADDR4 dev $TEST_IFACE"
				else
					rlRun "ip link add $gre_devname type vxlan id 42 remote $REMOTE_ADDR6 local $LOCAL_ADDR6 dev $TEST_IFACE"
				fi
			fi
			rlRun "ip link set $gre_devname up"
			rlRun "ip addr add $gre_s_ip4/24 dev $gre_devname"
			rlRun "ip -6 addr add $gre_s_ip6/64 dev $gre_devname"
			rlRun "ip route add $gre_c_ip4net dev $gre_devname"
			rlRun "ip -6 route add $gre_c_ip6net dev $gre_devname"

			rhts-sync-block -s CLIENT_GRE_CONFIG_${ipversion}_$remote $CLIENTS
			rlRun "tcpdump -i any -w grev4.pcap &"
			rlRun "sleep 5"
			rlRun "ping $gre_c_ip4 -c 5"
			rlRun "pkill tcpdump"
			rlRun "sleep 5"

			if ! uname -r | grep "^2"
			then
			if [ $ipversion == "4" ]
			then
				rlRun "tcpdump -r grev4.pcap -nnle | grep \"$CLI_ADDR4.*> $SER_ADDR4.*OTV.*instance 42\""
				rlRun "tcpdump -r grev4.pcap -nnle | grep \"$SER_ADDR4.*> $CLI_ADDR4.*OTV.*instance 42\""
				[ $? -ne 0 ] && rlRun -l "tcpdump -r grev4.pcap -nnle"
			else
				rlRun "tcpdump -r grev4.pcap -nnle | grep \"$CLI_ADDR6.*> $SER_ADDR6.*OTV.*instance 42\""
				rlRun "tcpdump -r grev4.pcap -nnle | grep \"$SER_ADDR6.*> $CLI_ADDR6.*OTV.*instance 42\""
				[ $? -ne 0 ] && rlRun -l "tcpdump -r grev4.pcap -nnle"
			fi
			fi

			rlRun "tcpdump -i any -w grev6.pcap &"
			rlRun "sleep 5"
			rlRun "ping6 $gre_c_ip6 -c 5"
			rlRun "pkill tcpdump"
			rlRun "sleep 5"
			if ! uname -r | grep "^2"
			then
			if [ $ipversion == "4" ]
			then
				rlRun "tcpdump -r grev6.pcap -nnle | grep \"$CLI_ADDR4.*> $SER_ADDR4.*OTV.*instance 42\""
				rlRun "tcpdump -r grev6.pcap -nnle | grep \"$SER_ADDR4.*> $CLI_ADDR4.*OTV.*instance 42\""
				[ $? -ne 0 ] && rlRun -l "tcpdump -r grev6.pcap -nnle"
			else
				rlRun "tcpdump -r grev6.pcap -nnle | grep \"$CLI_ADDR6.*> $SER_ADDR6.*OTV.*instance 42\""
				rlRun "tcpdump -r grev6.pcap -nnle | grep \"$SER_ADDR6.*> $CLI_ADDR6.*OTV.*instance 42\""
				[ $? -ne 0 ] && rlRun -l "tcpdump -r grev6.pcap -nnle"
			fi
			fi
			rhts-sync-block -s CLIENT_IPERF_TCPV4_${ipversion}_$remote $CLIENTS
			rlRun "iperf -c $gre_c_ip4"
			rhts-sync-set -s SERVER_IPERF_TCPV4_FINISH_${ipversion}_$remote
			rhts-sync-block -s CLIENT_IPERF_UDPV4_${ipversion}_$remote $CLIENTS
			rlRun "iperf -u -c $gre_c_ip4"
			rhts-sync-set -s SERVER_IPERF_UDPV4_FINISH_${ipversion}_$remote

			rhts-sync-block -s CLIENT_IPERF_TCPV6_${ipversion}_$remote $CLIENTS
			rlRun "iperf -V -c $gre_c_ip6"
			rhts-sync-set -s SERVER_IPERF_TCPV6_FINISH_${ipversion}_$remote
			rhts-sync-block -s CLIENT_IPERF_UDPV6_${ipversion}_$remote $CLIENTS
			rlRun "iperf -u -V -c $gre_c_ip6"

			rlRun "netperf -L $gre_s_ip4 -H $gre_c_ip4 -t UDP_STREAM"
			rlRun "netperf -L $gre_s_ip4 -H $gre_c_ip4 -t TCP_STREAM"
			rlRun "netperf -L $gre_s_ip4 -H $gre_c_ip4 -t SCTP_STREAM -- -m 16k"
			rlRun "netperf -L $gre_s_ip6 -H $gre_c_ip6 -t UDP_STREAM"
			rlRun "netperf -L $gre_s_ip6 -H $gre_c_ip6 -t TCP_STREAM"
			rlRun "netperf -L $gre_s_ip6 -H $gre_c_ip6 -t SCTP_STREAM -- -m 16k"
			rhts-sync-set -s SERVER_ALL_FINISH_${ipversion}_$remote
			rlRun "ip -d -s link sh $gre_devname"
			rlRun "ip link del $gre_devname"

		done
	done


elif i_am_client
then
	rlRun "get_test_iface_and_addr"

	for ipversion in $ipversion_type
	do
		for remote in $remote_type
		do
			if [ $remote == "mcast" ]
			then
				rlRun "ip link add $gre_devname type vxlan id 42 group ${mcast_group[$ipversion]} dev $TEST_IFACE"
			else
				if [ $ipversion == "4" ]
				then
					rlRun "ip link add $gre_devname type vxlan id 42 remote $REMOTE_ADDR4 local $LOCAL_ADDR4 dev $TEST_IFACE"
				else
					rlRun "ip link add $gre_devname type vxlan id 42 remote $REMOTE_ADDR6 local $LOCAL_ADDR6 dev $TEST_IFACE"
				fi
			fi
			rlRun "ip link set $gre_devname up"
			rlRun "ip addr add $gre_c_ip4/24 dev $gre_devname"
			rlRun "ip -6 addr add $gre_c_ip6/64 dev $gre_devname"
			rlRun "ip route add $gre_s_ip4net dev $gre_devname"
			rlRun "ip -6 route add $gre_s_ip6net dev $gre_devname"
			rlRun "pkill -9 netserver" "0-255"
			rlRun "netserver -d"

			rhts-sync-set -s CLIENT_GRE_CONFIG_${ipversion}_$remote
			rlRun "pkill -9 iperf" "0-255"
			rlRun "iperf -s -B $gre_c_ip4 -D &"
			rhts-sync-set -s CLIENT_IPERF_TCPV4_${ipversion}_$remote
			rhts-sync-block -s SERVER_IPERF_TCPV4_FINISH_${ipversion}_$remote $SERVERS
			rlRun "pkill -9 iperf" "0-255"
			rlRun "iperf -s -u -B $gre_c_ip4 -D &"
			rhts-sync-set -s CLIENT_IPERF_UDPV4_${ipversion}_$remote

			rhts-sync-block -s SERVER_IPERF_UDPV4_FINISH_${ipversion}_$remote $SERVERS
			rlRun "pkill -9 iperf" "0-255"
			rlRun "iperf -s -V -B $gre_c_ip6 -D &"
			rhts-sync-set -s CLIENT_IPERF_TCPV6_${ipversion}_$remote
			rhts-sync-block -s SERVER_IPERF_TCPV6_FINISH_${ipversion}_$remote $SERVERS
			rlRun "pkill -9 iperf" "0-255"
			rlRun "iperf -s -u -V -B $gre_c_ip6 -D &"
			rhts-sync-set -s CLIENT_IPERF_UDPV6_${ipversion}_$remote
			rhts-sync-block -s SERVER_ALL_FINISH_${ipversion}_$remote $SERVERS
			rlRun "ip -d -s link sh $gre_devname"

			rlRun "pkill -9 iperf"
			rlRun "pkill -9 netserver"
			rlRun "ip link del $gre_devname"

		done
	done

else
	# if use vlan topo, use cs ttopology
	if [ -z "${TOPO##*vlan*}" ]
	then
		rlRun "netns_cs_setup"
	else
		rlRun "netns_crs_setup"
	fi

	for ipversion in 4 6
	do
		for remote in unicast
		do
			if [ $remote == "mcast" ]
			then
				rlRun "$C_CMD ip link add $gre_devname type vxlan id 42 group ${mcast_group[$ipversion]} dev $C_IFACE"
				rlRun "$S_CMD ip link add $gre_devname type vxlan id 42 group ${mcast_group[$ipversion]} dev $S_IFACE"
			else
				if [ $ipversion == "4" ]
				then
					rlRun "$C_CMD ip link add $gre_devname type vxlan id 42 remote $SER_ADDR4 local $CLI_ADDR4 dev $C_IFACE"
					rlRun "$S_CMD ip link add $gre_devname type vxlan id 42 remote $CLI_ADDR4 local $SER_ADDR4 dev $S_IFACE"
				else
					rlRun "$C_CMD ip link add $gre_devname type vxlan id 42 remote $SER_ADDR6 local $CLI_ADDR6 dev $C_IFACE"
					rlRun "$S_CMD ip link add $gre_devname type vxlan id 42 remote $CLI_ADDR6 local $SER_ADDR6 dev $S_IFACE"
				fi
			fi
			rlRun "$C_CMD ip link set $gre_devname up"
			rlRun "$C_CMD ip addr add $gre_c_ip4/24 dev $gre_devname"
			rlRun "$C_CMD ip -6 addr add $gre_c_ip6/64 dev $gre_devname"
			rlRun "$C_CMD ip route add $gre_s_ip4net dev $gre_devname"
			rlRun "$C_CMD ip -6 route add $gre_s_ip6net dev $gre_devname"

			rlRun "$S_CMD ip link set $gre_devname up"
			rlRun "$S_CMD ip addr add $gre_s_ip4/24 dev $gre_devname"
			rlRun "$S_CMD ip -6 addr add $gre_s_ip6/64 dev $gre_devname"
			rlRun "$S_CMD ip route add $gre_c_ip4net dev $gre_devname"
			rlRun "$S_CMD ip -6 route add $gre_c_ip6net dev $gre_devname"

			rlRun "sleep 5"
			rlRun "$C_CMD ping $gre_s_ip4 -c 5"
			rlRun "$C_CMD ping6 $gre_s_ip6 -c 5"
			rlRun "$C_CMD ip -d -s link sh $gre_devname"
			rlRun "$S_CMD ip -d -s link sh $gre_devname"

			rlRun "$C_CMD ip link del $gre_devname"
			rlRun "$S_CMD ip link del $gre_devname"

		done
	done

	if [ -z "${TOPO##*vlan*}" ]
	then
		rlRun "netns_cs_cleanup"
	else
		rlRun "netns_crs_cleanup"
	fi

	# vxlan with group
	rlLog "vxlan with group"
	rlRun "netns_cs_setup"

	for ipversion in 4 6
	do
		for remote in mcast
		do
			if [ $remote == "mcast" ]
			then
				rlRun "$C_CMD ip link add $gre_devname type vxlan id 42 group ${mcast_group[$ipversion]} dev $C_IFACE"
				rlRun "$S_CMD ip link add $gre_devname type vxlan id 42 group ${mcast_group[$ipversion]} dev $S_IFACE"
			else
				if [ $ipversion == "4" ]
				then
					rlRun "$C_CMD ip link add $gre_devname type vxlan id 42 remote $SER_ADDR4 local $CLI_ADDR4 dev $C_IFACE"
					rlRun "$S_CMD ip link add $gre_devname type vxlan id 42 remote $CLI_ADDR4 local $SER_ADDR4 dev $S_IFACE"
				else
					rlRun "$C_CMD ip link add $gre_devname type vxlan id 42 remote $SER_ADDR6 local $CLI_ADDR6 dev $C_IFACE"
					rlRun "$S_CMD ip link add $gre_devname type vxlan id 42 remote $CLI_ADDR6 local $SER_ADDR6 dev $S_IFACE"
				fi
			fi
			rlRun "$C_CMD ip link set $gre_devname up"
			rlRun "$C_CMD ip addr add $gre_c_ip4/24 dev $gre_devname"
			rlRun "$C_CMD ip -6 addr add $gre_c_ip6/64 dev $gre_devname"
			rlRun "$C_CMD ip route add $gre_s_ip4net dev $gre_devname"
			rlRun "$C_CMD ip -6 route add $gre_s_ip6net dev $gre_devname"

			rlRun "$S_CMD ip link set $gre_devname up"
			rlRun "$S_CMD ip addr add $gre_s_ip4/24 dev $gre_devname"
			rlRun "$S_CMD ip -6 addr add $gre_s_ip6/64 dev $gre_devname"
			rlRun "$S_CMD ip route add $gre_c_ip4net dev $gre_devname"
			rlRun "$S_CMD ip -6 route add $gre_c_ip6net dev $gre_devname"

			rlRun "sleep 5"
			rlRun "$C_CMD ping $gre_s_ip4 -c 5"
			rlRun "$C_CMD ping6 $gre_s_ip6 -c 5"
			rlRun "$C_CMD ip -d -s link sh $gre_devname"
			rlRun "$S_CMD ip -d -s link sh $gre_devname"

			rlRun "$C_CMD ip link del $gre_devname"
			rlRun "$S_CMD ip link del $gre_devname"

		done
	done

	rlRun "netns_cs_cleanup"

fi
rlPhaseEnd

}


# Parameters
TEST_ITEMS_ALL="basic"
TEST_ITEMS=${TEST_ITEMS:-$TEST_ITEMS_ALL}

rlJournalStart
	rlPhaseStartSetup
	rlPhaseEnd


for test_item in $TEST_ITEMS
do
	$test_item
done

	rlPhaseStartTest
	rlPhaseEnd

	rlPhaseStartCleanup
	rlPhaseEnd

rlJournalEnd
