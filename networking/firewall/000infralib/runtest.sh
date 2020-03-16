#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/networking/firewall/000infralib
#   Description: firewall/000infralib
#   Author: Shuang Li <shuali@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc. All rights reserved.
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
# Global parameters
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

#
# Select tool to manage package, which could be "yum" or "dnf"
# Note global variable YUM will be used later
#
FILE=$(readlink -f ${BASH_SOURCE})
NETWORKING_ROOT="${FILE%/networking/*}/networking"
source $NETWORKING_ROOT/common/include.sh
yum=$(select_yum_tool)
if (( $? != 0 )); then
	echo "FATAL: fail to get package tool" | tee -a $OUTPUTFILE
	rstrnt-report-result $TEST WARN 99
	rstrnt-abort -t recipe
	exit 0
fi
export YUM=$yum


MH_INFRA_ROOT="$(dirname $(readlink -f $BASH_SOURCE))"
###########################################################
# init env parameters
###########################################################
test -e ~/.profile && { update_profile_only=true; } || { update_profile_only=false; }
source ${MH_INFRA_ROOT}/env.sh
$update_profile_only && exit 0
source ${MH_INFRA_ROOT}/src/init.sh
###########################################################
# init environment
###########################################################
rlJournalStart
		rlPhaseStartSetup "000infralib Setup"
		$MH_AS_A_CONTROLLER && {
			[ $MH_INFRA_TYPE == "ns" ] && {
				rlRun "iproute_install" # for ip netns on rhel6
			}
			[ $MH_INFRA_TYPE == "vm" ] && {
				rlRun "${YUM} install expect -y"
				rlRun "${YUM} install pexpect -y || ${YUM} install python3-pexpect -y"
				rlRun "vinit"
			}
		}
		$MH_AS_A_TESTNODE && {
			[ $MH_INFRA_TYPE == "ns" ] && {
				rlRun "test_env_init"
			}
			[ $MH_INFRA_TYPE == "vm" ] && {
				rlRun "test_env_init"
			}
		}
        rlPhaseEnd

        rlJournalPrintText
rlJournalEnd
