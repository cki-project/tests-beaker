#! /bin/bash -x
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   This file includes xfstests preset functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Set up xfstests environment, set default values
# Sets TEST_DIR, SCRATCH_MNT, REPORT_PASS, REPORT_FAIL, LOOP, SKIP_LEVEL
function preset_default()
{
	# Set the default git date for xfstests
	# the -N postfix specifies the release number for the git snapshot date
	GITDATE=20181015-1
	# RHEL5/6 almost reaches EOL, stay in fixed xfstests version, no new tests
	if [ $RHEL_MAJOR -eq 5 ]; then
		GITDATE=20140212-2
	elif [ $RHEL_MAJOR -eq 6 ]; then
		GITDATE=20160621-1
	fi

	# Set up xfstests environment, set default values
	TEST_DIR=/mnt/testarea/test
	SCRATCH_MNT=/mnt/testarea/scratch

	# Initialize the TEST_PARAM_FSTYPE variable (if not set)
	init_test_param_fstype

	# Only test for default block size by default
	BLKSIZES="default"

	# Turn off verbose mode by default
	REPORT_PASS=0
	REPORT_FAIL=0

	# Run the tests only once by default
	LOOP=1

	# The default skip level is 1
	SKIP_LEVEL=1

	# The root dir of beaker test
	XFSTESTS_BEAKER_ROOT=`pwd`

	# enable user namespace, RHEL7 turns it off by default.
	# this would enable generic/317 and generic/318 on RHEL7, which are
	# userns tests
	sysctl user.max_user_namespaces=15075 >/dev/null 2>&1
}


# Needs TEST_PARAM_<param> and sets <param>
function preset_testparams()
{
	# Set TEST_PARAMS
	# Pick up vars from the workflow/recipe if they're set
	test -n "${TEST_PARAM_GITDATE}" && GITDATE="${TEST_PARAM_GITDATE}"
	test -n "${TEST_PARAM_GITBRANCH}" && GITBRANCH="${TEST_PARAM_GITBRANCH}"
	test -n "${TEST_PARAM_GITREPO}" && GITREPO="${TEST_PARAM_GITREPO}"
	export GITREPO=git://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git
	test -n "${TEST_PARAM_TEST_DEV}" && TEST_DEV="${TEST_PARAM_TEST_DEV}"
	test -n "${TEST_PARAM_TEST_DIR}" && TEST_DIR="${TEST_PARAM_TEST_DIR}"
	test -n "${TEST_PARAM_SCRATCH_DEV}" && SCRATCH_DEV="${TEST_PARAM_SCRATCH_DEV}"
	test -n "${TEST_PARAM_SCRATCH_LOGDEV}" && SCRATCH_LOGDEV="${TEST_PARAM_SCRATCH_LOGDEV}"
	test -n "${TEST_PARAM_SCRATCH_RTDEV}" && SCRATCH_RTDEV="${TEST_PARAM_SCRATCH_RTDEV}"
	test -n "${TEST_PARAM_SCRATCH_MNT}" && SCRATCH_MNT="${TEST_PARAM_SCRATCH_MNT}"
	test -n "${TEST_PARAM_SCRATCH_DEV_POOL}" && SCRATCH_DEV_POOL="${TEST_PARAM_SCRATCH_DEV_POOL}"
	test -n "${TEST_PARAM_SCRATCH_DEV_POOL_MNT}" && SCRATCH_DEV_POOL_MNT="${TEST_PARAM_SCRATCH_DEV_POOL_MNT}"
	test -n "${TEST_PARAM_REPORT_PASS}" && REPORT_PASS="${TEST_PARAM_REPORT_PASS}"
	test -n "${TEST_PARAM_REPORT_FAIL}" && REPORT_FAIL="${TEST_PARAM_REPORT_FAIL}"
	test -n "${TEST_PARAM_LOOP}" && LOOP="${TEST_PARAM_LOOP}"
	test -n "${TEST_PARAM_SKIP_LEVEL}" && SKIP_LEVEL="${TEST_PARAM_SKIP_LEVEL}"
	test -n "${TEST_PARAM_MKFS_OPTS}" && MKFS_OPTS="${TEST_PARAM_MKFS_OPTS}"
	test -n "${TEST_PARAM_MOUNT_OPTS}" && MOUNT_OPTS="${TEST_PARAM_MOUNT_OPTS}"
	test -n "${TEST_PARAM_TEST_FS_MOUNT_OPTS}" && TEST_FS_MOUNT_OPTS="${TEST_PARAM_TEST_FS_MOUNT_OPTS}"
	test -n "${TEST_PARAM_CHECK_OPTS}" && CHECK_OPTS="${TEST_PARAM_CHECK_OPTS}"
	test -n "${TEST_PARAM_CHECK_GROUPS}" && CHECK_GROUPS="${TEST_PARAM_CHECK_GROUPS}"
	test -n "${TEST_PARAM_SKIPTESTS}" && SKIPTESTS="${SKIPTESTS} ${TEST_PARAM_SKIPTESTS}"
	test -n "${TEST_PARAM_RUNTESTS}" && RUNTESTS="${TEST_PARAM_RUNTESTS}"
	# These last two need a bit of special treatment (notice the plural form)
	test -n "${TEST_PARAM_FSTYPE}" && FSTYPES="${TEST_PARAM_FSTYPE}"
	test -n "${TEST_PARAM_OVERLAY_BASE_FSTYPE}" && OVLBASEFSTYP="${TEST_PARAM_OVERLAY_BASE_FSTYPE}"
	test -n "${TEST_PARAM_BLKSIZE}" && BLKSIZES="${TEST_PARAM_BLKSIZE}"
	test -n "${TEST_PARAM_DEV_TYPE}" && DEV_TYPE="${TEST_PARAM_DEV_TYPE}"
	test -n "${TEST_PARAM_CIFS_MOUNT_OPTS}" && CIFS_MOUNT_OPTIONS="${TEST_PARAM_CIFS_MOUNT_OPTS}"
	test -n "${TEST_PARAM_KNOWN_ISSUE}" && KNOWN_ISSUE="${TEST_PARAM_KNOWN_ISSUE}"
	test -n "${TEST_PARAM_TEST_ID}" && TEST_ID="${TEST_PARAM_TEST_ID}"
	test -n "${TEST_PARAM_LOGWRITES_DEV}" && LOGWRITES_DEV="${TEST_PARAM_LOGWRITES_DEV}"
	test -n "${TEST_PARAM_LOGWRITES_MNT}" && LOGWRITES_MNT="${TEST_PARAM_LOGWRITES_MNT}"
	# use $FSTYPES as TEST_ID if not set
	if [ -z "$TEST_ID" ]; then
		TEST_ID=$FSTYPES
	fi
}

