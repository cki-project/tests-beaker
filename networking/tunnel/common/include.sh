#!/bin/bash

NIC_COMMON_DIR=$(dirname $(readlink -f $BASH_SOURCE))

# select tool to manage package, which could be "yum" or "dnf"
function select_yum_tool() {
    if [ -x /usr/bin/dnf ]; then
        echo "/usr/bin/dnf"
    elif [ -x /usr/bin/yum ]; then
        echo "/usr/bin/yum"
    else
        return 1
    fi

    return 0
}

yum=$(select_yum_tool)

# find absolute path for networking
abs_networking_path=$(echo $(pwd) | sed 's/\/networking\/.*/\/networking/')
echo "absolute networking path is ${abs_networking_path}" | tee -a $OUTPUTFILE

netns_crs_setup()
{

################TOPO#############################
#  client -- bridge -- route -- bridge -- server
# 10.10.0.1/24       10.10.0.254/24      10.10.1.1/24
# 2000::1/64         2000::a/64          2001::1/64
#################################################

	C_CMD="ip netns exec client"
	S_CMD="ip netns exec server"
	CLI_ADDR4="10.10.0.1"
	SER_ADDR4="10.10.1.1"
	CLI_ADDR6="2000::1"
	SER_ADDR6="2001::1"
	c_r_addr4="10.10.0.254"
	s_r_addr4="10.10.1.254"
	c_r_addr6="2000::a"
	s_r_addr6="2001::a"
	ip netns add client
	ip netns add server
	ip netns add route

	ip link add br_c type bridge
	ip link add br_s type bridge

	ip link add veth0_c type veth peer name veth0_c_br
	ip link add veth1_c type veth peer name veth1_c_br
	ip link add veth0_cr type veth peer name veth0_cr_br
	ip link add veth0_sr type veth peer name veth0_sr_br
	ip link add veth0_s type veth peer name veth0_s_br
	ip link add veth1_s type veth peer name veth1_s_br

	ip link set veth0_c netns client
	ip link set veth1_c netns client
	ip link set veth0_s netns server
	ip link set veth1_s netns server
	ip link set veth0_cr netns route
	ip link set veth0_sr netns route

	ip link set veth0_c_br master br_c
	ip link set veth1_c_br master br_c
	ip link set veth0_cr_br master br_c

	ip link set veth0_s_br master br_s
	ip link set veth1_s_br master br_s
	ip link set veth0_sr_br master br_s

	local iface
	local iface_c
	local iface_s
	local iface_r
	for iface in br_c br_s veth0_c_br veth1_c_br veth0_cr_br veth0_s_br veth1_s_br veth0_sr_br
	do
		ip link set $iface up
	done

	for iface_c in lo veth0_c veth1_c
	do
		$C_CMD ip link set $iface_c up
	done

	for iface_s in lo veth0_s veth1_s
	do
		$S_CMD ip link set $iface_s up
	done

	for iface_r in lo veth0_cr veth0_sr
	do
		ip netns exec route ip link set $iface_r up
	done

	echo "source ${abs_networking_path}/common/include.sh; rm -f /tmp/test_*; PVT=yes; TOPO=$TOPO; NIC_NUM=$NIC_NUM; get_test_iface" | ip netns exec client bash
	C_IFACE=$(tail -n1 /tmp/test_iface | tr -d '\r\n')
	echo "source ${abs_networking_path}/common/include.sh; rm -f /tmp/test_*; PVT=yes; TOPO=$TOPO; NIC_NUM=$NIC_NUM; get_test_iface" | ip netns exec server bash

	S_IFACE=$(tail -n1 /tmp/test_iface | tr -d '\r\n')

	C_IFACE_R=veth0_cr
	S_IFACE_R=veth0_sr

	$C_CMD ip addr add $CLI_ADDR4/24 dev $C_IFACE
	$C_CMD ip addr add $CLI_ADDR6/64 dev $C_IFACE
	$S_CMD ip addr add $SER_ADDR4/24 dev $S_IFACE
	$S_CMD ip addr add $SER_ADDR6/64 dev $S_IFACE

	ip netns exec route ip addr add $c_r_addr4/24 dev veth0_cr
	ip netns exec route ip addr add $c_r_addr6/64 dev veth0_cr
	ip netns exec route ip addr add $s_r_addr4/24 dev veth0_sr
	ip netns exec route ip addr add $s_r_addr6/64 dev veth0_sr
	ip netns exec route sysctl -w net.ipv4.conf.all.forwarding=1
	ip netns exec route sysctl -w net.ipv6.conf.all.forwarding=1

	$C_CMD ip route add default via $c_r_addr4
	$C_CMD ip -6 route add default via $c_r_addr6
	$S_CMD ip route add default via $s_r_addr4
	$S_CMD ip -6 route add default via $s_r_addr6

	$C_CMD ping $SER_ADDR4 -c 2
	$C_CMD ping6 $SER_ADDR6 -c 2

	return 0
}

netns_crs_cleanup()
{
	unset C_IFACE
	unset S_IFACE
	unset CLI_ADDR4
	unset CLI_ADDR6
	unset SER_ADDR4
	unset SER_ADDR6
	unset C_CMD
	unset S_CMD
	netns_clean.sh
}

