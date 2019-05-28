#!/bin/sh

###########################################################
# Common functions definition for ns infra
###########################################################
topo_all_destroy()
{
	local ns;
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests destroy "
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	rmmod veth
	for ns in $(ip netns); do
		ip netns del $ns
	done
	topo_lo_run mellanox_cleanup
	topo_lo_run netronome_cleanup
}

###########################################################
# Topo: Client Server
###########################################################
# internal APIs
topo_cs_run()
{
	local guest=$1; shift; local cmd=$@
	case $guest in
		'client') topo_ns_run cs_c $cmd;;
		'server') topo_lo_run $cmd;;
	esac
}
topo_cs_guests()
{
	local guests
	ip netns | grep cs_c > /dev/null 2>&1 && { guests=$guests" client"; }
	guests=$guests" server"
	echo -n $guests
}
topo_cs_ifaces()
{
	case $1 in
		'client') echo -n "eth1";;
		'server') echo -n "veth_cs_s1";;
	esac
}
topo_cs_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                           Client---|---Server"
	echo "::                           (netns)      (Host)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create "
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	ip netns add cs_c
	ip link add name veth_cs_s1 type veth peer name eth1 netns cs_c
}
topo_cs_destroy()
{
	topo_all_destroy
}

############################################################
# Topo: Bridge Forward
############################################################
# internal APIs
topo_bf_run()
{
	local guest=$1; shift; local cmd=$@
	case $guest in
		'client') topo_ns_run bf_c $cmd;;
		'bridge') topo_ns_run bf_b $cmd;;
		'server') topo_lo_run $cmd;;
	esac
}
topo_bf_guests()
{
	local guests
	ip netns | grep bf_c > /dev/null 2>&1 && { guests=$guests" client"; }
	ip netns | grep bf_b > /dev/null 2>&1 && { guests=$guests" bridge"; }
	guests=$guests" server"
	echo -n $guests
}
topo_bf_ifaces()
{
	case $1 in
		'client') echo -n "eth1";;
		'bridge') echo -n "br0 eth1 eth2";;
		'server') echo -n "veth_bf_s1";;
	esac
}
topo_bf_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                     Client---|---Bridge---|---Server"
	echo "::                     (netns)      (netns)      (Host)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create "
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	ip netns add bf_c
	ip netns add bf_b
	ip link add name eth1 netns bf_c type veth peer name eth1 netns bf_b
	ip link add name veth_bf_s1 type veth peer name eth2 netns bf_b
	ip netns exec bf_b ip link add name br0 type bridge
	ip netns exec bf_b ip link set br0 up
	ip netns exec bf_b ip link set eth1 master br0
	ip netns exec bf_b ip link set eth2 master br0
	if $MH_BR_OPENSTACK; then
		for iface in eth1 eth2 br0; do
			ip link set $iface mtu 9000
		done
	fi
}
topo_bf_destroy()
{
	topo_all_destroy
}

###########################################################
# Topo: Route Forward
###########################################################
# internal APIs
topo_rf_run()
{
	local guest=$1; shift; local cmd=$@
	case $guest in
		'client') topo_ns_run rf_c $cmd;;
		'router') topo_ns_run rf_r $cmd;;
		'server') topo_lo_run $cmd;;
	esac
}
topo_rf_guests()
{
	local guests
	ip netns | grep rf_c > /dev/null 2>&1 && { guests=$guests" client"; }
	ip netns | grep rf_r > /dev/null 2>&1 && { guests=$guests" router"; }
	guests=$guests" server"
	echo -n $guests
}
topo_rf_ifaces()
{
	case $1 in
		'client') echo -n "eth1";;
		'router') echo -n "eth1 eth2";;
		'server') echo -n "veth_rf_s1";;
	esac
}
topo_rf_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                     Client---|---Router---|---Server"
	echo "::                     (netns)      (netns)      (Host)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create "
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	ip netns add rf_c
	ip netns add rf_r
	ip link add name eth1 netns rf_c type veth peer name eth1 netns rf_r
	ip link add name veth_rf_s1 type veth peer name eth2 netns rf_r
}
topo_rf_destroy()
{
	topo_all_destroy
}

