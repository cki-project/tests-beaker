#!/bin/sh

###########################################################
# Common functions definition for vm infra
###########################################################
topo_guest_start()
{
	local guest=$1
	[ -z $2 ] && { local nic_num=2; } || { local nic_num=$2; }
	if vinfo -n $guest > /dev/null 2>&1; then
		vchange $guest
		vrsync ~/.profile
		vssh "source ~/.profile && /mnt/tests/kernel/networking/firewall/000infralib/runtest.sh"
	else
		# ssh key installing has been finished in vstart process
		vstart $guest
		ip link set dev tap_${guest}_1 nomaster
		ip link set dev tap_${guest}_2 nomaster
		# use repos from the host instead of the latest one for RHEL-8
		test -e /etc/yum.repos.d/beaker-BaseOS.repo && { vrsync /etc/yum.repos.d/beaker-BaseOS.repo; }
		test -e /etc/yum.repos.d/beaker-BaseOS-debuginfo.repo && { vrsync /etc/yum.repos.d/beaker-BaseOS-debuginfo.repo; }
		test -e /etc/yum.repos.d/beaker-AppStream.repo && { vrsync /etc/yum.repos.d/beaker-AppStream.repo; }
		test -e /etc/yum.repos.d/beaker-AppStream-debuginfo.repo && { vrsync /etc/yum.repos.d/beaker-AppStream-debuginfo.repo; }
		test -e /etc/yum.repos.d/beaker-HighAvailability.repo && { vrsync /etc/yum.repos.d/beaker-HighAvailability.repo; }
		test -e /etc/yum.repos.d/beaker-HighAvailability-debuginfo.repo && { vrsync /etc/yum.repos.d/beaker-HighAvailability-debuginfo.repo; }
		# use repos from the host instead of the latest one for RHEL-7
		test -e /etc/yum.repos.d/beaker-Server.repo && { vrsync /etc/yum.repos.d/beaker-Server.repo; }
		test -e /etc/yum.repos.d/beaker-Server-debuginfo.repo && { vrsync /etc/yum.repos.d/beaker-Server-debuginfo.repo; }
		test -e /etc/yum.repos.d/beaker-Server-optional.repo && { vrsync /etc/yum.repos.d/beaker-Server-optional.repo; }
		test -e /etc/yum.repos.d/beaker-Server-optional-debuginfo.repo && { vrsync /etc/yum.repos.d/beaker-Server-optional-debuginfo.repo; }
		# test -e /etc/yum.repos.d/beaker-LoadBalancer.repo && { vrsync /etc/yum.repos.d/beaker-LoadBalancer.repo; }
		vssh ${YUM} clean all
		vssh ${YUM} rm -rf /var/cache/yum
		vssh ${YUM} install kernel-kernel-networking-firewall-000infralib -y
		vrsync ~/.profile
		vssh "source ~/.profile && rm -f ~/.profile && /mnt/tests/kernel/networking/firewall/000infralib/runtest.sh"
	fi
	if $MH_IS_DEBUG; then
		vssh ${YUM} reinstall kernel-kernel-networking-firewall-000infralib -y
		vssh mkdir -p $MH_COMMON_ROOT
		vssh mkdir -p $MH_INFRA_ROOT
		vrsync $MH_COMMON_ROOT
		vrsync $MH_INFRA_ROOT
		vrsync ~/.profile
		vssh "source ~/.profile && rm -f ~/.profile && /mnt/tests/kernel/networking/firewall/000infralib/runtest.sh"
	fi
	if ! ( vssh uname -r | grep -q $MH_KERNEL ); then
		if [ "${MH_KERNEL##*.}" == "debug" ]; then
			vkernel $(echo $MH_KERNEL | cut -d '.' -f -4) debug
		else
			vkernel $(echo $MH_KERNEL | cut -d '.' -f -4)
		fi
		vrsync ~/.profile
		vssh "source ~/.profile && rm -f ~/.profile && /mnt/tests/kernel/networking/firewall/000infralib/runtest.sh"
	fi
	if [ $nic_num -gt 2 ]; then
		for count in $(seq 3 $nic_num); do
			vnic -n $guest -t tap add tap_${guest}_${count}
			ip link set tap_${guest}_${count} up
		done
	fi
}
topo_guest_innerifs()
{
	local guest=$1
	local nic_num=$2
	local start=$(echo $nic_num | cut -d '-' -f 1)
	local stop=$(echo $nic_num | cut -d '-' -f 2)
	local ifacelist=""; local count=0;
	for count in $(seq $start $stop); do
		local ifname=eth${count}
		vssh -n $guest ip link show dev $ifname > /dev/null 2>&1 || { continue; }
		ifacelist=$ifacelist" "$ifname
	done
	echo -n "$ifacelist"
}
topo_guest_outerifs()
{
	local guest=$1
	local nic_num=$2
	local start=$(echo $nic_num | cut -d '-' -f 1)
	local stop=$(echo $nic_num | cut -d '-' -f 2)
	local ifacelist=""; local count=0;
	for count in $(seq $start $stop); do
		local ifname=tap_${guest}_${count}
		ip link show dev $ifname > /dev/null 2>&1 || { continue; }
		ifacelist=$ifacelist" "$ifname
	done
	echo -n "$ifacelist"
}
topo_all_destroy()
{
	local ifname
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests destroy "
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	for ifname in $(bridge link | grep -v 'master br_wan' | grep -v 'master br_lan' | awk '{print $7}' | uniq); do
	 	ip link del dev $ifname
	done
}

