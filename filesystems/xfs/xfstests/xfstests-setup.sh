#! /usr/bin/env bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   This file includes xfstests setup functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Needs FSTYPE, CHECK_OPTS
# Sets FSTYPE, CHECK_OPTS
function setup_nfs34()
{
	if [ "$FSTYPE" == "nfs3" ];then
		cat /etc/nfsmount.conf |grep -v 'Defaultvers=' |grep -v 'Nfsvers=' > nfsmount.conf.mod
		cp -f /etc/exports exports.bup
		cp -f /etc/nfsmount.conf nfsmount.conf.bup
		mv -f nfsmount.conf.mod /etc/nfsmount.conf
		echo 'Defaultvers=3' >> /etc/nfsmount.conf
		echo 'Nfsvers=3' >> /etc/nfsmount.conf
		cat /etc/sysconfig/nfs | grep -v 'MOUNTD_NFS_V3=' > nfs.mod
		cp -f /etc/sysconfig/nfs nfs.bup
		mv -f nfs.mod /etc/sysconfig/nfs
		echo 'MOUNTD_NFS_V3=yes' >> /etc/sysconfig/nfs
		CHECK_OPTS="-nfs $CHECK_OPTS"
	fi

	if [ "$FSTYPE" == "nfs4" ];then
		cat /etc/nfsmount.conf |grep -v 'Defaultvers=' |grep -v 'Nfsvers=' > nfsmount.conf.mod
		cp -f /etc/exports exports.bup
		cp -f /etc/nfsmount.conf nfsmount.conf.bup
		mv -f nfsmount.conf.mod /etc/nfsmount.conf
		echo 'Defaultvers=4' >> /etc/nfsmount.conf
		echo 'Nfsvers=4' >> /etc/nfsmount.conf
		cat /etc/sysconfig/nfs | grep -v 'MOUNTD_NFS_V4=' > nfs.mod
		cp -f /etc/sysconfig/nfs nfs.bup
		mv -f nfs.mod /etc/sysconfig/nfs
		echo 'MOUNTD_NFS_V4=yes' >> /etc/sysconfig/nfs
		if [ $RHEL_MAJOR -eq 5 ];then
			# Nfs4 can't be mounted by nfs on rhel5, mask it
			# Nfs4 also does not support option context=
			cp -f /bin/mount /bin/mount.real
			cp -f mount4.py /bin/mount
			chmod a+x /bin/mount
		fi
		CHECK_OPTS="-nfs $CHECK_OPTS"
	fi
}


# Needs FSTYPE, CHECK_OPTS
# Sets CHECK_OPTS, TMPFS_MOUNT_OPTIONS, TEST_FS_MOUNT_OPTS
function setup_tmpfs()
{
	if [ "$FSTYPE" == "tmpfs" ];then
		CHECK_OPTS="-tmpfs $CHECK_OPTS"
		TMPFS_MOUNT_OPTIONS="-o size=1G"
		TEST_FS_MOUNT_OPTS="-o size=512M"
	fi
}

# Needs FSTYPE, CHECK_OPTS
# Sets CHECK_OPTS, CIFS_MOUNT_OPTIONS
function setup_cifs()
{
	if [ "$FSTYPE" == "cifs" ]; then
		cp -f /etc/samba/smb.conf smb.conf.bup
		CHECK_OPTS="-cifs $CHECK_OPTS"
		# this is needed otherwise cifs will ask for password at mount time
		export FSTYP=cifs
		CIFS_MOUNT_OPTIONS="$CIFS_MOUNT_OPTIONS -o username=root,password=redhat"
		# this is needed by _test_mount, seems like xfstests bug, workaround here
		export TEST_FS_MOUNT_OPTS=$CIFS_MOUNT_OPTIONS
		echo -e "redhat\nredhat" | smbpasswd -a root -s
		rm -f /etc/samba/smb.conf
		touch /etc/samba/smb.conf
		restorecon /etc/samba/smb.conf
	fi
}

# Needs FSTYPE, CHECK_OPTS
# Sets CHECK_OPTS
function setup_overlay()
{
	if [ "$FSTYPE" != "overlay" ];then
		return
	fi
	CHECK_OPTS="-overlay $CHECK_OPTS"
	# enable userns so overlay/020 doesn't fail due to ENOSPC
	# RHEL7.4 kernel needs this
	sysctl user.max_user_namespaces=100 >/dev/null 2>&1
}

