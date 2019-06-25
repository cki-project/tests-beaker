#!/bin/bash
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

source /usr/share/beakerlib/beakerlib.sh
source $(dirname $(readlink -f $BASH_SOURCE))/libbkrm.sh

STQE_GIT="https://gitlab.com/rh-kernel-stqe/python-stqe.git"
STQE_STABLE_VERSION=${STQE_STABLE_VERSION:-"6ae4855"}
LIBSAN_STABLE_VERSION=${LIBSAN_STABLE_VERSION:-"0.3.0"}

function stqe_get_fwroot
{
    typeset fwroot="/var/tmp/$(basename $STQE_GIT | sed 's/.git//')"
    echo $fwroot
}

function stqe_init_fwroot
{
    typeset fwbranch=$1

    # clone the framework
    typeset fwroot=$(stqe_get_fwroot)
    rlRun "rm -rf $fwroot"
    rlRun "git clone $STQE_GIT $fwroot" || rlAbort "fail to clone $STQE_GIT"

    # install the framework
    pushd "." && rlRun "cd $fwroot"

    if [[ $fwbranch != "master" ]]; then
        if [[ -n $STQE_STABLE_VERSION ]]; then
            rlRun "git checkout $STQE_STABLE_VERSION" || \
                rlAbort "fail to checkout $STQE_STABLE_VERSION"
        fi
        if [[ -n $LIBSAN_STABLE_VERSION ]]; then
            rlRun "pip3 install libsan==$LIBSAN_STABLE_VERSION" || \
                rlAbort "fail to install libsan==$LIBSAN_STABLE_VERSION"
        fi
    fi

    #
    # XXX: On RHEL7, should use python2 instead because python3
    #      is not available by default
    #
    typeset python=""
    typeset cmd=""
    for cmd in python3 python2 python; do
        $cmd -V > /dev/null 2>&1 && python=$cmd && break
    done
    [[ -n $python ]] || rlSkip "python not found"

    # install required packages
    rlRun "bash env_setup.sh" $BKRM_RC_ANY

    rlRun "$python setup.py install --prefix=" || \
        rlAbort "fail to install test framework"

    popd

    return 0
}

function stqe_fini_fwroot
{
    typeset fwroot=$(stqe_get_fwroot)
    rlRun "rm -rf $fwroot"
}
