#!/bin/bash
#
# Copyright (c) 2013 Red Hat, Inc. All rights reserved.
#
# This copyrighted material is made available to anyone wishing
# to use, modify, copy, or redistribute it subject to the terms
# and conditions of the GNU General Public License version 2.
#
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
#

###############################################################################
vm_get_default_iface()
{
	local vm=$1
        if [ $(GetDistroRelease) -gt 7 ];then
                local def_dev=`/usr/libexec/platform-python run.py $vm "ip route" | grep default | awk '{print $5}'`
        else
                local def_dev=`python run.py $vm "ip route" | grep default | awk '{print $5}'`
        fi
	
	echo $def_dev
}

######
vm_get_default_ip4addr()
{
	local vm=$1
	local def_dev_name=$(vm_get_default_iface $vm)
	if [ -n "$def_dev_name" ]; then
	                if [ $(GetDistroRelease) -gt 7 ];then
                        local ip4addr=`/usr/libexec/platform-python run.py $vm "ip addr show dev $def_dev_name" | awk '/inet /{print $2}' | awk -F'/' '{print $1}'`
                else
                        local ip4addr=`python run.py $vm "ip addr show dev $def_dev_name" | awk '/inet /{print $2}' | awk -F'/' '{print $1}'`
                fi
                        echo $ip4addr
	fi
}

######
vm_get_test_dev()
{
	local vm=$1
	local mac_addr=$2
	if [ $(GetDistroRelease) -gt 7 ];then
                local test_dev=` /usr/libexec/platform-python run.py $vm "ip link show" | grep -i -m 1 -B 1 $mac_addr | awk -F': ' 'NR==1 {print $2}'`
        else
                local test_dev=`python run.py $vm "ip link show" | grep -i -m 1 -B 1 $mac_addr | awk -F': ' 'NR==1 {print $2}'`
        fi
	echo $test_dev
}

######
vm_get_test_dev_ip4addr()
{
	local vm=$1
	local mac_addr=$2
        if [ $(GetDistroRelease) -gt 7 ];then
                local ip4addr=`/usr/libexec/platform-python run.py $vm "ip addr show" | grep -i -m 1 -A 1 $mac_addr |awk '/inet /{print $2}' |awk -F'/' '{print $1}'`
        else
                local ip4addr=`python run.py $vm "ip addr show" | grep -i -m 1 -A 1 $mac_addr |awk '/inet /{print $2}' |awk -F'/' '{print $1}'`
        fi

	echo $ip4addr
}

######
vm_get_test_dev_ip6addr()
{
	local vm=$1
	local mac_addr=$2
        if [ $(GetDistroRelease) -gt 7 ];then
                local ip6addr=`/usr/libexec/platform-python run.py $vm "ip addr show" | grep -i -m 1 -A 2 $mac_addr |grep 'global' |awk '/inet6 /{print $2}' |awk -F'/' '{print $1}'`
        else
                local ip6addr=`python run.py $vm "ip addr show" | grep -i -m 1 -A 2 $mac_addr |grep 'global' |awk '/inet6 /{print $2}' |awk -F'/' '{print $1}'`
        fi

	echo $ip6addr
}

######
vm_set_test_dev_ip4addr()
{
	local vm=$1
	local mac_addr=$2
	local ip4addr=$3
	local test_dev=$(vm_get_test_dev $vm $mac_addr)
	if [ -n "$test_dev" ]; then
	                if [ $(GetDistroRelease) -gt 7 ];then
                        #./run.py $vm "ip addr add $ip4addr dev $test_dev"
                        /usr/libexec/platform-python run.py $vm "ifconfig $test_dev $ip4addr up"
                else
                        python run.py $vm "ifconfig $test_dev $ip4addr up"
                fi
                sleep 1

	fi
}

######
vm_set_test_dev_ip6addr()
{
	local vm=$1
	local mac_addr=$2
	local ip6addr=$3
	local test_dev=$(vm_get_test_dev $vm $mac_addr)
	if [ -n "$test_dev" ]; then
                if [ $(GetDistroRelease) -gt 7 ];then
                        /usr/libexec/platform-python run.py $vm "echo 0 > /proc/sys/net/ipv6/conf/${test_dev}/disable_ipv6"
                        sleep 1
                        /usr/libexec/platform-python run.py $vm "ip addr add $ip6addr/64 dev $test_dev"
                else
                        python run.py $vm "echo 0 > /proc/sys/net/ipv6/conf/${test_dev}/disable_ipv6"
                        sleep 1
                        python run.py $vm "ip addr add $ip6addr/64 dev $test_dev"
                fi

	fi
}

