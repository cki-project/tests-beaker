#! /usr/bin/env bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   This file includes functions that can help setup test devices
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

MAX_SIZE="$(conv_to_num 100T)"

# Transform the default layout and create xfstest, xfscratch and xfshome lvm devices
# Vars: [FSTYPE] [XFSTEST_SIZE_G] [XFSCRATCH_SIZE_G], default as XFSTEST_SIZE_G=6, XFSCRATCH_SIZE_G=12
# Pars: no
# Retn: no
function transform_lvm_layout()
{
	local test_size=${XFSTEST_SIZE_G:-6}
	local scratch_size=${XFSCRATCH_SIZE_G:-12}
	local _DEV1="$(echo /dev/mapper/*-xfstest)"
	local _DEV2="$(echo /dev/mapper/*-xfscratch)"
	local _DEV="$(echo /dev/mapper/*home)"

	if test -b "$_DEV1" -a -b "$_DEV2" -a -b "$_DEV";then
		echoo "Nothing to do, the lvm devices are already there"
		report transform_lvm_layout:eexist PASS 0
		return 0
	fi
	if ! ls "$_DEV";then
		echoo "No lvm device to transform"
		report transform_lvm_layout:nodev FAIL 0
		return 1
	fi

	local _MNT="/home"
	local LV="xfshome" # Use common new home name
	local VG="$(lvdisplay -c "$_DEV"|cut -d ':' -f 2)"
	local SIZE=$(df -P -B G $_MNT|tail -1|awk '{print $4}'|cut -dG -f1)

	test -z "$SIZE" && SIZE=0
	if test $SIZE -lt $((${test_size}+${scratch_size}+7));then
		echoo "Not enough free space to create desired layout"
		report tranform_lvm_layout:enospc FAIL 1
		return 1
	fi

	echo "Repartitioning lvm device $_DEV"
	xlog umount "$_MNT" "$_DEV"
	xlog lvchange -an "$_DEV"
	xlog lvremove "$_DEV" || echoo "Cannot remove $_DEV"
	# Now, the _DEV will be /dev/VG/LV
	_DEV="/dev/$VG/$LV"
	xlog lvcreate -L ${test_size}G -n xfstest "$VG" || report xfstest-dev FAIL 0
	xlog lvcreate -L ${scratch_size}G -n xfscratch "$VG" || report xfscratch-dev FAIL 0
	xlog lvcreate -l 100%FREE -n "$LV" "$VG" || report $LV-dev FAIL 0

	# If there is a FSTYPE to mkfs the home device to then mkfs the home device and upgrade the record in fstab
	if test -n "$FSTYPE";then
		# Make FSTYPE fs on the device
		mkfs_dev "$_DEV"
		cat /etc/fstab | grep -v "/home " > fstab.home_dev
		echo "$_DEV   $_MNT   $FSTYPE   defaults   0 0" >> fstab.home_dev
		cp -f fstab.home_dev /etc/fstab
		if ! xlog mount /home;then
			echoo "Unable to mount /home after the transformation"
			echoo "Something must have gone wrong"
			report transform_lvm_layout:mount FAIL 0
			return 1
		fi
		# Just some rudimentary /home setup
		xlog mkdir -p /home/test # test user should keep his home directory
		xlog chown test /home/test
	fi
	# And report success
	report transform_lvm_layout PASS 0
	return 0
}

# A common function to get a ram-disk device.
# RAM_DEV will be set and output when get ram-disk successfully
# Or return not 0
# Params: [ram-disk size], the size you want, or this function will calculate
#  a suitable size for you
# Output: RAM_DEV
function get_ram_dev()
{
	local RDSIZE=${1}
	local MEMSIZE=`free -g|grep -i mem: |awk '{print $2}'`
	local size=2

	if [ -z "$RDSIZE" ];then
		RDSIZE=$size
		while [ $size -lt $MEMSIZE ];do
			RDSIZE=$size
			size=$((size*2))
		done
	fi
	if [ $RDSIZE -ge $MEMSIZE ];then
		echoo "Memory size(${MEMSIZE}G) too small, we need ${RDSIZE}G"
		return 1
	fi

	RAM_DEV=""
	if lsmod|grep -wq zram;then
		for i in `ls /dev/zram*`;do
			if ! cat /proc/mounts /proc/swaps|grep -wq $i;then
				RAM_DEV=$i
				break;
			fi
		done
	else
		if ! modprobe zram num_devices=2;then
			echoo "load zram.ko module failed"
			return 2
		fi
		RAM_DEV=/dev/zram0
	fi
	if [ -z "$RAM_DEV" ];then
		echoo "can't find idle ramdisk"
		return 2
	fi
	echo $RAM_DEV
	echo $((${RDSIZE}*1024*1024*1024)) > /sys/class/block/$(basename $RAM_DEV)/disksize
	return $?
}

# A common function to get a block-ram-disk(brd) device.
# CONFIG_BLK_DEV_RAM  supports DAX(CONFIG_BLK_DEV_RAM_DAX).
# RAM_DEV will be set and output when get brd successfully
# Or return not 0
# Params: [ram-disk size(G)]
function get_brd_dev()
{
	local kv=$(uname -r)
	if [ ${kv:0:1} -lt 3 ];then
		echoo "Please run this on RHEL7 or above."
		return 1
	fi

	local RDSIZE=$((${1}*1024*1024))
	local MEMSIZE=`free -g|grep -i mem: |awk '{print $2}'`

	if [ $1 -ge $MEMSIZE ];then
		echoo "Memory size(${MEMSIZE}G) too small, we need ${1}G"
		return 1
	fi

	RAM_DEV=""
	if lsmod|grep -wq brd;then
		for i in `ls /dev/ram*`;do
			if ! cat /proc/mounts /proc/swaps|grep -wq $i;then
				if [ "$TEST_DEV" != "$i" ] && [ "$SCRATCH_DEV" != "$i"  ];then
					RAM_DEV=$i
					break
				fi
			fi
		done
	else
		if ! modprobe brd rd_size=${RDSIZE};then
			echoo "load brd module failed"
			return 2
		fi
		RAM_DEV=/dev/ram0
	fi
	if [ -z "$RAM_DEV" ];then
		echoo "can't find idle ramdisk"
		return 2
	fi
	echo $RAM_DEV
	return $?
}