###########################################################
# Topo: Bridge Forward #2
###########################################################
# internal APIs
topo_bf2_run()
{
	local guest=$1; shift; local cmd=$@
	case $guest in
		'client') topo_ns_run bf2_c $cmd;;
		'bridge1') topo_ns_run bf2_b1 $cmd;;
		'bridge2') topo_ns_run bf2_b2 $cmd;;
		'server') topo_lo_run $cmd;;
	esac
}
topo_bf2_guests()
{
	local guests
	ip netns | grep bf2_c > /dev/null 2>&1 && { guests=$guests" client"; }
	ip netns | grep bf2_b1 > /dev/null 2>&1 && { guests=$guests" bridge1"; }
	ip netns | grep bf2_b2 > /dev/null 2>&1 && { guests=$guests" bridge2"; }
	guests=$guests" server"
	echo -n $guests
}
topo_bf2_ifaces()
{
	case $1 in
		'client') echo -n "eth1";;
		'bridge1') echo -n "br0 eth1 eth2";;
		'bridge2') echo -n "br0 eth1 eth2";;
		'server') echo -n "veth_bf2_s1";;
	esac
}
topo_bf2_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                Client---|---Bridge1---|---Bridge2---|---Server"
	echo "::                (netns)      (netns)       (netns)       (Host)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create "
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	ip netns add bf2_c
	ip netns add bf2_b1
	ip netns add bf2_b2
	ip link add name eth1 netns bf2_c type veth peer name eth1 netns bf2_b1
	ip link add name eth2 netns bf2_b1 type veth peer name eth2 netns bf2_b2
	ip link add name veth_bf2_s1 type veth peer name eth1 netns bf2_b2
	for ns in bf2_b1 bf2_b2; do
		ip netns exec $ns ip link add name br0 type bridge
		ip netns exec $ns ip link set br0 up
		ip netns exec $ns ip link set eth1 master br0
		ip netns exec $ns ip link set eth2 master br0
	done
}
topo_bf2_destroy()
{
	topo_all_destroy
}

###########################################################
# Topo: Route Forward #2
###########################################################
# internal APIs
topo_rf2_run()
{
	local guest=$1; shift; local cmd=$@
	case $guest in
		'client') topo_ns_run rf2_c $cmd;;
		'router1') topo_ns_run rf2_r1 $cmd;;
		'router2') topo_ns_run rf2_r2 $cmd;;
		'server') topo_lo_run $cmd;;
	esac
}
topo_rf2_guests()
{
	local guests
	ip netns | grep rf2_c > /dev/null 2>&1 && { guests=$guests" client"; }
	ip netns | grep rf2_r1 > /dev/null 2>&1 && { guests=$guests" router1"; }
	ip netns | grep rf2_r2 > /dev/null 2>&1 && { guests=$guests" router2"; }
	guests=$guests" server"
	echo -n $guests
}
topo_rf2_ifaces()
{
	case $1 in
		'client') echo -n "eth1";;
		'router1') echo -n "eth1 eth2";;
		'router2') echo -n "eth1 eth2";;
		'server') echo -n "veth_rf2_s1";;
	esac
}
topo_rf2_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                Client---|---Router1---|---Router2---|---Server"
	echo "::                (netns)      (netns)       (netns)       (Host)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create "
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	ip netns add rf2_c
	ip netns add rf2_r1
	ip netns add rf2_r2
	ip link add name eth1 netns rf2_c type veth peer name eth1 netns rf2_r1
	ip link add name eth2 netns rf2_r1 type veth peer name eth2 netns rf2_r2
	ip link add name veth_rf2_s1 type veth peer name eth1 netns rf2_r2
}
topo_rf2_destroy()
{
	topo_all_destroy
}

