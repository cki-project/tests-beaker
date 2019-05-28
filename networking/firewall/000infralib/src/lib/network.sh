#!/bin/sh

###########################################################
# network cleaning
###########################################################
network_sysctl_restore()
{
	local topo=$1; local guest=$2
	local file="/tmp/sysctl.${topo}.${guest}.conf"
	test -e $file && sysctl -q -p $file 2> /dev/null || sysctl -a > $file
}
network_link_clean()
{
	# bridge clean
	if ip link show dev br_wan > /dev/null 2>&1; then
		local iface
		for iface in $(bridge link | grep -v 'master br_wan' | grep -v 'master br_lan' | awk '{print $7}' | uniq); do
		 	ip link del dev $iface
		done
	else
		rmmod bridge
	fi

	# vlan|bond clean
	rmmod 8021q
	rmmod bonding

	# ip tunnel clean
	rmmod vxlan
	rmmod geneve
	rmmod ipip
	rmmod ip6_tunnel

	# ip xfrm clean
	ip xfrm state flush
	ip xfrm policy flush
	ip -6 xfrm state flush
	ip -6 xfrm policy flush
}
network_addr_clean()
{
	local iface;
	for iface in $(ls /sys/class/net/); do
		if ip route | grep default | grep -q $iface; then
			continue
		fi
		if ip route | grep dhcp | grep -q $iface; then
			continue
		fi
		if [ "$iface" == "br_wan" ]; then
			continue
		fi
		if [ "$iface" == "br_lan" ]; then
			continue
		fi
		ip -4 addr flush dev $iface scope global
		ip -6 addr flush dev $iface scope global
	done
}

###########################################################
# offload setting
###########################################################
network_set_offload()
{
	local iface=$1; shift; local offloads=$@; local offload;
	[ -z "$offloads" ] && { return; }
	local offloads_on=$(echo $offloads | cut -d '/' -f 1)
	local offloads_off=$(echo $offloads | cut -d '/' -f 2)
	for offload in $offloads_off; do
		ethtool -K $iface $offload off > /dev/null 2>&1
	done
	for offload in $offloads_on; do
		ethtool -K $iface $offload on > /dev/null 2>&1
	done
	ethtool -k $iface
}

###########################################################
# nic drivers showing
###########################################################
network_show_drivers()
{
	local iface;
	for iface in $(ls /sys/class/net/); do
		if ! ethtool -i $iface > /dev/null 2>&1; then
			continue
		fi
		local driver=$(ethtool -i $iface | grep driver | awk '{print $2}')
		echo -e $iface':\t'$driver
	done
}

###########################################################
# NIC vendor & model checking
###########################################################
network_get_nic_vendor()
{
	if [ -z "$NIC_VENDOR" ]; then
		echo -n "None"
	else
		if ! ( lspci | grep -qi "$NIC_VENDOR" ); then
			echo -n "None"
		else
			if [ -z "$NIC_DEVICE" ]; then
				echo -n "$NIC_VENDOR"
			else
				if ! ( lspci | grep -i $NIC_VENDOR | grep -qi "$NIC_DEVICE" ); then
					echo -n "None"
				else
					echo -n "$NIC_VENDOR"
				fi
			fi
		fi
	fi
}

