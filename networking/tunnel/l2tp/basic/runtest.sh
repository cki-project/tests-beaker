#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of networking/tunnel/l2tp/basic
#   Description: Test basic L2TP functionality for IPv4 and IPv6
#   Author: Jianlin Shi <jishi@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc.
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
. ../../../common/include.sh || exit 1
. ../../common/include.sh || exit 1

# Functions

basic()
{
	local gre_devname=l2tp1
	local gre_c_ip4="192.168.6.2"
	local gre_c_ip4net="192.168.6.0/24"
	local gre_c_ip6="6001:db8:ac10:fe01::2"
	local gre_c_ip6net="6001:db8:ac10:fe01::0/64"
	local gre_s_ip4="192.168.7.2"
	local gre_s_ip4net="192.168.7.0/24"
	local gre_s_ip6="7001:db8:ac10:fe01::2"
	local gre_s_ip6net="7001:db8:ac10:fe01::0/64"

rlPhaseStartTest "basic_$TOPO"
if i_am_server
then
	rlRun "get_test_iface_and_addr"

	rlRun "modprobe l2tp_eth" "0-255"
	rlRun "modprobe l2tp_ip" "0-255"
	rlRun "modprobe l2tp_ip6" "0-255"
	for encap_type in ip udp
	do
		for ipversion in 4 6
		do
			if [ $ipversion == "4" ]
			then
				[ $encap_type == "udp" ] && rlRun "ip l2tp add tunnel tunnel_id 3000 peer_tunnel_id 4000 encap $encap_type \
					local $LOCAL_ADDR4 remote $REMOTE_ADDR4 udp_sport 5000 udp_dport 6000" ||
					rlRun "$C_CMD ip l2tp add tunnel tunnel_id 3000 peer_tunnel_id 4000 encap $encap_type  local $LOCAL_ADDR4 remote $REMOTE_ADDR4"
			else
				[ $encap_type == "udp" ] && rlRun "ip l2tp add tunnel tunnel_id 3000 peer_tunnel_id 4000 encap $encap_type \
					local $LOCAL_ADDR6 remote $REMOTE_ADDR6 udp_sport 5000 udp_dport 6000" ||
					rlRun "$C_CMD ip l2tp add tunnel tunnel_id 3000 peer_tunnel_id 4000 encap $encap_type  local $LOCAL_ADDR6 remote $REMOTE_ADDR6"
			fi
			rlRun "ip l2tp add session name $gre_devname tunnel_id 3000 session_id 1000 peer_session_id 2000"
			rlRun "ip link set $gre_devname up"
			rlRun "ip addr add $gre_s_ip4/24 dev $gre_devname"
			rlRun "ip -6 addr add $gre_s_ip6/64 dev $gre_devname"
			rlRun "ip route add $gre_c_ip4net dev $gre_devname"
			rlRun "ip -6 route add $gre_c_ip6net dev $gre_devname"
			rhts-sync-block -s CLIENT_GRE_CONFIG_${encap_type}_$ipversion $CLIENTS
			rlRun "ping $gre_c_ip4 -c 5"
			rlRun "ping6 $gre_c_ip6 -c 5"

			rhts-sync-block -s CLIENT_IPERF_TCPV4_${encap_type}_$ipversion $CLIENTS
			rlRun "iperf -c $gre_c_ip4"
			rhts-sync-set -s SERVER_IPERF_TCPV4_FINISH_${encap_type}_$ipversion
			rhts-sync-block -s CLIENT_IPERF_UDPV4_${encap_type}_$ipversion $CLIENTS
			rlRun "iperf -u -c $gre_c_ip4"
			rhts-sync-set -s SERVER_IPERF_UDPV4_FINISH_${encap_type}_$ipversion

			rhts-sync-block -s CLIENT_IPERF_TCPV6_${encap_type}_$ipversion $CLIENTS
			rlRun "iperf -V -c $gre_c_ip6"
			rhts-sync-set -s SERVER_IPERF_TCPV6_FINISH_${encap_type}_$ipversion
			rhts-sync-block -s CLIENT_IPERF_UDPV6_${encap_type}_$ipversion $CLIENTS
			rlRun "iperf -u -V -c $gre_c_ip6"

			rlRun "netperf -L $gre_s_ip4 -H $gre_c_ip4 -t UDP_STREAM"
			rlRun "netperf -L $gre_s_ip4 -H $gre_c_ip4 -t TCP_STREAM"
			rlRun "netperf -L $gre_s_ip4 -H $gre_c_ip4 -t SCTP_STREAM"
			rlRun "netperf -L $gre_s_ip6 -H $gre_c_ip6 -t UDP_STREAM"
			rlRun "netperf -L $gre_s_ip6 -H $gre_c_ip6 -t TCP_STREAM"
			rlRun "netperf -L $gre_s_ip6 -H $gre_c_ip6 -t SCTP_STREAM"
			rhts-sync-set -s SERVER_ALL_FINISH_${encap_type}_$ipversion
			rlRun "ip -d -s link sh $gre_devname"
			rlRun "ip l2tp del tunnel tunnel_id 3000 peer_tunnel_id 4000"
			# can't add tunnel with same tunnel id right after tunnel is deleted
			rlRun "sleep 5"
		done
	done

	rlRun "modprobe -r l2tp_eth l2tp_ip6 l2tp_ip" "0-255"

elif i_am_client
then
	rlRun "get_test_iface_and_addr"

	rlRun "modprobe l2tp_eth" "0-255"
	rlRun "modprobe l2tp_ip" "0-255"
	rlRun "modprobe l2tp_ip6" "0-255"
	for encap_type in ip udp
	do
		for ipversion in 4 6
		do
			if [ $ipversion == "4" ]
			then
				[ $encap_type == "udp" ] && rlRun "ip l2tp add tunnel tunnel_id 4000 peer_tunnel_id 3000 encap $encap_type \
					local $LOCAL_ADDR4 remote $REMOTE_ADDR4 udp_sport 6000 udp_dport 5000" ||
					rlRun "$C_CMD ip l2tp add tunnel tunnel_id 4000 peer_tunnel_id 3000 encap $encap_type  local $LOCAL_ADDR4 remote $REMOTE_ADDR4"
			else
				[ $encap_type == "udp" ] && rlRun "ip l2tp add tunnel tunnel_id 4000 peer_tunnel_id 3000 encap $encap_type \
					local $LOCAL_ADDR6 remote $REMOTE_ADDR6 udp_sport 6000 udp_dport 5000 " ||
					rlRun "$C_CMD ip l2tp add tunnel tunnel_id 4000 peer_tunnel_id 3000 encap $encap_type  local $LOCAL_ADDR6 remote $REMOTE_ADDR6"
			fi
			rlRun "ip l2tp add session name $gre_devname tunnel_id 4000 session_id 2000 peer_session_id 1000"
			rlRun "ip link set $gre_devname up"
			rlRun "ip addr add $gre_c_ip4/24 dev $gre_devname"
			rlRun "ip -6 addr add $gre_c_ip6/64 dev $gre_devname"
			rlRun "ip route add $gre_s_ip4net dev $gre_devname"
			rlRun "ip -6 route add $gre_s_ip6net dev $gre_devname"
			rlRun "pkill -9 netserver" "0-255"
			rlRun "netserver -d"

			rhts-sync-set -s CLIENT_GRE_CONFIG_${encap_type}_$ipversion
			rlRun "pkill -9 iperf" "0-255"
			rlRun "iperf -s -B $gre_c_ip4 -D &"
			rhts-sync-set -s CLIENT_IPERF_TCPV4_${encap_type}_$ipversion
			rhts-sync-block -s SERVER_IPERF_TCPV4_FINISH_${encap_type}_$ipversion $SERVERS
			rlRun "pkill -9 iperf" "0-255"
			rlRun "iperf -s -u -B $gre_c_ip4 -D &"
			rhts-sync-set -s CLIENT_IPERF_UDPV4_${encap_type}_$ipversion

			rhts-sync-block -s SERVER_IPERF_UDPV4_FINISH_${encap_type}_$ipversion $SERVERS
			rlRun "pkill -9 iperf" "0-255"
			rlRun "iperf -s -V -B $gre_c_ip6 -D &"
			rhts-sync-set -s CLIENT_IPERF_TCPV6_${encap_type}_$ipversion
			rhts-sync-block -s SERVER_IPERF_TCPV6_FINISH_${encap_type}_$ipversion $SERVERS
			rlRun "pkill -9 iperf" "0-255"
			rlRun "iperf -s -u -V -B $gre_c_ip6 -D &"
			rhts-sync-set -s CLIENT_IPERF_UDPV6_${encap_type}_$ipversion
			rhts-sync-block -s SERVER_ALL_FINISH_${encap_type}_$ipversion $SERVERS
			rlRun "ip -d -s link sh $gre_devname"

			rlRun "pkill -9 iperf"
			rlRun "pkill -9 netserver"
			rlRun "ip l2tp del tunnel tunnel_id 4000 peer_tunnel_id 3000"
			# can't add tunnel with same tunnel id right after tunnel is deleted
			rlRun "sleep 5"
		done
	done

	rlRun "modprobe -r l2tp_eth l2tp_ip6 l2tp_ip" "0-255"
else
	# if use vlan topo, use cs ttopology
	if [ -z "${TOPO##*vlan*}" ]
	then
		rlRun "netns_cs_setup"
	else
		rlRun "netns_crs_setup"
	fi
	rlRun "modprobe l2tp_eth" "0-255"
	rlRun "modprobe l2tp_ip" "0-255"
	rlRun "modprobe l2tp_ip6" "0-255"

	for encap_type in ip udp
	do
		for ipversion in 4 6
		do
			if [ $ipversion == "4" ]
			then
				[ $encap_type == "udp" ] && rlRun "$C_CMD ip l2tp add tunnel tunnel_id 3000 peer_tunnel_id 4000 encap $encap_type \
					local $CLI_ADDR4 remote $SER_ADDR4 udp_sport 5000 udp_dport 6000" ||
					rlRun "$C_CMD ip l2tp add tunnel tunnel_id 3000 peer_tunnel_id 4000 encap $encap_type  local $CLI_ADDR4 remote $SER_ADDR4"
			else
				[ $encap_type == "udp" ] && rlRun "$C_CMD ip l2tp add tunnel tunnel_id 3000 peer_tunnel_id 4000 encap $encap_type \
					local $CLI_ADDR6 remote $SER_ADDR6 udp_sport 5000 udp_dport 6000" ||
					rlRun "$C_CMD ip l2tp add tunnel tunnel_id 3000 peer_tunnel_id 4000 encap $encap_type  local $CLI_ADDR6 remote $SER_ADDR6"
			fi
			rlRun "$C_CMD ip l2tp add session name $gre_devname tunnel_id 3000 session_id 1000 peer_session_id 2000"

			rlRun "$C_CMD ip link set $gre_devname up"
			rlRun "$C_CMD ip addr add $gre_c_ip4/24 dev $gre_devname"
			rlRun "$C_CMD ip -6 addr add $gre_c_ip6/64 dev $gre_devname"
			rlRun "$C_CMD ip route add $gre_s_ip4net dev $gre_devname"
			rlRun "$C_CMD ip -6 route add $gre_s_ip6net dev $gre_devname"

			if [ $ipversion == "4" ]
			then
				[ $encap_type == "udp" ] && rlRun "$S_CMD ip l2tp add tunnel tunnel_id 4000 peer_tunnel_id 3000 encap $encap_type \
					local $SER_ADDR4 remote $CLI_ADDR4 udp_sport 6000 udp_dport 5000" ||
					rlRun "$S_CMD ip l2tp add tunnel tunnel_id 4000 peer_tunnel_id 3000 encap $encap_type local $SER_ADDR4 remote $CLI_ADDR4"
			else
				[ $encap_type == "udp" ] && rlRun "$S_CMD ip l2tp add tunnel tunnel_id 4000 peer_tunnel_id 3000 encap $encap_type \
					local $SER_ADDR6 remote $CLI_ADDR6 udp_sport 6000 udp_dport 5000" ||
					rlRun "$S_CMD ip l2tp add tunnel tunnel_id 4000 peer_tunnel_id 3000 encap $encap_type local $SER_ADDR6 remote $CLI_ADDR6"
			fi
			rlRun "$S_CMD ip l2tp add session name $gre_devname tunnel_id 4000 session_id 2000 peer_session_id 1000"

			rlRun "$S_CMD ip link set $gre_devname up"
			rlRun "$S_CMD ip addr add $gre_s_ip4/24 dev $gre_devname"
			rlRun "$S_CMD ip -6 addr add $gre_s_ip6/64 dev $gre_devname"
			rlRun "$S_CMD ip route add $gre_c_ip4net dev $gre_devname"
			rlRun "$S_CMD ip -6 route add $gre_c_ip6net dev $gre_devname"

			rlRun "$C_CMD ping $gre_s_ip4 -c 5"
			rlRun "$C_CMD ping6 $gre_s_ip6 -c 5"

			rlRun "$S_CMD iperf -s -B $gre_s_ip4 -D &"
			rlRun "sleep 5"
			rlRun "$C_CMD iperf -c $gre_s_ip4"
			rlRun "pkill -9 iperf" "0-255"
			rlRun "$S_CMD iperf -s -B $gre_s_ip4 -u -D &"
			rlRun "sleep 5"
			rlRun "$C_CMD iperf -u -c $gre_s_ip4"
			rlRun "pkill -9 iperf" "0-255"

			rlRun "$S_CMD iperf -s -V -B $gre_s_ip6 -D &"
			rlRun "sleep 5"
			rlRun "$C_CMD iperf -V -c $gre_s_ip6"
			rlRun "pkill -9 iperf" "0-255"
			rlRun "$S_CMD iperf -s -V -B $gre_s_ip6 -u -D &"
			rlRun "sleep 5"
			rlRun "$C_CMD iperf -u -V -c $gre_s_ip6"
			rlRun "pkill -9 iperf" "0-255"

			rlRun "$S_CMD pkill -9 netserver" "0-255"
			rlRun "$S_CMD netserver -d"
			rlRun "$C_CMD netperf -L $gre_c_ip4 -H $gre_s_ip4 -t UDP_STREAM -- -R 1"
			if $C_CMD netperf -L $gre_c_ip4 -H $gre_s_ip4 -t SCTP_STREAM -l 1
			then
				rlRun "$C_CMD netperf -L $gre_c_ip4 -H $gre_s_ip4 -t SCTP_STREAM -- -m 16k"
			fi
			rlRun "$C_CMD netperf -L $gre_c_ip4 -H $gre_s_ip4 -t TCP_STREAM"
			rlRun "$C_CMD netperf -L $gre_c_ip6 -H $gre_s_ip6 -t UDP_STREAM -- -R 1"
			rlRun "$C_CMD netperf -L $gre_c_ip6 -H $gre_s_ip6 -t TCP_STREAM"
			if $C_CMD netperf -L $gre_c_ip6 -H $gre_s_ip6 -t SCTP_STREAM -l 1
			then
				rlRun "$C_CMD netperf -L $gre_c_ip6 -H $gre_s_ip6 -t SCTP_STREAM -- -m 16k"
			fi
			rlRun "$C_CMD ip -d -s link sh $gre_devname"
			rlRun "$S_CMD ip -d -s link sh $gre_devname"

			rlRun "pkill -9 netserver"
			rlRun "$C_CMD ip l2tp del tunnel tunnel_id 3000 peer_tunnel_id 4000"
			rlRun "$S_CMD ip l2tp del tunnel tunnel_id 4000 peer_tunnel_id 3000"
			rlRun "sleep 1"
		done

	done

	if [ -z "${TOPO##*vlan*}" ]
	then
		rlRun "netns_cs_cleanup"
	else
		rlRun "netns_crs_cleanup"
	fi
	rlRun "modprobe -r l2tp_eth l2tp_ip6 l2tp_ip" "0-255"

fi
rlPhaseEnd

}


# Parameters
TEST_ITEMS_ALL="basic"
TEST_ITEMS=${TEST_ITEMS:-$TEST_ITEMS_ALL}

rlJournalStart
	rlPhaseStartSetup
	rlRun "netperf_install"
	which iperf || rlRun "iperf_install"
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
