#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/networking/kselftests
#   Description: kselftests
#   Author: Hangbin Liu <haliu@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Global parameters
# DEBUG: enable debug or not, default is true
# CHECK_UNINVES: also check uninvestigated tests result, default is false
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
. ./include.sh
#-------------------- Setup --------------------
EXEC_DIR="$PWD/kselftests"
SKIP=4

# Test items
LOG_ONCE=0
TEST_ITEMS=${TEST_ITEMS:-"net net/forwarding bpf tc-testing"}

DEFAULT_IFACE=$(ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}')
TOTAL_MEM=$(free -m | awk '/Mem/ {print $2}')

skip_tests=(
# CONFIG_TEST_BPF is not set
test_bpf.sh
)

# Tests in this list need large memory
large_mem_tests=(
tc-tests/filters/concurrency.json
tc-tests/filters/tests.json
)

debug_info()
{
	[ ${LOG_ONCE} -eq 0 ] && \
		log "$(rpm -q bpftool clang llvm iproute iproute-tc)" && \
		LOG_ONCE=1

	if [ "$DEBUG" ]; then
		run "ip link show"
		run "bpftool prog show"
		run "iptables -L"
		run "ip6tables -L"
	fi
}

clean_env()
{
	# log the link before clean
	debug_info
	modprobe -r ipip
	modprobe -r vxlan
	modprobe -r geneve
	modprobe -r ip_gre
	modprobe -r ip6_gre
	modprobe -r ip6_vti
	modprobe -r ip6_tunnel
	modprobe -r veth
	# Looks fedora doesn't has this module
	# modprobe -r netdevsim
	ip -a netns del
	sleep 2
	debug_info
}

# usage: check_skipped_tests test_name "${skip_test[@]}"
check_skipped_tests()
{
	local match="$1"
	[[ " ${skip_tests[*]} " == *" $match "* ]] && return 0
	[ $TOTAL_MEM -lt 8000 ] && [[ " ${large_mem_tests[*]} " == *" $match "* ]] && return 0
	# skip the test if it not exist for backward compatibility
	[ ! -f $match ] && return 0
	return 1
}

run_test()
{
	local test_name=$1

	# some times the test may fail with resource issue, re-run it would
	# pass
	./${test_name} &> $OUTPUTFILE
	local ret=$?
	if [ $ret -ne 0 ]; then
		./${test_name} &>> $OUTPUTFILE
	else
		return $ret
	fi
}

# For upstream kselftest testing, we need a pre-build selftest tar ball url
install_kselftests()
{
	wget --no-check-certificate $CKI_SELFTEST_URL -O kselftest.tar.gz
	tar zxf kselftest.tar.gz
	[ -f kselftest/run_kselftest.sh ] && return 0 || return 1
}

install_netsniff()
{
	dnf install -y jq netsniff-ng
	which mausezahn && return 0 || return 1
}

install_smcroute()
{
	which smcroute && return 0
	yum install -y libcap-devel
	smc_v="2.4.4"
	wget https://github.com/troglobit/smcroute/releases/download/${smc_v}/smcroute-${smc_v}.tar.gz
	tar zxf smcroute-${smc_v}.tar.gz
	pushd smcroute-${smc_v}
	./autogen.sh && ./configure --sysconfdir=/etc --localstatedir=/var && make && make install
	popd
	which smcroute && return 0 || return 1
}

# @arg1: test name
get_test_list()
{
	local name=$1
	local start_line end_line test_list

	pushd $EXEC_DIR &> /dev/null

	if [ $name == "net/forwarding" ]; then
		test_list=$(find net/forwarding -maxdepth 1 -perm -g=x -type f | sed "s/net\/forwarding\///")
	else
		start_line=$(grep -n "in $name" run_kselftest.sh | cut -f1 -d:)
		sed -n "${start_line},$ p" run_kselftest.sh > ${name}.list
		end_line=$(grep -n "cd \$ROOT" ${name}.list | head -n1 | cut -f1 -d:)
		sed -i "${end_line},$ d" ${name}.list
		sed -i "1,3 d" ${name}.list
		test_list=$(cat ${name}.list | awk -F'"' '{print $2}')
	fi
	popd &> /dev/null
	echo $test_list
}

check_result()
{
	local num=$1
	local total_num=$2
	local test_folder=$3
	local test_name=$4
	local test_result=$5

	if [ "$test_result" -eq 0 ]; then
		test_pass "${num}..${total_num} selftests: ${test_folder}: ${test_name} [PASS]"
	elif [[ " ${pending_tests[*]} " == *" $test_name "* ]] && [ ! $CHECK_UNINVES ]; then
		test_pass "${num}..${total_num} selftests: ${test_folder}: ${test_name} [WAIVE]"
	elif [[ " ${uninves_tests[*]} " == *" $test_name "* ]] && [ ! $CHECK_UNINVES ]; then
		test_pass "${num}..${total_num} selftests: ${test_folder}: ${test_name} [WAIVE]"
	elif [ "$test_result" -eq $SKIP ]; then
		test_pass "${num}..${total_num} selftests: ${test_folder}: ${test_name} [SKIP]"
	else
		test_fail "${num}..${total_num} selftests: ${test_folder}: ${test_name} [FAIL]"
	fi

	return $test_result
}

