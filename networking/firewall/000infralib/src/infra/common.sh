#!/bin/sh

############################################################
# Common functions definition
############################################################
# internal APIs
topo_generate_nwaddr()
{
	local topo=$1; local subnet=$2; local family=$3;
	local offset=0
	[ -n "$JOBID" ] && { offset=$((JOBID % 100)); }
	case $topo in
		'cs') offset=$((offset))
			case $subnet in
				'net') offset=$((offset+1));;
			esac
			;;
		'bf') offset=$((offset+10))
			case $subnet in
				'net') offset=$((offset+1));;
			esac
			;;
		'rf') offset=$((offset+20))
			case $subnet in
				'cnet') offset=$((offset+1));;
				'snet') offset=$((offset+2));;
			esac
			;;
		'bf2') offset=$((offset+30))
			case $subnet in
				'net') offset=$((offset+1));;
				'vxnet') offset=$((offset+2));;
			esac
			;;
		'rf2') offset=$((offset+40))
			case $subnet in
				'cnet') offset=$((offset+1));;
				'rnet') offset=$((offset+2));;
				'snet') offset=$((offset+3));;
			esac
			;;
		'lb') offset=$((offset+50))
			case $subnet in
				'cnet') offset=$((offset+1));;
				'snet') offset=$((offset+2));;
				'lnet') offset=$((offset));;
			esac
			;;
		'lb2') offset=$((offset+60))
			case $subnet in
				'net') offset=$((offset+1));;
				'lnet') offset=$((offset));;
			esac
			;;
		'lb3') offset=$((offset+70))
			case $subnet in
				'onet') offset=$((offset+1));;
				'inet') offset=$((offset+2));;
				'lnet') offset=$((offset));;
			esac
			;;
		'ha') offset=$((offset+80))
			case $subnet in
				'cnet') offset=$((offset+1));;
				'fnet') offset=$((offset+2));;
				'snet') offset=$((offset+3));;
				'lnet') offset=$((offset));;
			esac
			;;
		'tcf') offset=$((offset+90))
			case $subnet in
				'net') offset=$((offset+1));;
				'vxnet') offset=$((offset+2));;
				'genet') offset=$((offset+3));;
			esac
			;;
		'tcf2') offset=$((offset+100))
			case $subnet in
				'net') offset=$((offset+1));;
				'vxnet') offset=$((offset+2));;
				'genet') offset=$((offset+3));;
			esac
			;;
	esac
	if [ $family == "ip6lnk" ]; then
		echo -n "fe80:0:0:${offset}::0"
	elif [ $family == "ip6" ]; then
		echo -n "2001:db8:ffff:${offset}::0"
	else
		echo -n "10.167.${offset}.0"
	fi
}
topo_define_run()
{
	local topo=$1
	eval "run()
	{
		local guest=\$1; shift; local cmd=\$@;
		echo \"[\$(date '+%T')][\$guest]$ \"\$cmd
		if [ \$guest == 'controller' ]; then
			topo_lo_run \$cmd
		else
			topo_${topo}_run \$guest \$cmd
		fi
	}"
}
topo_env_init()
{
	local topo=$1; local guest; local iface; local en;
	# run() function preparing
	topo_define_run ${topo}
	# old infrastructures cleaning
	topo_${topo}_destroy
	# network settings cleaning
	for guest in $(topo_${topo}_guests); do
		run ${guest} network_link_clean
		run ${guest} network_addr_clean
		run ${guest} netfilter_rules_clean
		run ${guest} netfilter_defrag_clean
		run ${guest} netfilter_brnf_clean
		run ${guest} netsched_rules_clean
	done
	# new infrastructures creating
	topo_${topo}_create
	# network settings initiating
	for guest in $(topo_${topo}_guests); do
		run ${guest} network_sysctl_restore ${topo} ${guest}
		for iface in $(topo_${topo}_ifaces ${guest}); do
			run ${guest} ip link set $iface up
			run ${guest} nmcli device set $iface managed no
			run ${guest} network_set_offload $iface $MH_OFFLOADS
		done
	done
	# old variables cleaning
	for en in $(env | grep ^${topo}'_' | cut -d '=' -f 1); do
		unset $en
	done
}
topo_env_check()
{
	local topo=$1; local guest;
	for guest in $(topo_${topo}_guests); do
		run ${guest} uname -r
		run ${guest} network_show_drivers
		run ${guest} nmcli device status
		run ${guest} ip addr
		run ${guest} netfilter_modules_show
		run ${guest} netsched_modules_show
	done
}
# external APIs
topo_netfilter_clean_all()
{
	local topo; local guest;
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: netfilter clean all"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	for topo in cs bf bf2 rf rf2 lb lb2 lb3 ha; do
		type -t topo_${topo}_guests > /dev/null 2>&1 || continue
		topo_define_run ${topo}
		for guest in $(topo_${topo}_guests); do
			run ${guest} netfilter_rules_clean
			run ${guest} netfilter_modules_unload
			run ${guest} netfilter_modules_show
		done
	done
}
topo_netsched_clean_all()
{
	local topo; local guest;
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: netsched clean all"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	for topo in cs bf rf tcf tcf2; do
		type -t topo_${topo}_guests > /dev/null 2>&1 || continue
		topo_define_run ${topo}
		for guest in $(topo_${topo}_guests); do
			run ${guest} netsched_rules_clean
			run ${guest} netsched_modules_unload
			run ${guest} netsched_modules_show
			run ${guest} mellanox_cleanup
			run ${guest} netronome_cleanup
		done
	done
}

