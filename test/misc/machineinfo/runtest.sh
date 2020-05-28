#!/bin/bash

# Copyright (c) 2014 Red Hat, Inc. All rights reserved. This copyrighted material 
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Artem Savkov <asavkov@redhat.com>

. ../../../cki_lib/libcki.sh || exit 1

set +x

MDESC=/tmp/machinedesc.log
DATAFILE=/tmp/lshw.log

echo "arch: $(uname -m)" > ${MDESC}
lshw -class cpu -short >> ${MDESC}
lshw -json -sanitize -notime > ${DATAFILE}

rstrnt-report-log -l ${MDESC}
rstrnt-report-log -l ${DATAFILE}
rstrnt-report-result $TEST PASS 0

rm ${DATAFILE}
exit 0
