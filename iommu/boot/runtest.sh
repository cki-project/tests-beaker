#!/bin/bash
# vim: dict=/usr/share/rhts-library/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/iommu/boot
#   Description: Test various IOMMU boot options
#   Author: William Gomeringer <wgomerin@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc. All rights reserved.
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

# Include libraries
. ../../cki_lib/libcki.sh || exit 1

# file to write custom boot options (from CMDLINEARGS)
CustomBootOptions=custom-boot-options.txt
# file to use if no custom boot options passed
DefaultBootOptionsIntel=default-boot-options-intel.txt
DefaultBootOptionsAMD=default-boot-options-amd.txt
# file to store current boot options being tested
CurrentBootOptions=current-boot-options.txt
cpuvendor=$(grep -m1 vendor_id /proc/cpuinfo | awk '{print $NF}')
dmesgErrors=iommu-dmesg-errors.txt
dmesgReport=iommu-dmesg-report.txt

function bootOptions() {
    bootOptionsFile=$1
    

    while read -r line; do
        # Check to see if new options have been set yet
	if [[ -z "${REBOOTCOUNT}" ||  "${REBOOTCOUNT}" -eq 0 ]] || \
	    [[ ! -a $CurrentBootOptions ]]; then
	    echo "Start test." | tee -a "${OUTPUTFILE}"
	    echo "Old cmdline: $(cat /proc/cmdline)" | tee -a "${OUTPUTFILE}"

            # Update the boot loader.
	    default=$(/sbin/grubby --default-kernel)

	    echo "Cmdline to be added: ${line}" | tee -a "${OUTPUTFILE}"
	    /sbin/grubby --args="${line}" --update-kernel="${default}"
	    code=$?

	    if [ ${code} -ne 0 ]; then
		echo "Fail: error changing boot loader." |
		tee -a "${OUTPUTFILE}"
		rstrnt-report-result "${TEST}/boot_loader" "FAIL" 0
	    else
		echo "${line}" > $CurrentBootOptions
		echo "Reboot now!" | tee -a "${OUTPUTFILE}"
		rstrnt-report-result "${TEST}/boot_loader" "PASS" 0
		rstrnt-reboot
	    fi
	else
            # The reboot has finished. Verify the cmdline.
	    echo "New cmdline: $(cat /proc/cmdline)" | tee -a "${OUTPUTFILE}"

            grep "$(cat $CurrentBootOptions)" /proc/cmdline
	    code=$?
	    # remove spaces for reporting boot option to beaker
	    CurrentBootOptionsReport=$(cat $CurrentBootOptions | sed 's/\ /-/')	    

	    if [ ${code} -ne 0 ]; then
		echo "Fail: error booting kernel with specified cmdline" |
		tee -a "${OUTPUTFILE}"

		rstrnt-report-result "${TEST}/$CurrentBootOptionsReport" "FAIL" 0
		rm $CurrentBootOptions
	        /sbin/grubby --remove-args="${line}" \
		 --update-kernel="${default}"
        	sed -i "/$line\$/d" $bootOptionsFile
	    else
       		echo "boot options persisted through reboot." | tee -a "${OUTPUTFILE}"
		rstrnt-report-result "${TEST}/$CurrentBootOptionsReport" "PASS" 0
	        rm $CurrentBootOptions
                /sbin/grubby --remove-args="${line}" \
                 --update-kernel="${default}"
        	sed -i "/$line\$/d" $bootOptionsFile
	    fi
	fi



    done < $bootOptionsFile
}

function dmesgErrors() {
    dmesgLineNumber=0
    
    # find any iommu errors in dmesg/messages file
    while read -r dmesgLine; do
	dmesgLineNumber=$(($dmesgLineNumber+1))
	journalctl | grep "$dmesgLine"
	    code=$?
	    if [ ${code} -ne 1 ]; then
		echo "Fail: the following iommu regex matched in dmesg:" |
		tee -a "${OUTPUTFILE}"
		echo "$dmesgLine" | tee -a "${OUTPUTFILE}"
		echo "see TESTOUT.log for actual message or $dmesgReport for report" |
		tee -a "${OUTPUTFILE}"
		echo "$dmesgLineNumber FAIL $dmesgLine" >> $dmesgReport
	    else
		echo "$dmesgLineNumber PASS $dmesgLine" >> $dmesgReport
	    fi
    done < $dmesgErrors

    # report pass/fail to beaker if errors were found, upload report
    grep FAIL $dmesgReport
    dmesgReportCode=$?

    if [ ${dmesgReportCode} -ne 1 ]; then
	rstrnt-report-result "${TEST}/iommu-dmesg" "FAIL" 0
    else
	rstrnt-report-result "${TEST}/iommu-dmesg" "PASS" 0
    fi
    
    rstrnt-report-log -l $dmesgReport

}

function cleanupTest() {
    rm $dmesgReport
}

if [[ -n $CMDLINEARGS ]]; then
    if [ -z "${REBOOTCOUNT}" ] || [ "${REBOOTCOUNT}" -eq 0 ]; then
       IFS=':'
       for i in $CMDLINEARGS; do
	   echo $i >> $CustomBootOptions
       done
    fi
    bootOptions $CustomBootOptions
    dmesgErrors
else
    if [[ $cpuvendor = "GenuineIntel" ]]; then
	bootOptions $DefaultBootOptionsIntel
	dmesgErrors
    elif [[ $cpuvendor = "AuthenticAMD" ]]; then
       	bootOptions $DefaultBootOptionsAMD
	dmesgErrors
    else
	rstrnt-report-result "${TEST}/nonAMDorIntelProcessor" "SKIP" 0
	exit 0
    fi
fi

cleanupTest
