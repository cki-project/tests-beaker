#!/bin/bash

TEST_ITEMS_ALL="$TEST_ITEMS_ALL rule_test rule_uidrange_test rule_suppress_test"

rule_test()
{
rlPhaseStartTest "Rule Test $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	local route_host
	[ x"$ROUTE_MODE" == x"local" ] && route_host=$C_HOSTNAME || route_host=$R_HOSTNAME

for version in 4 6
do
	[ x"$version" == x"4" ] && ping=ping || ping=ping6
	#default
	rlRun "vrun $route_host ip -$version rule list | grep \"0:.*from all.*lookup local\""
	rlRun "vrun $route_host ip -$version rule list | grep \"32766:.*from all.*lookup main\""

	#invalid value
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} goto 100" "2,254"
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} table -5" "0-255"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} table -5" "0-255"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} table -5" "0-255"

	#table id
	for tableid in local main 200
	do
		rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} table $tableid"
		rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} table $tableid" "0-255"
		rlRun "vrun $route_host ip -$version rule list | grep \"32765:.*from all to ${S_IP[$version]}.*lookup $tableid\""
		rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} goto 32765"
		rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} goto 32765" "0-255"
		rlRun "vrun $route_host ip -$version rule list | grep \"from all to ${S_IP[$version]}.*goto 32765\""
		rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} table $tableid"
		rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} table $tableid" "0-255"
		rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} goto 32765"
		rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} goto 32765" "0-255"
	done

	#set and check
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} table 300"
	rlRun "vrun $route_host ip -$version rule add to ${S_IP[$version]} table 300" "0-255"
	rlRun "vrun $route_host ip -$version route add table 300 default dev $R_L_IF2 via ${R_R_IP2[$version]}"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep $R_L_IF2"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF2 | sed -n '3,$'p | grep $R_L_IF2"
	rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} oif $R_L_IF1 | sed -n '3,$'p | grep $R_L_IF2" "1"

	vrun $route_host "nohup tcpdump -U -i $R_L_IF2 -p -w route_second.pcap &"
	sleep 5
	rlRun "vrun $C_HOSTNAME $ping ${S_IP[$version]} -c 1"
	rlRun "sleep 2"
	rlRun "vrun $route_host pkill tcpdump"
	sleep 5
	rlRun "vrun $route_host tcpdump -r route_second.pcap -nnle | grep \"> ${S_IP[$version]}\""
	[ $? -ne 0 ] && rlRun "vrun $route_host tcpdump -r route_second.pcap -nnle"
	rlRun "vrun $route_host ip -$version route del table 300 default dev $R_L_IF2 via ${R_R_IP2[$version]}"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} table 300"
	rlRun "vrun $route_host ip -$version rule del to ${S_IP[$version]} table 300" "0-255"
	rlRun "vrun $C_HOSTNAME $ping ${S_IP[$version]} -c 5"
done

	rlRun "vrun $route_host ip -4 rule del to 172.145.11.1 table unspec" "2,254"
	rlRun "vrun $route_host ip -4 rule add to 172.145.11.1 table unspec"
	rlRun "vrun $route_host ip -4 rule list | grep 172.145.11.1"
	rlRun "vrun $route_host ip -4 rule del to 172.145.11.1 table unspec"
	rlRun "vrun $route_host ip -4 rule list | grep 172.145.11.1" "1"

	rlRun "vrun $route_host ip -6 rule del to 4543:1111::1 table unspec" "2,254"

