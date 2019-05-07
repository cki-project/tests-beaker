#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/networking/tcp/tcp_keepalive
#   Description: tcp/tcp_keepalive
#   Author: Xiumei Mu <xmu@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc. All rights reserved.
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
#   Boston, MA 02110-1301, USA.
#

# include common and Beaker environments
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1


rlJournalStart
    rlPhaseStartSetup
       # host
       rlRun "sys_ka_idle=$(cat /proc/sys/net/ipv4/tcp_keepalive_time)" 0
       rlRun "sys_ka_interval=$(cat /proc/sys/net/ipv4/tcp_keepalive_intvl)" 0
       rlRun "sys_ka_idle=$(cat /proc/sys/net/ipv4/tcp_keepalive_probes)" 0
       # netns
       YUM=/usr/bin/yum
       if [ -x /usr/bin/dnf ]; then
           YUM=/usr/bin/dnf
       fi
       rlRun "$YUM -y install iproute" 0 "iproute installed"
       rlRun "ip netns add netns_ka" 0
       rlRun "ip netns exec netns_ka ip link set lo up" 0
       rlRun "netns_sys_ka_idle=$(ip netns exec netns_ka cat /proc/sys/net/ipv4/tcp_keepalive_time)" 0
       rlRun "netns_sys_ka_interval=$(ip netns exec netns_ka cat /proc/sys/net/ipv4/tcp_keepalive_intvl)" 0
       rlRun "netns_sys_ka_idle=$(ip netns exec netns_ka cat /proc/sys/net/ipv4/tcp_keepalive_probes)"
       # parameters of ./keepalive
       rlLog "socket settings of keepalive will overide the system's" 0
       rlRun "idle=6" 0
       rlRun "interval=1" 0
       rlRun "maxpkt=10" 0
       rlRun "port=7811"
    rlPhaseEnd

    rlPhaseStartTest "host"
        rlRun "tcpdump -nn -i lo port $port -w tcpdump.host.pcap &" 0
        sleep 5
        rlRun "./keepalive 127.0.0.1 $port $idle $interval $maxpkt &" 0
        rlRun "sleep $((15 + $idle + $interval * $maxpkt)) " 0  # should be > $idle + $interval * $maxpkt
        rlRun "childpid=`pgrep keepalive | tail -n1`" 0
        rlRun "kill -s SIGINT $childpid" 0
        rlRun "pkill tcpdump" 0
        sleep 5
        rlRun -l "tcpdump -r tcpdump.host.pcap" 0
        rlRun "kalive_pkts=$(tcpdump -r tcpdump.host.pcap | grep $port' >' | grep 'Flags \[.\]' | wc -l)" 0
        if [ $kalive_pkts -ne $maxpkt ];then
            rlFail "fail: kalive_pkts should equal $maxpkt"
            rlFileSubmit tcpdump.host.pcap
        else
            rlPass "pass: kalive_pkts equals $maxpkt"
        fi
    rlPhaseEnd

    rlPhaseStartTest "netns"
        rlRun "ip netns exec netns_ka tcpdump -nn -i lo port $port -w tcpdump.netns.pcap &" 0
        sleep 5 
        rlRun "ip netns exec netns_ka ./keepalive 127.0.0.1 $port $idle $interval $maxpkt &" 0
        rlRun "sleep $((15 + $idle + $interval * $maxpkt)) " 0 # should be > $idle + $interval * $maxpkt
        rlRun "childpid=`pgrep keepalive | tail -n1`" 0
        rlRun "kill -s SIGINT $childpid" 0
        rlRun "pkill tcpdump" 0
        sleep 5
        rlRun -l "tcpdump -r tcpdump.netns.pcap" 0
        rlRun "kalive_pkts=$(tcpdump -r tcpdump.netns.pcap | grep $port' >' | grep 'Flags \[.\]' | wc -l)" 0
        if [ $kalive_pkts -ne $maxpkt ];then
            rlFail "fail: kalive_pkts should equal $maxpkt"
            rlFileSubmit tcpdump.netns.pcap
        else
            rlPass "pass: kalive_pkts equals $maxpkt"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "ip netns del netns_ka"
    rlPhaseEnd

    rlJournalPrintText
rlJournalEnd

