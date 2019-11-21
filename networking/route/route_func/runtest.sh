#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /installation/nic/Sanity/ixgbe
#   Description: What the test does
#   Author: Jianlin Shi<jishi@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc.
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

# Include internal libray
. ../../common/include.sh || exit 1

TEST_TYPE=${TEST_TYPE:-"netns"}
ROUTE_MODE=${ROUTE_MODE:-"local"}
. ./include.sh || exit 1


# Parameters

TEST_ITEMS=${TEST_ITEMS:-$TEST_ITEMS_ALL}
TEST_TOPO=${TEST_TOPO:-"default"}


#init


rlJournalStart
rlPhaseStartSetup
	[ x"$TEST_TYPE" == x"netns" ] && netns_clean.sh
	# would fail sometimes
	# only used in route_fuzz_test which would not run
	#rlRun "which iperf || iperf_install"
	rlRun "nl_fib_lookup_install"
	rlLog "test_items:$TEST_ITEMS"
	rlLog "test_topo:$TEST_TOPO"
	rlLog "test_type:$TEST_TYPE"
	rlLog "route_mode:$ROUTE_MODE"
	rlRun "${TEST_TOPO}_${ROUTE_MODE}_setup"

rlPhaseEnd

for test_item in $TEST_ITEMS
do
	$test_item
done

rlPhaseStartCleanup
	rlRun "${TEST_TOPO}_${ROUTE_MODE}_cleanup"
rlPhaseEnd

rlJournalEnd