# A common function to get a loop device, it does not manipulate
# any variables, it just outputs the LOOP_DEV name.
# Params: <image> <size>
# Output: <loop_dev>
function get_loop_dev(){
	if test -z "$1" -o -z "$2";then
		echoo "Usage: get_loop_dev <fs.img> <size>"
		report get_loop_dev FAIL 0
		return 1
	fi
	local LOOP_IMG="$1"
	local LOOP_SIZE="$(conv_to_num $2)"
	local LOOP_SIZE_M="$(($LOOP_SIZE/1048576))" # Size in MBs
	touch $LOOP_IMG # Make sure the file exists
	# If the 3rd parameter is non-zero, truncate the image
	if test -n "$3";then
		truncate -s "${LOOP_SIZE_M}M" "$LOOP_IMG"
	fi
	# Use dd iff the file does not already have the asked-for size
	if test $(du --apparent-size -m "$LOOP_IMG" | awk '{print $1}') -lt $LOOP_SIZE_M;then
		# Convert to MB, for dd
		LOOP_SIZE_M="$(($LOOP_SIZE/1048576+1))" # Round it up so that the du -s test passes next time
		dd if=/dev/zero bs=1M "count=$LOOP_SIZE_M" "of=$LOOP_IMG"
	fi
	LOOP_DEV=$(losetup -f) # Even RHEL5 supports this
	if ! test -b "$LOOP_DEV";then
		echoo "Could not get a good loop device"
		report get_loop_dev FAIL 0
		return 1
	fi
	umount $LOOP_DEV >/dev/null 2>&1
	losetup -d $LOOP_DEV >/dev/null 2>&1
	losetup $LOOP_DEV "$LOOP_IMG"
	if test $? -ne 0 ; then
		echoo "Failed to set up loopback test device"
		report get_loop_dev FAIL 0
		return 1
	fi
	echoo $LOOP_DEV
}

# A common function to get a VDO device
function get_vdo_dev()
{
	local dev="$1"

	if ! modprobe kvdo; then
		echoo "Can't find kvdo module, please check if it's installed properly"
		report get_vdo_dev FAIL 0
		return 1
	fi

	if [ -z "$dev" ]; then
		echoo "Usage: get_vdo_dev <device>"
		report get_vdo_dev FAIL 0
		return 1
	fi
	if [ ! -b "$dev" ]; then
		dev=`get_loop_dev $dev 10G`
	fi

	VDO_DEV="/dev/mapper/vdo_$(basename $dev)"
	vdo create --name="$(basename $VDO_DEV)" --device=${dev} --force >/dev/null 2>&1
	if [ ! -b $VDO_DEV ]; then
		echoo "Could not get a good vdo device"
		report get_vdo_dev FAIL 0
		return 1
	fi

	echoo $VDO_DEV
}

# Get test device, there are several heuristics designed to obtain
# a real (standard block or lvm) device. The default option is loop
# device. The test device is a rather small device that isn't mkfs'd
# by xfstests -- it is a rather stable mount.
# Params: [device_type]
# Vars:   [TEST_DEV] [TEST_DIR] [FSTYPE]
# Sets:   <TEST_DEV> <DEV_TYPE>
function get_test_dev()
{
	local DEV_TYPE="$1"

	if [ -z "$DEV_TYPE" ]; then
		# For nfs{,3,4} and tmpfs cifs just set DEV_TYPE variable to FSTYPE
		test "$(echo $FSTYPE|head -c 3)" == "nfs" -o "$FSTYPE" == "tmpfs" -o \
		     "$FSTYPE" == "cifs" && DEV_TYPE="$FSTYPE"

		# User specified mount point
		test -n "${TEST_DIR}" -a -n "$(findmnt -n -o SOURCE $TEST_DIR)" && DEV_TYPE=mount

		# User specified test device
		test -n "${TEST_DEV}" && DEV_TYPE=user

		# If no DEV_TYPE was specified, use the default one
		test -z "$DEV_TYPE" && DEV_TYPE=default
	fi

	case "$DEV_TYPE" in
	user)
		# For a user specified storage, try to get TEST_DIR, but maybe get nothing
		if [ -z "$TEST_DIR" ];then
			TEST_DIR=$(findmnt -n -o TARGET $TEST_DEV)
		fi
		;;
	mount)
		# Mount point was specified
		# Get TEST_DEV from /proc/mounts
		TEST_DEV=$(findmnt -n -o SOURCE $TEST_DIR)
		xlog umount $TEST_DEV
		# Remove the entry from fstab in case there's one
		cp /etc/fstab{,.test_dev}
		cat /etc/fstab.test_dev | grep -v $TEST_DIR >/etc/fstab
		;;
	nfs*)
		umount $TEST_DIR >/dev/null 2>&1
		echoo "TEST_PARAM_TEST_DEV not specified; using localhost"
		# Export whole root - for simple nfs3/4 compatibility
		rm -rf /export/test
		mkdir -p /export/test
		echo '/export/test  *(rw,no_root_squash)' >> /etc/exports
		# stop iptables, service name is iptables on RHEL6, firewalld on RHEL7
		rlServiceStop iptables
		rlServiceStop firewalld
		xlog rlServiceStop rpcbind && xlog rlServiceStart rpcbind
		# restart rpc.statd on RHEL7 for PPC64, it's not running by default
		rlServiceStop nfs-lock && rlServiceStart nfs-lock
		xlog rlServiceStop nfs && xlog rlServiceStart nfs
		TEST_DEV=localhost:/export/test
		DEV_TYPE=nfs
		;;
	cifs)
		umount $TEST_DIR >/dev/null 2>&1
		echoo "TEST_PARAM_TEST_DEV not specified; using localhost"
		rm -rf /export/test
		mkdir -p /export/test
		chcon -t samba_share_t /export/test
		cat >>/etc/samba/smb.conf <<EOF
[test]
	path = /export/test
	writable = yes
