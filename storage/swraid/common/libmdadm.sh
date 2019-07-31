#!/bin/bash

# Copyright (c) 2016 Red Hat, Inc. All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# Author: Chnaghui Zhong <czhong@redhat.com>

JOURNAL_SUPPORT=0
info=`mdadm --create --help | grep -o "write-journal"`
if [ "$info" = "write-journal" ]; then
        JOURNAL_SUPPORT=1
fi
#----------------------------------------------------------------------------#
# MD_Create_RAID ()
# Usage:
#   Create md raid.
# Parameter:
# 	$level				# like 0, 1, 3, 5, 10, 50                       
# 	$dev_list			# like 'sda sdb sdc sdd'
# 	$raid_dev_num		# like 3                       
# 	$spar_dev_num		# like 2                                    
# 	$chunk				# like 64                                     
# Returns:
#   Return code:
#       0 on success
#       1 if something went wrong.
#   Return string:
#       RETURN_STR		# $md_raid like '/dev/md0'
#		MD_DEVS			# $raid_dev_list like '/dev/sda /dev/sdb'
#----------------------------------------------------------------------------#

function MD_Create_RAID()
{
	RETURN_STR=''
	MD_DEVS=''
	local level=$1
	local dev_list=$2
	local raid_dev_num=$3
	local bitmap=$4
	local spar_dev_num=${5:-0}
	local chunk=${6:-512}
	local bitmap_chunksize=${7:-64M}
	local dev_num=0
	local raid_dev=''
	local spar_dev=''
	local md_raid=""
	local mtdata=${8:-1.2}
	local ret=0
	# start to create
	echo "INFO: Executing MD_Create_RAID() to create raid $level"
	# check if the given disks are more the needed
	for i in $dev_list; do
		dev_num=$((dev_num+1))
	done
	if [ $dev_num -lt $(($raid_dev_num+$spar_dev_num)) ]; then
		echo "FAIL: Required devices are more than given."
	fi
	# get free md device name, only scan /dev/md[0-15].
	for i in `seq 1 30`; do
		ls -l /dev/md$i > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			md_raid=/dev/md$i
			break
		fi
	done
	# get raid disk list.
	for i in `seq 1 $raid_dev_num`; do
		tmp_dev=`echo $dev_list | cut -d " " -f $i`
		raid_dev="$raid_dev /dev/$tmp_dev"
	done
	echo "INFO: Created md raid with these raid devices \"$raid_dev\"."
	# get spare disk list.
	if [ $spar_dev_num -ne 0 ]; then
		for i in `seq $((raid_dev_num+1)) $((raid_dev_num+spar_dev_num))`; do
			tmp_dev=`echo $dev_list | cut -d " " -f $i`
			spar_dev="$spar_dev /dev/$tmp_dev"
		done
		echo "INFO: Created md raid with these spare disks \"$spar_dev\"."
	fi
	sleep 5
	# create md raid
	if [ $bitmap -eq 1 ]; then
		if [ $spar_dev_num -ne 0 ]; then
			rlRun "mdadm --create --run $md_raid --level $level --metadata $mtdata \
			--raid-devices $raid_dev_num $raid_dev \
			--spare-devices $spar_dev_num $spar_dev --chunk $chunk --bitmap=internal \
			--bitmap-chunk=$bitmap_chunksize"
		else
			rlRun "mdadm --create --run $md_raid --level $level --metadata $mtdata \
			--raid-devices $raid_dev_num $raid_dev --chunk $chunk --bitmap=internal \
			--bitmap-chunk=$bitmap_chunksize"
		fi
	elif [ $bitmap -eq 2 ];then
		touch /home/bitmap_md_$level
	 	echo "INFO:bitmap backup in /home/bitmap_md_$level"
		bitmap_dir="/home/bitmap_md_$level"
		if [ $spar_dev_num -ne 0 ]; then
			rlRun "mdadm --create --run $md_raid --level $level --metadata $mtdata \
                        --raid-devices $raid_dev_num $raid_dev \
                        --spare-devices $spar_dev_num $spar_dev --chunk $chunk --bitmap=$bitmap_dir \
			--force  --bitmap-chunk=$bitmap_chunksize"
                else
			rlRun "mdadm --create --run $md_raid --level $level --metadata $mtdata \
                        --raid-devices $raid_dev_num $raid_dev --chunk $chunk --bitmap=$bitmap_dir \
			--force --bitmap-chunk=$bitmap_chunksize"
                fi
	else
		if [ $spar_dev_num -ne 0 ]; then
			rlRun "mdadm --create --run $md_raid --level $level --metadata $mtdata \
			--raid-devices $raid_dev_num $raid_dev \
			--spare-devices $spar_dev_num $spar_dev --chunk $chunk"
		else
			rlRun "mdadm --create --run $md_raid --level $level --metadata $mtdata \
			--raid-devices $raid_dev_num $raid_dev --chunk $chunk"
		fi
	fi
	ret=$?
	if [ $ret -ne 0 ]; then
		rlLog "INFO:create $md_raid failed."
		exit
	fi
	echo "create `date +%s` mdadm -CR $md_raid -l $level -e $mtdata -n $raid_dev_num \"$raid_dev\" \
	      -x=$spar_dev_num $spar_dev bitmap=$bitmap --chunk $chunk --bitmap-chunk=$bitmap_chunksize"
	echo "INFO:cat /proc/mdstat######################"
	rlRun "cat /proc/mdstat"
	rlRun "lsblk"
	ls /dev/md* |egrep md[0-9]+
	echo "INFO:mdadm -D $md_raid #########################"
	rlRun "mdadm --detail $md_raid"
	# define global variables
	MD_DEVS="$raid_dev $spar_dev"
	RETURN_STR="$md_raid"	
	return $ret
}
####################### End of functoin MD_Create_RAID

