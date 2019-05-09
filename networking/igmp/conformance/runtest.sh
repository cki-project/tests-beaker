#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/networking/igmp/conformance
#   Description: Test setting and getting of socket options for multicast and IGMP.
#   Author: Radek Pazdera <rpazdera@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012-2019 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 021$NUM_PACKETS-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include common and beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1
. ./common/include.sh || exit 1
. ./common/network.sh || exit 1
. ./common/service.sh || exit 1


PACKAGE="kernel"
# Use random group address
GROUP_ADDR[4]="239.$((${RANDOM}%254+1)).$((${RANDOM}%254+1)).$((${RANDOM}%254+1))"
GROUP_ADDR[6]="ff05::1"
LOCALHOST[4]="127.0.0.1"
LOCALHOST[6]="::1"
PORT="1337"
PORT2="1338"
NUM_PACKETS="10"
TTL="11"
HOPS="11"
PHASE_DURATION=6
#PHASE_DURATION=30
NONEXISTING_SOURCE[4]="127.0.0.2"
NONEXISTING_SOURCE[6]="::2"
OUTFILE="/tmp/igmp_max.file"
MAX_LIMIT=3000
family=${family:-"4 6"}

TEST_SETUPS=`ls -1 test_tools/sockopt_* | grep -v "\.h$"`
ip link add dummy1 type dummy
ip link set dummy1 up
ip addr add 10.10.0.1/24 dev dummy1
ip addr add 2000::1/64 dev dummy1
ping 10.10.0.1 -c 1
ping6 2000::1 -c 1

# get testing interface, or just use the default interface
TEST_IFACE=${CUR_IFACE:-dummy1}
LOCAL_IP[4]=$(get_iface_ip4 $TEST_IFACE)
LOCAL_IP[6]=$(get_iface_ip6 $TEST_IFACE)
# make sure we have ip addrss before start
if [ ! "${LOCAL_IP[4]}" ];then
	test_fail "NO LOCAL_IP[4] address"
fi
if [ ! "${LOCAL_IP[6]}" ];then
	test_fail "NO LOCAL_IP[6] address"
fi

