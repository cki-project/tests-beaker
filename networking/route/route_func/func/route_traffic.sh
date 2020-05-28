#!/bin/bash

TEST_ITEMS_ALL="$TEST_ITEMS_ALL route_mtu_test route_tos_test route_addr_test route_stress_test route_ioctl_test route_fuzz_test option_realm_test route_part_forward_test route_sport_test route_dport_test route_ipproto_test"

route_tos_test()
{
rlPhaseStartTest "Route tos $TEST_TYPE $TEST_TOPO $ROUTE_MODE"

	local route_host
	[ x"$ROUTE_MODE" == x"local" ] && route_host=$C_HOSTNAME || route_host=$R_HOSTNAME
	local version=4
	local err=0

	# add tos route
	rlRun "vrun $route_host ip -$version route add default tos 0x10 dev $R_L_IF1 via ${R_R_IP1[$version]}"
	rlRun "vrun $route_host ip -$version route add default tos 0x10 dev $R_L_IF1 via ${R_R_IP1[$version]}" "0-255"
	rlRun "vrun $route_host ip -$version route add default tos 0x04 dev $R_L_IF2 via ${R_R_IP2[$version]}"
	rlRun "vrun $route_host ip -$version route add default tos 0x04 dev $R_L_IF2 via ${R_R_IP2[$version]}" "0-255"
	rlRun "vrun $route_host ip -$version route add default tos 0x08 dev $R_L_IF1 via ${R_R_IP1[$version]}"
	rlRun "vrun $route_host ip -$version route add default tos 0x08 dev $R_L_IF1 via ${R_R_IP1[$version]}" "0-255"

	# get route
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} tos 0x10 | grep \"via ${R_R_IP1[$version]} dev $R_L_IF1\""
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} tos 0x04 | grep \"via ${R_R_IP2[$version]} dev $R_L_IF2\""
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} tos 0x08 | grep \"via ${R_R_IP1[$version]} dev $R_L_IF1\""

	# ping and check route
	vrun $route_host "nohup tcpdump -U -i $R_L_IF1 -w tos10.pcap &"
	rlRun "sleep 2"
	rlRun "vrun $route_host ping ${S_IP[$version]} -c 5 -Q 0x10"
	rlRun "sleep 2"
	rlRun "vrun $route_host pkill tcpdump" "0-255"
	rlRun "sleep 2"
	rlRun "vrun $route_host tcpdump -r tos10.pcap -nnle | grep \"> ${S_IP[$version]}\""
	[ $? -ne 0 ] && { let err++; rlRun "vrun $route_host tcpdump -r tos10.pcap -nnle"; }

	vrun $route_host "nohup tcpdump -U -i $R_L_IF2 -w tos04.pcap &"
	rlRun "sleep 2"
	rlRun "vrun $route_host ping ${S_IP[$version]} -c 5 -Q 0x04"
	rlRun "sleep 2"
	rlRun "vrun $route_host pkill tcpdump" "0-255"
	rlRun "sleep 2"
	rlRun "vrun $route_host tcpdump -r tos04.pcap -nnle | grep \"> ${S_IP[$version]}\""
	[ $? -ne 0 ] && { let err++; rlRun "vrun $route_host tcpdump -r tos04.pcap -nnle"; }

	vrun $route_host "nohup tcpdump -U -i $R_L_IF1 -w tos08.pcap &"
	rlRun "sleep 2"
	rlRun "vrun $route_host ping ${S_IP[$version]} -c 5 -Q 0x08"
	rlRun "sleep 2"
	rlRun "vrun $route_host pkill tcpdump" "0-255"
	rlRun "sleep 2"
	rlRun "vrun $route_host tcpdump -r tos08.pcap -nnle | grep \"> ${S_IP[$version]}\""
	[ $? -ne 0 ] && { let err++; rlRun "vrun $route_host tcpdump -r tos08.pcap -nnle"; }

	# del route
	rlRun "vrun $route_host ip -$version route del default tos 0x10 dev $R_L_IF1 via ${R_R_IP1[$version]}"
	rlRun "vrun $route_host ip -$version route del default tos 0x10 dev $R_L_IF1 via ${R_R_IP1[$version]}" "0-255"
	rlRun "vrun $route_host ip -$version route del default tos 0x04 dev $R_L_IF2 via ${R_R_IP2[$version]}"
	rlRun "vrun $route_host ip -$version route del default tos 0x04 dev $R_L_IF2 via ${R_R_IP2[$version]}" "0-255"
	rlRun "vrun $route_host ip -$version route del default tos 0x08 dev $R_L_IF1 via ${R_R_IP1[$version]}"
	rlRun "vrun $route_host ip -$version route del default tos 0x08 dev $R_L_IF1 via ${R_R_IP1[$version]}" "0-255"

	rlRun "vrun $C_HOSTNAME ping ${S_IP[$version]} -c 5"

rlPhaseEnd
}

route_mtu_test()
{
rlPhaseStartTest "Route Mtu $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	local route_host
	[ x"$ROUTE_MODE" == x"local" ] && route_host=$C_HOSTNAME || route_host=$R_HOSTNAME
	local test_versions="4 6"
	[ x"$ROUTE_MODE" == x"forward" ] && test_versions="4"
for version in $test_versions
do
	[ x"$version" == x"4" ] && ping=ping || ping=ping6
	rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} mtu 1400"
	rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} mtu 1400" "0-255"
	rlRun "vrun $route_host ip -$version route list | grep \"${S_IP[$version]} .* dev $R_L_IF2.*mtu 1400\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version route list"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep \"mtu 1400\""
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF2 | grep $R_L_IF2"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF1 | grep $R_L_IF2" "1"

	vrun $S_HOSTNAME "nohup tcpdump -U -i any -U -w server.pcap &"
	rlRun "sleep 5"
	rlRun "vrun $C_HOSTNAME $ping ${S_IP[$version]} -c 1 -s 1500"
	rlRun "sleep 2"
	rlRun "vrun $S_HOSTNAME pkill tcpdump" "0-255"
	rlRun "sleep 5"
	if [ x"$version" == x"4" ]
	then
		rlRun "vrun $S_HOSTNAME tcpdump -r server.pcap -nnle | grep \"length 1412: .* > ${S_IP[$version]}\""
		[ $? -ne 0 ] && rlRun "vrun $S_HOSTNAME tcpdump -r server.pcap -nnle"
	else
		rlRun "vrun $S_HOSTNAME tcpdump -r server.pcap -nnle | grep \"length 1416: .* > ${S_IP[$version]}\""
		[ $? -ne 0 ] && rlRun "vrun $S_HOSTNAME tcpdump -r server.pcap -nnle"
	fi

	rlRun "vrun $route_host ip -$version route del ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} mtu 1400"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep \"mtu 1400\"" "1"
	rlRun "vrun $route_host ip -$version route del ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} mtu 1400" "0-255"
	rlRun "vrun $route_host $ping ${S_IP[$version]} -c 5"