function setup_devices()
{
	# Check that no loop device is blocking TEST_DIR or SCRATCH_MNT
	release_loops

	# Do the setup for nfs3/nfs4
	# Starts nfs server if necessary, export proper directories, ...
	setup_nfs34

	# Basic tmpfs setup
	setup_tmpfs

	# Setup for cifs
	setup_cifs

	# Setup for overlayfs
	setup_overlay

	# Sets TEST_DEV if unset
	get_test_dev "$DEV_TYPE"

	# Sets SCRATCH_DEV if unset
	get_scratch_dev "$DEV_TYPE"

	# Sets LOGWRITES_DEV if unset
	get_logwrites_dev "$DEV_TYPE"

	# Sets SCRATCH_DEV_POOL if unset
	get_scratch_dev_pool "$DEV_TYPE"

	# Make sure test devices are unmounted
	umount_devices

	# Set FSCK variable, function resides in misc.sh
	set_fsck
}


function setup_blksize()
{
	# Skip this setup if we are asked for default block size
	test "$BLKSIZE" == "default" && return 0
	# Deal with BLKSIZE
	# btrfs has no 'block size'
	if [ ! -z "${BLKSIZE}" -a $FSTYPE != "btrfs" ];then
		if [ $FSTYPE = "xfs" ];then
			MKFS_OPTS="-b size=$BLKSIZE $MKFS_OPTS"
		else
			MKFS_OPTS="-b $BLKSIZE $MKFS_OPTS"
		fi
	fi
}


function setup_gfs2()
{
	# GFS2 needs lock_nolock option for testing
	if [ "$FSTYPE" == "gfs2" ]; then
		MKFS_OPTS="-p lock_nolock -j 1 -O $MKFS_OPTS"
	fi
}


# Needs FSTYPE, TEST_DEV, MKFS_OPTS
function setup_test_dev_mkfs()
{
	# The TEST_DEV device is expected to be pre-mkfs'd as $FSTYPE
	# Nfs cannot be dd'd nor mkfs'd
	if [ "$FSTYPE" != "nfs3" -a "$FSTYPE" != "nfs4" -a "$FSTYPE" != "tmpfs" -a "$FSTYPE" != "cifs" ]; then
		# Make FSTYPE fs with MKFS_OPTS options on the device, exit on failure
		if ! mkfs_dev $TEST_DEV; then
			exit 0
		fi
	fi
}

# Submit block device info for debug
function get_blkdev_info()
{
	local dev=$1
	[ -b $dev ] || return

	echo blockdev -v --getsz --getss --getpbsz --getbsz --getsize64 $dev
	blockdev -v --getsz --getss --getpbsz --getbsz --getsize64 $dev
}

# Needs TEST_DEV, TEST_DIR, SRATCH_DEV, SCRATCH_MNT, SCRATCH_DEV_POOL, SCRATCH_LOGDEV and SCRATCH_RTDEV
function setup_config()
{
	local config=/var/lib/xfstests/local.config
	cat << _EOF_ > $config
TEST_DEV=$TEST_DEV				# device containing TEST PARTITION
TEST_DIR=$TEST_DIR				# mount point of TEST PARTITION
SCRATCH_MNT=$SCRATCH_MNT			# mount point for SCRATCH PARTITION
SCRATCH_LOGDEV=$SCRATCH_LOGDEV			# optional external log for SCRATCH PARTITION
SCRATCH_RTDEV=$SCRATCH_RTDEV			# optional realtime device for SCRATCH PARTITION
LOGWRITES_DEV=$LOGWRITES_DEV			# optional dm-log-writes device
TMPFS_MOUNT_OPTIONS="${TMPFS_MOUNT_OPTIONS}"	# scratch mount options for tmpfs
TEST_FS_MOUNT_OPTS="${TEST_FS_MOUNT_OPTS}"	# test mount options for tmpfs
CIFS_MOUNT_OPTIONS="${CIFS_MOUNT_OPTIONS}"	# mount options for cifs
SELINUX_MOUNT_OPTIONS="-o context=system_u:object_r:nfs_t:s0"
_EOF_
	# Override default selinux mount options if selinux is enabled, the
	# default selinux mount option (root_t) doesn't work well with RHEL7.3
	# and prior releases, restore to this good old selinux context (nfs_t)
	if [ -x /usr/sbin/selinuxenabled ] && /usr/sbin/selinuxenabled; then
		echo "SELINUX_MOUNT_OPTIONS=\"-o context=system_u:object_r:nfs_t:s0\"" >> $config
	fi

	# SCRATCH_DEV is the first device of SCRATCH_DEV_POOL
	if [ "x$SCRATCH_DEV_POOL" == "x" ]; then
		echo "SCRATCH_DEV=$SCRATCH_DEV" >> $config
	else
		echo "SCRATCH_DEV_POOL=\"$SCRATCH_DEV_POOL\"" >> $config
	fi

	get_blkdev_info $TEST_DEV > blockdev.info
	get_blkdev_info $SCRATCH_DEV >> blockdev.info
	get_blkdev_info $LOGWRITES_DEV >> blockdev.info

	rhts_submit_log -l $config
	rhts_submit_log -l blockdev.info
}