EOF
		xlog rlServiceStop smb && xlog rlServiceStart smb
		TEST_DEV=//$HOSTNAME/test
		DEV_TYPE=cifs
		;;
	tmpfs)
		TEST_DEV="tmpfs:test"
		;;
	lvm)
		TEST_DEV="$(echo /dev/mapper/*-xfstest)"
		if ! test -b "$TEST_DEV";then
			transform_lvm_layout
		fi
		TEST_DEV="$(echo /dev/mapper/*-xfstest)"
		if ! test -b "$TEST_DEV";then
			report get_test_dev:lvm FAIL 0
			TEST_DEV=""
			DEV_TYPE=""
			return 1
		fi
		;;
	ram)
		TEST_DEV=$(get_ram_dev)
		if [ $? -ne 0 ];then
			report get_test_dev:ram FAIL 0
			TEST_DEV=""
			DEV_TYPE=""
			return 1
		fi
		;;
	brd)
		TEST_DEV=$(get_brd_dev 10)
		if [ $? -ne 0 ];then
			report get_test_dev:brd FAIL 0
			TEST_DEV=""
			DEV_TYPE=""
			return 1
		fi
		;;
	vdo)
		# Try to get an underlying device from mount point, to create vdo
		# device at first.
		if [ -n "$TEST_DIR" ]; then
			TEST_DEV=$(findmnt -n -o SOURCE $TEST_DIR)
			if [ $? -eq 0 ]; then
				xlog umount $TEST_DEV
				# Remove the entry from fstab in case there's one
				rm -f /etc/fstab.test_dev 2>/dev/null
				cp /etc/fstab{,.test_dev}
				cat /etc/fstab.test_dev | grep -wv $TEST_DIR >/etc/fstab
			fi
		fi
		# If no device is specified, try to create a loop device for vdo
		if [ -z "$TEST_DEV" ]; then
			TEST_DEV="testfile"
		fi
		TEST_DEV=$(get_vdo_dev $TEST_DEV)
		if [ $? -ne 0 ]; then
			report get_test_dev:vdo FAIL 0
			TEST_DEV=""
			DEV_TYPE=""
			return 1
		fi
		;;
	any)
		TEST_DEV="$(echo /dev/mapper/*-xfstest)"
		DEV_TYPE=lvm
		if ! test -b "$TEST_DEV";then
			transform_lvm_layout
		fi
		TEST_DEV="$(echo /dev/mapper/*-xfstest)"
		if ! test -b "$TEST_DEV";then
			TEST_DEV=$(get_loop_dev testfile.img 6G)
			DEV_TYPE=loop
			if ! test -b "$TEST_DEV";then
				report get_test_dev:any FAIL 0
				TEST_DEV=""
				DEV_TYPE=""
				return 1
			fi
		fi
		;;
	default|loop)
		TEST_DEV=$(get_loop_dev testfile.img 6G)
		DEV_TYPE=loop
		if ! test -b "$TEST_DEV";then
			report get_test_dev:loop FAIL 0
			TEST_DEV=""
			DEV_TYPE=""
			return 1
		fi
		;;
	*)
		echoo "Unknown device type ($DEV_TYPE)"
		report get_test_dev:unknown FAIL 0
		TEST_DEV=""
		DEV_TYPE=""
		return 1;
		;;
	esac

	# overlayfs needs further setups
	if [ "$FSTYPE" != "overlay" ]; then
		report get_test_dev:$DEV_TYPE PASS 0
		return 0
	fi
	if [ "$OVLBASEFSTYP" == "ext4" ]; then
		mkfs -t ext4 -F $TEST_DEV
	else
		# xfs is the default fs, test xfs. And xfs needs ftype to be set
		export OVLBASEFSTYP="xfs"
		mkfs -t xfs -n ftype=1 -f $TEST_DEV
	fi
	if [ $? -ne 0 ]; then
		echoo "Failed to create $OVLBASEFSTYP on $TEST_DEV for overlay test"
		report get_test_dev:overlay FAIL 0
		return 1
	fi
	mkdir -p /mnt/ovl/test
	mount $TEST_DEV /mnt/ovl/test
	if [ $? -ne 0 ]; then
		echoo "Failed to mount XFS on /mnt/ovl/test for overlay test"
		report get_test_dev:overlay FAIL 0
		return 1
	fi
	export TEST_DEV=/mnt/ovl/test
	report get_test_dev:overlay PASS 0
	return 0
}

# Disable systemd mount unint for specified mount point
# Params: $1 mount point to disable systemd mount unit
# Ret: 0 success, > 0 failed
function systemd_disable_mount_unit()
{
	local mnt=$1
	local unit=""
	local ret=0

	test -n "$mnt"  || return $ret
	which systemctl || return $ret

	unit=$(systemctl list-units | grep $mnt | awk '{print $1}')
	test -n "$unit" || return $ret

	systemctl disable $unit; ret=$((ret + $?))
	systemctl stop $unit; ret=$((ret + $?))
	systemctl daemon-reload

	return $ret
}