done

rlPhaseEnd
}

# add route for different type of address
# and send packet to confirm if the route
# take effect
route_addr_test()
{
rlPhaseStartTest "Route Addr $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	local route_host
	[ x"$ROUTE_MODE" == x"local" ] && route_host=$C_HOSTNAME || route_host=$R_HOSTNAME
	multi_addr[4]=237.1.1.1
	multi_addr[6]=ff0e::1

for version in 4 6
do
	[ x"$version" == x"4" ] && ping=ping || ping=ping6
	#default route
	vrun $route_host "nohup tcpdump -U -i $R_L_IF1 -p -nnle > route_addr_pcap.log &"
	rlRun "sleep 2"
	rlRun "vrun $C_HOSTNAME $ping ${S_IP[$version]} -c 5"
	rlRun "sleep 3"
	rlRun "vrun $route_host pkill tcpdump" "0-255"
	rlRun "sleep 2"
	rlRun "vrun $route_host cat route_addr_pcap.log | grep \"> ${S_IP[$version]}\""
	[ $? -ne 0 ] && rlRun "vrun $route_host cat route_addr_pcap.log"

	#change route
	rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]}"
	rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]}" "0-255"
	rlRun "vrun $route_host ip -$version route list"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]}"
	vrun $route_host "nohup tcpdump -U -i $R_L_IF2 -p -nnle > route_addr_pcap.log &"
	rlRun "sleep 2"
	rlRun "vrun $C_HOSTNAME $ping ${S_IP[$version]} -c 5"
	rlRun "sleep 3"
	rlRun "vrun $route_host pkill tcpdump" "0-255"
	rlRun "sleep 2"
	rlRun "vrun $route_host cat route_addr_pcap.log | grep \"> ${S_IP[$version]}\""
	[ $? -ne 0 ] && rlRun "vrun $route_host cat route_addr_pcap.log"
	rlRun "vrun $route_host ip -$version route del ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]}"
	rlRun "vrun $route_host ip -$version route del ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]}" "0-255"

	#multicast addr
	if [ x"$ROUTE_MODE" == x"local" ]
	then
		rlRun "vrun $route_host ip -$version route get ${multi_addr[$version]}"
		if vrun $route_host ip -$version route get ${multi_addr[$version]} | grep $R_L_IF1
		then
			:
		else
			local route_change=1
			[ x"$version" == x"4" ] && \
				rlRun "vrun $route_host ip -$version route add ${multi_addr[$version]} dev $R_L_IF1 via ${R_R_IP1[$version]}" || \
				rlRun "vrun $route_host ip -$version route add ${multi_addr[$version]} dev $R_L_IF1 via ${R_R_IP1[$version]} table local"
		fi
		rlRun "vrun $route_host ip -$version route get ${multi_addr[$version]}"
		vrun $route_host "nohup tcpdump -U -i $R_L_IF1 -p -nnle > route_addr_pcap.log &"
		rlRun "sleep 2"
		rlRun "vrun $route_host $ping ${multi_addr[$version]} -c 5" "0,1"
		rlRun "sleep 2"
		rlRun "vrun $route_host pkill tcpdump" "0-255"
		rlRun "sleep 2"
		rlRun "vrun $route_host cat route_addr_pcap.log | grep \"> ${multi_addr[$version]}\""
		[ $? -ne 0 ] && rlRun "vrun $route_host cat route_addr_pcap.log"
		if [ x"$route_change" == x"1" ]
		then
			[ x"$version" == x"4" ] && \
				rlRun "vrun $route_host ip -$version route del ${multi_addr[$version]} dev $R_L_IF1 via ${R_R_IP1[$version]}" || \
				rlRun "vrun $route_host ip -$version route del ${multi_addr[$version]} dev $R_L_IF1 via ${R_R_IP1[$version]} table local"
		fi

		[ x"$version" == x"4" ] && \
			rlRun "vrun $route_host ip -$version route add ${multi_addr[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]}" || \
			rlRun "vrun $route_host ip -$version route add ${multi_addr[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table local"
		rlRun "vrun $route_host ip -$version route get ${multi_addr[$version]}"
		vrun $route_host "nohup tcpdump -U -i $R_L_IF2 -p -nnle > route_addr_pcap.log &"
		rlRun "sleep 2"
		rlRun "vrun $route_host $ping ${multi_addr[$version]} -c 5" "0,1"
		rlRun "sleep 2"
		rlRun "vrun $route_host pkill tcpdump" "0-255"
		rlRun "sleep 2"
		rlRun "vrun $route_host cat route_addr_pcap.log | grep \"> ${multi_addr[$version]}\""
		[ $? -ne 0 ] && rlRun "vrun $route_host cat route_addr_pcap.log"
		[ x"$version" == x"4" ] && \
			rlRun "vrun $route_host ip -$version route del ${multi_addr[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]}" || \
			rlRun "vrun $route_host ip -$version route del ${multi_addr[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table local"
	fi
done

rlPhaseEnd
}

route_stress_test()
{
	netperf_time=${NETPERF_TIME:-60}
rlPhaseStartTest "Route Stress $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	rlRun "vrun $S_HOSTNAME netserver -d"
	local test_type="TCP_STREAM UDP_STREAM SCTP_STREAM"
	if [ x"$TEST_TYPE" == x"netns" ]
	then
		uname -r | grep "2.6.32" && test_type="TCP_STREAM UDP_STREAM"
	fi
	for testname in $test_type
	do
		for version in 4 6
		do
			[ x"$testname" == x"UDP_STREAM" ] && rlRun "vrun $C_HOSTNAME netperf -$version -H ${S_IP[$version]} -t $testname -l $netperf_time -- -R 1" ||
				rlRun "vrun $C_HOSTNAME netperf -$version -H ${S_IP[$version]} -t $testname -l $netperf_time"
		done
	done
	rlRun "vrun $S_HOSTNAME pkill netserver"
rlPhaseEnd
}

