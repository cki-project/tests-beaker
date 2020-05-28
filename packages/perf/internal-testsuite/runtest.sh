#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /tools/perf/Regression/internal-testsuite-cki
#   Description: internal-testsuite
#   Author: Michael Petlan <mpetlan@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. ../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

# Known failure on Mustangs, skip this test until BZ 1619305 is resolved
if type -p dmidecode >/dev/null ; then
    if dmidecode -t1 | grep -q 'Product Name:.*Mustang.*' ; then
        rstrnt-report-result $TEST SKIP $OUTPUTFILE
        exit
    fi
fi

PACKAGE="perf"

# configuration
PERFTESTS_ENABLE_BLACKLIST=${PERFTESTS_ENABLE_BLACKLIST:-0}

# hook, someone likes using "True" there, we like 1, 0 values more
if [ "$PERFTESTS_ENABLE_BLACKLIST" = "true" -o "$PERFTESTS_ENABLE_BLACKLIST" = "True" ]; then
	PERFTESTS_ENABLE_BLACKLIST=1
fi

check_whitelisted()
{
	HASH=`echo -n "$1" | sha1sum | awk '{print $1}'`
	cat white.list | perl -pe 's/#.*$//' | grep $HASH | grep -q -e "all" -e "$ARCH"
	return $?
}

prepare_whitelists()
{
	rlRun "cp white.list $TmpDir/" 0 "WHITELIST: adding basic whitelist"
}

# return 0 when running kernel rt
is_kernel_rt()
{
	local kernel_name=$(uname -r)
	if [[ "$kernel_name" =~ "rt" ]]; then
		echo 0
	else
		echo 1
	fi
}