# Get scratch device, there are several heuristics designed to obtain
# a real (standard block or lvm) device. The default option is a loop
# device. The scratch device is ~ 2 times bigger than test device and
# is mkfs'd regularly.
# Params: [device_type]
# Vars:   [SCRATCH_DEV] [SCRATCH_MNT] [FSTYPE]
# Sets:   <SCRATCH_DEV> <DEV_TYPE>
function get_scratch_dev()
{
	local DEV_TYPE="$1"

	if [ -z "$DEV_TYPE" ]; then
		# For nfs{,3,4} and tmpfs cifs just set DEV_TYPE variable to FSTYPE
		test "$(echo $FSTYPE|head -c 3)" == "nfs" -o "$FSTYPE" == "tmpfs" -o \
		     "$FSTYPE" == "cifs" && DEV_TYPE="$FSTYPE"

		# User specified mount point
		test -n "${SCRATCH_MNT}" -a -n "$(findmnt -n -o SOURCE $SCRATCH_MNT)" && DEV_TYPE=mount

		# User specified scratch device
		test -n "${SCRATCH_DEV}" && DEV_TYPE=user

		# If no DEV_TYPE was specified, use the default one
		test -z "$DEV_TYPE" && DEV_TYPE=default
	fi

	case "$DEV_TYPE" in
	user)
		# For a user specified storage, try to get SCRATCH_MNT, but maybe get nothing
		if [ -z "$SCRATCH_MNT" ];then
			SCRATCH_MNT=$(findmnt -n -o TARGET $SCRATCH_MNT)
		fi
		;;
	mount)
		# Mount point was specified
		# Get SCRATCH_DEV from /proc/mounts
		SCRATCH_DEV=$(findmnt -n -o SOURCE $SCRATCH_MNT)
		systemd_disable_mount_unit $SCRATCH_MNT
		findmnt $SCRATCH_DEV &>/dev/null && xlog umount $SCRATCH_DEV
		# Remove the entry from fstab in case there's one
		cp /etc/fstab{,.scratch_dev}
		cat /etc/fstab.scratch_dev | grep -v $SCRATCH_MNT >/etc/fstab
		;;
	nfs*)
		umount $SCRATCH_MNT >/dev/null 2>&1
		echoo "TEST_PARAM_SCRATCH_DEV not specified; using localhost"
		# Export whole root - for simple nfs3/4 compatibility
		rm -rf /export/scratch
		mkdir -p /export/scratch
		echo '/export/scratch  *(rw,no_root_squash)' >> /etc/exports
		# stop iptables, service name is iptables on RHEL6, firewalld on RHEL7
		rlServiceStop iptables
		rlServiceStop firewalld
		xlog rlServiceStop rpcbind && xlog rlServiceStart rpcbind
		# restart rpc.statd on RHEL7 for PPC64, it's not running by default
		rlServiceStop nfs-lock && rlServiceStart nfs-lock
		xlog rlServiceStop nfs && xlog rlServiceStart nfs
		SCRATCH_DEV=localhost:/export/scratch
		DEV_TYPE=nfs
		;;
	cifs)
		umount $SCRATCH_MNT >/dev/null 2>&1
		echoo "TEST_PARAM_SCRATCH_DEV not specified; using localhost"
		rm -rf /export/scratch
		mkdir -p /export/scratch
		chcon -t samba_share_t /export/scratch
		cat >>/etc/samba/smb.conf <<EOF
[scratch]
	path = /export/scratch
	writable = yes
EOF
		xlog rlServiceStop smb && xlog rlServiceStart smb
		SCRATCH_DEV=//$HOSTNAME/scratch
		DEV_TYPE=cifs
		;;
	tmpfs)
		SCRATCH_DEV="tmpfs:scratch"
		;;
	brd)
		SCRATCH_DEV=$(get_brd_dev 15)
		if [ $? -ne 0 ];then
			report get_scratch_dev:brd FAIL 0
			SCRATCH_DEV=""
			DEV_TYPE=""
			return 1
		fi
		;;
	lvm)
		SCRATCH_DEV="$(echo /dev/mapper/*-xfscratch)"
		if ! test -b "$SCRATCH_DEV";then
			transform_lvm_layout
		fi
		SCRATCH_DEV="$(echo /dev/mapper/*-xfscratch)"
		if ! test -b "$SCRATCH_DEV";then
			report get_scratch_dev:lvm FAIL 0
			SCRATCH_DEV=""
			DEV_TYPE=""
			return 1
		fi
		;;
	vdo)
		# Try to get an underlying device from mount point, to create vdo
		# device at first
		if [ -n "$SCRATCH_MNT" ]; then
			SCRATCH_DEV=$(findmnt -n -o SOURCE $SCRATCH_MNT)
			if [ $? -eq 0 ]; then
				xlog umount $SCRATCH_DEV
				# Remove the entry from fstab in case there's one
				rm -f /etc/fstab.scratch_dev 2>/dev/null
				cp /etc/fstab{,.scratch_dev}
				cat /etc/fstab.scratch_dev | grep -v $SCRATCH_MNT >/etc/fstab
			fi
		fi
		# If no device is specified, try to create a loop device for vdo
		if [ -z "$SCRATCH_DEV" ]; then
			SCRATCH_DEV="scratchfile"
		fi
		SCRATCH_DEV=$(get_vdo_dev $SCRATCH_DEV)
		if [ $? -ne 0 ]; then
			report get_scratch_dev:vdo FAIL 0
			SCRATCH_DEV=""
			DEV_TYPE=""
			return 1
		fi
		;;
	any)
		SCRATCH_DEV="$(echo /dev/mapper/*-xfscratch)"
		if ! test -b "$SCRATCH_DEV";then
			transform_lvm_layout
		fi
		SCRATCH_DEV="$(echo /dev/mapper/*-xfscratch)"
		if ! test -b "$SCRATCH_DEV";then
			SCRATCH_DEV=$(get_loop_dev scratchfile.img 12G)
			DEV_TYPE=loop
			if ! test -b "$SCRATCH_DEV";then
				report get_scratch_dev:loop FAIL 0
				SCRATCH_DEV=""
				DEV_TYPE=""
				return 1
			fi
		fi
		;;
	default|loop)
		SCRATCH_DEV=$(get_loop_dev scratchfile.img 12G)
		DEV_TYPE=loop
		if ! test -b "$SCRATCH_DEV";then
			report get_scratch_dev:loop FAIL 0
			SCRATCH_DEV=""
			DEV_TYPE=""
			return 1
		fi
		;;
	*)
		echoo "Unknown device type ($DEV_TYPE)"
		report get_scratch_dev:unknown FAIL 0
		SCRATCH_DEV=""
		DEV_TYPE=""
		return 1;
		;;
	esac

	# overlayfs needs further setups
	if [ "$FSTYPE" != "overlay" ]; then
		report get_scratch_dev:$DEV_TYPE PASS 0
		return 0
	fi
	if [ "$OVLBASEFSTYP" == "ext4" ]; then
		mkfs -t ext4 -F $SCRATCH_DEV
	else
		# xfs is the default fs, test xfs. And xfs needs ftype to be set
		# xfs is the default fs, test xfs. And xfs needs ftype to be set
		export OVLBASEFSTYP="xfs"
		mkfs -t xfs -n ftype=1 -f $SCRATCH_DEV
	fi
	if [ $? -ne 0 ]; then
		echoo "Failed to create $OVLBASEFSTYP on $SCRATCH_DEV for overlay test"
		report get_scratch_dev:overlay FAIL 0
		return 1
	fi
	mkdir -p /mnt/ovl/scratch
	mount $SCRATCH_DEV /mnt/ovl/scratch
	if [ $? -ne 0 ]; then
		echoo "Failed to mount XFS on /mnt/ovl/scratch for overlay test"
		report get_scratch_dev:overlay FAIL 0
		return 1
	fi
	export SCRATCH_DEV=/mnt/ovl/scratch
	report get_scratch_dev:overlay PASS 0
	return 0
}

