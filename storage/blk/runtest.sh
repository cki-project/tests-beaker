#!/bin/sh
#
# Copyright (c) 2019 Red Hat, Inc. All rights reserved.
#
# This copyrighted material is made available to anyone wishing
# to use, modify, copy, or redistribute it subject to the terms
# and conditions of the GNU General Public License version 2.
#
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
#

if [[ ${_DEBUG_MODE} == "yes" ]]; then
	#
	# XXX: Don't involve the test harness if debug mode is enabled which
	#      is very helpful to manually run a single case without invoking
	#      function report_result() provided by test harness
	#
	function report_result { echo "$@"; }
else
	source /usr/bin/rhts_environment.sh
fi

NAME=$(basename $0)
CDIR=$(dirname $0)

function is_rhel7
{
	#
	# XXX: _TREE is set in kpet-db via:
	#
	#      {% if TREE == "rhel7" %}
	#          <param name="_TREE" value="rhel7"/>
	#      {% else %}
	#          <param name="_TREE" value="rhel8|ark|upstream"/>
	#      {% endif %}
	#
	[[ ${_TREE} == "rhel7" ]] && return 0 || return 1
}

function get_timestamp
{
	date +"%Y-%m-%d %H:%M:%S"
}

function get_test_result
{
	typeset test_ws=$1
	typeset test_case=$2

	typeset result_dir="$test_ws/results"
	typeset result_file=$(find $result_dir -type f | egrep "$test_case")
	typeset result="UNTESTED"
	if [[ -n $result_file ]]; then
		typeset res=$(egrep "^status" $result_file | awk '{print $NF}')
		if [[ $res == *"pass" ]]; then
			result="PASS"
		elif [[ $res == *"fail" ]]; then
			result="FAIL"
		else
			result="OTHER"
		fi
	fi

	echo $result
}

function do_test
{
	typeset test_ws=$1
	typeset test_case=$2

	typeset this_case=$test_ws/tests/$test_case
	echo ">>> $(get_timestamp) | Start to run test case $this_case ..."
	(cd $test_ws && ./check $test_case)
	typeset result=$(get_test_result $test_ws $test_case)
	echo ">>> $(get_timestamp) | End $this_case | $result"

	typeset -i ret=0
	if [[ $result == "PASS" ]]; then
		report_result "$TEST/tests/$test_case" PASS 0
		ret=0
	elif [[ $result == "FAIL" ]]; then
		report_result "$TEST/tests/$test_case" FAIL 1
		ret=1
	else
		report_result "$TEST/tests/$test_case" WARN 2
		ret=2
	fi

	return $ret
}

function get_test_cases_block
{
	typeset testcases=""
	if is_rhel7; then
		#
		# XXX: There are 27 cases of block testing, and these cases
		#      in the following are not available to run
		#      - block/003 # XXX: Test device is required
		#      - block/004 # XXX: Test device is required
		#      - block/005 # XXX: Test device is required
		#      - block/006
		#      - block/007 # XXX: Test device is required
		#      - block/008
		#      - block/010
		#      - block/011 # XXX: Test device is required
		#      - block/012 # XXX: Test device is required
		#      - block/013 # XXX: Test device is required
		#      - block/014
		#      - block/015
		#      - block/017
		#      - block/018
		#      - block/019
		#      - block/021
		#      - block/022
		#      - block/024
		#      - block/026
		#      - block/028
		#
		testcases+=" block/001"
		#testcases+=" block/002" # Test case issue: https://lore.kernel.org/linux-block/e84b29e1-209e-d598-0828-bed5e3b98093@acm.org/
		#testcases+=" block/009" # Fail randomly on x86_64, powerpc
		testcases+=" block/016"
		#testcases+=" block/020" # Fail randomly on arm64, powerpc
		testcases+=" block/021"
		testcases+=" block/023"
		#testcases+=" block/025" # Fail randomly on powerpc
	else
		#
		# XXX: There are 27 cases of block testing, and these cases
		#      in the following are not available to run
		#      - block/003 # XXX: Test device is required
		#      - block/004 # XXX: Test device is required
		#      - block/005 # XXX: Test device is required
		#      - block/007 # XXX: Test device is required
		#      - block/008
		#      - block/010 # XXX: Oops
		#      - block/011 # XXX: Test device is required
		#      - block/012 # XXX: Test device is required
		#      - block/013 # XXX: Test device is required
		#      - block/014
		#      - block/015
		#      - block/019
		#      - block/022
		#      - block/024
		#      - block/026
		#      - block/028
		#
		testcases+=" block/001"
		#testcases+=" block/002" # Test case issue: https://lore.kernel.org/linux-block/e84b29e1-209e-d598-0828-bed5e3b98093@acm.org/
		testcases+=" block/006"
		#testcases+=" block/009" # Fail randomly on x86_64, powerpc
		testcases+=" block/016"
		#block/017 fails on s390x
		uname -i | grep -q s390x || testcases+=" block/017"
		testcases+=" block/018"
		#testcases+=" block/020" # Fail randomly on arm64, powerpc
		testcases+=" block/021"
		testcases+=" block/023"
		#testcases+=" block/025" # Fail randomly on powerpc
	fi
	echo $testcases
}

function get_test_cases_loop
{
	typeset testcases=""
	if is_rhel7; then
		#
		# XXX: There are 7 cases of loop testing, and these cases
		#      in the following are not available to run
		#      - loop/002
		#      - loop/004
		#      - loop/007
		testcases+=" loop/001"
		testcases+=" loop/003"
		testcases+=" loop/005"
		testcases+=" loop/006"
	else
		#
		# XXX: There are 7 cases of loop testing, and these cases
		#      in the following are not available to run
		#      - loop/006
		#      - loop/007
		#
		uname -r | grep -q 5.0 || testcases+=" loop/001" # Fails on 5.0
		#testcases+=" loop/002" # Fails randomly on x86_64
		testcases+=" loop/003"
		#testcases+=" loop/004" # Fails randomly on powerpc
		testcases+=" loop/005"
	fi
	echo $testcases
}

testcases_default=""
testcases_default+=" $(get_test_cases_block)"
testcases_default+=" $(get_test_cases_loop)"
testcases=${_DEBUG_MODE_TESTCASES:-"$(echo $testcases_default)"}
test_ws=$CDIR/blktests
ret=0
for testcase in $testcases; do
	do_test $test_ws $testcase
	((ret += $?))
done

if [[ $ret -ne 0 ]]; then
	echo ">> There are failing tests, pls check it"
fi

exit 0
