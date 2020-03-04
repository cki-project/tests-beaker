#!/bin/bash
set -x

. /usr/bin/rhts_environment.sh

YUM=$(command -v yum)
if [ -z "$YUM" ]
then
	YUM=$(command -v dnf)
fi

function test_pass()
{
	rstrnt-report-result $TEST PASS 0
}

function test_fail()
{
	rstrnt-report-result $TEST FAIL 1
}

function test_skip()
{
	rstrnt-report-result $TEST SKIP 0
}

function nvr_kernel_current()
{
	rpm -qa "kernel*" | grep "$(uname -r)" | sort | head -n1
}

function nvr_kernel_latest()
{
	$YUM list --available kernel{,-rt}.$(uname -m) --showduplicates \
	| sed "s/.$(uname -m)//" \
	| sort -k1,1 -k2V \
	| awk 'END { print $1"-"$2".'$(uname -m)'"; }'
}

# Determine which kernel debuginfo to download.
# By default, use currently running kernel (unless overriden from env).
# This can be achieved either by specifying KERNEL_NVR directly, or one
# of the following two test config options:
# CONFIG_NVR_KERNEL_{CURRENT,LATEST}

if [ -z "${KERNEL_NVR++}" ]
then
	echo "DEBUG: Using current kernel nvr."
	KERNEL_NVR="$(nvr_kernel_current)"
else
	echo "DEBUG: Using user provided kernel NVR: $KERNEL_NVR"
fi

if [ -n "$CONFIG_NVR_KERNEL_CURRENT" ]
then
	echo "DEBUG: Using current kernel nvr."
	KERNEL_NVR="$(nvr_kernel_current)"
fi

if [ -n "$CONFIG_NVR_KERNEL_LATEST" ]
then
	echo "DEBUG: Using latest available kernel."
	KERNEL_NVR="$(nvr_kernel_latest)"
fi

if [ -z "${KERNEL_NVR++}" ]
then
	echo "ERROR: Unable to determine kernel nvr."
	echo "DEBUG: CONFIG_NVR_KERNEL_CURRENT: " \
	     $CONFIG_NVR_KERNEL_CURRENT
	echo "DEBUG: CONFIG_NVR_KERNEL_LATEST: " \
	     $CONFIG_NVR_KERNEL_LATEST
	echo "DEBUG: rpm -qa \"kernel*\""
	rpm -qa "kernel*"
	echo "DEBUG: uname -r: $(uname -r)"
	echo "DEBUG: $YUM list --available kernel{,rt}.$(uname -m)" \
	     "--showduplicates:"
	$YUM list --available kernel{,-rt}.$(uname -m) --showduplicates
	test_skip "FAILED. SEE ERROR OUTPUT ABOVE."
	exit 0
fi >&2

KERNEL_DEBUGINFO_NVR="$(
	echo $KERNEL_NVR | sed 's/^\([^0-9]*\)/\1debuginfo-/'
)"

TEMP_DIR="$(mktemp -d)"
OLD_CWD="$(pwd)"

cd "$TEMP_DIR"

if ! yumdownloader "$KERNEL_DEBUGINFO_NVR"
then
	echo "ERROR: Unable to download debuginfo RPM:" \
	     "$KERNEL_DEBUGINFO_NVR" >&2
	echo "DEBUG: List of $YUM list all" >&2
	$YUM list all >&2
	test_skip "FAILED. SEE ERROR OUTPUT ABOVE."
	exit 0
fi

RPM="$(find . -iname "$KERNEL_DEBUGINFO_NVR*.rpm" -type f)"

if [ -z "$RPM" -o ! -e "$RPM" ]
then
	echo "ERROR: Unable to find RPM." >&2
	echo "DEBUG: find ." >&2
	set -x
	find .
	test_skip "FAILED. SEE ERROR OUTPUT ABOVE."
	exit 0
fi

case $(file "$RPM" | cut -f2 -d' ' | tr '[A-Z]' '[a-z]') in
rpm)
	;;
*)
	echo "ERROR: Downloaded unknown filetype." >&2
	echo "DEBUG: file $RPM: $(file "$RPM")" >&2
	test_skip "FAILED. SEE ERROR OUTPUT ABOVE."
	exit 0
	;;
esac

RPM_VMLINUX_PATH="$(
	rpm2cpio "$RPM" 2> /dev/null                                       \
	| cpio -t       2> /dev/null                                       \
	| grep vmlinux
)"

rpm2cpio "$RPM"                 2> /dev/null                               \
| cpio -idv "$RPM_VMLINUX_PATH" 2> /dev/null

VMLINUX="$(find . -iname "vmlinux" -type f)"

if [ -z "$VMLINUX" -o ! -e "$VMLINUX" ]
then
	echo "ERROR: Unable to find vmlinux in RPM's contents." >&2
	echo "DEBUG: find ." >&2
	set -x
	find . >&2
	test_skip "FAILED. SEE ERROR OUTPUT ABOVE."
	exit 0
fi

if ! objdump -h "$VMLINUX" \
     | grep -E "[[:space:]]*[0-9]+[[:space:]]*.debug" &> /dev/null
then
	echo "ERROR: Unable to find .debug sections in vmlinux ELF." >&2
	test_fail "FAILED. SEE ERROR OUTPUT ABOVE."
	exit 1
else
	test_pass "TEST PASSED."
fi

cd $OLD_CWD
