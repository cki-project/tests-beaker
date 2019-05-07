#!/bin/bash

init_br()
{
	ip link add br_wan type bridge || brctl addbr br_wan
	ip link add br_lan type bridge || brctl addbr br_lan
	ip link set br_wan up
	ip link set br_lan up
}

netns_init()
{
	netns_name="$1"
	netns_cmd="ip netns exec $netns_name"
	ip netns add $netns_name
	ip link add veth0 type veth peer name tap_${netns_name}_0
	ip link add veth1 type veth peer name tap_${netns_name}_1
	ip link add veth2 type veth peer name tap_${netns_name}_2

	ip link set tap_${netns_name}_0 master br_wan || brctl addif br_wan tap_${netns_name}_0
	ip link set tap_${netns_name}_1 master br_lan || brctl addif br_lan tap_${netns_name}_1
	ip link set tap_${netns_name}_2 master br_lan || brctl addif br_lan tap_${netns_name}_2

	ip link set tap_${netns_name}_0 up
	ip link set tap_${netns_name}_1 up
	ip link set tap_${netns_name}_2 up

	ip link set veth0 netns ${netns_name} && $netns_cmd ip link set veth0 name eth0
	ip link set veth1 netns ${netns_name} && $netns_cmd ip link set veth1 name eth1
	ip link set veth2 netns ${netns_name} && $netns_cmd ip link set veth2 name eth2

	$netns_cmd ip link set lo up
	$netns_cmd ip link set eth0 up
	$netns_cmd ip link set eth1 up
	$netns_cmd ip link set eth2 up

	$netns_cmd ip route add default dev eth0
	# a short delay to let interfaces really up, not sure if it helps
	sleep 2
}

vcommon()
{
	CUR_NETNS=$1
	shift
	echo -e "\n[$(date '+%T')][$(whoami)]# echo '"$@"' | ip netns exec $CUR_NETNS"
	echo "source /mnt/tests/kernel/networking/common/include.sh; rm -f /tmp/test_iface; $@" | \
		ip netns exec $CUR_NETNS bash
}

vrun()
{
	CUR_NETNS=$1
	shift
	echo -e "\n[$(date '+%T')][$(whoami)]# echo '"$@"' | ip netns exec $CUR_NETNS bash"
	#echo "$@" | ip netns exec $CUR_NETNS bash
	echo $@ | ip netns exec $CUR_NETNS bash
}

# no need to really cp in netns, just log the cmd
vcp() { echo -e "\n[$(date '+%T')][$(whoami)]# $@"; }

env_init()
{
	netns_clean.sh
	run "init_br"
	run "netns_init server"
	run "netns_init client"
	echo -e "\nStart $TEST_NAME Test"
}

env_setup()
{
	if [ ! "`ip netns list | grep server`" ]; then
		init_br
		netns_init server
		netns_init client
	fi
	PASS=0
	FAIL=0
}

env_clean()
{
	if [ $FAIL -eq 0 ]; then
		echo -e "${TEST_NAME}\tPASS\t${PASS}" >> summary.log
	else
		echo -e "${TEST_NAME}\tFAIL\t${FAIL}" >> summary.log
	fi
	unset TEST_NAME
	unset VTOPO
	netns_clean.sh
}

test_pass()
{
	let PASS++
        echo -e "PASS\t${1}" >> summary.log
        echo -e "\n[  Test '"$1"' PASS  ]" | tee -a $OUTPUTFILE
        if [ $JOBID ]; then
                report_result "${TEST}/$1" "PASS" $PASS
        else
                echo -e "\n\n********\n\n"
                echo -e "[ Test '"${TEST}/$1"' PASS $PASS ]\n"
                echo -e "\n\n********\n\n"
        fi

}

test_fail()
{
	let FAIL++
        echo -e "FAIL\t${1}" >> summary.log
        echo -e "\n[  Test '"$1"' FAIL  ]" | tee -a $OUTPUTFILE
        # we only care how many test failed
        if [ $JOBID ]; then
                report_result "${TEST}/$1" "FAIL" "$FAIL"
        else
                echo -e "\n\n********\n\n"
                echo -e "[ Test '"${TEST}/$1"' FAIL $FAIL ]"
                echo -e "\n\n********\n\n"
        fi
}

setup_net()
{
	net=$1
	if [ -n "$net" ]; then
		setup_net_$net
	else
		VTOPO="PVT=yes"
		setup_net_default
	fi
	[ $? -ne 0 ] && exit 0
}