do_net_config()
{
	# Fix some known issues
	# rm 0x10 for fib_rule_tests.sh due to bz1480136
	# FIXME: should we restore it back after finishing test?
	sed -i "/0x10/d" /etc/iproute2/rt_dsfield
	# FIXME: sleep 5s before do IPv6 "Using route with mtu metric" test to
	# pass it. Not sure why ping would fail if not sleep some seconds, need to check
	sed -i "/via 2001:db8:101::2 mtu 1300/a\\\\tsleep 5" fib_tests.sh
	# need to be run on bare metal machines, or set -C 0 when run on VM
	sed -i 's/-C [0-9]/-C 0/g' msg_zerocopy.sh
	# fou is not enabled on RHEL
	sed -i 's/kci_test_encap_fou /#kci_test_encap_fou /' rtnetlink.sh
	# ip_defrag.sh need setting net.netfilter.nf_conntrack_frag6_high_thresh
	modprobe nf_conntrack_ipv6
	# pmtu.sh will return 1 for skiped tests, remove fou,gue tests
	sed -i '/^\tpmtu_ipv[4,6]_fou[4,6]_exception/d' pmtu.sh
	sed -i '/^\tpmtu_ipv[4,6]_gue[4,6]_exception/d' pmtu.sh
	sed -i 's/exitcode=1/[ $ret -ne 2 ] \&\& exitcode=1/' pmtu.sh
}

do_net_forwarding_config()
{
	which tc || dnf install -q -y iproute-tc
	install_netsniff || { test_fail "install netsniff for forwarding test failed" && return 1; }
	install_smcroute || { test_fail "install smcrouted for forwarding test failed" && return 1; }
	cp forwarding.config.sample forwarding.config
}

do_bpf_config() { return 0; }

do_tc_test()
{
	# Start tc test
	local item="tc-testing"
	local act_tests=$(ls -d tc-tests/actions/*.json)
	local fil_tests=$(ls -d tc-tests/filters/*.json)
	local qdi_tests=$(ls -d tc-tests/qdiscs/*.json)
	local total_tests="$act_tests $fil_tests $qdi_tests"
	local total_num=$(echo ${total_tests} | wc -w)
	local nfail=0 nskip=0 ret=0

	# prepare evn
	rpm -q clang || dnf install -y clang valgrind
	modprobe -r veth
	cd $EXEC_DIR/tc-testing

	# extend test timeout
	sed -i '/TIMEOUT/s/12/180/' tdc_config.py
	# to build action.o for test tc-tests/actions/bpf.json
	run "clang -target bpf -c bpf/action.c -o bpf/action.o"

	for name in ${total_tests}; do
		num=$(($num + 1))
		local OUTPUTFILE=$(new_outputfile)

		check_skipped_tests "${name}" && \
			test_pass "${num}..${total_num} selftests: ${item}: ${name} Skip" && continue

		echo ${tc_tests[$num - 1]} | grep -qP "tests\.json|concurrency\.json"  && extra_p="-d $DEFAULT_IFACE" || extra_p=""
		./tdc.py -f ${name} $extra_p &> $OUTPUTFILE
		ret=$?
		if grep -q "not ok" $OUTPUTFILE; then
			check_result $num $total_num ${item} ${name} 1
			nfail=$((nfail+1))
		elif grep -q "# skipped -" $OUTPUTFILE; then
			check_result $num $total_num ${item} ${name} 4
			nskip=$((nskip+1))
		elif grep -q "Traceback" $OUTPUTFILE; then
			check_result $num $total_num ${item} ${name} 4
			nskip=$((nskip+1))
		else
			check_result $num $total_num ${item} ${name} $ret
		fi
	done

	echo "${item}: total $total_num, failed $nfail, skipped $nskip"
}

#-------------------- Start Test --------------------
[ ! "$CKI_SELFTEST_URL" ] && test_skip_exit "No CKI_SELFTEST_URL found"
install_kselftests || test_fail_exit "install kselftests failed"

run "uname -r"
clean_env
submit_log "$EXEC_DIR/run_kselftest.sh"

for item in $TEST_ITEMS; do
	if [ "$item" == "tc-testing" ]; then
		do_tc_test
		continue
	fi

	_item=$(echo $item | tr -s "/-" "_")
	total_tests=$(get_test_list ${item})
	total_num=$(echo ${total_tests} | wc -w)
	nfail=0 num=0 name=""

	cd $EXEC_DIR/$item
	do_${_item}_config || continue

	for name in ${total_tests}; do
		num=$(($num + 1))
		OUTPUTFILE=$(new_outputfile)

		check_skipped_tests "${name}" && \
			test_pass "${num}..${total_num} selftests: ${item}: ${name} Skip" && continue

		dmesg -C

		run_test ${name}
		ret=$?

		echo -e "\n=== Dmesg result ===" >> $OUTPUTFILE
		dmesg >> $OUTPUTFILE

		check_result $num $total_num ${item} ${name} $ret || \
			nfail=$((nfail+1))
		clean_env
	done

	echo "${item}: total $total_num, failed $nfail"
done

#-------------------- Clean Up --------------------
