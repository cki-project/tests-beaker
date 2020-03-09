#!/bin/sh

# Source the common test script helpers
. /usr/bin/rhts_environment.sh

PS4='+ $(date "+%s.%N")\011 '
#set -x

storage_path=/mnt/testarea
i=0
ret=0

function make_storage_file()
{
	local retval="$1"
	local name="$2"
	local size="$3"
	fallocate -l$size $storage_path/$name 2>&1 >> $OUTPUTFILE
	if [ $? -ne 0 ]; then
		echo "Failed creating $storage_path/$name" | tee -a $OUTPUTFILE
		return 1
	fi
	eval $retval="$storage_path/$name"
	return 0
}

function make_loop_dev()
{
	local retval="$1"
	local size="$2"
	local loname=$(losetup -f)
	local storage=""

	i=$((i+1))
	make_storage_file storage storage$i $size

	losetup $loname $storage
	if [ $? -ne 0 ]; then
		echo "Failed setting up loopdev $loname for $storage" | tee -a $OUTPUTFILE
		return 1
	fi
	eval $retval="$loname"
	return 0
}

function clean_loop_dev()
{
	local loopdev=$1
	local file=$(losetup $loopdev | awk '{print $3}' | sed 's/^(//' | sed 's/)$//')
	losetup -d $loopdev
	test -f "$file" && rm -f $file
}

	
function rcmd()
{
	local cmd="$*"
	local _ret=0
	echo "$cmd" | tee -a $OUTPUTFILE
	eval $cmd > cmdlog.txt 2>&1
	_ret=$?
	cat cmdlog.txt | tee -a $OUTPUTFILE
	echo " --> ret $_ret" | tee -a $OUTPUTFILE
	ret=$((ret | $_ret))	
}

size_free=`df -BM $storage_path | tail -1 | awk '{ print $4 }' | sed "s/M//"`
# in M, adjust this manually according to make_loop_dev loopdev1 commands below
size_requested=1024

# SKIP test if there's not enough space on target device
if [[ $size_requested -gt $size_free ]]; then
  rstrnt-report-result $TEST SKIP $OUTPUTFILE
  exit
fi
rcmd make_loop_dev loopdev1 512M
rcmd make_loop_dev loopdev2 512M

devs="$loopdev1 $loopdev2"

rcmd pvcreate -ff $devs
rcmd pvs

rcmd vgcreate myvg $devs
rcmd vgs

for j in `seq 1 4`; do
	rcmd lvremove -ff myvg
	rcmd lvcreate -l 100%PV -T myvg/mythinpool
done

rcmd lvs

for j in `seq 1 4`; do
	rcmd lvcreate -V512M -T myvg/mythinpool -n thinvolume$j
	rcmd mkdir -p /mnt/testmnt$j
	rcmd mkfs.xfs -f /dev/mapper/myvg-thinvolume$j

	rcmd mount /dev/mapper/myvg-thinvolume$j /mnt/testmnt$j
	rcmd umount /mnt/testmnt$j

	rcmd lvcreate -s -kn --name mysnapshot$j myvg/thinvolume$j
	rcmd mount /dev/mapper/myvg-mysnapshot$j /mnt/testmnt$j
	rcmd umount /mnt/testmnt$j

	rcmd lvcreate -s -kn --name mysnapshot2$j myvg/mysnapshot$j
	rcmd mount /dev/mapper/myvg-mysnapshot2$j /mnt/testmnt$j
	rcmd umount /mnt/testmnt$j
done

rcmd lvs

for j in `seq 1 2`; do
	rcmd mount /dev/mapper/myvg-thinvolume$j /mnt/testmnt$j
	./iozone -f /mnt/testmnt$j/testfile -B -s 32535 -m 2 -Z
	rcmd umount /mnt/testmnt$j

	rcmd mount /dev/mapper/myvg-mysnapshot$j /mnt/testmnt$j
	./iozone -f /mnt/testmnt$j/testfile -B -s 32535 -m 2 -Z
	rcmd umount /mnt/testmnt$j

	rcmd mount /dev/mapper/myvg-mysnapshot2$j /mnt/testmnt$j
	./iozone -f /mnt/testmnt$j/testfile -B -s 32535 -m 2 -Z
	rcmd umount /mnt/testmnt$j
done

rcmd lvs
rcmd ls -la /dev/mapper

rcmd lvremove -ff myvg

rcmd vgremove -ff myvg
rcmd pvremove -ff $devs

rcmd clean_loop_dev $loopdev1
rcmd clean_loop_dev $loopdev2

rcmd lvs
rcmd vgs
rcmd pvs

echo "Test finished" | tee -a $OUTPUTFILE

if [ $ret -eq 0 ]; then
	rstrnt-report-result finished PASS 0
else
	rstrnt-report-result finished FAIL $ret
fi

exit 0