# Get scratch device pool, used mainly for btrfs
# Params: [device_type]
# Vars:   <SCRATCH_DEV> [SCRATCH_DEV_POOL] [SCRATCH_DEV_POOL_MNT] [FSTYPE]
# Sets:   <SCRATCH_DEV_POOL> <DEV_TYPE>
function get_scratch_dev_pool()
{
	DEV_TYPE="$1"

	# return if FSTYPE is not btrfs
	if [ "$FSTYPE" != "btrfs" ]; then
		report get_scratch_dev_pool:$DEV_TYPE PASS 0
		return 0
	fi

	# User specified mount point
	test -n "${SCRATCH_DEV_POOL_MNT}" && DEV_TYPE=mount

	# User specified scratch device
	test -n "${SCRATCH_DEV_POOL}" && DEV_TYPE=user

	# If no DEV_TYPE was specified, use the default one
	test -z "$DEV_TYPE" && DEV_TYPE=default

	case "$DEV_TYPE" in
	user)
		# For a user specified storage
		SCRATCH_DEV_POOL="$SCRATCH_DEV $SCRATCH_DEV_POOL"
		;;
	mount)
		# Mount point was specified
		# Get SCRATCH_DEV_POOL from /proc/mounts

		# SCRATCH_DEV is the first device in SCRATCH_DEV_POOL
		SCRATCH_DEV_POOL="$SCRATCH_DEV"
		local dev=""
		for mnt in $SCRATCH_DEV_POOL_MNT; do
			dev=$(findmnt -n -o SOURCE $mnt)
			systemd_disable_mount_unit $mnt
			findmnt $SCRATCH_DEV &>/dev/null && xlog umount $dev
			# Remove the entry from fstab in case there's one
			cp /etc/fstab{,.scratch_dev_pool}
			cat /etc/fstab.scratch_dev_pool | grep -v $mnt >/etc/fstab
			SCRATCH_DEV_POOL="$SCRATCH_DEV_POOL $dev"
		done
		;;
	# TODO: setup loop device dev pool
#	default|loop)
#		SCRATCH_DEV=$(get_loop_dev scratchfile.img 12G)
#		DEV_TYPE=loop
#		if ! test -b "$SCRATCH_DEV";then
#			report get_scratch_dev_pool:loop FAIL 0
#			SCRATCH_DEV_POOL=""
#			DEV_TYPE=""
#			return 1
#		fi
#		;;
	*)
		echoo "Unknown device type ($DEV_TYPE)"
		report get_scratch_dev_pool:unknown FAIL 0
		SCRATCH_DEV_POOL=""
		DEV_TYPE=""
		return 1;
		;;
	esac
	report get_scratch_dev_pool:$DEV_TYPE PASS 0
	return 0
}

# Get logwrites device, there are several heuristics designed to obtain a real
# (standard block or lvm) device. The default option is a loop device. The
# logwrites device isn't required to be big, 5G should be sufficient by
# default.
# Params: [device_type]
# Vars:   [LOGWRITES_DEV] [LOGWRITES_MNT] [FSTYPE]
# Sets:   <LOGWRITES_DEV> <DEV_TYPE>
function get_logwrites_dev()
{
	local DEV_TYPE="$1"

	# dm-log-writes tests only work for local filesystems
	case "$FSTYPE" in
	ext*|xfs|btrfs)
		;;
	*)
		report get_logwrites_dev:$DEV_TYPE:skip PASS 0
		return 0
		;;
	esac

	# User specified mount point
	test -n "${LOGWRITES_MNT}" -a -n "$(findmnt -n -o SOURCE $LOGWRITES_MNT)" && DEV_TYPE=mount

	# User specified logwrites device, it we specified a special "loop"
	# string, create a new loop device for LOGWRITES_DEV
	if [ -n "${LOGWRITES_DEV}" ]; then
		if [ "$LOGWRITES_DEV" == "loop" ]; then
			DEV_TYPE=loop
		else
			DEV_TYPE=user
		fi
	fi

	# If DEV_TYPE is still empty by now, then we don't need one, just return
	if [ -z "$DEV_TYPE" ]; then
		LOGWRITES_DEV=""
		report get_logwrites_dev:skip PASS 0
		return 0
	fi

	case "$DEV_TYPE" in
	user)
		# For a user specified storage, try to get LOGWRITES_MNT, but maybe get nothing
		if [ -z "$LOGWRITES_MNT" ];then
			LOGWRITES_MNT=$(findmnt -n -o TARGET $LOGWRITES_MNT)
		fi
		;;
	mount)
		# Mount point was specified
		# Get LOGWRITES_DEV from /proc/mounts
		# DEV_TYPE can be 'mount' if TEST_PARAM_DEV_TYPE is set to
		# 'mount', even if we don't set TEST_PARAM_LOGWRITES_MNT, test
		# LOGWRITES_MNT again here.
		if [ -z "$LOGWRITES_MNT" ]; then
			report get_logwrites_dev:skip PASS 0
			LOGWRITES_DEV=""
			return 0
		fi
		LOGWRITES_DEV=$(findmnt -n -o SOURCE $LOGWRITES_MNT)
		systemd_disable_mount_unit $LOGWRITES_MNT
		findmnt $LOGWRITES_DEV &>/dev/null && xlog umount $LOGWRITES_DEV
		# Remove the entry from fstab in case there's one
		cp /etc/fstab{,.logwrites_dev}
		cat /etc/fstab.logwrites_dev | grep -v $LOGWRITES_MNT >/etc/fstab
		;;
	brd)
		LOGWRITES_DEV=$(get_brd_dev 5)
		if [ $? -ne 0 ];then
			report get_logwrites_dev:brd FAIL 0
			LOGWRITES_DEV=""
			DEV_TYPE=""
			return 1
		fi
		;;
	loop)
		LOGWRITES_DEV=$(get_loop_dev logwritesfile.img 5G)
		DEV_TYPE=loop
		if ! test -b "$LOGWRITES_DEV";then
			report get_logwrites_dev:loop FAIL 0
			LOGWRITES_DEV=""
			DEV_TYPE=""
			return 1
		fi
		;;
	*)
		echoo "Unknown device type ($DEV_TYPE)"
		report get_logwrites_dev:unknown FAIL 0
		LOGWRITES_DEV=""
		DEV_TYPE=""
		return 1;
		;;
	esac

	report get_logwrites_dev:$DEV_TYPE PASS 0
	return 0
}

