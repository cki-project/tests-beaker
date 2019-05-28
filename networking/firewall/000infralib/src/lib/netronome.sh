#!/bin/sh

###########################################################
# Netronome hardware offload settings
###########################################################
netronome_firmware_update()
{
	# update firmware
	local target=$1; local firmware;
	pushd /usr/lib/firmware/netronome
	for firmware in $(ls nic_*.nffw); do
		test -e $target/$firmware && { rm -f $firmware; ln -s $target/$firmware $firmware; }
	done
	popd
	# reload nfp module
	local result=1; local count;
	for count in $(seq 10); do
		rmmod nfp
		modprobe nfp
		[ -n "$(netronome_get_pfs)" ] && { sleep 1; result=0; break; } || sleep 1
	done
	return $result
}
netronome_setup()
{
	local vfs_num=$1
	# wait for pfs available
	while true; do
		dmesg -C
		netronome_firmware_update flower && break
		netronome_firmware_update nic
	done
	local pfs=$(netronome_get_pfs)
	local pf1=$(echo $pfs | awk '{print $1}')
	# enable SR-IOV
	while true; do
		echo $vfs_num > /sys/class/net/$pf1/device/sriov_numvfs
		test $(netronome_get_vfs | wc -w) -eq $vfs_num && break || sleep 1
	done
	# wait for vfs available
	while true; do
		local success=true; local vf;
		for vf in $(netronome_get_vfs); do
			ip link set dev $vf up || success=false
		done
		$success && break || sleep 1
	done
	# enable the VFs to communicate with each other even if the PF link state is down
	local index
	for index in $(seq 0 $((vfs_num-1))); do
		ip link set dev $pf1 vf $index state enable
	done
	# disable NetworkManager for Netronome ifaces
	local iface
	for iface in $(ls /sys/class/net/); do
		local vendor=$(cat /sys/class/net/$iface/device/vendor 2>/dev/null)
		if [ "$vendor" != "0x19ee" ]; then
			continue
		fi
		nmcli device set $iface managed no
	done
}
netronome_cleanup()
{
	local pfs=$(netronome_get_pfs)
	[ -z "$pfs" ] && return 0
	local pf1=$(echo $pfs | awk '{print $1}')
	echo 0 > /sys/class/net/$pf1/device/sriov_numvfs
	while true; do
		netronome_firmware_update nic && break
	done
}
netronome_get_pfs()
{
	local target="0x4000"; local iface;
	[ "$NIC_DEVICE" == "Device 4000" ] && { target="0x4000"; }
	[ "$NIC_DEVICE" == "Device 6000" ] && { target="0x6000"; }
	for iface in $(ls /sys/class/net/); do
		local vendor=$(cat /sys/class/net/$iface/device/vendor 2>/dev/null)
		local device=$(cat /sys/class/net/$iface/device/device 2>/dev/null)
		if [ "$vendor" != "0x19ee" ]; then
			continue
		fi
		if [ "$device" != "$target" ]; then
			continue
		fi
		if [ -z $(cat /sys/class/net/$iface/phys_switch_id 2>/dev/null) ]; then
			continue
		fi
		local ifaces=$ifaces' '$iface
	done
	echo -n $ifaces
}
netronome_get_vfs()
{
	local target="0x6003"; local iface; local pcid;
	[ "$NIC_DEVICE" == "Device 4000" ] && { local VFS_DEVICE="Device 6003"; target="0x6003"; }
	for pcid in $(lspci -D | grep Netronome | grep "$VFS_DEVICE" | awk '{print $1}'); do
		for iface in $(ls /sys/class/net/); do
			local vendor=$(cat /sys/class/net/$iface/device/vendor 2>/dev/null)
			local device=$(cat /sys/class/net/$iface/device/device 2>/dev/null)
			if [ "$vendor" != "0x19ee" ]; then
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
netronome_get_reps()
{
	echo -n $(dmesg | grep VF | grep Representor | awk -F'[()]' '{print $2}')
}

