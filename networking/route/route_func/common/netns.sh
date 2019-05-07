#!/bin/bash

vrun()
{
    CUR_NETNS=$1
    shift
    echo -e "\n[$(date '+%T')][$(whoami)]# echo '"$@"' | ip netns exec $CUR_NETNS bash"
    echo $@ | ip netns exec $CUR_NETNS bash
}

# local route test topo
#
# +------------+      +-----------------+      +------------+
# |        IF1 +------+IF1              |      |            |
# |            |      |                 |      |            |
# |Client      |      |     Router  IF3 +------+IF3  Server |
# |            |      |                 |      |            |
# |        IF2 +------+IF2              |      |            |
# +------------+      +-----------------+      +------------+
# Client:
# Default route: IF1
# IF1:192.168.10.1/24   2010::1/64
# IF2:192.168.11.1/24   2011::1/64
# Router:
# IF1:192.168.10.254/24 2010::a/64
# IF2:192.168.11.254/24 2011::a/64
# IF3:10.10.0.254/24    3001::a/64
# Server:
# IF3: 10.10.0.1/24     3001::1/64

default_local_setup()
{
	C_HOSTNAME="client"
	R_HOSTNAME="router"
	S_HOSTNAME="server"

	R_L_IF1="veth0"
	R_L_IF2="veth1"
	R_R_IF1="veth0_r"
	R_R_IF2="veth1_r"
	R_L_IP1[4]="192.168.10.1"
	R_L_IP2[4]="192.168.11.1"
	R_R_IP1[4]="192.168.10.254"
	R_R_IP2[4]="192.168.11.254"
	R_L_IP1[6]="2010::1"
	R_L_IP2[6]="2011::1"
	R_R_IP1[6]="2010::a"
	R_R_IP2[6]="2011::a"

	S_IP[4]="10.10.0.1"
	S_IP[6]="3001::1"

	s_if3="veth2"
	r_if3="veth2_r"
	r_ip[4]="10.10.0.254"
	r_ip[6]="3001::a"

	for nsname in $C_HOSTNAME $R_HOSTNAME $S_HOSTNAME
	do
		ip netns add $nsname
	done

	ip link add $R_L_IF1 netns $C_HOSTNAME type veth peer name $R_R_IF1 netns $R_HOSTNAME
	ip link add $R_L_IF2 netns $C_HOSTNAME type veth peer name $R_R_IF2 netns $R_HOSTNAME

	ip link add $s_if3 netns $S_HOSTNAME type veth peer name $r_if3 netns $R_HOSTNAME

	for ifname in lo $R_L_IF1 $R_L_IF2
	do
		ip netns exec $C_HOSTNAME ip link set $ifname up
	done

	for ifname in lo $R_R_IF1 $R_R_IF2 $r_if3
	do
		ip netns exec $R_HOSTNAME ip link set $ifname up
	done

	for ifname in lo $s_if3
	do
		ip netns exec $S_HOSTNAME ip link set $ifname up
	done

	ip netns exec $C_HOSTNAME ip addr add ${R_L_IP1[4]}/24 dev $R_L_IF1
	ip netns exec $C_HOSTNAME ip addr add ${R_L_IP2[4]}/24 dev $R_L_IF2
	ip netns exec $C_HOSTNAME ip addr add ${R_L_IP1[6]}/64 dev $R_L_IF1
	ip netns exec $C_HOSTNAME ip addr add ${R_L_IP2[6]}/64 dev $R_L_IF2

	ip netns exec $R_HOSTNAME ip addr add ${R_R_IP1[4]}/24 dev $R_R_IF1
	ip netns exec $R_HOSTNAME ip addr add ${R_R_IP2[4]}/24 dev $R_R_IF2
	ip netns exec $R_HOSTNAME ip addr add ${r_ip[4]}/24 dev $r_if3
	ip netns exec $R_HOSTNAME ip addr add ${R_R_IP1[6]}/64 dev $R_R_IF1
	ip netns exec $R_HOSTNAME ip addr add ${R_R_IP2[6]}/64 dev $R_R_IF2
	ip netns exec $R_HOSTNAME ip addr add ${r_ip[6]}/64 dev $r_if3

	ip netns exec $S_HOSTNAME ip addr add ${S_IP[4]}/24 dev $s_if3
	ip netns exec $S_HOSTNAME ip addr add ${S_IP[6]}/64 dev $s_if3

	ip netns exec $C_HOSTNAME ip route add default via ${R_R_IP1[4]} dev $R_L_IF1
	ip netns exec $C_HOSTNAME ip -6 route add default via ${R_R_IP1[6]} dev $R_L_IF1

	ip netns exec $S_HOSTNAME ip route add default via ${r_ip[4]} dev $s_if3
	ip netns exec $S_HOSTNAME ip -6 route add default via ${r_ip[6]} dev $s_if3

	ip netns exec $R_HOSTNAME sysctl -w net.ipv4.conf.all.forwarding=1
	ip netns exec $R_HOSTNAME sysctl -w net.ipv6.conf.all.forwarding=1

	R_L_MAC1=`ip netns exec $C_HOSTNAME ip link sh $R_L_IF1 | grep link | awk '{print $2}'`
	R_L_MAC2=`ip netns exec $C_HOSTNAME ip link sh $R_L_IF2 | grep link | awk '{print $2}'`
	R_R_MAC1=`ip netns exec $R_HOSTNAME ip link sh $R_R_IF1 | grep link | awk '{print $2}'`
	R_R_MAC2=`ip netns exec $R_HOSTNAME ip link sh $R_R_IF2 | grep link | awk '{print $2}'`

	ip netns exec client ping ${S_IP[4]} -c 5
	ip netns exec client ping6 ${S_IP[6]} -c 5
}

