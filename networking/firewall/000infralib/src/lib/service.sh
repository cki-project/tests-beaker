#!/bin/sh

service_firewalld_start()
{
	rpm -q firewalld > /dev/null 2>&1 && {
		systemctl start firewalld
		systemctl enable firewalld
	} || {
		service iptables start
		service ip6tables start
		chkconfig iptables on
		chkconfig ip6tables on
	}
}
service_firewalld_stop()
{
	rpm -q firewalld > /dev/null 2>&1 && {
		systemctl stop firewalld
		systemctl disable firewalld
	} || {
		service iptables save
		service ip6tables save
		service iptables stop
		service ip6tables stop
		chkconfig iptables off
		chkconfig ip6tables off
	}
}
service_libvirtd_start()
{
	rpm -q systemd > /dev/null 2>&1 && {
		systemctl start libvirtd
		systemctl enable libvirtd
	} || {
		service libvirtd start
		chkconfig libvirtd on
	}
	ip link show dev virbr0 > /dev/null 2>&1 || {
		virsh net-create /usr/share/libvirt/networks/default.xml
	}
}
service_libvirtd_stop()
{
	ip link show dev virbr0 > /dev/null 2>&1 && {
		virsh net-destroy default 
		# virsh net-undefine default
	}
	rpm -q systemd > /dev/null 2>&1 && {
		systemctl stop libvirtd
		systemctl disable libvirtd
	} || {
		service libvirtd stop
		chkconfig libvirtd off
	}
}
service_vsftpd_start()
{
	[ -n "$1" ] && { local proto=$1; } || { local proto="ipv4"; }
	[ -n "$2" ] && { local ctrlport=$2; }
	[ -n "$3" ] && { local dataport=$3; }

	sed -i '/^#listen=/s/#//' /etc/vsftpd/vsftpd.conf
	sed -i '/^#listen_ipv6=/s/#//' /etc/vsftpd/vsftpd.conf
	sed -i '/^anonymous_enable=/s/NO/YES/' /etc/vsftpd/vsftpd.conf
	sed -i '$adual_log_enable=YES' /etc/vsftpd/vsftpd.conf

	if [ $proto == "ipv4" ]; then
		sed -i '/^listen=/s/NO/YES/' /etc/vsftpd/vsftpd.conf
		sed -i '/^listen_ipv6=/s/YES/NO/' /etc/vsftpd/vsftpd.conf
	else
		sed -i '/^listen=/s/YES/NO/' /etc/vsftpd/vsftpd.conf
		sed -i '/^listen_ipv6=/s/NO/YES/' /etc/vsftpd/vsftpd.conf
	fi
	if [ -n "$ctrlport" ]; then
		sed -i '/^connect_from_port_20/ilisten_port='$ctrlport /etc/vsftpd/vsftpd.conf
		sed -i '/^ftp[[:space:]]*[[:digit:]]*[[:digit:]]/s/[[:digit:]]*[[:digit:]]/'$ctrlport'/' /etc/services
	fi
	if [ -n "$dataport" ]; then
		local minport=$(echo $dataport | cut -d '-' -f 1)
		local maxport=$(echo $dataport | cut -d '-' -f 2)
		sed -i '$apasv_min_port='$minport /etc/vsftpd/vsftpd.conf
		sed -i '$apasv_max_port='$maxport /etc/vsftpd/vsftpd.conf
	fi

	rpm -q systemd > /dev/null 2>&1 && {
		systemctl start vsftpd
	} || {
		service vsftpd start
	}
}
service_vsftpd_stop()
{
	rpm -q systemd > /dev/null 2>&1 && {
		systemctl stop vsftpd
	} || {
		service vsftpd stop
	}
	# default port of data connection
	sed -i '/^pasv_min_port=/d' /etc/vsftpd/vsftpd.conf
	sed -i '/^pasv_max_port=/d' /etc/vsftpd/vsftpd.conf
	# default port of ctrl connection is 21
	sed -i '/^listen_port=/d' /etc/vsftpd/vsftpd.conf
	sed -i '/^ftp[[:space:]]*[[:digit:]]*[[:digit:]]/s/[[:digit:]]*[[:digit:]]/21/' /etc/services
	# default protocol is ipv4
	sed -i '/#listen=/s/#//' /etc/vsftpd/vsftpd.conf
	sed -i '/#listen_ipv6=/s/#//' /etc/vsftpd/vsftpd.conf
	sed -i '/^listen=/s/NO/YES/' /etc/vsftpd/vsftpd.conf
	sed -i '/^listen_ipv6=/s/YES/NO/' /etc/vsftpd/vsftpd.conf
	# default dual log config
	sed -i '/^dual_log_enable=YES/d' /etc/vsftpd/vsftpd.conf
}
service_tftp_start()
{
	rpm -q systemd > /dev/null 2>&1 && {
		systemctl start tftp
	} || {
		chkconfig tftp on
		service xinetd restart
	}
}
service_tftp_stop()
{
	rpm -q systemd > /dev/null 2>&1 && {
		systemctl stop tftp
	} || {
		chkconfig tftp off
		service xinetd restart
	}
}
service_httpd_start()
{
	rpm -q systemd > /dev/null 2>&1 && {
		systemctl start httpd
	} || {
		service httpd start
	}
}
service_httpd_stop()
{
	rpm -q systemd > /dev/null 2>&1 && {
		systemctl stop httpd
	} || {
		service httpd stop
	}
}

