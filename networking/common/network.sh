#!/bin/bash
# vim: sts=8 sw=8 noexpandtab:
# This is for network operations

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

trap 'cleanup_swcfg' HUP TERM KILL EXIT

# ---------------------- Global variables  ------------------

# variable for configuration files
SWCFG_UNDO="/mnt/testarea/swcfg_undo.sh"
NIC_INFO="/tmp/nic_info"; export NIC_INFO=$NIC_INFO

# variables for choosing required interfaces
PVT=${PVT:-"no"}
NAY=${NAY:-"no"}
NIC_DRIVER=${NIC_DRIVER:-"any"}
NIC_MODEL=${NIC_MODEL:-"any"}
NIC_SPEED=${NIC_SPEED:-"any"}
NIC_NUM=${NIC_NUM:-1}

# variables for setting up TOPOs
TOPO=${TOPO:-"nic"}
MTU_VAL=${MTU_VAL:-1500}
VLAN_ID=${VLAN_ID:-3}
SWCFG_AUTO=${SWCFG_AUTO:-"yes"}
BOND_OPTS=${BOND_OPTS:-"mode=1 miimon=100"}
TEAM_OPTS=${TEAM_OPTS:-"runner=activebackup"}
BOND_NAME=${BOND_NAME:-"bond0"}
TEAM_NAME=${TEAM_NAME:-"team0"}
BRIDGE_NAME=${BRIDGE_NAME:-"br0"}
OVS_NAME=${OVS_NAME:-"ovsbr0"}

# variables for setting up IP address
IPVER=${IPVER:-"4 6"}

# variables to save result of test iface and IP address
export CUR_IFACE=
export TEST_IFACE=
export SER_ADDR4=
export SER_ADDR6=
export CLI_ADDR4=
export CLI_ADDR6=
export LOCAL_ADDR4=
export LOCAL_ADDR6=
export REMOTE_ADDR4=
export REMOTE_ADDR6=
export LOCAL_IFACE_MAC=
export REMOTE_IFACE_MAC=

# ---------------------- network service  ------------------

#restart network service, for "service network restart" failed at rhel7
pure_restart_network()
{
        pkill -9 dhclient
        ip link set $1 down &> /dev/null
        ip link set $1 up &> /dev/null
        sleep 10
	if [ "$IPVER" != "6" ]; then
		dhclient $1
	else
		dhclient -6 $1
	fi
}

reset_network_env()
{
	echo "Starting reset_network_env ..."
	local exitcode=0
	local i

	cleanup_swcfg

	# remove bonding vlan bridge tunnel
	local modules="bonding 8021q bridge ipip gre sit vxlan veth"
	for i in $modules; do
		modprobe -r $i 2>/dev/null
	done



	if [ "$NM_CTL" = yes ]; then
		# Clear variables
		\rm /tmp/test_nic 2>/dev/null
		\rm /tmp/test_iface 2>/dev/null
		
		# restart network service
		pkill -9 dhclient
		pkill -f "nc -l"

		rsync -a --delete $networkLib/network-scripts.bak/ /etc/sysconfig/network-scripts/
		systemctl restart network
		systemctl restart NetworkManager
		
		# delete it when the device does not exist
		ip link del $TEAM_NAME
		ip link del $BOND_NAME
	else
		 # remove ovs
	        ovs-vsctl del-br ovsbr0 2>/dev/null && service openvswitch restart

		# remove netns
		ip netns list &> /dev/null && for i in `ip netns list | awk '{print $1}'`; do ip netns del $i; done

		# reset each test iface
		for i in `get_iface_list`; do
			test "$i" = "`get_default_iface`" && continue
			test team = "`get_iface_driver $i`" && teamd -k -t $i && continue
			clear_addr  $i
			set_mtu_val $i 1500
			ip link set $i down
		done

		# Clear variables
		\rm /tmp/test_nic 2>/dev/null
		\rm /tmp/test_iface 2>/dev/null


		# restart network service
		pkill -9 dhclient
		pkill -f "nc -l"
	
		rsync -a --delete $networkLib/network-scripts.no_nm/ /etc/sysconfig/network-scripts/
		 service network restart
	fi

	return $exitcode
}

# This is the recommanded function to use when start a network test
# It will:
#   1. get_test_iface()
#   2. setup_ip setup_ip6()
#   3. exchange_ip()
#   4. save results to related variables
#      - CUR_IFACE / TEST_IFACE
#      - LOCAL_ADDR4
#      - LOCAL_ADDR6
#      - REMOTE_ADDR4
#      - REMOTE_ADDR6
#      - SER_ADDR4
#      - SER_ADDR6
#      - CLI_ADDR4
#      - CLI_ADDR6
#      - LOCAL_IFACE_MAC
#      - REMOTE_IFACE_MAC
# Parameter:
#   - to choose NICs: NAY NIC_DRIVER NIC_NUM
#   - to setup_topo : TOPO BOND_OPTS MTU_VAL
#   - to setup_ip   : IPVER
# Return 0 for pass
get_iface_and_addr()
{
	net_sync get_iface_and_addr
	local exitcode=0
	get_test_iface CUR_IFACE || let exitcode++
	TEST_IFACE=$CUR_IFACE

	exchange_ip $TEST_IFACE || let exitcode++
	LOCAL_ADDR4=$(awk '/IP4/ {print $2}' /tmp/my_ip)
	LOCAL_ADDR6=$(awk '/IP6/ {print $2}' /tmp/my_ip)
	REMOTE_ADDR4=$(awk '/IP4/ {print $2}' /tmp/target_ip | uniq)
	REMOTE_ADDR6=$(awk '/IP6/ {print $2}' /tmp/target_ip | uniq)
	LOCAL_IFACE_MAC=$(awk '/MAC/ {print $2}' /tmp/my_ip)
	REMOTE_IFACE_MAC=$(awk '/MAC/ {print $2}' /tmp/target_ip | uniq)

	i_am_server && {
		SER_ADDR4=$LOCAL_ADDR4
		SER_ADDR6=$LOCAL_ADDR6
		CLI_ADDR4=$REMOTE_ADDR4
		CLI_ADDR6=$REMOTE_ADDR6
	}

	i_am_client && {
		SER_ADDR4=$REMOTE_ADDR4
		SER_ADDR6=$REMOTE_ADDR6
		CLI_ADDR4=$LOCAL_ADDR4
		CLI_ADDR6=$LOCAL_ADDR6
	}
	echo "------------- finish setup iface and IP address ----------------"
	return $exitcode
}
get_test_iface_and_addr() { get_iface_and_addr; }

# ---------------------- NICs  -----------------------------

# Get interface's name by MAC address
# @arg1: interface' MAC address (format: 00:c0:dd:1a:44:8c)
# output: interface's name
mac2name()
{
	local mac="$1"
	local name="mac2name-error"
	local target=""
	local ethX=""

	for ethX in `ls /sys/class/net`; do
		# skip virtual device
		if ethtool -i $ethX 2>/dev/null | grep -q "bus-info: [0-9].*"; then
			target=`get_iface_mac $ethX`
			if [ "$mac" = "$target" ]; then
				name=$ethX
				break
			fi
		fi
	done
	echo $name
}

# Pipe into mac2name
# example: echo 00:c0:dd:1a:44:8c | macs2name
macs2name()
{
	local mac=""
	while read mac; do
		mac2name $mac
	done
}

get_cur_iface()
{
	if [ "$IPVER" != "6" ]; then
		ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'
	else
		ip -6 route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'
	fi
}
get_default_iface() { get_cur_iface "$@"; }