# A function to get home device -- the biggest device, unlike test and
# scratch dev, the size is variable. The procedure might fail, in that
# case, the empty HOME_DEV var shall be set. The function will also
# remove the record about the device from fstab.
# Params: [device_type]
# Vars:   [HOME_DEV] [HOME_MNT] [FSTYPE]
# Sets:   <HOME_DEV> <DEV_TYPE>
function get_home_dev()
{
	DEV_TYPE="$1"

	# For nfs{,3,4} and tmpfs cifs just set DEV_TYPE variable to FSTYPE
	test "$(echo $FSTYPE|head -c 3)" == "nfs" -o "$FSTYPE" == "tmpfs" -o \
	"$FSTYPE" == "cifs" && DEV_TYPE="$FSTYPE"

	# User specified mount point
	test -n "${HOME_MNT}" -a -n "$(findmnt -n -o SOURCE $HOME_MNT)"  && DEV_TYPE=mount

	# User specified home device
	test -n "${HOME_DEV}" && DEV_TYPE=user

	# If no DEV_TYPE was specified, use the default one
	test -z "$DEV_TYPE" && DEV_TYPE=default

	case "$DEV_TYPE" in
	user)
		# For a user specified storage, do nothing
		;;
	mount)
		# Mount point was specified
		# Get the HOME_DEV from /proc/mounts
		HOME_DEV=$(findmnt -n -o SOURCE $HOME_MNT)
		;;
	loop)
		# We need to get an xfs file system on /home device
		transform_lvm_layout
		HOME_DEV=$(get_loop_dev /home/home_loop.img $MAX_SIZE truncate)
		if ! test -b "$HOME_DEV";then
			report get_home_dev:loop FAIL 0
			HOME_DEV=""
			DEV_TYPE=""
			return 1
		fi
		;;
	sparse)
		# First, check whether the layout was already modified
		# If not, then modify it
		local TMP_DEV="$(echo /dev/mapper/*-xfshome)"
		if ! test -b "$TMP_DEV";then
			transform_lvm_layout
		fi
		# Now, check for the presence of a home device
		TMP_DEV="$(echo /dev/mapper/*home)"
		if ! test -b "$TMP_DEV";then
			report get_home_dev:$DEV_TYPE FAIL 0
			return 1
		fi
		# Resolve TMP_DEV to dm-X device
		TMP_DEV=$(readlink -e "$TMP_DEV")
		if ! test -b "$TMP_DEV";then
			report get_home_dev:$DEV_TYPE:readlink FAIL 0
			return 1
		fi
		# Remove TMP_DEV from fstab if present
		cp /etc/fstab fstab.tmp_dev
		cat fstab.tmp_dev | grep -v "/home " > /etc/fstab
		# First, umount and remove the xfshome1 and zero device in case they were already present in the system
		umount /dev/mapper/xfshome1 /dev/mapper/zero1 "$TMP_DEV" 2> /dev/null
		dmsetup remove -f xfshome1 2> /dev/null
		dmsetup remove -f zero1 2> /dev/null
		wipefs -a "$TMP_DEV" 2> /dev/null
		dd if=/dev/zero of="$TMP_DEV" bs=1M count=1
		local MAX_SECTORS="$(echo $MAX_SIZE/512|bc -q)"
		echo "0 $MAX_SECTORS zero" | xlog dmsetup create zero1
		if ! test -b /dev/mapper/zero1;then
			report get_home_dev:$DEV_TYPE:zero1 FAIL 0
			return 1
		fi
		echo "0 $MAX_SECTORS snapshot /dev/mapper/zero1 $TMP_DEV p 128" | xlog dmsetup create xfshome1
		HOME_DEV=/dev/mapper/xfshome1
		if ! test -b "$HOME_DEV";then
			report get_home_dev:$DEV_TYPE:xfshome1 FAIL 0
			HOME_DEV=""
			return 1
		fi
		;;
	lvm|default)
		# Make the device available in case we used sparse home device before
		umount /dev/mapper/xfshome1 /dev/mapper/zero1 "$TMP_DEV" 2> /dev/null
		dmsetup remove -f xfshome1 2> /dev/null
		dmsetup remove -f zero1 2> /dev/null
		# First, check whether the layout was already modified
		# If not, then modify it
		HOME_DEV="$(echo /dev/mapper/*-xfshome)"
		if ! test -b "$HOME_DEV";then
			transform_lvm_layout
		fi
		# Now, check for the presence of a home device
		HOME_DEV="$(echo /dev/mapper/*home)"
		if ! test -b "$HOME_DEV";then
			report get_home_dev:$DEV_TYPE FAIL 0
			HOME_DEV=""
			DEV_TYPE=""
			return 1
		fi
		# Remove HOME_DEV from fstab if present
		xlog cp /etc/fstab fstab.home_dev
		cat fstab.home_dev | grep -v "/home " > /etc/fstab
		;;
	*)
		echo "Unsupported or unknown device type ($DEV_TYPE)"
		report get_home_dev:unknown FAIL 0
		HOME_DEV=""
		DEV_TYPE=""
		return 1;
		;;
	esac
	report get_home_dev:$DEV_TYPE PASS 0
	return 0
}

function setup_thinp_scratch_dev()
{
	local pool_size=0

	if [ -n "$THINP_SCRATCH_SIZE" -a -b "$SCRATCH_DEV" ];then
		echo "Try to create size=$THINP_SCRATCH_SIZE thinp device with $SCRATCH_DEV"
		pvcreate -ff $SCRATCH_DEV
		vgcreate thinp_scratch_vg $SCRATCH_DEV

		pool_size=`vgs --units g --nosuffix --noheadings -o vg_free thinp_scratch_vg | awk '{print int($0)}'`
		# left 1G free space
		pool_size=$((pool_size - 1))
		echo "thinp_scratch_vg have ${pool_size}G free size"
		lvcreate -L ${pool_size}G -T thinp_scratch_vg/scratchpool
		lvcreate -V "${THINP_SCRATCH_SIZE}" -T thinp_scratch_vg/scratchpool -n thinp_scratch_vol
		if [ -b /dev/thinp_scratch_vg/thinp_scratch_vol ];then
			ORG_SCRATCH_DEV=$SCRATCH_DEV
			SCRATCH_DEV=/dev/thinp_scratch_vg/thinp_scratch_vol
		else
			report set_thinp_scratch_dev FAIL 0
			lvdisplay
			return 1
		fi
	else
		echo "THINP_SCRATCH_SIZE not set, or no SCRATCH_DEV=$SCRATCH_DEV"
	fi
}