default_local_cleanup()
{
	unset C_HOSTNAME
	unset R_HOSTNAME
	unset S_HOSTNAME
	unset R_L_IF1
	unset R_L_IF2
	unset R_R_IF1
	unset R_R_IF2
	unset R_L_IP1[4]
	unset R_L_IP2[4]
	unset R_R_IP1[4]
	unset R_R_IP2[4]
	unset R_L_IP1[6]
	unset R_L_IP2[6]
	unset R_R_IP1[6]
	unset R_R_IP2[6]
	unset S_IP[4]
	unset S_IP[6]
	unset R_L_MAC1
	unset R_L_MAC2
	unset R_R_MAC1
	unset R_R_MAC2

	netns_clean.sh
}


# forward route topo
# +-----------+    +-----------------+   +-----------------+  +-----------+
# |           |    |             IF2 +---+ IF2             |  |           |
# |Client IF1 +----+ IF1 Route0      |   |     Route1  IF4 +--+IF4 Server |
# |           |    |             IF3 +---+ IF3             |  |           |
# +-----------+    +-----------------+   +-----------------+  +-----------+
#IP:
#Client:
#IF1: 192.168.0.1/2000::1
#Route0:
#IF1: 192.168.0.254/2000::a
#IF2: 10.0.0.1/4001::1
#IF3: 10.1.1.1/4002::1
#Route1:
#IF2: 10.0.0.2/4001::a
#IF3: 10.1.1.2/4002::a
#IF4: 192.168.1.254/2001::a
#Server:
#IF4: 192.168.1.1/2001::1
#Default route:
#Route0->IF2   <----->   Route1->IF2