route_ioctl_test()
{
rlPhaseStartTest "Route ioctl $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	[ x"$ROUTE_MODE" != x"local" ] && { rlLog "ROUTE_MODE:$ROUTE_MODE not local, return";return; }
	rlLog "[route_ioctl_test] check default v4 with route"
	rlRun "vrun $C_HOSTNAME route -A inet -n | grep \"0.0.0.0.*${R_R_IP1[4]}.*$R_L_IF1\""
	local networkv4_if1=`ipcalc -4 -n ${R_L_IP1[4]}/24 | awk -F= '{print $2}'`
	local netmaskv4_if1=`ifcalc -4 -m ${R_L_IP1[4]}/24 | awk -F= '{print $2}'`
	rlRun "vrun $C_HOSTNAME route -A inet -n | grep \"$networkv4_if1 .*0.0.0.0$netmaskv4_if1 .*$R_L_IF1\""

	rlLog "[route_ioctl_test] check default v6 with route"
	rlRun "vrun $C_HOSTNAME route -A inet6 -n | grep \"::/0.*${R_R_IP1[6]}.*$R_L_IF1\""
	rlRun "vrun $C_HOSTNAME route -A inet6 -n | grep \"ff00::/8.*$R_L_IF1\""

	local test_dst[4]=172.111.1.1
	local test_dst[6]=5010:2222:1111::1
	local version=4

for version in 4 6
do
	local family=inet
	local ping_cmd=ping
	[ x"$version" == x"6" ] && { family=inet6;ping_cmd=ping6; }
	rlRun "vrun $C_HOSTNAME route -A $family -Fn"
	uname -r | grep 2.6.32 || rlRun "vrun $C_HOSTNAME route -A $family -Cn"
	rlRun "vrun $C_HOSTNAME route -A $family -ne"
	rlRun "vrun $C_HOSTNAME route -A $family -nee"
	rlRun "vrun $C_HOSTNAME route -A $family -vn"

	vrun $C_HOSTNAME "nohup tcpdump -U -i $R_L_IF1 -w route_ioctl.pcap &"
	sleep 2
	rlRun "vrun $C_HOSTNAME $ping_cmd ${S_IP[$version]} -c 1"
	sleep 5
	rlRun "vrun $C_HOSTNAME pkill tcpdump" "0-255"
	sleep 1
	rlRun "vrun $C_HOSTNAME tcpdump -r route_ioctl.pcap -nnle | grep \"${R_L_IP1[$version]} > ${S_IP[$version]}\""


	local metric=0
	[ x"$version" == x"6" ] && metric=1024
	rlRun "vrun $C_HOSTNAME route -A $family del default metric $metric"
	rlRun "vrun $C_HOSTNAME route -A $family del default metric $metric" "0-255"
	rlRun "vrun $C_HOSTNAME route -A $family add default gw ${R_R_IP2[$version]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME route -A $family add default gw ${R_R_IP2[$version]} dev $R_L_IF2" "0-255"
	rlRun "vrun $C_HOSTNAME $ping_cmd ${S_IP[$version]} -c 5"
	vrun $C_HOSTNAME "nohup tcpdump -U -i $R_L_IF2 -w route_ioctl.pcap &"
	rlRun "sleep 2"
	rlRun "vrun $C_HOSTNAME $ping_cmd ${S_IP[$version]} -c 1"
	rlRun "sleep 5"
	rlRun "vrun $C_HOSTNAME pkill tcpdump" "0-255"
	rlRun "sleep 1"
	rlRun "vrun $C_HOSTNAME tcpdump -r route_ioctl.pcap -nnle | grep \"${R_L_IP2[$version]} > ${S_IP[$version]}\""
	rlRun "vrun $C_HOSTNAME route -A $family del default gw ${R_R_IP2[$version]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME route -A $family del default gw ${R_R_IP2[$version]} dev $R_L_IF2" "0-255"
	rlRun "vrun $C_HOSTNAME route -A $family add default gw ${R_R_IP1[$version]} dev $R_L_IF1 metric $metric"
	rlRun "vrun $C_HOSTNAME route -A $family add default gw ${R_R_IP1[$version]} dev $R_L_IF1 metric $metric" "0-255"

	rlRun "vrun $C_HOSTNAME route -A $family add ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME route -A $family -n | grep \"${test_dst[$version]}.*${R_R_IP2[$version]} .*$R_L_IF2\""
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME route -A $family add ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 metric 100"
	rlRun "vrun $C_HOSTNAME route -A $family add ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 metric 100" "0-255"
	rlRun "vrun $C_HOSTNAME route -A $family -n | grep \"${test_dst[$version]}.*${R_R_IP2[$version]} .*100 .*$R_L_IF2\""
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 metric 100"
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 metric 100" "0-255"
done

	family=inet
	version=4
	rlRun "vrun $C_HOSTNAME route -A $family add ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 mss 1400"
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 mss 1400"
	rlRun "vrun $C_HOSTNAME route -A $family add ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 mss 100000000" "0,3,4"
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 mss 100000000" "0,3,4"
	rlRun "vrun $C_HOSTNAME route -A $family add ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 window 1024"
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 window 1024"
	rlRun "vrun $C_HOSTNAME route -A $family add ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 window 16385"
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 window 16385"
	rlRun "vrun $C_HOSTNAME route -A $family add ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 irtt 300"
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 irtt 300"
	rlRun "vrun $C_HOSTNAME route -A $family add ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 irtt 12001"
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_dst[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2 irtt 12001"

	rlRun "vrun $C_HOSTNAME route -A $family add ${test_dst[$version]} reject"
	rlRun "vrun $C_HOSTNAME route -A $family add ${test_dst[$version]} reject" "0-255"
	rlRun "vrun $C_HOSTNAME $ping_cmd ${test_dst[$version]} -c 1" "2"
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_dst[$version]} reject"
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_dst[$version]} reject" "0-255"

	local test_net[4]=172.111.120.0/24
	local test_net[6]=2345::/64

	rlRun "vrun $C_HOSTNAME route -A $family add -net ${test_net[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME route -A $family add -net ${test_net[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2" "0-255"
	rlRun "vrun $C_HOSTNAME route -A $family del -net ${test_net[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME route -A $family del -net ${test_net[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2" "0-255"

	family=inet6
	version=6
	rlRun "vrun $C_HOSTNAME route -A $family add ${test_net[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME route -A $family add ${test_net[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2" "0-255"
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_net[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME route -A $family del ${test_net[$version]} gw ${R_R_IP2[$version]} dev $R_L_IF2" "0-255"
rlPhaseEnd
}

