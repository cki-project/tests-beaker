#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#	runtest.sh of /kernel/networking/ipsec/ipsec_basic/ipsec_basic_netns
#	Description: ipsec/ipsec_basic/ipsec_basic_netns
#	Author: Xiumei Mu <xmu@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#	Copyright (c) 2016 Red Hat, Inc. All rights reserved.
#
#	This copyrighted material is made available to anyone wishing
#	to use, modify, copy, or redistribute it subject to the terms
#	and conditions of the GNU General Public License version 2.
#
#	This program is distributed in the hope that it will be
#	useful, but WITHOUT ANY WARRANTY; without even the implied
#	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#	PURPOSE. See the GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public
#	License along with this program; if not, write to the Free
#	Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#	Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Global parameters
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
. ../../../common/include.sh

ipsec_stat(){
	local flow_proto=$1
	local when=$2
	local halog="/tmp/ha-${flow_proto}-${when}.log"
	local hblog="/tmp/hb-${flow_proto}-${when}.log"
	local packet="${flow_proto}.packet"

	if [ $when == before ]; then
		rlRun "tcpdump -i br0 > $packet &"
		rlRun "sleep 0.5"
	fi
	if [ $when == after ];then
		rlRun "pkill tcpdump; sleep 1"
		rlRun "cat $packet | egrep 'AH|ESP|IPComp' | head -n5"
		rm -f $packet
	fi
	echo "netns ha: ipsec statistisc: $flow_proto-$when" > $halog
	echo "#cat /proc/net/xfrm_stat" >> $halog
	$HA cat /proc/net/xfrm_stat >> $halog
	echo "#ip -s xfrm state" >> $halog
	$HA ip -s xfrm state >> $halog
	echo "#ip -s xfrm policy" >> $halog
	$HA ip -s xfrm policy >> $halog

	echo "netns hb: ipsec statistisc: $flow_proto-$when" > $hblog
	echo "#cat /proc/net/xfrm_stat" >> $hblog
	$HB cat /proc/net/xfrm_stat >> $hblog
	echo "#ip -s xfrm state" >> $hblog
	$HB ip -s xfrm state >> $hblog
	echo "#ip -s xfrm policy" >> $hblog
	$HB ip -s xfrm policy >> $hblog

	#rlFileSubmit $halog
	#rlFileSubmit $hblog
}

data_tests(){
	rlRun "tcpport=4053"
	rlRun "udpport=4053"
	rlRun "sctpport=4053"
	msg_size=$(($RANDOM%100+1400))
	rlLog "***** icmp ******"
	ipsec_stat icmp before
	for size in 10 $msg_size $IPSEC_SIZE_ARRAY ;do rlRun "$HA $ping -i 0.4 -c 5 -s $size ${HB_IP[$TEST_VER]}"; done
	ipsec_stat icmp after
	rlLog "***** tcp ******"
	ipsec_stat tcp before
	rlRun "$HB socat -u -$TEST_VER tcp-l:$tcpport open:tcprecv,creat &"
	rlRun "sleep 1"
	bytes_1M="1048576" # (1M) for tcp test
	[ $TEST_VER -eq 4 ] && rlRun "$HA socat -u -4 /dev/zero,readbytes=$bytes_1M tcp-connect:${HB_IP[$TEST_VER]}:$tcpport"
	[ $TEST_VER -eq 6 ] && rlRun "$HA socat -u -6 /dev/zero,readbytes=$bytes_1M tcp-connect:[${HB_IP[$TEST_VER]}]:$tcpport"
	rlRun "sleep 2"
	rlRun "ls -l tcprecv | grep $bytes_1M" 0 "tcp should receive $bytes_1M bytes, received `ls -l tcprecv | awk '{print $5}'` bytes"
	rm -f tcprecv
	ipsec_stat tcp after
	rlLog "***** udp ******"
	for size in $msg_size 20000;do
		ipsec_stat udp before
		rlRun "$HB socat -u -$TEST_VER udp-l:$udpport open:udprecv,creat &"
		rlRun "sleep 1"
		[ $TEST_VER -eq 4 ] && rlRun "$HA socat -u -4 /dev/zero,readbytes=$size udp-sendto:${HB_IP[$TEST_VER]}:$udpport"
		[ $TEST_VER -eq 6 ] && rlRun "$HA socat -u -6 /dev/zero,readbytes=$size udp-sendto:[${HB_IP[$TEST_VER]}]:$udpport"
		rlRun "sleep 2"
		rlRun "ls -l udprecv | grep $size" 0 "udp should receive $size bytes, received `ls -l udprecv | awk '{print $5}'` bytes"
		rlRun "pkill socat"
		rm -f udprecv
		ipsec_stat udp after
	done
	rlLog "***** sctp ******"
	ipsec_stat sctp before
	rlRun "$HB socat -u -$TEST_VER sctp-listen:$sctpport open:sctprecv,creat &"
	rlRun "sleep 1"
	[ $TEST_VER -eq 4 ] && rlRun "$HA socat -u -4 /dev/zero,readbytes=2000 sctp:${HB_IP[$TEST_VER]}:$sctpport"
	[ $TEST_VER -eq 6 ] && rlRun "$HA socat -u -6 /dev/zero,readbytes=2000 sctp:[${HB_IP[$TEST_VER]}]:$sctpport"
	rlRun "sleep 2"
	rlRun "ls -l sctprecv | grep 2000" 0 "sctp should receive 2000 bytes, received `ls -l sctprecv | awk '{print $5}'` bytes"
	rm -f sctprecv
	ipsec_stat sctp after
}

