#!/bin/bash

# Description:
#
# Knownissue classification:
#
#   fatal: means the issue/bz caused by this testcase will block(system
#          panic or hang) our test. we suggest to skip it directly.
#
#   fixed: means the issue/bz caused by this testcase has already been
#          fixed in a specified kernel version. And the testcase only
#          failed but no system panic/hang, we suggest to skip it when
#          < fixed-kernel-version, or we can remark the test result as
#          KNOWN issue in log to avoid beaker report failure.
#
#   unfix: means the issue/bz caused by this testcase have NOT being
#          fixed in corresponding RHEL(BZ delay to next version) product
#          or it'll never get a chance to be fixed(BZ close as WONTFIX).
#          And the testcase only failed but no system panic/hang), we
#          suggest to skip it when <= unfix-rhel-version, or we can remark
#          the test result as KNOWN issue to avoid beaker report failure.
#
# Issue Note:
#      We'd better follow these principles to exlucde testcase:
#      1. Upstream kernel bug use its kernel-nvr ranges
#      2. RHEL kernel bug(fixed) use its kernel-nvr ranges
#      3. RHEL kernel bug(unfix) use distro exclustion first, then move
#         to kernel-nvr ranges once it has been fixed.
#      4. Userspace package bug use itself package-nvr ranges
#
# Added-by: Li Wang <liwang@redhat.com>

. ../include/kvercmp.sh  || exit 1

cver=$(uname -r)
arch=$(uname -m)

# Identify OS release
if [ -r /etc/system-release-cpe ]; then
	# If system-release-cpe exists, we're on Fedora or RHEL6 or newer
	cpe=$(cat /etc/system-release-cpe)
	osflav=$(echo $cpe | cut -d: -f4)

	case $osflav in
		  fedora)
			osver=$(echo $cpe | cut -d: -f5)
			;;

	enterprise_linux)
			osver=$(echo $cpe | awk -F: '{print int(substr($5, 1,1))*100 + (int(substr($5,3,2)))}')
			;;
	esac
else
	# if we don't have system-release-cpe, use the old mechanism
	osver=0
fi

kn_fatal=${LTPDIR}/KNOWNISSUE_FATAL
kn_unfix=${LTPDIR}/KNOWNISSUE_UNFIX
kn_fixed=${LTPDIR}/KNOWNISSUE_FIXED
kn_issue=${LTPDIR}/KNOWNISSUE

function is_rhel8() { grep -q "release 8" /etc/redhat-release; }
function is_fedora() { grep -q "Fedora" /etc/redhat-release; }
function is_upstream() { uname -r | grep -q -v 'el[0-9]\|fc'; }
function is_arch() { [ "$(uname -m)" == "$1" ]; }
# osver_low <= $osver < osver_high
function osver_in_range() { ! is_upstream && [ "$1" -le "$osver" -a "$osver" -lt "$2" ]; }

# kernel_low <= $cver < kernel_high
function kernel_in_range()
{
	kvercmp "$1" "$cver"
	if [ $kver_ret -le 0 ]; then
		kvercmp "$cver" "$2"
		if [ $kver_ret -lt 0 ]; then
			return 0
		fi
	fi
	return 1
}

# pkg_low <= $pkgver < pkg_high
function pkg_in_range()
{
	pkgver=$(rpm -qa $1 | head -1 | sed 's/\(\w\+-\)//')
	kvercmp "$2" "$pkgver"
	if [ $kver_ret -le 0 ]; then
		kvercmp "$pkgver" "$3"
		if [ $kver_ret -lt 0 ]; then
			return 0
		fi
	fi
	return 1
}

# Usage: tskip "case1 case2 case3 ... caseN" fixed
function tskip()
{
	if echo "|fatal|fixed|unfix|" | grep -q "|$2|"; then
		for tcase in $1; do
			echo "$tcase" >> $(eval echo '${kn_'$2'}')
		done
	else
		echo "Error: parameter \"$2\" is incorrect."
		exit 1
	fi
}