###########################################################
# Topo: Load Balance
###########################################################
# internal APIs
topo_lb_run()
{
	local guest=$1; shift; local cmd=$@
	case $guest in
		'client1') topo_ns_run lb_c1 $cmd;;
		'client2') topo_ns_run lb_c2 $cmd;;
		'balancer') topo_lo_run $cmd;;
		'server1') topo_ns_run lb_s1 $cmd;;
		'server2') topo_ns_run lb_s2 $cmd;;
	esac
}
topo_lb_guests()
{
	local guests
	ip netns | grep lb_c1 > /dev/null 2>&1 && { guests=$guests" client1"; }
	ip netns | grep lb_c2 > /dev/null 2>&1 && { guests=$guests" client2"; }
	ip netns | grep lb_s1 > /dev/null 2>&1 && { guests=$guests" server1"; }
	ip netns | grep lb_s2 > /dev/null 2>&1 && { guests=$guests" server2"; }
	guests=$guests" balancer"
	echo -n $guests
}
topo_lb_ifaces()
{
	case $1 in
		'client1') echo -n "eth1";;
		'client2') echo -n "eth1";;
		'balancer') echo -n "br1 br2";;
		'server1') echo -n "eth1";;
		'server2') echo -n "eth1";;
	esac
}
topo_lb_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                    Client1                      Server1"
	echo "::                    (netns)---|              |---(netns)"
	echo "::                              |              |"
	echo "::                              |---Balancer---|"
	echo "::                              |    (Host)    |"
	echo "::                    Client2---|              |---Server2"
	echo "::                    (netns)                      (netns)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create "
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	ip netns add lb_c1
	ip netns add lb_c2
	ip netns add lb_s1
	ip netns add lb_s2
	ip link add name veth_lb_c1 type veth peer name eth1 netns lb_c1
	ip link add name veth_lb_c2 type veth peer name eth1 netns lb_c2
	ip link add name veth_lb_s1 type veth peer name eth1 netns lb_s1
	ip link add name veth_lb_s2 type veth peer name eth1 netns lb_s2
	for iface in br1 br2; do
		ip link add name $iface type bridge
		ip link set $iface up
	done
	for iface in veth_lb_c1 veth_lb_c2; do
		ip link set $iface master br1
		ip link set $iface up
	done
	for iface in veth_lb_s1 veth_lb_s2; do
		ip link set $iface master br2
		ip link set $iface up
	done
}
topo_lb_destroy()
{
	topo_all_destroy
}

###########################################################
# Topo: Load Balance #2
###########################################################
# internal APIs
topo_lb2_run()
{
	local guest=$1; shift; local cmd=$@
	case $guest in
		'client1') topo_ns_run lb2_c1 $cmd;;
		'client2') topo_ns_run lb2_c2 $cmd;;
		'balancer') topo_lo_run $cmd;;
		'server1') topo_ns_run lb2_s1 $cmd;;
		'server2') topo_ns_run lb2_s2 $cmd;;
	esac
}
topo_lb2_guests()
{
	local guests
	ip netns | grep lb2_c1 > /dev/null 2>&1 && { guests=$guests" client1"; }
	ip netns | grep lb2_c2 > /dev/null 2>&1 && { guests=$guests" client2"; }
	ip netns | grep lb2_s1 > /dev/null 2>&1 && { guests=$guests" server1"; }
	ip netns | grep lb2_s2 > /dev/null 2>&1 && { guests=$guests" server2"; }
	guests=$guests" balancer"
	echo -n $guests
}
topo_lb2_ifaces()
{
	case $1 in
		'client1') echo -n "eth1";;
		'client2') echo -n "eth1";;
		'balancer') echo -n "br0";;
		'server1') echo -n "eth1";;
		'server2') echo -n "eth1";;
	esac
}
topo_lb2_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                          Client1       Server1"
	echo "::                          (netns)---|---(netns)"
	echo "::                                    |"
	echo "::                                    |"
	echo "::                                    |"
	echo "::                          Client2---|---Server2"
	echo "::                          (netns)   |   (netns)"
	echo "::                                    |"
	echo "::                                    |"
	echo "::                                 Balancer"
	echo "::                                  (Host)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create "
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	ip netns add lb2_c1
	ip netns add lb2_c2
	ip netns add lb2_s1
	ip netns add lb2_s2
	ip link add name veth_lb2_c1 type veth peer name eth1 netns lb2_c1
	ip link add name veth_lb2_c2 type veth peer name eth1 netns lb2_c2
	ip link add name veth_lb2_s1 type veth peer name eth1 netns lb2_s1
	ip link add name veth_lb2_s2 type veth peer name eth1 netns lb2_s2
	ip link add name br0 type bridge
	ip link set br0 up
	for iface in veth_lb2_c1 veth_lb2_c2 veth_lb2_s1 veth_lb2_s2; do
		ip link set $iface master br0
		ip link set $iface up
	done
}
topo_lb2_destroy()
{
	topo_all_destroy
}