###########################################################
# Topo: Client Server
###########################################################
# internal APIs
topo_cs_run()
{
	local guest=$1; shift
	local cmd=$@
	case $guest in
		'client') topo_vm_run c1 $cmd;;
		'server') topo_vm_run s1 $cmd;;
	esac
}
topo_cs_guests()
{
	local guests
	vinfo -n c1 > /dev/null 2>&1 && { guests=$guests" client"; }
	vinfo -n s1 > /dev/null 2>&1 && { guests=$guests" server"; }
	echo -n $guests
}
topo_cs_ifaces()
{
	case $1 in
		'client') echo -n "$(topo_guest_innerifs c1 1-1)";;
		'server') echo -n "$(topo_guest_innerifs s1 1-1)";;
	esac
}
topo_cs_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                            Client---Server"
	echo "::                            (KVM)     (KVM)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create & packages install"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_guest_start c1 2
	topo_guest_start s1 2
	ip link add name br1 type bridge
	ip link set br1 up
	for iface in $(topo_guest_outerifs c1 1-1) $(topo_guest_outerifs s1 1-1);do
		ip link set $iface master br1
		ip link set $iface up
	done
}
topo_cs_destroy()
{
	topo_all_destroy
}

###########################################################
# Topo: Route Forward
###########################################################
# internal APIs
topo_rf_run()
{
	local guest=$1; shift
	local cmd=$@
	case $guest in
		'client') topo_vm_run c1 $cmd;;
		'router') topo_vm_run r1 $cmd;;
		'server') topo_vm_run s1 $cmd;;
	esac
}
topo_rf_guests()
{
	local guests
	vinfo -n c1 > /dev/null 2>&1 && { guests=$guests" client"; }
	vinfo -n r1 > /dev/null 2>&1 && { guests=$guests" router"; }
	vinfo -n s1 > /dev/null 2>&1 && { guests=$guests" server"; }
	echo -n $guests
}
topo_rf_ifaces()
{
	case $1 in
		'client') echo -n "$(topo_guest_innerifs c1 1-1)";;
		'router') echo -n "$(topo_guest_innerifs r1 1-2)";;
		'server') echo -n "$(topo_guest_innerifs s1 1-1)";;
	esac
}
topo_rf_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                         Client---Router---Server"
	echo "::                         (KVM)    (KVM)    (KVM)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create & packages install"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_guest_start c1 2
	topo_guest_start r1 2
	topo_guest_start s1 2
	for iface in br1 br2; do
		ip link add name $iface type bridge
		ip link set $iface up
	done
	for iface in $(topo_guest_outerifs c1 1-1) $(topo_guest_outerifs r1 1-1); do
		ip link set $iface master br1
		ip link set $iface up
	done
	for iface in $(topo_guest_outerifs s1 1-1) $(topo_guest_outerifs r1 2-2); do
		ip link set $iface master br2
		ip link set $iface up
	done
}
topo_rf_destroy()
{
	topo_all_destroy
}

