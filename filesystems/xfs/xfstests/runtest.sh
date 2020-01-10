#! /usr/bin/env bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/filesystems/xfs/xfstests
#   This test case runs the xfsqa test suite from sgi -- primarily
#   the "auto" group. The case needs at least 2 spare block devices
#   to run on and it can use up to 4 block devices.
#   These may be passed in as:
#
#   TEST_DEV
#   SCRATCH_DEV
#   SCRATCH_LOGDEV
#   SCRATCH_RTDEV
#
#   See PURPOSE file for more details.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Clear the dmesg, only the new messages are important
dmesg -c >/dev/null

# Source the common test script helpers
. /usr/bin/rhts_environment.sh

mkdir -p /usr/share/rhts/
echo "MAX_LOCKDEP_CHAIN_HLOCKS" >> /usr/share/rhts/falsestrings

. ./dep-install.sh
. ./misc.sh
. ./devices.sh
. ./install.sh
. ./xfstests-preset.sh
. ./xfstests-setup.sh
. ./xfstests-run.sh

# We need to define our own cleanup function
# Needs TEST_DEV, SCRATCH_DEV, TEST_DIR, SCRATCH_MNT
function cleanup ()
{
	popd >/dev/null 2>&1
	test -f nfs.bup && mv -f nfs.bup /etc/sysconfig/nfs
	test -f nfsmount.conf.bup && mv -f nfsmount.conf.bup /etc/nfsmount.conf
	test -f /bin/mount.real && mv -f /bin/mount.real /bin/mount
	test -f exports.bup && mv -f exports.bup /etc/exports
	test -f smb.conf.bup && mv -f smb.conf.bup /etc/samba/smb.conf
	general_cleanup
}

# Just use the default run function from ./xfstests-run.sh
run_full
exit 0
