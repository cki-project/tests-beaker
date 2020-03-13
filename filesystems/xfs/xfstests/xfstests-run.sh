#! /bin/bash -x
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   This file includes xfstests functions concerning a test run
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Needs RUNTESTS, SKIPTESTS, MKFS_OPTS, FSCK_OPTS, CHECK_OPTS and REPORT_PASS, REPORT_FAIL, KNOWN_ISSUE
function check_tests()
{
	for XFSTEST in $RUNTESTS; do
		ret=0
		# Skip tests that are failing, for now.  Some need fixing, others expected
		if echo $SKIPTESTS | grep -qw $XFSTEST; then
			echoo "Skipping test $XFSTEST due to known failure"
			continue
		fi
		if echo $SKIPTESTS | grep -q "\([^/]\|^\)[[:digit:]]\{3\}"; then
			# We have old style test seq number in SKIPTESTS, e.g. 300
			# filter all tests with the same seq number, no matter it's
			# generic/300 or xfs/300
			if echo $SKIPTESTS | grep -q "\([^/]\|^\)$(basename $XFSTEST)"; then
				echoo "Skipping test $XFSTEST due to known failure"
				continue
			fi
		fi

		echoo "Running test $XFSTEST"
		if test -f tests/$XFSTEST; then
			xlog head -n 10 tests/$XFSTEST
		else
			echoo "The test $XFSTEST does not seem to exist."
			continue
		fi
		MOUNT_OPTIONS="$MOUNT_OPTS" MKFS_OPTIONS="$MKFS_OPTS" xlog ./check $CHECK_OPTS $XFSTEST
		ret=$?

		# Construct XFSTEST_LOGNAME, used for submitting logs to beaker to avoid
		# overwriting test logs with the same seq number under different dirs.
		# e.g. if both generic/300 and ext4/300 fail, log file to be submitted
		# are both 300.full/300.out.bad
		# Rename log file by adding dir name prefix, so results/generic/300.full
		# will be results/generic/generic-300.full, results/ext4/300.full will be
		# results/ext4/ext4-300.full
		XFSTEST_LOGNAME=$(dirname $XFSTEST)/${XFSTEST/\//-}
		if test $ret -ne 0; then
			if [ -f results/$XFSTEST.full ]; then
				cp results/$XFSTEST.full results/$XFSTEST_LOGNAME.full
				rstrnt-report-log -l results/$XFSTEST_LOGNAME.full
			fi
			if [ -f results/$XFSTEST.out.bad ]; then
				cp results/$XFSTEST.out.bad results/$XFSTEST_LOGNAME.out.bad
				rstrnt-report-log -l results/$XFSTEST_LOGNAME.out.bad
				# Gather the full diff
				diff -u <(tr '`' "'" < tests/$XFSTEST.out) results/$XFSTEST.out.bad  > results/$XFSTEST_LOGNAME.out.bad.diff
				rstrnt-report-log -l results/$XFSTEST_LOGNAME.out.bad.diff
			fi
			if [ -f results/$XFSTEST.dmesg ]; then
				cp results/$XFSTEST.dmesg results/$XFSTEST_LOGNAME.dmesg
				rstrnt-report-log -l results/$XFSTEST_LOGNAME.dmesg
			fi
			ret=1
			report $XFSTEST FAIL 0
			# Work around, so that loop device bug does not interrupt the test, might be nice to do the same with the dm device release bug
			release_loops
		elif test "$REPORT_PASS" == "1"; then
			TESTTIME=`grep -w ^$XFSTEST results/check.time | awk '{print $2}'`
			if [ -f results/$XFSTEST.notrun ]; then
				XFSTEST="$XFSTEST[notrun]"
			fi
			report $XFSTEST PASS $TESTTIME
		fi

		if test $ret -eq 0; then
			PASSED="$PASSED $XFSTEST"
		else
			FAILED="$FAILED $XFSTEST"
		fi
	done
	test -z "$FAILED"
	return $?
}


function create_test_report()
{
	RESULT=PASS
	echoo "============ TEST REPORT ============"

	echoo -e "\n\n\n======== FAILED TESTS ========"
	for TEST in $(echo $FAILED | tr " " "\n" | sort -u); do
		if grep -qw $TEST known_issues ; then
			echoo -e "\n\n ==== $RHEL_VERSION|$FSTYPE|$TEST ====\nKnown failure, WAIVED"
		else
			echoo -e "\n\n ==== $RHEL_VERSION|$FSTYPE|$TEST ====\nUnknown failure, ERROR"
			RESULT=FAIL
		fi
	done

	report TEST_REPORT $RESULT 0
}


# Needs SKIPTESTS, RUNTESTS,
function check()
{
	local groups="${CHECK_GROUPS:-auto}"

	FAILED=""
	PASSED=""
	# And go!
	pushd /var/lib/xfstests/

	# Run all "auto" tests, excluding dmapi if FSTYPE is xfs
	# If FSTYPE is not xfs, -x dmapi would cause check to generate empty $RUNTESTS list with newer xfstests version
	if [ -z "$RUNTESTS" ]; then
		if [ "$FSTYPE" == "xfs" ]; then
			./check -n $CHECK_OPTS -g $groups -x dmapi | grep -E "^$FSTYPE/|^generic/|^shared/|^[[:digit:]]{3}$" >alltests.log
		else
			./check -n $CHECK_OPTS -g $groups | grep -E "^$FSTYPE/|^generic/|^shared/|^[[:digit:]]{3}$" >alltests.log
		fi
	else
		echo $RUNTESTS > alltests.log
	fi
	rstrnt-report-log -l alltests.log
	RUNTESTS=`cat alltests.log`
	if [ -z "$RUNTESTS" ]; then
		report RUNTESTS FAIL 0
		popd
		return 1
	fi

	for ((n=0;n<$LOOP;n++));do
		check_tests
	done

	# Loop until a fail is detected if LOOP=0
	if test $LOOP -eq 0; then
		while check_tests; do :;done
	fi
	popd
	create_test_report
	return 0
}

function run_full()
{
	# Just run the default preset function
	preset_full
	for FSTYPE in $FSTYPES; do
		# The variable BLKSIZES was set in preset_full
		# preset_full function
		# setup_blksize will handle this case properly and it won't
		# modify MKFS_OPTS based on this
		for BLKSIZE in $BLKSIZES; do
			# Now to the full fs-dependent setup
			setup_full
			# Now print the test info
			# It should print all the test variables
			system_info
			# And now, just run the test
			check
		done
	done
}