# setup_net_default:
#          controller (br_lan)
#                  |
#          |----------------|
#     server (eth1)    client (eth1)
setup_net_default()
{
	VTOPO=${VTOPO:-"PVT=yes"}
	# only install once, no need to install in netns again
	for pkg in $depend_pkgs; do
		run "${pkg}_install"
	done
	# Setup controller
	CONTROLLER_IFACE="br_lan"
	CONTROLLER_ADDR4="192.168.1.254"
	CONTROLLER_ADDR6="2001::254"
	run "ip addr add $CONTROLLER_ADDR4/24 dev $CONTROLLER_IFACE"
	run "ip addr add $CONTROLLER_ADDR6/64 dev $CONTROLLER_IFACE"

	# Setup Server
	vcommon server "rm -f /tmp/test_*; $VTOPO; get_test_iface"
	SERVER_IFACE=$(tail -n1 /tmp/test_iface | tr -d '\r\n')
	if [ $? -ne 0 ]; then
        	echo -e "\nNo SERVER IFACE"
		report_result $TEST WARN
		rhts-abort -t recipe
	fi
	SERVER_ADDR4="192.168.1.1"
	SERVER_ADDR6="2001::1"
	vrun server ip link set $SERVER_IFACE up
	vrun server ip addr add $SERVER_ADDR4/24 dev $SERVER_IFACE
	vrun server ip addr add $SERVER_ADDR6/64 dev $SERVER_IFACE

	# Setup Client
	vcommon client "rm -f /tmp/test_*; $VTOPO; get_test_iface"
	CLIENT_IFACE=$(tail -n1 /tmp/test_iface | tr -d '\r\n')
	if [ $? -ne 0 ]; then
		echo -e "\nNo CLIENT IFACE"
		report_result $TEST WARN
		rhts-abort -t recipe
	fi
	CLIENT_ADDR4="192.168.1.2"
	CLIENT_ADDR6="2001::2"
	vrun client ip link set $CLIENT_IFACE up
	vrun client ip addr add $CLIENT_ADDR4/24 dev $CLIENT_IFACE
	vrun client ip addr add $CLIENT_ADDR6/64 dev $CLIENT_IFACE
}

setup_net_vlan()
{
	VTOPO="PVT=yes;TOPO=nic_vlan"
	setup_net_default
}

setup_net_bond()
{
	VTOPO="PVT=yes;TOPO=bond;NIC_NUM=2"
	setup_net_default
}

# setup_net_route:
#                (br_cr)     controller     (br_sr)
#                   |                          |
#   Client (eth1) --|-- (eth1) Router (eth2) --|-- Server (eth1)
setup_net_route()
{
	# Setup env

	[ ! "`ip netns list | grep router`" ] && netns_init router

	ip link add br_cr type bridge || brctl addbr br_cr
	ip link add br_sr type bridge || brctl addbr br_sr
	ip link set br_cr up
	ip link set br_sr up
	ip link set tap_client_1 nomaster || brctl delif br_lan tap_client_1
	ip link set tap_server_1 nomaster || brctl delif br_lan tap_server_1
	ip link set tap_router_1 nomaster || brctl delif br_lan tap_router_1
	ip link set tap_router_2 nomaster || brctl delif br_lan tap_router_2
	ip link set tap_client_1 master br_cr || brctl addif br_cr tap_client_1
	ip link set tap_router_1 master br_cr || brctl addif br_cr tap_router_1
	ip link set tap_server_1 master br_sr || brctl addif br_sr tap_server_1
	ip link set tap_router_2 master br_sr || brctl addif br_sr tap_router_2

	VTOPO=${VTOPO:-"PVT=yes"}
	for pkg in $depend_pkgs; do
		run "${pkg}_install"
	done
	# Setup controller
	CONTROLLER_IFACE="br_lan"
	CONTROLLER_ADDR4="192.168.1.254"
	CONTROLLER_ADDR6="2001::254"
	run "ip addr add $CONTROLLER_ADDR4/24 dev $CONTROLLER_IFACE"
	run "ip addr add $CONTROLLER_ADDR6/64 dev $CONTROLLER_IFACE"

	# Setup Client
	vcommon client "rm -f /tmp/test_*; $VTOPO; get_test_iface"
	CLIENT_IFACE=$(tail -n1 /tmp/test_iface | tr -d '\r\n')
	CLIENT_ADDR4="192.168.1.1"
	CLIENT_ADDR6="2001::1"
	vrun client ip link set $CLIENT_IFACE up
	vrun client ip addr add $CLIENT_ADDR4/24 dev $CLIENT_IFACE
	vrun client ip addr add $CLIENT_ADDR6/64 dev $CLIENT_IFACE
	vrun client ip route add 192.168.2.0/24 via 192.168.1.254 dev $CLIENT_IFACE
	vrun client ip -6 route add 2002::/64 via 2001::254 dev $CLIENT_IFACE

	# Setup Router
	vrun router ip link set eth1 up
	vrun router ip link set eth2 up
	vrun router ip addr add 192.168.1.254/24 dev eth1
	vrun router ip addr add 192.168.2.254/24 dev eth2
	vrun router ip addr add 2001::254/64 dev eth1
	vrun router ip addr add 2002::254/64 dev eth2
	vrun router sysctl -w net.ipv4.conf.all.forwarding=1
	vrun router sysctl -w net.ipv6.conf.all.forwarding=1

	# Setup Server
	vcommon server "rm -f /tmp/test_*; $VTOPO; get_test_iface"
	SERVER_IFACE=$(tail -n1 /tmp/test_iface | tr -d '\r\n')
	SERVER_ADDR4="192.168.2.1"
	SERVER_ADDR6="2002::1"
	vrun server ip link set $SERVER_IFACE up
	vrun server ip addr add $SERVER_ADDR4/24 dev $SERVER_IFACE
	vrun server ip addr add $SERVER_ADDR6/64 dev $SERVER_IFACE
	vrun server ip route add 192.168.1.0/24 via 192.168.2.254 dev $SERVER_IFACE
	vrun server ip -6 route add 2001::/64 via 2002::254 dev $SERVER_IFACE
}