# Needs GITDATE for install_xfstests (sourced)
# Sets TEST_DIR, SCRATCH_MNT, REPORT_PASS, LOOP, installeddistro and kernbase
function preset_common()
{
	# Some tests require an "fsgqa" user
	xlog grep -w fsgqa /etc/passwd || /usr/sbin/useradd fsgqa
	if [ ! "$?" = 0 ]; then
		echoo "Failed to create fsgqa user."
		report setup FAIL 0
		exit 0
	fi

	# Some tests require an "123456-fsgqa" user
	xlog grep 123456-fsgqa /etc/passwd || /usr/sbin/useradd 123456-fsgqa
	if [ ! "$?" = 0 ]; then
		echoo "Failed to create 123456-fsgqa user."
		report setup FAIL 0
		exit 0
	fi

	# Disable lookup passwd through NIS by setting domainname to "(none)"
	# Otherwise acl related tests will get something like(on some hosts):
	# No such map passwd.byname. Reason: Can't bind to server which serves this domain
	domainname "(none)"

	# Running updatedb while the tests go slows things down
	service crond stop

	# trap exit, please redefine cleanup to proper cleanup function if you use this file in a different test
	trap "cleanup;exit \$status" 0 1 2 3 15

	# Install few utilities [xfsprogs, xfsdump, dbench, fio].
	# Necessary for rhel5/6 as xfsprogs is in ScalableFS channel that is not present in default beaker installations.
	# However, if the utilities are already installed they will not be overwritten.
	install_xfs

	# Install xfstests
	# Check and report exit value
	# The failure of this step is fatal
	install_xfstests

	# Create the default mount points...
	xlog mkdir -p $TEST_DIR
	xlog mkdir -p $SCRATCH_MNT
	if [ ! -d $TEST_DIR -o ! -d $SCRATCH_MNT ]; then
		echoo "Test dir $TEST_DIR or scratch dir $SCRATCH_MNT could not be created."
		report setup FAIL 0
		exit 0
	fi
}

# This should preset test environment properly
# Almost no parameters are necessary at this stage
# Sets TEST_PARAM_FSTYPE (if empty) and GITDATE
function preset_full()
{
	# Set default values of all the variables that need them
	preset_default
	# Update default params by TEST_PARAM_ parameters
	preset_testparams
	# Initial/generic setup (before test parameters)
	preset_common
	report preset_done PASS 0
}
