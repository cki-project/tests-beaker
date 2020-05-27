#!/bin/bash

FILE=$(readlink -f $BASH_SOURCE)
NAME=$(basename $FILE)
CDIR=$(dirname $FILE)
TMPDIR=${TMPDIR:-"/tmp"}

function is_rhel8
{
    typeset release=$(grep -Go 'release [0-9]\+' /etc/redhat-release | \
        awk '{print $NF}')
    [[ $release == "8" ]] && return 0 || return 1
}

function get_pkgmgr
{
    [[ -x /usr/bin/dnf ]] && echo "dnf" || echo "yum"
}

function install_dependencies
{
    #
    # XXX: On x86_64, to build libhugetlbfs, both glibc-static.x86_64 and
    #      glibc-static.i686 are required. For details, please refer to:
    #      Bug 1567712 - glibc-static needs to be multilib on RHEL 8
    #
    pkgs=""
    if [[ $(uname -i) == "x86_64" ]]; then
        # 32-bit packages
        pkgs+=" libgcc.i686"
        pkgs+=" glibc-devel.i686"
        pkgs+=" glibc-static.i686"
        # 64-bit packages
        pkgs+=" libgcc.x86_64"
        pkgs+=" glibc-devel.x86_64"
        pkgs+=" glibc-static.x86_64"
    else
        pkgs+=" libgcc"
        pkgs+=" glibc-devel"
        pkgs+=" glibc-static"
    fi
    pkgs+=" gcc"

    pkgmgr=$(get_pkgmgr)
    for pkg in $pkgs; do
        rpm --quiet -q $pkg && continue
        $pkgmgr -y install $pkgs
    done
}

LOOKASIDE="https://github.com/libhugetlbfs/libhugetlbfs/releases/download/"
PACKAGE_NAME="libhugetlbfs"
function get_package_version
{
    grep -q "release [5-7].*" /etc/redhat-release && echo 2.18 || echo 2.21
}

function get_libhugetlbfs_target
{
    PACKAGE_VERSION=$(get_package_version)
    echo ${PACKAGE_NAME}-${PACKAGE_VERSION}
}

function download_libhugetlbfs
{
    typeset target=$(get_libhugetlbfs_target)

    rm -rf $target.tar.gz
    typeset tarball=$LOOKASIDE/$(get_package_version)/$target.tar.gz
    wget -q $tarball || return 1

    rm -rf $target
    tar zxf $target.tar.gz || return 1
    return 0
}

function build_libhugetlbfs
{
    typeset target=$(get_libhugetlbfs_target)
    typeset arch=$(uname -i)
    typeset osmr=$(grep -Go 'release [0-9]\+' /etc/redhat-release | \
                   awk '{print $NF}')
    typeset oa=${osmr}_${arch}
    if [[ $oa != "8_aarch64" && $oa != "8_ppc64le" && $oa != "8_s390x" ]]; then
        #
        # XXX: For RHEL8, add BUILDTYPE=NATIVEONLY to skip 32-bit tests on
        #      64-bit systems
        #
        make -C $target BUILDTYPE=NATIVEONLY
        make -C $target PREFIX=/usr BUILDTYPE=NATIVEONLY install
    else
        make -C $target
        make -C $target PREFIX=/usr install
    fi

    cp -f $target/huge_page_setup_helper.py /usr/bin/
}

if is_rhel8; then
    install_dependencies
    download_libhugetlbfs
    build_libhugetlbfs
    bash $CDIR/patch.sh
else
    install_dependencies
    download_libhugetlbfs
    bash $CDIR/patch.sh
    build_libhugetlbfs
fi
exit $?