default_forward_setup()
{
	C_HOSTNAME="client"
	R_HOSTNAME="route0"
	S_HOSTNAME="server"

	R_L_IF1="eth0r0"
	R_L_IF2="eth1r0"
	R_R_IF1="eth0r0_r"
	R_R_IF2="eth1r0_r"
	R_L_IP1[4]="10.0.0.1"
	R_L_IP2[4]="10.1.1.1"
	R_R_IP1[4]="10.0.0.2"
	R_R_IP2[4]="10.1.1.2"
	R_L_IP1[6]="4001::1"
	R_L_IP2[6]="4002::1"
	R_R_IP1[6]="4001::2"
	R_R_IP2[6]="4002::2"

	S_IP[4]="192.168.1.1"
	S_IP[6]="2001::1"

	s_if3="veth2"
	r_if3="veth2_r"
	r_ip[4]="192.168.1.254"
	r_ip[6]="2001::a"

	c_if="veth0"
	c_if_r="veth0_r"
	c_ip[4]="192.168.0.1"
	c_ip[6]="2000::1"
	c_ip_r[4]="192.168.0.254"
	c_ip_r[6]="2000::a"

	for nsname in $C_HOSTNAME $S_HOSTNAME $R_HOSTNAME route1
	do
		ip netns add $nsname
	done

	ip link add $c_if netns $C_HOSTNAME type veth peer name $c_if_r netns $R_HOSTNAME
	ip link add $R_L_IF1 netns $R_HOSTNAME type veth peer name $R_R_IF1 netns route1
	ip link add $R_L_IF2 netns $R_HOSTNAME type veth peer name $R_R_IF2 netns route1
	ip link add $s_if3 netns $S_HOSTNAME type veth peer name $r_if3 netns route1

	for ifname in lo $c_if
	do
		ip netns exec $C_HOSTNAME ip link set $ifname up
	done

	for ifname in lo $R_L_IF1 $R_L_IF2 $c_if_r
	do
		ip netns exec $R_HOSTNAME ip link set $ifname up
	done

	for ifname in lo $R_R_IF1 $R_R_IF2 $r_if3
	do
		ip netns exec route1 ip link set $ifname up
	done

	for ifname in lo $s_if3
	do
		ip netns exec $S_HOSTNAME ip link set $ifname up
	done

	ip netns exec $C_HOSTNAME ip addr add ${c_ip[4]}/24 dev $c_if
	ip netns exec $C_HOSTNAME ip addr add ${c_ip[6]}/64 dev $c_if

	ip netns exec $R_HOSTNAME ip addr add ${c_ip_r[4]}/24 dev $c_if_r
	ip netns exec $R_HOSTNAME ip addr add ${c_ip_r[6]}/64 dev $c_if_r
	ip netns exec $R_HOSTNAME ip addr add ${R_L_IP1[4]}/24 dev $R_L_IF1
	ip netns exec $R_HOSTNAME ip addr add ${R_L_IP1[6]}/64 dev $R_L_IF1
	ip netns exec $R_HOSTNAME ip addr add ${R_L_IP2[4]}/24 dev $R_L_IF2
	ip netns exec $R_HOSTNAME ip addr add ${R_L_IP2[6]}/64 dev $R_L_IF2

	ip netns exec route1 ip addr add ${r_ip[4]}/24 dev $r_if3
	ip netns exec route1 ip addr add ${r_ip[6]}/64 dev $r_if3
	ip netns exec route1 ip addr add ${R_R_IP1[4]}/24 dev $R_R_IF1
	ip netns exec route1 ip addr add ${R_R_IP1[6]}/64 dev $R_R_IF1
	ip netns exec route1 ip addr add ${R_R_IP2[4]}/24 dev $R_R_IF2
	ip netns exec route1 ip addr add ${R_R_IP2[6]}/64 dev $R_R_IF2

	ip netns exec $S_HOSTNAME ip addr add ${S_IP[4]}/24 dev $s_if3
	ip netns exec $S_HOSTNAME ip addr add ${S_IP[6]}/64 dev $s_if3

	ip netns exec $R_HOSTNAME sysctl -w net.ipv4.conf.all.forwarding=1
	ip netns exec $R_HOSTNAME sysctl -w net.ipv6.conf.all.forwarding=1
	ip netns exec route1 sysctl -w net.ipv4.conf.all.forwarding=1
	ip netns exec route1 sysctl -w net.ipv6.conf.all.forwarding=1

	ip netns exec $R_HOSTNAME sysctl -w net.ipv4.conf.all.rp_filter=0
	ip netns exec $R_HOSTNAME sysctl -w net.ipv4.conf.default.rp_filter=0
	ip netns exec $R_HOSTNAME sysctl -w net.ipv4.conf.${R_L_IF1}.rp_filter=0
	ip netns exec $R_HOSTNAME sysctl -w net.ipv4.conf.${R_L_IF2}.rp_filter=0
	ip netns exec $R_HOSTNAME sysctl -w net.ipv4.conf.${c_if_r}.rp_filter=0
	ip netns exec $R_HOSTNAME sysctl -w net.ipv4.ip_forward_use_pmtu=1

	ip netns exec route1 sysctl -w net.ipv4.conf.all.rp_filter=0
	ip netns exec route1 sysctl -w net.ipv4.conf.default.rp_filter=0
	ip netns exec route1 sysctl -w net.ipv4.conf.${R_R_IF1}.rp_filter=0
	ip netns exec route1 sysctl -w net.ipv4.conf.${R_R_IF2}.rp_filter=0
	ip netns exec route1 sysctl -w net.ipv4.conf.${r_if3}.rp_filter=0
	ip netns exec route1 sysctl -w net.ipv4.ip_forward_use_pmtu=1


	ip netns exec $C_HOSTNAME ip route add default dev $c_if via ${c_ip_r[4]}
	ip netns exec $C_HOSTNAME ip -6 route add default dev $c_if via ${c_ip_r[6]}

	ip netns exec $S_HOSTNAME ip route add default dev $s_if3 via ${r_ip[4]}
	ip netns exec $S_HOSTNAME ip -6 route add default dev $s_if3 via ${r_ip[6]}

	ip netns exec $R_HOSTNAME ip route add default dev $R_L_IF1 via ${R_R_IP1[4]}
	ip netns exec $R_HOSTNAME ip -6 route add default dev $R_L_IF1 via ${R_R_IP1[6]}

	ip netns exec route1 ip route add default dev $R_R_IF1 via ${R_L_IP1[4]}
	ip netns exec route1 ip -6 route add default dev $R_R_IF1 via ${R_L_IP1[6]}

	R_L_MAC1=`ip netns exec $R_HOSTNAME ip link sh $R_L_IF1 | grep link | awk '{print $2}'`
	R_L_MAC2=`ip netns exec $R_HOSTNAME ip link sh $R_L_IF2 | grep link | awk '{print $2}'`
	R_R_MAC1=`ip netns exec route1 ip link sh $R_R_IF1 | grep link | awk '{print $2}'`
	R_R_MAC2=`ip netns exec route1 ip link sh $R_R_IF2 | grep link | awk '{print $2}'`

	ip netns exec client ping ${S_IP[4]} -c 5
	ip netns exec client ping6 ${S_IP[6]} -c 5
}
default_forward_cleanup(){ default_local_cleanup; }
