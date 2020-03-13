#! /bin/bash -x
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   dep-install.sh of /kernel/filesystems/xfs/include
#   This file installs common dependencies
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

YUM_PROG=$(which yum)
if which dnf >/dev/null; then
	YUM_PROG="$(which dnf) --setopt=strict=0"
fi
$YUM_PROG -y --skip-broken install xfs-kmod xfsprogs xfsdump perl quota acl attr  bind-utils bc indent rpm-build autoconf libtool popt-devel libblkid-devel readline-devel gettext policycoreutils-python shadow-utils libuuid-devel e4fsprogs e2fsprogs-devel gdbm-devel libaio-devel libattr-devel libacl-devel xfsprogs-devel btrfs-progs gfs2-utils python gcc ncurses-devel pyOpenSSL git mdadm libcap git vim openssl-devel samba samba-client cifs-utils nfs-utils rpcbind lvm2 librbd1-devel librdmacm-devel vdo kmod-kvdo fio python2 beakerlib libtirpc libtirpc-devel rpcgen blockdev
