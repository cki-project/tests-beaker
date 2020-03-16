#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Include Beaker environment
. ../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1
. ../common/libmdadm.sh || exit 1

function runtest()
{
	rlRun "modprobe raid456 devices_handle_discard_safely=Y"
	rlRun "echo Y >/sys/module/raid456/parameters/devices_handle_discard_safely"
	typeset release=$(cat /etc/redhat-release | tr -cd "[0-9.]")
	if [[ $(bc -l <<< "$release <= 7.4") -eq 1 ]]; then # release <= 7.4 is true
		rlRun "modprobe raid0 devices_discard_performance=Y"
		rlRun "echo Y >/sys/module/raid0/parameters/devices_discard_performance"
	fi
	devlist=''
	which mkfs.xfs
	[ $? -eq 0 ] && FILESYS="xfs" || FILESYS="ext4"
	disk_num=6
	#disk size M
	disk_size=500
	get_disks $disk_num $disk_size
	devlist=$RETURN_STR
	RAID_LIST="0 1 4 5 6 10"
	for level in $RAID_LIST; do
		RETURN_STR=''
		MD_RAID=''
		MD_DEV_LIST=''
		raid_num=5
		if [ "$level" = "0" ];then
			spare_num=0
			bitmap=0
		else
			spare_num=1
			bitmap=1
		fi
		MD_Create_RAID $level "$devlist" $raid_num $bitmap $spare_num
		if [ $? -ne 0 ];then
			rlLog "FAIL: Failed to create md raid $RETURN_STR"
			exit
		fi
		rlLog "INFO: Successfully created md raid $RETURN_STR"
		MD_RAID=$RETURN_STR
		MD_Get_State_RAID $MD_RAID
		state=$RETURN_STR
		while [[ $state != "active" && $state != "clean" ]]; do
			sleep 5
			MD_Get_State_RAID $MD_RAID
			state=$RETURN_STR
		done
		rlLog "mkfs -t $FILESYS $MD_RAID"
		mkfs -t $FILESYS $MD_RAID || mkfs -t $FILESYS -f $MD_RAID
		[ ! -d /mnt/md_test ] && mkdir /mnt/md_test
		rlRun "mount -t $FILESYS $MD_RAID /mnt/md_test "
		rlRun "fstrim -v /mnt/md_test"
		[ $? -ne 0 ] && rlLog "fstrim -v /mnt/md_test failed"	
		rlRun "umount $MD_RAID"
		MD_Clean_RAID $MD_RAID
	done	
	remove_disks "$devlist"
}

function check_log()
{
	rlRun "dmesg | grep -i 'Call Trace:'" 1 "check the errors"
}

function get_pkg_cmd()
{
	typeset pkgcmd=""
	typeset cmd=""
	for cmd in dnf yum; do
		$cmd --version > /dev/null 2>&1 && pkgcmd=$cmd && break
	done
	echo $pkgcmd
}

rlJournalStart
	rlPhaseStartTest
		rlRun "uname -a"
		pkgcmd=$(get_pkg_cmd)
		rlRun "rpm -q mdadm || $pkgcmd install -y mdadm"
		rlLog "$0"
		runtest
		check_log
	rlPhaseEnd
rlJournalPrintText
rlJournalEnd
