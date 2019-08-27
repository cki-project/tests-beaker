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

source $(dirname $(readlink -f $BASH_SOURCE))/libbkrm.sh
source ../../cki_lib/lib.sh

TMPDIR=${TMPDIR:-"/tmp"}
MSR_TOOLS_SRC_URL="https://github.com/intel/msr-tools.git"
MSR_TOOLS_DST_DIR="$TMPDIR/msr-tools"

function is_rhel7
{
    [ ! -e /etc/redhat-release ] && return 0
    rel=$(cat /etc/redhat-release)
    ver=$(echo "${rel##*release}" | awk '{$1=$1;print}' | cut -d '.' -f 1)
    [ "$ver" -eq 7 ] && return 1 || return 0
}

function msr_tools_install
{
    typeset script=${1:-"$TMPDIR/msr_tools_setup.sh"}

    cat > $script << EOF
    #!/bin/bash

    [[ -f /usr/sbin/rdmsr ]] && exit 0
    [[ -f /usr/local/bin/rdmsr ]] && exit 0

    src_url=$MSR_TOOLS_SRC_URL
    dst_dir=$MSR_TOOLS_DST_DIR
    rm -rf \$dst_dir
    git clone \$src_url \$dst_dir || exit 1
    cd \$dst_dir
    sed -i 's%^LT_INIT%#LT_INIT%g' configure.ac || exit 1
    ./autogen.sh || exit 1
    make || exit 1
    make install || exit 1
    exit 0
EOF

    rlRun "chmod +x $script" $BKRM_RC_ANY
    rlRun "cat -n $script" $BKRM_RC_ANY
    rlRun "bash $script" || return $BKRM_UNINITIATED

    return $BKRM_PASS
}

function msr_tools_uninstall
{
    typeset dst_dir=$MSR_TOOLS_DST_DIR
    [[ ! -d $dst_dir ]] && return $BKRM_PASS

    rlCd "$dst_dir"
    rlRun "make uninstall" $BKRM_RC_ANY
    rlPd

    return $BKRM_PASS
}

EPEL="http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
function msr_tools_epel_install()
{
    [ ! -e /etc/yum.repos.d/epel.repo ] && add_repo=true || add_repo=false

    if [ "$add_repo" = "true" ]; then
	rlRun "${YUM} -y install $EPEL" $BKRM_RC_ANY
    fi

    rlRun "${YUM} -y install msr-tools" $BKRM_RC_ANY

    if [ "$add_repo" = "true" ]; then
	rlRun "${YUM} -y remove epel-release" $BKRM_RC_ANY
    fi

    rlRun "which rdmsr"

    [ $? -eq 0 ] && return $BKRM_PASS || return $BKRM_UNINITIATED

}

function msr_tools_epel_uninstall
{
    rlRun "${YUM} -y remove msr-tools" $BKRM_RC_ANY
}

function msr_tools_setup
{
    is_rhel7
    if [ $? -eq 1 ]; then
	cki_yum_tool
	msr_tools_epel_install
    else
	msr_tools_install
    fi
}

function msr_tools_cleanup
{
    is_rhel7
    [ $? -eq 1 ] && msr_tools_epel_uninstall || msr_tools_uninstall
}
