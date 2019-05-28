#!/bin/sh

###########################################################
# Mellanox hardware offload settings
###########################################################
mellanox_setup()
{
	local vfs_num=$1; local vf; local vf_pcid;
	# get pfs info
	local pfs=$(mellanox_get_pfs)
	local pf1=$(echo $pfs | awk '{print $1}')
	# enable SR-IOV
	while true; do
		echo $vfs_num > /sys/class/net/$pf1/device/sriov_numvfs
		test $(mellanox_get_vfs | wc -w) -eq $vfs_num && break || sleep 1
	done
	# wait for vfs available
	while true; do
		local success=true
		for vf in $(mellanox_get_vfs); do
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
	for vf in $(mellanox_get_vfs); do
		local vfs_pcid=$vfs_pcid' '$(ethtool -i $vf | grep bus-info | awk '{print $2}')
	done
	while true; do
		for vf_pcid in $vfs_pcid; do
			echo $vf_pcid > /sys/bus/pci/drivers/mlx5_core/unbind
		done
		test $(mellanox_get_vfs | wc -w) -eq 0 && break || sleep 1
	done
	devlink dev eswitch set pci/$pf1_pcid mode switchdev
	devlink dev eswitch set pci/$pf1_pcid inline-mode transport
	ethtool -K $pf1 rxvlan off # workaround for bz1701502
	ethtool -K $pf1 txvlan off # wordaround for bz1701502
	ethtool -K $pf1 hw-tc-offload on
	while true; do
		for vf_pcid in $vfs_pcid; do
			echo $vf_pcid > /sys/bus/pci/drivers/mlx5_core/bind
		done
		test $(mellanox_get_vfs | wc -w) -eq $vfs_num && break || sleep 1
	done
	# wait for vfs available
	while true; do
		local success=true
		for vf in $(mellanox_get_vfs); do
			ip link set dev $vf up || success=false
		done
		$success && break || sleep 1
	done
	# disable NetworkManager for Mellanox ifaces
	local iface
	for iface in $(ls /sys/class/net/); do
		local vendor=$(cat /sys/class/net/$iface/device/vendor 2>/dev/null)
		if [ "$vendor" != "0x15b3" ]; then
			continue
		fi
		nmcli device set $iface managed no
	done
}
mellanox_cleanup()
{
	local pfs=$(mellanox_get_pfs)
	[ -z "$pfs" ] && return 0
	local pf1=$(echo $pfs | awk '{print $1}')
	test -e /sys/class/net/$pf1/device/sriov_numvfs || return 0
	echo 0 > /sys/class/net/$pf1/device/sriov_numvfs
}
mellanox_get_pfs()
{
	local target="0x1017"; local iface;
	[ "$NIC_DEVICE" == "MT27710" ] && { target="0x1015"; }
	[ "$NIC_DEVICE" == "ConnectX-4 Lx" ] && { target="0x1015"; }
	[ "$NIC_DEVICE" == "MT27800" ] && { target="0x1017"; }
	[ "$NIC_DEVICE" == "ConnectX-5" ] && { target="0x1017"; }
	for iface in $(ls /sys/class/net/); do
		local vendor=$(cat /sys/class/net/$iface/device/vendor 2>/dev/null)
		local device=$(cat /sys/class/net/$iface/device/device 2>/dev/null)
		if [ "$vendor" != "0x15b3" ]; then
			continue
		fi
		if [ "$device" != "$target" ]; then
			continue
		fi
		local ifaces=$ifaces' '$iface
	done
	echo -n $ifaces
}
mellanox_get_vfs()
{
	local target="0x1018"; local iface; local pcid;
	[ "$NIC_DEVICE" == "MT27710" ] && { local VFS_DEVICE="Virtual Function"; target="0x1016"; }
	[ "$NIC_DEVICE" == "ConnectX-4 Lx" ] && { local VFS_DEVICE="Virtual Function"; target="0x1016"; }
	[ "$NIC_DEVICE" == "MT27800" ] && { local VFS_DEVICE="Virtual Function"; target="0x1018"; }
	[ "$NIC_DEVICE" == "ConnectX-5" ] && { local VFS_DEVICE="Virtual Function"; target="0x1018"; }
	for pcid in $(lspci -D | grep Mellanox | grep "$VFS_DEVICE" | awk '{print $1}'); do
		for iface in $(ls /sys/class/net/); do
			local vendor=$(cat /sys/class/net/$iface/device/vendor 2>/dev/null)
			local device=$(cat /sys/class/net/$iface/device/device 2>/dev/null)
			if [ "$vendor" != "0x15b3" ]; then
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
mellanox_get_reps()
{
	local iface; local pf;
	for iface in $(ls /sys/devices/virtual/net/); do
		local phys_switch_id=$(cat /sys/devices/virtual/net/$iface/phys_switch_id 2>/dev/null)
		[ -z "$phys_switch_id" ] && continue
		for pf in $(mellanox_get_pfs); do
			local target=$(cat /sys/class/net/$pf/phys_switch_id 2>/dev/null)
			[ -z "$target" ] && continue
			[ "$phys_switch_id" != "$target" ] && continue
			local ifaces=$ifaces' '$iface
		done
	done
	echo -n $ifaces
}