perf_tests(){
	PERF_RESULTS="ipsec-perf-in-netns-$(uname -r)-$(date +%m%d).log"
	if [ ! -e $PERF_RESULTS ];then
		printf "|%-3s|%-75s|%-8s|%-8s|%-8s|\n" "IPv" "xfrm sa" "TCP Mb/s" "UDP Mb/s" "SCTP Mb/s" | tee -a $PERF_RESULTS
	fi
	printf "|%-3s|%-75s" "v$TEST_VER" "$SUB_PARAM" | tee -a $PERF_RESULTS
	rlRun "$HB netserver"
	rlRun "sleep 3"
	for pro in TCP UDP SCTP; do
		testtype=${pro}_STREAM
		netstat -s > /tmp/before
		cat /proc/net/sctp/snmp >> /tmp/before
		rlRun "nstat -n"
		echo "#cat /proc/net/xfrm_stat"
		cat /proc/net/xfrm_stat | tee xfrm_stat.before.log
		if [ $testtype == TCP_STREAM ];then
			rlRun "$HA netperf -H ${HB_IP[$TEST_VER]} -t $testtype -f m|tee /tmp/${testtype}.log"
		else
			rlRun "$HA netperf -H ${HB_IP[$TEST_VER]} -t $testtype -f m -- -m 32768 -s 128K -S 128K | tee /tmp/${testtype}.log"
		fi
		netstat -s > /tmp/after
		cat /proc/net/sctp/snmp >> /tmp/after
		echo "# netstat increment"
		diff /tmp/before /tmp/after -y |grep "|"
		echo "# nstat -s| egrep 'Fail|Error'"
		nstat -s| egrep 'Fail|Error'
		echo "#cat /proc/net/xfrm_stat"
		cat /proc/net/xfrm_stat | tee xfrm_stat.after.log
		diff xfrm_stat.before.log xfrm_stat.after.log && rlPass "$SUB_PARAM $pro:xfrm stat don't find any error"|| rlFail "$SUB_PARAM $pro:xfrm stat find error"
		throughput=`cat /tmp/${testtype}.log |grep -v '^$'| tail -n1| awk '{print $NF}'`
		if [ "$throughput" == "AF_INET" ] || [ "$throughput" == "AF_INET6" ] ;then
			throughput=0
			rlFail "no result"
		elif [ $(echo "$throughput < $THRESHOLD"|bc -l) == 1 ];then
			rlFail "$pro throughtput: $throughput is slower than ${THRESHOLD}Mbits/sec"
		fi
		rlLog "=========================================="
		rlLog "=== IPv${TEST_VER} $testtype: ${throughput} Mbits/sec ==="
		rlLog "=========================================="
		printf "|%-8s" "$throughput" |tee -a $PERF_RESULTS
	done
	rlRun "$HB pkill netserver"
	printf "|\n" |tee -a $PERF_RESULTS

}

