#!/bin/sh

###########################################################
# 
###########################################################
# include/uapi/linux/netfilter_ipv4.h
###########################################################
# enum nf_ip_hook_priorities {
#         NF_IP_PRI_FIRST = INT_MIN,
#         NF_IP_PRI_CONNTRACK_DEFRAG = -400,
#         NF_IP_PRI_RAW = -300,
#         NF_IP_PRI_SELINUX_FIRST = -225,
#         NF_IP_PRI_CONNTRACK = -200,
#         NF_IP_PRI_MANGLE = -150,
#         NF_IP_PRI_NAT_DST = -100,
#         NF_IP_PRI_FILTER = 0,
#         NF_IP_PRI_SECURITY = 50,
#         NF_IP_PRI_NAT_SRC = 100,
#         NF_IP_PRI_SELINUX_LAST = 225,
#         NF_IP_PRI_CONNTRACK_HELPER = 300,
#         NF_IP_PRI_CONNTRACK_CONFIRM = INT_MAX,
#         NF_IP_PRI_LAST = INT_MAX,
# };
###########################################################
# iptables v1.4.21: 
# The "nat" table is not intended for filtering, the use of DROP is therefore inhibited.
###########################################################
tg_STANDARD_is_unsupported_entry()
{
	return 1
}
tg_STANDARD_integration()
{
	local result=0
	[ $1 == "normal" ] && { local pktsize=""; }
	[ $1 == "fragment" ] && { local pktsize="-s 2048"; }
	##############################
	# init test environment
	##############################
	topo_cs_init
	topo_cs_ipv4
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
			[ $table == "nat" ] && [ $chain == "INPUT" ] && continue
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
			run server iptables -t $table -A $chain $cont -j ACCEPT
			run server iptables -t $table -A $chain $cont -j DROP
			run client ping $cs_server_ip1 -c1 $pktsize
			assert_pass result "-j ACCEPT [ping]"
			run server iptables -t $table -L -n -v
			run server iptables -t $table -F

			# -j DROP
			run server iptables -t $table -A $chain $cont -j DROP
			run server iptables -t $table -A $chain $cont -j ACCEPT
			run client ping $cs_server_ip1 -c1 $pktsize
			assert_fail result "-j DROP [ping]"
			run server iptables -t $table -L -n -v
			run server iptables -t $table -F

			# -j RETURN
			run server iptables -t $table -N TEST
			run server iptables -t $table -A TEST $cont -j RETURN
			run server iptables -t $table -A TEST $cont -j DROP
			run server iptables -t $table -A $chain $cont -j TEST
			run server iptables -t $table -A $chain $cont -j ACCEPT
			run client ping $cs_server_ip1 -c1 $pktsize
			assert_pass result "-j RETURN [ping]"
			run server iptables -t $table -L -n -v
			run server iptables -t $table -F
			run server iptables -t $table -X
		done
	done
	##############################
	# init test environment
	##############################
	topo_rf_init
	topo_rf_ipv4
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
			[ $table == "nat" ] && [ $chain == "FORWARD" ] && continue
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
			run router iptables -t $table -A $chain $cont -j ACCEPT
			run router iptables -t $table -A $chain $cont -j DROP
			run client ping $rf_server_ip1 -c1 $pktsize
			assert_pass result "-j ACCEPT [ping]"
			run router iptables -t $table -L -n -v
			run router iptables -t $table -F

			# -j DROP
			run router iptables -t $table -A $chain $cont -j DROP
			run router iptables -t $table -A $chain $cont -j ACCEPT
			run client ping $rf_server_ip1 -c1 $pktsize
			assert_fail result "-j DROP [ping]"
			run router iptables -t $table -L -n -v
			run router iptables -t $table -F

			# -j RETURN
			run router iptables -t $table -N TEST
			run router iptables -t $table -A TEST $cont -j RETURN
			run router iptables -t $table -A TEST $cont -j DROP
			run router iptables -t $table -A $chain $cont -j TEST
			run router iptables -t $table -A $chain $cont -j ACCEPT
			run client ping $rf_server_ip1 -c1 $pktsize
			assert_pass result "-j RETURN [ping]"
			run router iptables -t $table -L -n -v
			run router iptables -t $table -F
			run router iptables -t $table -X
		done
	done

	#DNAT:
	modprobe sctp
	run server sleep 1
	run router iptables -t nat -A PREROUTING -i $rf_router_if1 -p tcp -j DNAT --to-destination $rf_server_ip1:9999
	run router iptables -t nat -A PREROUTING -i $rf_router_if1 -p udp -j DNAT --to-destination $rf_server_ip1:9999
	run router iptables -t nat -A PREROUTING -i $rf_router_if1 -p sctp -j DNAT --to-destination $rf_server_ip1:9999
	run server ncat -4 -l 9999 &
	run server ncat -4 -u -l 9999 &
	run server ncat -4 --sctp -l 9999 &
	run server sleep 1
	run client "ncat -4 $rf_router_ip1 8888 <<<'abc'"
	assert_pass result "DNAT tcp pass"
	run client "ncat -4 -u $rf_router_ip1 8888 <<<'abc'"
	assert_pass result "DNAT udp pass"
	run client "ncat -4 --sctp $rf_router_ip1 8888 <<<'abc'"
	assert_pass result "DNAT sctp pass"

	run router iptables -tnat -nvL
	run router iptables -tnat -F
	pkill ncat

	#SNAT
	run router iptables -t nat -A POSTROUTING -o $rf_router_if2 -p tcp -j SNAT --to-source $rf_router_ip2:1234
	run router iptables -t nat -A POSTROUTING -o $rf_router_if2 -p udp -j SNAT --to-source $rf_router_ip2:1234
	run router iptables -t nat -A POSTROUTING -o $rf_router_if2 -p sctp -j SNAT --to-source $rf_router_ip2:1234
	run server iptables -A INPUT -i $rf_server_if1 -p tcp ! --sport 1234 -j DROP
	run server iptables -A INPUT -i $rf_server_if1 -p udp ! --sport 1234 -j DROP
	run server iptables -A INPUT -i $rf_server_if1 -p sctp ! --sport 1234 -j DROP

	run server ncat -4 -l 9999 &
	run server ncat -4 -u -l 9999 &
	run server ncat -4 --sctp -l 9999 &
	run server sleep 1
	run client "ncat -4 $rf_server_ip1 9999 <<<'abc'"
	assert_pass result "SNAT tcp pass"
	run client "ncat -4 -u $rf_server_ip1 9999 <<<'abc'"
	assert_pass result "SNAT udp pass"
	run client "ncat -4 --sctp $rf_server_ip1 9999 <<<'abc'"
	assert_pass result "SNAT sctp pass"

	run router iptables -tnat -nvL
	run router iptables -F
	run server iptables -nvL
	run server iptables -F
	pkill ncat

	return $result
}