###########################################################
# Topo: Load Balance #3
###########################################################
# internal APIs
topo_lb3_run()
{
	local guest=$1; shift; local cmd=$@
	case $guest in
		'client1') topo_ns_run lb3_c1 $cmd;;
		'client2') topo_ns_run lb3_c2 $cmd;;
		'balancer') topo_lo_run $cmd;;
		'server1') topo_ns_run lb3_s1 $cmd;;
		'server2') topo_ns_run lb3_s2 $cmd;;
	esac
}
topo_lb3_guests()
{
	local guests
	ip netns | grep lb3_c1 > /dev/null 2>&1 && { guests=$guests" client1"; }
	ip netns | grep lb3_c2 > /dev/null 2>&1 && { guests=$guests" client2"; }
	ip netns | grep lb3_s1 > /dev/null 2>&1 && { guests=$guests" server1"; }
	ip netns | grep lb3_s2 > /dev/null 2>&1 && { guests=$guests" server2"; }
	guests=$guests" balancer"
	echo -n $guests
}
topo_lb3_ifaces()
{
	case $1 in
		'client1') echo -n "eth1";;
		'client2') echo -n "eth1";;
		'balancer') echo -n "br1 br2";;
		'server1') echo -n "eth1 eth2";;
		'server2') echo -n "eth1 eth2";;
	esac
}
topo_lb3_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                          Client1       Server1"
	echo "::                          (netns)---|---(netns)---|"
	echo "::                                    |             |"
	echo "::                                    |             |"
	echo "::                                    |             |"
	echo "::                          Client2---|---Server2---|"
	echo "::                          (netns)   |   (netns)   |"
	echo "::                                    |             |"
	echo "::                                    |             |"
	echo "::                                 Balancer---------|"
	echo "::                                  (Host)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create "
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	ip netns add lb3_c1
	ip netns add lb3_c2
	ip netns add lb3_s1
	ip netns add lb3_s2
	ip link add name veth_lb3_c11 type veth peer name eth1 netns lb3_c1
	ip link add name veth_lb3_c21 type veth peer name eth1 netns lb3_c2
	ip link add name veth_lb3_s11 type veth peer name eth1 netns lb3_s1
	ip link add name veth_lb3_s12 type veth peer name eth2 netns lb3_s1
	ip link add name veth_lb3_s21 type veth peer name eth1 netns lb3_s2
	ip link add name veth_lb3_s22 type veth peer name eth2 netns lb3_s2
	for iface in br1 br2; do
		ip link add name $iface type bridge
		ip link set $iface up
	done
	for iface in veth_lb3_c11 veth_lb3_c21 veth_lb3_s11 veth_lb3_s21; do
		ip link set $iface master br1
		ip link set $iface up
	done
	for iface in veth_lb3_s12 veth_lb3_s22; do
		ip link set $iface master br2
		ip link set $iface up
	done
}
topo_lb3_destroy()
{
	topo_all_destroy
}

