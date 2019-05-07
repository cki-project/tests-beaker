#!/bin/bash

# Setup complicated interface(nic/bond vlan bridge)
# @arg1: inputs NICs
#
# @arg2: TOPO: nic, nic_vlan, nic_bridge, nic_bridge_vlan, nic_vlan_bridge,
#   bond, bond_vlan, bond_bridge, bond_bridge_vlan, bond_vlan_bridge,
#   team, team_vlan, team_bridge, team_bridge_vlan, team_vlan_bridge
#
# @arg3: (optional) variable to save the result
#
# example: NAY=yes; NIC_NUM=2; TOPO=bond_vlan; NM_setup_topo
#      or: NAY=yes; NIC_NUM=2; TOPO=bond_vlan; NM_CTL=yes; setup_topo
NM_setup_topo()
{
	local exitcode=0
	local handle="$1"
	local option="${2:-$TOPO}"
	local _output="$3"
	local topo_ret="$handle"
	option=${option//_/ }
	local topo=""
	local mtu=${MTU_VAL:-1500}

	echo $handle >> /tmp/test_nic
	echo -e "\n----------- start setup $option, handle: $handle -----------"

	for topo in $option; do
		echo
		case $topo in
			nic)
				NM_setup_nic "$topo_ret"		|| let exitcode++
				;;
			bond)
				NM_setup_bond "$topo_ret" "$BOND_NAME"	|| let exitcode++
				cat /proc/net/bonding/$topo_ret
				;;
			team)
				NM_setup_team "$topo_ret"  "$TEAM_NAME" || let exitcode++
				teamdctl $topo_ret config dump actual
				teamdctl $topo_ret state dump
				;;
			vlan)
				NM_setup_vlan "$topo_ret"		|| let exitcode++
				;;
			bridge)
				NM_setup_bridge "$topo_ret"		|| let exitcode++
				bridge link
				;;
			*)
				echo "Error: unsupported topo set"
				let exitcode++
				;;
		esac
		sleep 3

	done
	echo -e "\n---------- finish setup $option, got iface: $topo_ret --------\n"
	nmcli con sh
	nmcli dev sh $topo_ret
	[[ "$_output" ]] && eval $_output="'$topo_ret'"
	return $exitcode
}

# setup NIC
# @arg1: input NIC name
NM_setup_nic()
{
	local IF=$1
	nmcli con del $IF &>/dev/null
	nmcli con add type ethernet ifname $IF con-name $IF mtu $mtu
	topo_ret=$IF
}

# setup vlan
# @arg1: input interface name
NM_setup_vlan()
{
	local vid=${VLAN_ID:-'3'}
	local IF=$1
	topo_ret="$IF.$vid"
	nmcli con add type vlan con-name $IF.$vid dev $IF id $vid mtu $mtu
}

# setup team
# @arg1: input NIC(s)
# @arg2: team name
# @arg3: (optional) variable to save the result
NM_setup_team()
{
	local exitcode=0
	local handle=$1
	if [ -z "$handle" ]; then
		echo "FAIL, Team interface is empty"
		exit 1
	fi
	local option=$2
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
	if [ "$SWCFG_AUTO" = yes ] && [ "$NAY" = yes ] && echo "$team_json" | \egrep -q -w \
		"runner.*:.*(roundrobin|loadbalance|lacp)"; then
		if echo "$team_json" | \egrep -q -w "runner.*:.*lacp"; then
			port_channel_mode=active
		else
			port_channel_mode=on
		fi

		get_iface_sw_port "$handle" switch_name port_list kick_list || let exitcode++
		swcfg_port_channel $switch_name "$port_list" $port_channel_mode || let exitcode++
	fi

	# create team interface
	nmcli con add type team ifname $topo_ret con-name $topo_ret config "$team_json" || let exitcode++

	# add enslave nic
	for i in $handle; do
		nmcli con add type team-slave ifname $i master $topo_ret || let exitcode++
		nmcli con modify team-slave-$i 802-3-ethernet.mtu $mtu
		nmcli con up team-slave-$i || let exitcode++
		sleep 2
	done
	# Bug 1303968: MTU Fails to Set
	nmcli con modify $topo_ret 802-3-ethernet.mtu $mtu
	nmcli con up $topo_ret
	sleep 2
	return $exitcode
}

# setup bond
# @arg1: input NIC(s)
# @arg2: bonding name
NM_setup_bond()
{
	local exitcode=0
	local handle=$1
	if [ -z "$handle" ]; then
		echo "FAIL, Bonding interface is empty"
		exit 1
	fi
	local option=$2
	local bond_opts_nm=
	topo_ret=$option

	echo BOND_NAME=\'$BOND_NAME\'
	echo BOND_OPTS=\'$BOND_OPTS\'
	# parse bonding options
	# nmcli only support: mode primary miimon downdelay updelay arp-interval arp-ip-target
	bond_opts_nm="$(echo $BOND_OPTS | sed -e 's/_/-/g; s/=/ /g')"

	# config port-channel on switch
	if [ "$SWCFG_AUTO" = yes ] && [ "$NAY" = yes ] && echo "$BOND_OPTS" | \egrep -q -w \
		"mode=(0|2|4|balance-rr|balance-xor|802.3ad)"; then
		if echo "$BOND_OPTS" | \egrep -q -w "mode=(4|802.3ad)"; then
			port_channel_mode=active
		else
			port_channel_mode=on
		fi

		get_iface_sw_port "$handle" switch_name port_list kick_list || let exitcode++
		swcfg_port_channel $switch_name "$port_list" $port_channel_mode || let exitcode++
	fi

	# add bonding interface
	nmcli con add type bond ifname $topo_ret con-name $topo_ret $bond_opts_nm || let exitcode++

	# enslave NICs
	for i in $handle; do
		nmcli con add type bond-slave ifname $i master $topo_ret || let exitcode++
		nmcli con modify bond-slave-$i 802-3-ethernet.mtu $mtu
		nmcli con up bond-slave-$i || let exitcode++
		sleep 2
	done
	nmcli con modify $topo_ret 802-3-ethernet.mtu $mtu
	nmcli con up $topo_ret
	sleep 2
	return $exitcode
}

# setup bridge
# @arg1: inputs interface name(s) for bridge ports
# @arg2: bridge name
NM_setup_bridge()
{
	local handle="$1"
	local option="${2:-br0}"
	topo_ret="$option"

	nmcli con add type bridge ifname $topo_ret con-name $topo_ret
	nmcli con modify $topo_ret 802-3-ethernet.mtu $mtu
	nmcli con up $topo_ret
	for i in $handle; do
		nmcli con modify $i connection.master $topo_ret connection.slave-type bridge
		nmcli con modify $i 802-3-ethernet.mtu $mtu
		nmcli con up $i
		sleep 2
	done
	sleep 5
}
