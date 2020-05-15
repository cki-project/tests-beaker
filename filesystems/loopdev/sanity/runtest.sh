#!/bin/sh

# Source the common test script helpers
. ../../../cki_lib/libcki.sh || exit 1

TEST="filesystems/loopdev/sanity"
LOOKASIDE="http://www.iozone.org/src/current"
TARGET="iozone3_489"

PS4='+ $(date "+%s.%N")\011 '
set -x

storage_path=/mnt/testarea/loopdev_test.img
mnt_path=/mnt/loopsanity

# skip btrfs for now, since mkfs.btrfs refuses to work on file
filesystems="ext2 ext3 ext4 xfs"
declare -A mkfs_args
mkfs_args[ext2]="-F $storage_path"
mkfs_args[ext3]="-F $storage_path"
mkfs_args[ext4]="-F $storage_path"
mkfs_args[xfs]="-f -d file,size=512m,name=$storage_path"
mkfs_args[btrfs]="-f $storage_path"

RunTest()
{
    fs=$1

    mkfs.$fs ${mkfs_args[$fs]} 2>&1
    if [ $? -ne 0 ]; then
        echo "Failed creating fs:$fs"
        return 2
    fi

    mkdir -p $mnt_path
    mount -o loop $storage_path $mnt_path
    if [ $? -ne 0 ]; then
        echo "Failed mounting $storage_path to $mnt_path"
        return 3
    fi

    ./iozone -f $mnt_path/testfile -B -s 32535 -m 2>&1
    if [ $? -ne 0 ]; then
        killall -9 iozone
        umount $mnt_path
        echo "iozone failed"
        return 4
    fi

    umount $mnt_path
    if [ $? -ne 0 ]; then
        echo "Failed umounting $mnt_path"
        return 5
    fi

    return 0
}


# Main Test
echo "compiling $TARGET ..." | tee -a $OUTPUTFILE
wget ${LOOKASIDE}/${TARGET}.tar
tar -xvf ${TARGET}.tar
make -C ${TARGET}/src/current/ linux
cp -f ${TARGET}/src/current/iozone ./
if [ $? -ne 0 ]; then
      rstrnt-report-result $TEST WARN
      # Abort the task
      rstrnt-abort --server $RSTRNT_RECIPE_URL/tasks/$TASKID/status
      exit 0
fi

echo "Test is starting." | tee -a $OUTPUTFILE
fallocate -l512M $storage_path 2>&1 >> $OUTPUTFILE
if [ $? -ne 0 ]; then
    echo "Failed creating $storage_path" | tee -a $OUTPUTFILE
    exit 1
fi

for fs in $filesystems; do
    if command -v mkfs.$fs; then
        echo "Starting test for $fs" | tee -a $OUTPUTFILE
        RunTest $fs >> $OUTPUTFILE 2>&1
        ret=$?
        if [ $ret -eq 0 ]; then
            echo "$fs PASSed" | tee -a $OUTPUTFILE
            rstrnt-report-result $fs PASS 0
        else
            echo "$fs FAILed" | tee -a $OUTPUTFILE
            rstrnt-report-result $fs FAIL $ret
        fi
        cat $OUTPUTFILE
        echo > $OUTPUTFILE
    fi
done

rm -f $storage_path 2>&1 >> $OUTPUTFILE

echo "Test finished" | tee -a $OUTPUTFILE
rstrnt-report-result finished PASS 0

exit 0