# Keep in mind that all known issues should have finite exclusion range, that
# will end in near future. So that these issues pop up again, once we move to
# new minor/upstream release. And we have chance to re-evaluate.
# For example:
# - kernel_in_range "0" "2.6.32-600.el6" -> FINE
# - kernel_in_range "0" "9999.9999.9999" -> PROBLEM, will be excluded forever
# - osver_in_range "600" "609" -> FINE
# - osver_in_range "600" "99999" -> PROBLEM, will be excluded forever
function knownissue_filter()
{
	# skip OOM tests on large boxes since it takes too long
	[ $(free -g | grep "^Mem:" | awk '{print $2}') -gt 8 ] && tskip "oom0.*" fatal
	# copy_file_range02 is a new unstable test case and changes too frequently
	tskip "copy_file_range02" unfix 
	# move_pages12 patches pending
	# http://lists.linux.it/pipermail/ltp/2019-July/012907.html  --- patch pending on review in upstream
	# http://lists.linux.it/pipermail/ltp/2019-July/012962.html  --- kernel bug in upstream kernel
	tskip "move_pages12" unfix
	# Issue TBD
	tskip "madvise09" fatal
	# https://github.com/linux-test-project/ltp/issues/611
	tskip "ksm0.*" fatal
	# Bug 1660161 - [RHEL8] ltp/generic commands mkswap01 fails to create by-UUID device node in aarch64
	# hugetlb failures should be ignored since that lack of system memory for testing
	tskip "huge.*" fatal
	# Issue TBD
	tskip "memfd_create03" unfix
	# https://lore.kernel.org/linux-btrfs/4d97a9bb-864a-edd1-1aff-bdc9c8204100@redhat.com/T/#u 
	tskip "fs_fill" unfix
	# this case always make the beaker task abort with 'incrementing stop' msg
	tskip "min_free_kbytes" fatal
	# Issue TBD
	tskip "msgstress0.*" unfix
	# Issue TBD
	tskip "epoll_wait02" unfix
	# Issue TBD
	tskip "ftrace-stress-test" fatal
	# Issue TBD
	tskip "sync_file_range02" unfix
	# Issue read_all_sys is triggering hard lockups on mustangs while reading /sys
	# https://lore.kernel.org/linux-arm-kernel/1507592549.3785589.1570404050459.JavaMail.zimbra@redhat.com/
        is_arch "aarch64" && tskip "read_all_sys" fatal
	# OOM tests result in oom errors killing the test harness
	tskip "oom.*" fatal
	# http://lists.linux.it/pipermail/ltp/2019-November/014381.html
	tskip "futex_cmp_requeue01" unfix

	if is_rhel8; then
                # ------- unfix ---------
                # Bug 1734286 - mm: mempolicy: make mbind() return -EIO when MPOL_MF_STRICT is specified
                osver_in_range "800" "802" && tskip "mbind02" unfix
        fi

}

function tcase_exclude()
{
	local config="$*"

	while read skip; do
		echo "Excluding $skip form LTP runtest file"
		sed -i 's/^\('$skip'\)/#disabled, \1/g' ${config}
	done
}

# Usage:    knownissue_exclude "all" "RHELKT1LITE"
#
# Parameter explanation:
#  "all"    - skip all of the knownissues on test system
#  "fatal"  - only skip the fatal knownissues, and mark the others
#             from 'FAIL' to 'KNOW' in test log
#  "none"   - none of the knownissues will be skiped, only change
#             from 'FAIL' to 'KNOW' in test log
function knownissue_exclude()
{
	local param=$1
	shift
	local runtest="$*"

	rm -f ${kn_fatal} ${kn_unfix} ${kn_fixed} ${kn_issue}

	knownissue_filter

	case $param in
	  "all")
		[ -f ${kn_fatal} ] && cat ${kn_fatal} | tcase_exclude ${runtest}
		[ -f ${kn_unfix} ] && cat ${kn_unfix} | tcase_exclude ${runtest}
		[ -f ${kn_fixed} ] && cat ${kn_fixed} | tcase_exclude ${runtest}
		;;
	"fatal")
		[ -f ${kn_fatal} ] && cat ${kn_fatal} | tcase_exclude ${runtest}
		[ -f ${kn_unfix} ] && cat ${kn_unfix} >> ${kn_issue}
		[ -f ${kn_fixed} ] && cat ${kn_fixed} >> ${kn_issue}
		;;
	 "none")
		[ -f ${kn_fatal} ] && cat ${kn_fatal} >> ${kn_issue}
		[ -f ${kn_unfix} ] && cat ${kn_unfix} >> ${kn_issue}
		[ -f ${kn_fixed} ] && cat ${kn_fixed} >> ${kn_issue}
		;;
	      *)
		echo "Error, parameter "$1" is incorrect."
		;;
	esac
}