###########################################################
# Topo: High Availability
###########################################################
# internal APIs
topo_ha_run()
{
	local guest=$1; shift; local cmd=$@
	case $guest in
		'client') topo_ns_run ha_c $cmd;;
		'fw01') topo_ns_run ha_fw1 $cmd;;
		'fw02') topo_ns_run ha_fw2 $cmd;;
		'server') topo_lo_run $cmd;;
	esac
}
topo_ha_guests()
{
	local guests
	ip netns | grep ha_c > /dev/null 2>&1 && { guests=$guests" client"; }
	ip netns | grep ha_fw1 > /dev/null 2>&1 && { guests=$guests" fw01"; }
	ip netns | grep ha_fw2 > /dev/null 2>&1 && { guests=$guests" fw02"; }
	guests=$guests" server"
	echo -n $guests
}
topo_ha_ifaces()
{
	case $1 in
		'client') echo -n "eth1";;
		'fw01') echo -n "eth1 eth2 eth3";;
		'fw02') echo -n "eth1 eth2 eth3";;
		'server') echo -n "br2";;
	esac
}
topo_ha_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                                  Client"
	echo "::                                  (netns)"
	echo "::                                     |"
	echo "::                             |---------------|"
	echo "::                             |               |"
	echo "::                           FW01-------------FW02"
	echo "::                          (netns)          (netns)"
	echo "::                             |               |"
	echo "::                             |---------------|"
	echo "::                                     |"
	echo "::                                   Server"
	echo "::                                   (host)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	ip netns add ha_c
	ip netns add ha_fw1
	ip netns add ha_fw2
	ip link add name veth_ha_c1 type veth peer name eth1 netns ha_c
	ip link add name veth_ha_fw11 type veth peer name eth1 netns ha_fw1
	ip link add name veth_ha_fw12 type veth peer name eth2 netns ha_fw1
	ip link add name veth_ha_fw13 type veth peer name eth3 netns ha_fw1
	ip link add name veth_ha_fw21 type veth peer name eth1 netns ha_fw2
	ip link add name veth_ha_fw22 type veth peer name eth2 netns ha_fw2
	ip link add name veth_ha_fw23 type veth peer name eth3 netns ha_fw2
	for iface in br1 br2 br3; do
		ip link add name $iface type bridge
		ip link set $iface up
	done
	for iface in veth_ha_c1 veth_ha_fw11 veth_ha_fw21; do
		ip link set $iface master br1
		ip link set $iface up
	done
	for iface in veth_ha_fw12 veth_ha_fw22; do
		ip link set $iface master br2
		ip link set $iface up
	done
	for iface in veth_ha_fw13 veth_ha_fw23; do
		ip link set $iface master br3
		ip link set $iface up
	done
}
topo_ha_destroy()
{
	topo_all_destroy
}

############################################################
# Topo: TC Forward
############################################################
# internal APIs
topo_tcf_run()
{
	local guest=$1; shift; local cmd=$@
	case $guest in
		'client') topo_ns_run tcf_c $cmd;;
		'server') topo_ns_run tcf_s $cmd;;
		'switch') topo_lo_run $cmd;;
	esac
}
topo_tcf_guests()
{
	local guests
	ip netns | grep tcf_c > /dev/null 2>&1 && { guests=$guests" client"; }
	ip netns | grep tcf_s > /dev/null 2>&1 && { guests=$guests" server"; }
	guests=$guests" switch"
	echo -n $guests
}
topo_tcf_ifaces()
{
	local vendor=$(topo_lo_run network_get_nic_vendor)
	if [ $vendor == "Netronome" ]; then
		local vfs_c=$(topo_ns_run tcf_c netronome_get_vfs)
		local vfs_s=$(topo_ns_run tcf_s netronome_get_vfs)
		local reps=$(topo_lo_run netronome_get_reps)
	elif [ $vendor == "Mellanox" ]; then
		local vfs_c=$(topo_ns_run tcf_c mellanox_get_vfs)
		local vfs_s=$(topo_ns_run tcf_s mellanox_get_vfs)
		local reps=$(topo_lo_run mellanox_get_reps)
	elif [ $vendor == "Broadcom" ]; then
		local vfs_c=$(topo_ns_run tcf_c broadcom_get_vfs)
		local vfs_s=$(topo_ns_run tcf_s broadcom_get_vfs)
		local reps=$(topo_lo_run broadcom_get_reps)
	else
		local vfs_c='eth1'
		local vfs_s='eth1'
		local reps='veth_tcf_c1 veth_tcf_s1'
	fi
	case $1 in
		'client') echo -n "$vfs_c";;
		'server') echo -n "$vfs_s";;
		'switch') echo -n "$reps";;
	esac
}
topo_tcf_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                     Client---|---Switch---|---Server"
	echo "::                     (netns)      (Host)       (netns)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create "
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	# setup NIC adapters
	local vendor=$(topo_lo_run network_get_nic_vendor)
	if [ $vendor == "Netronome" ]; then
		topo_lo_run netronome_setup 2
	fi
	if [ $vendor == "Mellanox" ]; then
		topo_lo_run mellanox_setup 2
	fi
	if [ $vendor == "Broadcom" ]; then
		topo_lo_run broadcom_setup 2
	fi

	# setup test environment
	ip netns add tcf_c
	ip netns add tcf_s
	if [ $vendor == "None" ]; then
		ip link add name veth_tcf_c1 type veth peer name eth1 netns tcf_c
		ip link add name veth_tcf_s1 type veth peer name eth1 netns tcf_s
	else
		if [ $vendor == "Netronome" ]; then
			local vfs=$(topo_lo_run netronome_get_vfs)
		fi
		if [ $vendor == "Mellanox" ]; then
			local vfs=$(topo_lo_run mellanox_get_vfs)
		fi
		if [ $vendor == "Broadcom" ]; then
			local vfs=$(topo_lo_run broadcom_get_vfs)
		fi
		local vf1=$(echo $vfs | cut -d ' ' -f 1)
		local vf2=$(echo $vfs | cut -d ' ' -f 2)
		ip link set $vf1 netns tcf_c
		ip link set $vf2 netns tcf_s
	fi
}
topo_tcf_destroy()
{
	topo_all_destroy
}