###########################################################
# Topo: Client Server
###########################################################
# external APIs
topo_cs_help()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::   |-----------------|"
	echo "::   | Client---Server |"
	echo "::   |-----------------|"
	echo ":: - Functions predefined"
	echo "::   - topo_cs_init"
	echo "::   - topo_cs_ipv4"
	echo "::   - topo_cs_ipv6"
	echo "::   - topo_cs_ah"
	echo "::   - topo_cs_esp"
	echo "::   - topo_cs_check [ipv4|ipv6]"
	echo "::   - run [client|server] [cmd]"
	echo ":: - Variables predefined"
	echo "::   - cs_client_bif"
	echo "::   - cs_server_bif"
	echo "::   - cs_client_if1"
	echo "::   - cs_server_if1"
	echo "::   - cs_client_mac1"
	echo "::   - cs_server_mac1"
	echo "::   - cs_net_ip"
	echo "::   - cs_client_ip1"
	echo "::   - cs_server_ip1"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
}
topo_cs_init()
{
	topo_env_init cs

	export cs_client_if1=$(topo_cs_ifaces client | awk '{print $1}')
	export cs_server_if1=$(topo_cs_ifaces server | awk '{print $1}')

	export cs_client_mac1=`run client ip a s dev $cs_client_if1 | grep ether | awk '{print $2}'`
	export cs_server_mac1=`run server ip a s dev $cs_server_if1 | grep ether | awk '{print $2}'`

	export cs_client_bif=`run client ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export cs_server_bif=`run server ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
}
topo_cs_ipv4()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export cs_net_ip=$(topo_generate_nwaddr cs net ip)
	export cs_client_ip1=${cs_net_ip%0}2
	export cs_server_ip1=${cs_net_ip%0}1

	run client ip addr add $cs_client_ip1/24 dev $cs_client_if1
	run server ip addr add $cs_server_ip1/24 dev $cs_server_if1
	run client ip link set lo up
	run server ip link set lo up
}
topo_cs_ipv6()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export cs_net_ip=$(topo_generate_nwaddr cs net ip6)
	export cs_client_ip1=${cs_net_ip%0}2
	export cs_server_ip1=${cs_net_ip%0}1

	run client ip addr add $cs_client_ip1/64 dev $cs_client_if1
	run server ip addr add $cs_server_ip1/64 dev $cs_server_if1
	run client ip link set lo up
	run server ip link set lo up
}
topo_cs_ah()
{
	[ -z "$1" ] && { local spi_request=0x1000; } || { local spi_request=$1; }
	[ -z "$2" ] && { local spi_reply=0x2000; } || { local spi_reply=$2; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: AH settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	run client ip xfrm state add src $cs_client_ip1 dst $cs_server_ip1 proto ah spi $spi_request mode transport auth hmac\\\(sha1\\\) ipv6readylogsha11to2
	run server ip xfrm state add src $cs_client_ip1 dst $cs_server_ip1 proto ah spi $spi_request mode transport auth hmac\\\(sha1\\\) ipv6readylogsha11to2
	run client ip xfrm state add src $cs_server_ip1 dst $cs_client_ip1 proto ah spi $spi_reply mode transport auth hmac\\\(sha1\\\) ipv6readylogsha12to1
	run server ip xfrm state add src $cs_server_ip1 dst $cs_client_ip1 proto ah spi $spi_reply mode transport auth hmac\\\(sha1\\\) ipv6readylogsha12to1
	run client ip xfrm policy add dir out src $cs_client_ip1 dst $cs_server_ip1 proto any tmpl proto ah mode transport level required
	run server ip xfrm policy add dir out src $cs_server_ip1 dst $cs_client_ip1 proto any tmpl proto ah mode transport level required
	run client ip xfrm policy add dir in src $cs_server_ip1 dst $cs_client_ip1 proto any tmpl proto ah mode transport level required
	run server ip xfrm policy add dir in src $cs_client_ip1 dst $cs_server_ip1 proto any tmpl proto ah mode transport level required
}
topo_cs_esp()
{
	[ -z "$1" ] && { local spi_request=0x1000; } || { local spi_request=$1; }
	[ -z "$2" ] && { local spi_reply=0x2000; } || { local spi_reply=$2; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: ESP settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	run client ip xfrm state add src $cs_client_ip1 dst $cs_server_ip1 proto esp spi $spi_request mode transport enc blowfish ipv6readylogo3descbc1to2 auth hmac\\\(sha1\\\) ipv6readylogsha11to2
	run server ip xfrm state add src $cs_client_ip1 dst $cs_server_ip1 proto esp spi $spi_request mode transport enc blowfish ipv6readylogo3descbc1to2 auth hmac\\\(sha1\\\) ipv6readylogsha11to2
	run client ip xfrm state add src $cs_server_ip1 dst $cs_client_ip1 proto esp spi $spi_reply mode transport enc blowfish ipv6readylogo3descbc2to1 auth hmac\\\(sha1\\\) ipv6readylogsha12to1
	run server ip xfrm state add src $cs_server_ip1 dst $cs_client_ip1 proto esp spi $spi_reply mode transport enc blowfish ipv6readylogo3descbc2to1 auth hmac\\\(sha1\\\) ipv6readylogsha12to1
	run client ip xfrm policy add dir out src $cs_client_ip1 dst $cs_server_ip1 proto any tmpl src $cs_client_ip1 dst $cs_server_ip1 proto esp mode transport level required
	run server ip xfrm policy add dir out src $cs_server_ip1 dst $cs_client_ip1 proto any tmpl src $cs_server_ip1 dst $cs_client_ip1 proto esp mode transport level required
	run client ip xfrm policy add dir in src $cs_server_ip1 dst $cs_client_ip1 proto any tmpl src $cs_server_ip1 dst $cs_client_ip1 proto esp mode transport level required
	run server ip xfrm policy add dir in src $cs_client_ip1 dst $cs_server_ip1 proto any tmpl src $cs_client_ip1 dst $cs_server_ip1 proto esp mode transport level required
}
topo_cs_check()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: CS checking"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_env_check cs

	local result=0
	run client ping_pass -I $cs_client_if1 $cs_server_ip1 -c 3 || { result=1; }
	run server ping_pass -I $cs_server_if1 $cs_client_ip1 -c 3 || { result=1; }
	return $result
}

############################################################
# Topo: Bridge Forward
############################################################
# external APIs
topo_bf_help()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::   |--------------------------|"
	echo "::   | Client---Bridge---Server |"
	echo "::   |--------------------------|"
	echo ":: - Functions predefined"
	echo "::   - topo_bf_init"
	echo "::   - topo_bf_vlan"
	echo "::   - topo_bf_ipv4"
	echo "::   - topo_bf_ipv6"
	echo "::   - topo_bf_ah"
	echo "::   - topo_bf_esp"
	echo "::   - topo_bf_check [ipv4|ipv6]"
	echo "::   - run [client|bridge|server] [cmd]"
	echo ":: - Variables predefined"
	echo "::   - bf_client_bif"
	echo "::   - bf_bridge_bif"
	echo "::   - bf_server_bif"
	echo "::   - bf_client_if1"
	echo "::   - bf_bridge_if0"
	echo "::   - bf_bridge_if1"
	echo "::   - bf_bridge_if2"
	echo "::   - bf_server_if1"
	echo "::   - bf_client_mac1"
	echo "::   - bf_bridge_mac0"
	echo "::   - bf_bridge_mac1"
	echo "::   - bf_bridge_mac2"
	echo "::   - bf_server_mac1"
	echo "::   - bf_net_ip"
	echo "::   - bf_client_ip1"
	echo "::   - bf_bridge_ip0"
	echo "::   - bf_server_ip1"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
}
topo_bf_init()
{
	topo_env_init bf

	export bf_client_if1=$(topo_bf_ifaces client | awk '{print $1}')
	export bf_server_if1=$(topo_bf_ifaces server | awk '{print $1}')
	export bf_bridge_if0=$(topo_bf_ifaces bridge | awk '{print $1}')
	export bf_bridge_if1=$(topo_bf_ifaces bridge | awk '{print $2}')
	export bf_bridge_if2=$(topo_bf_ifaces bridge | awk '{print $3}')

	export bf_client_mac1=`run client ip a s dev $bf_client_if1 | grep ether | awk '{print $2}'`
	export bf_server_mac1=`run server ip a s dev $bf_server_if1 | grep ether | awk '{print $2}'`
	export bf_bridge_mac0=`run bridge ip a s dev $bf_bridge_if0 | grep ether | awk '{print $2}'`
	export bf_bridge_mac1=`run bridge ip a s dev $bf_bridge_if1 | grep ether | awk '{print $2}'`
	export bf_bridge_mac2=`run bridge ip a s dev $bf_bridge_if2 | grep ether | awk '{print $2}'`

	export bf_client_bif=`run client ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export bf_server_bif=`run server ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export bf_bridge_bif=`run bridge ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
}
topo_bf_vlan()
{
	[ -z "$1" ] && { local id=99; } || { local id=$1; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: VLAN settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	local bf_client_vif=$bf_client_if1.$id
	local bf_server_vif=$bf_server_if1.$id

	run client ip link add link $bf_client_if1 name $bf_client_vif type vlan id $id
	run server ip link add link $bf_server_if1 name $bf_server_vif type vlan id $id
	run client ip link set $bf_client_vif up
	run server ip link set $bf_server_vif up
	run client network_set_offload $bf_client_vif $MH_OFFLOADS
	run server network_set_offload $bf_server_vif $MH_OFFLOADS

	export bf_client_if1=$bf_client_vif
	export bf_server_if1=$bf_server_vif
	export bf_client_mac1=`run client ip a s dev $bf_client_if1 | grep ether | awk '{print $2}'`
	export bf_server_mac1=`run server ip a s dev $bf_server_if1 | grep ether | awk '{print $2}'`
}
topo_bf_ipv4()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export bf_net_ip=$(topo_generate_nwaddr bf net ip)
	export bf_client_ip1=${bf_net_ip%0}2
	export bf_server_ip1=${bf_net_ip%0}1
	export bf_bridge_ip0=${bf_net_ip%0}254

	run client ip addr add $bf_client_ip1/24 dev $bf_client_if1
	run bridge ip addr add $bf_bridge_ip0/24 dev $bf_bridge_if0
	run server ip addr add $bf_server_ip1/24 dev $bf_server_if1
	run client ip link set lo up
	run bridge ip link set lo up
	run server ip link set lo up
}
topo_bf_ipv6()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export bf_net_ip=$(topo_generate_nwaddr bf net ip6)
	export bf_client_ip1=${bf_net_ip%0}2
	export bf_server_ip1=${bf_net_ip%0}1
	export bf_bridge_ip0=${bf_net_ip%0}fffe

	run client ip addr add $bf_client_ip1/64 dev $bf_client_if1
	run bridge ip addr add $bf_bridge_ip0/64 dev $bf_bridge_if0
	run server ip addr add $bf_server_ip1/64 dev $bf_server_if1
	run client ip link set lo up
	run bridge ip link set lo up
	run server ip link set lo up
}
topo_bf_ah()
{
	[ -z "$1" ] && { local spi_request=0x1000; } || { local spi_request=$1; }
	[ -z "$2" ] && { local spi_reply=0x2000; } || { local spi_reply=$2; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: AH settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	run client ip xfrm state add src $bf_client_ip1 dst $bf_server_ip1 proto ah spi $spi_request mode transport auth hmac\\\(sha1\\\) ipv6readylogsha11to2
	run server ip xfrm state add src $bf_client_ip1 dst $bf_server_ip1 proto ah spi $spi_request mode transport auth hmac\\\(sha1\\\) ipv6readylogsha11to2
	run client ip xfrm state add src $bf_server_ip1 dst $bf_client_ip1 proto ah spi $spi_reply mode transport auth hmac\\\(sha1\\\) ipv6readylogsha12to1
	run server ip xfrm state add src $bf_server_ip1 dst $bf_client_ip1 proto ah spi $spi_reply mode transport auth hmac\\\(sha1\\\) ipv6readylogsha12to1
	run client ip xfrm policy add dir out src $bf_client_ip1 dst $bf_server_ip1 proto any tmpl proto ah mode transport level required
	run server ip xfrm policy add dir out src $bf_server_ip1 dst $bf_client_ip1 proto any tmpl proto ah mode transport level required
	run client ip xfrm policy add dir in src $bf_server_ip1 dst $bf_client_ip1 proto any tmpl proto ah mode transport level required
	run server ip xfrm policy add dir in src $bf_client_ip1 dst $bf_server_ip1 proto any tmpl proto ah mode transport level required
}
topo_bf_esp()
{
	[ -z "$1" ] && { local spi_request=0x1000; } || { local spi_request=$1; }
	[ -z "$2" ] && { local spi_reply=0x2000; } || { local spi_reply=$2; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: ESP settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	run client ip xfrm state add src $bf_client_ip1 dst $bf_server_ip1 proto esp spi $spi_request mode transport enc blowfish ipv6readylogo3descbc1to2 auth hmac\\\(sha1\\\) ipv6readylogsha11to2
	run server ip xfrm state add src $bf_client_ip1 dst $bf_server_ip1 proto esp spi $spi_request mode transport enc blowfish ipv6readylogo3descbc1to2 auth hmac\\\(sha1\\\) ipv6readylogsha11to2
	run client ip xfrm state add src $bf_server_ip1 dst $bf_client_ip1 proto esp spi $spi_reply mode transport enc blowfish ipv6readylogo3descbc2to1 auth hmac\\\(sha1\\\) ipv6readylogsha12to1
	run server ip xfrm state add src $bf_server_ip1 dst $bf_client_ip1 proto esp spi $spi_reply mode transport enc blowfish ipv6readylogo3descbc2to1 auth hmac\\\(sha1\\\) ipv6readylogsha12to1
	run client ip xfrm policy add dir out src $bf_client_ip1 dst $bf_server_ip1 proto any tmpl src $bf_client_ip1 dst $bf_server_ip1 proto esp mode transport level required
	run server ip xfrm policy add dir out src $bf_server_ip1 dst $bf_client_ip1 proto any tmpl src $bf_server_ip1 dst $bf_client_ip1 proto esp mode transport level required
	run client ip xfrm policy add dir in src $bf_server_ip1 dst $bf_client_ip1 proto any tmpl src $bf_server_ip1 dst $bf_client_ip1 proto esp mode transport level required
	run server ip xfrm policy add dir in src $bf_client_ip1 dst $bf_server_ip1 proto any tmpl src $bf_client_ip1 dst $bf_server_ip1 proto esp mode transport level required
}
topo_bf_check()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: BF checking"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_env_check bf
	run bridge ip link show master $bf_bridge_if0

	local result=0
	run client ping_pass -I $bf_client_if1 $bf_server_ip1 -c 3 || { result=1; }
	run server ping_pass -I $bf_server_if1 $bf_client_ip1 -c 3 || { result=1; }
	return $result
}

###########################################################
# Topo: Route Forward
###########################################################
# external APIs
topo_rf_help()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::   |--------------------------|"
	echo "::   | Client---Router---Server |"
	echo "::   |--------------------------|"
	echo ":: - Functions predefined"
	echo "::   - topo_rf_init"
	echo "::   - topo_rf_ipv4"
	echo "::   - topo_rf_ipv6"
	echo "::   - topo_rf_check [ipv4|ipv6]"
	echo "::   - run [client|router|server] [cmd]"
	echo ":: - Variables predefined"
	echo "::   - rf_client_bif"
	echo "::   - rf_router_bif"
	echo "::   - rf_server_bif"
	echo "::   - rf_client_if1"
	echo "::   - rf_router_if1"
	echo "::   - rf_router_if2"
	echo "::   - rf_server_if1"
	echo "::   - rf_client_mac1"
	echo "::   - rf_router_mac1"
	echo "::   - rf_router_mac2"
	echo "::   - rf_server_mac1"
	echo "::   - rf_cnet_ip"
	echo "::   - rf_snet_ip"
	echo "::   - rf_client_ip1"
	echo "::   - rf_router_ip1"
	echo "::   - rf_router_ip2"
	echo "::   - rf_server_ip1"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
}
topo_rf_init()
{
	topo_env_init rf

	export rf_client_if1=$(topo_rf_ifaces client | awk '{print $1}')
	export rf_server_if1=$(topo_rf_ifaces server | awk '{print $1}')
	export rf_router_if1=$(topo_rf_ifaces router | awk '{print $1}')
	export rf_router_if2=$(topo_rf_ifaces router | awk '{print $2}')

	export rf_client_mac1=`run client ip a s dev $rf_client_if1 | grep ether | awk '{print $2}'`
	export rf_server_mac1=`run server ip a s dev $rf_server_if1 | grep ether | awk '{print $2}'`
	export rf_router_mac1=`run router ip a s dev $rf_router_if1 | grep ether | awk '{print $2}'`
	export rf_router_mac2=`run router ip a s dev $rf_router_if2 | grep ether | awk '{print $2}'`

	export rf_client_bif=`run client ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export rf_server_bif=`run server ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export rf_router_bif=`run router ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
}
topo_rf_ipv4()
{
	local rftype=$1
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export rf_cnet_ip=$(topo_generate_nwaddr rf cnet ip)
	export rf_snet_ip=$(topo_generate_nwaddr rf snet ip)

	if [ -n "$rftype" ] && [ $rftype == "netmap" ]; then
		export rf_client_ip1=${rf_cnet_ip%0}2
		export rf_router_ip1=${rf_cnet_ip%0}1
		export rf_router_ip2=${rf_snet_ip%0}2
		export rf_server_ip1=${rf_snet_ip%0}1
	else
		export rf_client_ip1=${rf_cnet_ip%0}2
		export rf_router_ip1=${rf_cnet_ip%0}254
		export rf_router_ip2=${rf_snet_ip%0}254
		export rf_server_ip1=${rf_snet_ip%0}1
	fi

	run client ip addr add $rf_client_ip1/24 dev $rf_client_if1
	run router ip addr add $rf_router_ip1/24 dev $rf_router_if1
	run router ip addr add $rf_router_ip2/24 dev $rf_router_if2
	run server ip addr add $rf_server_ip1/24 dev $rf_server_if1
	run client ip link set lo up
	run router ip link set lo up
	run server ip link set lo up

	run router sysctl -w net.ipv4.ip_forward=1
	run client ip route add ${rf_snet_ip}/24 via ${rf_router_ip1} dev $rf_client_if1
	run server ip route add ${rf_cnet_ip}/24 via ${rf_router_ip2} dev $rf_server_if1
}
topo_rf_ipv6()
{
	local rftype=$1
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export rf_cnet_ip=$(topo_generate_nwaddr rf cnet ip6)
	export rf_snet_ip=$(topo_generate_nwaddr rf snet ip6)

	if [ -n "$rftype" ] && [ $rftype == "netmap" ]; then
		export rf_client_ip1=${rf_cnet_ip%0}2
		export rf_router_ip1=${rf_cnet_ip%0}1
		export rf_router_ip2=${rf_snet_ip%0}2
		export rf_server_ip1=${rf_snet_ip%0}1
	else
		export rf_client_ip1=${rf_cnet_ip%0}2
		export rf_router_ip1=${rf_cnet_ip%0}fffe
		export rf_router_ip2=${rf_snet_ip%0}fffe
		export rf_server_ip1=${rf_snet_ip%0}1
	fi

	run client ip addr add $rf_client_ip1/64 dev $rf_client_if1
	run router ip addr add $rf_router_ip1/64 dev $rf_router_if1
	run router ip addr add $rf_router_ip2/64 dev $rf_router_if2
	run server ip addr add $rf_server_ip1/64 dev $rf_server_if1
	run client ip link set lo up
	run router ip link set lo up
	run server ip link set lo up

	run router sysctl -w net.ipv6.conf.all.forwarding=1
	run client ip route add ${rf_snet_ip}/64 via ${rf_router_ip1} dev $rf_client_if1
	run server ip route add ${rf_cnet_ip}/64 via ${rf_router_ip2} dev $rf_server_if1
}
topo_rf_ah()
{
	[ -z "$1" ] && { local spi_request=0x1000; } || { local spi_request=$1; }
	[ -z "$2" ] && { local spi_reply=0x2000; } || { local spi_reply=$2; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: AH settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	# Security Association Database
	run client ip xfrm state add src $rf_client_ip1 dst $rf_server_ip1 proto ah spi $spi_request mode transport auth 'hmac\(sha1\)' ipv6readylogsha11to2
	run server ip xfrm state add src $rf_client_ip1 dst $rf_server_ip1 proto ah spi $spi_request mode transport auth 'hmac\(sha1\)' ipv6readylogsha11to2
	run client ip xfrm state add src $rf_server_ip1 dst $rf_client_ip1 proto ah spi $spi_reply   mode transport auth 'hmac\(sha1\)' ipv6readylogsha12to1
	run server ip xfrm state add src $rf_server_ip1 dst $rf_client_ip1 proto ah spi $spi_reply   mode transport auth 'hmac\(sha1\)' ipv6readylogsha12to1
	# Security Policy Database
	run client ip xfrm policy add dir out src $rf_client_ip1 dst $rf_server_ip1 proto any tmpl proto ah mode transport level required
	run server ip xfrm policy add dir out src $rf_server_ip1 dst $rf_client_ip1 proto any tmpl proto ah mode transport level required
	run client ip xfrm policy add dir in  src $rf_server_ip1 dst $rf_client_ip1 proto any tmpl proto ah mode transport level required
	run server ip xfrm policy add dir in  src $rf_client_ip1 dst $rf_server_ip1 proto any tmpl proto ah mode transport level required
}
topo_rf_esp()
{
	[ -z "$1" ] && { local spi_request=0x1000; } || { local spi_request=$1; }
	[ -z "$2" ] && { local spi_reply=0x2000; } || { local spi_reply=$2; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: ESP settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	# Security Association Database
	run client ip xfrm state add src $rf_client_ip1 dst $rf_server_ip1 proto esp spi $spi_request mode transport auth 'hmac\(sha1\)' ipv6readylogsha11to2 enc blowfish ipv6readylogo3descbc1to2
	run server ip xfrm state add src $rf_client_ip1 dst $rf_server_ip1 proto esp spi $spi_request mode transport auth 'hmac\(sha1\)' ipv6readylogsha11to2 enc blowfish ipv6readylogo3descbc1to2
	run client ip xfrm state add src $rf_server_ip1 dst $rf_client_ip1 proto esp spi $spi_reply   mode transport auth 'hmac\(sha1\)' ipv6readylogsha12to1 enc blowfish ipv6readylogo3descbc2to1
	run server ip xfrm state add src $rf_server_ip1 dst $rf_client_ip1 proto esp spi $spi_reply   mode transport auth 'hmac\(sha1\)' ipv6readylogsha12to1 enc blowfish ipv6readylogo3descbc2to1
	# Security Policy Database
	run client ip xfrm policy add dir out src $rf_client_ip1 dst $rf_server_ip1 proto any tmpl proto esp mode transport level required
	run server ip xfrm policy add dir out src $rf_server_ip1 dst $rf_client_ip1 proto any tmpl proto esp mode transport level required
	run client ip xfrm policy add dir in  src $rf_server_ip1 dst $rf_client_ip1 proto any tmpl proto esp mode transport level required
	run server ip xfrm policy add dir in  src $rf_client_ip1 dst $rf_server_ip1 proto any tmpl proto esp mode transport level required
}
topo_rf_check()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: RF checking"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_env_check rf

	local result=0
	run client ping_pass -I $rf_client_if1 $rf_server_ip1 -c 3 || { result=1; }
	run server ping_pass -I $rf_server_if1 $rf_client_ip1 -c 3 || { result=1; }
	return $result
}

###########################################################
# Topo: Bridge Forward #2
###########################################################
# external APIs
topo_bf2_help()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::   |-------------------------------------|"
	echo "::   | Client---Bridge1---Bridge2---Server |"
	echo "::   |-------------------------------------|"
	echo ":: - Functions predefined"
	echo "::   - topo_bf2_init"
	echo "::   - topo_bf2_ipv4"
	echo "::   - topo_bf2_ipv6"
	echo "::   - topo_bf2_check [ipv4|ipv6]"
	echo "::   - run [client|bridge1|bridge2|server] [cmd]"
	echo ":: - Variables predefined"
	echo "::   - bf2_client_bif"
	echo "::   - bf2_server_bif"
	echo "::   - bf2_bridge1_bif"
	echo "::   - bf2_bridge2_bif"
	echo "::   - bf2_client_if1"
	echo "::   - bf2_server_if1"
	echo "::   - bf2_bridge1_if0"
	echo "::   - bf2_bridge1_if1"
	echo "::   - bf2_bridge1_if2"
	echo "::   - bf2_bridge2_if0"
	echo "::   - bf2_bridge2_if1"
	echo "::   - bf2_bridge2_if2"
	echo "::   - bf2_client_mac1"
	echo "::   - bf2_server_mac1"
	echo "::   - bf2_bridge1_mac0"
	echo "::   - bf2_bridge1_mac1"
	echo "::   - bf2_bridge1_mac2"
	echo "::   - bf2_bridge2_mac0"
	echo "::   - bf2_bridge2_mac1"
	echo "::   - bf2_bridge2_mac2"
	echo "::   - bf2_net_ip"
	echo "::   - bf2_client_ip1"
	echo "::   - bf2_server_ip1"
	echo "::   - bf2_bridge1_ip0"
	echo "::   - bf2_bridge2_ip0"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
}
topo_bf2_init()
{
	topo_env_init bf2

	export bf2_client_if1=$(topo_bf2_ifaces client | awk '{print $1}')
	export bf2_server_if1=$(topo_bf2_ifaces server | awk '{print $1}')
	export bf2_bridge1_if0=$(topo_bf2_ifaces bridge1 | awk '{print $1}')
	export bf2_bridge1_if1=$(topo_bf2_ifaces bridge1 | awk '{print $2}')
	export bf2_bridge1_if2=$(topo_bf2_ifaces bridge1 | awk '{print $3}')
	export bf2_bridge2_if0=$(topo_bf2_ifaces bridge2 | awk '{print $1}')
	export bf2_bridge2_if1=$(topo_bf2_ifaces bridge2 | awk '{print $2}')
	export bf2_bridge2_if2=$(topo_bf2_ifaces bridge2 | awk '{print $3}')

	export bf2_client_mac1=`run client ip a s dev $bf2_client_if1 | grep ether | awk '{print $2}'`
	export bf2_server_mac1=`run server ip a s dev $bf2_server_if1 | grep ether | awk '{print $2}'`
	export bf2_bridge1_mac0=`run bridge1 ip a s dev $bf2_bridge1_if0 | grep ether | awk '{print $2}'`
	export bf2_bridge1_mac1=`run bridge1 ip a s dev $bf2_bridge1_if1 | grep ether | awk '{print $2}'`
	export bf2_bridge1_mac2=`run bridge1 ip a s dev $bf2_bridge1_if2 | grep ether | awk '{print $2}'`
	export bf2_bridge2_mac0=`run bridge2 ip a s dev $bf2_bridge2_if0 | grep ether | awk '{print $2}'`
	export bf2_bridge2_mac1=`run bridge2 ip a s dev $bf2_bridge2_if1 | grep ether | awk '{print $2}'`
	export bf2_bridge2_mac2=`run bridge2 ip a s dev $bf2_bridge2_if2 | grep ether | awk '{print $2}'`

	export bf2_client_bif=`run client ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export bf2_server_bif=`run server ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export bf2_bridge1_bif=`run bridge1 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export bf2_bridge2_bif=`run bridge2 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
}
topo_bf2_ipv4()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export bf2_net_ip=$(topo_generate_nwaddr bf2 net ip)
	export bf2_client_ip1=${bf2_net_ip%0}6
	export bf2_server_ip1=${bf2_net_ip%0}1
	export bf2_bridge1_ip0=${bf2_net_ip%0}254
	export bf2_bridge2_ip0=${bf2_net_ip%0}253

	run client ip addr add $bf2_client_ip1/24 dev $bf2_client_if1
	run server ip addr add $bf2_server_ip1/24 dev $bf2_server_if1
	run bridge1 ip addr add $bf2_bridge1_ip0/24 dev $bf2_bridge1_if0
	run bridge2 ip addr add $bf2_bridge2_ip0/24 dev $bf2_bridge2_if0
	run client ip link set lo up
	run server ip link set lo up
	run bridge1 ip link set lo up
	run bridge2 ip link set lo up
}
topo_bf2_ipv6()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export bf2_net_ip=$(topo_generate_nwaddr bf2 net ip6)
	export bf2_client_ip1=${bf2_net_ip%0}6
	export bf2_server_ip1=${bf2_net_ip%0}1
	export bf2_bridge1_ip0=${bf2_net_ip%0}fffe
	export bf2_bridge2_ip0=${bf2_net_ip%0}fffd

	run client ip addr add $bf2_client_ip1/64 dev $bf2_client_if1
	run server ip addr add $bf2_server_ip1/64 dev $bf2_server_if1
	run bridge1 ip addr add $bf2_bridge1_ip0/64 dev $bf2_bridge1_if0
	run bridge2 ip addr add $bf2_bridge2_ip0/64 dev $bf2_bridge2_if0
	run client ip link set lo up
	run server ip link set lo up
	run bridge1 ip link set lo up
	run bridge2 ip link set lo up
}
topo_bf2_ipv4_vxlan()
{
	[ -z "$1" ] && { local id=100; } || { local id=$1; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 VXLAN settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export bf2_vxnet_ip=$(topo_generate_nwaddr bf2 vxnet ip)
	export bf2_bridge1_ip2=${bf2_vxnet_ip%0}2
	export bf2_bridge2_ip2=${bf2_vxnet_ip%0}1

	run bridge1 ip addr add $bf2_bridge1_ip2/24 dev $bf2_bridge1_if2
	run bridge2 ip addr add $bf2_bridge2_ip2/24 dev $bf2_bridge2_if2

	export bf2_bridge1_vxif=vxlan0
	export bf2_bridge2_vxif=vxlan0

	run bridge1 ip link set $bf2_bridge1_if2 nomaster
	run bridge2 ip link set $bf2_bridge2_if2 nomaster

	run bridge1 ip link add $bf2_bridge1_vxif type vxlan id $id remote $bf2_bridge2_ip2 dstport 4789 dev $bf2_bridge1_if2
	run bridge2 ip link add $bf2_bridge2_vxif type vxlan id $id remote $bf2_bridge1_ip2 dstport 4789 dev $bf2_bridge2_if2
	run bridge1 ip link set $bf2_bridge1_vxif up
	run bridge2 ip link set $bf2_bridge2_vxif up
	run bridge1 network_set_offload $bf2_bridge1_vxif $MH_OFFLOADS
	run bridge2 network_set_offload $bf2_bridge2_vxif $MH_OFFLOADS

	run bridge1 ip link set $bf2_bridge1_vxif master $bf2_bridge1_if0
	run bridge2 ip link set $bf2_bridge2_vxif master $bf2_bridge2_if0
}
topo_bf2_ipv6_vxlan()
{
	[ -z "$1" ] && { local id=100; } || { local id=$1; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 VXLAN settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export bf2_vxnet_ip=$(topo_generate_nwaddr bf2 vxnet ip6)
	export bf2_bridge1_ip2=${bf2_vxnet_ip%0}2
	export bf2_bridge2_ip2=${bf2_vxnet_ip%0}1

	run bridge1 ip addr add $bf2_bridge1_ip2/64 dev $bf2_bridge1_if2
	run bridge2 ip addr add $bf2_bridge2_ip2/64 dev $bf2_bridge2_if2

	export bf2_bridge1_vxif=vxlan0
	export bf2_bridge2_vxif=vxlan0

	run bridge1 ip link set $bf2_bridge1_if2 nomaster
	run bridge2 ip link set $bf2_bridge2_if2 nomaster

	run bridge1 ip link add $bf2_bridge1_vxif type vxlan id $id remote $bf2_bridge2_ip2 dstport 4789 dev $bf2_bridge1_if2
	run bridge2 ip link add $bf2_bridge2_vxif type vxlan id $id remote $bf2_bridge1_ip2 dstport 4789 dev $bf2_bridge2_if2
	run bridge1 ip link set $bf2_bridge1_vxif up
	run bridge2 ip link set $bf2_bridge2_vxif up
	run bridge1 network_set_offload $bf2_bridge1_vxif $MH_OFFLOADS
	run bridge2 network_set_offload $bf2_bridge2_vxif $MH_OFFLOADS

	run bridge1 ip link set $bf2_bridge1_vxif master $bf2_bridge1_if0
	run bridge2 ip link set $bf2_bridge2_vxif master $bf2_bridge2_if0
}
topo_bf2_check()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: BF2 checking"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_env_check bf2
	run bridge1 ip link show master $bf2_bridge1_if0
	run bridge2 ip link show master $bf2_bridge2_if0

	local result=0
	if [ $bf2_bridge1_ip2 ] && [ $bf2_bridge2_ip2 ]; then
		run bridge1 ping_pass -I $bf2_bridge1_if2 $bf2_bridge2_ip2 -c 3 || { result=1; }
		run bridge2 ping_pass -I $bf2_bridge2_if2 $bf2_bridge1_ip2 -c 3 || { result=1; }
	fi
	run client ping_pass -I $bf2_client_if1 $bf2_server_ip1 -c 3 || { result=1; }
	run server ping_pass -I $bf2_server_if1 $bf2_client_ip1 -c 3 || { result=1; }
	return $result
}

###########################################################
# Topo: Route Forward #2
###########################################################
# external APIs
topo_rf2_help()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::   |-------------------------------------|"
	echo "::   | Client---Router1---Router2---Server |"
	echo "::   |-------------------------------------|"
	echo ":: - Functions predefined"
	echo "::   - topo_rf2_init"
	echo "::   - topo_rf2_ipv4"
	echo "::   - topo_rf2_ipv6"
	echo "::   - topo_rf2_check [ipv4|ipv6]"
	echo "::   - run [client|router1|router2|server] [cmd]"
	echo ":: - Variables predefined"
	echo "::   - rf2_client_bif"
	echo "::   - rf2_server_bif"
	echo "::   - rf2_router1_bif"
	echo "::   - rf2_router2_bif"
	echo "::   - rf2_client_if1"
	echo "::   - rf2_server_if1"
	echo "::   - rf2_router1_if1"
	echo "::   - rf2_router1_if2"
	echo "::   - rf2_router2_if1"
	echo "::   - rf2_router2_if2"
	echo "::   - rf2_client_mac1"
	echo "::   - rf2_server_mac1"
	echo "::   - rf2_router1_mac1"
	echo "::   - rf2_router1_mac2"
	echo "::   - rf2_router2_mac1"
	echo "::   - rf2_router2_mac2"
	echo "::   - rf2_cnet_ip"
	echo "::   - rf2_rnet_ip"
	echo "::   - rf2_snet_ip"
	echo "::   - rf2_client_ip1"
	echo "::   - rf2_server_ip1"
	echo "::   - rf2_router1_ip1"
	echo "::   - rf2_router1_ip2"
	echo "::   - rf2_router2_ip1"
	echo "::   - rf2_router2_ip2"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
}
topo_rf2_init()
{
	topo_env_init rf2

	export rf2_client_if1=$(topo_rf2_ifaces client | awk '{print $1}')
	export rf2_server_if1=$(topo_rf2_ifaces server | awk '{print $1}')
	export rf2_router1_if1=$(topo_rf2_ifaces router1 | awk '{print $1}')
	export rf2_router1_if2=$(topo_rf2_ifaces router1 | awk '{print $2}')
	export rf2_router2_if1=$(topo_rf2_ifaces router2 | awk '{print $1}')
	export rf2_router2_if2=$(topo_rf2_ifaces router2 | awk '{print $2}')

	export rf2_client_mac1=`run client ip a s dev $rf2_client_if1 | grep ether | awk '{print $2}'`
	export rf2_server_mac1=`run server ip a s dev $rf2_server_if1 | grep ether | awk '{print $2}'`
	export rf2_router1_mac1=`run router1 ip a s dev $rf2_router1_if1 | grep ether | awk '{print $2}'`
	export rf2_router1_mac2=`run router1 ip a s dev $rf2_router1_if2 | grep ether | awk '{print $2}'`
	export rf2_router2_mac1=`run router2 ip a s dev $rf2_router2_if1 | grep ether | awk '{print $2}'`
	export rf2_router2_mac2=`run router2 ip a s dev $rf2_router2_if2 | grep ether | awk '{print $2}'`

	export rf2_client_bif=`run client ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export rf2_server_bif=`run server ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export rf2_router1_bif=`run router1 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export rf2_router2_bif=`run ruoter2 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
}
topo_rf2_ipv4()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export rf2_cnet_ip=$(topo_generate_nwaddr rf2 cnet ip)
	export rf2_rnet_ip=$(topo_generate_nwaddr rf2 rnet ip)
	export rf2_snet_ip=$(topo_generate_nwaddr rf2 snet ip)

	export rf2_client_ip1=${rf2_cnet_ip%0}2
	export rf2_server_ip1=${rf2_snet_ip%0}1
	export rf2_router1_ip1=${rf2_cnet_ip%0}1
	export rf2_router1_ip2=${rf2_rnet_ip%0}2
	export rf2_router2_ip2=${rf2_rnet_ip%0}1
	export rf2_router2_ip1=${rf2_snet_ip%0}2

	run client ip addr add $rf2_client_ip1/24 dev $rf2_client_if1
	run server ip addr add $rf2_server_ip1/24 dev $rf2_server_if1
	run router1 ip addr add $rf2_router1_ip1/24 dev $rf2_router1_if1
	run router1 ip addr add $rf2_router1_ip2/24 dev $rf2_router1_if2
	run router2 ip addr add $rf2_router2_ip1/24 dev $rf2_router2_if1
	run router2 ip addr add $rf2_router2_ip2/24 dev $rf2_router2_if2
	run client ip link set lo up
	run server ip link set lo up
	run router1 ip link set lo up
	run router2 ip link set lo up

	run router1 sysctl -w net.ipv4.ip_forward=1
	run router2 sysctl -w net.ipv4.ip_forward=1
	run client ip route add ${rf2_rnet_ip}/24 via ${rf2_router1_ip1} dev $rf2_client_if1
	run client ip route add ${rf2_snet_ip}/24 via ${rf2_router1_ip1} dev $rf2_client_if1
	run server ip route add ${rf2_rnet_ip}/24 via ${rf2_router2_ip1} dev $rf2_server_if1
	run server ip route add ${rf2_cnet_ip}/24 via ${rf2_router2_ip1} dev $rf2_server_if1
	run router1 ip route add ${rf2_snet_ip}/24 via ${rf2_router2_ip2} dev $rf2_router1_if2
	run router2 ip route add ${rf2_cnet_ip}/24 via ${rf2_router1_ip2} dev $rf2_router2_if2
}
topo_rf2_ipv6()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export rf2_cnet_ip=$(topo_generate_nwaddr rf2 cnet ip6)
	export rf2_rnet_ip=$(topo_generate_nwaddr rf2 rnet ip6)
	export rf2_snet_ip=$(topo_generate_nwaddr rf2 snet ip6)

	export rf2_client_ip1=${rf2_cnet_ip%0}2
	export rf2_server_ip1=${rf2_snet_ip%0}1
	export rf2_router1_ip1=${rf2_cnet_ip%0}1
	export rf2_router1_ip2=${rf2_rnet_ip%0}2
	export rf2_router2_ip2=${rf2_rnet_ip%0}1
	export rf2_router2_ip1=${rf2_snet_ip%0}2

	run client ip addr add $rf2_client_ip1/64 dev $rf2_client_if1
	run server ip addr add $rf2_server_ip1/64 dev $rf2_server_if1
	run router1 ip addr add $rf2_router1_ip1/64 dev $rf2_router1_if1
	run router1 ip addr add $rf2_router1_ip2/64 dev $rf2_router1_if2
	run router2 ip addr add $rf2_router2_ip1/64 dev $rf2_router2_if1
	run router2 ip addr add $rf2_router2_ip2/64 dev $rf2_router2_if2
	run client ip link set lo up
	run server ip link set lo up
	run router1 ip link set lo up
	run router2 ip link set lo up

	run router1 sysctl -w net.ipv6.conf.all.forwarding=1
	run router2 sysctl -w net.ipv6.conf.all.forwarding=1
	run client ip route add ${rf2_rnet_ip}/64 via ${rf2_router1_ip1} dev $rf2_client_if1
	run client ip route add ${rf2_snet_ip}/64 via ${rf2_router1_ip1} dev $rf2_client_if1
	run server ip route add ${rf2_rnet_ip}/64 via ${rf2_router2_ip1} dev $rf2_server_if1
	run server ip route add ${rf2_cnet_ip}/64 via ${rf2_router2_ip1} dev $rf2_server_if1
	run router1 ip route add ${rf2_snet_ip}/64 via ${rf2_router2_ip2} dev $rf2_router1_if2
	run router2 ip route add ${rf2_cnet_ip}/64 via ${rf2_router1_ip2} dev $rf2_router2_if2
}
topo_rf2_check()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: RF2 checking"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_env_check rf2

	local result=0
	run router1 ping_pass -I $rf2_router1_if2 $rf2_router2_ip2 -c 3 || { result=1; }
	run router2 ping_pass -I $rf2_router2_if2 $rf2_router1_ip2 -c 3 || { result=1; }
	run client ping_pass -I $rf2_client_if1 $rf2_server_ip1 -c 3 || { result=1; }
	run server ping_pass -I $rf2_server_if1 $rf2_client_ip1 -c 3 || { result=1; }
	return $result
}