get_iface_list()
{
	local dev_list
	if [ "$(GetDistroRelease)" -ge 7 ]; then
		# when running in netns on rhel6, 'find /sys/class/net/ -type l' get all intefaces of host
		# not netns
		dev_list=$(find /sys/class/net/ -type l | awk -F'/' '!/lo|sit|usb|ib/{print $5}' | sort -u)
	else
		# when running in netns, 'cat /proc/net/dev' can always get all interfaces in the netns.
		# This should work on rhel6/7/8 ... But for minimal impact, use it on rhel6 or before only
		dev_list=$(cat /proc/net/dev | tail -n +3 | awk -F':' '!/lo|sit|usb|ib/{print $1}' | sort -u)
	fi
	for dev in ${dev_list}
	do
		# exclude usb network card
		if ethtool -i $dev | grep -qiE "bus-info.*usb"
		then
			continue
		else
			echo $dev
		fi
	done
}

get_sec_iface()
{
	iface_list=$(get_iface_list)
	for name in $iface_list
	do
		ip link set $name up
		sleep 10
		if [ "$name" = $(get_cur_iface) ];then
			continue
		elif [ "`ethtool $name | grep 'Link detected: yes'`" ];then
			echo $name
			return 0
		fi
		ip link set $name down
	done
	return 1
}

get_unused_iface()
{
	cur_num=1
	iface_num=$1
	iface_list=$(get_iface_list)
	for name in $iface_list
	do
		ip link set $name up
		sleep 10
		if [ "$name" = $(get_cur_iface) ];then
			continue
		elif [ "`ethtool $name | grep 'Link detected: yes'`" ] && [ $cur_num -lt $iface_num ];then
			let cur_num++
			continue
		elif [ "`ethtool $name | grep 'Link detected: yes'`" ];then
			echo $name
			return 0
		fi
		ip link set $name down
	done
	return 1
}

get_iface_by_driver()
{
	nic_driver=$1
	iface_list=$(get_iface_list)
	for name in $iface_list
	do
		ip link set $name up
		sleep 10
		if [ "$name" = $(get_cur_iface) ] || [ ! "`ethtool -i $name | grep $nic_driver`" ];then
			if [ "$name" != "$(get_cur_iface)" ];then
				ip link set $name down
			fi
			continue
		elif [ "`ethtool $name | grep 'Link detected: yes'`" ];then
			echo $name
			return 0
		fi
	done
	return 1
}

# Get interface's permanent MAC address
# @arg1 interface's name
# returns MAC
get_iface_mac()
{
	local input=${1:-unknown}
	local mac=

	if ethtool -h 2>&1 | grep -q show-permaddr; then
		mac=`ethtool -P $input | awk '{print $3}'`
	fi
	if [ -z "$mac" -o "00:00:00:00:00:00" = "$mac" ]; then
		mac=`cat /etc/sysconfig/network-scripts/ifcfg-$input | \
			awk -F = '/HWADDR=/ {print $2}' | \
			tr [A-Z] [a-z] | tr -d '"'`
	fi
	# For veth, we don't have ethtool support, and we also don't have
	# ifcfg file, use 'ip link' after all these check
	if [ -z "$mac" -o "00:00:00:00:00:00" = "$mac" ]; then
		mac=`ip link show $input | awk '/link\/ether/ {print $2}'`
	fi
	mac=${mac:-"get-mac-error"}
	echo $mac
}

get_iface_speed()
{
	ethtool $1 |  grep Speed*.*s | sed -n 's/.* \([0-9]\{1,\}\)Mb.*$/\1/p'
}

get_iface_driver()
{
	ethtool -i $1 | awk '/driver:/{print $2}'
}

get_iface_from_bus_info()
{
	local bus_info=$1
	if [ "$(GetDistroRelease)" = 5 ];then
		# the net name format under $bus_info/ on RHEL5 is : net:ethX
		ls /sys/bus/pci/devices/$bus_info/  | awk -F: '/net/ {print $2}'
	else
		ls /sys/bus/pci/devices/$bus_info/net/
	fi
}

random_mac()
{
	# the second MAC address must be even number
	mac=`echo $RANDOM | md5sum | sed 's/\(..\)/&:/g' | awk -F: {'print $1":"$2":"$3":"$4":"$5'}`
	mac="00:$mac"
	echo $mac
}

# Get private NICs, which have link detected but not default interface.
# (can be used for getting vm's test interface)
# @arg1: required NIC driver
# @arg2: required NIC number
get_pvt_iface()
{
	local nic_driver="${1:any}"
	local nic_num=${2:-1}
	local _output="$3"
	local find_cnt=0
	local exitcode=0
	local iface=
	case "$nic_driver" in
		""|any|ANY) nic_driver=".*" ;;
	esac

	local skip=$(get_default_iface)
	skip+=" $(cat /tmp/test_nic 2>/dev/null)"
	for i in $(get_iface_list); do
		echo "$skip" | \grep -q "$i" && continue
		# skip vlan/bonding/team/bridge etc vitrual interface
		ethtool -i $i &>/dev/null || continue
		ethtool -i $i 2>/dev/null | egrep -qi \
			"driver: (bonding|team|802.1Q|bridge)" && continue
		ip link set $i up ; sleep 15

		if ethtool $i | \grep -qi 'Link detected: yes' && \
			get_iface_driver $i | \egrep -qw "$nic_driver"; then
			if [ x"$iface" == x ]
			then
				iface="$i"
			else
				iface+=" $i"
			fi
			let find_cnt++
		else
			ip link set $i down
		fi
		[ "$nic_num" = "$find_cnt" ] && break
	done
	[[ "$_output" ]] && eval $_output="'$iface'" || echo $iface
	if [ "$nic_num" != "$find_cnt" ] && [ "$nic_num" != "all" ]; then
		echo "require $nic_num interfaces, but only got $find_cnt : $iface "
		let exitcode++
	fi
	return $exitcode
}

# Get network-qe's private NICs by variables $NIC_DRIVER $NIC_MODEL $NIC_SPEED $NIC_NUM
# @arg1: (optional) variable to save the result
# if no arg1, it will print the result to stdout.
# return 0 for pass
get_netqe_iface()
{
	local _output="$1"
	local exitcode=0
	local iface=

	nic_num=$NIC_NUM
	case "$nic_num" in
		all)
			nic_num=$ ;;
		[0-9]*)
			;;
		*)
			nic_num=1;;
	esac

	[ -f "$NIC_INFO" ] || get_netqe_nic_info
	iface=$(parse_netqe_nic_info.sh --match="$HOSTNAME" \
		--driver="$NIC_DRIVER" --model="$NIC_MODEL" --speed="$NIC_SPEED" \
		--field=mac | sed -n '1,'"$nic_num"'p' | macs2name)
	iface=`echo $iface`      #make outputs in one line

	find_cnt=`echo $iface | wc -w`
	if [ "$nic_num" != "$find_cnt" ] && [ "$nic_num" != "$" ]; then
		echo "require $nic_num interfaces, but only got $find_cnt : $iface "
		let exitcode++
	fi

	[[ "$_output" ]] && eval $_output="'$iface'" || echo $iface
	return $exitcode
}

# choose required NIC(s), save to $TEST_IFACE
get_required_iface()
{
	local exitcode=0
	local iface
	local sw
	local port
	if [ "$NAY" = yes ]; then
		get_netqe_iface TEST_IFACE  || let exitcode++
		for iface in $TEST_IFACE
		do
			get_iface_sw_port "$iface" sw port
			swcfg port_up $sw "$port" &> /dev/null || let exitcode++
			swcfg cleanup_port_channel $sw "$port" &> /dev/null
		done
	elif [ "$PVT" = yes ]; then
		get_pvt_iface "$NIC_DRIVER" "$NIC_NUM" TEST_IFACE  || let exitcode++
	else
		TEST_IFACE=$(get_default_iface)
	fi
	echo $TEST_IFACE
	return $exitcode
}

