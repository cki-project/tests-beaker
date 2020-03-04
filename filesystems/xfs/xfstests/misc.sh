#! /usr/bin/env bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   This file includes anything that does not fit in other categories
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

RHEL_NAME="RHEL"
# update the release name for RHEL-ALT
# /etc/redhat-release doesn't show if it's Pegas|Alt distro, seems we
# can only know from kernel version string, check if there's elNa,
# where N is RHEL major release number, e.g. el7a
if uname -r | grep -q el.a; then
	RHEL_NAME="RHELALT"
fi
RHEL_VERSION=$(egrep -o "[0-9]*\\.[0-9]* " /etc/redhat-release|tr '.' '_')
RHEL_MAJOR=$(echo $RHEL_VERSION|cut -d '_' -f 1)
RHEL_MINOR=$(echo $RHEL_VERSION|cut -d '_' -f 2)
if [[ -x /usr/bin/python ]]; then
	PYTHON_PROG=/usr/bin/python
elif [[ -x /usr/bin/python2 ]]; then
	PYTHON_PROG=/usr/bin/python2
elif [[ -x /usr/bin/python3 ]]; then
	PYTHON_PROG=/usr/bin/python3
elif [[ -x /usr/libexec/platform-python ]]; then
	PYTHON_PROG=/usr/libexec/platform-python
fi

# Returns non-zero value if any of the piped commands fails.
# This is a must for our test framework.
set -o pipefail

# Set FSCK variable to proper fs check utility
function set_fsck()
{
	FSCK="fsck.$FSTYPE"
	FSCK_OPTS=""
	FSCK_FIXOPTS=""
	case "$FSTYPE" in
	xfs)
		FSCK=xfs_repair
		FSCK_OPTS="-n"
		;;
	btrfs)
		FSCK=btrfsck
		;;
	gfs2)
		FSCK_OPTS="-n"
		;;
	ext2|ext3|ext4)
		FSCK_OPTS="-nf"
		FSCK_FIXOPTS="-yf"
		;;
	esac
}

# Initialize TEST_PARAM_FSTYPE variable (if not already set)
function init_test_param_fstype()
{
	test -n "$TEST_PARAM_FSTYPE" && return 0
	# If corresponded userspace uitls is available, set
	# default filesystem type by priority.
	if which mkfs.xfs ; then
		TEST_PARAM_FSTYPE="xfs"
		return
	fi
	if which mkfs.ext4 ; then
		TEST_PARAM_FSTYPE="ext4"
		return
	fi
	if which mkfs.ext3 ; then
		TEST_PARAM_FSTYPE="ext3"
		return
	fi
	if which mkfs.ext2 ; then
		TEST_PARAM_FSTYPE="ext2"
		return
	fi
	test -z "$TEST_PARAM_FSTYPE" && return 1
}

# The function converts postfix to a number
function conv_to_num()
{
	SIZE="$(echo $1 | head -c -2)"
	PFIX="$(echo $1 | tail -c 2 | tr '[A-Z]' '[a-z]')"

	case "$PFIX" in
		'k')
			echo "$SIZE * 1024"| bc -q
			;;
		'm')
			echo "$SIZE * 1048576" | bc -q
			;;
		'g')
			echo "$SIZE * 1073741824" | bc -q
			;;
		't')
			echo "$SIZE * 1099511627776" | bc -q
			;;
		'p')
			echo "$SIZE * 1125899906842624" | bc -q
			;;
		'e')
			echo "$SIZE * 1152921504606846976" | bc -q
			;;
		'z')
			echo "$SIZE * 1180591620717411303424" | bc -q
			;;
		'y')
			echo "$SIZE * 1208925819614629174706176" |bc -q
			;;
		*)
			echo "$1"
			;;
	esac
}

# Prints file to OUTPUTFILE as well as stdout
function echoo()
{
	echo $@ | tee -a $OUTPUTFILE
}

# Wrapper to rstrnt-report-result, clears $OUTPUTFILE
function report()
{
	WHAT="$TEST_ID:$1"
	STATUS="$2"
	SCORE="$3"
	test -z "$SCORE" && SCORE=0
	rstrnt-report-result "$WHAT" "$STATUS" "$SCORE"
	rm -f $OUTPUTFILE
	touch $OUTPUTFILE
}

# Wrapper to log the output of the command
function xlog()
{
	$@ 2>&1 | tee -a $OUTPUTFILE
	return $?
}

# Needs all the variables
function system_info()
{
	echoo -e "\n\n*************************************"
	echoo "KERNEL=$(uname -r)"
	# we care about the real version we're running, not the installed rpm package version
	echoo "XFSPROGS=$(mkfs.xfs -V | awk '{print $3}')"
	echoo "XFSDUMP=$(type xfsdump)"
	echoo "DBENCH=$(type dbench)"
	echoo "FIO=$(fio -v)"
	echoo "GITDATE=$GITDATE"
	#echoo "XFSTESTS=$(rpm -q xfstests)"
	echoo "RHEL_VERSION=$RHEL_VERSION"
	echoo "RHEL_MAJOR=$RHEL_MAJOR"
	echoo "LOOP=$LOOP"
	echoo "RHEL_MINOR=$RHEL_MINOR"
	echoo "FSTYPE=$FSTYPE"
	echoo "DEV_TYPE=$DEV_TYPE"
	echoo "TEST_DEV=$TEST_DEV"
	echoo "SCRATCH_DEV=$SCRATCH_DEV"
	echoo "LOGWRITES_DEV=$LOGWRITES_DEV"
	echoo "LOGWRITES_MNT=$LOGWRITES_MNT"
	echoo "SCRATCH_LOGDEV=$SCRATCH_LOGDEV"
	echoo "SCRATCH_RTDEV=$SCRATCH_RTDEV"
	echoo "TEST_DIR=$TEST_DIR"
	echoo "SCRATCH_MNT=$SCRATCH_MNT"
	echoo "RUNTESTS=$RUNTESTS"
	echoo "SKIPTESTS=$SKIPTESTS"
	echoo "MAX_SIZE=$MAX_SIZE"
	echoo "BLKSIZE=$BLKSIZE"
	echoo "MKFS_OPTS=$MKFS_OPTS"
	echoo "REPORT_PASS=$REPORT_PASS"
	echoo "CHECK_OPTS=$CHECK_OPTS"
	echoo "SKIP_LEVEL=$SKIP_LEVEL"
	echoo "NO_MKFS=$NO_MKFS"
	echoo "FSCK=$FSCK"
	echoo "FSCK_OPTS=$FSCK_OPTS"
	echoo -e "*************************************\n\n"

	report system_info PASS 0
}