route_fuzz_test()
{
rlPhaseStartTest "Route Fuzz $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	local route_host
	local perf_time=600
	[ x"$ROUTE_MODE" == x"local" ] && route_host=$C_HOSTNAME || route_host=$R_HOSTNAME

	rlRun "vrun $route_host ip -4 route get ${S_IP[4]}"
	rlRun "vrun $route_host ip -6 route get ${S_IP[6]}"

	rlRun "vrun $S_HOSTNAME netserver -d"
	vrun $S_HOSTNAME "nohup iperf -s -D &"

	vrun $C_HOSTNAME "nohup ping ${S_IP[4]} -t 5 &"
	vrun $S_HOSTNAME "nohup ping6 ${S_IP[6]} -t 5 &"
	vrun $C_HOSTNAME "nohup netperf -4 -H ${S_IP[4]} -t TCP_STREAM -l $perf_time &"
	vrun $C_HOSTNAME "nohup netperf -6 -H ${S_IP[6]} -t TCP_STREAM -l $perf_time &"
	vrun $C_HOSTNAME "nohup netperf -4 -H ${S_IP[4]} -t TCP_STREAM -l $perf_time -- -m 32768 &"
	vrun $C_HOSTNAME "nohup netperf -6 -H ${S_IP[6]} -t TCP_STREAM -l $perf_time -- -m 32768 &"
	if  ! uname -r | grep 2.6.32
	then
		vrun $C_HOSTNAME "nohup netperf -4 -H ${S_IP[4]} -t SCTP_STREAM -l $perf_time &"
		vrun $C_HOSTNAME "nohup netperf -6 -H ${S_IP[6]} -t SCTP_STREAM -l $perf_time &"
		vrun $C_HOSTNAME "nohup netperf -4 -H ${S_IP[4]} -t SCTP_STREAM -l $perf_time -- -m 32768 &"
		vrun $C_HOSTNAME "nohup netperf -6 -H ${S_IP[6]} -t SCTP_STREAM -l $perf_time -- -m 32768 &"
	fi
	vrun $C_HOSTNAME "nohup netperf -4 -H ${S_IP[4]} -t UDP_STREAM -l $perf_time -- -R 1 &"
	vrun $C_HOSTNAME "nohup iperf -c ${S_IP[4]} -t $perf_time &"

	vrun $route_host sysctl -w net.ipv4.route.gc_interval=10
	vrun $route_host sysctl -w net.ipv6.route.gc_interval=10
	rlRun "vrun $route_host ip -4 route add ${S_IP[4]} dev $R_L_IF2 via ${R_R_IP2[4]}"
	rlRun "vrun $route_host ip -4 route add ${S_IP[4]} dev $R_L_IF2 via ${R_R_IP2[4]}" "0-255"
	rlRun "vrun $route_host ip -4 route get ${S_IP[4]}"
	rlRun "vrun $route_host ip -6 route add ${S_IP[6]} dev $R_L_IF2 via ${R_R_IP2[6]}"
	rlRun "vrun $route_host ip -6 route add ${S_IP[6]} dev $R_L_IF2 via ${R_R_IP2[6]}" "0-255"
	rlRun "vrun $route_host ip -6 route get ${S_IP[6]}"
	rlRun "sleep 5"
	rlRun "vrun $route_host ip -4 route flush cache"
	rlRun "vrun $route_host ip -4 route flush cache" "0-255"
	rlRun "vrun $route_host ip -6 route flush cache"
	rlRun "vrun $route_host ip -6 route flush cache" "0-255"
	rlRun "sleep 5"
	rlRun "vrun $route_host ip -4 route del  ${S_IP[4]} dev $R_L_IF2 via ${R_R_IP2[4]}"
	rlRun "vrun $route_host ip -4 route get ${S_IP[4]}"
	rlRun "vrun $route_host ip -4 route del  ${S_IP[4]} dev $R_L_IF2 via ${R_R_IP2[4]}" "0-255"
	rlRun "vrun $route_host ip -6 route del  ${S_IP[6]} dev $R_L_IF2 via ${R_R_IP2[6]}"
	rlRun "vrun $route_host ip -6 route get ${S_IP[6]}"
	rlRun "vrun $route_host ip -6 route del  ${S_IP[6]} dev $R_L_IF2 via ${R_R_IP2[6]}" "0-255"
	rlRun "sleep 5"

	rlRun "vrun $route_host ip link set $R_L_IF1 down"
	rlRun "sleep 5"
	rlRun "vrun $route_host ip link set $R_L_IF1 up"
	rlRun "vrun $route_host ip -6 addr add ${R_L_IP1[6]}/64 dev $R_L_IF1"
	rlRun "vrun $route_host ip route add default via ${R_R_IP1[4]} dev $R_L_IF1"
	rlRun "vrun $route_host ip -6 route add default via ${R_R_IP1[6]} dev $R_L_IF1"
	rlRun "vrun $route_host ip -4 route get ${S_IP[4]}"
	rlRun "vrun $route_host ip -6 route get ${S_IP[6]}"
	rlRun "sleep 5"
	rlRun "vrun $C_HOSTNAME ping ${S_IP[4]} -t 5 -c 5"
	rlRun "vrun $S_HOSTNAME ping6 ${S_IP[6]} -t 5 -c 5"
	for i in `seq 0 9`
	do
		# cover ipv6_sysctl_rtcache_flush
		vrun $route_host "echo 1 > /proc/sys/net/ipv4/route/flush"
		vrun $route_host "echo 1 > /proc/sys/net/ipv6/route/flush"
		rlRun "vrun $route_host ip route flush cache"
		rlRun "vrun $route_host ip -6 route flush cache"
		rlRun "vrun $route_host ip -4 route get ${S_IP[4]}"
		rlRun "vrun $route_host ip -6 route get ${S_IP[6]}"
		sleep 5
	done

	rlRun "vrun $C_HOSTNAME pkill ping"
	rlRun "vrun $C_HOSTNAME pkill ping6" "0,1"
	rlRun "vrun $C_HOSTNAME pkill netperf" "0-255"
	vrun $C_HOSTNAME "pkill iperf"

	rlRun "vrun $S_HOSTNAME pkill netserver"
	vrun $S_HOSTNAME "pkill iperf"
	vrun $route_host sysctl -w net.ipv4.route.gc_interval=60
	vrun $route_host sysctl -w net.ipv6.route.gc_interval=30
	rlRun "vrun $C_HOSTNAME ping ${S_IP[4]} -t 5 -c 5"
	rlRun "vrun $S_HOSTNAME ping6 ${S_IP[6]} -t 5 -c 5"
rlPhaseEnd
}