report_interface()
{
	iface="$1"
	inf=/tmp/"$iface".info
	echo "# ip a s dev $iface" > $inf
	ip a s dev $iface >> $inf
	echo "# ip -6 route show" >> $inf
	ip -6 route show >> $inf
	echo "# ethtool -i $iface" >> $inf
	ethtool -i $iface >> $inf
	echo "ethtool $iface" >> $inf
	ethtool $iface >> $inf

	# if running in RHTS context, submit it
	if [ -n "$TEST" ]; then
		type rhts-submit-log >/dev/null 2>&1 && rhts-submit-log -l "$inf"
	fi
	return 0
}

report_iface_ethtool()
{
	iface="$1"
	inf=/tmp/"$iface".info
	> $inf
	exec 6>&1 7>&2
	exec 5>"$inf" 1>&5 2>&1
	echo "$iface:"
	ip a s dev $iface
	echo
	ethtool -i "$iface"
	echo
	ethtool "$iface"
	echo
	ethtool -k "$iface"
	echo
	ethtool -a "$iface"
	ethtool -c "$iface"
	ethtool -g "$iface"
	exec 5>&- 1>&6- 2>&7-
	cat "$inf"

	# if running in RHTS context, submit it
	if [ -n "$TEST" ]; then
		type rhts-submit-log >/dev/null 2>&1 && rhts-submit-log -l "$inf"
	fi
	return 0
}

# ---------------------- setup topo  -----------------------------

link_up()
{
	local input="$1"
	ip link set $input up || return 1
}

# Setup team
# @arg1 enslave NIC names
# @arg2 team name
# @arg3: (optional) variable to save the result
# Use variable $TEAM_OPTS or $TEAM_JSON to setting team parameters
# return 0 for pass
setup_team()
{
	local exitcode=0
	local handle="$1"
	local option="$2" #team name
	local _output="$3"
	local slave=""
	topo_ret=$option

	# parse team options
	team_json=${TEAM_JSON}
	[ -z "$TEAM_JSON" -a -n "$TEAM_OPTS" ] && {
		local v_runner=$(echo $TEAM_OPTS | \
			awk '/runner/{match($0,"runner=([^ ]+)",M); print M[1]}')
		local v_link_watch=$(echo $TEAM_OPTS | \
			awk '/link_watch/{match($0,"link_watch=([^ ]+)",M); print M[1]}')

		case $v_runner in
			# map samilar number compare with bonding
			0) v_runner=roundrobin;;
			1) v_runner=activebackup;;
			2) v_runner=loadbalance;;
			3) v_runner=broadcast;;
			4) v_runner=lacp;;
		esac

		v_runner=${v_runner:-activebackup}
		v_link_watch=${v_link_watch:-ethtool}

		team_json='{ "runner" : { "name": "'$v_runner'" },  "link_watch" : { "name": "'$v_link_watch'" } }'
	}
	team_json=${team_json:-'{"runner":{"name":"activebackup"}}'}
	echo TEAM_NAME=\'$TEAM_NAME\'
	echo TEAM_JSON=\'$team_json\'

	# config port-channel on switch
	#if [ "$SWCFG_AUTO" = yes ] && [ "$NAY" = yes ] && echo "$team_json" | \egrep -q -w \
	#	"runner.*:.*(roundrobin|loadbalance|lacp)"; then
	if [ "$SWCFG_AUTO" = yes ] && [ "$NAY" = yes ] && echo "$team_json" | \egrep -q -w "runner.*:.*(lacp)"; then	
		if echo "$team_json" | \egrep -q -w "runner.*:.*lacp"; then
			port_channel_mode=active
		else
			port_channel_mode=on
		fi

		get_iface_sw_port "$handle" switch_name port_list kick_list || let exitcode++
		swcfg_port_channel $switch_name "$port_list" $port_channel_mode || let exitcode++
	fi

	# create team interface
	teamd -t $topo_ret -rd -c "$team_json"       || let exitcode++
	link_up $topo_ret                            || let exitcode++

	# add port dev
	for port in $handle; do
		ip link set $port down               || let exitcode++
		teamdctl $topo_ret  port add $port   || let exitcode++
		link_up $port                        || let exitcode++
	done
	for port in $kick_list; do
		ifenslave -d $topo_ret $kick_list
	done
	sleep 3

	[[ "$_output" ]] && eval $_output="'$topo_ret'" || echo $topo_ret
	return $exitcode
}

# Setup bonding
# @arg1 enslave NIC names
# @arg2 bonding name
# @arg3: (optional) variable to save the result
# Use variable $BOND_OPTS to setting bonding parameters
# return 0 for pass
setup_bond()
{
	local exitcode=0
	local handle="$1"
	local option="$2" #bond name
	local _output="$3"
	local slave=""
	topo_ret=$option

	echo BOND_NAME=\'$BOND_NAME\'
	echo BOND_OPTS=\'$BOND_OPTS\'
	# config port-channel on switch
	#if [ "$SWCFG_AUTO" = yes ] && [ "$NAY" = yes ] && echo "$BOND_OPTS" | \egrep -q -w \
	#	"mode=(0|2|4|balance-rr|balance-xor|802.3ad)"; then
	if [ "$SWCFG_AUTO" = yes ] && [ "$NAY" = yes ] && echo "$BOND_OPTS" | \egrep -q -w \
                "mode=(4|802.3ad)"; then
		if echo "$BOND_OPTS" | \egrep -q -w "mode=(4|802.3ad)"; then
			port_channel_mode=active
		else
			port_channel_mode=on
		fi

		get_iface_sw_port "$handle" switch_name port_list kick_list || let exitcode++
		swcfg_port_channel $switch_name "$port_list" $port_channel_mode || let exitcode++
	fi

	# add bonding interface
	test -f /sys/class/net/bonding_masters || {
		if [ $(GetDistroRelease) = 8 ];then 
			modprobe -nv bonding | grep 'max_bonds=0' > /dev/null && spare_param='Y'
			if [ $spare_param = 'Y' ]
			then
				modprobe bonding max_bonds=1; sleep 2;
				echo "bonding spare param max_bonds exist"
			else
				modprobe bonding; sleep 2
			fi
			#modprobe bonding max_bonds=1; sleep 2
		else
			modprobe bonding; sleep 2
		fi
		echo -bond0 > /sys/class/net/bonding_masters
	}
	echo +$topo_ret > /sys/class/net/bonding_masters || let exitcode++

	# enslave NICs
	link_up $topo_ret             || let exitcode++
	ifenslave $topo_ret $handle   || let exitcode++
	[ -n "$kick_list" ] && ifenslave -d $topo_ret $kick_list
	sleep 3

	# setting bonding parameters
	if [ -n "$BOND_OPTS" ]; then
		change_bond_opts $topo_ret "$BOND_OPTS" || let exitcode++
	fi

	[[ "$_output" ]] && eval $_output="'$topo_ret'" || echo $topo_ret
	return $exitcode
}

# Set "modprobe bonding" command according to RHEL version and params available.
# Starting with RHEL 8, "modprobe bonding" must also include "max_bonds=1" in order
# for the bond0 interface to get automatically created.
set_modprobe_bond_cmd()
{
	local exitcode=0
	if [[ $(GetDistroRelease) -ge 8 ]]; then
		modprobe -nv bonding | grep 'max_bonds=0' > /dev/null && spare_param='Y'
		if [[ $spare_param == "Y" ]]; then
			modprobe_bond_cmd="modprobe bonding max_bonds=1"
		else
			modprobe_bond_cmd="modprobe bonding"
		fi
	else
		modprobe_bond_cmd="modprobe bonding"
	fi
	return $exitcode
}

