#!/bin/sh

###########################################################
# Mellanox hardware offload settings
###########################################################
broadcom_setup()
{
	local vfs_num=$1; local vf; local vf_pcid;
	# get pfs info
	local pfs=$(broadcom_get_pfs)
	local pf1=$(echo $pfs | awk '{print $1}')
	# enable SR-IOV
	while true; do
		echo $vfs_num > /sys/class/net/$pf1/device/sriov_numvfs
		test $(broadcom_get_vfs | wc -w) -eq $vfs_num && break || sleep 1
	done
	# wait for vfs available
	while true; do
		local success=true
		for vf in $(broadcom_get_vfs); do
			ip link set dev $vf up || success=false
		done
		$success && break || sleep 1
	done
	# enable the VFs to communicate with each other even if the PF link state is down
	local index
	for index in $(seq 0 $((vfs_num-1))); do
		ip link set dev $pf1 vf $index state enable
	done
	# enable switchdev mode of SR-IOV
	local pf1_pcid=$(ethtool -i $pf1 | grep bus-info | awk '{print $2}')
	for vf in $(broadcom_get_vfs); do
		local vfs_pcid=$vfs_pcid' '$(ethtool -i $vf | grep bus-info | awk '{print $2}')
	done
	while true; do
		for vf_pcid in $vfs_pcid; do
			echo $vf_pcid > /sys/bus/pci/drivers/bnxt_en/unbind
		done
		test $(broadcom_get_vfs | wc -w) -eq 0 && break || sleep 1
	done
	devlink dev eswitch set pci/$pf1_pcid mode switchdev
	devlink dev eswitch set pci/$pf1_pcid inline-mode transport
	ethtool -K $pf1 hw-tc-offload on
	while true; do
		for vf_pcid in $vfs_pcid; do
			echo $vf_pcid > /sys/bus/pci/drivers/bnxt_en/bind
		done
		test $(broadcom_get_vfs | wc -w) -eq $vfs_num && break || sleep 1
	done
	# wait for vfs available
	while true; do
		local success=true
		for vf in $(broadcom_get_vfs); do
			ip link set dev $vf up || success=false
		done
		$success && break || sleep 1
	done
	# disable NetworkManager for Broadcom ifaces
	local iface
	for iface in $(ls /sys/class/net/); do
		local vendor=$(cat /sys/class/net/$iface/device/vendor 2>/dev/null)
		if [ "$vendor" != "0x15b3" ]; then
			continue
		fi
		nmcli device set $iface managed no
	done
}
broadcom_cleanup()
{
	local pfs=$(broadcom_get_pfs)
	[ -z "$pfs" ] && return 0
	local pf1=$(echo $pfs | awk '{print $1}')
	test -e /sys/class/net/$pf1/device/sriov_numvfs || return 0
	echo 0 > /sys/class/net/$pf1/device/sriov_numvfs
}
broadcom_get_pfs()
{
	local target="0x16ca"; local iface;
	[ "$NIC_DEVICE" == "BCM57304 NetXtreme-C" ] && { target="0x16ca"; }
	for iface in $(ls /sys/class/net/); do
		local vendor=$(cat /sys/class/net/$iface/device/vendor 2>/dev/null)
		local device=$(cat /sys/class/net/$iface/device/device 2>/dev/null)
		# Broadcom
		if [ "$vendor" != "0x14e4" ]; then
			continue
		fi
		# BCM57304 NetXtreme-C
		if [ "$device" != "$target" ]; then
			continue
		fi
		local ifaces=$ifaces' '$iface
	done
	echo -n $ifaces
}
broadcom_get_vfs()
{
	local target="0x16cb"; local iface; local pcid;
	[ "$NIC_DEVICE" == "BCM57304 NetXtreme-C" ] && { local VFS_DEVICE="Ethernet Virtual Function"; target="0x16cb"; }
	for pcid in $(lspci -D | grep Broadcom | grep "$VFS_DEVICE" | awk '{print $1}'); do
		for iface in $(ls /sys/class/net/); do
			local vendor=$(cat /sys/class/net/$iface/device/vendor 2>/dev/null)
			local device=$(cat /sys/class/net/$iface/device/device 2>/dev/null)
			if [ "$vendor" != "0x14e4" ]; then
				continue
			fi
			if [ "$device" != "$target" ]; then
				continue
			fi
			if [ "$(ethtool -i $iface | grep bus-info | awk '{print $2}')" != "$pcid" ]; then
				continue
			fi
			local ifaces=$ifaces' '$iface
		done
	done
	echo -n $ifaces
}
broadcom_get_reps()
{
	local iface; local pf;
	for iface in $(ls /sys/devices/virtual/net/); do
		local phys_switch_id=$(cat /sys/devices/virtual/net/$iface/phys_switch_id 2>/dev/null)
		[ -z "$phys_switch_id" ] && continue
		for pf in $(broadcom_get_pfs); do
			local target=$(cat /sys/class/net/$pf/phys_switch_id 2>/dev/null)
			[ -z "$target" ] && continue
			[ "$phys_switch_id" != "$target" ] && continue
			local ifaces=$ifaces' '$iface
		done
	done
	echo -n $ifaces
}