option_realm_test()
{
rlPhaseStartTest "option realm $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	local route_host
	[ x"$ROUTE_MODE" == x"local" ] && route_host=$C_HOSTNAME || route_host=$R_HOSTNAME

	# valid and invlid realms with ip route
	rlRun "vrun $route_host ip route add ${S_IP[4]} dev $R_L_IF1 realms -1" "1-255"
	rlRun "vrun $route_host ip route add ${S_IP[4]} dev $R_L_IF1 realms 0"
	rlRun "vrun $route_host ip route del ${S_IP[4]} dev $R_L_IF1 realms 0"
	rlRun "vrun $route_host ip route add ${S_IP[4]} dev $R_L_IF1 realms 65536"
	rlRun "vrun $route_host ip route del ${S_IP[4]} dev $R_L_IF1 realms 65536"
	rlRun "vrun $route_host ip route add ${S_IP[4]} dev $R_L_IF1 realms 65535"
	rlRun "vrun $route_host ip route del ${S_IP[4]} dev $R_L_IF1 realms 65535"
	rlRun "vrun $route_host ip route add ${S_IP[4]} dev $R_L_IF1 realms 256/256" "1-255"
	rlRun "vrun $route_host ip route add ${S_IP[4]} dev $R_L_IF1 realms 255/255"
	rlRun "vrun $route_host ip route del ${S_IP[4]} dev $R_L_IF1 realms 255/255"
	rlRun "vrun $route_host ip route add ${S_IP[4]} dev $R_L_IF1 realms 0/0"
	rlRun "vrun $route_host ip route del ${S_IP[4]} dev $R_L_IF1 realms 0/0"
	rlRun "vrun $route_host ip route add ${S_IP[4]} dev $R_L_IF1 realms -1/-1" "1-255"

	# valid and invalid realms with ip rule
	rlRun "vrun $route_host ip rule add to ${S_IP[4]} realms -1" "1-255"
	rlRun "vrun $route_host ip rule add to ${S_IP[4]} realms 0"
	rlRun "vrun $route_host ip rule del to ${S_IP[4]} realms 0"
	rlRun "vrun $route_host ip rule add to ${S_IP[4]} realms 65536"
	rlRun "vrun $route_host ip rule del to ${S_IP[4]} realms 65536"
	rlRun "vrun $route_host ip rule add to ${S_IP[4]} realms 65535"
	rlRun "vrun $route_host ip rule del to ${S_IP[4]} realms 65535"
	rlRun "vrun $route_host ip rule add to ${S_IP[4]} realms -1/-1" "1-255"
	rlRun "vrun $route_host ip rule add to ${S_IP[4]} realms 0/0"
	rlRun "vrun $route_host ip rule del to ${S_IP[4]} realms 0/0"
	rlRun "vrun $route_host ip rule add to ${S_IP[4]} realms 255/255"
	rlRun "vrun $route_host ip rule del to ${S_IP[4]} realms 255/255"
	rlRun "vrun $route_host ip rule add to ${S_IP[4]} realms 256/256" "1-255"

	# normal operation with ip rule and ip route
	# only ip rule provide realms
	rlRun "vrun $route_host ip rule add to ${S_IP[4]} realms 1/2 table 1234"
	rlRun "vrun $route_host ip route add ${S_IP[4]} dev $R_L_IF1 via ${R_R_IP1[4]} table 1234"
	rlRun "vrun $C_HOSTNAME ping ${S_IP[4]} -c 1"
	# rlRun "vrun $route_host rtacct 1 | grep \"1.*84.*1.*84.*1\""
	# [ $? -ne 0 ] && rlRun -l "vrun $route_host rtacct 1"
	# rlRun "vrun $route_host rtacct 2 | grep \"2.*84.*1.*84.*1\""
	# [ $? -ne 0 ] && rlRun -l "vrun $route_host rtacct 2"
	rlRun "vrun $route_host cat /proc/net/rt_acct"
	rlRun "vrun $route_host rtacct -r"

	rlRun "vrun $route_host ip rule del to ${S_IP[4]} realms 1/2 table 1234"
	rlRun "vrun $route_host ip rule add to ${S_IP[4]} realms 3 table 1234"
	rlRun "vrun $C_HOSTNAME ping ${S_IP[4]} -c 1"
	# rlRun "vrun $route_host rtacct 3 | grep \"3.*84.*1.*84.*1\""
	# [ $? -ne 0 ] && rlRun -l "vrun $route_host rtacct 3"
	# rlRun "vrun $route_host rtacct | grep \"unknown.*84.*1.*84.*1\""
	# [ $? -ne 0 ] && rlRun -l "vrun $route_host rtacct"
	rlRun "vrun $route_host ip rule del to ${S_IP[4]} realms 3 table 1234"
	rlRun "vrun $route_host ip route del ${S_IP[4]} dev $R_L_IF1 via ${R_R_IP1[4]} table 1234"
	rlRun "vrun $route_host cat /proc/net/rt_acct"
	rlRun "vrun $route_host rtacct -r"

	# only ip route provides realms
	rlRun "vrun $route_host ip route add ${S_IP[4]} dev $R_L_IF1 via ${R_R_IP1[4]} realms 1/2"
	rlRun "vrun $C_HOSTNAME ping ${S_IP[4]} -c 1"
	# rlRun "vrun $route_host rtacct 1 | grep \"1.*84.*1\""
	# [ $? -ne 0 ] && rlRun "vrun $route_host rtacct 1"
	# rlRun "vrun $route_host rtacct 2 | grep \"2.*84.*1\""
	# [ $? -ne 0 ] && rlRun "vrun $route_host rtacct 2"
	rlRun "vrun $route_host cat /proc/net/rt_acct"
	rlRun "vrun $route_host rtacct -r"

	rlRun "vrun $route_host ip route change ${S_IP[4]} dev $R_L_IF1 via ${R_R_IP1[4]} realms 3"
	rlRun "vrun $C_HOSTNAME ping ${S_IP[4]} -c 1"
	# rlRun "vrun $route_host rtacct 3 | grep \"3.*84.*1.*84.*1\""
	# [ $? -ne 0 ] && rlRun -l "vrun $route_host rtacct 3"
	rlRun "vrun $route_host ip route del ${S_IP[4]} dev $R_L_IF1 via ${R_R_IP1[4]} realms 3"
	rlRun "vrun $route_host cat /proc/net/rt_acct"
	rlRun "vrun $route_host rtacct -r"

	# both ip rule and ip route provide realms
	rlRun "vrun $route_host ip rule add to ${S_IP[4]} realms 1/2 table 1234"
	rlRun "vrun $route_host ip rule list | grep \"${S_IP[4]}.*realms 1/2\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip rule list"
	rlRun "vrun $route_host ip route add ${S_IP[4]} dev $R_L_IF1 via ${R_R_IP1[4]} realms 3/4 table 1234"
	rlRun "vrun $route_host ip route list table 1234 | grep \"${S_IP[4]}.*realms 3/4\""
	[ $? -ne 0 ] && rlRun "vrun $route_host ip route list table 1234"
	rlRun "vrun $C_HOSTNAME ping ${S_IP[4]} -c 1"
	# rlRun "vrun $route_host rtacct | grep \"^3\""
	# [ $? -ne 0 ] && rlRun -l "vrun $route_host rtacct"
	# rlRun "vrun $route_host rtacct | grep \"^4\""
	# [ $? -ne 0 ] && rlRun -l "vrun $route_host rtacct"
	rlRun "vrun $route_host cat /proc/net/rt_acct"
	rlRun "vrun $route_host rtacct -r"

	rlRun "vrun $route_host ip route replace ${S_IP[4]} dev $R_L_IF1 via ${R_R_IP1[4]} realms 5/6 table 1234"
	rlRun "vrun $route_host ip route list table 1234 | grep \"${S_IP[4]}.*realms 5/6\""
	[ $? -ne 0 ] && rlRun "vrun $route_host ip route list table 1234"
	rlRun "vrun $C_HOSTNAME ping ${S_IP[4]} -c 1"
	# rlRun "vrun $route_host rtacct | grep \"^5\""
	# [ $? -ne 0 ] && rlRun -l "vrun $route_host rtacct"
	# rlRun "vrun $route_host rtacct | grep \"^6\""
	# [ $? -ne 0 ] && rlRun -l "vrun $route_host rtacct"
	rlRun "vrun $route_host cat /proc/net/rt_acct"
	rlRun "vrun $route_host rtacct -r"

	rlRun "vrun $route_host ip route append ${S_IP[4]} dev $R_L_IF1 via ${R_R_IP1[4]} realms 7/8 table 1234"
	rlRun "vrun $route_host ip route list table 1234 | grep \"${S_IP[4]}.*realms 7/8\""
	[ $? -ne 0 ] && rlRun "vrun $route_host ip route list table 1234"
	# https://bugzilla.redhat.com/show_bug.cgi?id=1539581
	rlRun "vrun $route_host ip route del ${S_IP[4]} dev $R_L_IF1 via ${R_R_IP1[4]} realms 7/8 table 1234"
	rlRun "vrun $route_host ip route list table 1234 | grep \"${S_IP[4]}.*realms 7/8\"" "1"
	[ $? -ne 1 ] && rlRun "vrun $route_host ip route list table 1234"

	rlRun "vrun $route_host ip route append ${S_IP[4]} dev $R_L_IF1 via ${R_R_IP1[4]} realms 9/10 table 1234"
	rlRun "vrun $route_host ip route flush table 1234"
	rlRun "vrun $route_host ip route list table 1234 | grep realms" "1"
	[ $? -ne 1 ] && rlRun -l "vrun $route_host ip route list table 1234"

	rlRun "vrun $route_host ip rule del to ${S_IP[4]} realms 1/2 table 1234"

rlPhaseEnd
}

