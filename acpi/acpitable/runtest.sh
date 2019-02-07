#!/bin/bash

#--------------------------------------------------------------------------------
# Copyright (c) 2019 Red Hat, Inc. All rights reserved. This copyrighted material 
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
# Author: Al Stone <ahs3@redhat.com>
#---------------------------------------------------------------------------------
#
#	Simple test: are ACPI tables present?
#
#	There's no foolproof method to know, but we can check to see
#	if acpidump can read files from /sys/firmware/acpi/tables.  An
#	added bonus is that we capture a copy of the tables, too.
#---------------------------------------------------------------------------------

# Source the common test script helpers
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

# make sure acpica-tools are installed
pkg=$(rpm -qa | grep acpica-tools)
if [ -z "$pkg" ] ; then
    report_result $TEST WARN
    rhts-abort -t recipe
fi 

# run acpidump, which should succeed and write tables to stdout
# (requires being run as root)
acpidump
if [ $? != 0 ] ; then
    report_result $TEST FAIL 1
else
    # all is well
    report_result $TEST PASS 0
fi