######
vm_set_test_dev_mtu()
{
	local vm=$1
	local mac_addr=$2
	local mtu=$3
	local test_dev=$(vm_get_test_dev $vm $mac_addr)
	if [ -n "$test_dev" ]; then
                if [ $(GetDistroRelease) -gt 7 ];then
                        /usr/libexec/platform-python  run.py $vm "ip link set $test_dev mtu $mtu"
                else
                        python run.py $vm "ip link set $test_dev mtu $mtu"
                fi

	fi
}

######
vm_upload_testcase()
{
	local vm=$1
	local files=$2
	local host_ip=$(vm_get_default_ip4addr $vm)
	if [ -n "$host_ip" ]; then
                if [ $(GetDistroRelease) -gt 7 ];then
                        /usr/libexec/platform-python scp.py $files root $host_ip redhat
                else
                        python scp.py $files root $host_ip redhat
                fi

	fi
}

######
vm_download_file()
{
	local vm=$1
	local files=$2
	local host_ip=$(vm_get_default_ip4addr $vm)
	if [ -n "$host_ip" ]; then
                if [ $(GetDistroRelease) -gt 7 ];then
                        /usr/libexec/platform-python scp.py $files root $host_ip redhat
                else
                        python scp.py $files root $host_ip redhat
                fi

	fi
}

libvirtd_start()
{
        if [ "$(get_rhel_major_verison)" -ge 7 ]; then
                systemctl start libvirtd
        else
                service libvirtd start
        fi  
}

###############################################################################
kvm_install()
{
	#install kvm and libvirtd
	/usr/libexec/qemu-kvm -version > /dev/null
	if [ $? != 0 ];then
		if [ $(GetDistroRelease) = 7 ];then
                        yum install -y qemu-kvm qemu-img qemu-kvm-common qemu-kvm-tools
                elif [ $(GetDistroRelease) = 8 ];then
                        yum install -y qemu-kvm  qemu-img qemu-kvm-common 
                else
                        echo "qemu-kvm does not support current system version"
                fi
		yum install -y  --skip-broken libvirt libvirt-python virt-viewer virt-manager virt-install
		libvirtd_start
                systemctl start virtlogd.socket
	fi

}

######
packages_install()
{
	#install ifconfig
	rpm -qa |grep -q net-tools || yum install -y net-tools

	#install pexpect
	rpm -qa |grep -q pexpect || yum install -y  pexpect

}

######
host_environment_init()
{
        #install the dependency packages 
        packages_install

        #install kvm and libvirtd
        kvm_install
}

######image_file=RHEL-Server-7.0-64-virtio.qcow2
get_image_file()
{
	local image_file=$1
	local image_seq=$2
	if hostname | grep "pek2.redhat.com" &>/dev/null
	then
		wget -q http://netqe-bj.usersys.redhat.com/share/vms/$image_file
	else
		wget -q http://netqe-infra01.knqe.lab.eng.bos.redhat.com/share/vms/RHEL/$image_file
	fi
	mv $image_file /var/lib/libvirt/images/$image_seq-$image_file
	if [ -e /var/lib/libvirt/images/$image_seq-$image_file ]; then
		echo "$image_seq-$image_file"
	else
		echo ""
	fi
}

######input(beaker-br, beaker-eth)
setup_beaker_br0()
{
	local host_br=$1
	local eth=$2

	#brctl show |grep -q $host_br && return 0
	#brctl addbr $host_br && brctl addif $host_br $eth || return 1
	ip link show type bridge |grep -q $host_br && return 0
	ip link add dev $host_br type bridge && ip link set dev $eth master $host_br || return 1
	pkill -9 dhclient > /dev/null; sleep 1; dhclient $host_br || return 1
	ip addr flush $eth
	return 0
}

######
vm_get_macaddr()
{
        rstr=`date +%s`
        vm_macaddr=00:${rstr:0:2}:${rstr:2:2}:${rstr:4:2}:${rstr:6:2}:${rstr:8:2}
        sleep 1
        echo $vm_macaddr
}

######
#depends on beaker-br0
######
vm_start()
{
	local vm_name=$1
	local image=$2
	local macaddr_0=$3
	local host_br=$4

	if ! virsh list | grep -q $vm_name; then

		virt-install --name $vm_name --ram=2048 --vcpus=2 \
		--disk path=/var/lib/libvirt/images/$image,device=disk,bus=virtio,format=qcow2 \
		--boot hd \
		--network bridge=$host_br,model=virtio,mac=$macaddr_0 \
		--graphics vnc,listen=0.0.0.0 \
		--wait=2 \
		--accelerate \
		--force  > /dev/null 2>&1
	fi
	sleep 5
	if [ "$(get_rhel_major_verison)" -gt 7 ]; then
		if ip link show vnet1 |grep -q master; then
			ip link set vnet1 nomaster
		fi
	else
	       if brctl show  |grep -q vnet1; then
	       		brctl delif virbr0 vnet1
		fi		
	fi

	return 0
}

