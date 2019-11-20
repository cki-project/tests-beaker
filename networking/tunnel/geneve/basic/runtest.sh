#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of networking/tunnel/geneve/basic
#   Description: What the test does
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


# include common and beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1
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
	local tunnel_type=geneve
	local gre_devname=geneve1
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

	for version in 4 6
	do
		if [ $version == "4" ]
		then
			rlRun "ip link add $gre_devname type $tunnel_type remote $REMOTE_ADDR4 vni 1234 ttl 64"
			rlRun "ip link add $gre_devname type $tunnel_type remote $REMOTE_ADDR4 vni 1234 ttl 64" "0-255"
		else
			rlRun "ip link add $gre_devname type $tunnel_type remote $REMOTE_ADDR6 vni 1234 ttl 64"
			rlRun "ip link add $gre_devname type $tunnel_type remote $REMOTE_ADDR6 vni 1234 ttl 64" "0-255"
		fi
		rlRun "ip link set $gre_devname up"
		rlRun "ip link set $gre_devname mtu 1400"
		rlRun "ip addr add $gre_s_ip4/24 dev $gre_devname"
		rlRun "ip -6 addr add $gre_s_ip6/64 dev $gre_devname"
		rlRun "ip route add $gre_c_ip4net dev $gre_devname"
		rlRun "ip -6 route add $gre_c_ip6net dev $gre_devname"

		rhts-sync-block -s CLIENT_GRE_CONFIG_$version $CLIENTS
		rlRun "tcpdump -i any -w grev4.pcap &"
		rlRun "sleep 5"
		rlRun "ping $gre_c_ip4 -c 5"
		rlRun "pkill tcpdump"
		rlRun "sleep 5"
		if [ $version == "4" ]
		then
			rlRun "tcpdump -r grev4.pcap -nnle | grep \"$CLI_ADDR4.*> $SER_ADDR4.*Geneve.*vni 0x4d2, proto TEB (0x6558).*$gre_c_ip4 > $gre_s_ip4\""
			rlRun "tcpdump -r grev4.pcap -nnle | grep \"$SER_ADDR4.*> $CLI_ADDR4.*Geneve.*vni 0x4d2, proto TEB (0x6558).*$gre_s_ip4 > $gre_c_ip4\""
			[ $? -ne 0 ] && rlRun -l "tcpdump -r grev4.pcap -nnle"
		else
			rlRun "tcpdump -r grev4.pcap -nnle | grep \"$CLI_ADDR6.*> $SER_ADDR6.*Geneve.*vni 0x4d2, proto TEB (0x6558).*$gre_c_ip4 > $gre_s_ip4\""
			rlRun "tcpdump -r grev4.pcap -nnle | grep \"$SER_ADDR6.*> $CLI_ADDR6.*Geneve.*vni 0x4d2, proto TEB (0x6558).*$gre_s_ip4 > $gre_c_ip4\""
			[ $? -ne 0 ] && rlRun -l "tcpdump -r grev4.pcap -nnle"
		fi

		rlRun "tcpdump -i any -w grev6.pcap &"
		rlRun "ping6 $gre_c_ip6 -c 5"
		rlRun "pkill tcpdump"
		rlRun "sleep 5"
		if [ $version == "4" ]
		then
			rlRun "tcpdump -r grev6.pcap -nnle | grep \"$CLI_ADDR4.*> $SER_ADDR4.*Geneve.*vni 0x4d2, proto TEB (0x6558).*$gre_c_ip6 > $gre_s_ip6\""
			rlRun "tcpdump -r grev6.pcap -nnle | grep \"$SER_ADDR4.*> $CLI_ADDR4.*Geneve.*vni 0x4d2, proto TEB (0x6558).*$gre_s_ip6 > $gre_c_ip6\""
			[ $? -ne 0 ] && rlRun -l "tcpdump -r grev6.pcap -nnle"
		else
			rlRun "tcpdump -r grev6.pcap -nnle | grep \"$CLI_ADDR6.*> $SER_ADDR6.*Geneve.*vni 0x4d2, proto TEB (0x6558).*$gre_c_ip6 > $gre_s_ip6\""
			rlRun "tcpdump -r grev6.pcap -nnle | grep \"$SER_ADDR6.*> $CLI_ADDR6.*Geneve.*vni 0x4d2, proto TEB (0x6558).*$gre_s_ip6 > $gre_c_ip6\""
			[ $? -ne 0 ] && rlRun -l "tcpdump -r grev6.pcap -nnle"
		fi

		rhts-sync-block -s CLIENT_IPERF_TCPV4_$version $CLIENTS
		rlRun "iperf -c $gre_c_ip4"
		rhts-sync-set -s SERVER_IPERF_TCPV4_FINISH_$version
		rhts-sync-block -s CLIENT_IPERF_UDPV4_$version $CLIENTS
		rlRun "iperf -u -c $gre_c_ip4"
		rhts-sync-set -s SERVER_IPERF_UDPV4_FINISH_$version

		rhts-sync-block -s CLIENT_IPERF_TCPV6_$version $CLIENTS
		rlRun "iperf -V -c $gre_c_ip6"
		rhts-sync-set -s SERVER_IPERF_TCPV6_FINISH_$version
		rhts-sync-block -s CLIENT_IPERF_UDPV6_$version $CLIENTS
		rlRun "iperf -u -V -c $gre_c_ip6"

		rlRun "netperf -L $gre_s_ip4 -H $gre_c_ip4 -t UDP_STREAM"
		rlRun "netperf -L $gre_s_ip6 -H $gre_c_ip6 -t UDP_STREAM"
		rhts-sync-set -s SERVER_ALL_FINISH_$version
		rlRun "ip -d -s link sh $gre_devname"
		rlRun "ip link del $gre_devname"
		rlRun "ip link del $gre_devname" "0-255"
	done