############################################################
# Topo: TC Forward #2
############################################################
# internal APIs
topo_tcf2_run()
{
	local guest=$1; shift; local cmd=$@
	case $guest in
		'client') topo_ns_run tcf2_c1 $cmd;;
		'server') topo_ns_run tcf2_s1 $cmd;;
		'monitor1') topo_ns_run tcf2_m1 $cmd;;
		'monitor2') topo_ns_run tcf2_m2 $cmd;;
		'switch1') topo_ns_run tcf2_sw1 $cmd;;
		'switch2') topo_ns_run tcf2_sw2 $cmd;;
	esac
}
topo_tcf2_guests()
{
	local guests
	ip netns | grep tcf2_c1 > /dev/null 2>&1 && { guests=$guests" client"; }
	ip netns | grep tcf2_s1 > /dev/null 2>&1 && { guests=$guests" server"; }
	ip netns | grep tcf2_m1 > /dev/null 2>&1 && { guests=$guests" monitor1"; }
	ip netns | grep tcf2_m2 > /dev/null 2>&1 && { guests=$guests" monitor2"; }
	ip netns | grep tcf2_sw1 > /dev/null 2>&1 && { guests=$guests" switch1"; }
	ip netns | grep tcf2_sw2 > /dev/null 2>&1 && { guests=$guests" switch2"; }
	echo -n $guests
}
topo_tcf2_ifaces()
{
	if [ "$MH_TC_VNIC" == "bond" ]; then
		local ifs_c="eth1 bond0 eth4 eth2 eth3"
		local ifs_s="eth1 bond0 eth4 eth2 eth3"
	elif [ "$MH_TC_VNIC" == "nic_vlan" ]; then
		local ifs_c="eth1 eth2.70 eth4"
		local ifs_s="eth1 eth2.70 eth4"
	elif [ "$MH_TC_VNIC" == "bond_vlan" ]; then
		local ifs_c="eth1 bond0.70 eth4 eth2 eth3"
		local ifs_s="eth1 bond0.70 eth4 eth2 eth3"
	else
		local ifs_c="eth1 eth2 eth4"
		local ifs_s="eth1 eth2 eth4"
	fi
	case $1 in
		'client') echo -n "eth1";;
		'server') echo -n "eth1";;
		'monitor1') echo -n "eth1";;
		'monitor2') echo -n "eth1";;
		'switch1') echo -n $ifs_c;;
		'switch2') echo -n $ifs_s;;
	esac
}
topo_tcf2_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::              Client                                  Server"
	echo "::              (netns)---|                         |---(netns)"
	echo "::                        |                         |"
	echo "::                        |---Switch1-----Switch2---|"
	echo "::                        |   (netns)     (netns)   |"
	echo "::              Monitor1--|                         |---Monitor2"
	echo "::              (netns)                                 (netns)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create "
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	ip netns add tcf2_c1
	ip netns add tcf2_s1
	ip netns add tcf2_m1
	ip netns add tcf2_m2
	ip netns add tcf2_sw1
	ip netns add tcf2_sw2
	ip link add name eth1 netns tcf2_c1 type veth peer name eth1 netns tcf2_sw1
	ip link add name eth1 netns tcf2_s1 type veth peer name eth1 netns tcf2_sw2
	ip link add name eth1 netns tcf2_m1 type veth peer name eth4 netns tcf2_sw1
	ip link add name eth1 netns tcf2_m2 type veth peer name eth4 netns tcf2_sw2
	ip link add name eth2 netns tcf2_sw1 type veth peer name eth2 netns tcf2_sw2
	ip link add name eth3 netns tcf2_sw1 type veth peer name eth3 netns tcf2_sw2
	ip netns exec tcf2_sw1 ip link set eth2 up
	ip netns exec tcf2_sw1 ip link set eth3 up
	ip netns exec tcf2_sw1 ip link set eth4 up
	ip netns exec tcf2_sw2 ip link set eth2 up
	ip netns exec tcf2_sw2 ip link set eth3 up
	ip netns exec tcf2_sw2 ip link set eth4 up

	# setup bonding
	if [ "$MH_TC_VNIC" == "bond" ] || [ "$MH_TC_VNIC" == "bond_vlan" ]; then
		local iface
		# setup bond0 on the switch1
		ip netns exec tcf2_sw1 modprobe bonding mode=1 miimon=100 max_bonds=0
		ip netns exec tcf2_sw1 ip link add name bond0 type bond
		ip netns exec tcf2_sw1 ip link set dev bond0 down
		for iface in eth2 eth3; do
			ip netns exec tcf2_sw1 ip link set dev $iface down
			ip netns exec tcf2_sw1 ip link set dev $iface master bond0
			ip netns exec tcf2_sw1 ip link set dev $iface up
			ip netns exec tcf2_sw1 ip link set dev $iface promisc on
		done
		ip netns exec tcf2_sw1 ip link set dev bond0 up
		# setup bond0 on the switch2
		ip netns exec tcf2_sw2 modprobe bonding mode=1 miimon=100 max_bonds=0
		ip netns exec tcf2_sw2 ip link add name bond0 type bond
		ip netns exec tcf2_sw2 ip link set dev bond0 down
		for iface in eth2 eth3; do
			ip netns exec tcf2_sw2 ip link set dev $iface down
			ip netns exec tcf2_sw2 ip link set dev $iface master bond0
			ip netns exec tcf2_sw2 ip link set dev $iface up
			ip netns exec tcf2_sw2 ip link set dev $iface promisc on
		done
		ip netns exec tcf2_sw2 ip link set dev bond0 up
	fi

	# setup vlan
	if [ "$MH_TC_VNIC" == "nic_vlan" ]; then
		# setup vlan on the switch1
		ip netns exec tcf2_sw1 ip link add link eth2 name eth2.70 type vlan id 70
		ip netns exec tcf2_sw1 ip link set eth2.70 up
		# setup vlan on the switch2
		ip netns exec tcf2_sw2 ip link add link eth2 name eth2.70 type vlan id 70
		ip netns exec tcf2_sw2 ip link set eth2.70 up
	fi

	# setup bonding & vlan
	if [ "$MH_TC_VNIC" == "bond_vlan" ]; then
		# setup vlan on the switch1
		ip netns exec tcf2_sw1 ip link add link bond0 name bond0.70 type vlan id 70
		ip netns exec tcf2_sw1 ip link set bond0.70 up
		ip netns exec tcf2_sw1 ip link set dev bond0 promisc on
		# setup vlan on the switch2
		ip netns exec tcf2_sw2 ip link add link bond0 name bond0.70 type vlan id 70
		ip netns exec tcf2_sw2 ip link set bond0.70 up
		ip netns exec tcf2_sw2 ip link set dev bond0 promisc on
	fi
}
topo_tcf2_destroy()
{
	topo_all_destroy
}

