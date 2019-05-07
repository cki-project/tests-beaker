#!/bin/bash
set -x

# Test topo with 3 network
#          br0                   br1                   br2
# Host A -- | --   Gateway_A   -- | --   Gateway_B   -- | -- Host B
# veth0       veth0        veth1     veth1      veth0        veth0

# .0.1        .0.254       .1.254   .1.253       .2.254     .2.1
# 2000::1    2000::254   2001::254 2001::253   2002::254    2002::1
MASK[4]="24"
MASK[6]="64"
HA_IP[4]="192.168.0.1"
HB_IP[4]="192.168.2.1"
GA_VETH0_IP[4]="192.168.0.254"
GA_VETH1_IP[4]="192.168.1.254"
GB_VETH1_IP[4]="192.168.1.253"
GB_VETH0_IP[4]="192.168.2.254"

HA_IP[6]="2000::1"
HB_IP[6]="2002::1"
GA_VETH0_IP[6]="2000::254"
GA_VETH1_IP[6]="2001::254"
GB_VETH1_IP[6]="2001::253"
GB_VETH0_IP[6]="2002::254"

# clean env
nets="ha hb ga gb"
for net in $nets; do
	ip netns del $net
done
modprobe -r veth
#modprobe -r bridge
ip link show br0 && ip link set dev br0 down && ip link del dev br0
ip link show br1 && ip link set dev br1 down && ip link del dev br1
ip link show br2 && ip link set dev br2 down && ip link del dev br2

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
ip link add br2 type bridge || brctl addbr br2

out_ifaces="br0 br1 br2 ha_veth0_br hb_veth0_br ga_veth0_br ga_veth1_br \
	gb_veth0_br gb_veth1_br"
for iface in $out_ifaces; do
	ip link set $iface up
done

ip link set ha_veth0_br master br0 || brctl addif br0 ha_veth0_br
ip link set ga_veth0_br master br0 || brctl addif br0 ga_veth0_br

ip link set ga_veth1_br master br1 || brctl addif br1 ga_veth1_br
ip link set gb_veth1_br master br1 || brctl addif br1 gb_veth1_br

ip link set gb_veth0_br master br2 || brctl addif br2 gb_veth0_br
ip link set hb_veth0_br master br2 || brctl addif br2 hb_veth0_br

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
$HA ip addr add 192.168.0.1/24 dev ha_veth0
$HB ip addr add 192.168.2.1/24 dev hb_veth0
$GA ip addr add 192.168.0.254/24 dev ga_veth0
$GA ip addr add 192.168.1.254/24 dev ga_veth1
$GB ip addr add 192.168.1.253/24 dev gb_veth1
$GB ip addr add 192.168.2.254/24 dev gb_veth0
$HA ip route add default via 192.168.0.254 dev ha_veth0
$HB ip route add default via 192.168.2.254 dev hb_veth0
$GA ip route add 192.168.2.0/24 via 192.168.1.253 dev ga_veth1
$GB ip route add 192.168.0.0/24 via 192.168.1.254 dev gb_veth1

# setup ipv6 addr
$HA ip addr add 2000::1/64 dev ha_veth0
$HB ip addr add 2002::1/64 dev hb_veth0
$GA ip addr add 2000::254/64 dev ga_veth0
$GA ip addr add 2001::254/64 dev ga_veth1
$GB ip addr add 2001::253/64 dev gb_veth1
$GB ip addr add 2002::254/64 dev gb_veth0
$HA ip -6 route add default via 2000::254 dev ha_veth0
$HB ip -6 route add default via 2002::254 dev hb_veth0
$GA ip -6 route add 2002::/64 via 2001::253 dev ga_veth1
$GB ip -6 route add 2000::/64 via 2001::254 dev gb_veth1
set +x