elif i_am_client
then
	rlRun "get_test_iface_and_addr"

	for version in 4 6
	do
		if [ $version == "4" ]
		then
			rlRun "ip link add $gre_devname type $tunnel_type remote $REMOTE_ADDR4 vni 1234 ttl 64"
			rlRun "ip link add $gre_devname type $tunnel_type remote $REMOTE_ADDR4 vni 1234 ttl 64" "0-255"
		else
			rlRun "ip link add $gre_devname type $tunnel_type remote $REMOTE_ADDR6 vni 1234 ttl 64"
			rlRun "ip link add $gre_devname type $tunnel_type remote $REMOTE_ADDR6 vni 1234 ttl 64" "0-255"
		fi
		rlRun "ip link set $gre_devname up"
		rlRun "ip link set $gre_devname mtu 1400"
		rlRun "ip addr add $gre_c_ip4/24 dev $gre_devname"
		rlRun "ip -6 addr add $gre_c_ip6/64 dev $gre_devname"
		rlRun "ip route add $gre_s_ip4net dev $gre_devname"
		rlRun "ip -6 route add $gre_s_ip6net dev $gre_devname"
		rlRun "pkill -9 netserver" "0-255"
		rlRun "netserver -d"

		rhts-sync-set -s CLIENT_GRE_CONFIG_$version
		rlRun "pkill -9 iperf" "0-255"
		rlRun "iperf -s -B $gre_c_ip4 -D &"
		rhts-sync-set -s CLIENT_IPERF_TCPV4_$version
		rhts-sync-block -s SERVER_IPERF_TCPV4_FINISH_$version $SERVERS
		rlRun "pkill -9 iperf" "0-255"
		rlRun "iperf -s -u -B $gre_c_ip4 -D &"
		rhts-sync-set -s CLIENT_IPERF_UDPV4_$version

		rhts-sync-block -s SERVER_IPERF_UDPV4_FINISH_$version $SERVERS
		rlRun "pkill -9 iperf" "0-255"
		rlRun "iperf -s -V -B $gre_c_ip6 -D &"
		rhts-sync-set -s CLIENT_IPERF_TCPV6_$version
		rhts-sync-block -s SERVER_IPERF_TCPV6_FINISH_$version $SERVERS
		rlRun "pkill -9 iperf" "0-255"
		rlRun "iperf -s -u -V -B $gre_c_ip6 -D &"
		rhts-sync-set -s CLIENT_IPERF_UDPV6_$version
		rhts-sync-block -s SERVER_ALL_FINISH_$version $SERVERS
		rlRun "ip -d -s link sh $gre_devname"

		rlRun "pkill -9 iperf"
		rlRun "pkill -9 netserver"
		rlRun "ip link del $gre_devname"
		rlRun "ip link del $gre_devname" "0-255"
	done