rlJournalStart
for f in $family
do
	PHASE_DURATION=6
    rlPhaseStartSetup
        rlRun "OUTPUT=`mktemp`" 0 "Create temporary file for tcpdump output"
        rlAssertEquals "Must be root to run this test." `id -u` 0
        disable_firewall
    rlPhaseEnd

    for setup in $TEST_SETUPS;
    do
        rlPhaseStartTest "C sockopt API $setup $f"
            rlRun -l "./$setup -v $f" 0 "$setup setup"
        rlPhaseEnd
    done

    rlPhaseStartTest "MULTICAST_LOOP enabled v$f"
        rlRun "./test_tools/recv_simple -c $f -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -n$TEST_IFACE >$OUTPUT 2>/dev/null &" 0
		[ x"$f" == x"4" ] && rlRun "cat /proc/net/igmp &"
		[ x"$f" == x"6" ] && rlRun "cat /proc/net/igmp6 &"
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -l1 -n $TEST_IFACE" 0

        wait

        number_of_packets=`grep "packets_received" $OUTPUT | cut -c 18-`
        rlAssertGreater "Received $number_of_packets packets" $number_of_packets 0
    rlPhaseEnd

    rlPhaseStartTest "MULTICAST_LOOP disabled v$f"
        rlRun "./test_tools/recv_simple -c $f -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -n$TEST_IFACE>$OUTPUT 2>/dev/null &" 0
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -l0 -n$TEST_IFACE" 0

        wait

        number_of_packets=`grep "packets_received" $OUTPUT | cut -c 18-`
        rlAssertEquals "Received $number_of_packets packets" $number_of_packets 0
    rlPhaseEnd


    rlPhaseStartTest "MULTICAST_IF v$f"
        rlRun "tcpdump -i $TEST_IFACE -vvv net ${GROUP_ADDR[$f]} >$OUTPUT 2>/dev/null &" 0
        pid=$!
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -l1 -i${LOCAL_IP[$f]} -n$TEST_IFACE" 0
        # sleep sometimes to wait tcpdump capture all packages
        sleep 15
        still_running=`ps -A | grep $pid`
        if [ -n "$still_running" ];
        then
            kill $pid
        fi

        number_of_packets=`grep "${GROUP_ADDR[$f]}" $OUTPUT | wc -l`
        rlAssertGreater "Received $number_of_packets packets" $number_of_packets 0
    rlPhaseEnd

    PHASE_DURATION=12
    rlPhaseStartTest "IP_ADD_MEMBERSHIP/IP_DROP_MEMBERSHIP v$f"
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -l1 -n$TEST_IFACE &" 0
        rlRun "./test_tools/recv_membership -c $f -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -n$TEST_IFACE >$OUTPUT 2>/dev/null " 0

        wait

        number_before_add=`grep "packets_received_before_add\=" $OUTPUT | cut -c 29-`
        number_of_good=`grep "packets_received\=" $OUTPUT | cut -c 18-`
        number_of_blocked=`grep "packets_received_after_drop" $OUTPUT | cut -c 29-`
        rlAssertEquals "Received number_before_add:$number_before_add packets" $number_before_add 0
        rlAssertGreater "Received number_of_good:$number_of_good packets" $number_of_good 0
        rlAssertEquals "Received number_after_drop:$number_of_blocked packets" $number_of_blocked 0
    rlPhaseEnd

    rlPhaseStartTest "IP_ADD_SOURCE_MEMBERSHIP/IP_DROP_SOURCE_MEMBERSHIP v$f"
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -l1 -i${LOCAL_IP[$f]} -n$TEST_IFACE &" 0
        rlRun "./test_tools/recv_source_membership -c $f -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -i${LOCAL_IP[$f]} -s${LOCAL_IP[$f]} -n$TEST_IFACE>$OUTPUT 2>/dev/null " 0

        wait

        number_before_join=`grep "packets_received_before_join\=" $OUTPUT | cut -c 30-`
        number_after_join=`grep "packets_received_after_join\=" $OUTPUT | cut -c 29-`
        number_after_leave=`grep "packets_received_after_leave\=" $OUTPUT | cut -c 30-`
        rlAssertEquals "Received number_before_join:$number_before_join packets" $number_before_join 0
        rlAssertGreater "Received number_after_join:$number_after_join packets" $number_after_join 0
        rlAssertEquals "Received number_after_leave:$number_after_leave packets" $number_after_leave 0
		if [ x"$f" == x"4" ]
		then
        number_after_add=`grep "packets_received_after_add\=" $OUTPUT | cut -c 28-`
        number_after_drop=`grep "packets_received_after_drop\=" $OUTPUT | cut -c 29-`
        rlAssertGreater "Received number_after_add:$number_after_add packets" $number_after_add 0
        rlAssertEquals "Received number_after_drop:$number_after_drop packets" $number_after_drop 0
		fi
    rlPhaseEnd

    rlPhaseStartTest "IP_ADD_SOURCE_MEMBERSHIP/IP_DROP_SOURCE_MEMBERSHIP nonexisting source v$f"
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -l1 -i${LOCAL_IP[$f]} -n$TEST_IFACE &" 0
        rlRun "./test_tools/recv_source_membership -c $f -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -s${NONEXISTING_SOURCE[$f]} -i${LOCAL_IP[$f]} -n$TEST_IFACE>$OUTPUT 2>/dev/null " 0

        wait

        number_before_join=`grep "packets_received_before_join\=" $OUTPUT | cut -c 30-`
        number_after_join=`grep "packets_received_after_join\=" $OUTPUT | cut -c 29-`
        number_after_leave=`grep "packets_received_after_leave\=" $OUTPUT | cut -c 30-`
        rlAssertEquals "Received number_before_join:$number_before_join packets" $number_before_join 0
        rlAssertEquals "Received number_after_join:$number_after_join packets" $number_after_join 0
        rlAssertEquals "Received number_after_leave:$number_after_leave packets" $number_after_leave 0
		if [ x"$f" == x"4" ]
		then
        number_after_add=`grep "packets_received_after_add\=" $OUTPUT | cut -c 28-`
        number_after_drop=`grep "packets_received_after_drop\=" $OUTPUT | cut -c 29-`
        rlAssertEquals "Received number_after_add:$number_after_add packets" $number_after_add 0
        rlAssertEquals "Received number_after_drop:$number_after_drop packets" $number_after_drop 0
		fi
    rlPhaseEnd

    rlPhaseStartTest "IP_BLOCK_SOURCE/IP_UNBLOCK_SOURCE v$f"
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -l1 -i${LOCAL_IP[$f]} -n$TEST_IFACE &" 0
        rlRun "./test_tools/recv_block_source -c $f -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -i${LOCAL_IP[$f]} -s${LOCAL_IP[$f]} -n$TEST_IFACE >$OUTPUT 2>/dev/null " 0

        wait

        number_before_block=`grep "packets_received_before_block\=" $OUTPUT | cut -c 31-`
        number_while_mcast_block=`grep "packets_received_while_mcast_block\=" $OUTPUT | cut -c 36-`
		number_after_mcast_unblock=`grep "packets_received_after_mcast_unblock\=" $OUTPUT | cut -c 38-`
        rlAssertGreater "Received number_before_block:$number_before_block packets" $number_before_block 0
        rlAssertEquals "Received number_while_mcast_block:$number_while_mcast_block blocked packets" $number_while_mcast_block 0
        rlAssertGreater "Received number_after_mcast_block:$number_after_mcast_unblock packets" $number_after_mcast_unblock 0
		if [ x"$f" == x"4" ]
		then
        number_while_block=`grep "packets_received_while_block\=" $OUTPUT | cut -c 30-`
        number_after_unblock=`grep "packets_received_after_unblock\=" $OUTPUT | cut -c 32-`
        rlAssertEquals "Received number_while_block:$number_while_block blocked packets" $number_while_block 0
        rlAssertGreater "Received number_after_unblock:$number_after_unblock packets" $number_after_unblock 0
		fi
    rlPhaseEnd

    rlPhaseStartTest "IP_BLOCK_SOURCE/IP_UNBLOCK_SOURCE nonexisting source v$f"
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -l1 -i${LOCAL_IP[$f]} -n$TEST_IFACE &" 0
        rlRun "./test_tools/recv_block_source -c $f -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -i${LOCAL_IP[$f]} -s${NONEXISTING_SOURCE[$f]} -n$TEST_IFACE >$OUTPUT 2>/dev/null " 0

        wait

        number_before_block=`grep "packets_received_before_block\=" $OUTPUT | cut -c 31-`
        number_while_mcast_block=`grep "packets_received_while_mcast_block\=" $OUTPUT | cut -c 36-`
		number_after_mcast_unblock=`grep "packets_received_after_mcast_unblock\=" $OUTPUT | cut -c 38-`
        rlAssertGreater "Received number_before_block:$number_before_block packets" $number_before_block 0
        rlAssertGreater "Received number_while_mcast_block:$number_while_mcast_block blocked packets" $number_while_mcast_block 0
        rlAssertGreater "Received number_after_mcast_block:$number_after_mcast_unblock packets" $number_after_mcast_unblock 0
		if [ x"$f" == x"4" ]
		then
        number_while_block=`grep "packets_received_while_block\=" $OUTPUT | cut -c 30-`
        number_after_unblock=`grep "packets_received_after_unblock\=" $OUTPUT | cut -c 32-`
        rlAssertGreater "Received number_while_block:$number_while_block blocked packets" $number_while_block 0
        rlAssertGreater "Received number_after_unblock:$number_after_unblock packets" $number_after_unblock 0
		fi
    rlPhaseEnd

    rlPhaseStartTest "MCAST_JOIN_GROUP/MCAST_LEAVE_GROUP v$f"
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -l1 -i${LOCAL_IP[$f]} -n$TEST_IFACE &" 0
        rlRun "./test_tools/recv_group -c $f -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -i${LOCAL_IP[$f]}  -n$TEST_IFACE >$OUTPUT 2>/dev/null " 0
		wait

		number_before_join=`grep "packets_received_before_join\=" $OUTPUT | cut -c 30-`
		number_after_join=`grep "packets_received\=" $OUTPUT | cut -c 18-`
		number_after_leave=`grep "packets_received_after_leave\=" $OUTPUT | cut -c 30-`
        rlAssertEquals "Received number_before_join:$number_before_join packets" $number_before_join 0
        rlAssertGreater "Received number_after_join:$number_after_join packets" $number_after_join 0
        rlAssertEquals "Received number_after_leave:$number_after_leave packets" $number_after_leave 0
    rlPhaseEnd

    rlPhaseStartTest "IP_MSFILTER/MCAST_MSFILTER v$f"
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -l1 -i${LOCAL_IP[$f]} -n$TEST_IFACE &" 0
        rlRun "./test_tools/recv_msfilter -c $f -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -i${LOCAL_IP[$f]} -s${LOCAL_IP[$f]} -n$TEST_IFACE >$OUTPUT 2>/dev/null " 0
		[ x"$f" == x"4" ] && rlRun -l "cat /proc/net/mcfilter"
		[ x"$f" == x"6" ] && rlRun -l "cat /proc/net/mcfilter6"
		wait

		number_before_msfilter=`grep "packets_received_before_msfilter\=" $OUTPUT | cut -c 34-`
		number_after_mcast_include=`grep "packets_received_after_mcast_include\=" $OUTPUT | cut -c 38-`
		number_after_mcast_exclude=`grep "packets_received_after_mcast_exclude\=" $OUTPUT | cut -c 38-`
        rlAssertGreater "Received number_before_msfilter:$number_before_msfilter packets" $number_before_msfilter 0
        rlAssertGreater "Received number_after_mcast_include:$number_after_mcast_include packets" $number_after_mcast_include 0
        rlAssertEquals "Received number_after_mcast_exclude:$number_after_mcast_exclude packets" $number_after_mcast_exclude 0

		if [ x"$f" == x"4" ]
		then
		number_after_include=`grep "packets_received_after_include\=" $OUTPUT | cut -c 32-`
		number_after_exclude=`grep "packets_received_after_exclude\=" $OUTPUT | cut -c 32-`
        rlAssertGreater "Received number_after_include:$number_after_include packets" $number_after_include 0
        rlAssertEquals "Received number_after_exclude:$number_after_exclude packets" $number_after_exclude 0
		fi

    rlPhaseEnd

    rlPhaseStartTest "IP_MSFILTER/MCAST_MSFILTER noexistsource v$f"
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -l1 -i${LOCAL_IP[$f]} -n$TEST_IFACE &" 0
        rlRun "./test_tools/recv_msfilter -c $f -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -i${LOCAL_IP[$f]} -s${NONEXISTING_SOURCE[$f]} -n$TEST_IFACE >$OUTPUT 2>/dev/null " 0
		wait

		number_before_msfilter=`grep "packets_received_before_msfilter\=" $OUTPUT | cut -c 34-`
		number_after_mcast_include=`grep "packets_received_after_mcast_include\=" $OUTPUT | cut -c 38-`
		number_after_mcast_exclude=`grep "packets_received_after_mcast_exclude\=" $OUTPUT | cut -c 38-`
        rlAssertGreater "Received number_before_msfilter:$number_before_msfilter packets" $number_before_msfilter 0
        rlAssertEquals "Received number_after_mcast_include:$number_after_mcast_include packets" $number_after_mcast_include 0
        rlAssertGreater "Received number_after_mcast_exclude:$number_after_mcast_exclude packets" $number_after_mcast_exclude 0

		if [ x"$f" == x"4" ]
		then
		number_after_include=`grep "packets_received_after_include\=" $OUTPUT | cut -c 32-`
		number_after_exclude=`grep "packets_received_after_exclude\=" $OUTPUT | cut -c 32-`
        rlAssertEquals "Received number_after_include:$number_after_include packets" $number_after_include 0
        rlAssertGreater "Received number_after_exclude:$number_after_exclude packets" $number_after_exclude 0
		fi

    rlPhaseEnd

	rlPhaseStartTest "filter multicast for socket v$f"
		#Filtering of packets based upon a socket's multicast reception state
		#as described in RFC3376 and RFC3810
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -l1 -i${LOCAL_IP[$f]} -n$TEST_IFACE &" 0
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT2 -l1 -i${LOCAL_IP[$f]} -n$TEST_IFACE &" 0
        rlRun "./test_tools/recv_source_membership -c $f -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -i${LOCAL_IP[$f]} -s${LOCAL_IP[$f]} -n$TEST_IFACE>output1.log 2>/dev/null &" 0
        rlRun "./test_tools/recv_source_membership -c $f -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT2 -i${LOCAL_IP[$f]} -s${NONEXISTING_SOURCE[$f]} -n$TEST_IFACE>output2.log 2>/dev/null" 0

		wait

        number_after_join_in=`grep "packets_received_after_join\=" output1.log | cut -c 29-`
        number_after_join_notin=`grep "packets_received_after_join\=" output2.log | cut -c 29-`
        rlAssertGreater "Received number_after_join_in:$number_after_join_in packets" $number_after_join_in 0
        rlAssertEquals "Received number_after_join_notin:$number_after_join_notin packets" $number_after_join_notin 0
		rlRun "rm -f output{1,2}.log"
    rlPhaseEnd

    PHASE_DURATION=6