#----------------------------------------------------------------------------#
# MD_Create_RAID_Journal ()
# Usage:
#   Create md raid with journal.
# Parameter:
# 	$level				# like 4, 5, 6
# 	$dev_list			# like 'sda sdb sdc sdd'
# 	$raid_dev_num		# like 3
# 	$spar_dev_num		# like 2
# 	$chunk				# like 64
# Returns:
#   Return code:
#       0 on success
#       1 if something went wrong.
#   Return string:
#       RETURN_STR		# $md_raid like '/dev/md0'
#		MD_DEVS			# $raid_dev_list like '/dev/sda /dev/sdb'
#----------------------------------------------------------------------------#

function MD_Create_RAID_Journal()
{
	RETURN_STR=''
	MD_DEVS=''
	local level=$1
	local dev_list=$2
	local raid_dev_num=$3
	local bitmap=$4
	local spar_dev_num=${5:-0}
	local chunk=${6:-512}
	local bitmap_chunksize=${7:-64M}
	local mtdata=${8:-1.2}
	local dev_num=0
	local raid_dev=''
	local spar_dev=''
	local md_raid=""
	local ret=0
	# start to create
	echo "INFO: Executing MD_Create_RAID_Journal() to create raid $level"
	# check if the given disks are more the needed
	for i in $dev_list; do
		dev_num=$((dev_num+1))
	done
	if [ $dev_num -lt $(($raid_dev_num+$spar_dev_num)) ]; then
		echo "FAIL: Required devices are more than given."
	fi
	# get free md device name, only scan /dev/md[0-15].
	for i in `seq 0 15`; do
		ls -l /dev/md$i > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			md_raid=/dev/md$i
			break
		fi
	done
	# take the first disk as journal disk
	tmp_dev=`echo $dev_list | cut -d " " -f 1`
	journal_dev="/dev/$tmp_dev"
	echo "INFO: Created md raid with write journal disk \"$journal_dev\"."
	# get raid disk list.
	for i in `seq 2 $raid_dev_num`; do
		tmp_dev=`echo $dev_list | cut -d " " -f $i`
		raid_dev="$raid_dev /dev/$tmp_dev"
	done
	echo "INFO: Created md raid with these raid devices \"$raid_dev\"."

	# get spare disk list.
	if [ $spar_dev_num -ne 0 ]; then
		for i in `seq $((raid_dev_num+1)) $((raid_dev_num+spar_dev_num))`; do
			tmp_dev=`echo $dev_list | cut -d " " -f $i`
			spar_dev="$spar_dev /dev/$tmp_dev"
		done
		echo "INFO: Created md raid with these spare disks \"$spar_dev\"."
	fi
	#There is one write journal disk, so change the raid_dev_num--
	((raid_dev_num--))
	# create md raid
	# prepare the parameter
	BITMAP=""
	SPAR_DEV=""
	if [ $spar_dev_num -ne 0 ]; then
		SPAR_DEV="--spare-devices $spar_dev_num $spar_dev"
	fi
	if [ -n "$journal_dev" ]; then
		WRITE_JOURNAL="--write-journal $journal_dev"
	fi
	rlRun "mdadm --create --run $md_raid --level $level --metadata $mtdata \
		--raid-devices $raid_dev_num $raid_dev $WRITE_JOURNAL $SPAR_DEV \
		$BITMAP --chunk $chunk"
	ret=$?
	if [ $ret -ne 0 ]; then
		echo "INFO:create $md_raid failed"
		exit
	fi
	echo "create raid time `date +%s` mdadm -CR $md_raid --level $level \
		--metadata $mtdata --raid-devices $raid_dev_num $raid_dev $WRITE_JOURNAL \
		$SPAR_DEV $BITMAP --chunk $chunk "
	rlRun "cat /proc/mdstat"
	rlRun "mdadm --detail $md_raid"
	# define global variables
	MD_DEVS="$journal_dev $raid_dev $spar_dev"
	RETURN_STR="$md_raid"
	return $ret
}
####################### End of functoin MD_Create_RAID_Journal