# Needs SKIPTESTS
# Sets SKIPTESTS
function setup_skiptests()
{
	# The skipped tests are onw autogenerated from known_issues file
	# Just provide it with the correct SKIP_LEVEL (1 by default)
	# SKIP_LEVEL=0 - no tests are skipped this way (apart from TEST_PARAM_SKIPTESTS)
	# SKIP_LEVEL=1 - skip all the tests specified in skipped section
	# SKIP_LEVEL=2 - skip all the known issues

	local release="${RHEL_NAME}${RHEL_VERSION}"
	if [ "$KNOWN_ISSUE" != "" ]; then
	        release=$KNOWN_ISSUE
	fi

	case "$SKIP_LEVEL" in
		"0")
			_SECTIONS=""
			;;
		"1")
			_SECTIONS="skipped"
			;;
		"2")
			_SECTIONS="skipped,general,$(uname -m)"
			;;
		*)
			echoo "Unknown SKIP_LEVEL $SKIP_LEVEL"
			report setup_skiptests FAIL 0
			;;
	esac

	# The following test is skipped if wordsize is 32
	# Currently it is the only exception for skipped tests
	# 092 - older kernels don't grok inode64 mounts on 32-bit boxes
	WORDSIZE=$(/var/lib/xfstests/src/feature -w)
	if [ $RHEL_MAJOR -eq 5 -a $WORDSIZE = 32 ]; then
		SKIPTESTS="$SKIPTESTS xfs/092"
	fi
}


# Do the setup for different BLKSIZE/FSTYPE
function setup_full
{
	# Reset fs-specific variables
	TEST_DEV="$TEST_PARAM_TEST_DEV"
	SCRATCH_DEV="$TEST_PARAM_SCRATCH_DEV"
	SCRATCH_LOGDEV="$TEST_PARAM_SCRATCH_LOGDEV"
	SCRATCH_RTDEV="$TEST_PARAM_SCRATCH_RTDEV"
	MKFS_OPTS="$TEST_PARAM_MKFS_OPTS"
	CHECK_OPTS="$TEST_PARAM_CHECK_OPTS"
	SKIPTESTS="$TEST_PARAM_SKIPTESTS"
	[ -z "$SKIPTESTS" ] && SKIPTESTS="$(cat known_issues)"
	RUNTESTS="$TEST_PARAM_RUNTESTS"
	[ -z "$RUNTESTS" ] && RUNTESTS="$(cat RUNTESTS)"
	DEV_TYPE="$TEST_PARAM_DEV_TYPE"
	FSCK=""
	FSCK_OPTS=""
	# Setup TEST_DEV and SCRATCH_DEV
	# Handle nfs3/4 specific cases
	setup_devices
	# Set MKFS_OPTS with respect to BLKSIZE parameter
	setup_blksize
	# GFS2 specific options
	setup_gfs2
	# Pre-mkfs TEST_DEV
	setup_test_dev_mkfs
	# Write the new xfstests config file
	setup_config
	# Setup SKIPTESTS variable based on SKIP_LEVEL, FSTYPE and TEST_PARAM_SKIPTESTS
	setup_skiptests

	report setup_done PASS 0
}
