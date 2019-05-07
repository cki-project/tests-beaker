#!/bin/bash
set -x

# Test topo with one network
#         br0
# Host A --|-- Host B
#   0.1          0.2
# 2000::1     2000::2
MASK[4]="24"
MASK[6]="64"
BR0_IP[4]="192.168.0.254"
HA_IP[4]="192.168.0.1"
HB_IP[4]="192.168.0.2"

BR0_IP[6]="2000::254"
HA_IP[6]="2000::1"
HB_IP[6]="2000::2"

# clean env
nets="ha hb"
for net in $nets; do
	ip netns del $net
done
modprobe -r veth
#modprobe -r bridge
ip link show br0 && ip link set dev br0 down && ip link del dev br0

# start setup
for net in $nets; do
	ip netns add $net
done

ip link add br0 type bridge || brctl addbr br0
ip link add ha_veth0 type veth peer name ha_veth0_br
ip link add hb_veth0 type veth peer name hb_veth0_br

ip link set ha_veth0_br master br0 || brctl addif br0 ha_veth0_br
ip link set hb_veth0_br master br0 || brctl addif br0 hb_veth0_br

ip link set ha_veth0 netns ha
ip link set hb_veth0 netns hb
HA="ip netns exec ha"
HB="ip netns exec hb"

out_ifaces="br0 ha_veth0_br hb_veth0_br"
for iface in $out_ifaces; do
	ip link set $iface up
done
$HA ip link set lo up
$HA ip link set ha_veth0 up
$HB ip link set lo up
$HB ip link set hb_veth0 up

# MTU testing
#$HB ip link set hb_veth0 mtu 1300

# setup ipv4 addr
ip addr add 192.168.0.254/24 dev br0
$HA ip addr add 192.168.0.1/24 dev ha_veth0
$HB ip addr add 192.168.0.2/24 dev hb_veth0
#$HA ip route add default via 192.168.0.254 dev ha_veth0
#$HB ip route add default via 192.168.0.254 dev hb_veth0

# setup ipv6 addr
ip addr add 2000::254/64 dev br0
$HA ip addr add 2000::1/64 dev ha_veth0
$HB ip addr add 2000::2/64 dev hb_veth0
#$HA ip route add default via 2000::254 dev ha_veth0
#$HB ip route add default via 2000::254 dev hb_veth0
set +x
