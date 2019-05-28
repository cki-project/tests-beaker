#!/bin/sh

###########################################################
# 
###########################################################
# include/uapi/linux/netfilter_ipv6.h
###########################################################
# enum nf_ip6_hook_priorities {
#         NF_IP6_PRI_FIRST = INT_MIN,
#         NF_IP6_PRI_CONNTRACK_DEFRAG = -400,
#         NF_IP6_PRI_RAW = -300,
#         NF_IP6_PRI_SELINUX_FIRST = -225,
#         NF_IP6_PRI_CONNTRACK = -200,
#         NF_IP6_PRI_MANGLE = -150,
#         NF_IP6_PRI_NAT_DST = -100,
#         NF_IP6_PRI_FILTER = 0,
#         NF_IP6_PRI_SECURITY = 50,
#         NF_IP6_PRI_NAT_SRC = 100,
#         NF_IP6_PRI_SELINUX_LAST = 225,
#         NF_IP6_PRI_CONNTRACK_HELPER = 300,
#         NF_IP6_PRI_LAST = INT_MAX,
# };
###########################################################
# like iptables : 
# The "nat" table is not intended for filtering, the use of DROP is therefore inhibited.
###########################################################
# https://bugzilla.redhat.com/show_bug.cgi?id=1298879#c2
###########################################################
tg_STANDARDv6_is_unsupported_entry()
{
	return 1
}
tg_STANDARDv6_integration()
{
	local result=0
	[ $1 == "normal" ] && { local pktsize=""; }
	[ $1 == "fragment" ] && { local pktsize="-s 2048"; }
	##############################
	# init test environment
	##############################
	topo_cs_init
	topo_cs_ipv6
	##############################
	# check test environment
	##############################
	topo_cs_check
	assert_pass result "client-server topo init"
	##############################
	# do your test
	##############################
	for table in filter mangle raw security; do
		for chain in PREROUTING INPUT OUTPUT POSTROUTING; do
			[ $table == "filter" ] && [ $chain == "PREROUTING" ] && continue
			[ $table == "filter" ] && [ $chain == "POSTROUTING" ] && continue
			[ $table == "raw" ] && [ $chain == "INPUT" ] && continue
			[ $table == "raw" ] && [ $chain == "POSTROUTING" ] && continue
			[ $table == "security" ] && [ $chain == "PREROUTING" ] && continue
			[ $table == "security" ] && [ $chain == "POSTROUTING" ] && continue

			if [ $chain == "PREROUTING" ] || [ $chain == "INPUT" ]; then
				cont="-i $cs_server_if1 -s $cs_client_ip1 -d $cs_server_ip1"
			else
				cont="-o $cs_server_if1 -s $cs_server_ip1 -d $cs_client_ip1"
			fi

			# -j ACCEPT
			run server ip6tables -t $table -A $chain -p icmpv6 -m icmp6 --icmpv6-type 136 -j ACCEPT
			run server ip6tables -t $table -A $chain -p icmpv6 -m icmp6 --icmpv6-type 135 -j ACCEPT
			run server ip6tables -t $table -A $chain $cont -j ACCEPT
			run server ip6tables -t $table -A $chain $cont -j DROP
			run client ping6 -I $cs_client_if1 $cs_server_ip1 -c3 $pktsize
			assert_pass result "-j ACCEPT [ping6]"
			run server ip6tables -t $table -L -n -v
			run server ip6tables -t $table -F

			# -j DROP
			run server ip6tables -t $table -A $chain -p icmpv6 -m icmp6 --icmpv6-type 136 -j ACCEPT
			run server ip6tables -t $table -A $chain -p icmpv6 -m icmp6 --icmpv6-type 135 -j ACCEPT
			run server ip6tables -t $table -A $chain $cont -j DROP
			run server ip6tables -t $table -A $chain $cont -j ACCEPT
			run client ping6 -I $cs_client_if1 $cs_server_ip1 -c3 $pktsize
			assert_fail result "-j DROP [ping6]"
			run server ip6tables -t $table -L -n -v
			run server ip6tables -t $table -F

			# -j RETURN
			run server ip6tables -t $table -A $chain -p icmpv6 -m icmp6 --icmpv6-type 136 -j ACCEPT
			run server ip6tables -t $table -A $chain -p icmpv6 -m icmp6 --icmpv6-type 135 -j ACCEPT
			run server ip6tables -t $table -N TEST
			run server ip6tables -t $table -A TEST $cont -j RETURN
			run server ip6tables -t $table -A TEST $cont -j DROP
			run server ip6tables -t $table -A $chain $cont -j TEST
			run server ip6tables -t $table -A $chain $cont -j ACCEPT
			run client ping6 -I $cs_client_if1 $cs_server_ip1 -c3 $pktsize
			assert_pass result "-j RETURN [ping6]"
			run server ip6tables -t $table -L -n -v
			run server ip6tables -t $table -F
			run server ip6tables -t $table -X
		done
	done
	##############################
	# init test environment
	##############################
	topo_rf_init
	topo_rf_ipv6
	##############################
	# check test environment
	##############################
	topo_rf_check
	assert_pass result "router-forward topo init"
	##############################
	# do your test
	##############################
	for table in filter mangle raw security; do
		for chain in PREROUTING FORWARD POSTROUTING; do
			[ $table == "filter" ] && [ $chain == "PREROUTING" ] && continue
			[ $table == "filter" ] && [ $chain == "POSTROUTING" ] && continue
			[ $table == "raw" ] && [ $chain == "FORWARD" ] && continue
			[ $table == "raw" ] && [ $chain == "POSTROUTING" ] && continue
			[ $table == "security" ] && [ $chain == "PREROUTING" ] && continue
			[ $table == "security" ] && [ $chain == "POSTROUTING" ] && continue

			if [ $chain == "PREROUTING" ]; then
				cont="-i $rf_router_if1 -s $rf_client_ip1 -d $rf_server_ip1"
			elif [ $chain == "POSTROUTING" ]; then
				cont="-o $rf_router_if2 -s $rf_client_ip1 -d $rf_server_ip1"
			else
				cont="-i $rf_router_if1 -o $rf_router_if2 -s $rf_client_ip1 -d $rf_server_ip1"
			fi

			# -j ACCEPT
			run router ip6tables -t $table -A $chain -p icmpv6 -m icmp6 --icmpv6-type 136 -j ACCEPT
			run router ip6tables -t $table -A $chain -p icmpv6 -m icmp6 --icmpv6-type 135 -j ACCEPT
			run router ip6tables -t $table -A $chain $cont -j ACCEPT
			run router ip6tables -t $table -A $chain $cont -j DROP
			run client ping6 -I $rf_client_if1 $rf_server_ip1 -c3 $pktsize
			assert_pass result "-j ACCEPT [ping6]"
			run router ip6tables -t $table -L -n -v
			run router ip6tables -t $table -F

			# -j DROP
			run router ip6tables -t $table -A $chain -p icmpv6 -m icmp6 --icmpv6-type 136 -j ACCEPT
			run router ip6tables -t $table -A $chain -p icmpv6 -m icmp6 --icmpv6-type 135 -j ACCEPT
			run router ip6tables -t $table -A $chain $cont -j DROP
			run router ip6tables -t $table -A $chain $cont -j ACCEPT
			run client ping6 -I $rf_client_if1 $rf_server_ip1 -c3 $pktsize
			assert_fail result "-j DROP [ping6]"
			run router ip6tables -t $table -L -n -v
			run router ip6tables -t $table -F

			# -j RETURN
			run router ip6tables -t $table -A $chain -p icmpv6 -m icmp6 --icmpv6-type 136 -j ACCEPT
			run router ip6tables -t $table -A $chain -p icmpv6 -m icmp6 --icmpv6-type 135 -j ACCEPT
			run router ip6tables -t $table -N TEST
			run router ip6tables -t $table -A TEST $cont -j RETURN
			run router ip6tables -t $table -A TEST $cont -j DROP
			run router ip6tables -t $table -A $chain $cont -j TEST
			run router ip6tables -t $table -A $chain $cont -j ACCEPT
			run client ping6 -I $rf_client_if1 $rf_server_ip1 -c3 $pktsize
			assert_pass result "-j RETURN [ping6]"
			run router ip6tables -t $table -L -n -v
			run router ip6tables -t $table -F
			run router ip6tables -t $table -X
		done
	done

	return $result
}