###########################################################
# Topo: Load Balance
###########################################################
# internal APIs
topo_lb_run()
{
	local guest=$1; shift
	local cmd=$@
	case $guest in
		'client1') topo_vm_run c1 $cmd;;
		'client2') topo_vm_run c2 $cmd;;
		'balancer') topo_vm_run r1 $cmd;;
		'server1') topo_vm_run s1 $cmd;;
		'server2') topo_vm_run s2 $cmd;;
	esac
}
topo_lb_guests()
{
	local guests
	vinfo -n c1 > /dev/null 2>&1 && { guests=$guests" client1"; }
	vinfo -n c2 > /dev/null 2>&1 && { guests=$guests" client2"; }
	vinfo -n r1 > /dev/null 2>&1 && { guests=$guests" balancer"; }
	vinfo -n s1 > /dev/null 2>&1 && { guests=$guests" server1"; }
	vinfo -n s2 > /dev/null 2>&1 && { guests=$guests" server2"; }
	echo -n $guests
}
topo_lb_ifaces()
{
	case $1 in
		'client1') echo -n "$(topo_guest_innerifs c1 1-1)";;
		'client2') echo -n "$(topo_guest_innerifs c2 1-1)";;
		'balancer') echo -n "$(topo_guest_innerifs r1 1-2)";;
		'server1') echo -n "$(topo_guest_innerifs s1 1-1)";;
		'server2') echo -n "$(topo_guest_innerifs s2 1-1)";;
	esac
}
topo_lb_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                    Client1                      Server1"
	echo "::                     (KVM)----|              |----(KVM)"
	echo "::                              |              |"
	echo "::                              |---Balancer---|"
	echo "::                              |    (KVM)     |"
	echo "::                    Client2---|              |---Server2"
	echo "::                     (KVM)                        (KVM)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create & packages install"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_guest_start c1 2
	topo_guest_start c2 2
	topo_guest_start r1 2
	topo_guest_start s1 2
	topo_guest_start s2 2
	for iface in br1 br2; do
		ip link add name $iface type bridge
		ip link set $iface up
	done
	for iface in $(topo_guest_outerifs c1 1-1) $(topo_guest_outerifs c2 1-1) $(topo_guest_outerifs r1 1-1); do
		ip link set $iface master br1
		ip link set $iface up
	done
	for iface in $(topo_guest_outerifs s1 1-1) $(topo_guest_outerifs s2 1-1) $(topo_guest_outerifs r1 2-2); do
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
	local guest=$1; shift
	local cmd=$@
	case $guest in
		'client1') topo_vm_run c1 $cmd;;
		'client2') topo_vm_run c2 $cmd;;
		'balancer') topo_vm_run r1 $cmd;;
		'server1') topo_vm_run s1 $cmd;;
		'server2') topo_vm_run s2 $cmd;;
	esac
}
topo_lb2_guests()
{
	local guests
	vinfo -n c1 > /dev/null 2>&1 && { guests=$guests" client1"; }
	vinfo -n c2 > /dev/null 2>&1 && { guests=$guests" client2"; }
	vinfo -n r1 > /dev/null 2>&1 && { guests=$guests" balancer"; }
	vinfo -n s1 > /dev/null 2>&1 && { guests=$guests" server1"; }
	vinfo -n s2 > /dev/null 2>&1 && { guests=$guests" server2"; }
	echo -n $guests
}
topo_lb2_ifaces()
{
	case $1 in
		'client1') echo -n "$(topo_guest_innerifs c1 1-1)";;
		'client2') echo -n "$(topo_guest_innerifs c2 1-1)";;
		'balancer') echo -n "$(topo_guest_innerifs r1 1-1)";;
		'server1') echo -n "$(topo_guest_innerifs s1 1-1)";;
		'server2') echo -n "$(topo_guest_innerifs s2 1-1)";;
	esac
}
topo_lb2_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                    Client1   Client2   Server1   Server2"
	echo "::                     (KVM)     (KVM)     (KVM)     (KVM)"
	echo "::                       |         |         |         |"
	echo "::                       -------------------------------"
	echo "::                                      |"
	echo "::                                   Balancer"
	echo "::                                    (KVM)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create & packages install"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_guest_start c1 2
	topo_guest_start c2 2
	topo_guest_start r1 2
	topo_guest_start s1 2
	topo_guest_start s2 2
	ip link add name br1 type bridge
	ip link set br1 up
	for iface in $(topo_guest_outerifs c1 1-1) $(topo_guest_outerifs c2 1-1) $(topo_guest_outerifs r1 1-1) $(topo_guest_outerifs s1 1-1) $(topo_guest_outerifs s2 1-1); do
		ip link set $iface master br1
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
	local guest=$1; shift
	local cmd=$@
	case $guest in
		'client1') topo_vm_run c1 $cmd;;
		'client2') topo_vm_run c2 $cmd;;
		'balancer') topo_vm_run r1 $cmd;;
		'server1') topo_vm_run s1 $cmd;;
		'server2') topo_vm_run s2 $cmd;;
	esac
}
topo_lb3_guests()
{
	local guests
	vinfo -n c1 > /dev/null 2>&1 && { guests=$guests" client1"; }
	vinfo -n c2 > /dev/null 2>&1 && { guests=$guests" client2"; }
	vinfo -n r1 > /dev/null 2>&1 && { guests=$guests" balancer"; }
	vinfo -n s1 > /dev/null 2>&1 && { guests=$guests" server1"; }
	vinfo -n s2 > /dev/null 2>&1 && { guests=$guests" server2"; }
	echo -n $guests
}
topo_lb3_ifaces()
{
	case $1 in
		'client1') echo -n "$(topo_guest_innerifs c1 1-1)";;
		'client2') echo -n "$(topo_guest_innerifs c2 1-1)";;
		'balancer') echo -n "$(topo_guest_innerifs r1 1-2)";;
		'server1') echo -n "$(topo_guest_innerifs s1 1-2)";;
		'server2') echo -n "$(topo_guest_innerifs s2 1-2)";;
	esac
}
topo_lb3_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                          Client1       Server1"
	echo "::                           (KVM)----|----(KVM)----|"
	echo "::                                    |             |"
	echo "::                                    |             |"
	echo "::                                    |             |"
	echo "::                          Client2---|---Server2---|"
	echo "::                           (KVM)    |    (KVM)    |"
	echo "::                                    |             |"
	echo "::                                    |             |"
	echo "::                                 Balancer---------|"
	echo "::                                  (KVM)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create & packages install"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_guest_start c1 2
	topo_guest_start c2 2
	topo_guest_start r1 2
	topo_guest_start s1 2
	topo_guest_start s2 2
	for iface in br1 br2; do
		ip link add name $iface type bridge
		ip link set $iface up
	done
	for iface in $(topo_guest_outerifs c1 1-1) $(topo_guest_outerifs c2 1-1) $(topo_guest_outerifs r1 1-1) $(topo_guest_outerifs s1 1-1) $(topo_guest_outerifs s2 1-1); do
		ip link set $iface master br1
		ip link set $iface up
	done
	for iface in $(topo_guest_outerifs r1 2-2) $(topo_guest_outerifs s1 2-2) $(topo_guest_outerifs s2 2-2); do
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
	local guest=$1; shift
	local cmd=$@
	case $guest in
		'client') topo_vm_run c1 $cmd;;
		'fw01') topo_vm_run r1 $cmd;;
		'fw02') topo_vm_run r2 $cmd;;
		'server') topo_vm_run s1 $cmd;;
	esac
}
topo_ha_guests()
{
	local guests
	vinfo -n c1 > /dev/null 2>&1 && { guests=$guests" client"; }
	vinfo -n r1 > /dev/null 2>&1 && { guests=$guests" fw01"; }
	vinfo -n r2 > /dev/null 2>&1 && { guests=$guests" fw02"; }
	vinfo -n s1 > /dev/null 2>&1 && { guests=$guests" server"; }
	echo -n $guests
}
topo_ha_ifaces()
{
	case $1 in
		'client') echo -n "$(topo_guest_innerifs c1 1-1)";;
		'fw01') echo -n "$(topo_guest_innerifs r1 1-3)";;
		'fw02') echo -n "$(topo_guest_innerifs r2 1-3)";;
		'server') echo -n "$(topo_guest_innerifs s1 1-1)";;
	esac
}
topo_ha_create()
{
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: Controller: Host"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo "::                                   Client"
	echo "::                                   (KVM)"
	echo "::                                     |"
	echo "::                             |---------------|"
	echo "::                             |               |"
	echo "::                           FW#01-----------FW#02"
	echo "::                           (KVM)           (KVM)"
	echo "::                             |               |"
	echo "::                             |---------------|"
	echo "::                                     |"
	echo "::                                   Server"
	echo "::                                   (KVM)"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	echo ":: [  BEGIN   ] :: guests create & packages install"
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
	topo_guest_start c1 2
	topo_guest_start r1 3
	topo_guest_start r2 3
	topo_guest_start s1 2
	for iface in br1 br2 br3; do
		ip link add name $iface type bridge
		ip link set $iface up
	done
	for iface in $(topo_guest_outerifs c1 1-1) $(topo_guest_outerifs r1 1-1) $(topo_guest_outerifs r2 1-1); do
		ip link set $iface master br1
		ip link set $iface up
	done
	for iface in $(topo_guest_outerifs s1 1-1) $(topo_guest_outerifs r1 2-2) $(topo_guest_outerifs r2 2-2); do
		ip link set $iface master br2
		ip link set $iface up
	done
	for iface in $(topo_guest_outerifs r1 3-3) $(topo_guest_outerifs r2 3-3); do
		ip link set $iface master br3
		ip link set $iface up
	done
}
topo_ha_destroy()
{
	topo_all_destroy
}

