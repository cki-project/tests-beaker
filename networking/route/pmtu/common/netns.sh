#!/bin/bash


####################################################################
# Topo
#+---------+       +---------+       +----------+        +----------+
#|          |      |          |      |           |       |           |
#|  Client  |------| Router0  |------| Router1   |-------|  Server   |
#|          |      |          |      |           |       |           |
#+---------+       +---------+       +----------+        +----------+
#
#           |  |                         |   |                        |   |
#192.168.0.1|--|192.168.0.254    10.0.0.1|---|10.0.0.2   192.168.1.254|---|192.168.1.1
#    2000::1|--|2000::a           2010::1|---|2010::2          2001::a|---|2001::1
#           |  |                         |   |                        |   |
#####################################################################

default_pmtu_setup()
{
	CLIENTNS="ip netns exec client"
	SERVERNS="ip netns exec server"
	ROUTE0NS="ip netns exec route0"
	ROUTE1NS="ip netns exec route1"
	veth0_client_ip[4]=192.168.0.1
	veth0_server_ip[4]=192.168.1.1
	veth0_client_r_ip[4]=192.168.0.254
	veth0_server_r_ip[4]=192.168.1.254
	veth0_route0_ip[4]=10.10.0.1
	veth0_route0_r_ip[4]=10.10.0.2

	veth0_client_ip[6]=2000::1
	veth0_server_ip[6]=2001::1
	veth0_client_r_ip[6]=2000::a
	veth0_server_r_ip[6]=2001::a
	veth0_route0_ip[6]=2010::1
	veth0_route0_r_ip[6]=2010::2

	ip netns add client
	ip netns add server
	ip netns add route0
	ip netns add route1

	ip link add veth0_client netns client type veth peer name veth0_client_r netns route0
	ip link add veth0_server netns server type veth peer name veth0_server_r netns route1
	ip link add veth0_route0 netns route0 type veth peer name veth0_route0_r netns route1

	$CLIENTNS ip link set lo up
	$CLIENTNS ip link set veth0_client up
	$CLIENTNS ip addr add ${veth0_client_ip[4]}/24 dev veth0_client
	$CLIENTNS ip addr add ${veth0_client_ip[6]}/64 dev veth0_client

	$SERVERNS ip link set lo up
	$SERVERNS ip link set veth0_server up
	$SERVERNS ip addr add ${veth0_server_ip[4]}/24 dev veth0_server
	$SERVERNS ip addr add ${veth0_server_ip[6]}/64 dev veth0_server

	$ROUTE0NS ip link set lo up
	$ROUTE0NS ip link set veth0_client_r up
	$ROUTE0NS ip link set veth0_route0 up
	$ROUTE0NS ip addr add ${veth0_client_r_ip[4]}/24 dev veth0_client_r
	$ROUTE0NS ip addr add ${veth0_client_r_ip[6]}/64 dev veth0_client_r
	$ROUTE0NS ip addr add ${veth0_route0_ip[4]}/24 dev veth0_route0
	$ROUTE0NS ip addr add ${veth0_route0_ip[6]}/64 dev veth0_route0

	$ROUTE1NS ip link set lo up
	$ROUTE1NS ip link set veth0_server_r up
	$ROUTE1NS ip link set veth0_route0_r up
	$ROUTE1NS ip addr add ${veth0_server_r_ip[4]}/24 dev veth0_server_r
	$ROUTE1NS ip addr add ${veth0_server_r_ip[6]}/64 dev veth0_server_r
	$ROUTE1NS ip addr add ${veth0_route0_r_ip[4]}/24 dev veth0_route0_r
	$ROUTE1NS ip addr add ${veth0_route0_r_ip[6]}/64 dev veth0_route0_r

	$CLIENTNS ip route add default via ${veth0_client_r_ip[4]}
	$CLIENTNS ip -6 route add default via ${veth0_client_r_ip[6]}

	$SERVERNS ip route add default via ${veth0_server_r_ip[4]}
	$SERVERNS ip -6 route add default via ${veth0_server_r_ip[6]}

	$ROUTE0NS ip route add default via ${veth0_route0_r_ip[4]}
	$ROUTE0NS ip -6 route add default via ${veth0_route0_r_ip[6]}

	$ROUTE1NS ip route add default via ${veth0_route0_ip[4]}
	$ROUTE1NS ip -6 route add default via ${veth0_route0_ip[6]}

	$ROUTE0NS sysctl -w net.ipv4.conf.all.forwarding=1
	$ROUTE0NS sysctl -w net.ipv6.conf.all.forwarding=1
	$ROUTE1NS sysctl -w net.ipv4.conf.all.forwarding=1
	$ROUTE1NS sysctl -w net.ipv6.conf.all.forwarding=1

	if [ x"$DO_SEC" == x"ipsec" ]
	then
		$CLIENTNS ip xfrm state add src ${veth0_client_ip[4]} dst ${veth0_server_ip[4]} proto ah spi 1 auth sha1 0x0123456789 mode transport
		$CLIENTNS ip xfrm state add src ${veth0_server_ip[4]} dst ${veth0_client_ip[4]} proto ah spi 2 auth sha1 0x0123456789 mode transport
		$CLIENTNS ip xfrm policy add src ${veth0_client_ip[4]} dst ${veth0_server_ip[4]} dir out tmpl src ${veth0_client_ip[4]} dst ${veth0_server_ip[4]} proto ah spi 1 mode transport
		$CLIENTNS ip xfrm policy add src ${veth0_server_ip[4]} dst ${veth0_client_ip[4]} dir in tmpl src ${veth0_server_ip[4]} dst ${veth0_client_ip[4]} proto ah spi 2 mode transport

		$SERVERNS ip xfrm state add src ${veth0_client_ip[4]} dst ${veth0_server_ip[4]} proto ah spi 1 auth sha1 0x0123456789 mode transport
		$SERVERNS ip xfrm state add src ${veth0_server_ip[4]} dst ${veth0_client_ip[4]} proto ah spi 2 auth sha1 0x0123456789 mode transport
		$SERVERNS ip xfrm policy add src ${veth0_client_ip[4]} dst ${veth0_server_ip[4]} dir in tmpl src ${veth0_client_ip[4]} dst ${veth0_server_ip[4]} proto ah spi 1 mode transport
		$SERVERNS ip xfrm policy add src ${veth0_server_ip[4]} dst ${veth0_client_ip[4]} dir out tmpl src ${veth0_server_ip[4]} dst ${veth0_client_ip[4]} proto ah spi 2 mode transport


		$CLIENTNS ip xfrm state add src ${veth0_client_ip[6]} dst ${veth0_server_ip[6]} proto ah spi 3 auth sha1 0x0123456789 mode transport
		$CLIENTNS ip xfrm state add src ${veth0_server_ip[6]} dst ${veth0_client_ip[6]} proto ah spi 4 auth sha1 0x0123456789 mode transport
		$CLIENTNS ip xfrm policy add src ${veth0_client_ip[6]} dst ${veth0_server_ip[6]} dir out tmpl src ${veth0_client_ip[6]} dst ${veth0_server_ip[6]} proto ah spi 3 mode transport
		$CLIENTNS ip xfrm policy add src ${veth0_server_ip[6]} dst ${veth0_client_ip[6]} dir in tmpl src ${veth0_server_ip[6]} dst ${veth0_client_ip[6]} proto ah spi 4 mode transport

		$SERVERNS ip xfrm state add src ${veth0_client_ip[6]} dst ${veth0_server_ip[6]} proto ah spi 3 auth sha1 0x0123456789 mode transport
		$SERVERNS ip xfrm state add src ${veth0_server_ip[6]} dst ${veth0_client_ip[6]} proto ah spi 4 auth sha1 0x0123456789 mode transport
		$SERVERNS ip xfrm policy add src ${veth0_client_ip[6]} dst ${veth0_server_ip[6]} dir in tmpl src ${veth0_client_ip[6]} dst ${veth0_server_ip[6]} proto ah spi 3 mode transport
		$SERVERNS ip xfrm policy add src ${veth0_server_ip[6]} dst ${veth0_client_ip[6]} dir out tmpl src ${veth0_server_ip[6]} dst ${veth0_client_ip[6]} proto ah spi 4 mode transport
	fi
}

default_pmtu_cleanup()
{
	unset CLIENTNS
	unset SERVERNS
	unset ROUTE0NS
	unset ROUTE1NS
	unset veth0_client_ip[4]
	unset veth0_server_ip[4]
	unset veth0_client_r_ip[4]
	unset veth0_server_r_ip[4]
	unset veth0_route0_ip[4]
	unset veth0_route0_r_ip[4]

	unset veth0_client_ip[6]
	unset veth0_server_ip[6]
	unset veth0_client_r_ip[6]
	unset veth0_server_r_ip[6]
	unset veth0_route0_ip[6]
	unset veth0_route0_r_ip[6]

	#netns_clean.sh
	#clean netns env
	for net in $(ip netns list | awk '{print $1}'); do
		ip netns del $net
	done
	modprobe -r veth
	modprobe -r bridge
}