if [ x"$ROUTE_MODE" == x"forward" ]
then
	for version in 4 6
	do

		# test for para from
		[ x"$version" == x"4" ] && ping=ping || ping=ping6
		rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep ${R_R_IP1[$version]}"
		rlRun "vrun $route_host ip -$version rule add from ${c_ip[$version]} table 11"
		rlRun "vrun $route_host ip -$version rule add from ${c_ip[$version]} table 11" "0-255"
		rlRun "vrun $route_host ip -$version rule list | grep \"from ${c_ip[$version]}.*lookup 11\""
		rlRun "vrun $route_host ip -$version route add default dev $R_L_IF2 via ${R_R_IP2[$version]} table 11"
		vrun $route_host tcpdump -U -i $R_L_IF2 -w if2.pcap &
		sleep 2
		rlRun "vrun $C_HOSTNAME $ping ${S_IP[$version]} -c 5"
		sleep 2
		rlRun "vrun $route_host pkill tcpdump"
		sleep 5
		rlRun "vrun $route_host tcpdump -r if2.pcap -nnle | grep \"> ${S_IP[$version]}\""
		[ $? -ne 0 ] && rlRun -l "vrun $route_host tcpdump -r if2.pcap -nnle"
		rlRun "vrun $route_host ip -$version rule del from ${c_ip[$version]} table 11"
		rlRun "vrun $route_host ip -$version rule del from ${c_ip[$version]} table 11" "0-255"
		rlRun "vrun $route_host ip -$version rule list | grep \"from ${c_ip[$version]}.*lookup 11\"" "1"
		rlRun "vrun $route_host ip -$version rule del from ${c_ip[$version]} table 11" "0-255"
		rlRun "vrun $route_host ip -$version route del default dev $R_L_IF2 via ${R_R_IP2[$version]} table 11"

		vrun $route_host tcpdump -U -i $R_L_IF2 -w if2.pcap &
		sleep 2
		rlRun "vrun $C_HOSTNAME $ping ${S_IP[$version]} -c 5"
		sleep 2
		rlRun "vrun $route_host pkill tcpdump"
		sleep 5
		rlRun "vrun $route_host tcpdump -r if2.pcap -nnle | grep \"> ${S_IP[$version]}\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $route_host tcpdump -r if2.pcap -nnle"

		# test for para iif
		rlRun "vrun $route_host ip -$version rule add iif $c_if_r table 11 pref 100"
		rlRun "vrun $route_host ip -$version rule add iif $c_if_r table 11 pref 100" "0-255"
		rlRun "vrun $route_host ip -$version route add default dev $R_L_IF2 via ${R_R_IP2[$version]} table 11"

		vrun $route_host tcpdump -U -i $R_L_IF2 -w if2.pcap &
		sleep 2
		rlRun "vrun $C_HOSTNAME $ping ${S_IP[$version]} -c 5"
		sleep 2
		rlRun "vrun $route_host pkill tcpdump"
		sleep 5
		rlRun "vrun $route_host tcpdump -r if2.pcap -nnle | grep \"> ${S_IP[$version]}\""
		[ $? -ne 0 ] && rlRun -l "vrun $route_host tcpdump -r if2.pcap -nnle"

		rlRun "vrun $route_host ip -$version rule del iif $c_if_r table 11 pref 100"
		rlRun "vrun $route_host ip -$version rule del iif $c_if_r table 11 pref 100" "0-255"
		rlRun "vrun $route_host ip -$version rule del iif $c_if_r table 11 pref 100" "0-255"
		rlRun "vrun $route_host ip -$version route del default dev $R_L_IF2 via ${R_R_IP2[$version]} table 11"

		vrun $route_host tcpdump -U -i $R_L_IF2 -w if2.pcap &
		sleep 2
		rlRun "vrun $C_HOSTNAME $ping ${S_IP[$version]} -c 5"
		sleep 2
		rlRun "vrun $route_host pkill tcpdump"
		sleep 5
		rlRun "vrun $route_host tcpdump -r if2.pcap -nnle | grep \"> ${S_IP[$version]}\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $route_host tcpdump -r if2.pcap -nnle"

		# test for not
		rlRun "vrun $route_host ip -$version rule add not iif $R_L_IF1 iif $R_L_IF2 table 11"
		rlRun "vrun $route_host ip -$version rule add not iif $R_L_IF1 iif $R_L_IF2 table 11" "0-255"
		rlRun "vrun $route_host ip -$version rule del not iif $R_L_IF1 iif $R_L_IF2 table 11"
		rlRun "vrun $route_host ip -$version rule del not iif $R_L_IF1 iif $R_L_IF2 table 11" "0-255"
		rlRun "vrun $route_host ip -$version rule del not iif $R_L_IF1 iif $R_L_IF2 table 11" "0-255"

		rlRun "vrun $route_host ip -$version rule add not from ${S_IP[$version]} to ${c_ip[$version]} pref 100 table 11"
		rlRun "vrun $route_host ip -$version rule list | grep \"100:.*not from ${S_IP[$version]} to ${c_ip[$version]}.*lookup 11\""
		rlRun "vrun $route_host ip -$version rule add not from ${S_IP[$version]} to ${c_ip[$version]} pref 100 table 11" "0-255"

		rlRun "vrun $route_host ip -$version route add default dev $R_L_IF2 via ${R_R_IP2[$version]} table 11"

		vrun $route_host tcpdump -U -i $R_L_IF2 -w if2.pcap &
		sleep 2
		rlRun "vrun $C_HOSTNAME $ping ${S_IP[$version]} -c 5"
		sleep 2
		rlRun "vrun $route_host pkill tcpdump"
		sleep 5
		rlRun "vrun $route_host tcpdump -r if2.pcap -nnle | grep \"> ${S_IP[$version]}\""
		[ $? -ne 0 ] && rlRun -l "vrun $route_host tcpdump -r if2.pcap -nnle"

		rlRun "vrun $route_host ip -$version rule del not from ${S_IP[$version]} to ${c_ip[$version]} pref 100 table 11"
		rlRun "vrun $route_host ip -$version rule del not from ${S_IP[$version]} to ${c_ip[$version]} pref 100 table 11" "0-255"
		rlRun "vrun $route_host ip -$version rule del not from ${S_IP[$version]} to ${c_ip[$version]} pref 100 table 11" "0-255"
		rlRun "vrun $route_host ip -$version route del default dev $R_L_IF2 via ${R_R_IP2[$version]} table 11"

		vrun $route_host tcpdump -U -i $R_L_IF2 -w if2.pcap &
		sleep 2
		rlRun "vrun $C_HOSTNAME $ping ${S_IP[$version]} -c 5"
		sleep 2
		rlRun "vrun $route_host pkill tcpdump"
		sleep 5
		rlRun "vrun $route_host tcpdump -r if2.pcap -nnle | grep \"> ${S_IP[$version]}\"" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $route_host tcpdump -r if2.pcap -nnle"
	done
