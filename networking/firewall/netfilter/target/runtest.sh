#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/networking/firewall/netfilter/target
#   Description: firewall/netfilter/target
#   Author: Shuang Li <shuali@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc. All rights reserved.
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

FILE=$(readlink -f $BASH_SOURCE)
NAME=$(basename $FILE)
CDIR=$(dirname  $FILE)

# Include Beaker environment
. ../../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

###########################################################
# init environment & load common libraries
###########################################################
sh     ../../000infralib/runtest.sh
source ../../000infralib/include.sh

###########################################################
# load libraries
###########################################################
# XXX: disable tg_TCPOPTSTRIP* cases in CKI as they are obsolete
MH_TG_ENTRIES=${MH_TG_ENTRIES:-"$(ls tg_STANDARD*.sh)"}
files=$MH_TG_ENTRIES

###########################################################
# do your tests
###########################################################
rlJournalStart
	rlPhaseStartSetup
	rlPhaseEnd

	for file in $files; do
		source $file
		for level in $MH_TEST_LEVELS; do
			function=${file%.sh}"_"${level}
			type -t "$function" > /dev/null 2>&1 && {
				for pkt in $MH_PKT_TYPES; do
					${file%.sh}"_is_unsupported_entry" ${level} ${pkt} && continue
					rlPhaseStartTest "${MH_INFRA_TYPE} $function ${pkt}"
						rlRun "$function ${pkt}"
					rlPhaseEnd
				done
			}
		done
	done

	rlPhaseStartCleanup
		rlRun "topo_netfilter_clean_all"
	rlPhaseEnd

rlJournalPrintText
rlJournalEnd

exit 0
