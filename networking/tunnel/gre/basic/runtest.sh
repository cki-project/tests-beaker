#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
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

# Include Common and Beaker environments
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1
. ../../../common/include.sh || exit 1
. ../../common/include.sh || exit 1

# Functions

basic()
{
	local gre_devname=gre1
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

	rlRun "ip tunnel add $gre_devname mode gre local $LOCAL_ADDR4 remote $REMOTE_ADDR4 ttl 64"
	rlRun "ip link set $gre_devname up"
	rlRun "ip addr add $gre_s_ip4/24 dev $gre_devname"
	rlRun "ip -6 addr add $gre_s_ip6/64 dev $gre_devname"
	rlRun "ip route add $gre_c_ip4net dev $gre_devname"
	rlRun "ip -6 route add $gre_c_ip6net dev $gre_devname"

	rlRun "killall -9 socat" "0-255"
	rlRun "socat tcp4-listen:51110 - > server4.log &"
	rhts-sync-set -s SERVER_SOCAT_TCP4_READY
	rhts-sync-block -s CLIENT_NC_TCP4_FINISH $CLIENTS
	rlAssertGrep "h" server4.log

	rlRun "killall -9 socat" "0-255"
	rlRun "socat tcp6-listen:51111 - > server6.log &"
	rhts-sync-set -s SERVER_SOCAT_TCP6_READY
	rhts-sync-block -s CLIENT_NC_TCP6_FINISH $CLIENTS
	rlAssertGrep "h" server6.log

	rhts-sync-block -s CLIENT_GRE_CONFIG $CLIENTS
	rlRun "tcpdump -i any -w grev4.pcap &"
	rlRun "sleep 5"
	rlRun "ping $gre_c_ip4 -c 5"
	rlRun "pkill tcpdump"
	rlRun "sleep 5"
	rlRun "tcpdump -r grev4.pcap -nnle | grep \"$CLI_ADDR4 > $SER_ADDR4: GREv0, proto IPv4 (0x0800).*: $gre_c_ip4 > $gre_s_ip4\""
	rlRun "tcpdump -r grev4.pcap -nnle | grep \"$SER_ADDR4 > $CLI_ADDR4: GREv0, proto IPv4 (0x0800).*: $gre_s_ip4 > $gre_c_ip4\""
	[ $? -ne 0 ] && rlRun -l "tcpdump -r grev4.pcap -nnle"

	rlRun "tcpdump -i any -w grev6.pcap &"
	rlRun "ping6 $gre_c_ip6 -c 5"
	rlRun "pkill tcpdump"
	rlRun "sleep 5"
	rlRun "tcpdump -r grev6.pcap -nnle | grep \"$CLI_ADDR4 > $SER_ADDR4: GREv0, proto IPv6 (0x86dd).*: $gre_c_ip6 > $gre_s_ip6\""
	rlRun "tcpdump -r grev6.pcap -nnle | grep \"$SER_ADDR4 > $CLI_ADDR4: GREv0, proto IPv6 (0x86dd).*: $gre_s_ip6 > $gre_c_ip6\""
	[ $? -ne 0 ] && rlRun -l "tcpdump -r grev6.pcap -nnle"

	rhts-sync-block -s CLIENT_IPERF_TCPV4 $CLIENTS
	rlRun "iperf -c $gre_c_ip4"
	rhts-sync-set -s SERVER_IPERF_TCPV4_FINISH
	rhts-sync-block -s CLIENT_IPERF_UDPV4 $CLIENTS
	rlRun "iperf -u -c $gre_c_ip4"
	rhts-sync-set -s SERVER_IPERF_UDPV4_FINISH

	rhts-sync-block -s CLIENT_IPERF_TCPV6 $CLIENTS
	rlRun "iperf -V -c $gre_c_ip6"
	rhts-sync-set -s SERVER_IPERF_TCPV6_FINISH
	rhts-sync-block -s CLIENT_IPERF_UDPV6 $CLIENTS
	rlRun "iperf -u -V -c $gre_c_ip6"

	rlRun "netperf -L $gre_s_ip4 -H $gre_c_ip4 -t UDP_STREAM"
	rlRun "netperf -L $gre_s_ip6 -H $gre_c_ip6 -t UDP_STREAM"
	rhts-sync-set -s SERVER_ALL_FINISH
	rlRun "ip -d -s tunnel show $gre_devname"
	rlRun "ip -d -s link sh $gre_devname"
	rlRun "ip link del $gre_devname"
	rlRun "ip tunnel del $gre_devname" "0-255"
	rlRun "modprobe -r vport_gre" "0-255"
	rlRun "modprobe -r ip_gre" "0-255"
	rlRun "jobs -p | xargs kill -9" "0-255"

elif i_am_client
then
	rlRun "get_test_iface_and_addr"

	rlRun "ip tunnel add $gre_devname mode gre local $LOCAL_ADDR4 remote $REMOTE_ADDR4 ttl 64"
	rlRun "ip link set $gre_devname up"
	rlRun "ip addr add $gre_c_ip4/24 dev $gre_devname"
	rlRun "ip -6 addr add $gre_c_ip6/64 dev $gre_devname"
	rlRun "ip route add $gre_s_ip4net dev $gre_devname"
	rlRun "ip -6 route add $gre_s_ip6net dev $gre_devname"
	rlRun "pkill -9 netserver" "0-255"
	rlRun "netserver -d"

	rhts-sync-block -s SERVER_SOCAT_TCP4_READY $SERVERS
	rlRun "nc -4 $gre_s_ip4 51110 <<< h"
	rhts-sync-set -s CLIENT_NC_TCP4_FINISH
	rhts-sync-block -s SERVER_SOCAT_TCP6_READY $SERVERS
	rlRun "nc -6 $gre_s_ip6 51111 <<< h"
	rhts-sync-set -s CLIENT_NC_TCP6_FINISH

	rhts-sync-set -s CLIENT_GRE_CONFIG
	rlRun "pkill -9 iperf" "0-255"
	rlRun "iperf -s -B $gre_c_ip4 -D &"
	rhts-sync-set -s CLIENT_IPERF_TCPV4
	rhts-sync-block -s SERVER_IPERF_TCPV4_FINISH $SERVERS
	rlRun "pkill -9 iperf" "0-255"
	rlRun "iperf -s -u -B $gre_c_ip4 -D &"
	rhts-sync-set -s CLIENT_IPERF_UDPV4

	rhts-sync-block -s SERVER_IPERF_UDPV4_FINISH $SERVERS
	rlRun "pkill -9 iperf" "0-255"
	rlRun "iperf -s -V -B $gre_c_ip6 -D &"
	rhts-sync-set -s CLIENT_IPERF_TCPV6
	rhts-sync-block -s SERVER_IPERF_TCPV6_FINISH $SERVERS
	rlRun "pkill -9 iperf" "0-255"
	rlRun "iperf -s -u -V -B $gre_c_ip6 -D &"
	rhts-sync-set -s CLIENT_IPERF_UDPV6
	rhts-sync-block -s SERVER_ALL_FINISH $SERVERS
	rlRun "ip -d -s link sh $gre_devname"
	rlRun "ip -d -s tunnel show $gre_devname"

	rlRun "pkill -9 iperf"
	rlRun "pkill -9 netserver"
	rlRun "ip tunnel del $gre_devname"
	rlRun "ip link del $gre_devname" "0-255"
	rlRun "modprobe -r vport_gre" "0-255"
	rlRun "modprobe -r ip_gre" "0-255"
else

	# if use vlan topo, use cs ttopology
	if [ -z "${TOPO##*vlan*}" ]
	then
		rlRun "netns_cs_setup"
	else
		rlRun "netns_crs_setup"
	fi
	rlRun "$C_CMD ip tunnel add $gre_devname mode gre local $CLI_ADDR4 remote $SER_ADDR4 ttl 64"
	rlRun "$C_CMD ip tunnel add $gre_devname mode gre local $CLI_ADDR4 remote $SER_ADDR4 ttl 64" "0-255"
	rlRun "$C_CMD ip link change $gre_devname type gre local $CLI_ADDR4 remote $SER_ADDR4 ttl 128"
	rlRun "$C_CMD ip link change $gre_devname type gre local $CLI_ADDR4 remote $SER_ADDR4 ttl 64"
	rlRun "$C_CMD ip link set $gre_devname up"
	rlRun "$C_CMD ip addr add $gre_c_ip4/24 dev $gre_devname"
	rlRun "$C_CMD ip -6 addr add $gre_c_ip6/64 dev $gre_devname"
	rlRun "$C_CMD ip route add $gre_s_ip4net dev $gre_devname"
	rlRun "$C_CMD ip -6 route add $gre_s_ip6net dev $gre_devname"

	rlRun "$S_CMD ip tunnel add $gre_devname mode gre local $SER_ADDR4 remote $CLI_ADDR4 ttl 64"
	rlRun "$S_CMD ip link set $gre_devname up"
	rlRun "$S_CMD ip addr add $gre_s_ip4/24 dev $gre_devname"
	rlRun "$S_CMD ip -6 addr add $gre_s_ip6/64 dev $gre_devname"
	rlRun "$S_CMD ip route add $gre_c_ip4net dev $gre_devname"
	rlRun "$S_CMD ip -6 route add $gre_c_ip6net dev $gre_devname"

	rlRun "$C_CMD tcpdump -i any -w grev4.pcap &"
	rlRun "sleep 5"
	rlRun "$C_CMD ping $gre_s_ip4 -c 5"
	rlRun "pkill tcpdump"
	rlRun "sleep 5"
	rlRun "tcpdump -r grev4.pcap -nnle | grep \"$CLI_ADDR4 > $SER_ADDR4: GREv0, proto IPv4 (0x0800).*: $gre_c_ip4 > $gre_s_ip4\""
	rlRun "tcpdump -r grev4.pcap -nnle | grep \"$SER_ADDR4 > $CLI_ADDR4: GREv0, proto IPv4 (0x0800).*: $gre_s_ip4 > $gre_c_ip4\""
	[ $? -ne 0 ] && rlRun -l "tcpdump -r grev4.pcap -nnle"
	rlRun "$C_CMD tcpdump -i any -w grev6.pcap &"
	rlRun "$C_CMD ping6 $gre_s_ip6 -c 5"
	rlRun "pkill tcpdump"
	rlRun "sleep 5"
	rlRun "tcpdump -r grev6.pcap -nnle | grep \"$CLI_ADDR4 > $SER_ADDR4: GREv0, proto IPv6 (0x86dd).*: $gre_c_ip6 > $gre_s_ip6\""
	rlRun "tcpdump -r grev6.pcap -nnle | grep \"$SER_ADDR4 > $CLI_ADDR4: GREv0, proto IPv6 (0x86dd).*: $gre_s_ip6 > $gre_c_ip6\""
	[ $? -ne 0 ] && rlRun -l "tcpdump -r grev6.pcap -nnle"

	rlRun "killall -9 socat" "0-255"
	rlRun "$S_CMD fuser -k -n tcp 51110 " "0-255"
	rlRun "$S_CMD fuser  -6 -k -n tcp 51110 " "0-255"
	rlRun "$S_CMD socat tcp4-listen:51110 - > server4.log &"
	rlRun "sleep 5"
	rlRun "$C_CMD nc -4 $gre_s_ip4 51110 <<< h"
	[ $? -ne 0 ] && rlRun -l "$S_CMD netstat -anp | grep 51110"
	rlRun "sleep 5"
	rlAssertGrep "h" server4.log

	rlRun "killall -9 socat" "0-255"
	rlRun "$S_CMD fuser -k -n tcp 51111" "0-255"
	rlRun "$S_CMD fuser  -6 -k -n tcp 51111" "0-255"
	rlRun "$S_CMD socat tcp6-listen:51111 - > server6.log &"
	rlRun "sleep 5"
	rlRun "$C_CMD nc -6 $gre_s_ip6 51111 <<< h"
	[ $? -ne 0 ] && rlRun -l "$S_CMD netstat -anp | grep 51111"
	rlRun "sleep 5"
	rlAssertGrep "h" server6.log

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
	rlRun "$C_CMD netperf -L $gre_c_ip6 -H $gre_s_ip6 -t UDP_STREAM -- -R 1"
	rlRun "$C_CMD ip -d -s link sh $gre_devname"
	rlRun "$C_CMD ip -d -s tunnel show $gre_devname"
	rlRun "$S_CMD ip -d -s tunnel show $gre_devname"
	rlRun "$S_CMD ip -d -s link sh $gre_devname"

	rlRun "pkill -9 netserver"
	rlRun "$C_CMD ip tunnel del $gre_devname"
	rlRun "$C_CMD ip link del $gre_devname" "0-255"
	rlRun "$S_CMD ip link del $gre_devname"
	rlRun "$S_CMD ip tunnel del $gre_devname" "0-255"

	if [ -z "${TOPO##*vlan*}" ]
	then
		rlRun "netns_cs_cleanup"
	else
		rlRun "netns_crs_cleanup"
	fi


	# set remote as multicast
	rlLog "remote as multicast"
	rlRun "netns_cs_setup"

	rlRun "$C_CMD ip link add $gre_devname type gre local $CLI_ADDR4 remote 239.1.1.1 ttl 64"
	rlRun "$C_CMD ip link add $gre_devname type gre local $CLI_ADDR4 remote 239.1.1.1 ttl 64" "0-255"
	rlRun "$C_CMD ip link change $gre_devname type gre local $CLI_ADDR4 remote 239.1.1.1 ttl 128"
	rlRun "$C_CMD ip link change $gre_devname type gre local $CLI_ADDR4 remote 239.1.1.1 ttl 64"

	rlRun "$C_CMD ip link set $gre_devname up"
	rlRun "$C_CMD ip addr add $gre_c_ip4/24 dev $gre_devname"
	rlRun "$C_CMD ip -6 addr add $gre_c_ip6/64 dev $gre_devname"
	rlRun "$C_CMD ip route add $gre_s_ip4net dev $gre_devname"
	rlRun "$C_CMD ip -6 route add $gre_s_ip6net dev $gre_devname"

	rlRun "$S_CMD ip link add $gre_devname type gre local $SER_ADDR4 remote 239.1.1.1 ttl 64"
	rlRun "$S_CMD ip link set $gre_devname up"
	rlRun "$S_CMD ip addr add $gre_s_ip4/24 dev $gre_devname"
	rlRun "$S_CMD ip -6 addr add $gre_s_ip6/64 dev $gre_devname"
	rlRun "$S_CMD ip route add $gre_c_ip4net dev $gre_devname"
	rlRun "$S_CMD ip -6 route add $gre_c_ip6net dev $gre_devname"

	rlRun "$C_CMD tcpdump -i any -w grev4.pcap &"
	rlRun "sleep 5"
	rlRun "$C_CMD ping $gre_s_ip4 -c 5"
	rlRun "pkill tcpdump"
	rlRun "sleep 5"
	rlRun "tcpdump -r grev4.pcap -nnle | grep \"$CLI_ADDR4 > 239.1.1.1: GREv0,.*proto IPv4 (0x0800).*: $gre_c_ip4 > $gre_s_ip4\""
	rlRun "tcpdump -r grev4.pcap -nnle | grep \"$SER_ADDR4 > 239.1.1.1: GREv0,.*proto IPv4 (0x0800).*: $gre_s_ip4 > $gre_c_ip4\""
	[ $? -ne 0 ] && rlRun -l "tcpdump -r grev4.pcap -nnle"
	rlRun "$C_CMD tcpdump -i any -w grev6.pcap &"
	rlRun "$C_CMD ping6 $gre_s_ip6 -c 5"
	rlRun "pkill tcpdump"
	rlRun "sleep 5"
	rlRun "tcpdump -r grev6.pcap -nnle | grep \"$CLI_ADDR4 > 239.1.1.1: GREv0,.*proto IPv6 (0x86dd).*: $gre_c_ip6 > $gre_s_ip6\""
	rlRun "tcpdump -r grev6.pcap -nnle | grep \"$SER_ADDR4 > 239.1.1.1: GREv0,.*proto IPv6 (0x86dd).*: $gre_s_ip6 > $gre_c_ip6\""
	[ $? -ne 0 ] && rlRun -l "tcpdump -r grev6.pcap -nnle"

	rlRun "killall -9 socat" "0-255"
	rlRun "$S_CMD fuser -k -n tcp 51112" "0-255"
	rlRun "$S_CMD fuser  -6 -k -n tcp 51112" "0-255"
	rlRun "$S_CMD socat tcp4-listen:51112 - > server4.log &"
	rlRun "sleep 1"
	rlRun "$C_CMD nc -4 $gre_s_ip4 51112 <<< h"
	[ $? -ne 0 ] && rlRun -l "$S_CMD netstat -anp | grep 51112"
	rlRun "sleep 1"
	rlAssertGrep "h" server4.log

	rlRun "killall -9 socat" "0-255"
	rlRun "$S_CMD fuser -k -n tcp 51113" "0-255"
	rlRun "$S_CMD fuser  -6 -k -n tcp 51113" "0-255"
	rlRun "$S_CMD socat tcp6-listen:51113 - > server6.log &"
	rlRun "sleep 1"
	rlRun "$C_CMD nc -6 $gre_s_ip6 51113 <<< h"
	[ $? -ne 0 ] && rlRun -l "$S_CMD netstat -anp | grep 51113"
	rlRun "sleep 1"
	rlAssertGrep "h" server6.log

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
	rlRun "$C_CMD netperf -L $gre_c_ip6 -H $gre_s_ip6 -t UDP_STREAM -- -R 1"
	rlRun "$C_CMD ip -d -s tunnel show $gre_devname"
	rlRun "$C_CMD ip -d -s link sh $gre_devname"
	rlRun "$S_CMD ip -d -s link sh $gre_devname"
	rlRun "$S_CMD ip -d -s tunnel show $gre_devname"

	rlRun "pkill -9 netserver"
	rlRun "$C_CMD ip link del $gre_devname"
	rlRun "$C_CMD ip tunnel del $gre_devname" "0-255"
	rlRun "$S_CMD ip tunnel del $gre_devname"
	rlRun "$S_CMD ip link del $gre_devname" "0-255"

	# add gre without remote
	rlLog "gre without remote"
	rlRun "$C_CMD ip link add $gre_devname type gre local $CLI_ADDR4 ttl 64"
	rlRun "netns_cs_cleanup"

	rlRun "modprobe -r vport_gre" "0-255"
	rlRun "modprobe -r ip_gre" "0-255"
	rlRun "jobs -p | xargs kill -9" "0-255"
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
	rlRun "${yum} install psmisc -y --skip-broken" "0-255"
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
