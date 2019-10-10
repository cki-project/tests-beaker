#!/bin/bash
# This is basic include file

lib_service()
{
	local service=$1
	local action=$2
	if [ "$(GetDistroRelease)" -ge 7 ];then
		systemctl $action ${service}.service
	else
		service $service $action
	fi
}

# TODO: save iptables on RHEL7, then iptables -F
disable_firewall()
{
	if [ "$(GetDistroRelease)" -ge 7 ];then
		systemctl stop firewalld.service
		systemctl disable firewalld.service
	else
		service iptables save
		service ip6tables save
		service iptables stop
		service ip6tables stop
		chkconfig iptables off
		chkconfig ip6tables off
	fi
}

enable_firewall()
{
	if [ "$(GetDistroRelease)" -ge 7 ];then
		systemctl start firewalld.service
		systemctl enable firewalld.service
	else
		service iptables start
		service ip6tables start
		chkconfig iptables on
		chkconfig ip6tables on
	fi
}

disable_avc_check()
{
	setenforce 0
	[ "$AVC_ERROR" ] && export AVC_ERROR_BAK=$AVC_ERROR
	export AVC_ERROR=+no_avc_check
	export RHTS_OPTION_STRONGER_AVC=
	unset AVC_ERROR_FILE
	[ "$TEST_ID" ] && cp -f /var/log/audit/audit.log /var/log/audit/audit.${TESTID}.bak || :
}

enable_avc_check()
{
	setenforce 1
	{ [ "$AVC_ERROR_BAK" ] && export AVC_ERROR=$AVC_ERROR_BAK; } || \
		{ export AVC_ERROR=`mktemp /mnt/testarea/tmp.XXXXXX` && touch $AVC_ERROR; }
	export RHTS_OPTION_STRONGER_AVC=yes
	export AVC_ERROR_FILE="$AVC_ERROR"
	[ -f /var/log/audit/audit.${TESTID}.bak ] && \
		mv -f /var/log/audit/audit.${TESTID}.bak /var/log/audit/audit.log || return 0
}

stop_NetworkManager()
{
	# If stop NM, RHEL7 cannnot respawn dhclient for beaker interface,
	# and result in lost management IP address after DHCP expired.
	# Let's keep NetworkManger running and just set non-beaker interfaces NM_CONTROLLED=no

	local beaker_nic=$(get_default_iface)
	for f in /etc/sysconfig/network-scripts/ifcfg-*; do
		grep -q $beaker_nic $f && continue
		grep -q loopback $f && continue

		sed -i 's/BOOTPROTO=dhcp/BOOTPROTO=none/g' $f
		if grep -q NM_CONTROLLED $f; then
			sed -i 's/NM_CONTROLLED=yes/NM_CONTROLLED=no/g' $f
		else
			sed -i '$a\NM_CONTROLLED=no' $f
		fi
		#In RHEL-7.3-beta, NetworkManager would set accept_ra of nic to 0,so restore
		#them to 1.As the nic controlled by NetworkManager has no local ipv6 addr,so
		#down these cards,up them when need to use and local ipv6 addr would be generated
		#corresponsively
		devname=`basename $f | cut -f 2 -d -`
		nmcli dev set $devname managed no
		for config in "accept_ra" "accept_ra_defrtr" "accept_ra_pinfo" "accept_ra_rtr_pref"
		do
			echo 1 > /proc/sys/net/ipv6/conf/$devname/$config
		done
		ip link set $devname down
	done
	nmcli c reload

	[ -d $networkLib/network-scripts.no_nm/ ] || \
		rsync -a --delete /etc/sysconfig/network-scripts/ $networkLib/network-scripts.no_nm/

	lib_service NetworkManager status &> /dev/null || return 0
	lib_service NetworkManager restart
}