rlJournalStart
	rlPhaseStartSetup
		rlRun "netperf_install"
		if cat /boot/config-`uname -r`| grep -v "^#" |grep CONFIG_DEBUG_KMEMLEAK; then
			KMEMLEAK=${KMEMLEAK:-"enable"}
		else
			KMEMLEAK="disable"
		fi
		[ $KMEMLEAK == "enable" ] && rlRun "cat /sys/kernel/debug/kmemleak > kmemleak.before"
		THRESHOLD=${THRESHOLD:-"10"}
		SUB_PARAM=${SUB_PARAM:-"-p esp -e aes -m tunnel -s '10 65450'"}
		rlRun "source ipsec-parameter-setting.sh $SUB_PARAM"
		uname -r | grep el6 && {
			rlLog "For el6, Maximum data of ping6 is smaller than that on el7(due to sendbuf size),not test max data for el6"
			rlRun "IPSEC_SIZE_ARRAY='10 10000'"
		}
		rlLog "TEST_VER=$TEST_VER, SPI=$SPI, IPSEC_MODE=$IPSEC_MODE, PROTO=$PROTO, ALG=$ALG"
		[ $TEST_VER -eq 4 ] && ping="ping" || ping="ping6"
		rlRun "spi1='0x$SPI'"
		rlRun "spi2='0x$(( $SPI + 1 ))'"
		rlRun "source netns_1_net.sh"
		rlRun "$HA ip xfrm state add src ${HA_IP[$TEST_VER]} dst ${HB_IP[$TEST_VER]} spi $spi1 $PROTO $ALG mode $IPSEC_MODE sel src ${HA_IP[$TEST_VER]} dst ${HB_IP[$TEST_VER]}"
		rlRun "$HA ip xfrm state add src ${HB_IP[$TEST_VER]} dst ${HA_IP[$TEST_VER]} spi $spi2 $PROTO $ALG mode $IPSEC_MODE sel src ${HB_IP[$TEST_VER]} dst ${HA_IP[$TEST_VER]}"
		rlRun "$HA ip xfrm policy add dir out src ${HA_IP[$TEST_VER]} dst ${HB_IP[$TEST_VER]} tmpl src ${HA_IP[$TEST_VER]} dst ${HB_IP[$TEST_VER]} $PROTO mode $IPSEC_MODE"
		rlRun "$HA ip xfrm policy add dir in src ${HB_IP[$TEST_VER]} dst ${HA_IP[$TEST_VER]} tmpl src ${HB_IP[$TEST_VER]} dst ${HA_IP[$TEST_VER]} $PROTO mode $IPSEC_MODE level use"

		rlRun "$HB ip xfrm state add src ${HB_IP[$TEST_VER]} dst ${HA_IP[$TEST_VER]} spi $spi2 $PROTO $ALG mode $IPSEC_MODE sel src ${HB_IP[$TEST_VER]} dst ${HA_IP[$TEST_VER]}"
		rlRun "$HB ip xfrm state add src ${HA_IP[$TEST_VER]} dst ${HB_IP[$TEST_VER]} spi $spi1 $PROTO $ALG mode $IPSEC_MODE sel src ${HA_IP[$TEST_VER]} dst ${HB_IP[$TEST_VER]}"
		rlRun "$HB ip xfrm policy add dir out src ${HB_IP[$TEST_VER]} dst ${HA_IP[$TEST_VER]} tmpl src ${HB_IP[$TEST_VER]} dst ${HA_IP[$TEST_VER]} $PROTO mode $IPSEC_MODE"
		rlRun "$HB ip xfrm policy add dir in src ${HA_IP[$TEST_VER]} dst ${HB_IP[$TEST_VER]} tmpl src ${HA_IP[$TEST_VER]} dst ${HB_IP[$TEST_VER]} $PROTO mode $IPSEC_MODE level use"
	rlPhaseEnd

	rlPhaseStartTest "$SUB_PARAM"
		data_tests
		perf_tests
		cp /proc/crypto proc_crypto
		rlFileSubmit proc_crypto
	rlPhaseEnd

	rlPhaseStartCleanup
		rlRun "netns_clean.sh"
		rlFileSubmit $PERF_RESULTS
		if [ $KMEMLEAK == "enable" ];then
			rlRun "sleep 180" && rlRun "echo scan > /sys/kernel/debug/kmemleak"
			rlRun "cat /sys/kernel/debug/kmemleak > kmemleak.after"
			diff kmemleak.before kmemleak.after
			rlRun "diff kmemleak.before kmemleak.after | grep -B5 -A16 backtrace" 1 "checking kmemleak"
		fi
	rlPhaseEnd

	rlJournalPrintText
rlJournalEnd
