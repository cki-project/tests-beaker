#! /usr/bin/env bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   This file includes commands that check for system stuff
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Check that root fs is xfs on rhel 7+
function check_root_fs()
{
	# xfs is not the default fs in rhel5, rhel6, skip
	if test $RHEL_MAJOR -lt 7;then
		report check_root_fs PASS 0
		return 0
	fi
	DEV="$(cat /etc/fstab|grep -E " / " | awk '{print $1}')"
	if test -z "$DEV";then
		report check_root_fs PASS 0
		return 0 # root fs detection failed, heuristic failed
	fi
	if xlog xfs_info "$DEV";then
		report check_root_fs PASS 0
		return 0
	fi
	report check_root_fs FAIL 1
}

# Check that all the packages that are built from source were successfully installed, report failure otherwise
function check_installed()
{
	xlog rpm -q xfsprogs-devel
	test $? -ne 0 && report check_installed:xfsprogs FAIL 1
	xlog rpm -q xfsdump
	test $? -ne 0 && report check_installed:xfsdump FAIL 1
	xlog rpm -q dbench
	test $? -ne 0 && report check_installed:dbench FAIL 1
	xlog rpm -q fio
	test $? -ne 0 && report check_installed:fio FAIL 1
}