#----------------------------------------------------------------------------#
# MD_Save_RAID ()
# Usage:
#   Save md raid configuration.
# Parameter:
# 	NULL
# Returns:
#   Return code:
#       0 on success
#       1 if something went wrong.
#   Return string:
#       NULL
#----------------------------------------------------------------------------#

function MD_Save_RAID()
{
    echo "INFO: Executing MD_Save_RAID()"                    
    echo "DEVICE $MD_DEVS" > /etc/mdadm.conf
	if [ $? -ne 0 ]; then
		echo "FAIL: Failed to save md device info to /etc/mdadm.conf"
	fi
	mdadm --detail --scan >> /etc/mdadm.conf
	if [ $? -ne 0 ]; then
		echo "FAIL: Failed to save md state info to /etc/mdadm.conf"
	fi
	return 0
}
####################### End of functoin MD_Save_RAID

#----------------------------------------------------------------------------#
# MD_Clean_RAID ()
# Usage:
#	Clean md raid.
# Parameter:
#   $md_name		# like '/dev/md0'
# Returns:
#   Return code:
#       0 on success
#       1 if something went wrong.
#   Return string:
#       NULL
#----------------------------------------------------------------------------#

function MD_Clean_RAID()
{
    echo "INFO: Executing MD_Clean_RAID() against this md device: $md_name"
	local md_name=$1	
	echo "mdadm --stop $md_name"
	mdadm --stop $md_name
	st=$?
	while [ $st -ne 0 ]; do
		echo "INFO:mdadm stop failed"	
		sleep 10
		rm -rf /etc/mdadm.conf
		for i in $(cat /proc/mdstat |grep "inactive" |awk '{print $1}') ;do
			mdadm --stop "/dev/$i"
		done
	mdadm --stop $md_name
	st=$?
	done
	sleep 10	
	echo "clean devs : $MD_DEVS"
	for dev in $MD_DEVS; do
		echo "mdadm --zero-superblock $dev"
		`mdadm --zero-superblock $dev` 
	done
	#`mdadm --zero-superblock "$MD_DEVS"` 
	echo "ret is $?"
	rm -rf /etc/mdadm.conf
	sleep 10
	echo "ls $md_name"
        ls $md_name
        if [ $? = 1 ];then
                echo "mdadm --stop command can't delete md node name $md_name in /dev node"
		ls /dev/md*
		cat /proc/mdstat
        else
        	echo "mdadm --stop can delete md node name $md_name in /dev"
        fi
	return 0
}
####################### End of functoin MD_Clean_RAID

#----------------------------------------------------------------------------#
# MD_Get_State_RAID ()
# Usage:
#   get md raid status
# Parameter:
#   $md_name		# like "/dev/md0"
# Returns:
#   Return code:
#       0 on success
#       1 if something went wrong.
#   Return string:
#       RETURN_STR  # $state, like 'clean, resyncing'
#----------------------------------------------------------------------------#

function MD_Get_State_RAID()
{
    RETURN_STR=''
	local md_name=$1
	local state=''
	local start_times=0
	local end_times=0
	local spend_times=0
	start_times=$(date +%s)
	echo " $start_times start_time against this md array: $md_name "
	state=`mdadm --detail $md_name | grep "State :" | cut -d ":" -f 2 | cut -d " " -f 2`
	sta=$?
	if [ -z "$state" ]; then
		echo "`date +%s`  first_time_failed get raid statu #######################"
		while [ $sta ];do
			state=`mdadm --detail $md_name | grep "State :" | cut -d ":" -f 2 | cut -d " " -f 2`
			sta=$?
			end_times=$(date +%s)
			spend_times=$((end_times - start_times))
				if [[ $spend_times -gt 10  ]];then
					echo "get raid status spend $spend_times and exit  "
					ls /dev/md* |egrep md[0-9]+
					cat /proc/mdstat
					exit
				fi
		done
		echo "$spend_times spend raid statu_time #############################"	
	fi
	echo "state is $state"
    RETURN_STR="$state"
    return 0
}