route_part_forward_test()
{
	# to cover https://bugzilla.redhat.com/show_bug.cgi?id=1520244
rlPhaseStartTest "part forward $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	[ x"$ROUTE_MODE" != x"local" ] && { rlLog "ROUTE_MODE:$ROUTE_MODE not local, return";return; }

	rlRun "vrun $R_HOSTNAME sysctl -w net.ipv4.conf.${R_R_IF1}.forwarding=0"
	# ip route get would return 2 on 4 kernel
	if vrun $R_HOSTNAME ip route get to ${S_IP[4]} iif $R_R_IF1 from ${R_L_IP1[4]}
	then
		rlRun "vrun $R_HOSTNAME ip route get to ${S_IP[4]} iif $R_R_IF1 from ${R_L_IP1[4]} | grep \"unreachable\""
		[ $? -ne 0 ] && rlRun -l "vrun $R_HOSTNAME ip route get to ${S_IP[4]} iif $R_R_IF1 from ${R_L_IP1[4]}"
		rlRun "vrun $R_HOSTNAME ip route get to ${S_IP[4]} iif $R_R_IF2 from ${R_L_IP2[4]} | grep \"unreachable\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $R_HOSTNAME ip route get to ${S_IP[4]} iif $R_R_IF2 from ${R_L_IP2[4]}"
	else
		rlRun "vrun $R_HOSTNAME ip route get to ${S_IP[4]} iif $R_R_IF2 from ${R_L_IP2[4]}"
		[ $? -ne 0 ] && rlRun -l "vrun $R_HOSTNAME ip route get to ${S_IP[4]} iif $R_R_IF2 from ${R_L_IP2[4]}"
		rlRun "vrun $R_HOSTNAME ip route get to ${S_IP[4]} iif $R_R_IF2 from ${R_L_IP2[4]} | grep \"unreachable\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $R_HOSTNAME ip route get to ${S_IP[4]} iif $R_R_IF2 from ${R_L_IP2[4]}"
	fi

	rlRun "vrun $R_HOSTNAME ip route flush cache"

	rlRun "vrun $C_HOSTNAME ping ${S_IP[4]} -c 1" "1-255"
	rlRun "vrun $C_HOSTNAME ip route change default via ${R_R_IP2[4]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ping ${S_IP[4]} -c 1"
	rlRun "vrun $C_HOSTNAME ip route change default via ${R_R_IP1[4]} dev $R_L_IF1"

	rlRun "vrun $C_HOSTNAME ip route flush cache"
	rlRun "vrun $R_HOSTNAME ip route flush cache"

	rlRun "vrun $R_HOSTNAME sysctl -w net.ipv4.conf.${R_R_IF1}.forwarding=1"
	rlRun "vrun $R_HOSTNAME sysctl -w net.ipv4.conf.${R_R_IF2}.forwarding=0"

	rlRun "vrun $S_HOSTNAME netserver -d" "0-255"
	rlRun "vrun $R_HOSTNAME netserver -d" "0-255"

	vrun $C_HOSTNAME "netperf -4 -H ${R_R_IP2[4]} -t TCP_STREAM -l 30 -- -m 16k &"
	vrun $C_HOSTNAME "netperf -4 -H ${R_R_IP2[4]} -t SCTP_STREAM -l 35 -- -m 16k &"
	vrun $C_HOSTNAME "netperf -4 -H ${R_R_IP2[4]} -t UDP_STREAM -l 40 -- -R 1 &"
	vrun $C_HOSTNAME "netperf -4 -H ${S_IP[4]} -t TCP_STREAM -l 45 -- -m 16k &"
	vrun $C_HOSTNAME "netperf -4 -H ${S_IP[4]} -t SCTP_STREAM -l 50 -- -m 16k &"
	vrun $C_HOSTNAME "netperf -4 -H ${S_IP[4]} -t UDP_STREAM -l 55 -- -R 1 &"

	for tmp_time in `seq 1 20`
	do
		sleep 1
		rlRun "vrun $C_HOSTNAME ip route flush cache"
		rlRun "vrun $R_HOSTNAME ip route flush cache"
	done
	vrun $C_HOSTNAME pkill -9 netperf
	rlRun "vrun $C_HOSTNAME ip route flush cache"
	rlRun "vrun $R_HOSTNAME ip route flush cache"

	rlRun "vrun $R_HOSTNAME sysctl -w net.ipv4.conf.${R_R_IF2}.forwarding=1"
rlPhaseEnd
}