#######global var(vm_name, vm1_macaddr_0, beaker_br)######
vm_environment_init()
{
		image_num=$1
        ##global(vm1_macaddr_0 vm1_macaddr_1)
        vm1_macaddr_0=$(vm_get_macaddr)
        echo "vm_get_macaddr vm1_macaddr_0=$vm1_macaddr_0"

        local guest_image=$(get_image_file $image_name $image_num)
        if [ "x$guest_image" != "x" ]; then
                echo "get_image_file success, image=$guest_image"
        else
                { echo "get_image_file fail"; return 1;}
        fi

        vm_start $vm_name $guest_image $vm1_macaddr_0 $beaker_br || \
{ echo "vm_start fail" ; return 1;} && echo "vm_start success"

        sleep 10

        vm_NetworkManager_stop $vm_name || \
{ echo "vm_NetworkManager_stop fail" ;} && echo "vm_NetworkManager_stop success"

        vm_firewall_stop $vm_name || \
{ echo "vm_firewall_stop fail"; } && echo "vm_firewall_stop success"
	return 0

}

#########################################################################################
get_rhel_major_verison()
{
	sed 's/[^0-9\.]//g' /etc/redhat-release |awk -F'.' '{print $1}'
}

vm_NetworkManager_stop()
{
	local vm=$1
	        if [ "$(get_rhel_major_verison)" -gt 7 ]; then
                /usr/libexec/platform-python run.py $vm "systemctl stop NetworkManager"
        elif [ "$(get_rhel_major_verison)" -eq 7 ];then
                python run.py $vm "systemctl stop NetworkManager"
        else
                python run.py $vm "service NetworkManager stop"
	fi
}

vm_firewall_stop()
{
	local vm=$1
        if [ "$(get_rhel_major_verison)" -gt 7 ]; then
                /usr/libexec/platform-python run.py $vm "systemctl stop firewalld.service"
                /usr/libexec/platform-python run.py $vm "iptables -F"
                /usr/libexec/platform-python run.py $vm "ip6tables -F"
                /usr/libexec/platform-python run.py $vm "setenforce 0"
        elif [ "$(get_rhel_major_verison)" -eq 7 ];then
                python run.py $vm "systemctl stop firewalld.service"
                python run.py $vm "iptables -F"
                python run.py $vm "ip6tables -F"
                python run.py $vm "setenforce 0"
        else
                python run.py $vm "service iptables stop"
                python run.py $vm "service ip6tables stop"
                python run.py $vm "iptables -F"
                python run.py $vm "ip6tables -F"
                python run.py $vm "setenforce 0"
        fi

}

###############################################################################

######input(driver name)
driver_vf_create()
{
	local CUR_DRIVER=$1
	case $CUR_DRIVER in

		mlx4_en)
		CUR_DRIVER="mlx4_core"
		kernel_opt=num_vfs
		;;
		default)
		echo "driver do not support SR-IOV"
		return
		;;
	esac
	modprobe -rv $CUR_DRIVER
	if [ x$CUR_DRIVER == x"mlx4_en" ]; then
		CUR_DRIVER="mlx4_core"
	fi
	modprobe $CUR_DRIVER ${kernel_opt}=2
	if [ $? -ne 0 ]; then
		echo "$CUR_DRIVER create vf fail"
		return 1
	fi
}

######input(DRIVER, IF,mac_addr), output(DRIVER_vf.xml)
be2net_vf_create()
{
	local DRIVER=$1
	local IF=$2
	local mac_addr=$3
	local COUNT="30"   #be2net can creste 30 VFs per interface.
	local pci_addr=$(ethtool -i $IF | awk '/^bus-info:/ {print $NF}')

	modprobe -rv $DRIVER
	sleep 1
	modprobe -v $DRIVER num_vfs=$COUNT
	sleep 1
	ip link set $IF up
	if [ $(ls -l /sys/bus/pci/devices/$pci_addr/virtfn* |wc -l) != $COUNT ]; then
		echo "${DRIVER}_create_vf fail"
		exit 1
	fi

	pf_pci_addr=$(echo "pci_${pci_addr}" | sed -e 's/:/_/g' -e 's/\./_/g')
	echo "physical function pci addr $pf_pci_addr"
	vf_xml_info=$(virsh nodedev-dumpxml $pf_pci_addr |grep -A $COUNT "virt_functions" |tail -n 1 |sed -e "s|address|address type=\'pci\'|g")
	[ -z "$vf_xml_info" ] && { echo "vf_xml_info=$vf_xml_info, fail"; exit 1;}
	echo "virtual function pci info $vf_xml_info"

cat > ${DRIVER}_vf.xml << _EOF
<interface type='hostdev' managed='yes'>
  <source>
    $vf_xml_info
  </source>
  <mac address='$mac_addr'/>
</interface>

_EOF

}