# Setup vlan
# @arg1 which interface to add vlan
# @arg2 vlan tag
# @arg3: (optional) variable to save the result
# return 0 for pass
setup_vlan()
{
	local exitcode=0
	local handle="$1"
	local option="$2" #vlan id
	local _output="$3"
	topo_ret="$handle.$option"

	echo VLAN_ID=\'$VLAN_ID\'
	if [ $(GetDistroRelease) = 5 ]; then
		vconfig add $handle $option || let exitcode++
	else
		ip link add link $handle name $topo_ret type vlan id $option  || let exitcode++
	fi
	sleep 2
	link_up $handle     || let exitcode++
	link_up $topo_ret   || let exitcode++
	sleep 3

	[[ "$_output" ]] && eval $_output="'$topo_ret'" || echo $topo_ret
	return $exitcode
}

# Setup vlan egress qos map
# @arg1 vlan-device
# @arg2 skb-priority
# @arg3 vlan-qos
# return 0 for pass
setup_vlan_egress()
{
	local exitcode=0
	local handle="$1"
	local skbp="$2"
	local vlanq="$3"

	if [ $(GetDistroRelease) = 5 ]; then
		vconfig set_egress_map $handle $skbp $vlanq || let exitcode++
	else
		ip link set dev $handle type vlan egress-qos-map $skbp:$vlanq || let exitcode++
	fi

	return $exitcode
}

# Setup vlan ingress qos map
# @arg1 vlan-device
# @arg2 skb-priority
# @arg3 vlan-qos
# return 0 for pass
setup_vlan_ingress()
{
	local exitcode=0
	local handle="$1"
	local skbp="$2"
	local vlanq="$3"

	if [ $(GetDistroRelease) = 5 ]; then
		vconfig set_ingress_map $handle $skbp $vlanq || let exitcode++
	else
		ip link set dev $handle type vlan ingress-qos-map $vlanq:$skbp || let exitcode++
	fi

	return $exitcode
}

# Remove vlan
# @arg1 interface to remove
# return 0 for pass
rem_vlan()
{
	local exitcode=0
	local handle="$1"

	if [ $(GetDistroRelease) = 5 ]; then
		vconfig rem $handle || let exitcode++
	else
		ip link del $handle || let exitcode++
	fi

	return $exitcode
}

# Setup bridge
# @arg1 interface names will add in bridge
# @arg2 bridge name
# @arg3: (optional) variable to save the result
# return 0 for pass
setup_bridge()
{
	local exitcode=0
	local handle="$1"
	local option="${2:-br0}" #bridge name
	local _output="$3"
	local i
	topo_ret="$option"

	echo BRIDGE_NAME=\'$BRIDGE_NAME\'
	# create br0
	if [ $(GetDistroRelease) -ge 7 ]; then
		ip link add $topo_ret type bridge  || let exitcode++
	else
		brctl addbr $topo_ret              || let exitcode++
	fi
	link_up $topo_ret                  || let exitcode++

	# add interface to br0
	# WARNINIG: Be careful when you want to add two interfaces into one
	# bridge. It may cause broadcast storm.
	for i in $handle; do
		if [ $(GetDistroRelease) -ge 7 ]; then
			ip link set $i master $topo_ret    || let exitcode++
		else
			brctl addif $topo_ret $i           || let exitcode++
		fi
		clear_addr $i                  || let exitcode++
		link_up $i                     || let exitcode++
		sleep 2
	done

	[[ "$_output" ]] && eval $_output="'$_topo_ret'" || echo $topo_ret
	return $exitcode
}
# Setup ovs
# @arg1 interface names will add in ovs
# @arg2 ovsbr name
# @arg3: (optional) variable to save the result
# return 0 for pass
setup_ovs()
{
	local exitcode=0
	local handle="$1"
	local option="${2:-ovsbr0}" #ovs br name
	local _output="$3"
	local i
	topo_ret="$option"
	#setup
	ovs_install
	service openvswitch start
	# create
	ovs-vsctl add-br $topo_ret         || let exitcode++
	link_up $topo_ret                  || let exitcode++

	# add interface to ovsbr0
	# WARNINIG: Be careful when you want to add two interfaces into one
	# ovs-br. It may cause broadcast storm.
	for i in $handle; do
		ovs-vsctl add-port $topo_ret $i|| let exitcode++
		clear_addr $i                  || let exitcode++
		link_up $i                     || let exitcode++
		sleep 2
	done

	[[ "$_output" ]] && eval $_output="'$_topo_ret'" || echo $topo_ret
	return $exitcode
}


# Change interfaces' MTU
# @arg1: iface name
# @arg2: MTU value
# Param:
#   MTU_VAL
# retuen 0 for pass
change_iface_mtu()
{
	MTU_VAL=${MTU_VAL:-1500}
	local exitcode=0
	local iface=$1
	local value=${2:-$MTU_VAL}

	local cur_val=`cat /sys/class/net/$iface/mtu`
	[ "$cur_val" = "$value" ] && return 0

	local driver=$(ethtool -i $iface | awk '/driver:/{print $2}')
	case "$driver" in
		bonding)
			local i
			for i in $(cat /sys/class/net/$iface/bonding/slaves); do
				change_iface_mtu $i $value
			done
			;;

		802.1Q)
			local i=$(cat /proc/net/vlan/$iface | awk '/Device:/{print $2}')
			change_iface_mtu $i $value
			;;
		bridge)
			local i
			for i in $(ls /sys/class/net/$iface/brif); do
				change_iface_mtu $i $value
			done
			;;
		openvswitch)
			local i
			for i in $(ovs-vsctl list-ifaces $iface); do
				change_iface_mtu $i $value
			done
			;;
		*)
			#nic
			;;
	esac
	ip link set $iface mtu $value || let exitcode++
	return $exitcode
}
set_mtu_val(){ change_iface_mtu "$@"; }

# Truncate input to 1, for setup_topo
# @arg1: input description
# @arg2: inputs
truncate_topo_input()
{
	local exitcode=0
	local handle="$1"
	local inputs="$2"
	local _output="$3"

	local cnt=`echo $inputs | wc -w`
	[ $cnt -eq 1 ] || {
		echo "setup_$handle just can operate 1, but input $cnt: $inputs"
		read inputs nil <<< "$inputs"
		echo "just leave $inputs"
		let exitcode++
	}

	topo_ret="$inputs"
}

# Setup complicated interface(nic/bond vlan bridge)
# @arg1: inputs NICs
# @arg2: (optional) TOPO (nic, nic_vlan, nic_bridge, bond, bond_vlan, bond_bridge ...)
# @arg3: (optional) variable to save the result
# Parameter:
#   TOPO
#   BOND_OPTS		: Parameters for loading bonding driver
#   TEAM_JSON		: JSON config string for `teamd -c`
#   TEAM_OPTS		: Simple parameters for team driver if don't like TEAM_JSON,
#			  Just support runner and link_watch
#			  Eg: runner=activebackup
#   MTU_VAL
#   BRIDGE_NAME
#   VLAN_ID
#   OVS_NAME
# return 0 for pass
# example: NAY=yes; NIC_NUM=2; TOPO=bond_vlan; setup_topo
setup_topo()
{
	local exitcode=0
	local handle="$1"
	local option="${2:-$TOPO}"
	local _output="$3"
	local topo_ret="$handle"


	echo $handle >> /tmp/test_nic
	echo -e "\n----------- start setup $option, handle: $handle -----------"

	# change bond_vlan_bridge to "bond vlan bridge"
	option=${option//_/ }
	local topo=""
	for topo in $option; do
		echo
		case $topo in
			nic)
				truncate_topo_input $topo "$topo_ret" || let exitcode++
				link_up "$topo_ret"                   || let exitcode++
				;;
			bond)
				setup_bond "$topo_ret" "$BOND_NAME"   || let exitcode++
				cat /proc/net/bonding/$topo_ret
				;;
			team)
				setup_team "$topo_ret" "$TEAM_NAME"   || let exitcode++
				teamdctl $topo_ret config dump actual
				teamdctl $topo_ret state dump
				;;
			vlan)
				truncate_topo_input $topo "$topo_ret" || let exitcode++
				setup_vlan "$topo_ret" "$VLAN_ID"     || let exitcode++
				;;
			bridge)
				setup_bridge "$topo_ret" "${BRIDGE_NAME}" || let exitcode++
				bridge link
				;;
			ovs)
				setup_ovs "$topo_ret" "${OVS_NAME}" || let exitcode++
				ovs-vsctl show
				;;
			*)
				echo "Error: unsupported topo set"
				let exitcode++
				;;
		esac
		ip link show $topo_ret
	done
	echo -e "\n---------- finish setup $option, got iface: $topo_ret --------\n"

	# change $iface MTU
	change_iface_mtu $topo_ret

	[[ "$_output" ]] && eval $_output="'$topo_ret'"
	return $exitcode
}

