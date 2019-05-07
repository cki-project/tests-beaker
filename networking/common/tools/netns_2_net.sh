#!/bin/bash
set -x
# Test topo with two network
#         br0             br1
#          |-- Gateway_A --|
# Host A --|               |-- Host B
#          |-- Gateway_B --|

# IPv4
#             192.168.0.254  192.168.1.254
# 192.168.0.1                              192.168.1.1
#             192.168.0.253  192.168.1.253

# IPv6
#            2000::a 2001::a
# 2000::1                      2001::1
#            2000::b 2001::b
MASK[4]="24"
MASK[6]="64"
HA_IP[4]="192.168.0.1"
HB_IP[4]="192.168.1.1"
GA_VETH0_IP[4]="192.168.0.254"
GA_VETH1_IP[4]="192.168.1.254"
GB_VETH0_IP[4]="192.168.0.253"
GB_VETH1_IP[4]="192.168.1.253"

HA_IP[6]="2000::1"
HB_IP[6]="2001::1"
GA_VETH0_IP[6]="2000::a"
GA_VETH1_IP[6]="2001::a"
GB_VETH0_IP[6]="2000::b"
GB_VETH1_IP[6]="2001::b"

get_netns_iface_lladdr()
{
	local netns=$1
	local iface=$2
	ip netns exec $netns ip addr show $iface | awk '/fe80/{print $2}' | \
		cut -d'/' -f1
}

# clean env
nets="ha hb ga gb"
for net in $nets; do
	ip netns del $net
done
modprobe -r veth
#modprobe -r bridge
ip link show br0 && ip link set dev br0 down && ip link del dev br0
ip link show br1 && ip link set dev br1 down && ip link del dev br1

# start setup
for net in $nets; do
	ip netns add $net
done

ip link add ha_veth0 type veth peer name ha_veth0_br
ip link add hb_veth0 type veth peer name hb_veth0_br

ip link add ga_veth0 type veth peer name ga_veth0_br
ip link add ga_veth1 type veth peer name ga_veth1_br

ip link add gb_veth0 type veth peer name gb_veth0_br
ip link add gb_veth1 type veth peer name gb_veth1_br

ip link add br0 type bridge || brctl addbr br0
ip link add br1 type bridge || brctl addbr br1

out_ifaces="br0 br1 ha_veth0_br hb_veth0_br ga_veth0_br ga_veth1_br \
	gb_veth0_br gb_veth1_br"
for iface in $out_ifaces; do
	ip link set $iface up
done

ip link set ha_veth0_br master br0 || brctl addif br0 ha_veth0_br
ip link set ga_veth0_br master br0 || brctl addif br0 ga_veth0_br
ip link set gb_veth0_br master br0 || brctl addif br0 gb_veth0_br

ip link set hb_veth0_br master br1 || brctl addif br1 hb_veth0_br
ip link set ga_veth1_br master br1 || brctl addif br1 ga_veth1_br
ip link set gb_veth1_br master br1 || brctl addif br1 gb_veth1_br

ip link set ha_veth0 netns ha
ip link set hb_veth0 netns hb
ip link set ga_veth0 netns ga
ip link set ga_veth1 netns ga
ip link set gb_veth0 netns gb
ip link set gb_veth1 netns gb

HA="ip netns exec ha"
HB="ip netns exec hb"
GA="ip netns exec ga"
GB="ip netns exec gb"

$HA ip link set lo up
$HA ip link set ha_veth0 up
$HB ip link set lo up
$HB ip link set hb_veth0 up
$GA ip link set lo up
$GA ip link set ga_veth0 up
$GA ip link set ga_veth1 up
$GB ip link set lo up
$GB ip link set gb_veth0 up
$GB ip link set gb_veth1 up

$GA sysctl net.ipv4.ip_forward=1
$GB sysctl net.ipv4.ip_forward=1
$GA sysctl net.ipv6.conf.all.forwarding=1
$GB sysctl net.ipv6.conf.all.forwarding=1

# setup ipv4 addr
$GA ip addr add 192.168.0.254/24 dev ga_veth0
$GA ip addr add 192.168.1.254/24 dev ga_veth1
$GB ip addr add 192.168.0.253/24 dev gb_veth0
$GB ip addr add 192.168.1.253/24 dev gb_veth1

$HA ip addr add 192.168.0.1/24 dev ha_veth0
$HB ip addr add 192.168.1.1/24 dev hb_veth0
$HA ip route add default via 192.168.0.254 dev ha_veth0
$HB ip route add default via 192.168.1.254 dev hb_veth0

# setup ipv6 addr
$GA ip addr add 2000::a/64 dev ga_veth0
$GB ip addr add 2000::b/64 dev gb_veth0
$GA ip addr add 2001::a/64 dev ga_veth1
$GB ip addr add 2001::b/64 dev gb_veth1

$HA ip addr add 2000::1/64 dev ha_veth0
$HB ip addr add 2001::1/64 dev hb_veth0
$HA ip route add default via $(get_netns_iface_lladdr ga ga_veth0) dev ha_veth0
$HB ip route add default via $(get_netns_iface_lladdr ga ga_veth1) dev hb_veth0
set +x