fi

rlPhaseEnd
}

rule_uidrange_test()
{
	# ip rule can choose action based on uid of the user who use rule
	# https://lwn.net/Articles/704878/
	# only supported on 4 kernel
rlPhaseStartTest "Rule uidrange Test $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	local route_host
	[ x"$ROUTE_MODE" == x"local" ] && route_host=$C_HOSTNAME || route_host=$R_HOSTNAME

	rlRun "vrun $route_host ip rule add uidrange 100-101 table 100" "0-255"
	vrun $route_host ip rule list | grep uidrange || { rlLog "not support uidrange, return"; vrun $route_host ip rule del uidrange 100-101 table 100; return 0; }
	rlRun "vrun $route_host ip rule del uidrange 100-101 table 100"

	for version in 4 6
	do
		[ $version -eq 4 ] && ping_cmd=ping || ping_cmd=ping6
		rlRun "vrun $route_host ip -$version rule add uidrange -2-1 table 100" "1-255"
		rlRun "vrun $route_host ip -$version rule add uidrange 11111111111-222222222222222 table 100" "1-255"

		rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} via ${R_R_IP2[$version]} table 100"
		rlRun "vrun $route_host ip -$version rule add uidrange 100-200 table 100"

		rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep ${R_R_IP2[$version]}" "1"
		[ $? -ne 1 ] && rlRun "vrun $route_host ip -$version route get ${S_IP[$version]}"
		rlRun "vrun $route_host ip -$version rule del uidrange 100-200 table 100"

		rlRun "vrun $route_host ip -$version rule add uidrange 0-100 table 100"
		rlRun "vrun $route_host ip -$version rule list | grep \"uidrange 0-100 lookup 100\""
		[ $? -ne 0 ] && rlRun "vrun $route_host ip -$version rule list"
		rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep ${R_R_IP2[$version]}"
		[ $? -ne 0 ] && rlRun "vrun $route_host ip -$version route get ${S_IP[$version]}"

		vrun $route_host "nohup tcpdump -U -i $R_L_IF2 -w uidrange_$version.pcap &"
		rlRun "sleep 2"
		rlRun "vrun $C_HOSTNAME $ping_cmd ${S_IP[$version]} -c 2"
		rlRun "sleep 2"
		rlRun "vrun $route_host pkill tcpdump" "0-255"
		rlRun "sleep 2"
		rlRun "vrun $route_host tcpdump -r uidrange_$version.pcap -nnle | grep \"> ${S_IP[$version]}\""
		[ $? -ne 0 ] && rlRun -l "vrun $route_host tcpdump -r uidrange_$version.pcap -nnle"

		rlRun "vrun $route_host ip -$version rule del uidrange 0-100 table 100"
		rlRun "vrun $route_host ip -$version route del ${S_IP[$version]} via ${R_R_IP2[$version]} table 100"
	done