# Get test interface - choose required NICs and setup topo
# Param:
#   NAY
#   NIC_DRIVER
#   NIC_MODEL
#   NIC_SPEED
#   NIC_NUM
#   TOPO
#   BOND_OPTS
#   MTU_VAL
# @arg1: (optional) variable to save the result
# return 0 for pass, and will save result in TEST_IFACE
__get_test_iface()
{
	local exitcode=0
	local param_list="NAY PVT NIC_DRIVER NIC_MODEL NIC_SPEED NIC_NUM TOPO MTU_VAL"

	echo "------------- choose required NIC(s) ----------------"
	local i val
	for i in $param_list; do
		eval val="\$$i"
		echo "$i='$val'"
	done

	# choose required NIC(s), save to $TEST_IFACE
	echo; echo -n "picked NIC(s): "
	get_required_iface || let exitcode++

	for i in $TEST_IFACE; do
		echo -e "\n \$ ethtool -i $i"
		ethtool -i $i
	done

	# setup topo
	if [ $NM_CTL = yes ];then
		NM_setup_topo "$TEST_IFACE" "$TOPO" TEST_IFACE  || let exitcode++
	else
		setup_topo "$TEST_IFACE" "$TOPO" TEST_IFACE	|| let exitcode++
	fi
	echo $TEST_IFACE >> /tmp/test_iface

	return $exitcode
}

# Support get multiple test iface
# Use comma-separated values to sepcify each param's different value
# Current it does not support BOND_OPTS, TEAM_OPTS and TEAM_JSON
#
# Example 1: need 2 bonding interface, each have 2 slaves
#   PVT=yes
#   NIC_NUM=2,2
#   TOPO=bond,bond
#   BOND_NAME=bond10,bond20
#
# Example 2: need 2 nic_vlan_bridge, each use different NIC, bridge and vlan id
#   PVT=yes
#   NIC_NUM=1,1
#   TOPO=nic_vlan_bridge,nic_vlan_bridge
#   BRIDGE_NAME=br_lan10,br_lan20
#   VLAN_ID=10,20

get_test_iface()
{
	local exitcode=0
	local _output=$1

	[ -f /tmp/test_iface ] && reset_network_env
	[ "$TOPO" = nic -a "$NIC_DRIVER" = any -a "$NIC_NUM" -eq 1 ] && \
		NIC_DRIVER=$(get_iface_driver $(get_required_iface))

	local param_list="NAY PVT NIC_DRIVER NIC_MODEL NIC_SPEED NIC_NUM
	TOPO BOND_NAME TEAM_NAME VLAN_ID BRIDGE_NAME"

	local i key values value_curr
	local index total setup

	total=$(echo $TOPO | sed "s/,/ /g" | wc -w)
	for index in $(seq $total); do
		for i in $param_list; do
			key="$i"
			eval values="\$$key"
			value_curr=$(echo $values | cut -d, -f $index)
			[ -n "$value_curr" ] || value_curr=$(echo $values | cut -d, -f1)
			setup[$index]+="$key=$value_curr "
		done
	done

	for index in $(seq $total); do
		eval local "${setup[index]}"
		echo "============= Start setup_topo $index/$total: $TOPO ================"
		__get_test_iface || let exitcode++
	done

	[[ "$_output" ]] && eval $_output="'$TEST_IFACE'"
	return $exitcode
}


# ---------------------- Bonding operations -----------------------------

