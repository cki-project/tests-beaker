#!/bin/bash

function get_pkgmgr
{
    [[ -x /usr/bin/dnf ]] && echo "dnf" || echo "yum"
}

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