function cleanup_thinp_scratch_dev()
{
	if [ -n "$THINP_SCRATCH_SIZE" ];then
		lvremove -ff thinp_scratch_vg
		vgremove -ff thinp_scratch_vg
		if [ -n "$ORG_SCRATCH_DEV" ];then
			SCRATCH_DEV=$ORG_SCRATCH_DEV
			unset ORG_SCRATCH_DEV
			pvremove -ff $SCRATCH_DEV
		fi
	fi
}

function setup_thinp_test_dev()
{
	local pool_size=0

	if [ -n "$THINP_TEST_SIZE" -a -b "$TEST_DEV" ];then
		echo "Try to create size=$THINP_TEST_SIZE thinp device with $TEST_DEV"
		pvcreate -ff $TEST_DEV
		vgcreate thinp_test_vg $TEST_DEV

		pool_size=`vgs --units g --nosuffix --noheadings -o vg_free thinp_test_vg | awk '{print int($0)}'`
		# left 1G free space
		pool_size=$((pool_size - 1))
		echo "thinp_test_vg have ${pool_size}G free size"
		lvcreate -L ${pool_size}G -T thinp_test_vg/testpool
		lvcreate -V "${THINP_TEST_SIZE}" -T thinp_test_vg/testpool -n thinp_test_vol
		if [ -b /dev/thinp_test_vg/thinp_test_vol ];then
			ORG_TEST_DEV=$TEST_DEV
			TEST_DEV=/dev/thinp_test_vg/thinp_test_vol
		else
			report set_thinp_test_dev FAIL 0
			lvdisplay
			return 1
		fi
	else
		echo "THINP_TEST_SIZE not set, or no TEST_DEV=$TEST_DEV"
	fi
}

function cleanup_thinp_test_dev()
{
	if [ -n "$THINP_TEST_SIZE" ];then
		lvremove -ff thinp_test_vg
		vgremove -ff thinp_test_vg
		if [ -n "$ORG_TEST_DEV" ];then
			TEST_DEV=$ORG_TEST_DEV
			unset ORG_TEST_DEV
			pvremove -ff $TEST_DEV
		fi
	fi
}

# Unmount and release all the loop devices
function free_loops()
{
	for loop in /dev/loop*; do
		umount $loop > /dev/null 2>&1
		losetup -d $loop > /dev/null 2>&1
	done
}

# Needs TEST_DIR and SCRATCH_MNT
function release_loops()
{
	# Check that no loop device is blocking TEST_DIR or SCRATCH_MNT
	loops="$(losetup -a |egrep $TEST_DIR\|$SCRATCH_MNT |cut -d ':' -f 1)"
	if [ -n "$loops" ];then
		sleep 1
		for i in $loops
		do
			test -z $i || losetup -d $i >/dev/null 2>&1
		done
	fi
}

# Unmount test dev and scratch_dev if they are mounted
# Needs TEST_DEV, FSTYPE, SCRATCH_DEV
function umount_devices()
{
	# We mount test devices on $TEST_DEV and $SCRATCH_DEV for overlay
	# on purpose, don't umount them
	if [ "$FSTYPE" == "overlay" ]; then
		report umount_devices/skip PASS 0
		return 0
	fi

	# Make sure test devices are unmounted
	xlog grep $TEST_DEV /proc/mounts && xlog umount $TEST_DEV || :
	if test $? -ne 0; then
		echoo "Failed to unmount $TEST_DEV."
		report umount_devices FAIL 0
		exit 0
	fi

	xlog grep $SCRATCH_DEV /proc/mounts && xlog umount $SCRATCH_DEV || :
	if test $? -ne 0; then
		echoo "Failed to unmount $SCRATCH_DEV."
		report umount_devices FAIL 0
		exit 0
	fi

	for dev in $SCRATCH_DEV_POOL; do
		xlog grep $dev /proc/mounts && xlog umount $dev || :
		if test $? -ne 0; then
			echoo "Failed to unmount scratch dev pool device $dev"
			report umount_devices FAIL 0
			exit 0
		fi
	done
	report umount_devices PASS 0
}