if [ x"$f" == x"6" ]
then
    rlPhaseStartTest "IPV6_MULTICAST_HOPS"
        rlRun "tcpdump -i any -vvv net ${GROUP_ADDR[$f]} >$OUTPUT 2>/dev/null &" 0
        pid=$!
        rlRun "./test_tools/send_simple -c $f -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -e$HOPS -i${LOCAL_IP[$f]} -n$TEST_IFACE" 0
        sleep 15
        still_running=`ps -A | grep $pid`
        if [ -n "$still_running" ];
        then
            kill $pid
        fi
        number_of_packets=`grep "hlim[[:space:]]*$HOPS" $OUTPUT | wc -l`
        rlAssertGreater "Received $number_of_packets packets" $number_of_packets 0
    rlPhaseEnd
fi

if [ x"$f" == x"4" ]
then
    rlPhaseStartTest "IP_MULTICAST_TTL"
        rlRun "tcpdump -i any -vvv net ${GROUP_ADDR[$f]} >$OUTPUT 2>/dev/null &" 0
        pid=$!
        rlRun "./test_tools/send_simple -c 4 -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -t$TTL -i${LOCALHOST[$f]}" 0
        # sleep sometimes to wait tcpdump capture all packages
        sleep 15
        still_running=`ps -A | grep $pid`
        if [ -n "$still_running" ];
        then
            kill $pid
        fi

        number_of_packets=`grep "ttl[[:space:]]*$TTL" $OUTPUT | wc -l`
        rlAssertGreater "Received $number_of_packets packets" $number_of_packets 0
    rlPhaseEnd

    rlPhaseStartTest "IP_ADD_SOURCE_MEMBERSHIP/IP_DROP_SOURCE_MEMBERSHIP-----------------NONEXISTING_SOURCE"
    	rlRun "PHASE_DURATION=30"
        rlRun "./test_tools/recv_add_drop_src -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -s${NONEXISTING_SOURCE[$f]} -i${LOCAL_IP[$f]}>$OUTPUT 2>/dev/null &" 0
        rlRun "./test_tools/send_simple -c 4 -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -i${LOCAL_IP[$f]}" 0

        wait

        number_of_report=`grep "Report sent--packets_received\=" $OUTPUT | cut -c 31-`
        number_of_addSource=`grep "AddSrcMember--packets_received\=" $OUTPUT | cut -c 32-`
        number_of_dropSource=`grep "DropSrcMember--packets_received\=" $OUTPUT | cut -c 33-`
        rlAssertGreater "Received $number_of_report packets" $number_of_report 0
        #if added srcIP is not local IP, number_of_addSource = 0
        #if else, number_of_addSource > 0
        rlAssertEquals "Received $number_of_addSource" $number_of_addSource 0
        rlAssertEquals "Received $number_of_dropSource packets" $number_of_dropSource 0
    rlPhaseEnd

    rlPhaseStartTest "IP_ADD_SOURCE_MEMBERSHIP/IP_DROP_SOURCE_MEMBERSHIP-----------------FUNCTIONAL TEST"
            rlRun "PHASE_DURATION=30"
            rlRun "./test_tools/recv_add_drop_src -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -s${LOCAL_IP[$f]} -i${LOCAL_IP[$f]}>$OUTPUT 2>/dev/null &" 0
            rlRun "./test_tools/send_simple -c 4 -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -i${LOCAL_IP[$f]}" 0

            wait

            number_of_report=`grep "Report sent--packets_received\=" $OUTPUT | cut -c 31-`
            number_of_addSource=`grep "AddSrcMember--packets_received\=" $OUTPUT | cut -c 32-`
            number_of_dropSource=`grep "DropSrcMember--packets_received\=" $OUTPUT | cut -c 33-`
            rlAssertGreater "Reported--Received $number_of_report packets" $number_of_report 0
           #if added srcIP is not local IP, number_of_addSource = 0
            #if else, number_of_addSource > 0
            rlAssertGreater "Add Src Membership--Received $number_of_addSource" $number_of_addSource 0
            rlAssertEquals "Drop src Membership--Received $number_of_dropSource packets" $number_of_dropSource 0
   rlPhaseEnd

    rlPhaseStartTest "IP_ADD_BLOCK_SOURCE_MEMBERSHIP------INCLUDE_EXCLUDE-----------FUNCTIONAL TEST"
            rlRun "PHASE_DURATION=60"
            rlRun "./test_tools/recv_add_block_hybrid -d$PHASE_DURATION -a${GROUP_ADDR[$f]} -p$PORT -s${LOCAL_IP[$f]} -i${LOCAL_IP[$f]}>$OUTPUT 2>/dev/null &" 0
            rlRun "PHASE_DURATION=120"
            rlRun "./test_tools/send_simple -c 4 -d$PHASE_DURATION -f0.2 -a${GROUP_ADDR[$f]} -p$PORT -i${LOCAL_IP[$f]}" 0

            wait

            number_of_report=`grep "report--packets_received\=" $OUTPUT | cut -c 26-`
            number_of_addSource=`grep "AddSrcMember--packets_received\=" $OUTPUT | cut -c 32-`
            number_of_dropSource=`grep "DropSrcMember--packets_received\=" $OUTPUT | cut -c 33-`
            number_of_blockSource=`grep "BlockSrcMember--packets_received\=" $OUTPUT | cut -c 34-`
            number_of_unblockSource=`grep "UnblockSrcMember--packets_received\=" $OUTPUT | cut -c 36-`
            rlAssertGreater "Report Membership--Received $number_of_report" $number_of_report 0
            rlAssertGreater "Add Src Membership--Received $number_of_addSource" $number_of_addSource 0
            rlAssertEquals "Drop src Membership--Received $number_of_dropSource packets" $number_of_dropSource 0
            rlAssertEquals "Block src Membership--Received $number_of_blockSource packets" $number_of_blockSource 0
            rlAssertGreater "Unblock src Membership--Received $number_of_unblockSource packets" $number_of_unblockSource 0
   rlPhaseEnd

   rlPhaseStartTest "igmp_max limit"
	    rlRun "sysctl -w net.ipv4.igmp_max_memberships=$MAX_LIMIT"
	    rlRun "sysctl -w net.core.optmem_max=2048000"

	    echo  "sysctl taking effect..."

	    rlRun "./test_tools/igmp_capacity -a 239.1.1.1 -p $MAX_LIMIT > $OUTFILE 2>/tmp/err_4_igmp" 1
	    rlAssertGrep "i=$MAX_LIMIT" $OUTFILE
	    rlAssertGrep "setsockopt: No buffer space available" /tmp/err_4_igmp
   rlPhaseEnd
fi


    rlPhaseStartCleanup
        rlRun "rm -f $OUTPUT" 0 "Remove temporary file"
    rlPhaseEnd
done
	ip link del dummy1
	modprobe -r dummy
rlJournalPrintText
rlJournalEnd