netns_cs_setup()
{

################TOPO#############################
#  client -- bridge -- server
# 10.10.0.1/24         10.10.0.2/24
# 2000::1/64           2000::2/64
#################################################

	C_CMD="ip netns exec client"
	S_CMD="ip netns exec server"
	CLI_ADDR4="10.10.0.1"
	SER_ADDR4="10.10.0.2"
	CLI_ADDR6="2000::1"
	SER_ADDR6="2000::2"
	ip netns add client
	ip netns add server

	ip link add br0 type bridge

	ip link add veth0_c type veth peer name veth0_c_br
	ip link add veth1_c type veth peer name veth1_c_br
	ip link add veth0_s type veth peer name veth0_s_br
	ip link add veth1_s type veth peer name veth1_s_br

	ip link set veth0_c netns client
	ip link set veth1_c netns client
	ip link set veth0_s netns server
	ip link set veth1_s netns server

        ip link set veth0_c_br master br0
        ip link set veth1_c_br master br0

        ip link set veth0_s_br master br0
        ip link set veth1_s_br master br0

	local iface
	local iface_c
	local iface_s
	local iface_r
	for iface in br0 veth0_c_br veth1_c_br veth1_s_br veth0_s_br
	do
		ip link set $iface up
	done

	for iface_c in lo veth0_c veth1_c
	do
		$C_CMD ip link set $iface_c up
	done

	for iface_s in lo veth0_s veth1_s
	do
		$S_CMD ip link set $iface_s up
	done

	echo "source ${abs_networking_path}/common/include.sh; rm -f /tmp/test_*; PVT=yes; TOPO=$TOPO; NIC_NUM=$NIC_NUM; get_test_iface" | ip netns exec client bash
	C_IFACE=$(tail -n1 /tmp/test_iface | tr -d '\r\n')
	echo "source ${abs_networking_path}/common/include.sh; rm -f /tmp/test_*; PVT=yes; TOPO=$TOPO; NIC_NUM=$NIC_NUM; get_test_iface" | ip netns exec server bash

	S_IFACE=$(tail -n1 /tmp/test_iface | tr -d '\r\n')

	$C_CMD ip addr add $CLI_ADDR4/24 dev $C_IFACE
	$C_CMD ip addr add $CLI_ADDR6/64 dev $C_IFACE
	$S_CMD ip addr add $SER_ADDR4/24 dev $S_IFACE
	$S_CMD ip addr add $SER_ADDR6/64 dev $S_IFACE

	$C_CMD ping $SER_ADDR4 -c 2
	$C_CMD ping6 $SER_ADDR6 -c 2

	return 0
}

netns_cs_cleanup() { netns_crs_cleanup; }

netns_3c_setup()
{

################TOPO#############################
#  client1 -- bridge -- client2
# 10.10.0.1/24   |     10.10.0.2/24
# 2000::1/64     |     2000::2/64
#                |
#              client3
#             10.10.0.3/24
#             2000::3/64
#################################################

	C1_CMD="ip netns exec client1"
	C2_CMD="ip netns exec client2"
	C3_CMD="ip netns exec client3"
	C1_ADDR4="10.10.0.1"
	C2_ADDR4="10.10.0.2"
	C3_ADDR4="10.10.0.3"
	C1_ADDR6="2000::1"
	C2_ADDR6="2000::2"
	C3_ADDR6="2000::3"
	ip netns add client1
	ip netns add client2
	ip netns add client3

	ip link add br0 type bridge

	ip link add veth0_c1 type veth peer name veth0_c1_br
	ip link add veth1_c1 type veth peer name veth1_c1_br
	ip link add veth0_c2 type veth peer name veth0_c2_br
	ip link add veth1_c2 type veth peer name veth1_c2_br
	ip link add veth0_c3 type veth peer name veth0_c3_br
	ip link add veth1_c3 type veth peer name veth1_c3_br

	ip link set veth0_c1 netns client1
	ip link set veth1_c1 netns client1
	ip link set veth0_c2 netns client2
	ip link set veth1_c2 netns client2
	ip link set veth0_c3 netns client3
	ip link set veth1_c3 netns client3

	local iface	$C1_CMD ip addr add $C1_ADDR6/64 dev $C1_IFACE
	$C2_CMD ip addr add $C2_ADDR4/24 dev $C2_IFACE
	$C2_CMD ip addr add $C2_ADDR6/64 dev $C2_IFACE
	$C3_CMD ip addr add $C3_ADDR4/24 dev $C3_IFACE
	$C3_CMD ip addr add $C3_ADDR6/64 dev $C3_IFACE

	$C1_CMD ping $C2_ADDR4 -c 2
	$C1_CMD ping6 $C2_ADDR6 -c 2
	$C1_CMD ping $C3_ADDR4 -c 2
	$C1_CMD ping6 $C3_ADDR6 -c 2

	return 0
}

netns_3c_cleanup()
{
	unset C1_IFACE
	unset C2_IFACE
	unset C3_IFACE
	unset C1_ADDR4
	unset C2_ADDR4
	unset C3_ADDR4
	unset C1_ADDR6
	unset C2_ADDR6
	unset C3_ADDR6
	unset C1_CMD
	unset C2_CMD
	unset C3_CMD

	netns_clean.sh
}



which socat || ${yum} install socat -y 
pushd $NIC_COMMON_DIR
for file in *.sh
do
	[ x"$file" == x"runtest.sh" -o x"$file" == x"include.sh" ] && continue
	source $file
done
popd
