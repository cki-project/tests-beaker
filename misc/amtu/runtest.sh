#!/bin/sh
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/misc/amtu
#   Description: Test Abstract Machine Test Utility
#   Author: Paul Bunyan <pbunyan@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2009 Red Hat, Inc. All rights reserved.
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

# Source the common test script helpers
. ../../cki_lib/libcki.sh || exit 1

# Assume the test will fail.
result=FAIL

# Helper functions
function result_fail()
{
    echo "***** End of runtest.sh *****" | tee -a $OUTPUTFILE
    export result=FAIL
    rstrnt-report-result $TEST $result 1
    exit 0
}

function result_pass ()
{
    echo "***** End of runtest.sh *****" | tee -a $OUTPUTFILE
    export result=PASS
    rstrnt-report-result $TEST $result 0
    exit 0
}

function build_amtu()
{
    LOOKASIDE="https://github.com/jstancek/amtu.git --branch autoconf-amtu-1.1"

    AMTU_NVR="amtu-1.1"

    if [ -e "$AMTU_NVR" ]; then
        rm -rf $AMTU_NVR
    fi

    if [ ! -e "$AMTU_NVR.tar.gz" ]; then
        # download
        git clone ${LOOKASIDE} ${AMTU_NVR}
        if [ $? -ne 0 ]; then
            echo "Could not download $LOOKASIDE $AMTU_NVR"|tee -a $OUTPUTFILE
            # Add task param, needed for kernel-ci/CKI, e.g. <params><param name="CI" value="yes"/><params>
            if [ "$CI" = "yes" ]; then
                return 1
            fi
            exit 1
        fi
    else 
        # unpack
        tar xfvz $AMTU_NVR.tar.gz
        if [ $? -ne 0 ]; then
            echo "Could not extract $AMTU_NVR.tar.gz" | tee -a $OUTPUTFILE
            # Add task param, needed for kernel-ci/CKI, e.g. <params><param name="CI" value="yes"/><params>
            if [ "$CI" = "yes" ]; then
                return 2
            fi
            exit 2
        fi
    fi

    if [ ! -d "$AMTU_NVR" ]; then
        echo "Could not find dir $AMTU_NVR" | tee -a $OUTPUTFILE
        # Add task param, needed for kernel-ci/CKI, e.g. <params><param name="CI" value="yes"/><params>
        if [ "$CI" = "yes" ]; then
            return 3
        fi
        exit 3
    fi

    # apply patches
    pushd $AMTU_NVR
    git am ../memsep-use-_exit-to-exit-child.patch
    git am --ignore-space-change --ignore-whitespace  ../memtest-limit-memtest-to-512MB-of-memory.patch
    popd

    # build
    pushd $AMTU_NVR
    autoreconf -ifv . > tmp 2>&1
    ./configure > tmp 2>&1
    cat tmp | tee -a $OUTPUTFILE; rm -f tmp

    make > tmp 2>&1
    cat tmp | tee -a $OUTPUTFILE; rm -f tmp

    cp -f src/amtu ./
    popd

    if [ ! -e $AMTU_NVR/amtu ]; then
        echo "Failed to build amtu" | tee -a $OUTPUTFILE
        # Add task param, needed for kernel-ci/CKI, e.g. <params><param name="CI" value="yes"/><params>
        if [ "$CI" = "yes" ]; then
            return 4
        fi
        exit 4
    fi
    amtubin=$(pwd)/$AMTU_NVR/amtu
}

# ---------- Start Test -------------
# Setup some variables
if [ -e /etc/redhat-release ] ; then
    installeddistro=$(cat /etc/redhat-release)
else
    installeddistro=unknown
fi

amtubin=$(which amtu)
kernbase=$(rpm -q --queryformat '%{name}-%{version}-%{release}.%{arch}\n' -qf /boot/config-$(uname -r))
amtubase=$(rpm -q --queryformat '%{name}-%{version}-%{release}.%{arch}\n' -qf "$amtubin")

#if [[ $(expr match $kernbase 'kernel-xen.*') > 0 ]]; then
#   echo "*** This is a xen kernel, the test won't be run" | tee -a $OUTPUTFILE
#   echo "*** will submit the result as PASS" | tee -a $OUTPUTFILE
#   result_pass
#fi

if [[ $(expr match $kernbase 'kernel-xen.*') > 0 ]]; then
   echo "*** Unsure why this kernel was not in the defult list" | tee -a $OUTPUTFILE
   echo "*** Added back in Dec 21, 2009 - Jeff Burke <jburke@redhat.com>" | tee -a $OUTPUTFILE
   result_pass
fi

echo "***** Starting the runtest.sh script *****" | tee -a $OUTPUTFILE
echo "***** Current Running Kernel Package = "$kernbase" *****" | tee -a $OUTPUTFILE
echo "***** Current Running AMTU Package = "$amtubase" *****" | tee -a $OUTPUTFILE
echo "***** Current Running Distro = "$installeddistro" *****" | tee -a $OUTPUTFILE

if [ -z "$amtubin" -o ! -e "$amtubin" ]; then
    echo "***** There is no amtu on this system, try to build one" | tee -a $OUTPUTFILE
    build_amtu
    # Add task param, needed for kernel-ci/CKI, e.g. <params><param name="CI" value="yes"/><params>
    if [ $? -ne 0 ] && [ "$CI" = "yes" ]; then
        rstrnt-report-result $TEST WARN
        rstrnt-abort -t recipe
    fi

fi

#####################################
# Usage: amtu [-dmsinph]
# d      Display debug messages
# m      Execute Memory Test
# s      Execute Memory Separation Test
# i      Execute I/O Controller - Disk Test
# n      Execute I/O Controller - Network Test
# p      Execute Supervisor Mode Instructions Test
# h      Display help message
#####################################

amtu_params="-dmsip"

$amtubin $amtu_params >>$OUTPUTFILE 2>&1
if [ "$?" -ne "0" ] ; then
    result_fail
else
    result_pass
fi
