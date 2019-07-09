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

source ${CDIR%/cpu/driver}/cpu/common/libbkrm.sh

TMPDIR=${TMPDIR:-"/tmp"}
MSR_TOOLS_SRC_URL="https://github.com/intel/msr-tools.git"
MSR_TOOLS_DST_DIR="$TMPDIR/msr-tools"

function msr_tools_setup
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
    rlRun "bash $script" || return $BKRM_FATAL

    return $BKRM_PASS
}

function msr_tools_cleanup
{
    typeset dst_dir=$MSR_TOOLS_DST_DIR
    [[ ! -d $dst_dir ]] && return $BKRM_PASS

    rlCd "$dst_dir"
    rlRun "make uninstall" $BKRM_RC_ANY
    rlPd

    return $BKRM_PASS
}