else
	# if use vlan topo, use cs ttopology
	if [ -z "${TOPO##*vlan*}" ]
	then
		rlRun "netns_cs_setup"
	else
		rlRun "netns_crs_setup"
	fi

	for version in 4 6
	do
		if [ $version == "4" ]
		then
			rlRun "$C_CMD ip link add $gre_devname type $tunnel_type remote $SER_ADDR4 vni 1234 ttl 64"
			rlRun "$C_CMD ip link add $gre_devname type $tunnel_type remote $SER_ADDR4 vni 1234 ttl 64" "0-255"
			rlRun "$S_CMD ip link add $gre_devname type $tunnel_type remote $CLI_ADDR4 vni 1234 ttl 64"
			rlRun "$S_CMD ip link add $gre_devname type $tunnel_type remote $CLI_ADDR4 vni 1234 ttl 64" "0-255"
		else
			rlRun "$C_CMD ip link add $gre_devname type $tunnel_type remote $SER_ADDR6 vni 1234 ttl 64"
			rlRun "$C_CMD ip link add $gre_devname type $tunnel_type remote $SER_ADDR6 vni 1234 ttl 64" "0-255"
			rlRun "$S_CMD ip link add $gre_devname type $tunnel_type remote $CLI_ADDR6 vni 1234 ttl 64"
			rlRun "$S_CMD ip link add $gre_devname type $tunnel_type remote $CLI_ADDR6 vni 1234 ttl 64" "0-255"
		fi

		rlRun "$C_CMD ip link set $gre_devname up"
		# workaround for https://bugzilla.redhat.com/show_bug.cgi?id=1470001
		rlRun "$C_CMD ip link set $gre_devname mtu 1400"
		rlRun "$C_CMD ip addr add $gre_c_ip4/24 dev $gre_devname"
		rlRun "$C_CMD ip -6 addr add $gre_c_ip6/64 dev $gre_devname"
		rlRun "$C_CMD ip route add $gre_s_ip4net dev $gre_devname"
		rlRun "$C_CMD ip -6 route add $gre_s_ip6net dev $gre_devname"
		rlRun "c_geneve1_mac=`$C_CMD ip link sh $gre_devname | grep link/ether | awk '{print $2}'`"

		rlRun "$S_CMD ip link set $gre_devname up"
		rlRun "$S_CMD ip link set $gre_devname mtu 1400"
		rlRun "$S_CMD ip addr add $gre_s_ip4/24 dev $gre_devname"
		rlRun "$S_CMD ip -6 addr add $gre_s_ip6/64 dev $gre_devname"
		rlRun "$S_CMD ip route add $gre_c_ip4net dev $gre_devname"
		rlRun "$S_CMD ip -6 route add $gre_c_ip6net dev $gre_devname"
		rlRun "s_geneve1_mac=`$S_CMD ip link sh $gre_devname | grep link/ether | awk '{print $2}'`"

		rlRun "sleep 5"
		rlRun "$C_CMD ping $gre_s_ip4 -c 5"
		rlRun "$C_CMD ping6 $gre_s_ip6 -c 5"
		rlRun "$C_CMD ip -d -s link sh $gre_devname"
		rlRun "$S_CMD ip -d -s link sh $gre_devname"

		rlRun "$C_CMD ip link del $gre_devname"
		rlRun "$C_CMD ip link del $gre_devname" "0-255"
		rlRun "$S_CMD ip link del $gre_devname"
		rlRun "$S_CMD ip link del $gre_devname" "0-255"
	done
	if [ -z "${TOPO##*vlan*}" ]
	then
		rlRun "netns_cs_cleanup"
	else
		rlRun "netns_crs_cleanup"
	fi
fi
rlPhaseEnd

}


# Parameters
TEST_ITEMS_ALL="basic"
TEST_ITEMS=${TEST_ITEMS:-$TEST_ITEMS_ALL}

rlJournalStart
	rlPhaseStartSetup
        rlRun "lsmod | grep sctp || modprobe sctp" "0-255"
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