# try to make sure all test devices are mounted
# this function generally be used when test case cleanup
# I hope all test devices are mounted, then next case use
# function likes get_test_dev can use *mount* parameter to get
# the device name, when dir name be given. This situation always happen
# when beaker job xml use <partition>.
function mount_devices()
{
	# Make sure test device is mounted
	if [ -n "$TEST_DIR" -a -n "$TEST_DEV" ];then
		blkid $TEST_DEV || mkfs_dev $TEST_DEV
		findmnt $TEST_DEV >/dev/null || mount $TEST_DEV $TEST_DIR
	fi
	# Make sure scratch device is mounted
	if [ -n "$SCRATCH_MNT" -a -n "$SCRATCH_DEV" ];then
		blkid $SCRATCH_DEV | mkfs_dev $SCRATCH_DEV
		findmnt $SCRATCH_DEV >/dev/null || mount $SCRATCH_DEV $SCRATCH_MNT
	fi
	# Make sure logwrites device is mounted
	if [ -n "$LOGWRITES_MNT" -a -n "$LOGWRITES_DEV" ];then
		mkfs_dev $LOGWRITES_DEV
		findmnt $LOGWRITES_DEV >/dev/null || mount $LOGWRITES_DEV $LOGWRITES_MNT
	fi
	# Make sure all scratch pool devices be mounted
	if [ -n "$SCRATCH_DEV_POOL" -a -n "$SCRATCH_DEV_POOL_MNT" ];then
		ARRAY_SCRATCH_DEV_POOL=(`echo $SCRATCH_DEV_POOL`)
		ARRAY_SCRATCH_DEV_POOL_MNT=(`echo $SCRATCH_DEV_POOL_MNT`)
		for (( i=0; i<${#ARRAY_SCRATCH_DEV_POOL[@]}; i++ ));do
			blkid ${ARRAY_SCRATCH_DEV_POOL[$i]} | mkfs_dev ${ARRAY_SCRATCH_DEV_POOL[$i]}
			findmnt ${ARRAY_SCRATCH_DEV_POOL[$i]} >/dev/null || mount ${ARRAY_SCRATCH_DEV_POOL[$i]}  ${ARRAY_SCRATCH_DEV_POOL_MNT[$i]}
		done
	fi
}

# Just mkfs the supplied device
# Arguments: <device>
# Needs: FSTYPE
function mkfs_dev(){
	local _DEV="$1"

	if [ "$FSTYPE" == "overlay" ]; then
		return 0
	fi

	if ! test -b "$_DEV";then
		echoo "Device '$_DEV' is not a block device"
		report mkfs_dev:no_block FAIL 0
		return 1
	fi
	if ! which "mkfs.$FSTYPE" >/dev/null 2>&1;then
		echoo "No 'mkfs.$FSTYPE' is present in system"
		report mkfs_dev:no_mkfs FAIL 0
		return 1
	fi
	# Do not forget to remove the old fs signature
	wipefs -a "$_DEV" 2> /dev/null
	dd if=/dev/zero of="$_DEV" bs=1M count=1 >/dev/null
	xlog "mkfs.$FSTYPE" $MKFS_OPTS "$_DEV"
	if test $? -ne 0;then
		echoo "Mkfs command failed"
		report "mkfs_dev:$_DEV" FAIL 0
		return 1
	fi
	report "mkfs_dev:$_DEV" PASS 0
	return 0
}

# Update an fstab entry after test done, and make sure the device
# is mounted. Or return 1 if it can't be mounted again.
# Usage: update_fstab <device> <mountpoint> [fstype]
# Needs: FSTYPE
function update_fstab()
{
	local dev=$1
	local mnt=$2
	local type=$3

	if [ -z "$dev" -o -z "$mnt" ]; then
		echoo "device and directory names are needed"
		return 1
	fi

	if [ -z "$type" -a -z "$FSTYPE" ]; then
		type=`blkid $dev |sed -n 's;.*[ \t]TYPE="\([a-zA-Z0-9_-]*\)".*;\1;p'`
		echoo "Find filesystem type by blkid: $type"
		FSTYPE=$type
	fi
	[ -z "$type" ] && type=xfs
	umount $dev 2>/dev/nul
	[ -z "$FSTYPE" ] && FSTYPE=$type
	mkfs_dev $dev && mount $dev $mnt
	if [ $? -ne 0 ];then
		echoo "Can't mount $dev on $mnt again!"
		return 1;
	fi

	local uuid
	uuid=`blkid $dev | sed -n 's;.*UUID=\"\([[:graph:]]*\)\".*;\1;p'`
	sed -i "/${dev##*/}[[:blank:]]*/d" /etc/fstab
	sed -i "/UUID=$uuid[[:blank:]]*/d" /etc/fstab

	echo "$dev $mnt $type defaults 0 0" >> /etc/fstab
	return 0
}

# Update TEST_DEV, SCRATCH_DEV and SCRATCH_DEV_POOL related entries in fstab,
# and make sure all devices (except loop devices) are still mounted when test
# end.
# This function generally is used when test case cleanup, especially you hope
# to use these test devices again in next case running.
function localfs_cleanup()
{
	if [ -n "$TEST_DEV" -a -n "$TEST_DIR" ];then
		if ! losetup -a| grep -qw $TEST_DEV; then
			update_fstab "$TEST_DEV" "$TEST_DIR" || return 1
		elif [[ "$TEST_DEV" =~ "/dev/mapper/vdo_loop" ]]; then
			umount $TEST_DEV 2>/dev/null
			vdo remove --name=$(basename $TEST_DEV) --force
			losetup -d /dev/${TEST_DEV#*vdo_}
		else
			umount $TEST_DEV 2>/dev/null
			losetup -d $TEST_DEV 2>/dev/null
		fi
	fi

	if [ -n "$SCRATCH_DEV" -a -n "$SCRATCH_MNT" ];then
		if ! losetup -a| grep -qw $SCRATCH_DEV; then
			update_fstab "$SCRATCH_DEV" "$SCRATCH_MNT" || return 1
		elif [[ "$SCRATCH_DEV" =~ "/dev/mapper/vdo_loop" ]]; then
			umount $SCRATCH_DEV 2>/dev/null
			vdo remove --name=$(basename $SCRATCH_DEV) --force
			losetup -d /dev/${SCRATCH_DEV#*vdo_}
		else
			umount $SCRATCH_DEV 2>/dev/null
			losetup -d $SCRATCH_DEV 2>/dev/null
		fi
	fi

	if [ -n "$SCRATCH_DEV_POOL" -a -n "$SCRATCH_DEV_POOL_MNT" ];then
		ARRAY_SCRATCH_DEV_POOL=(`echo $SCRATCH_DEV_POOL`)
		ARRAY_SCRATCH_DEV_POOL_MNT=(`echo $SCRATCH_DEV_POOL_MNT`)
		for (( i=0; i<${#ARRAY_SCRATCH_DEV_POOL[@]}; i++ ));do
			if ! losetup -a | grep -qw ${ARRAY_SCRATCH_DEV_POOL[$i]}; then
				update_fstab "${ARRAY_SCRATCH_DEV_POOL[$i]}  ${ARRAY_SCRATCH_DEV_POOL_MNT[$i]}" || return 1
			else
				umount ${ARRAY_SCRATCH_DEV_POOL[$i]} 2>/dev/null
				losetup -d ${ARRAY_SCRATCH_DEV_POOL[$i]} 2>/dev/null
			fi
		done
	fi
}

function general_cleanup()
{
	case $FSTYPE in
	xfs|ext*|btrfs)
		localfs_cleanup
		;;
	nfs*|cifs|overlay|tmpfs)
		return 0
		;;
	*)
		echoo "Don't know how to mkfs for $FSTYPE, or $FSTYPE is not supported by this case"
		return 1
		;;
	esac
}

export FSTYPE=${FSTYPE:-xfs}