######for igb, ixgbe, bnx2x, qlcnic
######input(DRIVER, IF,mac_addr), output(DRIVER_vf.xml)
pci_vf_create()
{
	local DRIVER=$1
	local IF=$2
	local mac_addr=$3
	local pci_addr=$(ethtool -i $IF | awk '/^bus-info:/ {print $NF}')
	ip link set $IF up
	local COUNT=$(cat /sys/bus/pci/devices/$pci_addr/sriov_totalvfs)
	sleep 1
	echo $COUNT > /sys/bus/pci/devices/$pci_addr/sriov_numvfs
	sleep 2
	if [ $(ls -l /sys/bus/pci/devices/$pci_addr/virtfn* |wc -l) != $COUNT ]; then
		echo "${DRIVER}_create_vf fail"
		exit 1
	fi

	pf_pci_addr=$(echo "pci_${pci_addr}" | sed -e 's/:/_/g' -e 's/\./_/g')
	echo "physical function pci addr $pf_pci_addr"
	vf_xml_info=$(virsh nodedev-dumpxml $pf_pci_addr |grep -A $COUNT "virt_functions" |tail -n 1 |sed -e "s|address|address type=\'pci\'|g")
	[ -z $vf_xml_info ] && { echo "vf_xml_info=$vf_xml_info, fail"; exit 1;}
	echo "virtual function pci info $vf_xml_info"

cat > ${DRIVER}_vf.xml << _EOF
<interface type='hostdev' managed='yes'>
  <source>
    $vf_xml_info
  </source>
  <mac address='$mac_addr'/>
</interface>

_EOF

}

change_sys_pw()
{
	echo "change root password of the system"
	(echo "redhat"; sleep 1; echo "redhat" ) |passwd
}

check_iommu()
{
	cat /var/log/messages |grep "Intel-IOMMU: enabled"
	if [ $? -ne 0 ]; then
		echo "test fail, Intel-IOMMU not enabled!!!!!!"
		exit 1
	fi
}

stop_unused_network_service()
{
	if [ $(GetDistroRelease) = 7 ]; then
		/usr/bin/systemctl stop NetworkManager || service NetworkManager stop
	fi
}

get_client_vm_ip()
{
	local name=$1
	local i
	for i in `seq 0 10`
	do
		client_vm_ipaddr=$(vm_get_default_ip4addr $name)
		if [ -n "$client_vm_ipaddr" ]; then
			echo "get client_vm_ipaddr=$client_vm_ipaddr, success"
			break
		fi
		sleep 5
	done
	if [ x"$client_vm_ipaddr" = x"" ]; then
		echo "get client_vm_ipaddr=$client_vm_ipaddr, fail"
		exit 1
	fi
}

setup_default_vm()
{
	image_num=$1
	change_sys_pw
	stop_unused_network_service
	host_environment_init
	local default_eth=$(get_default_iface)
	local default_br=${2:-'beaker-br0'}
	beaker_eth=${beaker_eth:-$default_eth}
	beaker_br=${beaker_br:-$default_br}
	image_name=${image_name:-'RHEL-Server-6.6-64-virtio.qcow2'}
	setup_beaker_br0 $beaker_br $beaker_eth
	vm_environment_init $image_num
	get_client_vm_ip $vm_name
	vm_upload_testcase $vm_name './netperf.sh'
	vm_upload_testcase $vm_name './super_netperf'
}
check_call_trace()
{
        rlRun -l "dmesg | grep WARNING" 1
    rlRun -l "dmesg | grep 'Call Trace'" 1
    rlRun -l "dmesg | grep 'cut here'" 1
    rlRun -l "dmesg | grep 'Kernel panic'" 1
    rlRun -l "dmesg | grep BUG" 1
    rlRun -l "dmesg | grep 'failed to load firmware image'" 1
        return 0
}
iface_rename()
{
        IFACE0=$IFACE
        ip link set $IFACE down
        ip link set dev $IFACE name if0
        IFACE=if0
        ip link set $IFACE up
}
iface_rename_back()
{
        ip link set $IFACE down
        ip link set dev $IFACE name $IFACE0
}
