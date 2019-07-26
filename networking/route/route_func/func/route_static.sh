#!/bin/bash

TEST_ITEMS_ALL="$TEST_ITEMS_ALL route_default_test route_prefix_test route_selector_test route_options_test"

route_default_test()
{
rlPhaseStartTest "Route_Default $TEST_TYPE $TEST_TOPO $ROUTE_MODE"

	[ x"$ROUTE_MODE" != x"local" ] && { rlLog "ROUTE_MODE:$ROUTE_MODE not local, return";return; }
	#ipv4
	rlLog "[Log] default v4"

	rlRun "vrun $C_HOSTNAME ip route list dev lo"
	rlRun "vrun $C_HOSTNAME ip route list dev lo | sed -n '3,$'p | grep -w lo" "1"
	rlRun "vrun $C_HOSTNAME ip route list dev lo table main"
	rlRun "vrun $C_HOSTNAME ip route list dev lo table main | sed -n '3,$'p | grep -w lo" "1"
	rlRun "vrun $C_HOSTNAME ip route list table local dev lo"
	rlRun "vrun $C_HOSTNAME ip route list table local dev lo | sed -n '3,$'p | grep -q \"broadcast 127.0.0.0.*proto kernel.*scope link\""
	rlRun "vrun $C_HOSTNAME ip route list table local dev lo | sed -n '3,$'p | grep -q \"local 127.0.0.0.*proto kernel.*scope host\""
	rlRun "vrun $C_HOSTNAME ip route list table local dev lo | sed -n '3,$'p | grep -q \"local 127.0.0.1.*proto kernel.*scope host\""
	rlRun "vrun $C_HOSTNAME ip route list table local dev lo | sed -n '3,$'p | grep -q \"broadcast 127.255.255.255.*proto kernel.*scope link\""

	rlRun "vrun $C_HOSTNAME ip route list table main dev $R_L_IF1"
	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF1"
	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF1 | sed -n '3,$'p | grep -q \"default via ${R_R_IP1[4]}\""
	local networkv4_if1=`ipcalc -4 -n ${R_L_IP1[4]}/24 | awk -F= '{print $2}'`
	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF1 | sed -n '3,$'p | grep -q \"$networkv4_if1/24.*proto kernel.*scope link.*src ${R_L_IP1[4]}\""
	local broadcastv4_if1=`ipcalc -4 -b ${R_L_IP1[4]}/24 | awk -F= '{print $2}'`

	rlRun "vrun $C_HOSTNAME ip route list table local dev $R_L_IF1"
	rlRun "vrun $C_HOSTNAME ip route list table local dev $R_L_IF1 | sed -n '3,$'p | grep -q \"broadcast $networkv4_if1.*proto kernel.*scope link.*src ${R_L_IP1[4]}\""
	rlRun "vrun $C_HOSTNAME ip route list table local dev $R_L_IF1 | sed -n '3,$'p | grep -q \"broadcast $broadcastv4_if1.*proto kernel.*scope link.*src ${R_L_IP1[4]}\""
	rlRun "vrun $C_HOSTNAME ip route list table local dev $R_L_IF1 | sed -n '3,$'p | grep -q \"local ${R_L_IP1[4]}.*proto kernel.*scope host.*src ${R_L_IP1[4]}\""


	#ipv6
	rlLog "[Log] default v6"

	rlRun "vrun $C_HOSTNAME ip -6 route list dev lo"
	rlRun "vrun $C_HOSTNAME ip -6 route list dev lo | sed -n '3,$'p | grep -w -q lo" "1"
	rlRun "vrun $C_HOSTNAME ip -6 route list table main dev lo"
	rlRun "vrun $C_HOSTNAME ip -6 route list table main dev lo | sed -n '3,$'p | grep -w -q lo" "1"

	rlRun "vrun $C_HOSTNAME ip -6 route list table local dev lo"
	rlRun "vrun $C_HOSTNAME ip -6 route list table local dev lo | sed -n '3,$'p | grep -q \"local ::1\""
	rlRun "vrun $C_HOSTNAME ip -6 route list table local | sed -n '3,$'p | grep -q \"local ${R_L_IP1[6]}\""

	rlRun "vrun $C_HOSTNAME ip -6 route list dev $R_L_IF1"
	rlRun "vrun $C_HOSTNAME ip -6 route list dev $R_L_IF1 | sed -n '3,$'p | grep -q \"default via ${R_R_IP1[6]}\""

	rlRun "vrun $C_HOSTNAME ip -6 route list table local dev $R_L_IF1"
	rlRun "vrun $C_HOSTNAME ip -6 route list table local dev $R_L_IF1 | sed -n '3,$'p | grep -q \"ff00::/8\""

rlPhaseEnd
}