function create_loop_devices()
{
    Create_Loop_Devices $@
}

# ---------------------------------------------------------#
# Create_Loop_Devices ()
# Usage:
#   Create loop devices. We will find out the free number
#   of loop to bind on tmp file.
# Parameter:
#   $count      #like "12"
#   $size_mib   #like "1024"
# Returns:
#   Return code:
#       0 on success
#       1 if something went wrong.
#   Return string:
#       RETURN_STR like 'loop9 loop10'
# ---------------------------------------------------------#

function Create_Loop_Devices()
{
    RETURN_STR=''
    local count="$1"
    local size_mib="$2"
    local loop_dev_list=''
    mkdir /home/loop
    for X in `seq 1 ${count}`;do
        local loop_file_name=$(mktemp /home/loop/loop.XXXXXX)
	     dd if=/dev/zero of=${loop_file_name} count=$size_mib  bs=1M 1>/dev/null 2>&1
        local loop_dev_name=$(losetup -f)
#BUG: RHEL5 only support 8 loop device and we need to check whether we are run out of it
        local command="losetup ${loop_dev_name} ${loop_file_name} 1>/dev/null 2>&1"
        eval "${command}"
        if [ $? -eq 0 ];then
            loop_dev_list="${loop_dev_list}${loop_dev_name} "
        else
            echo "FAIL: Failed to create loop devices with command: ${command}"
            return 1
        fi
    done
    loop_dev_list=$(echo "${loop_dev_list}" | sed -e 's/ $//')
    echo "${loop_dev_list}" #Back capability
    loop_dev_list=$(echo "${loop_dev_list}" | sed -e 's/\/dev\///g')
    RETURN_STR="${loop_dev_list}"
    return 0
}

function get_disks()
{
	disk_num=$1
	disk_size=$2
	LOOP_DEVICE_LIST=$(create_loop_devices $disk_num $disk_size)
	for i in $(seq 1 $disk_num); do
	   	disk_temp=$(echo $LOOP_DEVICE_LIST | cut -d " " -f $i)
   		disk_temp=$(echo $disk_temp | cut -d "/" -f 3)
   		devlist="$devlist $disk_temp"
	done
	RETURN_STR="$devlist"
}

function remove_disks()
{
	disks=$1			  
	for disk in $disks; do
		try_num=1
		disk="/dev/"$disk
		echo "losetup -d $disk"
		losetup -d $disk
		state=$?
		while [ $state -ne 0 ]; do
			if [ $try_num -eq 4 ]; then
				echo "FAIL: After tried 3 times losetup -d $disk"
				return 1
			fi
			sleep 1
			losetup -d $disk
			state=$?
			((try_num++))
                done
	done
	rm -rf /home/loop/loop.*
	rm -rf /home/loop/
}

function local_clean()
{
		local md_name=""
                mdadm -E /dev/sd[b-i]1 |grep "raid" || cat /proc/mdstat |grep "inactive" || ls /dev/md* |egrep md[0-9]+
                if [ $? = 0 ];then
                                echo "have some md don't clean"
				ls /dev/md* |egrep md[0-9]+
				for md_name in "$(ls /dev/md* |egrep md[0-9]+)" ;do
					mdadm --stop $md_name
					sleep 5
					echo "$md_name have stop"
				done
				rm -rf  /etc/mdadm.conf 
				mdadm -Ss;sleep 5
                                mdadm  --zero-superblock  /dev/sd[b-i]1
                            	mdadm  --zero-superblock /dev/sd[b-i]
                                cat /proc/mdstat
               			lsblk 
fi		
		echo "INFO:need to remove partition first"
		for i in b c d e f g h i ;do
			mdadm  --zero-superblock "/dev/sd$i"
			sleep 1
			gdisk /dev/sd$i  &> /dev/null  <<EOF
d
3
d
2
d
1
w
Y
EOF
			sleep 1
			partprobe /dev/sd$i 
		done

		echo "have been remove all partition,check it"
		lsblk;cat /proc/mdstat; ls /dev/md*
}
