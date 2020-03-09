#!/bin/bash
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

# Include environments
. /usr/share/beakerlib/beakerlib.sh || exit 1

# Include cki library
. ../../cki_lib/libcki.sh || exit 1

# Task parameters
# DeBug - Set to non-zero value to enable debugging
# FwtsGitRemote - git repository
# FwtsGitBranch - git branch that will be used


: ${DeBug:=0}
: ${FwtsGitRemote:=git://kernel.ubuntu.com/hwe/fwts.git}
: ${FwtsGitBranch:=""}
FwtsIncludeDir=$(readlink -f "../include/")

FWTS_ON_FAIL_REPORT=${FWTS_ON_FAIL_REPORT:-FAIL}


# Fetch availabe rpm tools
YUM=$(cki_get_yum_tool)

# firmware test setup
function fwtsSetup()
{
    # Setup build prerequisites for fwts
    # normally Beaker pre-installs the prereqs, but since this is an "include"
    # task Beaker won't check the rpm-requirements for this task
    if ! rlCheckRpm pcre-devel; then
        $YUM install pcre-devel -y
        rlAssertRpm pcre-devel
    fi

    if ! rlCheckRpm json-c-devel; then
        $YUM install json-c-devel -y
        rlAssertRpm json-c-devel
    fi

    if ! rlCheckRpm glib2-devel; then
        $YUM install glib2-devel -y
        rlAssertRpm glib2-devel
    fi

    if ! rlCheckRpm elfutils-libelf-devel; then
        $YUM install elfutils-libelf-devel -y
        rlAssertRpm elfutils-libelf-devel
    fi

    # libbsd is a requirement to build.
    if ! rlCheckRpm libbsd-devel; then
        $YUM install libbsd-devel -y
        if [ $? -ne 0 ]; then 
            # libbsd-devel is available from epel for rhel7
            if rlIsRHEL 7; then
               $YUM  -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
            elif rlIsRHEL 8; then
               $YUM  -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
            fi
            $YUM install libbsd-devel -y
            rlAssertRpm libbsd-devel
        fi
    fi
    # Skip download/build/installation if it looks like fwts is already installed
    if ! [ -x /usr/local/bin/fwts ] ; then

        # Download fwts sources
        rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
        rlRun "cd $TmpDir" 0 "change directory to tmpdir"
        if [ -n "$FwtsGitRemote" ]; then
            # Get sources from git
            if [ -n "$FwtsGitBranch" -a "$FwtsGitBranch" != "HEAD" ]; then
                rlRun "git clone --branch $FwtsGitBranch $FwtsGitRemote" 0 "clone git repository"
                if [ $? -ne 0 ]; then
                    cki_abort_task "Failed to clone git $FwtsGitRemote branch $FwtsGitBranch repository"
                fi
            else
                rlRun "git clone $FwtsGitRemote" 0 "clone git repository"
                if [ $? -ne 0 ]; then
                    cki_abort_task "Failed to clone git $FwtsGitRemote repository"
                fi
            fi
            rlRun "cd fwts" 0 "cd into fwts source directory"
            rlLog "Current branch is $(git rev-parse --abbrev-ref HEAD) $(git rev-parse HEAD)"
        fi

        # Apply patches
        for p in ${FwtsIncludeDir}/patches/*.patch ; do
            rlRun "patch -p1 < $p" 0 "applying patch: $p"
        done

        # setup efi_runtime module needed by uefirt* tests
        # make modules_install so efi_runtime can be loaded with modprobe as fwts requires
        rlRun "cd efi_runtime" 0 "cd into efi_runtime directory"
        # Setting $KVER to the running kernel version should negate the need for  0003-efi_runtime_Makefile_modules_install.patch
        if [ "$(uname -m)" = "aarch64" ] ; then
            rlRun "ARCH=arm64 KVER=$(uname -r) make all install" 0 "make all install inside efi_runtime"
        else
            rlRun "KVER=$(uname -r) make all install" 0 "make all install inside efi_runtime"
        fi
        rlRun "cd .." 0 "cd up one directory back into fwts source root"

        # run autoreconf to recreate build system files for fwts
        rlRun "autoreconf -ivf" 0 "run autoreconf to recreate build system files for fwts"

        # run configure script to generage Makefile for fwts
        rlRun "./configure" 0 "run configure to generate Makefile for fwts"

        # run make to build binaries from source for fwts
        rlRun "make -j$(nproc)" 0 "run make to build binaries from source for fwts"

        # run make install to install files for fwts on system
        rlRun "make install" 0 "run make install to install files for fwts on system"
    else
        rlLog "It appears that fwts is already installed, skipping the build process"
    fi # endif for install check
    # Get fwts version from installed fwts binary
    rlRun -l "fwts -v" 0 "run fwts to get version, if this fails fwts likely did not build/install properly"

    # Run modinfo on efi_runtime to confirm it installed properly
    rlRun -l "modinfo efi_runtime" 0 "Check to see if efi_runtime built/installed properly"
}

# firmware test report results
function fwtsReportResults()
{
    # first, submit fwts results.log file to beaker
    rlFileSubmit results.log

    resultSummaryLines=$(cat results.log | awk '/^---------------\+-----\+-----\+-----\+-----\+-----\+-----\+/ { print FNR }')
    echo $resultSummaryLines

    beginTableLine=$(echo $resultSummaryLines | awk '{print $1}')
    endTableLine=$(echo $resultSummaryLines | awk '{print $2}')

    # there is a third summary line after the totals FYI

    # Throw away the beginning and end of table
    beginTableLine=$(( $beginTableLine + 1 ))
    endTableLine=$(( $endTableLine - 1 ))

    # Test |Pass |Fail |Abort |Warn |Skip |Info |
    sed -n $beginTableLine\,$endTableLine\p results.log > resultsSummary.out
  
    while IFS= read -r line
    do
        fwtsTest=$(echo "$line" | awk -F \| '{print $1}')
        fwtsPass=$(echo "$line" | awk -F \| '{print $2}')
        fwtsFail=$(echo "$line" | awk -F \| '{print $3}')
        fwtsAbort=$(echo "$line" | awk -F \| '{print $4}')
        fwtsWarn=$(echo "$line" | awk -F \| '{print $5}')
        fwtsSkip=$(echo "$line" | awk -F \| '{print $6}')
        fwtsInfo=$(echo "$line" | awk -F \| '{print $7}')

        if echo $fwtsFail | grep -q '[0-9]'; then
            # add waive text,  when fail tests are treated pass
            if  [[ "$FWTS_ON_FAIL_REPORT" == "PASS" ]]; then
                rlPhaseStartTest "${fwtsTest}-[WAIVE]-see_log_files"
                rlPass "fwtsFail count: $fwtsFail"
            else
                rlPhaseStart $FWTS_ON_FAIL_REPORT $fwtsTest
                rlFail "fwtsFail count: $fwtsFail"
            fi
            rlPhaseEnd
        elif echo $fwtsAbort | grep -q '[0-9]' || echo $fwtsWarn | grep -q '[0-9]'\
            || echo $fwtsSkip | grep -q '[0-9]'
        then
            if  [[ "$FWTS_ON_FAIL_REPORT" == "PASS" ]]; then
                rlPhaseStartTest "${fwtsTest}-[WAIVE]-see_log_files"
                rlPass "fwts reports $fwtsTest aborted/warned/skipped, see results.log for details"
            else
                rlPhaseStart $FWTS_ON_FAIL_REPORT $fwtsTest
                rlFail "fwts reports $fwtsTest aborted/warned/skipped, see results.log for details"
            fi
            rlPhaseEnd
        elif echo $fwtsInfo | grep -q '[0-9]'; then
            rlPhaseStartTest $fwtsTest
            rlPass "fwtsInfo count: $fwtsInfo"
            rlPhaseEnd
        elif echo $fwtsPass | grep -q '[0-9]'; then
            rlPhaseStartTest $fwtsTest
            rlPass "fwtsPass count: $fwtsPass"
            rlPhaseEnd
        fi
    done < resultsSummary.out    
}

function fwtsCleanup()
{
    if [ -d "$TmpDir" ] ; then
        [[ $DeBug = "0" ]] && rlRun "rm -r $TmpDir" 0 "Removing tmp directory" || rlLog "Debugging enabled, keeping $TmpDir"
    fi
}