# Live change bonding's parameter
# @arg1: bonding's name
# @arg2: bonding parameters, eg "mode=1 miimon=200 updelay=100 downdelay=100"
#	  or "mode=1 arp_ip_target=192.168.1.253,192.168.1.254 arp_interval=100"
# return 0 for pass
change_bond_opts()
{
	local bondX=$1
	local opts="$2"
	local exitcode=0
	pushd /sys/class/net/$bondX/bonding
	local slave=`cat slaves`

	ifenslave -d $bondX $slave	 || let exitcode++
	ip link set $bondX down		 || let exitcode++
	sleep 2

	local i j k
	# set value to parameter
	for i in $opts; do
		local opt=${i%=*}; local val=${i#*=}

		# add special process for arp_ip_target
		if [ "$opt" = arp_ip_target ]; then
			# clear arp_ip_target
			for j in `cat arp_ip_target`; do echo -$j > arp_ip_target; done

			# arp_ip_target can set multiple ip addr separated by a comma
			IFS_BAK=$IFS; IFS=','
			local targets=`echo $val`
			IFS=$IFS_BAK
			for k in $targets; do
				echo +$k > $opt || let exitcode++
			done
		else
			echo $val > $opt        || let exitcode++
		fi
	done

	ip link set $bondX up		 || let exitcode++
	eval ifenslave $bondX $slave		 || let exitcode++
	sleep 2
	popd

	return $exitcode
}

# ---------------------- IP  -----------------------------

get_iface_ip4()
{
	ip addr show dev $1 | awk -F'[/ ]' '/inet / {print $6}' | head -n1
}

#usage check_connection6 2001::1 eth1 test_something
check_connection()
{
	if [ `echo $1 | grep -P ":|ip6"` ];then
		if [ $2 ];then
			ping6 $1 -I $2 -c 10
		else
			ping6 $1 -c 10
		fi
	else
		if [ $2 ];then
			ping $1 -I $2 -c 10
		else
			ping $1 -c 10
		fi
	fi
	rc=$?
	if [ $3 ];then
		if [ $rc == 0 ];then
			log "Test pass: $3"
		else
			log "Test fail: $3"
			test_fail "$3"
			exit 1
		fi
	fi
	return $rc
}

get_iface_ip6()
{
	# Do not select link local address
	ip addr show dev $1 | grep -v fe80 | grep inet6 -m 1 | awk '{print $2}' | cut -d'/' -f1
}

get_ip6_laddr()
{
	ip addr show dev $1 | awk '/fe80/{print $2}' | cut -d'/' -f1
}

get_cur_gw_route4()
{
	ip route | grep "default via.* dev.*" | sed -n 's/^default via \([0-9\.]*\) dev .*/\1/p'
}
get_ip4_default_gw() { get_cur_gw_route4; }

# Get current interface's IPv4 gateway address - the one before broadcast address
# @arg1: interface' name
# @arg2: variable name to save the result
# if not have $2, then it will print the result to stdout.
# return 0 for pass
get_cur_iface_gw()
{
	local returnvalue
	local iface=$1
	local _output=$2
	local result=`ip addr show $iface | awk '/inet.*brd/ {print $4; exit}' \
		| awk -F. '{printf "%s.%s.%s.%s\n",$1,$2,$3,$4-1}'`
	if [ -z $result ]; then
		result=unknown
		returnvalue=1
	else
		returnvalue=0
	fi

	if [[ "$_output" ]]; then
		eval $_output="'$result'"
	else
		echo $result
	fi

	return $returnvalue
}
get_iface_gw_ip() { get_cur_iface_gw "$@"; }

clear_addr()
{
	ip addr flush $1 || return 1
	#workaround for BZ1364496
	ip -6 route flush dev $1 || return 1
}

# Get the DHCP server's IPv4 address
# @arg1: interface' name
# @arg2: (optional)variable name to save the result
# if not have $2, then it will print the result to stdout.
# return 0 for pass
get_iface_dhcps_ip()
{
	local exitcode=0
	local iface=$1
	local _output=$2
	local result=$(cat /var/lib/dhclient/dhclient*.leases \
		| sed -n '/"'$iface'"/,/dhcp-server-identifier/p' \
		| grep dhcp-server-identifier \
		| tail -n 1 \
		| awk -F ' +|;' 'NR==1 {print $4}'
	)
	[ -z $result ] && {
		result=unknown
		exitcode=1
	}

	[[ "$_output" ]] && eval $_output="'$result'" || echo $result
	return $exitcode
}

# setup IPv4 address
# @arg1: interface name
# return 0 for pass
setup_ip()
{
	local exitcode=0
	local iface=$1
	local ip4=$(get_iface_ip4 $iface)
	[ -n "$ip4" ] && return 0

	if [ "$PVT" = yes ]; then
		local random=$((RANDOM%250))
		ip4="192.168.11.$random/24"
		echo $iface | grep -q 'vlan3\|\.3' && ip4="192.168.13.$random/24"
		echo $iface | grep -q 'vlan4\|\.4' && ip4="192.168.14.$random/24"
		ip addr add $ip4 brd 192.168.11.255 dev $iface || let exitcode++
		return $exitcode
	fi

	if [ "$NM_CTL" = yes ]; then
		local cnt=0
		sleep 5
		while [ "$cnt" -lt 12 ]; do
			test -n "$(get_iface_ip4 $iface)" && break
			sleep 5
			let cnt++
		done
	else
		pkill -9 dhclient; sleep 2
		local arg="-v"
		# RHEL5's dhclient do not have verbose option
		[ $(GetDistroRelease) = 5 ] && arg=""
		dhclient $arg $iface
		ip4=$(get_iface_ip4 $iface)
		try_times=1
		until [ -n "$ip4" ] || [ $try_times -ge 3 ]
		do
			pkill -9 dhclient; sleep 2
			dhclient $arg $iface
			ip4=$(get_iface_ip4 $iface)	
			let try_times++
		done
	fi

	ip4=$(get_iface_ip4 $iface)
	if [ -z "$ip4" ]; then
		# I find the current code(get_iface_and_addr) only call this func for the last topo.
		# So , at here, treat $iface belongs to last topo. 
		# By liali.
		last_topo=$(echo $TOPO | awk -F, '{print $NF}')
		last_vlan_id=$(echo $VLAN_ID | awk -F, '{print $NF}')
		topo_contain_vlan=$(echo $last_topo | grep -iq vlan && echo yes || echo no)
		let exitcode++

		[ -z "$NAY" ] && { ip4=NULL; return 1; }
		ip4="192.168.1.250/24"
		brd="192.168.1.255"
		
		#newcode
		if [ ${topo_contain_vlan} = yes ];then
			ip4="192.168.${last_vlan_id}.250/24"
			brd="192.168.${last_vlan_id}.255"
			if i_am_server;then
				ip4="192.168.${last_vlan_id}.251/24"
			fi
			if i_am_client;then
				ip4="192.168.${last_vlan_id}.252/24"
			fi
		else
			if i_am_server;then
				ip4="192.168.1.251/24"
			fi
			if i_am_client;then
				ip4="192.168.1.252/24"
			fi
		fi

		# old code
		if((0));then
			echo $iface | grep -q 'vlan3\|\.3' && ip4="192.168.3.250/24"
			echo $iface | grep -q 'vlan4\|\.4' && ip4="192.168.4.250/24"
		
			if i_am_server; then
				ip4="192.168.1.251/24"
				echo $iface | grep -q 'vlan3\|\.3' && ip4="192.168.3.251/24"
				echo $iface | grep -q 'vlan4\|\.4' && ip4="192.168.4.251/24"
			fi
			if i_am_client; then
				ip4="192.168.1.252/24"
				echo $iface | grep -q 'vlan3\|\.3' && ip4="192.168.3.252/24"
				echo $iface | grep -q 'vlan4\|\.4' && ip4="192.168.4.252/24"
			fi
		fi
		
		ip addr add $ip4 brd $brd dev $iface || let exitcode++
	fi
	return $exitcode
}

# setup IPv6 address
# @arg1: interface name
# return 0 for pass
setup_ip6()
{
	local exitcode=0
	local iface=$1
	local ip6=
	local cnt=0

	link_up $iface  || let exitcode++
	sleep 2

	if [ "$PVT" = yes ]; then
		ip -6 addr flush $iface
		ip link set $iface down
		sleep 2
		link_up $iface
		sleep 2
		local random=$((RANDOM%250))
		ip6="2011::$random/64"
		echo $iface | grep -q 'vlan3\|\.3' && ip6="2013::$random/64"
		echo $iface | grep -q 'vlan4\|\.4' && ip6="2014::$random/64"
		ip addr add $ip6 dev $iface || let exitcode++
		return $exitcode
	fi

	# wait for IPv6 prefix from RA server
	while [ "$cnt" -lt 18 ]; do
		ip -6 addr show dev $iface scope global | grep -q 'global' && break
		sleep 10
		let cnt++
	done

	ip6=$(get_iface_ip6 $iface)
	# manauly setup
        if [ -z "$ip6" ]; then
                # I find the current code(get_iface_and_addr) only call this func for the last topo.
                # So , at here, treat $iface belongs to last topo. 
                # By liali.
                last_topo=$(echo $TOPO | awk -F, '{print $NF}')
                last_vlan_id=$(echo $VLAN_ID | awk -F, '{print $NF}')
                topo_contain_vlan=$(echo $last_topo | grep -iq vlan && echo yes || echo no)
                let exitcode++

                [ -z "$NAY" ] && { ip6=NULL; return 1; }
                ip6="2$(printf %03d ${last_vlan_id})::250/64"

                #newcode
                if [ ${topo_contain_vlan} = yes ];then
                        ip6="2$(printf %03d ${last_vlan_id})::250/64"
                        if i_am_server;then
                                ip6="2$(printf %03d ${last_vlan_id})::251/64"
                        fi
                        if i_am_client;then
                                ip6="2$(printf %03d ${last_vlan_id})::252/64"
                        fi
                else
                        if i_am_server;then
                                ip6="2001::251/64"
                        fi
                        if i_am_client;then
                                ip6="2001::252/64"
                        fi
                fi

                #oldcode
                if((0));then
                        echo $iface | grep -q 'vlan3\|\.3' && ip6="2003::250/64"
                        echo $iface | grep -q 'vlan4\|\.4' && ip6="2004::250/64"

                        if i_am_server; then
                                ip6="2001::251/64"
                                echo $iface | grep -q 'vlan3\|\.3' && ip6="2003::251/64"
                                echo $iface | grep -q 'vlan4\|\.4' && ip6="2004::251/64"
                        fi
                        if i_am_client; then
                                ip6="2001::252/64"
                                echo $iface | grep -q 'vlan3\|\.3' && ip6="2003::252/64"
                                echo $iface | grep -q 'vlan4\|\.4' && ip6="2004::252/64"
                        fi
                fi
                ip addr add $ip6 dev $iface || let exitcode++
        fi
	return $exitcode
}

# get my/target IP/IPv6 address, for single host just let target ip = my ip
# @arg1: interface name
# Param:
#  IPVER - IP version: 4, 6 or "4 6"
exchange_ip()
{
	local iface=${1:-$TEST_IFACE}
	IPVER=${IPVER:-"4 6"}
	local exitcode=0

	lsof -v 2>/dev/null || ${yum} -y install lsof
	echo "MAC $(get_iface_mac $iface) @$HOSTNAME" > /tmp/my_ip
	# dislike combination_test, we just get IP addr, no mask
	echo $IPVER | grep -q 4 && {
		setup_ip $iface || let exitcode++
		echo "IP4 $(get_iface_ip4 $iface) @$HOSTNAME" >> /tmp/my_ip
	}
	echo $IPVER | grep -q 6 && {
		setup_ip6 $iface || let exitcode++
		echo "IP6 $(get_iface_ip6 $iface) @$HOSTNAME" >> /tmp/my_ip
	}
	ip addr show $iface

	if [ -n "$TOPO" -a "$TOPO" != "nic" ];then
		for i in `cat /tmp/test_nic`;do
				clear_addr $i
		done
	fi

	if [ "$IPVER" != "6" ]; then
		local TARGET=$(get_iface_ip4 $(get_default_iface)) # use IP addr in case hostname cannot be resolved.
	else
		local TARGET=$(get_iface_ip6 $(get_default_iface)) # use IP addr in case hostname cannot be resolved.
	fi
	i_am_server && TARGET=$CLIENTS
	i_am_client && TARGET=$SERVERS

	while lsof -i TCP:1234; do
		local pid=$(lsof -i TCP:1234 | tail -n1 | awk '{print $2}')
		echo $pid | grep -e "\b[0-9]\+\b" >/dev/null && kill -9 $pid && wait $pid
		sleep 1
	done

	if [ "$IPVER" != "6" ]; then
		nc -l 1234 -k > /tmp/target_ip &
	else
		nc -l 1234 -6 -k > /tmp/target_ip &
	fi
	# make sure tcp:1234 is in listen stat
	for i in {1..5}
	do
		if which ss
		then
			if ss -anp | grep "tcp.*LISTEN.*1234 "
			then
				break
			else
				sleep 1
			fi
		else
			if netstat -anp | grep "tcp.*1234 .*LISTEN"
			then
				break
			else
				sleep 1
			fi
		fi
	done

	# to debug, would delete later
	ps aux | grep nc
	echo $TARGET
	systemctl status firewalld
	getenforce

	net_sync "exchange_ip-started"
	for target in $TARGET;do
		if [ "$IPVER" != "6" ]; then
			# try multiple time to avoid failure
			for i in {1..20}
			do
				if nc $target 1234 < /tmp/my_ip
				then
					break
				else
					sleep 1
				fi
			done
			sleep 1
			# send another time to make sure it can be sent successfully
			nc $target 1234 < /tmp/my_ip
		else
			for i in {1..20}
			do
				if nc -6 $target 1234 < /tmp/my_ip
				then
					break
				else
					sleep 1
				fi
			done
			sleep 1
			nc -6 $target 1234 < /tmp/my_ip
		fi
	done
	# just for debug
	cat /tmp/my_ip
	cat /tmp/target_ip
	sleep 3
	net_sync "exchange_ip-finished"
	# kill listening socket
	while lsof -i TCP:1234; do
		local pid=$(lsof -i TCP:1234 | tail -n1 | awk '{print $2}')
		# use kill rather than kill -9 to let nc write buffer to file
		echo $pid | grep -e "\b[0-9]\+\b" >/dev/null && kill $pid && wait $pid
		sleep 1
	done

	#for debug
	cat /tmp/target_ip
	return $exitcode
}

# get my/target IP/IPv6 address, for single host just let target ip = my ip
# @arg1: interface name
# Param:
#  IPVER - IP version: 4, 6 or "4 6"
update_ip()
{
	rm -rf /tmp/my_ip
	rm -rf /tmp/target_ip

	local iface=${1:-$TEST_IFACE}
	IPVER=${IPVER:-"4 6"}
	local exitcode=0

	lsof -v 2>/dev/null || ${yum} -y install lsof
	echo "MAC $(get_iface_mac $iface) @$HOSTNAME" > /tmp/my_ip
	# dislike combination_test, we just get IP addr, no mask
	echo $IPVER | grep -q 4 && {
		echo "IP4 $(get_iface_ip4 $iface) @$HOSTNAME" >> /tmp/my_ip
	}
	echo $IPVER | grep -q 6 && {
		echo "IP6 $(get_iface_ip6 $iface) @$HOSTNAME" >> /tmp/my_ip
	}
	ip addr show $iface

	i_am_server && TARGET=$CLIENTS
	i_am_client && TARGET=$SERVERS

	if [ "$IPVER" != "6" ]; then
		nc -l 1234 -k > /tmp/target_ip &
	else
		nc -l 1234 -6 -k > /tmp/target_ip &
	fi
	if i_am_server;then
		sync_set client update_ip-started_server
		sync_wait client update_ip-started_client
	else
		sync_wait server update_ip-started_server
		sync_set server update_ip-started_client
	fi
	#net_sync "update_ip-started"
	for target in $TARGET;do
		if [ "$IPVER" != "6" ]; then
			nc $target 1234 < /tmp/my_ip
		else
			nc -6 $target 1234 < /tmp/my_ip
		fi
	done
	sleep 3
	if i_am_server;then
		sync_set client update_ip-finished_server
		sync_wait client update_ip-finished_client
	else
		sync_wait server update_ip-finished_server
		sync_set server update_ip-finished_client
	fi
	#net_sync "update_ip-finished"
	# kill listening socket
	while lsof -i TCP:1234; do
		local pid=$(lsof -i TCP:1234 | tail -n1 | awk '{print $2}')
		echo $pid | grep -e "\b[0-9]\+\b" >/dev/null && kill -9 $pid && wait $pid
		sleep 1
	done
	
	LOCAL_ADDR4=$(awk '/IP4/ {print $2}' /tmp/my_ip)
	LOCAL_ADDR6=$(awk '/IP6/ {print $2}' /tmp/my_ip)
	REMOTE_ADDR4=$(awk '/IP4/ {print $2}' /tmp/target_ip | uniq)
	REMOTE_ADDR6=$(awk '/IP6/ {print $2}' /tmp/target_ip | uniq)
	LOCAL_IFACE_MAC=$(awk '/MAC/ {print $2}' /tmp/my_ip)
	REMOTE_IFACE_MAC=$(awk '/MAC/ {print $2}' /tmp/target_ip | uniq)

	return $exitcode
}

# ---------------------- switch configure  -----------------------------

# Get interface's switch_name and port
# @arg1: interface name(s)
# @arg2: variable name to save switch_name
# @arg3: variable name to save port_list
# @arg4: (optional) variable name to save kicked port_list
get_iface_sw_port()
{
	[ -f "$NIC_INFO" ] || get_netqe_nic_info
	local iface="$1"
	local _switch_name="$2"
	local _port_list="$3"
	local _kick_list="$4"
	local exitcode=0
	typeset -A iface_port_array

	# get iface_port_array
	for i in $iface; do
		local mac=`get_iface_mac $i`
		switch_port=`grep "$mac" $NIC_INFO | awk '{print $2}'`
		[ -n "$switch_port" ] || {
			switch_port=switch-port-error; let exitcode++
		}
		iface_port_array[$i]=$switch_port
	done

	# find the most switch_name
	switch_name=`printf '%s\n' "${iface_port_array[@]}" | \
		sed 's/\([0-9]*\)-[A-Z,a-z].*/\1/' | \
		uniq -c | sort | awk 'END {print $2}'`

	# split switch_name and port_list
	for i in $iface; do
		switch_port="${iface_port_array[$i]}"
		echo "$switch_port" | grep -q "${switch_name}-[A-Z,a-z]" && {
			# just save port
			iface_port_array[$i]="${switch_port#$switch_name-}"
		} || {
			# kick switch_port on different switch
			echo "Warning: $i is on different switch, kick it from the port list" >&2
			iface_port_array[$i]=""
			kick_list+="$i "
			let exitcode++
		}
	done
	port_list="`echo ${iface_port_array[@]}`" # remove newline

	# save and print results
	[[ "$_switch_name" ]] && eval $_switch_name="'$switch_name'" || echo $switch_name
	[[ "$_port_list" ]] && eval $_port_list="'$port_list'" || echo \"$port_list\"
	[[ "$_kick_list" ]] && eval $_kick_list="'$kick_list'"
	return $exitcode
}

swcfg_port_channel()
{
	local switch_name="$1"
	local port_list="$2"
	local mode="$3"
	local exitcode=0

	local cmd="swcfg setup_port_channel $switch_name '$port_list' $mode"
	local cmd_undo="swcfg cleanup_port_channel $switch_name '$port_list'"

	echo "$cmd"
	sleep $((RANDOM%25))
	echo "$cmd" | sh && {
		echo "$cmd_undo" >> $SWCFG_UNDO
		sleep 10
	} || {
		test_fail "Warning: setup switch port-channel fail "
		exitcode=1
	}
	return $exitcode
}

cleanup_swcfg()
{
	local exitcode=0
	test -f $SWCFG_UNDO || {
		return $exitcode
	}

	cat $SWCFG_UNDO
	sh $SWCFG_UNDO && {
		\rm $SWCFG_UNDO
	} || {
		test_fail "Warning: cleanup switch config error"
		local fail_cfg=${SWCFG_UNDO}_fail_$(date +%Y%m%d_%H%M)
		mv $SWCFG_UNDO $fail_cfg
		submit_log $fail_cfg
		let exitcode++;
	}
	sleep 5
	return $exitcode
}

# ---------------------- Guest configure  -----------------------------

# Attach new guests' interface to our bridge
# Parameter:
#   TOPO: The last interface must be bridge, e.g. nic_bridge, nic_vlan_bridge
# Optional parameter:
#   VNIC_NUM
#   GUEST_NAME
#   BRIDGE_NAME
# return 1 for fail
# Usage: add the following parameters in test case /kernel/networking/common
# NAY=yes
# NIC_DRIVER=bnx2
# TOPO=nic_vlan_bridge
# FUNCTION=attach_interface
attach_interface()
{
	TOPO=${TOPO:-"nic_bridge"}
	BRIDGE_NAME=${BRIDGE_NAME:-"test_br"}
	[ "$(GetDistroRelease)" = 7 ] && VCONFIG="--config --live" || \
		VCONFIG="--config"
	# choose NIC and setup topo
	get_test_iface
	if [ ! -d /sys/class/net/${BRIDGE_NAME}/bridge ]; then
		log "Could not find bridge to attach"
		return 1
	fi

	local vnic_num=${VNIC_NUM:-1}
	local guest_list=`virsh list --name`
	local guest_name=${GUEST_NAME:-$guest_list}
	for num in `seq $vnic_num`; do
		for domain in $guest_name; do
			log "Check guest $doamin is running ..."
			virsh list | grep -q "$domain"
			if [ $? -ne 0 ]; then
				log "Guest $domain is not running."
				test_fail "Guest_${domain}_is_not_running"
			fi
			virsh attach-interface $domain --type bridge --source $BRIDGE_NAME $VCONFIG
			if [ $? -ne 0 ]; then
				log "Warn: attach nic $num on $BRIDGE_NAME for $domain failed"
				test_fail "attach_nic_${num}_on_${BRIDGE_NAME}_fail_for_${domain}"
			else
				test_pass "attach_nic_${num}_on_${BRIDGE_NAME}_pass_for_${domain}"
			fi
		done
	done
}

# Function to obtain list of currently reachable IP addresses on subnet specified
# Requires that there is a route available to the subnet specifed
# Usage: get_reachable_ips <subnet>
# Examples of usage:
# get_reachable_ips 192.168.1.0/24
# Typically save results to a variable for future use:
# target_ip_list=$(get_reachable_ips 192.168.1.0/24)
# target_ip1=$(echo $target_ip_list | awk '{print $1}')
# target_ip2=$(echo $target_ip_list | awk '{print $2}')
# if [[ $(echo $target_ips | awk '{print NF}') -lt 2 ]]; then
#	   echo "Not enough target IP addresses available"
# fi
get_reachable_ips()
{
	local exitcode=0
	subnet=$1
	subnet_search_string=$(echo $subnet | awk -F "." '{print $1"."$2"."$3}')
	exclude_file="/home/exclude_ip_list.txt"
	if [[ ! $(ip r | grep "$subnet") ]]; then
		rlLog "No route to the $subnet subet.  Aborting livehosts operation..."
	fi
	rm -f $exclude_file
	if [[ ! $(which nmap) ]]; then
		epel_release_install
		${yum} -y install nmap
	fi
	if [[ $(ip a | grep -w inet | grep -w "$subnet_search_string") ]]; then
		ip a | grep -w inet | grep -w "$subnet_search_string" | awk '{print $2}' | awk -F "/" '{print $1}' > $exclude_file
		nmap $subnet -n -sP --excludefile $exclude_file | grep report | awk '{print $5}' | tee /home/reachable_ips.txt
		if [[ ! -s /home/reachable_ips.txt ]]; then
				rlLog "No reachable IP addresses were found"
		fi
	else
		rlLog "No local IP address residing on target subnet.  Aborting nmap operation..."
		return 1
	fi
	return $exitcode
}

# Function to obtain reachable target IP addresses on 192.168.1.0/24 subnet 
# in case other methods fail.  Requires that there is a route available to the 
# 192.168.1.0/24 subnet.
# Usage: get_target_ip_addr
get_target_ip_addr()
{
	local exitcode=0
	local mgmt_iface=$(ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}')
	local iface_list=$(ls /sys/class/net | egrep -v "lo|ovs|vir|vnet|tun|bond|team|$mgmt_iface")
	local tmp_iface=$(echo $iface_list | awk '{print $NF}')
	echo "Temporary interface being used: $tmp_iface"
	ip link set dev $tmp_iface up
	sleep 2
	pkill dhclient; sleep 2; dhclient -v $tmp_iface
	sleep 2
	if [[ ! $(ip r | grep "192.168.1.0/24") ]]; then
		local tmp_iface=$(echo $iface_list | awk '{print $1}')
		echo "Temporary interface now being used: $tmp_iface"
		ip link set dev $tmp_iface up
		sleep 2
		pkill dhclient; sleep 2; dhclient -v $tmp_iface
		sleep 2
	fi
	if [[ ! $(ip r | grep "192.168.1.0/24") ]]; then
		rlLog "Tried dhcp on 2 ifaces but still no route to the 192.168.1.0/24 subnet.  Aborting get_target_ip_addr operation..."
		return 1
	fi
	local target_ip_list=$(get_reachable_ips 192.168.1.0/24)
	if [[ $(echo $target_ip_list | grep "192.168.1.254") ]]; then
		target_ip="192.168.1.254"
	elif [[ $(echo $target_ip_list | grep "192.168.1.253") ]]; then
		target_ip="192.168.1.253"
	else
		target_ip=$(echo $target_ip_list | awk '{print $NF}')
	fi
	echo "Target IP address is: $target_ip"
	ip addr flush dev $tmp_iface
	return $exitcode
}