###########################################################
# Topo: Load Balance
###########################################################
# external APIs
topo_lb_help()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::   |----------------------------------|"
	echo "::   | Client1--|            |--Server1 |"
	echo "::   |          |            |          |"
	echo "::   |          |--Balancer--|          |"
	echo "::   |          |            |          |"
	echo "::   | Client2--|            |--Server2 |"
	echo "::   |----------------------------------|"
	echo ":: - Functions predefined"
	echo "::   - topo_lb_init"
	echo "::   - topo_lb_ipv4"
	echo "::   - topo_lb_ipv6"
	echo "::   - topo_lb_check [ipv4|ipv6]"
	echo "::   - run [client1|client2|balancer|server1|server2] [cmd]"
	echo ":: - Variables predefined"
	echo "::   - lb_client1_bif"
	echo "::   - lb_client2_bif"
	echo "::   - lb_server1_bif"
	echo "::   - lb_server2_bif"
	echo "::   - lb_balancer_bif"
	echo "::   - lb_client1_if1"
	echo "::   - lb_client2_if1"
	echo "::   - lb_server1_if1"
	echo "::   - lb_server2_if1"
	echo "::   - lb_balancer_if1"
	echo "::   - lb_balancer_if2"
	echo "::   - lb_client1_mac1"
	echo "::   - lb_client2_mac1"
	echo "::   - lb_server1_mac1"
	echo "::   - lb_server2_mac1"
	echo "::   - lb_balancer_mac1"
	echo "::   - lb_balancer_mac2"
	echo "::   - lb_cnet_ip"
	echo "::   - lb_snet_ip"
	echo "::   - lb_client1_ip1"
	echo "::   - lb_client2_ip1"
	echo "::   - lb_server1_ip1"
	echo "::   - lb_server2_ip1"
	echo "::   - lb_balancer_ip1"
	echo "::   - lb_balancer_ip2"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
}
topo_lb_init()
{
	topo_env_init lb

	export lb_client1_if1=$(topo_lb_ifaces client1 | awk '{print $1}')
	export lb_client2_if1=$(topo_lb_ifaces client2 | awk '{print $1}')
	export lb_server1_if1=$(topo_lb_ifaces server1 | awk '{print $1}')
	export lb_server2_if1=$(topo_lb_ifaces server2 | awk '{print $1}')
	export lb_balancer_if1=$(topo_lb_ifaces balancer | awk '{print $1}')
	export lb_balancer_if2=$(topo_lb_ifaces balancer | awk '{print $2}')

	export lb_client1_mac1=`run client1 ip a s dev $lb_client1_if1 | grep ether | awk '{print $2}'`
	export lb_client2_mac1=`run client2 ip a s dev $lb_client2_if1 | grep ether | awk '{print $2}'`
	export lb_server1_mac1=`run server1 ip a s dev $lb_server1_if1 | grep ether | awk '{print $2}'`
	export lb_server2_mac1=`run server2 ip a s dev $lb_server2_if1 | grep ether | awk '{print $2}'`
	export lb_balancer_mac1=`run balancer ip a s dev $lb_balancer_if1 | grep ether | awk '{print $2}'`
	export lb_balancer_mac2=`run balancer ip a s dev $lb_balancer_if2 | grep ether | awk '{print $2}'`

	export lb_client1_bif=`run client1 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export lb_client2_bif=`run client2 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export lb_server1_bif=`run server1 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export lb_server2_bif=`run server2 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export lb_balancer_bif=`ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
}
topo_lb_ipv4()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	local lb_lnet_ip=$(topo_generate_nwaddr lb lnet ip6lnk)
	local lb_client1_lip1=${lb_lnet_ip%0}3
	local lb_client2_lip1=${lb_lnet_ip%0}4
	local lb_server1_lip1=${lb_lnet_ip%0}1
	local lb_server2_lip1=${lb_lnet_ip%0}2
	local lb_balancer_lip1=${lb_lnet_ip%0}fffe
	local lb_balancer_lip2=${lb_lnet_ip%0}fffd

	run client1 ip addr show dev $lb_client1_if1 | grep -q 'scope link' || run client1 ip addr add $lb_client1_lip1/64 dev $lb_client1_if1 scope link
	run client2 ip addr show dev $lb_client2_if1 | grep -q 'scope link' || run client2 ip addr add $lb_client2_lip1/64 dev $lb_client2_if1 scope link
	run server1 ip addr show dev $lb_server1_if1 | grep -q 'scope link' || run server1 ip addr add $lb_server1_lip1/64 dev $lb_server1_if1 scope link
	run server2 ip addr show dev $lb_server2_if1 | grep -q 'scope link' || run server2 ip addr add $lb_server2_lip1/64 dev $lb_server2_if1 scope link
	run balancer ip addr show dev $lb_balancer_if1 | grep -q 'scope link' || run balancer ip addr add $lb_balancer_lip1/64 dev $lb_balancer_if1 scope link
	run balancer ip addr show dev $lb_balancer_if2 | grep -q 'scope link' || run balancer ip addr add $lb_balancer_lip2/64 dev $lb_balancer_if2 scope link

	export lb_cnet_ip=$(topo_generate_nwaddr lb cnet ip)
	export lb_snet_ip=$(topo_generate_nwaddr lb snet ip)

	export lb_client1_ip1=${lb_cnet_ip%0}3
	export lb_client2_ip1=${lb_cnet_ip%0}4
	export lb_server1_ip1=${lb_snet_ip%0}1
	export lb_server2_ip1=${lb_snet_ip%0}2
	export lb_balancer_ip1=${lb_cnet_ip%0}254
	export lb_balancer_ip2=${lb_snet_ip%0}254

	run client1 ip addr add $lb_client1_ip1/24 dev $lb_client1_if1
	run client2 ip addr add $lb_client2_ip1/24 dev $lb_client2_if1
	run server1 ip addr add $lb_server1_ip1/24 dev $lb_server1_if1
	run server2 ip addr add $lb_server2_ip1/24 dev $lb_server2_if1
	run balancer ip addr add $lb_balancer_ip1/24 dev $lb_balancer_if1
	run balancer ip addr add $lb_balancer_ip2/24 dev $lb_balancer_if2

	run client1 ip link set lo up
	run client2 ip link set lo up
	run server1 ip link set lo up
	run server2 ip link set lo up
	run balancer ip link set lo up

	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 masquerade settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	run balancer sysctl -w net.ipv4.ip_forward=1
	run client1 ip route add ${lb_snet_ip}/24 via ${lb_balancer_ip1} dev $lb_client1_if1
	run client2 ip route add ${lb_snet_ip}/24 via ${lb_balancer_ip1} dev $lb_client2_if1
	run server1 ip route add ${lb_cnet_ip}/24 via ${lb_balancer_ip2} dev $lb_server1_if1
	run server2 ip route add ${lb_cnet_ip}/24 via ${lb_balancer_ip2} dev $lb_server2_if1
}
topo_lb_ipv6()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	local lb_lnet_ip=$(topo_generate_nwaddr lb lnet ip6lnk)
	local lb_client1_lip1=${lb_lnet_ip%0}3
	local lb_client2_lip1=${lb_lnet_ip%0}4
	local lb_server1_lip1=${lb_lnet_ip%0}1
	local lb_server2_lip1=${lb_lnet_ip%0}2
	local lb_balancer_lip1=${lb_lnet_ip%0}fffe
	local lb_balancer_lip2=${lb_lnet_ip%0}fffd

	run client1 ip addr show dev $lb_client1_if1 | grep -q 'scope link' || run client1 ip addr add $lb_client1_lip1/64 dev $lb_client1_if1 scope link
	run client2 ip addr show dev $lb_client2_if1 | grep -q 'scope link' || run client2 ip addr add $lb_client2_lip1/64 dev $lb_client2_if1 scope link
	run server1 ip addr show dev $lb_server1_if1 | grep -q 'scope link' || run server1 ip addr add $lb_server1_lip1/64 dev $lb_server1_if1 scope link
	run server2 ip addr show dev $lb_server2_if1 | grep -q 'scope link' || run server2 ip addr add $lb_server2_lip1/64 dev $lb_server2_if1 scope link
	run balancer ip addr show dev $lb_balancer_if1 | grep -q 'scope link' || run balancer ip addr add $lb_balancer_lip1/64 dev $lb_balancer_if1 scope link
	run balancer ip addr show dev $lb_balancer_if2 | grep -q 'scope link' || run balancer ip addr add $lb_balancer_lip2/64 dev $lb_balancer_if2 scope link

	export lb_cnet_ip=$(topo_generate_nwaddr lb cnet ip6)
	export lb_snet_ip=$(topo_generate_nwaddr lb snet ip6)

	export lb_client1_ip1=${lb_cnet_ip%0}3
	export lb_client2_ip1=${lb_cnet_ip%0}4
	export lb_server1_ip1=${lb_snet_ip%0}1
	export lb_server2_ip1=${lb_snet_ip%0}2
	export lb_balancer_ip1=${lb_cnet_ip%0}fffe
	export lb_balancer_ip2=${lb_snet_ip%0}fffe

	run client1 ip addr add $lb_client1_ip1/64 dev $lb_client1_if1
	run client2 ip addr add $lb_client2_ip1/64 dev $lb_client2_if1
	run server1 ip addr add $lb_server1_ip1/64 dev $lb_server1_if1
	run server2 ip addr add $lb_server2_ip1/64 dev $lb_server2_if1
	run balancer ip addr add $lb_balancer_ip1/64 dev $lb_balancer_if1
	run balancer ip addr add $lb_balancer_ip2/64 dev $lb_balancer_if2

	run client1 ip link set lo up
	run client2 ip link set lo up
	run server1 ip link set lo up
	run server2 ip link set lo up
	run balancer ip link set lo up

	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 masquerade settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	run balancer sysctl -w net.ipv6.conf.all.forwarding=1
	run client1 ip route add ${lb_snet_ip}/64 via ${lb_balancer_ip1} dev $lb_client1_if1
	run client2 ip route add ${lb_snet_ip}/64 via ${lb_balancer_ip1} dev $lb_client2_if1
	run server1 ip route add ${lb_cnet_ip}/64 via ${lb_balancer_ip2} dev $lb_server1_if1
	run server2 ip route add ${lb_cnet_ip}/64 via ${lb_balancer_ip2} dev $lb_server2_if1
}
topo_lb_check()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: LB checking"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_env_check lb

	local result=0
	run client1 ping_pass -I $lb_client1_if1 $lb_server1_ip1 -c 3 || { result=1; }
	run client1 ping_pass -I $lb_client1_if1 $lb_server2_ip1 -c 3 || { result=1; }
	run client2 ping_pass -I $lb_client2_if1 $lb_server1_ip1 -c 3 || { result=1; }
	run client2 ping_pass -I $lb_client2_if1 $lb_server2_ip1 -c 3 || { result=1; }
	return $result
}

###########################################################
# Topo: Load Balance #2
###########################################################
# external APIs
topo_lb2_help()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::   |---------------------------------------|"
	echo "::   | Client1   Client2   Server1   Server2 |"
	echo "::   |    |         |         |         |    |"
	echo "::   |    -------------------------------    |"
	echo "::   |                   |                   |"
	echo "::   |                Balancer               |"
	echo "::   |---------------------------------------|"
	echo ":: - Functions predefined"
	echo "::   - topo_lb2_init"
	echo "::   - topo_lb2_ipv4"
	echo "::   - topo_lb2_ipv6"
	echo "::   - topo_lb2_check [ipv4|ipv6]"
	echo "::   - run [client1|client2|balancer|server1|server2] [cmd]"
	echo ":: - Variables predefined"
	echo "::   - lb2_client1_bif"
	echo "::   - lb2_client2_bif"
	echo "::   - lb2_server1_bif"
	echo "::   - lb2_server2_bif"
	echo "::   - lb2_balancer_bif"
	echo "::   - lb2_client1_if1"
	echo "::   - lb2_client2_if1"
	echo "::   - lb2_server1_if1"
	echo "::   - lb2_server2_if1"
	echo "::   - lb2_balancer_if1"
	echo "::   - lb2_client1_mac1"
	echo "::   - lb2_client2_mac1"
	echo "::   - lb2_server1_mac1"
	echo "::   - lb2_server2_mac1"
	echo "::   - lb2_balancer_mac1"
	echo "::   - lb2_net_ip"
	echo "::   - lb2_client1_ip1"
	echo "::   - lb2_client2_ip1"
	echo "::   - lb2_server1_ip1"
	echo "::   - lb2_server2_ip1"
	echo "::   - lb2_balancer_ip1"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
}
topo_lb2_init()
{
	topo_env_init lb2

	export lb2_client1_if1=$(topo_lb2_ifaces client1 | awk '{print $1}')
	export lb2_client2_if1=$(topo_lb2_ifaces client2 | awk '{print $1}')
	export lb2_server1_if1=$(topo_lb2_ifaces server1 | awk '{print $1}')
	export lb2_server2_if1=$(topo_lb2_ifaces server2 | awk '{print $1}')
	export lb2_balancer_if1=$(topo_lb2_ifaces balancer | awk '{print $1}')

	export lb2_client1_mac1=`run client1 ip a s dev $lb2_client1_if1 | grep ether | awk '{print $2}'`
	export lb2_client2_mac1=`run client2 ip a s dev $lb2_client2_if1 | grep ether | awk '{print $2}'`
	export lb2_server1_mac1=`run server1 ip a s dev $lb2_server1_if1 | grep ether | awk '{print $2}'`
	export lb2_server2_mac1=`run server2 ip a s dev $lb2_server2_if1 | grep ether | awk '{print $2}'`
	export lb2_balancer_mac1=`run balancer ip a s dev $lb2_balancer_if1 | grep ether | awk '{print $2}'`

	export lb2_client1_bif=`run client1 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export lb2_client2_bif=`run client2 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export lb2_server1_bif=`run server1 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export lb2_server2_bif=`run server2 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export lb2_balancer_bif=`ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
}
topo_lb2_ipv4()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	local lb2_lnet_ip=$(topo_generate_nwaddr lb2 lnet ip6lnk)
	local lb2_client1_lip1=${lb2_lnet_ip%0}3
	local lb2_client2_lip1=${lb2_lnet_ip%0}4
	local lb2_server1_lip1=${lb2_lnet_ip%0}1
	local lb2_server2_lip1=${lb2_lnet_ip%0}2
	local lb2_balancer_lip1=${lb2_lnet_ip%0}5

	run client1 ip addr show dev $lb2_client1_if1 | grep -q 'scope link' || run client1 ip addr add $lb2_client1_lip1/64 dev $lb2_client1_if1
	run client2 ip addr show dev $lb2_client2_if1 | grep -q 'scope link' || run client2 ip addr add $lb2_client2_lip1/64 dev $lb2_client2_if1
	run server1 ip addr show dev $lb2_server1_if1 | grep -q 'scope link' || run server1 ip addr add $lb2_server1_lip1/64 dev $lb2_server1_if1
	run server2 ip addr show dev $lb2_server2_if1 | grep -q 'scope link' || run server2 ip addr add $lb2_server2_lip1/64 dev $lb2_server2_if1
	run balancer ip addr show dev $lb2_balancer_if1 | grep -q 'scope link' || run balancer ip addr add $lb2_balancer_lip1/64 dev $lb2_balancer_if1

	export lb2_net_ip=$(topo_generate_nwaddr lb2 net ip)
	export lb2_client1_ip1=${lb2_net_ip%0}3
	export lb2_client2_ip1=${lb2_net_ip%0}4
	export lb2_server1_ip1=${lb2_net_ip%0}1
	export lb2_server2_ip1=${lb2_net_ip%0}2
	export lb2_balancer_ip0=${lb2_net_ip%0}254
	export lb2_balancer_ip1=${lb2_net_ip%0}5

	run client1 ip addr add $lb2_client1_ip1/24 dev $lb2_client1_if1
	run client2 ip addr add $lb2_client2_ip1/24 dev $lb2_client2_if1
	run server1 ip addr add $lb2_server1_ip1/24 dev $lb2_server1_if1
	run server2 ip addr add $lb2_server2_ip1/24 dev $lb2_server2_if1
	run balancer ip addr add $lb2_balancer_ip1/24 dev $lb2_balancer_if1

	run client1 ip link set lo up
	run client2 ip link set lo up
	run server1 ip link set lo up
	run server2 ip link set lo up
	run balancer ip link set lo up
}
topo_lb2_ipv4_gateway()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 gateway settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	run server1 ip addr add $lb2_balancer_ip0/32 dev lo:0
	run server2 ip addr add $lb2_balancer_ip0/32 dev lo:0
	run balancer ip addr add $lb2_balancer_ip0/24 dev $lb2_balancer_if1:0

	run server1 sysctl -w net.ipv4.conf.all.arp_ignore=1
	run server2 sysctl -w net.ipv4.conf.all.arp_ignore=1
	run server1 sysctl -w net.ipv4.conf.all.arp_announce=2
	run server2 sysctl -w net.ipv4.conf.all.arp_announce=2
}
topo_lb2_ipv6()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	local lb2_lnet_ip=$(topo_generate_nwaddr lb2 lnet ip6lnk)
	local lb2_client1_lip1=${lb2_lnet_ip%0}3
	local lb2_client2_lip1=${lb2_lnet_ip%0}4
	local lb2_server1_lip1=${lb2_lnet_ip%0}1
	local lb2_server2_lip1=${lb2_lnet_ip%0}2
	local lb2_balancer_lip1=${lb2_lnet_ip%0}5

	run client1 ip addr show dev $lb2_client1_if1 | grep -q 'scope link' || run client1 ip addr add $lb2_client1_lip1/64 dev $lb2_client1_if1
	run client2 ip addr show dev $lb2_client2_if1 | grep -q 'scope link' || run client2 ip addr add $lb2_client2_lip1/64 dev $lb2_client2_if1
	run server1 ip addr show dev $lb2_server1_if1 | grep -q 'scope link' || run server1 ip addr add $lb2_server1_lip1/64 dev $lb2_server1_if1
	run server2 ip addr show dev $lb2_server2_if1 | grep -q 'scope link' || run server2 ip addr add $lb2_server2_lip1/64 dev $lb2_server2_if1
	run balancer ip addr show dev $lb2_balancer_if1 | grep -q 'scope link' || run balancer ip addr add $lb2_balancer_lip1/64 dev $lb2_balancer_if1

	export lb2_net_ip=$(topo_generate_nwaddr lb2 net ip6)
	export lb2_client1_ip1=${lb2_net_ip%0}3
	export lb2_client2_ip1=${lb2_net_ip%0}4
	export lb2_server1_ip1=${lb2_net_ip%0}1
	export lb2_server2_ip1=${lb2_net_ip%0}2
	export lb2_balancer_ip0=${lb2_net_ip%0}fffe
	export lb2_balancer_ip1=${lb2_net_ip%0}5

	run client1 ip addr add $lb2_client1_ip1/64 dev $lb2_client1_if1
	run client2 ip addr add $lb2_client2_ip1/64 dev $lb2_client2_if1
	run server1 ip addr add $lb2_server1_ip1/64 dev $lb2_server1_if1
	run server2 ip addr add $lb2_server2_ip1/64 dev $lb2_server2_if1
	run balancer ip addr add $lb2_balancer_ip1/64 dev $lb2_balancer_if1

	run client1 ip link set lo up
	run client2 ip link set lo up
	run server1 ip link set lo up
	run server2 ip link set lo up
	run balancer ip link set lo up
}
topo_lb2_ipv6_gateway()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 gateway settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	run server1 ip addr add $lb2_balancer_ip0/128 dev lo:0
	run server2 ip addr add $lb2_balancer_ip0/128 dev lo:0
	run balancer ip addr add $lb2_balancer_ip0/64 dev $lb2_balancer_if1:0

	run server1 sysctl -w net.ipv6.conf.all.accept_dad=0
	run server2 sysctl -w net.ipv6.conf.all.accept_dad=0
}
topo_lb2_check()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: LB2 checking"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_env_check lb2
	run balancer ip link show master $lb2_balancer_if1

	local result=0
	run client1 ping_pass -I $lb2_client1_if1 $lb2_server1_ip1 -c 3 || { result=1; }
	run client1 ping_pass -I $lb2_client1_if1 $lb2_server2_ip1 -c 3 || { result=1; }
	run client2 ping_pass -I $lb2_client2_if1 $lb2_server1_ip1 -c 3 || { result=1; }
	run client2 ping_pass -I $lb2_client2_if1 $lb2_server2_ip1 -c 3 || { result=1; }
	run client1 ping_pass -I $lb2_client1_if1 $lb2_balancer_ip1 -c 3 || { result=1; }
	run client2 ping_pass -I $lb2_client2_if1 $lb2_balancer_ip1 -c 3 || { result=1; }
	run server1 ping_pass -I $lb2_server1_if1 $lb2_balancer_ip1 -c 3 || { result=1; }
	run server2 ping_pass -I $lb2_server2_if1 $lb2_balancer_ip1 -c 3 || { result=1; }
	run client1 ping_pass -I $lb2_client1_if1 $lb2_balancer_ip0 -c 3 || { result=1; }
	run client2 ping_pass -I $lb2_client2_if1 $lb2_balancer_ip0 -c 3 || { result=1; }
	return $result
}