route_sport_test()
{
rlPhaseStartTest "Route Sport $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	local route_host
	if ! ip rule add sport 1234 table 100
	then
		rlLog "not support sport, return"
		return 0
	else
		rlRun "ip rule del sport 1234 table 100"
	fi
	[ x"$ROUTE_MODE" == x"local" ] && route_host=$C_HOSTNAME || route_host=$R_HOSTNAME
	local test_versions="4 6"
	[ x"$ROUTE_MODE" == x"forward" ] && test_versions="4"
for version in $test_versions
do
	[ x"$version" == x"4" ] && ping=ping || ping=ping6
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} sport 7000 table 101"
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} sport 7000 table 101" "0-255"
	rlRun "vrun $route_host ip -$version rule list | grep \"sport 7000.*lookup 101\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version rule list"
	# https://bugzilla.redhat.com/show_bug.cgi?id=1678111
	# not support yet, comment this
	#rlRun "vrun $route_host ip -$version rule list sport 7000 | grep \"lookup 101\""
	#[ $? -ne 0 ] && rlRun "vrun $route_host ip -$version rule list sport 7000"
	rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 101"
	rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 101" "0-255"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep \"${R_R_IP1[$version]}\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version route get ${S_IP[$version]}"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} sport 7000 | grep \"${R_R_IP2[$version]}\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version route get ${S_IP[$version]} sport 7000"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF2 | grep $R_L_IF2"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF2 sport 7000 | grep $R_L_IF2"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF1 sport 7000 | grep $R_L_IF1"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF1 | grep $R_L_IF1"

	vrun $route_host "nohup tcpdump -U -i $R_L_IF2 -w sport${version}.pcap &"
	vrun $S_HOSTNAME "nohup ncat -$version -l 10010 > tcp${version}-7000.log &"
	rlRun "sleep 2"
	rlRun "vrun $C_HOSTNAME ncat -$version -p 7000 ${S_IP[$version]} 10010 <<< 1" "0-255"

	rlRun "sleep 2"
	rlRun "vrun $route_host pkill tcpdump" "0-255"
	rlRun "sleep 5"
	rlRun "vrun $route_host tcpdump -r sport${version}.pcap -nnle | grep \"> ${S_IP[$version]}\""
	[ $? -ne 0 ] && rlRun "vrun $route_host tcpdump -r sport${version}.pcap -nnle"

	#rlRun "vrun $route_host ip rule save sport 7000 > sport.route"
	#rlRun "vrun $route_host ip rule flush sport 7000"
	#rlRun "vrun $route_host ip rule list | grep \"sport 7000\"" "1"
	#rlRun "vrun $route_host ip rule restore < sport.route"
	rlRun "vrun $route_host ip -$version rule list | grep \"sport 7000.*lookup 101\""
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} sport 7000 table 101"
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} sport 7000 table 101"
	rlRun "vrun $route_host ip -$version rule list | grep \"sport 7000.*lookup 101\""
	#[ $? -ne 0 ] && rlRun "$vrun _route_host ip -$version rule list sport 7000"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} sport 7000 | grep \"${R_R_IP2[$version]}\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version route get ${S_IP[$version]} sport 7000"

	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} sport 7000 table 101"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} sport 7000 table 101" "0-255"

	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} sport 11111111 table 101" "0-255"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} sport 11111111 table 101" "0-255"
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} sport 0 table 101" "0-255"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} sport 0 table 101" "0-255"
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} sport -1 table 101" "0-255"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} sport -1 table 101" "0-255"

	rlRun "vrun $route_host ip -$version route flush table 101"
	rlRun "vrun $C_HOSTNAME pkill -9 socat" "0-255"
done

rlPhaseEnd
}

route_dport_test()
{
rlPhaseStartTest "Route Dport $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	local route_host
	if ! ip rule add dport 1234 table 100
	then
		rlLog "not support dport, return"
		return 0
	else
		rlRun "ip rule del dport 1234 table 100"
	fi
	[ x"$ROUTE_MODE" == x"local" ] && route_host=$C_HOSTNAME || route_host=$R_HOSTNAME
	local test_versions="4 6"
	[ x"$ROUTE_MODE" == x"forward" ] && test_versions="4"
for version in $test_versions
do
	[ x"$version" == x"4" ] && ping=ping || ping=ping6
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} dport 7001 table 102"
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} dport 7001 table 102" "0-255"
	rlRun "vrun $route_host ip -$version rule list | grep \"dport 7001.*lookup 102\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version rule list"
	#rlRun "vrun $route_host ip -$version rule list dport 7001 | grep \"lookup 102\""
	# https://bugzilla.redhat.com/show_bug.cgi?id=1678111
	#[ $? -ne 0 ] && rlRun "vrun $route_host ip -$version rule list dport 7001"
	rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 102"
	rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 102" "0-255"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep \"${R_R_IP1[$version]}\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version route get ${S_IP[$version]}"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} dport 7001 | grep \"${R_R_IP2[$version]}\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version route get ${S_IP[$version]} dport 7001"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF2 | grep $R_L_IF2"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF2 dport 7001 | grep $R_L_IF2"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF1 dport 7001 | grep $R_L_IF1"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF1 | grep $R_L_IF1"

	vrun $route_host "nohup tcpdump -U -i $R_L_IF2 -w dport${version}.pcap &"
	vrun $S_HOSTNAME "nohup ncat -$version -l 7001 > tcp${version}-7001.log &"
	rlRun "sleep 2"
	rlRun "vrun $C_HOSTNAME ncat -$version ${S_IP[$version]} 7001 <<< 1" "0-255"

	rlRun "sleep 2"
	rlRun "vrun $route_host pkill tcpdump" "0-255"
	rlRun "sleep 5"
	rlRun "vrun $route_host tcpdump -r dport${version}.pcap -nnle | grep \"> ${S_IP[$version]}\""
	[ $? -ne 0 ] && rlRun "vrun $route_host tcpdump -r dport${version}.pcap -nnle"

	#rlRun "vrun $route_host ip rule save dport 7001 > dport.route"
	#rlRun "vrun $route_host ip rule flush dport 7001"
	#rlRun "vrun $route_host ip rule list | grep \"dport 7001\"" "1"
	#rlRun "vrun $route_host ip rule restore < dport.route"
	rlRun "vrun $route_host ip -$version rule list | grep \"dport 7001.*lookup 102\""
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} dport 7001 table 102"
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} dport 7001 table 102"
	rlRun "vrun $route_host ip -$version rule list | grep \"dport 7001.*lookup 102\""
	#[ $? -ne 0 ] && rlRun "$vrun _route_host ip -$version rule list dport 7001"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} dport 7001 | grep \"${R_R_IP2[$version]}\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version route get ${S_IP[$version]} dport 7001"

	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} dport 7001 table 102"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} dport 7001 table 102" "0-255"

	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} dport 11111111 table 102" "0-255"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} dport 11111111 table 102" "0-255"
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} dport 0 table 102" "0-255"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} dport 0 table 102" "0-255"
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} dport -1 table 102" "0-255"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} dport -1 table 102" "0-255"

	rlRun "vrun $route_host ip -$version route flush table 102"
	rlRun "vrun $C_HOSTNAME pkill -9 socat" "0-255"
