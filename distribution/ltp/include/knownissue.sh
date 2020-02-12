#!/bin/bash

# Description:
#   See: https://wiki.test.redhat.com/Kernel/LTPKnownIssue
#        https://url.corp.redhat.com/ltp-overview
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

function is_rhel5() { grep -q "release 5" /etc/redhat-release; }
function is_rhel6() { grep -q "release 6" /etc/redhat-release; }
function is_rhel7() { grep -q "release 7" /etc/redhat-release; }
function is_rhel8() { grep -q "release 8" /etc/redhat-release; }
function is_rhel_alt() { rpm -q --qf "%{sourcerpm}\n" -f /boot/vmlinuz-$(uname -r) | grep -q "alt"; }
function is_upstream() { uname -r | grep -q -v 'el[0-9]\|fc'; }
function is_arch() { [ "$(uname -m)" == "$1" ]; }
function is_zstream() { uname -r | awk -F. '{if (match($4, "[[:digit:]]") != 1) exit 1}'; }
function is_kvm()
{
	if command -v virt-what; then
		hv=$(virt-what)
		[ "$hv" == "kvm" ] && return 0
	fi
	return 1
}
function is_rt() { [ -f /sbin/kernel-is-rt ] && /sbin/kernel-is-rt; }
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

# Usage: tback "case1 case2 case3 ... caseN"
# add back cases,like zstream fixed case
function tback()
{
	for tcase in $1; do
		sed -i "/\b$tcase\b/d" ${kn_fatal} ${kn_unfix} ${kn_fixed}
	done
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

	# this case always make the beaker task abort with 'incrementing stop' msg
	tskip "min_free_kbytes" fatal
	# msgctl10 -> keeps triggerring OOM...(Bug 1162965?), msgctl11 -> too many pids
	# LTP-20180926 renamed msgctl08-11 to msgstress01-04, so skip msgstress03-04 too
	#     https://github.com/linux-test-project/ltp/commit/3e882e3e4c2d
	tskip "msgctl10 msgctl11" fatal
	tskip "msgstress03 msgstress04" fatal
	# read_all_dev can trigger accidental reboots when reading /dev/watchdog
	# https://github.com/linux-test-project/ltp/issues/377
	tskip "read_all_dev" fatal
	# Bug 1534635 - CVE-2018-1000001 glibc: realpath() buffer underflow when getcwd() returns relative path allows privilege escalation
	pkg_in_range "glibc" "0" "2.17-221.el7" && tskip "realpath01 cve-2018-1000001" fixed

	if is_upstream; then
		# ------- unfix ---------
		# http://lists.linux.it/pipermail/ltp/2017-January/003424.html
		kernel_in_range "4.8.0-rc6" "4.12" && tskip "utimensat01.*" unfix
		# http://lists.linux.it/pipermail/ltp/2019-March/011231.html
		kernel_in_range "5.0.0" "5.2.0" && tskip "mount02" unfix

	fi

	if is_rhel8; then
		# ------- fatal ---------
		if [ "$(find /sys/firmware/efi/vars -name raw_var | wc -l)" -ge 1 ];
		then
			# Bug 1628542: kernel panic running LTP read_all_sys on UEFI systems
			osver_in_range "800" "800" && tskip "read_all_sys" fatal
		fi
		# Bug 1684734 - [RHEL-8.0][s390x]ltp-lite mtest06 testing hits EWD due to
		osver_in_range "800" "802" && is_arch "s390x" && tskip "mtest06" fatal
		# Bug 1738338 - [ RHEL-8.1][PANIC][kernel-debug] Oops: 0000 [#1] SMP KASAN NOPTI
		osver_in_range "800" "803" && tskip "proc01" fatal
		# Bug 1789964 - [RHEL-8.2][aarch64/ppc64le] ltp/lite fork09 - fails to complete 
		tskip "fork09" fatal

		# ------- unfix ---------
		# Bug 1657032 - fallocate05 intermittently failing in ltp lite
		osver_in_range "800" "801" && tskip "fallocate05" unfix
		# Bug 1660161 - [RHEL8] ltp/generic commands mkswap01 fails to create by-UUID device node in aarch64
		osver_in_range "800" "801" && is_arch "aarch64" && tskip "mkswap01" unfix
		# Bug 1657880 - CVE-2018-19854 kernel: Information Disclosure in crypto_report_one in crypto/crypto_user.c
		osver_in_range "800" "801" && tskip "cve-2018-19854 crypto_user01" unfix
		# Bug 1650597 - [RHEL8][aarch64][Huawei] ltp/lite migrate_pages failures in T2280
		osver_in_range "800" "801" && is_arch "aarch64" && tskip "migrate_pages03" unfix
		# Bug 1724724 - [RHEL-8.1]LTP: SMSW operation get success with KVM UMIP enabled from userspace
		is_kvm && is_arch "x86_64" && tskip "umip_basic_test" unfix
                # Bug 1739587 - [RHEL-8.1] ltp/generic: syscalls/perf_event_open02 test failures on RT kernel
                is_rt && osver_in_range "800" "802" && tskip "perf_event_open02" unfix
		# Bug 1760638 - timer_create: alarmtimer return wrong errno, on RTC-less system, s390x, ppc64
		! is_arch "x86_64" && osver_in_range "800" "803" && tskip "timer_create01" unfix
		# Bug 1758717 - Snap 4.1 LTP move_pages fail
		osver_in_range "800" "803" && tskip "move_pages12" unfix
		# Bug 1734286 - mm: mempolicy: make mbind() return -EIO when MPOL_MF_STRICT is specified
		osver_in_range "800" "803" && tskip "mbind02" unfix
		# Bug 1777554 - false positive with huge pages on aarch64
		# Note: this can be removed when pkey01 is fixed upstream
		#       http://lists.linux.it/pipermail/ltp/2019-December/014683.html
		is_arch "aarch64" && tskip "pkey01" unfix

		# ------- fixed ---------
		# Bug 1718370 - overlayfs fixes up to upstream 5.2
		kernel_in_range "0" "4.18.0-109.el8" && tskip "fanotify06" fixed
		# Bug 1638647 - ltp execveat03 failed, as missing "355139a8dba4
		kernel_in_range "0" "4.18.0-27.el8" && tskip "execveat03" fixed
		# Bug 1652432 - fanotify: fix handling of events on child sub-directory
		kernel_in_range "0" "4.18.0-50.el8" && tskip "fanotify09" fixed
	fi

	if is_rhel_alt; then
		# ------- fatal ---------
		# Bug 1679243 - RHEL-ALT-7.6z: usage of stale vma in do_fault() can lead to a crash
		osver_in_range "700" "707" && is_arch "s390x" && tskip "mtest06" fatal
		# Bug 1402585 - kernel panic on split_huge_page_to_list() on Pegas
		# Bug 1383953 - WARNING: CPU: 4 PID: 33 at arch/x86/kernel/smp.c:125 native_smp_send_reschedule+0x3f/0x50
		# Bug 1405748 - [Pegas-7.4-20161213.n.2][PANIC] Kernel panic - not syncing: Out of memory and no killable processes...
		# kernel 4.8.0, 4.9.0, 4.10.0 and 4.11.0
		kernel_in_range "4.8.0-0.5.el7" "4.12.0-0.0.el7" && tskip "oom0.*" fatal
		# Bug 1481899 - Pegas1.0 Alpha [ P9 ZZ DD2 ]: machine crashes while running runltp.
		kernel_in_range "4.8.0-0.5.el7" "4.11.0-32.el7" && tskip "keyctl05" fatal
		# Bug 1519901 - WARNING: possible circular locking dependency detected
		is_arch "aarch64" && kernel_in_range "4.14.0-0.el7" "4.14.0-53.el7" && tskip "dynamic_debug01" fatal
		# Bug 1551905 - CVE-2018-5803 kernel-alt: kernel: Missing length check of payload in net/sctp
		kernel_in_range "0" "4.14.0-58.el7" && tskip "cve-2018-5803" fatal
		# Bug 1647199 - pty02 causes kernel panics on kernels older than 4.15, see upstream kernel commit 966031f340185
		tskip "pty02" fatal

		# ------- unfix ---------
		# http://lists.linux.it/pipermail/ltp/2017-January/003424.html
		kernel_in_range "4.8.0-rc6" "4.12" && tskip "utimensat01.*" unfix
		# sysfs syscall is deprecated and not implemented for aarch64 kernels
		# NOTE: sysfs syscall is unrelated to the sysfs filesystem, i.e., /sys
		is_arch "aarch64" && tskip "sysfs" unfix
		# ustat syscall is deprecated and not implemented for aarch64 kernels
		is_arch "aarch64" && tskip "ustat" unfix
		# Bug 1777554 - false positive with huge pages on aarch64
		# Note: this can be removed when pkey01 is fixed upstream
		#       http://lists.linux.it/pipermail/ltp/2019-December/014683.html
		is_arch "aarch64" && tskip "pkey01" unfix

		# ------- fixed ---------
		# disable futex_wake04 until we fix Bug 1087896
		osver_in_range "700" "705" && is_arch "aarch64" && tskip "futex_wake04" fixed
		# Bug 1543265 - CVE-2017-17807 kernel-alt: kernel: Missing permissions check for request_key()
		osver_in_range "700" "708" && tskip "request_key04 cve-2017-17807" fixed
		# Bug 1578750 - ovl: hash directory inodes for fsnotify
		osver_in_range "700" "707" && tskip "inotify07" fixed
		# Bug 1578751 - ovl: hash non-dir by lower inode for fsnotify
		osver_in_range "700" "707" && tskip "inotify08" fixed
		# Bug 1645586 - execveat03 fails, missing upstream patch
		kernel_in_range "0" "4.14.0-116.el7a" && tskip "execveat03" fixed
		# Bug 1632639 - fanotify09 fails
		kernel_in_range "0" "4.14.0-116.el7a" && tskip "fanotify09" fixed
		# Bug 1632639 - bind03 fails
		kernel_in_range "0" "4.14.0-115.el7a"  && tskip "bind03" fixed
		# Bug 1596532 - VFS: regression in fsnotify, resulting in kernel panic or softlockup [7.6-alt]
		kernel_in_range "0" "4.14.0-113.el7a"  && tskip "inotify09" fixed
	fi

	if is_rhel7; then
		# ------- fatal ---------
		# Bug 1708066 - fs/binfmt_misc.c: do not allow offset overflow
		osver_in_range "700" "708" && tskip "binfmt_misc01" fatal
		# Bug 1551906 - CVE-2018-5803 kernel: Missing length check of payload in net/sctp
		kernel_in_range "0" "3.10.0-871.el7" && tskip "cve-2018-5803" fatal
		# Bug 1498371 - CVE-2017-12192 kernel: NULL pointer dereference due to KEYCTL_READ
		kernel_in_range "0" "3.10.0-794.el7" && tskip "keyctl07 cve-2017-12192" fatal
		# Bug 1438998 - CVE-2017-2671 kernel: ping socket / AF_LLC connect() sin_family race
		kernel_in_range "0" "3.10.0-647.el7" && tskip "cve-2017-2671" fatal
		# Bug 1502625 - CVE-2017-12193 kernel: Null pointer dereference due to incorrect node-splitting
		kernel_in_range "0" "3.10.0-794.el7" && tskip "cve-2017-12193 add_key04" fatal
		# Bug 1579131 - sched/sysctl: Check user input value of sysctl_sched_time_avg
		osver_in_range "700" "707" && tskip "sysctl01.*" fatal
		# Bug 1464851 - kernel panic when ran ltp syscalls add_key02 on RHEL7.4
		kernel_in_range "0" "3.10.0-794.el7" && tskip "add_key02 cve-2017-15274" fatal
		# Bug 1461637 - [ltp/msgctl10] BUG: unable to handle kernel paging request at ffff8800abe4a5a0
		kernel_in_range "0" "3.10.0-957.el7" && tskip "msgctl10" fatal
		# Bug 1266759 - [s390x] ltp/futex_wake04.c cause system hang
		kernel_in_range "0" "3.10.0-957.el7" && is_arch "s390x" && tskip "futex_wake04" fatal
		# futex_wake04 hangs 7.0z
		kernel_in_range "0" "3.10.0-229.el7" && tskip "futex_wake04" fatal
		# Bug 1276398 - parallel memory allocation with numa balancing...
		[ $(free -g | grep Mem | awk '{print $2}') -gt 512 ] && \
			kernel_in_range "0" "3.10.0-436.el7" && tskip "mtest0.*" fatal
		# Bug 1256718 - Unable to handle kernel paging request for data in vmem_map
		kernel_in_range "0" "3.10.0-323.el7" && tskip "rwtest03.*" fatal
		# Bug 1247436 - BUG: soft lockup - CPU#3 stuck for 22s! [inotify06:51229]
		kernel_in_range "0" "3.10.0-320.el7" && tskip "inotify06.*" fatal
		# BUG: Bad page state in process msgctl11  pfn:3940e
		kernel_in_range "3.10.0-229.el7" "3.10.0-514.el7" && tskip "msgctl11" fatal
		# Bug 1481114 - [LTP fanotify07] kernel hangs while testing fanotify permission event destruction
		kernel_in_range "0" "3.10.0-810.el7" && tskip "fanotify07" fatal
		# Bug 1543262 - CVE-2017-17807 kernel: Missing permissions check for request_key()
		osver_in_range "700" "708" && tskip "request_key04 cve-2017-17807" fatal
		# Bug TBD - needs investigation: fallocate05 fails on ppc64/ppc64le
		is_arch "ppc64" && tskip "fallocate05" fatal
		is_arch "ppc64le" && tskip "fallocate05" fatal
		# Bug 1503242 - Backport keyring fixes
		kernel_in_range "0" "3.10.0-794.el7" && tskip "request_key03 cve-2017-15951 cve-2017-15299" fatal
		# Bug 1422368 - kernel: Off-by-one error in selinux_setprocattr
		kernel_in_range "0" "3.10.0-584.el7" && tskip "cve-2017-2618" fatal

		# ------- unfix ---------
		# Bug 1543262 - CVE-2017-17807 kernel: Missing permissions check for request_key()
		osver_in_range "700" "709" && tskip "request_key04 cve-2017-17807" unfix
		# Bug 1688067 - [xfstests]: copy_file_range cause corruption on rhel-7
		osver_in_range "707" "710" && tskip "copy_file_range01" unfix
		# Bug 1708078 - cve-2017-17806 crypto: hmac - require that the underlying hash algorithm is unkeyed
		osver_in_range "700" "708" && tskip "af_alg01 cve-2017-17806" unfix
		# Bug 1708089 - crypto: af_alg - consolidation * of duplicate code
		osver_in_range "700" "709" && tskip "af_alg02 cve-2017-17805" unfix
		# Bug 1672242 - clash between linux/in.h and netinet/in.h
		osver_in_range "700" "708" && tskip "setsockopt03 cve-2016-4997" unfix
		# Bug 1639345 - [RHEL-7.7] fsnotify: fix ignore mask logic in fsnotify
		osver_in_range "700" "708" && tskip "fanotify10" unfix
		# Bug 1666604 - shmat returned EACCES when mapping the nil page
		osver_in_range "700" "711" && tskip "shmat03 cve-2017-5669" unfix
		# Bug 1666588 - getrlimit03.c:121: FAIL: __NR_prlimit64(0) had rlim_cur = ffffffffffffffff but __NR_getrlimit(0) had rlim_cur = ffffffffffffffff
		osver_in_range "700" "708" && is_arch "s390x"&& tskip "getrlimit03" unfix
		# Bug 1593435 - ppc64: kt1lite getrandom02 test failure reported
		osver_in_range "705" "707" && is_arch "ppc64" && tskip "getrandom02" unfix
		# Bug 1593435 - ppc64: kt1lite getrandom02 test failure reported
		osver_in_range "705" "707" && is_arch "ppc64le" && tskip "getrandom02" unfix
		# Bug 1185242 - Corruption with O_DIRECT and unaligned user buffers
		tskip "dma_thread_diotest" unfix
		# disable sysctl tests -> RHEL7 does not support these
		tskip "sysctl" unfix
		# Bug 1431926 - CVE-2016-10044 kernel: aio_mount function does not properly restrict execute access
		tskip "cve-2016-10044" unfix
		# Bug 1760639 - rhel7 timer_create: alarmtimer return wrong errno, on RTC-less system, s390x, ppc64
		! is_arch "x86_64" && osver_in_range "700" "709" && tskip "timer_create01" unfix
		# Bug 1726896 - mm: fix race on soft-offlining free huge pages
		osver_in_range "700" "709" && tskip "move_pages12" unfix

		# ------- fixed ---------
		# Bug 1652436 - fanotify: fix handling of events on child sub-directory
		osver_in_range "700" "708" && tskip "fanotify09" fixed
		# Bug 1597738 - [RHEL7.6]ltp fanotify09 test failed as missing patch of "fanotify: fix logic of events on child"
		kernel_in_range "0" "3.10.0-951.el7" && tskip "fanotify09" fixed
		# Bug 1633059 - [RHEL7.6]ltp syscalls/mlock203 test failed as missing patch "mm: mlock:
		kernel_in_range "0" "3.10.0-957.el7" && tskip "mlock203" fixed
		# Bug 1569921 - rhel7.5 regression in fsnotify, resulting in kernel panic or softlockup
		kernel_in_range "0" "3.10.0-896.el7"  && tskip "inotify09" fixed
		# Bug 1578750 - ovl: hash directory inodes for fsnotify
		osver_in_range "700" "707" && tskip "inotify07" fixed
		# Bug 1578751 - ovl: hash non-dir by lower inode for fsnotify
		osver_in_range "700" "707" && tskip "inotify08" fixed
		# Bug 1481118 - [LTP fcntl35] unprivileged user exceeds fs.pipe-max-size
		kernel_in_range "0" "3.10.0-951.el7" && tskip "fcntl35" fixed
		# Bug 1490308 - [LTP keyctl04] fix keyctl_set_reqkey_keyring() to not leak thread keyrings
		osver_in_range "700" "706" && tskip "keyctl04" fixed
		# Bug 1490314 - [LTP cve-2017-5669] test for "Fix shmat mmap nil-page protection" fails
		osver_in_range "700" "707" && tskip "cve-2017-5669" fixed
		# Bug 1450158 - CVE-2017-7472 kernel: keyctl_set_reqkey_keyring() leaks thread keyrings
		kernel_in_range "0" "3.10.0-794.el7" && tskip "cve-2017-7472" fixed
		# Bug 1421964 - spurious EMFILE errors from inotify_init
		kernel_in_range "0" "3.10.0-593.el7" && tskip "inotify06.*" fixed
		# Bug 1418182 - [FJ7.3 Bug]: The [X]GETNEXTQUOTA subcommand on quotactl systemcall returns a wrong value
		kernel_in_range "0" "3.10.0-592.el7" && tskip "quotactl03" fixed
		# Bug 1395538 - xfs: getxattr spuriously returns -ENOATTR due to setxattr race
		kernel_in_range "0" "3.10.0-561.el7" && tskip "getxattr04" fixed
		# Bug 1216957 - rsyslog restart pulls lots of older log entries again...
		kernel_in_range "3.10.0-229.el7" "3.10.0-693.el7" && tskip "syslog01" fixed
		# Bug 1385124 - CVE-2016-5195 kernel: Privilege escalation via MAP_PRIVATE
		kernel_in_range "0" "3.10.0-514.el7" && tskip "dirtyc0w" fixed
		# Bug 1183961 - fanotify: fix notification of groups with inode...
		kernel_in_range "0" "3.10.0-449.el7" && tskip "fanotify06" fixed
		# Bug 1293401 - kernel: User triggerable crash from race between key read and rey revoke [RHEL-7]
		kernel_in_range "0" "3.10.0-343.el7" && tskip "cve-2015-7550 keyctl02.*" fixed
		# Bug 1323048 - Page fault is not avoidable by using madvise...
		osver_in_range "700" "703" && tskip "madvise06" fixed
		# Bug 1232712 - x38_edac polluting logs: dmesg / systemd's journal
		kernel_in_range "0" "3.10.0-285.el7" && tskip "kmsg01" fixed
		# Bug 1162965 - Kernel panic - not syncing: Out of memory and no killable processes...
		kernel_in_range "0" "3.10.0-219.el7" && tskip "msgctl10" fixed
		# Bug 1121784 - Failed RT Signal delivery can corrupt FP registers
		kernel_in_range "0" "3.10.0-201.el7" && tskip "signal06" fixed
		# Bug 1156096 - ext4: rest of the update for rhel7.1
		kernel_in_range "0" "3.10.0-200.el7" && tskip "mmap16" fixed
		# Bug 1107774 - powerpc: 64bit sendfile is capped at 2GB
		kernel_in_range "0" "3.10.0-152.el7" && is_arch "ppc64" && tskip "sendfile09" fixed
		# Bug 1072385 - CVE-2014-8173 trinity hit BUG: unable to handle kernel...
		kernel_in_range "0" "3.10.0-148.el7" && tskip "madvise05" fixed
		# Bug 1092746 - system calls including getcwd and files in...
		kernel_in_range "0" "3.10.0-125.el7" && tskip "getcwd04" fixed
		# Bug 1351249 - [RHELSA-7.3] ltptest hits EWD at mtest01w
		kernel_in_range "0" "4.5.0-0.45.el7" && is_arch "aarch64" && tskip "mtest0.*" fixed
		# Bug 1352669 - [RHELSA-7.3] ltptest hits EWD at madvise06
		kernel_in_range "0" "4.5.0-0.45.el7" && is_arch "aarch64" && tskip "madvise06" fixed
		# Bug 1303001 - read() return -1 ENOMEM (Cannot allocate memory))...
		kernel_in_range "0" "4.5.0-0.rc3.27.el7" && is_arch "aarch64" && tskip "dio04 dio10" fixed
		# disable gethostbyname_r01, GHOST glibc CVE-2015-0235
		pkg_in_range glibc "0" "2.18" && tskip "gethostbyname_r01" fixed
		# Bug 1144516 - LTP profil01 test fails on RHELSA aarch64
		pkg_in_range "glibc" "0" "2.17-165.el7" && is_arch "aarch64" && tskip "profil01" fixed
		# Bug 1330705 - open() and openat() ignore 'mode' with O_TMPFILE
		pkg_in_range "glibc" "0" "2.17-159.el7.1" && tskip "open14 openat03"  fixed
		# Bug 1439264 - CVE-2017-6951 kernel: NULL pointer dereference in keyring_search_aux function [rhel-7.4]
		kernel_in_range "0" "3.10.0-686.el7" && tskip "cve-2017-6951 request_key05" fixed
		# Bug 1273465 - CVE-2015-7872 kernel: Using request_key() or keyctl request2 to get a kernel causes the key garbage collector to crash
		kernel_in_range "0" "3.10.0-332.el7" && tskip "keyctl03" fixed

		# Bug 1509152 - KEYS: return full count in keyring_read() if buffer is too small
		kernel_in_range "0" "3.10.0-794.el7" && tskip "keyctl06" fixed
		# Bug 1503242 - Backport keyring fixes
		kernel_in_range "0" "3.10.0-794.el7" && tskip "add_key03" fixed
		# Bug 1389309 - CVE-2016-9604 kernel: security: The built-in keyrings for security tokens can be joined as a session and then modified by the root user [rhel-7.4]
		kernel_in_range "0" "3.10.0-686.el7" && tskip "keyctl08 cve-2016-9604" fixed
		# Bug 1437404 - CVE-2017-7308 kernel: net/packet: overflow in check for priv area size
		kernel_in_range "0" "3.10.0-656.el7" && tskip "setsockopt02" fixed

		if is_zstream; then
			# Bug 1441171 - CVE-2017-7308 kernel: net/packet: overflow in check for priv area size [rhel-7.3.z]
			kernel_in_range "3.10.0-514.21.1.el7" "3.10.0-514.999" && tback "setsockopt02"
			# Bug 1658607 - ltp/lite fallocate05 failing on RHEL-6.10
			# Skip <= 72z
			kernel_in_range "0" "3.10.0-327.9999" && tskip "fallocate05" fixed
			# Bug 1455609 - CVE-2017-8890 kernel: Double free in the inet_csk_clone_lock function in net/ipv4/inet_connection_sock.c [rhel-7.4]
			kernel_in_range "0" "3.10.0-693.0" && tskip "cve-2017-8890 accept02" fixed
			# Bug 1544612 (CVE-2018-6927) - CVE-2018-6927 kernel: Integer overflow in futex.c:futux_requeue can lead to denial of service or unspecified impact
			kernel_in_range "0" "3.10.0-862.0" && tskip "cve-2018-6927 futex_cmp_requeue02" fixed
			# Bug 1402013 (CVE-2016-9793) - CVE-2016-9793 kernel: Signed overflow for SO_{SND|RCV}BUFFORCE
			kernel_in_range "0" "3.10.0-327.9999" && tskip "cve-2016-9793 setsockopt04" fixed
			# fanotify06 new subcase skipped on zstream.
			tskip "fanotify06" fixed
		fi
	fi

	if is_rhel6; then
		# ------- fatal ---------
		# Bug 1710149 - fs/binfmt_misc.c: do not allow offset overflow
		osver_in_range "600" "611" && tskip "binfmt_misc01" fatal
		# Bug 1551908 - CVE-2018-5803 kernel: Missing length check of payload in net/sctp
		kernel_in_range "0" "2.6.32-751.el6" && tskip "cve-2018-5803" fatal
		# Bug 1438999 - CVE-2017-2671 kernel: ping socket / AF_LLC connect() sin_family race [rhel-6.10]
		kernel_in_range "0" "2.6.32-702.el6" && tskip "cve-2017-2671" fatal
		# Bug 1293402 - kernel: User triggerable crash from race between key read and ...
		kernel_in_range "0" "2.6.32-600.el6" && tskip "cve-2015-7550 keyctl02.*" fatal
		# Bug 1273463 - CVE-2015-7872 kernel: Using request_key() or keyctl request2 ...
		kernel_in_range "0" "2.6.32-585.el6" && tskip "keyctl03.*" fatal
		# kernel BUG at kernel/cred.c:97!
		osver_in_range "600" "609" && tskip "cve-2015-3290" fatal
		# Bug 1453183 - NULL ptr deref at follow_huge_addr+0x78/0x100
		osver_in_range "600" "611" && tskip "move_pages12.*" fatal
		# Bug 1490917 - CVE-2017-6951 kernel: NULL pointer dereference in keyring_search_aux function [rhel-6.10]
		osver_in_range "600" "611" && tskip "cve-2017-6951 request_key05" fatal
		# Bug 1498365 - CVE-2017-12192 kernel: NULL pointer dereference due to KEYCTL_READ
		osver_in_range "600" "611" && tskip "keyctl07 cve-2017-12192" fatal
		# Bug 1446569 - CVE-2016-9604 kernel: security: The built-in keyrings for security tokens can be joined as
		osver_in_range "600" "611" && tskip "cve-2016-9604" fatal
		# Bug 1450157 - CVE-2017-7472 kernel: keyctl_set_reqkey_keyring() leaks thread keyrings [rhel-6.10]
		osver_in_range "600" "611" && tskip "cve-2017-7472" fatal
		# Bug 1502909 - CVE-2017-15274 kernel: dereferencing NULL payload with nonzero length [rhel-6.10]
		osver_in_range "600" "611" && tskip "cve-2017-15274" fatal
		# Bug 1558845 - LTP fork05 reports 'BUG: unable to handle kernel paging request at XXX
		osver_in_range "600" "611" && tskip "fork05.*" fatal
		# Bug 1560398 - LTP modify_ldt02 causes panic 'BUG: unable to handle kernel paging request at XXX'
		osver_in_range "600" "611" && tskip "modify_ldt02.*" fatal
		# Bug 1543261 - CVE-2017-17807 kernel: Missing permissions check for request_key()
		osver_in_range "600" "611" && tskip "request_key04 cve-2017-17807" fatal
		# Bug 1579128 - sched/sysctl: Check user input value of sysctl_sched_time_avg
		osver_in_range "600" "611" && tskip "sysctl01.*" fatal

		# ------- unfix ---------
		# Bug 1653138 - remap_file_pages() return success in use after free of shm file
		osver_in_range "600" "611" && tskip "shmctl05" unfix
		# Bug 1537384 - KEYS: Disallow keyrings beginning with '.' to be joined as session keyrings
		osver_in_range "600" "611" && tskip "keyctl08" unfix
		# Bug 1537371 - KEYS: prevent creating a different user's keyrings
		osver_in_range "600" "611" && tskip "add_key03" unfix
		# Bug 1477055 - add_key02.c:99: FAIL: unexpected error with key type 'user': EINVAL
		osver_in_range "600" "610" && tskip "add_key02" unfix
		# Bug 1323048 - Page fault is not avoidable by using madvise...
		osver_in_range "600" "610" && tskip "madvise06" unfix
		# disable signal06 until we backport df24fb859a4e200d, 66463db4fc5605d51c7bb
		osver_in_range "600" "610" && tskip "signal06" unfix
		# Bug 1413025 - avc: denied { write } for pid=11089
		osver_in_range "600" "610" && tskip "quotactl01" unfix
		# Bug 1412044 - sctp: fix -ENOMEM result with invalid
		osver_in_range "600" "610" && tskip "sendto02" unfix
		# Bug 1455546 - [RHEL6.9][kernel] LTP recvmsg03 test hangs
		osver_in_range "600" "611" && tskip "recvmsg03.*" unfix
		# Bug 1490308 - [LTP keyctl04] fix keyctl_set_reqkey_keyring() to not leak thread keyrings
		osver_in_range "600" "611" && tskip "keyctl04" unfix
		# Bug 1491136 - [LTP cve-2017-5669] test for "Fix shmat mmap nil-page protection" fails
		osver_in_range "600" "611" && tskip "cve-2017-5669 shmat03" unfix
		#Bug 1652855 - LTP fcntl33 fcntl33_64 report FAIL: fcntl() downgraded lease when not read-only
		osver_in_range "600" "611" && tskip "fcntl33 fcntl33_64" unfix
		# Bug 1461342 - clock_adjtime(CLOCK_REALTIME) doesn't return current timex data
		osver_in_range "600" "611" && tskip "clock_adjtime02" unfix
		# Bug 1059782 - backport numa: add a sysctl for numa_balancing
		osver_in_range "600" "611" && tskip "migrate_pages02" unfix
		# ------- fixed ---------
		# disable mlock03, it has been marked as broken on RHEL6
		tskip "mlock03" fixed
		# Bug 1193250 - FUTEX_WAKE may fail to wake waiters on...
		kernel_in_range "0" "2.6.32-555.el6" && tskip "futex_wake04" fixed
		# Bug 848316 - [hugetblfs]Attempt to mmap into highmem...
		kernel_in_range "0" "2.6.32-449.el6" && is_arch "ppc64" && tskip "mmap15" fixed
		# Bug 1205014 - vfs: fix data corruption when blocksize...
		kernel_in_range "0" "2.6.32-622.el6" && tskip "mmap16" fixed
		# Bug 862177 - [RHEL6] readahead not behaving as expected
		kernel_in_range "0" "2.6.32-465.el6" && tskip "readahead02.*" fixed
		# Bug 815891 - fork incorrectly succeeds when virtual...
		kernel_in_range "0" "2.6.32-304.el6" && tskip "fork14" fixed
		# disable vma testcases because of Bug 725855, for <RHEL6.4
		kernel_in_range "0" "2.6.32-279.el6" && tskip "vma0.*" fixed
		# disable gethostbyname_r01, GHOST glibc CVE-2015-0235
		pkg_in_range glibc "0" "2.18" && tskip "gethostbyname_r01" fixed
		# Bug 822731 - CVE-2012-3430 kernel: recv{from,msg}() on an rds socket can leak kernel memory [rhel-6.4]
		kernel_in_range "0" "2.6.32-294.el6" && tskip "recvmsg03.*" fixed
		# disable getrusage04 because bug 690998 is not in RHEL 6.0-z
		kernel_in_range "0" "2.6.32-131.0.5.el6" && tskip "getrusage04.*" fixed
	        # Bug 789238 - [FJ6.2 Bug]: malloc() deadlock in case of allocation...
		pkg_in_range "glibc" "0" "2.12-1.68.el6" && tskip "mallocstress" fixed
		# Bug 1547587 - CVE-2018-6927 kernel: Integer overflow in futex.c:futux_requeue can lead to denial of service or unspecified impact [rhel-6.10]
		osver_in_range "600" "611" && tskip "cve-2018-6927 futex_cmp_requeue02" fixed

		if is_zstream; then
			# Bug 1455612 - CVE-2017-8890 kernel: Double free in the inet_csk_clone_lock function in net/ipv4/inet_connection_sock.c [rhel-6.10]
			kernel_in_range "0" "2.6.32-754.0" && tskip "cve-2017-8890 accept02" fixed
			# Bug 1610958 (CVE-2017-18344) - CVE-2017-18344 kernel: out-of-bounds access in the show_timer function in kernel/time/posix-timers.c
			kernel_in_range "0" "2.6.32-754.999" && tskip "cve--2017-18344 timer_create03" fixed
		fi
	fi

	if is_rhel5; then
		tskip "keyctl02 proc01 cve-2017-5669 \
			cve-2017-6951 cve-2017-2671 \
			request_key04 cve-2017-17807 \
			cve-2015-7550 cve-2018-5803 \
			binfmt_misc01" \
		fatal

		tskip "mmap16 fork14 gethostbyname_r01 \
			add_key02 keyctl04 sendto02 \
			signal06 vma05 dynamic_debug01 \
			poll02 select04" \
		unfix
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