###########################################################
# Topo: Load Balance #3
###########################################################
# external APIs
topo_lb3_help()
{
	:
}
topo_lb3_init()
{
	topo_env_init lb3

	export lb3_client1_if1=$(topo_lb3_ifaces client1 | awk '{print $1}')
	export lb3_client2_if1=$(topo_lb3_ifaces client2 | awk '{print $1}')
	export lb3_server1_if1=$(topo_lb3_ifaces server1 | awk '{print $1}')
	export lb3_server1_if2=$(topo_lb3_ifaces server1 | awk '{print $2}')
	export lb3_server2_if1=$(topo_lb3_ifaces server2 | awk '{print $1}')
	export lb3_server2_if2=$(topo_lb3_ifaces server2 | awk '{print $2}')
	export lb3_balancer_if1=$(topo_lb3_ifaces balancer | awk '{print $1}')
	export lb3_balancer_if2=$(topo_lb3_ifaces balancer | awk '{print $2}')

	export lb3_client1_mac1=`run client1 ip a s dev $lb3_client1_if1 | grep ether | awk '{print $2}'`
	export lb3_client2_mac1=`run client2 ip a s dev $lb3_client2_if1 | grep ether | awk '{print $2}'`
	export lb3_server1_mac1=`run server1 ip a s dev $lb3_server1_if1 | grep ether | awk '{print $2}'`
	export lb3_server1_mac2=`run server1 ip a s dev $lb3_server1_if2 | grep ether | awk '{print $2}'`
	export lb3_server2_mac1=`run server2 ip a s dev $lb3_server2_if1 | grep ether | awk '{print $2}'`
	export lb3_server2_mac2=`run server2 ip a s dev $lb3_server2_if2 | grep ether | awk '{print $2}'`
	export lb3_balancer_mac1=`run balancer ip a s dev $lb3_balancer_if1 | grep ether | awk '{print $2}'`
	export lb3_balancer_mac2=`run balancer ip a s dev $lb3_balancer_if2 | grep ether | awk '{print $2}'`

	export lb3_client1_bif=`run client1 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export lb3_client2_bif=`run client2 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export lb3_server1_bif=`run server1 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export lb3_server2_bif=`run server2 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export lb3_balancer_bif=`ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
}
topo_lb3_ipv4()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	local lb3_lnet_ip=$(topo_generate_nwaddr lb3 lnet ip6lnk)
	local lb3_client1_lip1=${lb3_lnet_ip%0}5
	local lb3_client2_lip1=${lb3_lnet_ip%0}6
	local lb3_server1_lip1=${lb3_lnet_ip%0}3
	local lb3_server1_lip2=${lb3_lnet_ip%0}4
	local lb3_server2_lip1=${lb3_lnet_ip%0}1
	local lb3_server2_lip2=${lb3_lnet_ip%0}2
	local lb3_balancer_lip1=${lb3_lnet_ip%0}fffe
	local lb3_balancer_lip2=${lb3_lnet_ip%0}fffd

	run client1 ip addr show dev $lb3_client1_if1 | grep -q 'scope link' || run client1 ip addr add $lb3_client1_lip1/64 dev $lb3_client1_if1 scope link
	run client2 ip addr show dev $lb3_client2_if1 | grep -q 'scope link' || run client2 ip addr add $lb3_client2_lip1/64 dev $lb3_client2_if1 scope link
	run server1 ip addr show dev $lb3_server1_if1 | grep -q 'scope link' || run server1 ip addr add $lb3_server1_lip1/64 dev $lb3_server1_if1 scope link
	run server1 ip addr show dev $lb3_server1_if2 | grep -q 'scope link' || run server1 ip addr add $lb3_server1_lip2/64 dev $lb3_server1_if2 scope link
	run server2 ip addr show dev $lb3_server2_if1 | grep -q 'scope link' || run server2 ip addr add $lb3_server2_lip1/64 dev $lb3_server2_if1 scope link
	run server2 ip addr show dev $lb3_server2_if2 | grep -q 'scope link' || run server2 ip addr add $lb3_server2_lip2/64 dev $lb3_server2_if2 scope link
	run balancer ip addr show dev $lb3_balancer_if1 | grep -q 'scope link' || run balancer ip addr add $lb3_balancer_lip1/64 dev $lb3_balancer_if1 scope link
	run balancer ip addr show dev $lb3_balancer_if2 | grep -q 'scope link' || run balancer ip addr add $lb3_balancer_lip2/64 dev $lb3_balancer_if2 scope link

	export lb3_onet_ip=$(topo_generate_nwaddr lb3 onet ip)
	export lb3_inet_ip=$(topo_generate_nwaddr lb3 inet ip)

	export lb3_client1_ip1=${lb3_onet_ip%0}3
	export lb3_client2_ip1=${lb3_onet_ip%0}4
	export lb3_server1_ip1=${lb3_onet_ip%0}1
	export lb3_server1_ip2=${lb3_inet_ip%0}1
	export lb3_server2_ip1=${lb3_onet_ip%0}2
	export lb3_server2_ip2=${lb3_inet_ip%0}2
	export lb3_balancer_ip1=${lb3_onet_ip%0}5
	export lb3_balancer_ip2=${lb3_inet_ip%0}5

	run client1 ip addr add $lb3_client1_ip1/24 dev $lb3_client1_if1
	run client2 ip addr add $lb3_client2_ip1/24 dev $lb3_client2_if1
	run server1 ip addr add $lb3_server1_ip1/24 dev $lb3_server1_if1
	run server1 ip addr add $lb3_server1_ip2/24 dev $lb3_server1_if2
	run server2 ip addr add $lb3_server2_ip1/24 dev $lb3_server2_if1
	run server2 ip addr add $lb3_server2_ip2/24 dev $lb3_server2_if2
	run balancer ip addr add $lb3_balancer_ip1/24 dev $lb3_balancer_if1
	run balancer ip addr add $lb3_balancer_ip2/24 dev $lb3_balancer_if2

	run client1 ip link set lo up
	run client2 ip link set lo up
	run server1 ip link set lo up
	run server2 ip link set lo up
	run balancer ip link set lo up
}
topo_lb3_ipv4_ipip()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 IPIP settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export lb3_server1_tif=tunl0
	export lb3_server2_tif=tunl0

	run server1 modprobe ipip
	run server2 modprobe ipip
	run server1 ip link set $lb3_server1_tif up
	run server2 ip link set $lb3_server2_tif up
	run server1 network_set_offload $lb3_server1_tif $MH_OFFLOADS
	run server2 network_set_offload $lb3_server2_tif $MH_OFFLOADS

	run server1 ip addr add $lb3_balancer_ip1/32 dev $lb3_server1_tif
	run server2 ip addr add $lb3_balancer_ip1/32 dev $lb3_server2_tif

	run server1 sysctl -w net.ipv4.ip_forward=1
	run server2 sysctl -w net.ipv4.ip_forward=1

	run server1 sysctl -w net.ipv4.conf.all.arp_ignore=1
	run server2 sysctl -w net.ipv4.conf.all.arp_ignore=1
	run server1 sysctl -w net.ipv4.conf.all.arp_announce=2
	run server2 sysctl -w net.ipv4.conf.all.arp_announce=2
	run server1 sysctl -w net.ipv4.conf.${lb3_server1_tif}.arp_ignore=1
	run server2 sysctl -w net.ipv4.conf.${lb3_server2_tif}.arp_ignore=1
	run server1 sysctl -w net.ipv4.conf.${lb3_server1_tif}.arp_announce=2
	run server2 sysctl -w net.ipv4.conf.${lb3_server2_tif}.arp_announce=2

	run server1 sysctl -w net.ipv4.conf.all.rp_filter=0
	run server2 sysctl -w net.ipv4.conf.all.rp_filter=0
	run server1 sysctl -w net.ipv4.conf.${lb3_server1_tif}.rp_filter=0
	run server2 sysctl -w net.ipv4.conf.${lb3_server2_tif}.rp_filter=0
}
topo_lb3_ipv6()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	local lb3_lnet_ip=$(topo_generate_nwaddr lb3 lnet ip6lnk)
	local lb3_client1_lip1=${lb3_lnet_ip%0}5
	local lb3_client2_lip1=${lb3_lnet_ip%0}6
	local lb3_server1_lip1=${lb3_lnet_ip%0}3
	local lb3_server1_lip2=${lb3_lnet_ip%0}4
	local lb3_server2_lip1=${lb3_lnet_ip%0}1
	local lb3_server2_lip2=${lb3_lnet_ip%0}2
	local lb3_balancer_lip1=${lb3_lnet_ip%0}fffe
	local lb3_balancer_lip2=${lb3_lnet_ip%0}fffd

	run client1 ip addr show dev $lb3_client1_if1 | grep -q 'scope link' || run client1 ip addr add $lb3_client1_lip1/64 dev $lb3_client1_if1 scope link
	run client2 ip addr show dev $lb3_client2_if1 | grep -q 'scope link' || run client2 ip addr add $lb3_client2_lip1/64 dev $lb3_client2_if1 scope link
	run server1 ip addr show dev $lb3_server1_if1 | grep -q 'scope link' || run server1 ip addr add $lb3_server1_lip1/64 dev $lb3_server1_if1 scope link
	run server1 ip addr show dev $lb3_server1_if2 | grep -q 'scope link' || run server1 ip addr add $lb3_server1_lip2/64 dev $lb3_server1_if2 scope link
	run server2 ip addr show dev $lb3_server2_if1 | grep -q 'scope link' || run server2 ip addr add $lb3_server2_lip1/64 dev $lb3_server2_if1 scope link
	run server2 ip addr show dev $lb3_server2_if2 | grep -q 'scope link' || run server2 ip addr add $lb3_server2_lip2/64 dev $lb3_server2_if2 scope link
	run balancer ip addr show dev $lb3_balancer_if1 | grep -q 'scope link' || run balancer ip addr add $lb3_balancer_lip1/64 dev $lb3_balancer_if1 scope link
	run balancer ip addr show dev $lb3_balancer_if2 | grep -q 'scope link' || run balancer ip addr add $lb3_balancer_lip2/64 dev $lb3_balancer_if2 scope link

	export lb3_onet_ip=$(topo_generate_nwaddr lb3 onet ip6)
	export lb3_inet_ip=$(topo_generate_nwaddr lb3 inet ip6)

	export lb3_client1_ip1=${lb3_onet_ip%0}3
	export lb3_client2_ip1=${lb3_onet_ip%0}4
	export lb3_server1_ip1=${lb3_onet_ip%0}1
	export lb3_server1_ip2=${lb3_inet_ip%0}1
	export lb3_server2_ip1=${lb3_onet_ip%0}2
	export lb3_server2_ip2=${lb3_inet_ip%0}2
	export lb3_balancer_ip1=${lb3_onet_ip%0}5
	export lb3_balancer_ip2=${lb3_inet_ip%0}5

	run client1 ip addr add $lb3_client1_ip1/64 dev $lb3_client1_if1
	run client2 ip addr add $lb3_client2_ip1/64 dev $lb3_client2_if1
	run server1 ip addr add $lb3_server1_ip1/64 dev $lb3_server1_if1
	run server1 ip addr add $lb3_server1_ip2/64 dev $lb3_server1_if2
	run server2 ip addr add $lb3_server2_ip1/64 dev $lb3_server2_if1
	run server2 ip addr add $lb3_server2_ip2/64 dev $lb3_server2_if2
	run balancer ip addr add $lb3_balancer_ip1/64 dev $lb3_balancer_if1
	run balancer ip addr add $lb3_balancer_ip2/64 dev $lb3_balancer_if2

	run client1 ip link set lo up
	run client2 ip link set lo up
	run server1 ip link set lo up
	run server2 ip link set lo up
	run balancer ip link set lo up
}
topo_lb3_ipv6_ipip()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 IPIP settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export lb3_server1_tif=ip6tnl0
	export lb3_server2_tif=ip6tnl0

	run server1 modprobe ip6_tunnel
	run server2 modprobe ip6_tunnel
	run server1 ip link set $lb3_server1_tif up
	run server2 ip link set $lb3_server2_tif up
	run server1 network_set_offload $lb3_server1_tif $MH_OFFLOADS
	run server2 network_set_offload $lb3_server2_tif $MH_OFFLOADS

	run server1 ip addr add $lb3_balancer_ip1/128 dev $lb3_server1_tif
	run server2 ip addr add $lb3_balancer_ip1/128 dev $lb3_server2_tif

	run server1 sysctl -w net.ipv6.conf.all.forwarding=1
	run server2 sysctl -w net.ipv6.conf.all.forwarding=1

	run server1 sysctl -w net.ipv6.conf.all.accept_dad=0
	run server2 sysctl -w net.ipv6.conf.all.accept_dad=0
	run server1 sysctl -w net.ipv6.conf.${lb3_server1_tif}.accept_dad=0
	run server2 sysctl -w net.ipv6.conf.${lb3_server2_tif}.accept_dad=0
}
topo_lb3_check()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: LB3 checking"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_env_check lb3

	local result=0
	run client1 ping_pass -I $lb3_client1_if1 $lb3_server1_ip1 -c 3 || { result=1; }
	run client1 ping_pass -I $lb3_client1_if1 $lb3_server2_ip1 -c 3 || { result=1; }
	run client2 ping_pass -I $lb3_client2_if1 $lb3_server1_ip1 -c 3 || { result=1; }
	run client2 ping_pass -I $lb3_client2_if1 $lb3_server2_ip1 -c 3 || { result=1; }
	run client1 ping_pass -I $lb3_client1_if1 $lb3_balancer_ip1 -c 3 || { result=1; }
	run client2 ping_pass -I $lb3_client2_if1 $lb3_balancer_ip1 -c 3 || { result=1; }
	run server1 ping_pass -I $lb3_server1_if2 $lb3_balancer_ip2 -c 3 || { result=1; }
	run server2 ping_pass -I $lb3_server2_if2 $lb3_balancer_ip2 -c 3 || { result=1; }
	return $result
}

###########################################################
# Topo: High Availability
###########################################################
# external APIs
topo_ha_help()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::   |-------------------|"
	echo "::   |      Client       |"
	echo "::   |         |         |"
	echo "::   |   |-----------|   |"
	echo "::   |   |           |   |"
	echo "::   | FW01---------FW02 |"
	echo "::   |   |           |   |"
	echo "::   |   |-----------|   |"
	echo "::   |         |         |"
	echo "::   |      Server       |"
	echo "::   |-------------------|"
	echo ":: - Functions predefined"
	echo "::   - topo_ha_init"
	echo "::   - topo_ha_ipv4"
	echo "::   - topo_ha_ipv6"
	echo "::   - topo_ha_sync [notrack|ftfw|alarm]"
	echo "::   - topo_ha_check [ipv4|ipv6]"
	echo "::   - run [client|fw01|fw02|server] [cmd]"
	echo ":: - Variables predefined"
	echo "::   - ha_client_bif"
	echo "::   - ha_server_bif"
	echo "::   - ha_fw01_bif"
	echo "::   - ha_fw02_bif"
	echo "::   - ha_client_if1"
	echo "::   - ha_server_if1"
	echo "::   - ha_fw01_if1"
	echo "::   - ha_fw01_if2"
	echo "::   - ha_fw01_if3"
	echo "::   - ha_fw02_if1"
	echo "::   - ha_fw02_if2"
	echo "::   - ha_fw02_if3"
	echo "::   - ha_client_mac1"
	echo "::   - ha_server_mac1"
	echo "::   - ha_fw01_mac1"
	echo "::   - ha_fw01_mac2"
	echo "::   - ha_fw01_mac3"
	echo "::   - ha_fw02_mac1"
	echo "::   - ha_fw02_mac2"
	echo "::   - ha_fw02_mac3"
	echo "::   - ha_cnet_ip"
	echo "::   - ha_snet_ip"
	echo "::   - ha_fnet_ip"
	echo "::   - ha_client_ip1"
	echo "::   - ha_server_ip1"
	echo "::   - ha_fw01_ip1"
	echo "::   - ha_fw01_ip2"
	echo "::   - ha_fw01_ip3"
	echo "::   - ha_fw02_ip1"
	echo "::   - ha_fw02_ip2"
	echo "::   - ha_fw02_ip3"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
}
topo_ha_init()
{
	topo_env_init ha

	export ha_client_if1=$(topo_ha_ifaces client | awk '{print $1}')
	export ha_server_if1=$(topo_ha_ifaces server | awk '{print $1}')
	export ha_fw01_if1=$(topo_ha_ifaces fw01 | awk '{print $1}')
	export ha_fw01_if2=$(topo_ha_ifaces fw01 | awk '{print $2}')
	export ha_fw01_if3=$(topo_ha_ifaces fw01 | awk '{print $3}')
	export ha_fw02_if1=$(topo_ha_ifaces fw02 | awk '{print $1}')
	export ha_fw02_if2=$(topo_ha_ifaces fw02 | awk '{print $2}')
	export ha_fw02_if3=$(topo_ha_ifaces fw02 | awk '{print $3}')

	export ha_client_mac1=`run client ip a s dev $ha_client_if1 | grep ether | awk '{print $2}'`
	export ha_server_mac1=`run server ip a s dev $ha_server_if1 | grep ether | awk '{print $2}'`
	export ha_fw01_mac1=`run fw01 ip a s dev $ha_fw01_if1 | grep ether | awk '{print $2}'`
	export ha_fw01_mac2=`run fw01 ip a s dev $ha_fw01_if2 | grep ether | awk '{print $2}'`
	export ha_fw01_mac3=`run fw01 ip a s dev $ha_fw01_if3 | grep ether | awk '{print $2}'`
	export ha_fw02_mac1=`run fw02 ip a s dev $ha_fw02_if1 | grep ether | awk '{print $2}'`
	export ha_fw02_mac2=`run fw02 ip a s dev $ha_fw02_if2 | grep ether | awk '{print $2}'`
	export ha_fw02_mac3=`run fw02 ip a s dev $ha_fw02_if3 | grep ether | awk '{print $2}'`

	export ha_client_bif=`run client ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export ha_server_bif=`run server ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export ha_fw01_bif=`run fw01 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export ha_fw02_bif=`run fw02 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
}
topo_ha_ipv4()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	local ha_lnet_ip=$(topo_generate_nwaddr ha lnet ip6lnk)
	local ha_client_lip1=${ha_lnet_ip%0}6
	local ha_server_lip1=${ha_lnet_ip%0}1
	local ha_fw01_lip1=${ha_lnet_ip%0}4
	local ha_fw02_lip1=${ha_lnet_ip%0}5
	local ha_fw01_lip2=${ha_lnet_ip%0}2
	local ha_fw02_lip2=${ha_lnet_ip%0}3

	run client ip addr show dev $ha_client_if1 | grep -q 'scope link' || run client ip addr add $ha_client_lip1/64 dev $ha_client_if1
	run server ip addr show dev $ha_server_if1 | grep -q 'scope link' || run server ip addr add $ha_server_lip1/64 dev $ha_server_if1
	run fw01 ip addr show dev $ha_fw01_if1 | grep -q 'scope link' || run fw01 ip addr add $ha_fw01_lip1/64 dev $ha_fw01_if1
	run fw01 ip addr show dev $ha_fw01_if2 | grep -q 'scope link' || run fw01 ip addr add $ha_fw01_lip2/64 dev $ha_fw01_if2
	run fw02 ip addr show dev $ha_fw02_if1 | grep -q 'scope link' || run fw02 ip addr add $ha_fw02_lip1/64 dev $ha_fw02_if1
	run fw02 ip addr show dev $ha_fw02_if2 | grep -q 'scope link' || run fw02 ip addr add $ha_fw02_lip2/64 dev $ha_fw02_if2

	export ha_cnet_ip=$(topo_generate_nwaddr ha cnet ip)
	export ha_snet_ip=$(topo_generate_nwaddr ha snet ip)
	export ha_client_ip1=${ha_cnet_ip%0}3
	export ha_server_ip1=${ha_snet_ip%0}3
	export ha_fw01_ip1=${ha_cnet_ip%0}1
	export ha_fw02_ip1=${ha_cnet_ip%0}2
	export ha_fw01_ip2=${ha_snet_ip%0}1
	export ha_fw02_ip2=${ha_snet_ip%0}2
	export ha_fw_cip=${ha_cnet_ip%0}254
	export ha_fw_sip=${ha_snet_ip%0}254

	export ha_fnet_ip=$(topo_generate_nwaddr ha fnet ip)
	export ha_fw01_ip3=${ha_fnet_ip%0}1
	export ha_fw02_ip3=${ha_fnet_ip%0}2

	run client ip addr add $ha_client_ip1/24 dev $ha_client_if1
	run server ip addr add $ha_server_ip1/24 dev $ha_server_if1
	run fw01 ip addr add $ha_fw01_ip1/24 dev $ha_fw01_if1
	run fw01 ip addr add $ha_fw01_ip2/24 dev $ha_fw01_if2
	run fw02 ip addr add $ha_fw02_ip1/24 dev $ha_fw02_if1
	run fw02 ip addr add $ha_fw02_ip2/24 dev $ha_fw02_if2
	run fw01 ip addr add $ha_fw01_ip3/24 dev $ha_fw01_if3
	run fw02 ip addr add $ha_fw02_ip3/24 dev $ha_fw02_if3

	run client ip link set lo up
	run server ip link set lo up
	run fw01 ip link set lo up
	run fw02 ip link set lo up

	run fw01 sysctl -w net.ipv4.ip_forward=1
	run fw02 sysctl -w net.ipv4.ip_forward=1
}
topo_ha_ipv6()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	local ha_lnet_ip=$(topo_generate_nwaddr ha lnet ip6lnk)
	local ha_client_lip1=${ha_lnet_ip%0}6
	local ha_server_lip1=${ha_lnet_ip%0}1
	local ha_fw01_lip1=${ha_lnet_ip%0}4
	local ha_fw02_lip1=${ha_lnet_ip%0}5
	local ha_fw01_lip2=${ha_lnet_ip%0}2
	local ha_fw02_lip2=${ha_lnet_ip%0}3

	run client ip addr show dev $ha_client_if1 | grep -q 'scope link' || run client ip addr add $ha_client_lip1/64 dev $ha_client_if1
	run server ip addr show dev $ha_server_if1 | grep -q 'scope link' || run server ip addr add $ha_server_lip1/64 dev $ha_server_if1
	run fw01 ip addr show dev $ha_fw01_if1 | grep -q 'scope link' || run fw01 ip addr add $ha_fw01_lip1/64 dev $ha_fw01_if1
	run fw01 ip addr show dev $ha_fw01_if2 | grep -q 'scope link' || run fw01 ip addr add $ha_fw01_lip2/64 dev $ha_fw01_if2
	run fw02 ip addr show dev $ha_fw02_if1 | grep -q 'scope link' || run fw02 ip addr add $ha_fw02_lip1/64 dev $ha_fw02_if1
	run fw02 ip addr show dev $ha_fw02_if2 | grep -q 'scope link' || run fw02 ip addr add $ha_fw02_lip2/64 dev $ha_fw02_if2

	export ha_cnet_ip=$(topo_generate_nwaddr ha cnet ip6)
	export ha_snet_ip=$(topo_generate_nwaddr ha snet ip6)
	export ha_client_ip1=${ha_cnet_ip%0}3
	export ha_server_ip1=${ha_snet_ip%0}3
	export ha_fw01_ip1=${ha_cnet_ip%0}1
	export ha_fw02_ip1=${ha_cnet_ip%0}2
	export ha_fw01_ip2=${ha_snet_ip%0}1
	export ha_fw02_ip2=${ha_snet_ip%0}2
	export ha_fw_cip=${ha_cnet_ip%0}fffe
	export ha_fw_sip=${ha_snet_ip%0}fffe

	export ha_fnet_ip=$(topo_generate_nwaddr ha fnet ip)
	export ha_fw01_ip3=${ha_fnet_ip%0}1
	export ha_fw02_ip3=${ha_fnet_ip%0}2

	run client ip addr add $ha_client_ip1/64 dev $ha_client_if1
	run server ip addr add $ha_server_ip1/64 dev $ha_server_if1
	run fw01 ip addr add $ha_fw01_ip1/64 dev $ha_fw01_if1
	run fw01 ip addr add $ha_fw01_ip2/64 dev $ha_fw01_if2
	run fw02 ip addr add $ha_fw02_ip1/64 dev $ha_fw02_if1
	run fw02 ip addr add $ha_fw02_ip2/64 dev $ha_fw02_if2
	run fw01 ip addr add $ha_fw01_ip3/24 dev $ha_fw01_if3
	run fw02 ip addr add $ha_fw02_ip3/24 dev $ha_fw02_if3

	run client ip link set lo up
	run server ip link set lo up
	run fw01 ip link set lo up
	run fw02 ip link set lo up

	run fw01 sysctl -w net.ipv6.conf.all.forwarding=1
	run fw02 sysctl -w net.ipv6.conf.all.forwarding=1
}
topo_ha_sync()
{
	local mode=$1
	[ $2 == "ipv4" ] && { local content="IPv4"; }
	[ $2 == "ipv6" ] && { local content="IPv6"; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: SYNC $mode settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	run fw01 rm -f /etc/conntrackd/primary-backup.sh
	run fw02 rm -f /etc/conntrackd/primary-backup.sh
	run fw01 rm -f /etc/conntrackd/conntrackd.conf
	run fw02 rm -f /etc/conntrackd/conntrackd.conf
	run fw01 rm -f /etc/keepalived/keepalived.conf
	run fw02 rm -f /etc/keepalived/keepalived.conf

	run fw01 "rpm -ql conntrack-tools | grep primary-backup.sh | xargs -I {} cp {} /etc/conntrackd/primary-backup.sh"
	run fw02 "rpm -ql conntrack-tools | grep primary-backup.sh | xargs -I {} cp {} /etc/conntrackd/primary-backup.sh"
	run fw01 chmod +x /etc/conntrackd/primary-backup.sh
	run fw02 chmod +x /etc/conntrackd/primary-backup.sh
	run fw01 "rpm -ql conntrack-tools | grep conntrackd.conf | grep $mode | xargs -I {} cp {} /etc/conntrackd/conntrackd.conf"
	run fw02 "rpm -ql conntrack-tools | grep conntrackd.conf | grep $mode | xargs -I {} cp {} /etc/conntrackd/conntrackd.conf"
	run fw01 "rpm -ql conntrack-tools | grep keepalived.conf | xargs -I {} cp {} /etc/keepalived/keepalived.conf"
	run fw02 "rpm -ql conntrack-tools | grep keepalived.conf | xargs -I {} cp {} /etc/keepalived/keepalived.conf"

	run fw01 sed -i \'/^[[:space:]]*IPv4_interface 192.168.100.100/s/IPv4_interface 192.168.100.100/IPv4_interface $ha_fw01_ip3/g\' /etc/conntrackd/conntrackd.conf
	run fw02 sed -i \'/^[[:space:]]*IPv4_interface 192.168.100.100/s/IPv4_interface 192.168.100.100/IPv4_interface $ha_fw02_ip3/g\' /etc/conntrackd/conntrackd.conf
	run fw01 sed -i \'/^[[:space:]]*Interface eth2/s/Interface eth2/Interface $ha_fw01_if3/g\' /etc/conntrackd/conntrackd.conf
	run fw02 sed -i \'/^[[:space:]]*Interface eth2/s/Interface eth2/Interface $ha_fw02_if3/g\' /etc/conntrackd/conntrackd.conf
	run fw01 sed -i \'/Address Ignore/aIPv4_address $ha_fw01_ip3\' /etc/conntrackd/conntrackd.conf
	run fw02 sed -i \'/Address Ignore/aIPv4_address $ha_fw02_ip3\' /etc/conntrackd/conntrackd.conf
	run fw01 sed -i \'/Address Ignore/a${content}_address $ha_fw01_ip2\' /etc/conntrackd/conntrackd.conf
	run fw01 sed -i \'/Address Ignore/a${content}_address $ha_fw01_ip1\' /etc/conntrackd/conntrackd.conf
	run fw02 sed -i \'/Address Ignore/a${content}_address $ha_fw02_ip2\' /etc/conntrackd/conntrackd.conf
	run fw02 sed -i \'/Address Ignore/a${content}_address $ha_fw02_ip1\' /etc/conntrackd/conntrackd.conf
	run fw01 sed -i \'/Address Ignore/aIPv4_address 10.73.0.0/16 \# beaker NW\' /etc/conntrackd/conntrackd.conf
	run fw02 sed -i \'/Address Ignore/aIPv4_address 10.73.0.0/16 \# beaker NW\' /etc/conntrackd/conntrackd.conf

	run fw01 sed -i \'/^[[:space:]]*state SLAVE/s/state SLAVE/state MASTER/g\' /etc/keepalived/keepalived.conf
	run fw02 sed -i \'/^[[:space:]]*state SLAVE/s/state SLAVE/state BACKUP/g\' /etc/keepalived/keepalived.conf
	run fw01 sed -i \'/^[[:space:]]*priority 80/s/priority 80/priority 80/g\' /etc/keepalived/keepalived.conf
	run fw02 sed -i \'/^[[:space:]]*priority 80/s/priority 80/priority 50/g\' /etc/keepalived/keepalived.conf
	run fw01 sed -i \'/^[[:space:]]*interface eth1/s/interface eth1/interface $ha_fw01_if1/g\' /etc/keepalived/keepalived.conf
	run fw01 sed -i \'/^[[:space:]]*interface eth0/s/interface eth0/interface $ha_fw01_if2/g\' /etc/keepalived/keepalived.conf
	run fw02 sed -i \'/^[[:space:]]*interface eth1/s/interface eth1/interface $ha_fw02_if1/g\' /etc/keepalived/keepalived.conf
	run fw02 sed -i \'/^[[:space:]]*interface eth0/s/interface eth0/interface $ha_fw02_if2/g\' /etc/keepalived/keepalived.conf
	if [ $2 == "ipv6" ]; then
		run fw01 sed -i \'/^[[:space:]]*192.168.0.100/ife80::1:fffe\' /etc/keepalived/keepalived.conf
		run fw01 sed -i \'/^[[:space:]]*192.168.1.100/ife80::2:fffe\' /etc/keepalived/keepalived.conf
		run fw02 sed -i \'/^[[:space:]]*192.168.0.100/ife80::1:fffe\' /etc/keepalived/keepalived.conf
		run fw02 sed -i \'/^[[:space:]]*192.168.1.100/ife80::2:fffe\' /etc/keepalived/keepalived.conf
	fi
	run fw01 sed -i \'/^[[:space:]]*192.168.0.100/s/192.168.0.100/$ha_fw_cip/g\' /etc/keepalived/keepalived.conf
	run fw01 sed -i \'/^[[:space:]]*192.168.1.100/s/192.168.1.100/$ha_fw_sip/g\' /etc/keepalived/keepalived.conf
	run fw02 sed -i \'/^[[:space:]]*192.168.0.100/s/192.168.0.100/$ha_fw_cip/g\' /etc/keepalived/keepalived.conf
	run fw02 sed -i \'/^[[:space:]]*192.168.1.100/s/192.168.1.100/$ha_fw_sip/g\' /etc/keepalived/keepalived.conf
}
topo_ha_check()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: HA checking"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_env_check ha

	run fw01 rpm -q conntrack-tools
	run fw02 rpm -q conntrack-tools
	run fw01 rpm -q keepalived
	run fw02 rpm -q keepalived
	local result=0
	run fw01 wait_pass ping -I $ha_fw01_if3 $ha_fw02_ip3 -c 3 || { result=1; }
	run client ping_pass -I $ha_client_if1 $ha_fw01_ip1 -c 3 || { result=1; }
	run client ping_pass -I $ha_client_if1 $ha_fw02_ip1 -c 3 || { result=1; }
	run server ping_pass -I $ha_server_if1 $ha_fw01_ip2 -c 3 || { result=1; }
	run server ping_pass -I $ha_server_if1 $ha_fw02_ip2 -c 3 || { result=1; }
	run fw01 conntrackd -d
	run fw02 conntrackd -d
	run fw01 keepalived -d
	run fw02 keepalived -d
	run fw01 wait_start conntrackd
	run fw02 wait_start conntrackd
	run fw01 wait_start keepalived
	run fw02 wait_start keepalived
	run client ping_pass -I $ha_client_if1 $ha_fw_cip -c 3 || { result=1; }
	run server ping_pass -I $ha_server_if1 $ha_fw_sip -c 3 || { result=1; }
	run client ip route add ${ha_snet_ip}/${prefix} via ${ha_fw_cip} dev $ha_client_if1
	run server ip route add ${ha_cnet_ip}/${prefix} via ${ha_fw_sip} dev $ha_server_if1
	run client ping_pass -I $ha_client_if1 $ha_server_ip1 -c 3 || { result=1; }
	run server ping_pass -I $ha_server_if1 $ha_client_ip1 -c 3 || { result=1; }
	run client ip route del ${ha_snet_ip}/${prefix}
	run server ip route del ${ha_cnet_ip}/${prefix}
	run fw01 pkill keepalived
	run fw02 pkill keepalived
	run fw01 conntrackd -k
	run fw02 conntrackd -k
	return $result
}

###########################################################
# Topo: TC Forward
###########################################################
# external APIs
topo_tcf_help()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::   |----------------------------------------|"
	echo "::   | Client--|                              |"
	echo "::   |         |                              |"
	echo "::   |         |--Switch--Switch2--|--Monitor |"
	echo "::   |         |                              |"
	echo "::   | Server--|                              |"
	echo "::   |----------------------------------------|"
	echo ":: - Functions predefined"
	echo "::   - topo_tcf_init"
	echo "::   - topo_tcf_vlan"
	echo "::   - topo_tcf_ipv4"
	echo "::   - topo_tcf_ipv6"
	echo "::   - topo_tcf_check [ipv4|ipv6]"
	echo "::   - run [client|switch|server] [cmd]"
	echo ":: - Variables predefined"
	echo "::   - tcf_client_bif"
	echo "::   - tcf_switch_bif"
	echo "::   - tcf_server_bif"
	echo "::   - tcf_client_if1"
	echo "::   - tcf_switch_if1"
	echo "::   - tcf_switch_if2"
	echo "::   - tcf_server_if1"
	echo "::   - tcf_client_mac1"
	echo "::   - tcf_switch_mac1"
	echo "::   - tcf_switch_mac2"
	echo "::   - tcf_server_mac1"
	echo "::   - tcf_net_ip"
	echo "::   - tcf_client_ip1"
	echo "::   - tcf_server_ip1"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
}
topo_tcf_init()
{
	topo_env_init tcf

	export tcf_client_if1=$(topo_tcf_ifaces client | awk '{print $1}')
	export tcf_server_if1=$(topo_tcf_ifaces server | awk '{print $1}')
	export tcf_switch_if1=$(topo_tcf_ifaces switch | awk '{print $1}')
	export tcf_switch_if2=$(topo_tcf_ifaces switch | awk '{print $2}')

	export tcf_client_mac1=`run client ip a s dev $tcf_client_if1 | grep ether | awk '{print $2}'`
	export tcf_server_mac1=`run server ip a s dev $tcf_server_if1 | grep ether | awk '{print $2}'`
	export tcf_switch_mac1=`run switch ip a s dev $tcf_switch_if1 | grep ether | awk '{print $2}'`
	export tcf_switch_mac2=`run switch ip a s dev $tcf_switch_if2 | grep ether | awk '{print $2}'`

	export tcf_client_bif=`run client ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export tcf_server_bif=`run server ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export tcf_switch_bif=`run switch ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`

	[ $MH_INFRA_TYPE == "ns" ] && return

	export tcf_monitor_if1=$(topo_tcf_ifaces monitor | awk '{print $1}')
	export tcf_switch2_if1=$(topo_tcf_ifaces switch2 | awk '{print $1}')

	export tcf_monitor_mac1=`run monitor ip a s dev $tcf_monitor_if1 | grep ether | awk '{print $2}'`
	export tcf_switch2_mac1=`run switch2 ip a s dev $tcf_switch2_if1 | grep ether | awk '{print $2}'`

	export tcf_monitor_bif=`run monitor ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export tcf_switch2_bif=`run switch2 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
}
topo_tcf_vlan()
{
	[ -z "$1" ] && { local proto='802.1Q'; } || { local proto=$1; }
	[ -z "$2" ] && { local id=99; } || { local id=$2; }
	[ -z "$3" ] && { local prio=0; } || { local prio=$3; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: VLAN settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf_client_vif=$tcf_client_if1.$id
	export tcf_server_vif=$tcf_server_if1.$id

	run client ip link add link $tcf_client_if1 name $tcf_client_vif type vlan protocol $proto id $id egress 0:$prio ingress $prio:0
	run server ip link add link $tcf_server_if1 name $tcf_server_vif type vlan protocol $proto id $id egress 0:$prio ingress $prio:0
	run client ip link set $tcf_client_vif up
	run server ip link set $tcf_server_vif up
	run client network_set_offload $tcf_client_vif $MH_OFFLOADS
	run server network_set_offload $tcf_server_vif $MH_OFFLOADS

	export tcf_client_if1=$tcf_client_vif
	export tcf_server_if1=$tcf_server_vif
	export tcf_client_mac1=`run client ip a s dev $tcf_client_if1 | grep ether | awk '{print $2}'`
	export tcf_server_mac1=`run server ip a s dev $tcf_server_if1 | grep ether | awk '{print $2}'`
}
topo_tcf_bridge()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: BRIDGE settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf_switch_if0=br0

	run switch ip link add name $tcf_switch_if0 type bridge
	run switch ip link set $tcf_switch_if0 up
	run switch network_set_offload $tcf_switch_if0 $MH_OFFLOADS

	export tcf_switch_mac0=`run server ip a s dev $tcf_switch_if0 | grep ether | awk '{print $2}'`
}
topo_tcf_vxlan()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: VXLAN settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf_switch_vxif=vxlan0

	run switch ip link add $tcf_switch_vxif type vxlan dstport 4789 external dev lo
	run switch ip link set $tcf_switch_vxif up
	run switch network_set_offload $tcf_switch_vxif $MH_OFFLOADS

	export tcf_switch_vxmac=`run switch ip a s dev $tcf_switch_vxif | grep ether | awk '{print $2}'`
}
topo_tcf_geneve()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: GENEVE settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf_switch_geif=geneve0

	run switch ip link add $tcf_switch_geif type geneve dstport 0 external
	run switch ip link set $tcf_switch_geif up
	run switch network_set_offload $tcf_switch_geif $MH_OFFLOADS

	export tcf_switch_gemac=`run switch ip a s dev $tcf_switch_geif | grep ether | awk '{print $2}'`
}
topo_tcf_ipv4()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf_net_ip=$(topo_generate_nwaddr tcf net ip)
	export tcf_client_ip1=${tcf_net_ip%0}2
	export tcf_server_ip1=${tcf_net_ip%0}1

	run client ip addr add $tcf_client_ip1/24 dev $tcf_client_if1
	run server ip addr add $tcf_server_ip1/24 dev $tcf_server_if1
	run client ip link set lo up
	run server ip link set lo up
}
topo_tcf_ipv6()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf_net_ip=$(topo_generate_nwaddr tcf net ip6)
	export tcf_client_ip1=${tcf_net_ip%0}2
	export tcf_server_ip1=${tcf_net_ip%0}1

	run client ip addr add $tcf_client_ip1/64 dev $tcf_client_if1
	run server ip addr add $tcf_server_ip1/64 dev $tcf_server_if1
	run client ip link set lo up
	run server ip link set lo up
}
topo_tcf_ipv4_vxlan()
{
	[ -z "$1" ] && { local id=100; } || { local id=$1; }
	[ -z "$2" ] && { local tos=0; } || { local tos=$2; }
	[ -z "$3" ] && { local ttl=64; } || { local ttl=$3; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 VXLAN settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf_client_vxif=vxlan0
	export tcf_server_vxif=vxlan0

	run client ip link add $tcf_client_vxif type vxlan id $id tos $tos ttl $ttl remote $tcf_server_ip1 dstport 4789 dev $tcf_client_if1
	run server ip link add $tcf_server_vxif type vxlan id $id tos $tos ttl $ttl remote $tcf_client_ip1 dstport 4789 dev $tcf_server_if1
	run client ip link set $tcf_client_vxif up
	run server ip link set $tcf_server_vxif up
	run client network_set_offload $tcf_client_vxif $MH_OFFLOADS
	run server network_set_offload $tcf_server_vxif $MH_OFFLOADS

	export tcf_client_vxmac=`run client ip a s dev $tcf_client_vxif | grep ether | awk '{print $2}'`
	export tcf_server_vxmac=`run server ip a s dev $tcf_server_vxif | grep ether | awk '{print $2}'`

	export tcf_vxnet_ip=$(topo_generate_nwaddr tcf vxnet ip)
	export tcf_client_vxip=${tcf_vxnet_ip%0}2
	export tcf_server_vxip=${tcf_vxnet_ip%0}1

	run client ip addr add $tcf_client_vxip/24 dev $tcf_client_vxif
	run server ip addr add $tcf_server_vxip/24 dev $tcf_server_vxif

	# run client ip route add $tcf_server_vxip encap ip id $id src $tcf_client_ip1 dst $tcf_server_ip1 tos $tos ttl $ttl dev $tcf_client_vxif
	# run server ip route add $tcf_client_vxip encap ip id $id src $tcf_server_ip1 dst $tcf_client_ip1 tos $tos ttl $ttl dev $tcf_server_vxif
}
topo_tcf_ipv6_vxlan()
{
	[ -z "$1" ] && { local id=100; } || { local id=$1; }
	[ -z "$2" ] && { local tc=0; } || { local tc=$2; }
	[ -z "$3" ] && { local hoplimit=64; } || { local hoplimit=$3; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 VXLAN settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf_client_vxif=vxlan0
	export tcf_server_vxif=vxlan0

	run client ip link add $tcf_client_vxif type vxlan id $id tos $tc ttl $hoplimit remote $tcf_server_ip1 dstport 4789 dev $tcf_client_if1
	run server ip link add $tcf_server_vxif type vxlan id $id tos $tc ttl $hoplimit remote $tcf_client_ip1 dstport 4789 dev $tcf_server_if1
	run client ip link set $tcf_client_vxif up
	run server ip link set $tcf_server_vxif up
	run client network_set_offload $tcf_client_vxif $MH_OFFLOADS
	run server network_set_offload $tcf_server_vxif $MH_OFFLOADS

	export tcf_client_vxmac=`run client ip a s dev $tcf_client_vxif | grep ether | awk '{print $2}'`
	export tcf_server_vxmac=`run server ip a s dev $tcf_server_vxif | grep ether | awk '{print $2}'`

	export tcf_vxnet_ip=$(topo_generate_nwaddr tcf vxnet ip6)
	export tcf_client_vxip=${tcf_vxnet_ip%0}2
	export tcf_server_vxip=${tcf_vxnet_ip%0}1

	run client ip addr add $tcf_client_vxip/64 dev $tcf_client_vxif
	run server ip addr add $tcf_server_vxip/64 dev $tcf_server_vxif

	# run client ip -6 neigh add $tcf_server_vxip lladdr $tcf_server_vxmac dev $tcf_client_vxif
	# run server ip -6 neigh add $tcf_client_vxip lladdr $tcf_client_vxmac dev $tcf_server_vxif
	# run client ip route add $tcf_server_vxip encap ip6 id $id src $tcf_client_ip1 dst $tcf_server_ip1 tc $tc hoplimit $hoplimit dev $tcf_client_vxif
	# run server ip route add $tcf_client_vxip encap ip6 id $id src $tcf_server_ip1 dst $tcf_client_ip1 tc $tc hoplimit $hoplimit dev $tcf_server_vxif
}
topo_tcf_ipv4_geneve()
{
	[ -z "$1" ] && { local id=100; } || { local id=$1; }
	[ -z "$2" ] && { local tos=0; } || { local tos=$2; }
	[ -z "$3" ] && { local ttl=64; } || { local ttl=$3; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 GENEVE settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf_client_geif=geneve0
	export tcf_server_geif=geneve0

	run client ip link add $tcf_client_geif type geneve id $id tos $tos ttl $ttl remote $tcf_server_ip1 dstport 6081
	run server ip link add $tcf_server_geif type geneve id $id tos $tos ttl $ttl remote $tcf_client_ip1 dstport 6081
	run client ip link set $tcf_client_geif up
	run server ip link set $tcf_server_geif up
	run client network_set_offload $tcf_client_geif $MH_OFFLOADS
	run server network_set_offload $tcf_server_geif $MH_OFFLOADS

	export tcf_client_gemac=`run client ip a s dev $tcf_client_geif | grep ether | awk '{print $2}'`
	export tcf_server_gemac=`run server ip a s dev $tcf_server_geif | grep ether | awk '{print $2}'`

	export tcf_genet_ip=$(topo_generate_nwaddr tcf genet ip)
	export tcf_client_geip=${tcf_genet_ip%0}2
	export tcf_server_geip=${tcf_genet_ip%0}1

	run client ip addr add $tcf_client_geip/24 dev $tcf_client_geif
	run server ip addr add $tcf_server_geip/24 dev $tcf_server_geif

	# run client ip route change $tcf_server_geip encap ip id $id src $tcf_client_ip1 dst $tcf_server_ip1 tos $tos ttl $ttl dev $tcf_client_geif
	# run server ip route change $tcf_client_geip encap ip id $id src $tcf_server_ip1 dst $tcf_client_ip1 tos $tos ttl $ttl dev $tcf_server_geif
}
topo_tcf_ipv6_geneve()
{
	[ -z "$1" ] && { local id=100; } || { local id=$1; }
	[ -z "$2" ] && { local tc=0; } || { local tc=$2; }
	[ -z "$3" ] && { local hoplimit=64; } || { local hoplimit=$3; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 GENEVE settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf_client_geif=geneve0
	export tcf_server_geif=geneve0

	run client ip link add $tcf_client_geif type geneve id $id tos $tc ttl $hoplimit remote $tcf_server_ip1 dstport 6081
	run server ip link add $tcf_server_geif type geneve id $id tos $tc ttl $hoplimit remote $tcf_client_ip1 dstport 6081
	run client ip link set $tcf_client_geif up
	run server ip link set $tcf_server_geif up
	run client network_set_offload $tcf_client_geif $MH_OFFLOADS
	run server network_set_offload $tcf_server_geif $MH_OFFLOADS

	export tcf_client_gemac=`run client ip a s dev $tcf_client_geif | grep ether | awk '{print $2}'`
	export tcf_server_gemac=`run server ip a s dev $tcf_server_geif | grep ether | awk '{print $2}'`

	export tcf_genet_ip=$(topo_generate_nwaddr tcf genet ip6)
	export tcf_client_geip=${tcf_genet_ip%0}2
	export tcf_server_geip=${tcf_genet_ip%0}1

	run client ip addr add $tcf_client_geip/64 dev $tcf_client_geif
	run server ip addr add $tcf_server_geip/64 dev $tcf_server_geif

	# run client ip -6 neigh add $tcf_server_geip lladdr $tcf_server_gemac dev $tcf_client_geif
	# run server ip -6 neigh add $tcf_client_geip lladdr $tcf_client_gemac dev $tcf_server_geif
	# run client ip route add $tcf_server_geip encap ip6 id $id src $tcf_client_ip1 dst $tcf_server_ip1 tc $tc hoplimit $hoplimit dev $tcf_client_geif
	# run server ip route add $tcf_client_geip encap ip6 id $id src $tcf_server_ip1 dst $tcf_client_ip1 tc $tc hoplimit $hoplimit dev $tcf_server_geif
}
topo_tcf_check()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: TCF checking"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_env_check tcf

	local result=0

	if [ $tcf_switch_if0 ]; then
		run switch tc qdisc add dev $tcf_switch_if0 clsact
		run switch tc qdisc add dev $tcf_switch_if1 clsact
		run switch tc qdisc add dev $tcf_switch_if2 clsact
		run switch tc filter add dev $tcf_switch_if0 egress flower indev $tcf_switch_if1 action mirred egress redirect dev $tcf_switch_if2
		run switch tc filter add dev $tcf_switch_if0 egress flower indev $tcf_switch_if2 action mirred egress redirect dev $tcf_switch_if1
		run switch tc filter add dev $tcf_switch_if1 ingress matchall action mirred egress redirect dev $tcf_switch_if0
		run switch tc filter add dev $tcf_switch_if2 ingress matchall action mirred egress redirect dev $tcf_switch_if0
	elif [ $tcf_switch_vxif ]; then
		run switch tc qdisc add dev $tcf_switch_vxif clsact
		run switch tc qdisc add dev $tcf_switch_if1 clsact
		run switch tc qdisc add dev $tcf_switch_if2 clsact
		run switch tc filter add dev $tcf_switch_vxif egress flower indev $tcf_switch_if1 action mirred egress redirect dev $tcf_switch_if2
		run switch tc filter add dev $tcf_switch_vxif egress flower indev $tcf_switch_if2 action mirred egress redirect dev $tcf_switch_if1
		run switch tc filter add dev $tcf_switch_if1 ingress matchall action mirred egress redirect dev $tcf_switch_vxif
		run switch tc filter add dev $tcf_switch_if2 ingress matchall action mirred egress redirect dev $tcf_switch_vxif
	elif [ $tcf_switch_geif ]; then
		run switch tc qdisc add dev $tcf_switch_geif clsact
		run switch tc qdisc add dev $tcf_switch_if1 clsact
		run switch tc qdisc add dev $tcf_switch_if2 clsact
		run switch tc filter add dev $tcf_switch_geif egress flower indev $tcf_switch_if1 action mirred egress redirect dev $tcf_switch_if2
		run switch tc filter add dev $tcf_switch_geif egress flower indev $tcf_switch_if2 action mirred egress redirect dev $tcf_switch_if1
		run switch tc filter add dev $tcf_switch_if1 ingress matchall action mirred egress redirect dev $tcf_switch_geif
		run switch tc filter add dev $tcf_switch_if2 ingress matchall action mirred egress redirect dev $tcf_switch_geif
	else
		run switch tc qdisc add dev $tcf_switch_if1 ingress
		run switch tc qdisc add dev $tcf_switch_if2 ingress
		run switch tc filter add dev $tcf_switch_if1 ingress matchall action mirred egress redirect dev $tcf_switch_if2
		run switch tc filter add dev $tcf_switch_if2 ingress matchall action mirred egress redirect dev $tcf_switch_if1
	fi

	run client ping_pass -I $tcf_client_if1 $tcf_server_ip1 -c 3 || { result=1; }
	run server ping_pass -I $tcf_server_if1 $tcf_client_ip1 -c 3 || { result=1; }
	if [ $tcf_client_vxif ] && [ $tcf_server_vxif ]; then
		run client ping_pass -I $tcf_client_vxif $tcf_server_vxip -c 3 || { result=1; }
		run server ping_pass -I $tcf_server_vxif $tcf_client_vxip -c 3 || { result=1; }
	fi
	if [ $tcf_client_geif ] && [ $tcf_server_geif ]; then
		run client ping_pass -I $tcf_client_geif $tcf_server_geip -c 3 || { result=1; }
		run server ping_pass -I $tcf_server_geif $tcf_client_geip -c 3 || { result=1; }
	fi

	if [ $tcf_switch_if0 ]; then
		run switch tc qdisc del dev $tcf_switch_if0 clsact
		run switch tc qdisc del dev $tcf_switch_if1 clsact
		run switch tc qdisc del dev $tcf_switch_if2 clsact
	elif [ $tcf_switch_vxif ]; then
		run switch tc qdisc del dev $tcf_switch_vxif clsact
		run switch tc qdisc del dev $tcf_switch_if1 clsact
		run switch tc qdisc del dev $tcf_switch_if2 clsact
	elif [ $tcf_switch_geif ]; then
		run switch tc qdisc del dev $tcf_switch_geif clsact
		run switch tc qdisc del dev $tcf_switch_if1 clsact
		run switch tc qdisc del dev $tcf_switch_if2 clsact
	else
		run switch tc qdisc del dev $tcf_switch_if1 ingress
		run switch tc qdisc del dev $tcf_switch_if2 ingress
	fi

	return $result
}

###########################################################
# Topo: TC Forward #2
###########################################################
# external APIs
topo_tcf2_help()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::   |------------------------------------------|"
	echo "::   |  Client--|                    |--Server  |"
	echo "::   |          |                    |          |"
	echo "::   |          |--Switch1--Switch2--|          |"
	echo "::   |          |                    |          |"
	echo "::   | Monitor1-|                    |-Monitor2 |"
	echo "::   |------------------------------------------|"
	echo ":: - Functions predefined"
	echo "::   - topo_tcf2_init"
	echo "::   - topo_tcf2_vlan"
	echo "::   - topo_tcf2_qinq"
	echo "::   - topo_tcf2_vxlan"
	echo "::   - topo_tcf2_geneve"
	echo "::   - topo_tcf2_ipv4"
	echo "::   - topo_tcf2_ipv6"
	echo "::   - topo_tcf2_ipv4_vxlan"
	echo "::   - topo_tcf2_ipv6_vxlan"
	echo "::   - topo_tcf2_ipv4_geneve"
	echo "::   - topo_tcf2_ipv6_geneve"
	echo "::   - topo_tcf2_check [ipv4|ipv6]"
	echo "::   - run [client|switch1|switch2|server] [cmd]"
	echo ":: - Variables predefined"
	echo "::   - tcf2_client_bif"
	echo "::   - tcf2_server_bif"
	echo "::   - tcf2_switch1_bif"
	echo "::   - tcf2_switch2_bif"
	echo "::   - tcf2_client_if1"
	echo "::   - tcf2_server_if1"
	echo "::   - tcf2_switch1_if1"
	echo "::   - tcf2_switch1_if2"
	echo "::   - tcf2_switch2_if1"
	echo "::   - tcf2_switch2_if2"
	echo "::   - tcf2_client_mac1"
	echo "::   - tcf2_server_mac1"
	echo "::   - tcf2_switch1_mac1"
	echo "::   - tcf2_switch1_mac2"
	echo "::   - tcf2_switch2_mac1"
	echo "::   - tcf2_switch2_mac2"
	echo "::   - tcf2_net_ip"
	echo "::   - tcf2_client_ip1"
	echo "::   - tcf2_server_ip1"
	echo "::   - tcf2_vxnet_ip"
	echo "::   - tcf2_genet_ip"
	echo "::   - tcf2_switch1_ip2"
	echo "::   - tcf2_switch2_ip2"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::"
}
topo_tcf2_init()
{
	topo_env_init tcf2

	export tcf2_client_if1=$(topo_tcf2_ifaces client | awk '{print $1}')
	export tcf2_server_if1=$(topo_tcf2_ifaces server | awk '{print $1}')
	export tcf2_monitor1_if1=$(topo_tcf2_ifaces monitor1 | awk '{print $1}')
	export tcf2_monitor2_if1=$(topo_tcf2_ifaces monitor2 | awk '{print $1}')
	export tcf2_switch1_if1=$(topo_tcf2_ifaces switch1 | awk '{print $1}')
	export tcf2_switch1_if2=$(topo_tcf2_ifaces switch1 | awk '{print $2}')
	export tcf2_switch2_if1=$(topo_tcf2_ifaces switch2 | awk '{print $1}')
	export tcf2_switch2_if2=$(topo_tcf2_ifaces switch2 | awk '{print $2}')
	export tcf2_switch1_mif=$(topo_tcf2_ifaces switch1 | awk '{print $3}')
	export tcf2_switch2_mif=$(topo_tcf2_ifaces switch2 | awk '{print $3}')

	export tcf2_client_mac1=`run client ip a s dev $tcf2_client_if1 | grep ether | awk '{print $2}'`
	export tcf2_server_mac1=`run server ip a s dev $tcf2_server_if1 | grep ether | awk '{print $2}'`
	export tcf2_monitor1_mac1=`run monitor1 ip a s dev $tcf2_monitor1_if1 | grep ether | awk '{print $2}'`
	export tcf2_monitor2_mac1=`run monitor2 ip a s dev $tcf2_monitor2_if1 | grep ether | awk '{print $2}'`
	export tcf2_switch1_mac1=`run switch1 ip a s dev $tcf2_switch1_if1 | grep ether | awk '{print $2}'`
	export tcf2_switch1_mac2=`run switch1 ip a s dev $tcf2_switch1_if2 | grep ether | awk '{print $2}'`
	export tcf2_switch2_mac1=`run switch2 ip a s dev $tcf2_switch2_if1 | grep ether | awk '{print $2}'`
	export tcf2_switch2_mac2=`run switch2 ip a s dev $tcf2_switch2_if2 | grep ether | awk '{print $2}'`
	export tcf2_switch1_mmac=`run switch1 ip a s dev $tcf2_switch1_mif | grep ether | awk '{print $2}'`
	export tcf2_switch2_mmac=`run switch2 ip a s dev $tcf2_switch2_mif | grep ether | awk '{print $2}'`

	export tcf2_client_bif=`run client ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export tcf2_server_bif=`run server ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export tcf2_monitor1_bif=`run monitor1 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export tcf2_monitor2_bif=`run monitor2 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export tcf2_switch1_bif=`run switch1 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`
	export tcf2_switch2_bif=`run switch2 ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'`

	[ "$MH_TC_VNIC" != "bond" ] && [ "$MH_TC_VNIC" != "bond_vlan" ] && return

	export tcf2_switch1_if3=$(topo_tcf2_ifaces switch1 | awk '{print $4}')
	export tcf2_switch1_if4=$(topo_tcf2_ifaces switch1 | awk '{print $5}')
	export tcf2_switch2_if3=$(topo_tcf2_ifaces switch2 | awk '{print $4}')
	export tcf2_switch2_if4=$(topo_tcf2_ifaces switch2 | awk '{print $5}')

	export tcf2_switch1_mac3=`run switch1 ip a s dev $tcf2_switch1_if3 | grep ether | awk '{print $2}'`
	export tcf2_switch1_mac4=`run switch1 ip a s dev $tcf2_switch1_if4 | grep ether | awk '{print $2}'`
	export tcf2_switch2_mac3=`run switch2 ip a s dev $tcf2_switch2_if3 | grep ether | awk '{print $2}'`
	export tcf2_switch2_mac4=`run switch2 ip a s dev $tcf2_switch2_if4 | grep ether | awk '{print $2}'`
}
topo_tcf2_vlan()
{
	[ -z "$1" ] && { local proto='802.1Q'; } || { local proto=$1; }
	[ -z "$2" ] && { local id=99; } || { local id=$2; }
	[ -z "$3" ] && { local prio=0; } || { local prio=$3; }
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: VLAN settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf2_client_vif=$tcf2_client_if1.$id
	export tcf2_server_vif=$tcf2_server_if1.$id

	run client ip link add link $tcf2_client_if1 name $tcf2_client_vif type vlan protocol $proto id $id egress 0:$prio ingress $prio:0
	run server ip link add link $tcf2_server_if1 name $tcf2_server_vif type vlan protocol $proto id $id egress 0:$prio ingress $prio:0
	run client ip link set $tcf2_client_vif up
	run server ip link set $tcf2_server_vif up
	run client network_set_offload $tcf2_client_vif $MH_OFFLOADS
	run server network_set_offload $tcf2_server_vif $MH_OFFLOADS

	export tcf2_client_if1=$tcf2_client_vif
	export tcf2_server_if1=$tcf2_server_vif
	export tcf2_client_mac1=`run client ip a s dev $tcf2_client_if1 | grep ether | awk '{print $2}'`
	export tcf2_server_mac1=`run server ip a s dev $tcf2_server_if1 | grep ether | awk '{print $2}'`
}
topo_tcf2_vxlan()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: VXLAN settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf2_switch1_vxif=vxlan0
	export tcf2_switch2_vxif=vxlan0

	run switch1 ip link add $tcf2_switch1_vxif type vxlan dstport 4789 external dev lo
	run switch2 ip link add $tcf2_switch2_vxif type vxlan dstport 4789 external dev lo
	run switch1 ip link set $tcf2_switch1_vxif up
	run switch2 ip link set $tcf2_switch2_vxif up
	run switch1 network_set_offload $tcf2_switch1_vxif $MH_OFFLOADS
	run switch2 network_set_offload $tcf2_switch2_vxif $MH_OFFLOADS
}
topo_tcf2_geneve()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: GENEVE settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf2_switch1_geif=geneve0
	export tcf2_switch2_geif=geneve0

	run switch1 ip link add $tcf2_switch1_geif type geneve dstport 0 external
	run switch2 ip link add $tcf2_switch2_geif type geneve dstport 0 external
	run switch1 ip link set $tcf2_switch1_geif up
	run switch2 ip link set $tcf2_switch2_geif up
	run switch1 network_set_offload $tcf2_switch1_geif $MH_OFFLOADS
	run switch2 network_set_offload $tcf2_switch2_geif $MH_OFFLOADS
}
topo_tcf2_ipv4()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf2_net_ip=$(topo_generate_nwaddr tcf2 net ip)
	export tcf2_client_ip1=${tcf2_net_ip%0}2
	export tcf2_server_ip1=${tcf2_net_ip%0}1
	export tcf2_monitor1_ip1=${tcf2_net_ip%0}4
	export tcf2_monitor2_ip1=${tcf2_net_ip%0}3

	run client ip addr add $tcf2_client_ip1/24 dev $tcf2_client_if1
	run server ip addr add $tcf2_server_ip1/24 dev $tcf2_server_if1
	run client ip link set lo up
	run server ip link set lo up

	run monitor1 ip addr add $tcf2_monitor1_ip1/24 dev $tcf2_monitor1_if1
	run monitor2 ip addr add $tcf2_monitor2_ip1/24 dev $tcf2_monitor2_if1
	run monitor1 ip link set lo up
	run monitor2 ip link set lo up

	run switch1 ip link set dev $tcf2_switch1_if2 promisc on
	run switch2 ip link set dev $tcf2_switch2_if2 promisc on
}
topo_tcf2_ipv6()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf2_net_ip=$(topo_generate_nwaddr tcf2 net ip6)
	export tcf2_client_ip1=${tcf2_net_ip%0}2
	export tcf2_server_ip1=${tcf2_net_ip%0}1
	export tcf2_monitor1_ip1=${tcf2_net_ip%0}4
	export tcf2_monitor2_ip1=${tcf2_net_ip%0}3

	run client ip addr add $tcf2_client_ip1/64 dev $tcf2_client_if1
	run server ip addr add $tcf2_server_ip1/64 dev $tcf2_server_if1
	run client ip link set lo up
	run server ip link set lo up

	run monitor1 ip addr add $tcf2_monitor1_ip1/64 dev $tcf2_monitor1_if1
	run monitor2 ip addr add $tcf2_monitor2_ip1/64 dev $tcf2_monitor2_if1
	run monitor1 ip link set lo up
	run monitor2 ip link set lo up

	run switch1 ip link set dev $tcf2_switch1_if2 promisc on
	run switch2 ip link set dev $tcf2_switch2_if2 promisc on
}
topo_tcf2_ipv4_vxlan()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 VXLAN settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf2_vxnet_ip=$(topo_generate_nwaddr tcf2 vxnet ip)
	export tcf2_switch1_ip2=${tcf2_vxnet_ip%0}2
	export tcf2_switch2_ip2=${tcf2_vxnet_ip%0}1

	run switch1 ip addr add $tcf2_switch1_ip2/24 dev $tcf2_switch1_if2
	run switch2 ip addr add $tcf2_switch2_ip2/24 dev $tcf2_switch2_if2

	run switch1 ip link set dev $tcf2_switch1_if2 promisc off
	run switch2 ip link set dev $tcf2_switch2_if2 promisc off
}
topo_tcf2_ipv6_vxlan()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 VXLAN settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf2_vxnet_ip=$(topo_generate_nwaddr tcf2 vxnet ip6)
	export tcf2_switch1_ip2=${tcf2_vxnet_ip%0}2
	export tcf2_switch2_ip2=${tcf2_vxnet_ip%0}1

	run switch1 ip addr add $tcf2_switch1_ip2/64 dev $tcf2_switch1_if2
	run switch2 ip addr add $tcf2_switch2_ip2/64 dev $tcf2_switch2_if2

	run switch1 ip link set dev $tcf2_switch1_if2 promisc off
	run switch2 ip link set dev $tcf2_switch2_if2 promisc off
}
topo_tcf2_ipv4_geneve()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv4 GENEVE settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf2_genet_ip=$(topo_generate_nwaddr tcf2 genet ip)
	export tcf2_switch1_ip2=${tcf2_genet_ip%0}2
	export tcf2_switch2_ip2=${tcf2_genet_ip%0}1

	run switch1 ip addr add $tcf2_switch1_ip2/24 dev $tcf2_switch1_if2
	run switch2 ip addr add $tcf2_switch2_ip2/24 dev $tcf2_switch2_if2

	run switch1 ip link set dev $tcf2_switch1_if2 promisc off
	run switch2 ip link set dev $tcf2_switch2_if2 promisc off
}
topo_tcf2_ipv6_geneve()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: IPv6 GENEVE settings"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	export tcf2_genet_ip=$(topo_generate_nwaddr tcf2 genet ip6)
	export tcf2_switch1_ip2=${tcf2_genet_ip%0}2
	export tcf2_switch2_ip2=${tcf2_genet_ip%0}1

	run switch1 ip addr add $tcf2_switch1_ip2/64 dev $tcf2_switch1_if2
	run switch2 ip addr add $tcf2_switch2_ip2/64 dev $tcf2_switch2_if2

	run switch1 ip link set dev $tcf2_switch1_if2 promisc off
	run switch2 ip link set dev $tcf2_switch2_if2 promisc off
}
topo_tcf2_check()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: TCF2 checking"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_env_check tcf2

	local result=0

	if [ $tcf2_switch1_ip2 ] && [ $tcf2_switch2_ip2 ]; then
		run switch1 ping_pass -I $tcf2_switch1_if2 $tcf2_switch2_ip2 -c 3 || { result=1; }
		run switch2 ping_pass -I $tcf2_switch2_if2 $tcf2_switch1_ip2 -c 3 || { result=1; }
	fi

	if [ $tcf2_switch1_vxif ] && [ $tcf2_switch2_vxif ]; then
		run switch1 tc qdisc add dev $tcf2_switch1_if1 ingress
		run switch2 tc qdisc add dev $tcf2_switch2_if1 ingress
		run switch1 tc qdisc add dev $tcf2_switch1_vxif ingress
		run switch2 tc qdisc add dev $tcf2_switch2_vxif ingress
		run switch1 tc filter add dev $tcf2_switch1_if1 ingress flower action tunnel_key set src_ip $tcf2_switch1_ip2 dst_ip $tcf2_switch2_ip2 dst_port 4789 id 100 action mirred egress redirect dev $tcf2_switch1_vxif
		run switch2 tc filter add dev $tcf2_switch2_if1 ingress flower action tunnel_key set src_ip $tcf2_switch2_ip2 dst_ip $tcf2_switch1_ip2 dst_port 4789 id 100 action mirred egress redirect dev $tcf2_switch2_vxif
		run switch1 tc filter add dev $tcf2_switch1_vxif ingress flower action tunnel_key unset action mirred egress redirect dev $tcf2_switch1_if1
		run switch2 tc filter add dev $tcf2_switch2_vxif ingress flower action tunnel_key unset action mirred egress redirect dev $tcf2_switch2_if1
		run client ping_pass -I $tcf2_client_if1 $tcf2_server_ip1 -c 3 || { result=1; }
		run server ping_pass -I $tcf2_server_if1 $tcf2_client_ip1 -c 3 || { result=1; }
		run switch1 tc qdisc del dev $tcf2_switch1_if1 ingress
		run switch2 tc qdisc del dev $tcf2_switch2_if1 ingress
		run switch1 tc qdisc del dev $tcf2_switch1_vxif ingress
		run switch2 tc qdisc del dev $tcf2_switch2_vxif ingress
	elif [ $tcf2_switch1_geif ] && [ $tcf2_switch2_geif ]; then
		run switch1 tc qdisc add dev $tcf2_switch1_if1 ingress
		run switch2 tc qdisc add dev $tcf2_switch2_if1 ingress
		run switch1 tc qdisc add dev $tcf2_switch1_geif ingress
		run switch2 tc qdisc add dev $tcf2_switch2_geif ingress
		run switch1 tc filter add dev $tcf2_switch1_if1 ingress flower action tunnel_key set src_ip $tcf2_switch1_ip2 dst_ip $tcf2_switch2_ip2 dst_port 6081 id 100 action mirred egress redirect dev $tcf2_switch1_geif
		run switch2 tc filter add dev $tcf2_switch2_if1 ingress flower action tunnel_key set src_ip $tcf2_switch2_ip2 dst_ip $tcf2_switch1_ip2 dst_port 6081 id 100 action mirred egress redirect dev $tcf2_switch2_geif
		run switch1 tc filter add dev $tcf2_switch1_geif ingress flower action tunnel_key unset action mirred egress redirect dev $tcf2_switch1_if1
		run switch2 tc filter add dev $tcf2_switch2_geif ingress flower action tunnel_key unset action mirred egress redirect dev $tcf2_switch2_if1
		run client ping_pass -I $tcf2_client_if1 $tcf2_server_ip1 -c 3 || { result=1; }
		run server ping_pass -I $tcf2_server_if1 $tcf2_client_ip1 -c 3 || { result=1; }
		run switch1 tc qdisc del dev $tcf2_switch1_if1 ingress
		run switch2 tc qdisc del dev $tcf2_switch2_if1 ingress
		run switch1 tc qdisc del dev $tcf2_switch1_geif ingress
		run switch2 tc qdisc del dev $tcf2_switch2_geif ingress
	else
		run switch1 tc qdisc add dev $tcf2_switch1_if1 ingress
		run switch1 tc qdisc add dev $tcf2_switch1_if2 ingress
		run switch2 tc qdisc add dev $tcf2_switch2_if1 ingress
		run switch2 tc qdisc add dev $tcf2_switch2_if2 ingress
		run switch1 tc filter add dev $tcf2_switch1_if1 ingress matchall action mirred egress mirror dev $tcf2_switch1_mif mirred egress redirect dev $tcf2_switch1_if2
		run switch2 tc filter add dev $tcf2_switch2_if1 ingress matchall action mirred egress mirror dev $tcf2_switch2_mif mirred egress redirect dev $tcf2_switch2_if2
		run switch1 tc filter add dev $tcf2_switch1_if2 ingress matchall action mirred egress mirror dev $tcf2_switch1_mif mirred egress redirect dev $tcf2_switch1_if1
		run switch2 tc filter add dev $tcf2_switch2_if2 ingress matchall action mirred egress mirror dev $tcf2_switch2_mif mirred egress redirect dev $tcf2_switch2_if1
		run monitor1 tcpdump -Ui $tcf2_monitor1_if1 -w tcpdump1.pcap &
		run monitor2 tcpdump -Ui $tcf2_monitor2_if1 -w tcpdump2.pcap &
		run monitor1 wait_start tcpdump
		run monitor2 wait_start tcpdump
		run client ping_pass -I $tcf2_client_if1 $tcf2_server_ip1 -c 3 || { result=1; }
		run server ping_pass -I $tcf2_server_if1 $tcf2_client_ip1 -c 3 || { result=1; }
		run monitor1 wait_written tcpdump1.pcap
		run monitor2 wait_written tcpdump2.pcap
		run monitor1 pkill tcpdump
		run monitor2 pkill tcpdump
		run monitor1 "tcpdump -r tcpdump1.pcap -nn | grep ICMP" || { result=1; }
		run monitor1 "tcpdump -r tcpdump1.pcap -nn | grep ICMP" || { result=1; }
		run monitor2 "tcpdump -r tcpdump2.pcap -nn | grep ICMP" || { result=1; }
		run monitor2 "tcpdump -r tcpdump2.pcap -nn | grep ICMP" || { result=1; }
		run monitor1 tcpdump -r tcpdump1.pcap -nn
		run monitor2 tcpdump -r tcpdump2.pcap -nn
		run switch1 tc qdisc del dev $tcf2_switch1_if1 ingress
		run switch1 tc qdisc del dev $tcf2_switch1_if2 ingress
		run switch2 tc qdisc del dev $tcf2_switch2_if1 ingress
		run switch2 tc qdisc del dev $tcf2_switch2_if2 ingress
	fi

	return $result
}

