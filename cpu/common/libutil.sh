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

source $(dirname $(readlink -f $BASH_SOURCE))/../../cki_lib/libcki.sh

TMPDIR=${TMPDIR:-"/tmp"}
MSR_TOOLS_SRC_URL="https://github.com/intel/msr-tools.git"
MSR_TOOLS_DST_DIR="$TMPDIR/msr-tools"

function is_rhel7
{
    [[ ! -e /etc/redhat-release ]] && return 1

    typeset ver=$(sed 's/.*release//' /etc/redhat-release | \
                  awk '{print $1}' | \
                  awk -F'.' '{print $1}')
    [[ $ver == 7 ]] && return 0 || return 1
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

    cki_run_cmd_neu "chmod +x $script"
    cki_run_cmd_neu "cat -n $script"
    cki_run_cmd_pos "bash $script" || return $CKI_UNINITIATED

    return $CKI_PASS
}

function msr_tools_uninstall
{
    typeset dst_dir=$MSR_TOOLS_DST_DIR
    [[ ! -d $dst_dir ]] && return $CKI_PASS

    cki_cd "$dst_dir"
    cki_run_cmd_neu "make uninstall"
    cki_pd

    return $CKI_PASS
}

YUM=""
EPEL="http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
function msr_tools_epel_install()
{
    typeset add_repo=false
    [[ ! -e /etc/yum.repos.d/epel.repo ]] && add_repo=true

    [[ "$add_repo" == "true" ]] && \
        cki_run_cmd_neu "${YUM} -y install $EPEL"
    cki_run_cmd_neu "${YUM} -y install msr-tools"
    [[ "$add_repo" == "true" ]] && \
        cki_run_cmd_neu "${YUM} -y remove epel-release"

    cki_run_cmd_pos "which rdmsr"
    (( $? == 0 )) && return $CKI_PASS || return $CKI_UNINITIATED
}

function msr_tools_epel_uninstall
{
    cki_run_cmd_neu "${YUM} -y remove msr-tools"
}

function msr_tools_setup
{
    YUM=$(cki_get_yum_tool)
    is_rhel7 && msr_tools_epel_install || msr_tools_install
}

function msr_tools_cleanup
{
    is_rhel7 && msr_tools_epel_uninstall || msr_tools_uninstall
}