rlJournalStart
	rlPhaseStartSetup
		rlAssertRpm $PACKAGE
		rlCheckRpm python-perf || yum -y install python-perf
		export ARCH=`arch`
		export KERNEL=`uname -r`

		export KERNEL_PKG_NAME="kernel-$KERNEL"
		if [ $(is_kernel_rt) -eq 0 ]; then
			export KERNEL_DEBUGINFO_PKG_NAME="kernel-rt-debuginfo-$KERNEL"
		else
			export KERNEL_DEBUGINFO_PKG_NAME="kernel-debuginfo-$KERNEL"
		fi
		echo $KERNEL | grep -q debug
		if [ $? -eq 0 ]; then
			export KERNEL=${KERNEL%[.+]debug}
			if [ $(is_kernel_rt) -eq 0 ]; then
				export KERNEL_PKG_NAME="kernel-rt-debug-$KERNEL"
				export KERNEL_DEBUGINFO_PKG_NAME="kernel-rt-debug-debuginfo-$KERNEL"
			else
				export KERNEL_PKG_NAME="kernel-debug-$KERNEL"
				export KERNEL_DEBUGINFO_PKG_NAME="kernel-debug-debuginfo-$KERNEL"
			fi
		fi
		rlLog "Variables:"
		rlLog "KERNEL = $KERNEL"
		rlLog "KERNEL_PKG_NAME = $KERNEL_PKG_NAME"
		rlLog "KERNEL_DEBUGINFO_PKG_NAME = $KERNEL_DEBUGINFO_PKG_NAME"
		rpmquery $KERNEL_DEBUGINFO_PKG_NAME
		if [ $? -ne 0 ]; then
			# we need to install debuginfo for the proper kernel
			# but sometimes, debuginfo-install is not available!
			which debuginfo-install || rlRun "yum -y install yum-utils dnf-utils" 0 "Installing {yum,dnf}-utils (it has not been present)"
			which debuginfo-install # now it should be installed, but what if it fails...
			if [ $? -eq 0 ]; then
				rlRun "yum install -y $KERNEL_DEBUGINFO_PKG_NAME" 0 "Installing debuginfo for $KERNEL_PKG_NAME via yum/dnf (unable to obtain debuginfo-install)"
			fi
		fi
		rlRun "rpmquery $KERNEL_DEBUGINFO_PKG_NAME" 0 "Correct debuginfo is installed ($KERNEL)"
                # return Skip when correct kernel debug is not installed
                if [ $? -ne 0 ]; then
                    echo "Correct kernel debuginfo pkg: ${KERNEL_DEBUGINFO_PKG_NAME} is not installed" | tee -a ${OUTPUTFILE}
                    rstrnt-report-result $TEST SKIP $OUTPUTFILE
                    exit 0
                fi
		echo "==================== kernel packages installed ===================="
		rpmquery -a | grep -e kernel -e perf
		echo "==================================================================="
		rlCheckRpm $PACKAGE-debuginfo || rlRun "debuginfo-install -y $PACKAGE"
		rlAssertRpm $PACKAGE-debuginfo
		# we need iputils-debuginfo for the sake of `perf test inet_pton` testcase
		rlCheckRpm iputils-debuginfo || rlRun "debuginfo-install -y iputils"
		rlAssertRpm iputils-debuginfo

		mkdir TMP ; cd TMP
		export TmpDir=`pwd`
		cd ..

		# PREPARE WHITELISTS
		prepare_whitelists

		# This is important: remember the original sample rate to be restored later
		#
		# Various heavy tests may lead to that kernel throttles the sample rate too much
		# which may cause other tests to fail and such failures look mysterious and are
		# hard to investigate and reproduce. This should harden the test to be less prone
		# to this type of problems.
		ORIGINAL_SAMPLE_RATE=`sysctl kernel.perf_event_max_sample_rate | tr -d ' ' | cut -d= -f2`
		echo "ORIGINAL SAMPLE RATE = $ORIGINAL_SAMPLE_RATE" | tee -a ${OUTPUTFILE}
		REASONABLE_SAMPLE_RATE=20000
		if [ $ORIGINAL_SAMPLE_RATE -lt $REASONABLE_SAMPLE_RATE ]; then
			echo "(it seems to be too low, so increasing it to $REASONABLE_SAMPLE_RATE" | tee -a ${OUTPUTFILE}
			ORIGINAL_SAMPLE_RATE=$REASONABLE_SAMPLE_RATE
		fi

		rlRun "pushd $TmpDir >/dev/null"
		rlRun "perf test list |& tee tests.list" 0 "We will run the following tests:"
	rlPhaseEnd

	while read line; do
		TEST_NUMBER="`echo $line | perl -ne 'print $1 if /^(\d+):\s/'`"
		TEST_DESC="`echo $line | perl -pe 's/^\d+:\s//'`"
		# skip the incompatible lines (basically the subtests)
		test -n "$TEST_NUMBER" || continue
		rlPhaseStart FAIL "TEST #$TEST_NUMBER : $TEST_DESC"
			if check_whitelisted "$TEST_DESC"; then
				rlLog "[ WHITELISTED ] :: $TEST_NUMBER: $TEST_DESC  (known issue)"
			else
				perf test -vv $TEST_NUMBER &>  $TEST_NUMBER.log
				RETVAL=$?
				cat $TEST_NUMBER.log
				RESULT=`tail -n 1 $TEST_NUMBER.log | awk -F':' '{print $NF}' | tr -d ' '`
				printf "%8s -- %s\n" $RESULT "$line" | tee -a results.log
				echo $RESULT | grep -qi FAIL
				if [ $RETVAL -ne 0 -o $? -eq 0 ]; then
					rlFail "$TEST_NUMBER: $TEST_DESC"
				else
					rlPass "$TEST_NUMBER: $TEST_DESC"
				fi

				# restore original sample rate to ensure the tests dependent on it pass
				# more info: https://bugzilla.redhat.com/show_bug.cgi?id=1532741#c18
				sysctl kernel.perf_event_max_sample_rate=$ORIGINAL_SAMPLE_RATE
			fi
		rlPhaseEnd
	done < tests.list

	# bz1414043 coverage
	rlPhaseStartTest "bz1414043 coverage -- \"Session topology\" test fails with some CPUs disabled"
		# check if we have enough CPUs (at least two)
		if [ `nproc` -lt 2 ]; then
			rlLog "bz1414043 coverage skipped (we need at least 2 cpus)"
		else
			# check if the test is not disabled on this machine
			TEST_NUMBER="`perf test list |& grep topology | perl -ne 'print $1 if /^(\d+):\s/'`"
			TEST_DESC="`perf test list |& grep topology | perl -pe 's/^\d+:\s//'`"
			if check_whitelisted "$TEST_DESC" || check_whitelisted "Session topology with CPU disabled"; then
				rlLog "bz1414043 coverage skipped (whitelisted)"
			else
				# check if we can disable a cpu (we sometimes cannot on aarch64)
				echo 0 > /sys/devices/system/cpu/cpu1/online
				if [ $? -ne 0 ]; then
					rlLog "bz1414043 coverage skipped (cannot turn cpu1 off)"
				else
					# now it should be OK, so test!
					rlRun "perf test -v topology" 0 "bz1414043 test (should PASS)" # BUG REPRODUCTION ASSERT
					rlRun "echo 1 > /sys/devices/system/cpu/cpu1/online" 0 "Turning the cpu1 back on"
				fi
			fi
		fi
	rlPhaseEnd

	# this test is suitable for kernels version 3 and newer
	KERNEL_MAJOR_VERSION=`uname -r | perl -ne 'print "$1" if /^(\d+)\./'`
	if [ $KERNEL_MAJOR_VERSION -ge 3 ]; then
	# bz1308907 coverage
	rlPhaseStartTest "bz1308907 coverage -- FAILED '/usr/libexec/perf-core/tests/attr/test-stat-C0' - match failure"
		# check if the test is not disabled on this machine
		TEST_NUMBER="`perf test list |& grep perf_event_attr | perl -ne 'print $1 if /^(\d+):\s/'`"
		TEST_DESC="`perf test list |& grep perf_event_attr | perl -pe 's/^\d+:\s//'`"
		if check_whitelisted "$TEST_DESC"; then
			rlLog "bz1308907 coverage skipped (whitelisted)"
		else
			# the corresponding perf-test should NOT contain the following line in the output:
			# FAILED '/usr/libexec/perf-core/tests/attr/test-stat-C0' - match failure
			rlRun "perf test -v $TEST_NUMBER |& grep FAILED" 1 "bz1308907 test (should PASS)" # BUG REPRODUCTION ASSERT
		fi
	rlPhaseEnd
	fi

	rlPhaseStartCleanup
		rlRun "tar c * | xz > logs-`date +%s`.tar.xz"
		rlFileSubmit "logs-*.tar.xz"
		echo "===========================[ results ]============================="
		cat results.log
		echo "==================================================================="
		rlRun -l "cat results.log | grep FAILED" 1 "No tests failed"
		rlRun "popd >/dev/null"
		rlRun "rm -rf $TmpDir"
		# restore the sample rate back to the original or something reasonable
		sysctl kernel.perf_event_max_sample_rate=$ORIGINAL_SAMPLE_RATE
	rlPhaseEnd
rlJournalPrintText
rlJournalEnd