rlPhaseEnd
}

rule_suppress_test()
{
	# ip rule can suppress action if interface group or prefix length match the setting
	# https://patchwork.ozlabs.org/patch/264420/
	# only supported on 4 kernel
rlPhaseStartTest "Rule suppress Test $TEST_TYPE $TEST_TOPO $ROUTE_MODE"
	local route_host
	[ x"$ROUTE_MODE" == x"local" ] && route_host=$C_HOSTNAME || route_host=$R_HOSTNAME

	rlRun "vrun $route_host ip rule add table 100 suppress_prefixlength 32" "0-255"
	vrun $route_host ip rule list | grep suppress_prefixlength || { rlLog "not support suppress, return"; vrun $route_host ip rule del table 100 suppress_prefixlength 32; return 0; }
	rlRun "vrun $route_host ip rule del table 100 suppress_prefixlength 32"

	for version in 4 6
	do
		[ $version -eq 4 ] && ping_cmd=ping || ping_cmd=ping6
		[ $version -eq 4 ] && prefix_length=32 || prefix_length=128
		rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} via ${R_R_IP2[$version]} table 100"

		rlRun "vrun $route_host ip -$version rule add table 100 suppress_prefixlength -1" "1-255"
		rlRun "vrun $route_host ip -$version rule add table 100 suppress_prefixlength 0" "0-255"
		rlRun "vrun $route_host ip -$version rule del table 100 suppress_prefixlength 0" "0-255"
		rlRun "vrun $route_host ip -$version rule add table 100 suppress_prefixlength 1111111111" "0-255"
		rlRun "vrun $route_host ip -$version rule del table 100 suppress_prefixlength 1111111111" "0-255"

		rlRun "vrun $route_host ip -$version rule add table 100 suppress_prefixlength $prefix_length"
		rlRun "vrun $route_host ip -$version rule list | grep \"lookup 100 suppress_prefixlength $prefix_length\""
		[ $? -ne 0 ] && rlRun -l "vrun $route_host ip $version rule list"
		rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep ${R_R_IP2[$version]}" "1"
		[ $? -ne 1 ] && rlRun "vrun $route_host ip -$version route get ${S_IP[$version]}"

		rlRun "vrun $route_host ip -$version rule del table 100 suppress_prefixlength $prefix_length"

		rlRun "vrun $route_host ip -$version rule add table 100 suppress_prefixlength 31"
		rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep ${R_R_IP2[$version]}"
		[ $? -ne 0 ] && rlRun "vrun $route_host ip -$version route get ${S_IP[$version]}"

		vrun $route_host "nohup tcpdump -U -i $R_L_IF2 -w suppress_pref_$version.pcap &"
		rlRun "sleep 2"
		rlRun "vrun $C_HOSTNAME $ping_cmd ${S_IP[$version]} -c 2"
		rlRun "sleep 2"
		rlRun "vrun $route_host pkill tcpdump" "0-255"
		rlRun "sleep 2"
		rlRun "vrun $route_host tcpdump -r suppress_pref_$version.pcap -nnle | grep \"> ${S_IP[$version]}\""
		[ $? -ne 0 ] && rlRun -l "vrun $route_host tcpdump -r suppress_pref_$version.pcap -nnle"

		rlRun "vrun $route_host ip -$version rule del table 100 suppress_prefixlength 31"

		rlRun "vrun $route_host ip -$version route del ${S_IP[$version]} via ${R_R_IP2[$version]} table 100"
		rlRun "vrun $route_host ip -$version rule list | grep suppress" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $route_host ip -$version rule list"

	done
	rlRun "vrun $route_host ip rule add table 100 suppress_ifgroup 0" "0-255"
	vrun $route_host ip rule list | grep suppress_ifgroup || { rlLog "not support suppress, return"; vrun $route_host ip rule del table 100 suppress_ifgroup 0; return 0; }
	rlRun "vrun $route_host ip rule del table 100 suppress_ifgroup 0"

	for version in 4 6
	do
		[ $version -eq 4 ] && ping_cmd=ping || ping_cmd=ping6
		rlRun "vrun $route_host ip -$version route add ${S_IP[$version]} via ${R_R_IP2[$version]} table 100"

		rlRun "vrun $route_host ip -$version rule add table 100 suppress_ifgroup 0"
		rlRun "vrun $route_host ip -$version rule list | grep \"lookup 100 suppress_ifgroup default\""
		[ $? -ne 0 ] && rlRun -l "vrun $route_host ip -$version rule list"
		rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep ${R_R_IP2[$version]}" "1"
		[ $? -ne 1 ] && rlRun "vrun $route_host ip -$version route get ${S_IP[$version]}"

		rlRun "vrun $route_host ip -$version rule del table 100 suppress_ifgroup 0"

		rlRun "vrun $route_host ip -$version rule add table 100 suppress_ifgroup 200"
		rlRun "vrun $route_host ip -$version route get ${S_IP[$version]} | grep ${R_R_IP2[$version]}"
		[ $? -ne 0 ] && rlRun "vrun $route_host ip -$version route get ${S_IP[$version]}"

		vrun $route_host "nohup tcpdump -U -i $R_L_IF2 -w suppress_group_$version.pcap &"
		rlRun "sleep 2"
		rlRun "vrun $C_HOSTNAME $ping_cmd ${S_IP[$version]} -c 2"
		rlRun "sleep 2"
		rlRun "vrun $route_host pkill tcpdump" "0-255"
		rlRun "sleep 2"
		rlRun "vrun $route_host tcpdump -r suppress_group_$version.pcap -nnle | grep \"> ${S_IP[$version]}\""
		[ $? -ne 0 ] && rlRun -l "vrun $route_host tcpdump -r suppress_group_$version.pcap -nnle"

		rlRun "vrun $route_host ip -$version rule del table 100 suppress_ifgroup 200"
		rlRun "vrun $route_host ip -$version route del ${S_IP[$version]} via ${R_R_IP2[$version]} table 100"
		rlRun "vrun $route_host ip -$version rule list | grep suppress" "1"
		[ $? -ne 1 ] && rlRun -l "vrun $route_host ip -$version rule list"

	done
rlPhaseEnd
}
