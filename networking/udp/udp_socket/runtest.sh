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

source ../../common/include.sh || exit 1

ns1="ip netns exec ha"
ns2="ip netns exec hb"
ns1_if="ha_veth0"
ns2_ip6="2000::2"
ns2_ip4="192.168.0.2"
csum_zero_msg="udp checksum is 0"
port=$(($RANDOM % 10000 + $RANDOM % 1000))
wait_time="2"

rlJournalStart
    rlPhaseStartSetup
	(uname -r |grep el6) || rlRun "modprobe -r br_netfilter" 0-255 "disable from bridge call iptables 4/6"
    rlPhaseEnd

    rlPhaseStartTest "Regression test for Bug 518034"
		rlRun "./udp_socket" 0 "Start Test"
    rlPhaseEnd

    rlPhaseStartTest "SO_NO_CHECK and UDP_NO_CHECK6_RX/TX"
		# Basic setsockopt/getsockopt tests
		rlRun "./udp_no_check -c 0"

	if [ "$(GetDistroRelease)" -ge 7 ]; then
		# Function test between 2 peers
		bash netns_1_net.sh
		rlRun "$ns1 tcpdump -U -ni $ns1_if -w $ns1_if.pcap &"

		# client (so_no_check - 1) / server
		# On the incoming side UDP seems to treat a checksum of 0 as valid.
		rlRun "$ns2 ./udp_no_check -c 1 -H 0 -P $port -l -R &> server.log &"
		sleep $wait_time
		rlRun "$ns1 ./udp_no_check -c 1 -H 0 -P $(($port+1)) -h $ns2_ip4 -p $port -s -n 1"
		sleep $wait_time
		pkill -9 udp_no_check
		rlRun "cat server.log | grep 'received'"
		rlRun "cat server.log | grep '$csum_zero_msg'"

		# client (no_check6_tx - 0) / server (no_check6_rx - 0)
		# server can receive msg sent by client
		sleep 1
		rlRun "$ns2 ./udp_no_check -c 1 -H :: -P $port -l &> server.log &"
		sleep $wait_time
		rlRun "$ns1 ./udp_no_check -c 1 -H :: -P $(($port+1)) -h $ns2_ip6 -p $port -s"
		sleep $wait_time
		pkill -9 udp_no_check
		rlRun "cat server.log | grep 'received'"

		# client (no_check6_tx - 1) / server (no_check6_rx - 0)
		# server can't receive msg sent by client
		sleep 1
		rlRun "$ns2 ./udp_no_check -c 1 -H :: -P $port -l &> server.log &"
		sleep $wait_time
		rlRun "$ns1 ./udp_no_check -c 1 -H :: -P $(($port+1)) -h $ns2_ip6 -p $port -t 1 -s"
		sleep $wait_time
		pkill -9 udp_no_check
		rlRun "cat server.log | grep 'received'" 1

		# client (no_check6_tx - 0) / server (no_check6_rx - 1)
		# server can receive msg sent by client
		sleep 1
		rlRun "$ns2 ./udp_no_check -c 1 -H :: -P $port -l -r 1 &> server.log &"
		sleep $wait_time
		rlRun "$ns1 ./udp_no_check -c 1 -H :: -P $(($port+1)) -h $ns2_ip6 -p $port -s"
		sleep $wait_time
		pkill -9 udp_no_check
		rlRun "cat server.log | grep 'received'"

		# client (no_check6_tx - 1) / server (no_check6_rx - 1)
		# server can receive msg sent by client
		sleep 1
		rlRun "$ns2 ./udp_no_check -c 1 -H :: -P $port -l -r 1 &> server.log &"
		sleep $wait_time
		rlRun "$ns1 ./udp_no_check -c 1 -H :: -P $(($port+1)) -h $ns2_ip6 -p $port -s -t 1"
		sleep $wait_time
		pkill -9 udp_no_check
		rlRun "cat server.log | grep 'received'"

		pkill tcpdump
		sleep $wait_time
		rstrnt-report-log -l $ns1_if.pcap
		bash netns_clean.sh
	fi
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