done

rlPhaseEnd
}

route_ipproto_test()
{
rlPhaseStartTest "Route Ipproto $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	local route_host
	if ! ip rule add ipproto tcp table 100
	then
		rlLog "not support ipproto, return"
		return 0
	else
		rlRun "ip rule del ipproto tcp table 100"
	fi
	[ x"$ROUTE_MODE" == x"local" ] && route_host=$C_HOSTNAME || route_host=$R_HOSTNAME
	local test_versions="4 6"
	[ x"$ROUTE_MODE" == x"forward" ] && test_versions="4"
for version in $test_versions
do
	[ x"$version" == x"4" ] && ping=ping || ping=ping6
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} ipproto tcp table 102"
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} ipproto tcp table 102" "0-255"
	rlRun "vrun $route_host ip -$version rule list | grep \"ipproto tcp.*lookup 102\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version rule list"
	#rlRun "vrun $route_host ip -$version rule list ipproto tcp | grep \"lookup 102\""
	# https://bugzilla.redhat.com/show_bug.cgi?id=1678111
	#[ $? -ne 0 ] && rlRun "vrun $route_host ip -$version rule list ipproto tcp"
	rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 102"
	rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 102" "0-255"

	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep \"${R_R_IP1[$version]}\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version route get ${S_IP[$version]}"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} ipproto tcp | grep \"${R_R_IP2[$version]}\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version route get ${S_IP[$version]} ipproto tcp"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF2 | grep $R_L_IF2"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF2 ipproto tcp | grep $R_L_IF2"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF1 ipproto tcp | grep $R_L_IF1"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF1 | grep $R_L_IF1"

	vrun $route_host "nohup tcpdump -U -i $R_L_IF2 -w ipproto${version}.pcap &"
	vrun $S_HOSTNAME "nohup ncat -$version -l 7002 > tcp${version}-ipproto.log &"
	rlRun "sleep 2"
	rlRun "vrun $C_HOSTNAME ncat -$version ${S_IP[$version]} 7002 <<< 1" "0-255"

	rlRun "sleep 2"
	rlRun "vrun $route_host pkill tcpdump" "0-255"
	rlRun "vrun $route_host pkill ncat" "0-255"
	rlRun "sleep 5"
	rlRun "vrun $route_host tcpdump -r ipproto${version}.pcap -nnle | grep \"> ${S_IP[$version]}\""
	[ $? -ne 0 ] && rlRun "vrun $route_host tcpdump -r ipproto${version}.pcap -nnle"

	#rlRun "vrun $route_host ip rule save ipproto tcp > ipproto.route"
	#rlRun "vrun $route_host ip rule flush ipproto tcp"
	#rlRun "vrun $route_host ip rule list | grep \"ipproto tcp\"" "1"
	#rlRun "vrun $route_host ip rule restore < ipproto.route"
	rlRun "vrun $route_host ip -$version rule list | grep \"ipproto tcp.*lookup 102\""
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} ipproto tcp table 102"
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} ipproto tcp table 102"
	rlRun "vrun $route_host ip -$version rule list | grep \"ipproto tcp.*lookup 102\""
	[ $? -ne 0 ] && rlRun "$vrun _route_host ip -$version rule list ipproto tcp"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} ipproto tcp | grep \"${R_R_IP2[$version]}\""
	[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version route get ${S_IP[$version]} ipproto tcp"

	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} ipproto tcp table 102"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} ipproto tcp table 102" "0-255"

	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} ipproto udp table 102"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} ipproto udp | grep \"${R_R_IP2[$version]}\""

	vrun $route_host "nohup tcpdump -U -i $R_L_IF2 -w ipproto${version}.pcap &"
	vrun $S_HOSTNAME "nohup ncat -u -$version -l 7002 > udp${version}-ipproto.log &"
	rlRun "sleep 2"
	vrun $C_HOSTNAME "socat - udp${version}-sendto:[${S_IP[$version]}]:7002 <<< 1111"

	rlRun "sleep 2"
	rlRun "vrun $route_host pkill tcpdump" "0-255"
	rlRun "vrun $route_host pkill ncat" "0-255"
	rlRun "sleep 5"
	rlRun "vrun $route_host tcpdump -r ipproto${version}.pcap -nnle | grep \"> ${S_IP[$version]}\""
	[ $? -ne 0 ] && rlRun "vrun $route_host tcpdump -r ipproto${version}.pcap -nnle"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} ipproto udp table 102"

	if [ $version -eq 4 ]
	then
		rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} ipproto icmp table 102"
		rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} ipproto icmp | grep \"${R_R_IP2[$version]}\""
	elif [ $version -eq 6 ]
	then
		rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} ipproto ipv6-icmp table 102"
		# ip route does not support ipv6-icmp
		#rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} ipproto ipv6-icmp | grep \"${R_R_IP2[$version]}\""
	fi

	vrun $route_host "nohup tcpdump -U -i $R_L_IF2 -w ipproto${version}.pcap &"
	rlRun "sleep 2"
	rlRun "vrun $C_HOSTNAME $ping ${S_IP[$version]} -c 4"

	rlRun "sleep 2"
	rlRun "vrun $route_host pkill tcpdump" "0-255"
	rlRun "vrun $route_host pkill ncat" "0-255"
	rlRun "sleep 5"
	rlRun "vrun $route_host tcpdump -r ipproto${version}.pcap -nnle | grep \"> ${S_IP[$version]}\""
	[ $? -ne 0 ] && rlRun "vrun $route_host tcpdump -r ipproto${version}.pcap -nnle"
	if [ $version -eq 4 ]
	then
		rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} ipproto icmp table 102" "0-255"
		rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} ipproto icmp table 102"
		rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} ipproto icmp table 102" "0-255"
	elif [ $version -eq 6 ]
	then
		rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} ipproto ipv6-icmp table 102" "0-255"
		rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} ipproto ipv6-icmp table 102"
		rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} ipproto ipv6-icmp table 102" "0-255"
	fi

	rlRun "vrun $route_host ip -$version route flush table 102"
	rlRun "vrun $C_HOSTNAME pkill -9 socat" "0-255"
done

rlPhaseEnd
}