route_prefix_test()
{
rlPhaseStartTest "Route_Prefix $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	[ x"$ROUTE_MODE" != x"local" ] && { rlLog "ROUTE_MODE:$ROUTE_MODE not local, return";return; }

	#ipv4
	rlLog "[Log] ipv4 prefix test"
	rlRun "vrun $C_HOSTNAME ip route get 10.20.1.1 | sed -n '3,$'p | grep $R_L_IF1"
	rlRun "vrun $C_HOSTNAME ip route add 10.20.0.0/16 via ${R_R_IP2[4]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route get 10.20.1.1 | sed -n '3,$'p | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF2 | grep 10.20.0.0/16"
	rlRun "vrun $C_HOSTNAME ip route list root 10.20.0.0/8 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route list root 10.20.0.0/16 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route list root 10.20.0.0/17 | grep $R_L_IF2" "1"
	rlRun "vrun $C_HOSTNAME ip route list match 10.20.0.0/17 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route list match 10.20.0.0/16 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route list match 10.20.0.0/15 | grep $R_L_IF2" "1"
	rlRun "vrun $C_HOSTNAME ip route list exact 10.20.0.0/16 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route list exact 10.20.0.0/17 | grep $R_L_IF2" "1"
	rlRun "vrun $C_HOSTNAME ip route list exact 10.20.0.0/15 | grep $R_L_IF2" "1"

	rlRun "vrun $C_HOSTNAME ip route flush root 10.20.0.0/8 dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route flush root 10.20.0.0/8 dev $R_L_IF2" "0-255"
	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF2 | grep 10.20.0.0/16" "1"
	rlRun "vrun $C_HOSTNAME ip route get 10.20.1.1 | sed -n '3,$'p | grep $R_L_IF1"
	rlRun "vrun $C_HOSTNAME ip route add 10.20.0.0/16 via ${R_R_IP2[4]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route add 10.20.0.0/16 via ${R_R_IP2[4]} dev $R_L_IF2" "0-255"
	rlRun "vrun $C_HOSTNAME ip route get 10.20.1.1 | sed -n '3,$'p | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF2 | grep 10.20.0.0/16"
	rlRun "vrun $C_HOSTNAME ip route flush root 10.20.0.0/17 dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF2 | grep 10.20.0.0/16"

	rlRun "vrun $C_HOSTNAME ip route flush match 10.20.0.0/8 dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF2 | grep 10.20.0.0/16"
	rlRun "vrun $C_HOSTNAME ip route flush match 10.20.0.0/17 dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route flush match 10.20.0.0/17 dev $R_L_IF2" "0-255"
	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF2 | grep 10.20.0.0/16" "1"

	rlRun "vrun $C_HOSTNAME ip route add 10.20.0.0/16 via ${R_R_IP2[4]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route add 10.20.0.0/16 via ${R_R_IP2[4]} dev $R_L_IF2" "0-255"
	rlRun "vrun $C_HOSTNAME ip route get 10.20.1.1 | sed -n '3,$'p | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route flush exact 10.20.0.0/18 dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF2 | grep 10.20.0.0/16"
	rlRun "vrun $C_HOSTNAME ip route flush exact 10.20.0.0/16 dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF2 | grep 10.20.0.0/16" "1"
	rlRun "vrun $C_HOSTNAME ip route flush exact 10.20.0.0/16 dev $R_L_IF2" "0-255"

	rlRun "vrun $C_HOSTNAME ip route add 10.20.0.0/16 via ${R_R_IP2[4]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route del 10.20.0.0/16 via ${R_R_IP2[4]} dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF2 | grep 10.20.0.0/16" "1"
	rlRun "vrun $C_HOSTNAME ip route del 10.20.0.0/16 via ${R_R_IP2[4]} dev $R_L_IF2" "0-255"

	#ipv6
	rlLog "[Log] ipv6 prefix test"
	rlRun "vrun $C_HOSTNAME ip -6 route get 2590::1 | grep $R_L_IF1"
	rlRun "vrun $C_HOSTNAME ip -6 route add 2590::/32 dev $R_L_IF2 via ${R_R_IP2[6]}"
	rlRun "vrun $C_HOSTNAME ip -6 route get 2590::1 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route list dev $R_L_IF2 | grep 2590::/32"
	rlRun "vrun $C_HOSTNAME ip -6 route list root 2590::/31 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route list root 2590::/32 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route list root 2590::/33 | grep $R_L_IF2" "1"
	rlRun "vrun $C_HOSTNAME ip -6 route list match 2590::/31 | grep $R_L_IF2" "1"
	rlRun "vrun $C_HOSTNAME ip -6 route list match 2590::/32 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route list match 2590::/33 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route list exact 2590::/31 | grep $R_L_IF2" "1"
	rlRun "vrun $C_HOSTNAME ip -6 route list exact 2590::/32 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route list exact 2590::/33 | grep $R_L_IF2" "1"

	rlRun "vrun $C_HOSTNAME ip -6 route flush root 2590::/33 dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route list dev $R_L_IF2 | grep 2590::/32"
	rlRun "vrun $C_HOSTNAME ip -6 route flush root 2590::/32 dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route list dev $R_L_IF2 | grep 2590::/32" "1"
	rlRun "vrun $C_HOSTNAME ip -6 route flush root 2590::/32 dev $R_L_IF2" "0-255"

	rlRun "vrun $C_HOSTNAME ip -6 route add 2590::/32 dev $R_L_IF2 via ${R_R_IP2[6]}"
	rlRun "vrun $C_HOSTNAME ip -6 route add 2590::/32 dev $R_L_IF2 via ${R_R_IP2[6]}" "0-255"
	rlRun "vrun $C_HOSTNAME ip -6 route get 2590::1 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route flush match 2590::/31 dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route list | grep 2590::/32"
	rlRun "vrun $C_HOSTNAME ip -6 route flush match 2590::/32 dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route list | grep 2590::/32" "1"
	rlRun "vrun $C_HOSTNAME ip -6 route flush match 2590::/32 dev $R_L_IF2" "0-255"

	rlRun "vrun $C_HOSTNAME ip -6 route add 2590::/32 dev $R_L_IF2 via ${R_R_IP2[6]}"
	rlRun "vrun $C_HOSTNAME ip -6 route add 2590::/32 dev $R_L_IF2 via ${R_R_IP2[6]}" "0-255"
	rlRun "vrun $C_HOSTNAME ip -6 route get 2590::1 | grep $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route flush exact 2590::/31 dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route list | grep 2590::/32"
	rlRun "vrun $C_HOSTNAME ip -6 route flush exact 2590::/32 dev $R_L_IF2"
	rlRun "vrun $C_HOSTNAME ip -6 route list | grep 2590::/32" "1"
	rlRun "vrun $C_HOSTNAME ip -6 route flush exact 2590::/32 dev $R_L_IF2" "0-255"

	rlRun "vrun $C_HOSTNAME ip -6 route add 2590::/32 dev $R_L_IF2 via ${R_R_IP2[6]}"
	rlRun "vrun $C_HOSTNAME ip -6 route del 2590::/32 dev $R_L_IF2 via ${R_R_IP2[6]}"
	rlRun "vrun $C_HOSTNAME ip -6 route list | grep 2590::/32" "1"
	rlRun "vrun $C_HOSTNAME ip -6 route del 2590::/32 dev $R_L_IF2 via ${R_R_IP2[6]}" "0-255"

rlPhaseEnd
}
route_selector_test()
{
rlPhaseStartTest "Route_Selector $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	[ x"$ROUTE_MODE" != x"local" ] && { rlLog "ROUTE_MODE:$ROUTE_MODE not local, return";return; }

	#ipv4&ipv6 table

	local dst_ip1[4]=172.111.1.1
	local dst_ip2[4]=172.111.2.1
	local dst_ip1[6]=3010::1
	local dst_ip2[6]=3010::2
	for version in 4 6
	do
		rlLog "[Log] ipv$version table test"
		rlRun "vrun $C_HOSTNAME ip -$version route list table -1" "0-255"
		rlRun "vrun $C_HOSTNAME ip -$version route list table 0"
		rlRun "vrun $C_HOSTNAME ip -$version route list table 11" "0-255"
		rlRun "vrun $C_HOSTNAME ip -$version route list table 256" "0-255"
		rlRun "vrun $C_HOSTNAME ip -$version route list table 1111" "0-255"

		rlRun "vrun $C_HOSTNAME ip -$version route list table local | grep ${dst_ip1[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table local"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table local" "0-255"
		if [ x"$TEST_TYPE" == x"netns" ] && [ x"$version" == x"4" ]
		then
			rlRun "vrun $C_HOSTNAME nl-fib-lookup -t 255 ${dst_ip1[$version]}"
		fi
		rlRun "vrun $C_HOSTNAME ip -$version route list table local | grep ${dst_ip1[$version]}"
		rlRun "vrun $C_HOSTNAME ip -$version route list table main | grep ${dst_ip1[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route list table all | grep ${dst_ip1[$version]}"
		rlRun "vrun $C_HOSTNAME ip -$version route get ${dst_ip1[$version]}| sed -n '3,$'p | grep ${dst_ip1[$version]}"
		rlRun "vrun $C_HOSTNAME ip -$version route get ${dst_ip1[$version]} oif $R_L_IF2 | sed -n '3,$'p | grep \"${dst_ip1[$version]} .*$R_L_IF2\""
		rlRun "vrun $C_HOSTNAME ip -$version route get ${dst_ip1[$version]} oif $R_L_IF1 | sed -n '3,$'p | grep \"${dst_ip1[$version]} .*$R_L_IF2\"" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table local"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table local" "0-255"
		if [ x"$TEST_TYPE" == x"netns" ] && [ x"$version" == x"4" ]
		then
			rlRun "vrun $C_HOSTNAME nl-fib-lookup -t 255 ${dst_ip1[$version]}"
		fi
		rlRun "vrun $C_HOSTNAME ip -$version route list table local | grep ${dst_ip1[$version]} " "1"
		rlRun "vrun $C_HOSTNAME ip -$version route list table all | grep ${dst_ip1[$version]} " "1"

		rlRun "vrun $C_HOSTNAME ip -$version route list table 111 | grep ${dst_ip2[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip2[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 111"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip2[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 111" "0-255"
		if [ x"$TEST_TYPE" == x"netns" ] && [ x"$version" == x"4" ]
		then
			rlRun "vrun $C_HOSTNAME nl-fib-lookup -t 111 ${dst_ip1[$version]}"
		fi
		rlRun "vrun $C_HOSTNAME ip -$version route list table 111 | grep ${dst_ip2[$version]}"
		rlRun "vrun $C_HOSTNAME ip -$version route list table local| grep ${dst_ip2[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route list table main | grep ${dst_ip2[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route list table all | grep ${dst_ip2[$version]}"
		rlRun "vrun $C_HOSTNAME ip -$version route get ${dst_ip2[$version]} | sed -n '3,$'p | grep \"${dst_ip2[$version]} .*$R_L_IF1\""
		rlRun "vrun $C_HOSTNAME ip -$version route get ${dst_ip2[$version]} oif $R_L_IF1 | sed -n '3,$'p | grep \"${dst_ip2[$version]} .*$R_L_IF1\""
		if [ x"$version" == x"4" ]
		then
			rlRun "vrun $C_HOSTNAME ip -$version route get ${dst_ip2[$version]} oif $R_L_IF2 | sed -n '3,$'p | grep \"${dst_ip2[$version]} .*$R_L_IF2\""
		else
			rlRun "vrun $C_HOSTNAME ip -$version route get ${dst_ip2[$version]} oif $R_L_IF2 | sed -n '3,$'p | grep \"${dst_ip2[$version]} .*$R_L_IF2\"" "1"
		fi
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip2[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 111"
		rlRun "vrun $C_HOSTNAME ip -$version route list table 111 | grep ${dst_ip2[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip2[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 111" "0-255"
		rlRun "vrun $C_HOSTNAME ip -$version route list table all | grep ${dst_ip2[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip2[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 111"
		rlRun "vrun $C_HOSTNAME ip -$version route list table 111 | grep ${dst_ip2[$version]}"
		rlRun "vrun $C_HOSTNAME ip -$version route flush table 111"
		rlRun "vrun $C_HOSTNAME ip -$version route list table 111 | grep ${dst_ip2[$version]}" "1"

		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table local"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table local" "0-255"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 111"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 111" "0-255"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table local"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 111"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table local" "0-255"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} table 111" "0-255"
	done

	#ipv4&ipv6 proto
	for version in 4 6
	do
		rlLog "[Log] ip$version proto test"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto kernel"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto boot"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto static"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto -1" "255"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto 256" "255"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto 0"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto 111"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto all"

		rlRun "vrun $C_HOSTNAME ip -$version route list proto static | grep ${dst_ip1[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} proto static"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} proto static" "0-255"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto static | grep ${dst_ip1[$version]}"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto boot | grep ${dst_ip1[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto all | grep ${dst_ip1[$version]}"
		rlRun "vrun $C_HOSTNAME ip -$version route get ${dst_ip1[$version]} | sed -n '3,$'p | grep $R_L_IF2"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} proto static"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto static | grep ${dst_ip1[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} proto static" "0-255"

		rlRun "vrun $C_HOSTNAME ip -$version route list proto 111 | grep ${dst_ip2[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip2[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} proto 111"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip2[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} proto 111" "0-255"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto 111 | grep ${dst_ip2[$version]}"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto all | grep ${dst_ip2[$version]}"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto static | grep ${dst_ip2[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route get ${dst_ip2[$version]} | sed -n '3,$'p | grep $R_L_IF2"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip2[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} proto 111"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto 111 | grep ${dst_ip2[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip2[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} proto 111" "0-255"

		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip2[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} proto 111"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip2[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} proto static" "2"
		rlRun "vrun $C_HOSTNAME ip -$version route flush proto 111"
		rlRun "vrun $C_HOSTNAME ip -$version route list proto 111 | grep ${dst_ip2[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route flush proto 111" "0-255"
	done

	#ipv4$ipv6 type
	for version in 4
	do
		rlLog "[Log] ip$version type test"
		for type in unicast multicast broadcast local
		do
			rlRun "vrun $C_HOSTNAME ip -$version route list type $type table all"

			rlRun "vrun $C_HOSTNAME ip -$version route list type $type table main | grep ${dst_ip1[$version]}" "1"
			rlRun "vrun $C_HOSTNAME ip -$version route add $type ${dst_ip1[$version]} dev $R_L_IF2 table main"
			rlRun "vrun $C_HOSTNAME ip -$version route add $type ${dst_ip1[$version]} dev $R_L_IF2 table main" "0-255"
			rlRun "sleep 2"
			rlRun "vrun $C_HOSTNAME ip -$version route list type $type table main | grep ${dst_ip1[$version]}"
			[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -$version route list type $type table main"
			[ x"$type" != x"local" ] && \
				rlRun "vrun $C_HOSTNAME ip -$version route get ${dst_ip1[$version]} | sed -n '3,$'p | grep $R_L_IF2" || \
				rlRun "vrun $C_HOSTNAME ip -$version route get ${dst_ip1[$version]} | sed -n '3,$'p | grep lo"
			rlRun "vrun $C_HOSTNAME ip -$version route del $type ${dst_ip1[$version]} dev $R_L_IF2 table main"
			rlRun "vrun $C_HOSTNAME ip -$version route del $type ${dst_ip1[$version]} dev $R_L_IF2 table main" "0-255"

			rlRun "vrun $C_HOSTNAME ip -$version route add $type ${dst_ip1[$version]} dev $R_L_IF2 table 100"
			rlRun "vrun $C_HOSTNAME ip -$version route add local ${dst_ip1[$version]} dev $R_L_IF2 table 100" "2"
			rlRun "vrun $C_HOSTNAME ip -$version route flush type $type table 100"
			rlRun "vrun $C_HOSTNAME ip -$version route list type $type table 100 | grep ${dst_ip1[$version]}" "1"
			[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -$version route list type $type table 100"
			rlRun "vrun $C_HOSTNAME ip -$version route flush type $type table 100" "0-255"
		done
	done

	#ipv4&ipv6 scope
	for version in 4
	do
		rlLog "[Log] ip$version scope test"

		rlRun "vrun $C_HOSTNAME ip -$version route list scope 0"
		rlRun "vrun $C_HOSTNAME ip -$version route list scope -1" "255"
		rlRun "vrun $C_HOSTNAME ip -$version route list scope 256" "255"
		rlRun "vrun $C_HOSTNAME ip -$version route list scope 1111" "255"
		rlRun "vrun $C_HOSTNAME ip -$version route list scope 111"
		rlRun "vrun $C_HOSTNAME ip -$version route list scope link"
		rlRun "vrun $C_HOSTNAME ip -$version route list scope host"
		rlRun "vrun $C_HOSTNAME ip -$version route list scope global"

		rlRun "vrun $C_HOSTNAME ip -$version route list scope 111 | grep ${dst_ip1[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} scope 111"
		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} scope 111" "0-255"
		if [ x"$TEST_TYPE" == x"netns" ] && [ x"$version" == x"4" ]
		then
			rlRun "vrun $C_HOSTNAME nl-fib-lookup -s 111 ${dst_ip1[$version]}"
		fi
		rlRun "vrun $C_HOSTNAME ip -$version route list scope 111 | grep ${dst_ip1[$version]}"
		rlRun "vrun $C_HOSTNAME ip -$version route get ${dst_ip1[$version]} | grep $R_L_IF2"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} scope 111"
		if [ x"$TEST_TYPE" == x"netns" ] && [ x"$version" == x"4" ]
		then
			rlRun "vrun $C_HOSTNAME nl-fib-lookup -s 111 ${dst_ip1[$version]}"
		fi
		rlRun "vrun $C_HOSTNAME ip -$version route list scope 111 | grep ${dst_ip1[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route del ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} scope 111" "0-255"

		rlRun "vrun $C_HOSTNAME ip -$version route add ${dst_ip1[$version]} dev $R_L_IF2 via ${R_R_IP2[$version]} scope global table 120"
		rlRun "vrun $C_HOSTNAME ip -$version route list scope global table 120 | grep ${dst_ip1[$version]}"
		rlRun "vrun $C_HOSTNAME ip -$version route list scope global table 120 | grep ${dst_ip1[$version]}" "0-255"
		rlRun "vrun $C_HOSTNAME ip -$version route flush scope global table 120"
		rlRun "vrun $C_HOSTNAME ip -$version route list scope global table 120 | grep ${dst_ip1[$version]}" "1"
		rlRun "vrun $C_HOSTNAME ip -$version route flush scope global table 120" "0-255"
	done

	if [ x"$TEST_TYPE" == x"netns" ] && [ x"$version" == x"4" ]
	then
		rlRun "vrun $C_HOSTNAME nl-fib-lookup -f 1 ${dst_ip1[$version]}"
	fi

rlPhaseEnd
}

route_options_test()
{
rlPhaseStartTest "Route_Options $TEST_TYPE $TEST_TOPO $ROUTE_MODE"

	[ x"$ROUTE_MODE" != x"local" ] && { rlLog "ROUTE_MODE:$ROUTE_MODE not local, return";return; }
	#ipv4
	# to cover https://bugzilla.redhat.com/show_bug.cgi?id=1475642
	rlLog "[Log] metrics v4"

	rlRun "vrun $C_HOSTNAME ip rule add to 1.1.1.0/24 table 1234"
	for feature in mtu advmss reordering window cwnd initcwnd rto_min hoplimit initrwnd ssthresh
	do
		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $feature 28 table 1234"
		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $feature 28 table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route show table 1234 | grep \"$feature.*28\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route show table 1234"
		rlRun "vrun $C_HOSTNAME ip route get 1.1.1.1 | grep \"$feature.*28\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route show table 1234"
		rlRun "vrun $C_HOSTNAME ip route change 1.1.1.0/24 dev $R_L_IF1 $feature 27 table 1234"
		rlRun "vrun $C_HOSTNAME ip route change 1.1.1.0/24 dev $R_L_IF1 $feature 27 table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route replace 1.1.1.0/24 dev $R_L_IF1 $feature 26 table 1234"
		rlRun "vrun $C_HOSTNAME ip route replace 1.1.1.0/24 dev $R_L_IF1 $feature 26 table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route show table 1234 | grep \"$feature.*26\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route show table 1234"

		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $feature 29 table 1234"
		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $feature 29 table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $feature 30 table 1234"
		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $feature 30 table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route list table 1234 | grep \"$feature.*30\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route list table 1234"
		rlRun "vrun $C_HOSTNAME ip route get 1.1.1.1"

		rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 $feature 29 table 1234"

		rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF1 table 1234 | sed -n '3,$'p | grep \"$feature.*29\"" "1"

		if ! uname -r | grep "^2\.6"
		then
		rlRun "vrun $C_HOSTNAME \"ip route save table 1234 > /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip route flush table 1234"
		rlRun "vrun $C_HOSTNAME ip route list table 1234 | grep \"$feature.*30\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $C_HOSTNAME ip route list table 1234"
		rlRun "vrun $C_HOSTNAME \"ip route restore table 1234 < /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip route list table 1234 | grep \"$feature.*30\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route list table 1234"
		rlRun "vrun $C_HOSTNAME ip route get 1.1.1.1"
		fi

		rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 $feature 26 table 1234"
		rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 $feature 30 table 1234"
		rlRun "vrun $C_HOSTNAME ip route flush table 1234"
	done

	for feature in rtt rttvar
	do
		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $feature 10s table 1234"
		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $feature 10s table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route show table 1234 | grep \"$feature.*10s\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route show table 1234"
		rlRun "vrun $C_HOSTNAME ip route get 1.1.1.1 | grep \"$feature.*10s\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route get 1.1.1.1"

		rlRun "vrun $C_HOSTNAME ip route change 1.1.1.0/24 dev $R_L_IF1 $feature 9s table 1234"
		rlRun "vrun $C_HOSTNAME ip route change 1.1.1.0/24 dev $R_L_IF1 $feature 9s table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route replace 1.1.1.0/24 dev $R_L_IF1 $feature 8s table 1234"
		rlRun "vrun $C_HOSTNAME ip route replace 1.1.1.0/24 dev $R_L_IF1 $feature 8s table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route show table 1234 | grep \"$feature.*8s\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route show table 1234"

		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $feature 11s table 1234"
		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $feature 11s table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $feature 12s table 1234"
		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $feature 12s table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route show table 1234 | grep \"$feature.*12s\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route show table 1234"
		rlRun "vrun $C_HOSTNAME ip route get 1.1.1.1"

		rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 $feature 11s table 1234"
		rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF1 table 1234 | grep \"$feature.*11s\"" "1"
		[ $? -ne 1 ] && rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF1 table 1234"

		if ! uname -r | grep "^2\.6"
		then
		rlRun "vrun $C_HOSTNAME \"ip route save table 1234 > /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip route flush table 1234"
		rlRun "vrun $C_HOSTNAME ip route list table 1234 | grep \"$feature.*12s\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $C_HOSTNAME ip route list table 1234"

		rlRun "vrun $C_HOSTNAME \"ip route restore table 1234 < /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip route list table 1234 | grep \"$feature.*12s\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route list table 1234"
		rlRun "vrun $C_HOSTNAME ip route get 1.1.1.1"
		fi

		rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 $feature 8s table 1234"
		rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 $feature 12s table 1234"
		rlRun "vrun $C_HOSTNAME ip route flush table 1234"
	done

	if vrun $C_HOSTNAME ip route add 2.2.2.0/24 dev $R_L_IF1 quickack 1 congctl dctcp table 1234
	then
		vrun $C_HOSTNAME ip route del 2.2.2.0/24 dev $R_L_IF1 quickack 1 congctl dctcp table 1234
		# quickack
		rlRun "vrun $C_HOSTNAME ip route add 1.1.1.0/24 dev $R_L_IF1 quickack 0 table 1234"
		rlRun "vrun $C_HOSTNAME ip route add 1.1.1.0/24 dev $R_L_IF1 quickack 0 table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route change 1.1.1.0/24 dev $R_L_IF1 quickack 1 table 1234"
		rlRun "vrun $C_HOSTNAME ip route change 1.1.1.0/24 dev $R_L_IF1 quickack 1 table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route show table 1234 | grep \"quickack 1\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route show table 1234"
		rlRun "vrun $C_HOSTNAME ip route get 1.1.1.1 | grep \"quickack 1\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route get 1.1.1.1"

		if ! uname -r | grep "^2\.6"
		then
		rlRun "vrun $C_HOSTNAME \"ip route save table 1234 > /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip route flush table 1234"
		rlRun "vrun $C_HOSTNAME ip route show table 1234 | grep \"quickack 1\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $C_HOSTNAME ip route show table 1234"

		rlRun "vrun $C_HOSTNAME \"ip route restore table 1234 < /tmp/table1234.save \""
		rlRun "vrun $C_HOSTNAME ip route list table 1234 | grep \"quickack 1\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route list table 1234"
		rlRun "vrun $C_HOSTNAME ip route get 1.1.1.1"
		fi

		rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 quickack 1 table 1234"
		rlRun "vrun $C_HOSTNAME ip route flush table 1234"

		# congctl
		rlRun "vrun $C_HOSTNAME ip route add 1.1.1.0/24 dev $R_L_IF1 congctl cubic table 1234"
		rlRun "vrun $C_HOSTNAME ip route add 1.1.1.0/24 dev $R_L_IF1 congctl cubic table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route get 1.1.1.1 | grep \"congctl cubic\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route get 1.1.1.1"
		rlRun "vrun $C_HOSTNAME ip route change 1.1.1.0/24 dev $R_L_IF1 congctl reno table 1234"
		rlRun "vrun $C_HOSTNAME ip route change 1.1.1.0/24 dev $R_L_IF1 congctl reno table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip route list table 1234 | grep \"congctl reno\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route list table 1234"
		rlRun "vrun $C_HOSTNAME ip route replace 1.1.1.0/24 dev $R_L_IF1 congctl dctcp table 1234"
		rlRun "vrun $C_HOSTNAME ip route get 1.1.1.1"

		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 congctl cubic table 1234"
		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 congctl reno table 1234"

		rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 congctl cubic table 1234"

		rlRun "vrun $C_HOSTNAME ip route list table 1234 | grep \"congctl cubic\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $C_HOSTNAME ip route list table 1234"

		if ! uname -r | grep "2\.6"
		then
		rlRun "vrun $C_HOSTNAME \"ip route save table 1234 > /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip route flush table 1234"
		rlRun "vrun $C_HOSTNAME ip route list table 1234 | grep \"congctl\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $C_HOSTNAME ip route list table 1234"

		rlRun "vrun $C_HOSTNAME \"ip route restore table 1234 < /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip route list table 1234 | grep \"congctl\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip route list table 1234"
		fi

		rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 congctl reno table 1234"
		rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 congctl dctcp table 1234"
		rlRun "vrun $C_HOSTNAME ip route flush table 1234"
	fi

	rlRun "vrun $C_HOSTNAME ip rule del to 1.1.1.0/24 table 1234"

	if vrun $C_HOSTNAME ip route add 2.2.2.0/24 dev $R_L_IF1 quickack 1 congctl dctcp features ecn table 1234
	then
		vrun $C_HOSTNAME ip route del 2.2.2.0/24 dev $R_L_IF1 quickack 1 congctl dctcp features ecn table 1234
		para0="features ecn rtt 10s congctl cubic quickack 1 rttvar 10s"
		para1="features ecn rtt 20s congctl reno quickack 1 rttvar 20s"
		para2="features ecn rtt 30s congctl dctcp quickack 1 rttvar 30s"
	else
		para0=""
		para1=""
		para2=""
	fi
	for feature in mtu advmss reordering window cwnd initcwnd rto_min hoplimit initrwnd
	do
		rlRun "para0=\"$para0 $feature 28\""
		rlRun "para1=\"$para1 $feature 29\""
		rlRun "para2=\"$para2 $feature 30\""
	done
	rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $para0"
	rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $para0" "0-255"
	rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $para1"
	rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $para1" "0-255"
	rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $para2"
	rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 $para2" "0-255"

	rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 $para1"

	rlRun "vrun $C_HOSTNAME ip route list dev $R_L_IF1 | sed -n '3,$'p | grep \"mtu 29\"" "1"

	rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 $para0"
	rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 $para2"
	rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 $para2" "0-255"

	# route options for ipv6
	rlLog "route options for ipv6"
	rlRun "vrun $C_HOSTNAME ip -6 rule add to 1111::/64 table 1234"
	for feature in mtu advmss reordering window cwnd initcwnd rto_min hoplimit initrwnd ssthresh
	do
		rlRun "vrun $C_HOSTNAME ip -6 route append 1111::/64 dev $R_L_IF1 $feature 28 table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route append 1111::/64 dev $R_L_IF1 $feature 28 table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | grep \"$feature.*28\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route show table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route get 1111::1 | grep \"$feature.*28\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route show table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route change 1111::/64 dev $R_L_IF1 $feature 27 table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route change 1111::/64 dev $R_L_IF1 $feature 27 table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip -6 route replace 1111::/64 dev $R_L_IF1 $feature 26 table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route replace 1111::/64 dev $R_L_IF1 $feature 26 table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | grep \"$feature.*26\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route show table 1234"

		if ! uname -r | grep "2\.6"
		then
		rlRun "vrun $C_HOSTNAME \"ip -6 route save table 1234 > /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip -6 route flush table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route list table 1234 | grep \"$feature.*26\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route list table 1234"
		rlRun "vrun $C_HOSTNAME \"ip -6 route restore table 1234 < /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip -6 route list table 1234 | grep \"$feature.*26\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route list table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route get 1111::1"
		fi

		rlRun "vrun $C_HOSTNAME ip -6 route del 1111::/64 dev $R_L_IF1 $feature 26 table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route flush table 1234"
	done

	for feature in rtt rttvar
	do
		rlRun "vrun $C_HOSTNAME ip -6 route append 1111::/64 dev $R_L_IF1 $feature 10s table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route append 1111::/64 dev $R_L_IF1 $feature 10s table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | grep \"$feature.*10s\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route show table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route get 1111::1 | grep \"$feature.*10s\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route get 1111::1"

		rlRun "vrun $C_HOSTNAME ip -6 route change 1111::/64 dev $R_L_IF1 $feature 9s table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route change 1111::/64 dev $R_L_IF1 $feature 9s table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip -6 route replace 1111::/64 dev $R_L_IF1 $feature 8s table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route replace 1111::/64 dev $R_L_IF1 $feature 8s table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | grep \"$feature.*8s\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route show table 1234"

		if ! uname -r | grep "2\.6"
		then
		rlRun "vrun $C_HOSTNAME \"ip -6 route save table 1234 > /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip -6 route flush table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route list table 1234 | grep \"$feature.*8s\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route list table 1234"

		rlRun "vrun $C_HOSTNAME \"ip -6 route restore table 1234 < /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip -6 route list table 1234 | grep \"$feature.*8s\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route list table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route get 1111::1"
		fi

		rlRun "vrun $C_HOSTNAME ip -6 route del 1111::/64 dev $R_L_IF1 $feature 8s table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route flush table 1234"
	done

	if vrun $C_HOSTNAME ip -6 route add 2222::/64 dev $R_L_IF1 quickack 1 congctl dctcp table 1234
	then
		vrun $C_HOSTNAME ip -6 route del 2222::/64 dev $R_L_IF1 quickack 1 congctl dctcp table 1234
		# quickack
		rlRun "vrun $C_HOSTNAME ip -6 route add 1111::/64 dev $R_L_IF1 quickack 0 table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route add 1111::/64 dev $R_L_IF1 quickack 0 table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip -6 route change 1111::/64 dev $R_L_IF1 quickack 1 table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route change 1111::/64 dev $R_L_IF1 quickack 1 table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | grep \"quickack 1\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route show table 1234"
		rlRun "vrun $C_HOSTNAME ip route get 1111::1 | grep \"quickack 1\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route get 1111::1"

		if ! uname -r | grep "2\.6"
		then
		rlRun "vrun $C_HOSTNAME \"ip -6 route save table 1234 > /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip -6 route flush table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | grep \"quickack 1\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route show table 1234"

		rlRun "vrun $C_HOSTNAME \"ip -6 route restore table 1234 < /tmp/table1234.save \""
		rlRun "vrun $C_HOSTNAME ip -6 route list table 1234 | grep \"quickack 1\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route list table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route get 1111::1"
		fi

		rlRun "vrun $C_HOSTNAME ip -6 route del 1111::/64 dev $R_L_IF1 quickack 1 table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route flush table 1234"

		# congctl
		rlRun "vrun $C_HOSTNAME ip -6 route add 1111::/64 dev $R_L_IF1 congctl cubic table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route add 1111::/64 dev $R_L_IF1 congctl cubic table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip -6 route get 1111::1 | grep \"congctl cubic\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route get 1111::1"
		rlRun "vrun $C_HOSTNAME ip -6 route change 1111::/64 dev $R_L_IF1 congctl reno table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route change 1111::/64 dev $R_L_IF1 congctl reno table 1234" "0-255"
		rlRun "vrun $C_HOSTNAME ip -6 route list table 1234 | grep \"congctl reno\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route list table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route replace 1111::/64 dev $R_L_IF1 congctl dctcp table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route get 1111::1"

		if ! uname -r | grep "2\.6"
		then
		rlRun "vrun $C_HOSTNAME \"ip -6 route save table 1234 > /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip -6 route flush table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route list table 1234 | grep \"congctl\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $C_HOSTNAME ip route list table 1234"

		rlRun "vrun $C_HOSTNAME \"ip -6 route restore table 1234 < /tmp/table1234.save\""
		rlRun "vrun $C_HOSTNAME ip -6 route list table 1234 | grep \"congctl\""
		[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route list table 1234"
		fi

		rlRun "vrun $C_HOSTNAME ip -6 route del 1111::/64 dev $R_L_IF1 congctl dctcp table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route flush table 1234"
	fi

	if vrun $C_HOSTNAME ip route add 2222::/64 dev $R_L_IF1 quickack 1 congctl dctcp features ecn table 1234
	then
		vrun $C_HOSTNAME ip route del 2222::/64 dev $R_L_IF1 quickack 1 congctl dctcp features ecn table 1234
		para0="features ecn rtt 10s congctl cubic quickack 1 rttvar 10s"
		para1="features ecn rtt 20s congctl reno quickack 1 rttvar 20s"
		para2="features ecn rtt 30s congctl dctcp quickack 1 rttvar 30s"
	else
		para0=""
		para1=""
		para2=""
	fi
	for feature in mtu advmss reordering window cwnd initcwnd rto_min hoplimit initrwnd
	do
		rlRun "para0=\"$para0 $feature 28\""
		rlRun "para1=\"$para1 $feature 29\""
		rlRun "para2=\"$para2 $feature 30\""
	done
	rlRun "vrun $C_HOSTNAME ip -6 route append 1111::/64 dev $R_L_IF1 $para0 table 1234"
	rlRun "vrun $C_HOSTNAME ip -6 route append 1111::/64 dev $R_L_IF1 $para0 table 1234" "0-255"
	rlRun "vrun $C_HOSTNAME ip -6 route change 1111::/64 dev $R_L_IF1 $para1 table 1234"
	rlRun "vrun $C_HOSTNAME ip -6 route change 1111::/64 dev $R_L_IF1 $para1 table 1234" "0-255"
	rlRun "vrun $C_HOSTNAME ip -6 route replace 1111::/64 dev $R_L_IF1 $para2 table 1234"
	rlRun "vrun $C_HOSTNAME ip -6 route replace 1111::/64 dev $R_L_IF1 $para2 table 1234" "0-255"


	rlRun "vrun $C_HOSTNAME ip -6 route get 1111::1"
	rlRun "vrun $C_HOSTNAME ip -6 route show table 1234"

	if ! uname -r | grep "2\.6"
	then
	rlRun "vrun $C_HOSTNAME \"ip -6 route save table 1234 > /tmp/table1234.save\""
	rlRun "vrun $C_HOSTNAME ip -6 route flush table 1234"
	rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | grep mtu" "1"
	[ $? -ne 1 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route show table 1234"

	rlRun "vrun $C_HOSTNAME \"ip -6 route restore table 1234 < /tmp/table1234.save\""
	rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | grep mtu"
	[ $? -ne 0 ] && rlRun -l "vrun $C_HOSTNAME ip -6 route show table 1234"
	fi

	rlRun "vrun $C_HOSTNAME ip -6 route del 1111::/64 dev $R_L_IF1 $para2 table 1234"
	rlRun "vrun $C_HOSTNAME ip -6 route del 1111::/64 dev $R_L_IF1 $para2 table 1234" "0-255"
	rlRun "vrun $C_HOSTNAME ip -6 route flush table 1234"

	rlRun "vrun $C_HOSTNAME ip -6 rule del to 1111::/64 table 1234"

	# bug https://bugzilla.redhat.com/show_bug.cgi?id=1500463
	rlLog "ipv6 pref testing"
	for pref in high low medium
	do
		rlRun "vrun $C_HOSTNAME ip -6 route add 1111::/64 dev $R_L_IF1 pref $pref"
		rlRun "vrun $C_HOSTNAME ip -6 route add 1111::/64 dev $R_L_IF1 pref $pref" "0-255"
		rlRun "vrun $C_HOSTNAME ip -6 route list | grep \"1111::/64.*pref $pref\""
		rlRun "vrun $C_HOSTNAME ip -6 route list dev $R_L_IF1 | grep \"1111::/64.*pref $pref\""
		rlRun "vrun $C_HOSTNAME ip -6 route get 1111::1 | grep \"pref $pref\""
		rlRun "vrun $C_HOSTNAME ip -6 route del 1111::/64 dev $R_L_IF1 pref $pref"
		rlRun "vrun $C_HOSTNAME ip -6 route del 1111::/64 dev $R_L_IF1 pref $pref" "0-255"
		rlRun "vrun $C_HOSTNAME ip -6 route list | grep \"1111::/64.*pref $pref\"" "1"
	done

	# bug https://bugzilla.redhat.com/show_bug.cgi?id=1526442
	if vrun $C_HOSTNAME ip route add 1.1.1.0/24 dev $R_L_IF1 features ecn congctl dctcp table 1234
	then
		rlRun "vrun $C_HOSTNAME ip route show table 1234 | sed -n '3,$'p | grep \"1.1.1.0/24.*features ecn congctl dctcp\""

		rlRun "vrun $C_HOSTNAME ip -6 route add 1111::/64 dev $R_L_IF1 features ecn congctl dctcp table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | sed -n '3,$'p | grep \"1111::/64.*features ecn congctl dctcp\""

		rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 features ecn congctl dctcp table 1234"
		rlRun "vrun $C_HOSTNAME ip route show table 1234 | sed -n '3,$'p | grep \"1.1.1.0/24.*features ecn congctl dctcp\"" "1"

		rlRun "vrun $C_HOSTNAME ip -6 route del 1111::/64 dev $R_L_IF1 features ecn congctl dctcp table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | sed -n '3,$'p | grep \"1111::/64.*features ecn congctl dctcp\"" "1"

		rlRun "vrun $C_HOSTNAME ip route append 1.1.1.0/24 dev $R_L_IF1 features ecn congctl dctcp table 1234"
		rlRun "vrun $C_HOSTNAME ip route show table 1234 | sed -n '3,$'p | grep \"1.1.1.0/24.*features ecn congctl dctcp\""

		rlRun "vrun $C_HOSTNAME ip -6 route append 1111::/64 dev $R_L_IF1 features ecn congctl dctcp table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | sed -n '3,$'p | grep \"1111::/64.*features ecn congctl dctcp\""

		rlRun "vrun $C_HOSTNAME ip route flush table 1234"
		rlRun "vrun $C_HOSTNAME ip route show table 1234 | sed -n '3,$'p | grep \"1.1.1.0/24.*features ecn congctl dctcp\"" "1"

		rlRun "vrun $C_HOSTNAME ip -6 route flush table 1234"
		rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | sed -n '3,$'p | grep \"1111::/64.*features ecn congctl dctcp\"" "1"

		for add_cmd in change replace
		do
			for del_cmd in del flush
			do
				rlRun "vrun $C_HOSTNAME ip route add 1.1.1.0/24 dev $R_L_IF1 table 1234"
				rlRun "vrun $C_HOSTNAME ip route $add_cmd 1.1.1.0/24 dev $R_L_IF1 features ecn congctl dctcp table 1234"
				rlRun "vrun $C_HOSTNAME ip route show table 1234 | sed -n '3,$'p | grep \"1.1.1.0/24.*features ecn congctl dctcp\""

				rlRun "vrun $C_HOSTNAME ip -6 route add 1111::/64 dev $R_L_IF1 table 1234"
				rlRun "vrun $C_HOSTNAME ip -6 route $add_cmd 1111::/64 dev $R_L_IF1 features ecn congctl dctcp table 1234"
				rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | sed -n '3,$'p | grep \"1111::/64.*features ecn congctl dctcp\""

				if [ $del_cmd == "flush" ]
				then
					rlRun "vrun $C_HOSTNAME ip route flush table 1234"
					rlRun "vrun $C_HOSTNAME ip route show table 1234 | sed -n '3,$'p | grep \"1.1.1.0/24.*features ecn congctl dctcp\"" "1"
					rlRun "vrun $C_HOSTNAME ip -6 route flush table 1234"
					rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | sed -n '3,$'p | grep \"1111::/64.*features ecn congctl dctcp\"" "1"
				else
					rlRun "vrun $C_HOSTNAME ip route $del_cmd 1.1.1.0/24 dev $R_L_IF1 features ecn congctl dctcp table 1234"
					rlRun "vrun $C_HOSTNAME ip route show table 1234 | sed -n '3,$'p | grep \"1.1.1.0/24.*features ecn congctl dctcp\"" "1"
					rlRun "vrun $C_HOSTNAME ip -6 route $del_cmd 1111::/64 dev $R_L_IF1 features ecn congctl dctcp table 1234"
					rlRun "vrun $C_HOSTNAME ip -6 route show table 1234 | sed -n '3,$'p | grep \"1111::/64.*features ecn congctl dctcp\"" "1"
				fi
				rlRun "vrun $C_HOSTNAME ip route del 1.1.1.0/24 dev $R_L_IF1 table 1234" "0-255"
				rlRun "vrun $C_HOSTNAME ip -6 route del 1111::/64 dev $R_L_IF1 table 1234" "0-255"
			done
		done
	fi

rlPhaseEnd
}
