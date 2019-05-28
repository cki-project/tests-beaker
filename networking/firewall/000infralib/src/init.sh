#!/bin/sh

###########################################################
# Get Test Environment Variable
###########################################################
source ~/.profile

###########################################################
# Common Lib
###########################################################
[ $MH_INFRA_TYPE == "vm" ] && {
	# include vm-lib for vinit
	source $MH_COMMON_ROOT/vm/vm.sh
}

###########################################################
# 000infralib Lib (for init)
###########################################################
source $MH_INFRA_ROOT/src/lib/repo.sh
source $MH_INFRA_ROOT/src/lib/install.sh

###########################################################
# test environment init for servers
###########################################################
test_env_init()
{
	if uname -r | grep -q el6; then
		if test -e /etc/yum.repos.d/redhat.repo > /dev/null 2>&1; then
			repo_epel_6_set
		else
			repo_centos_set
		fi
	fi
	if uname -r | grep -q el7; then
		if test -e /etc/yum.repos.d/redhat.repo > /dev/null 2>&1; then
			repo_epel_7_set
		else
			repo_centos_set
		fi
	fi
	if uname -r | grep -q el8; then
		: # nothing to do
	fi
	if uname -r | grep -q fc; then
		repo_fedora_set
	fi

	local array=(); local pkt;
	array+=('gcc' 'git' 'bc' 'pciutils')
	array+=('kernel-modules-extra' 'iproute-tc')
	array+=('nftables' 'iptables' 'iptables-utils' 'iptables-ebtables' 'iptables-arptables' 'ebtables' 'arptables' 'ipvsadm' 'ipset')
	array+=('tcpdump' 'wireshark')
	array+=('ftp' 'vsftpd' 'tftp' 'tftp-server')
	array+=('curl' 'wget' 'httpd')
	array+=('nmap' 'nc' 'nmap-ncat')
	array+=('hping3' 'omping' 'traceroute')
	array+=('pptp-setup')
	array+=('lksctp-tools-devel')
	array+=('conntrack-tools' 'keepalived')
	array+=('python3')
	# array+=('bash-completion')
	for pkt in ${array[@]}; do
		rpm -q $pkt || { ${YUM} install $pkt -y; }
	done

	python_argparse_install
	python_scapy_install
	python_NetfilterQueue_install
	conntrack_tools_install
	sipp_install
	iproute_install
	super_netperf_install
	hping3_install

	seq -sX $MH_PAYLOAD_LEN | tr -d '[:digit:]' > /var/ftp/pub/${MH_PAYLOAD_LEN}.pkt
	chmod 755 /var/ftp/pub/${MH_PAYLOAD_LEN}.pkt
	seq -sX $MH_PAYLOAD_LEN | tr -d '[:digit:]' > /var/lib/tftpboot/${MH_PAYLOAD_LEN}.pkt
	chmod 755 /var/lib/tftpboot/${MH_PAYLOAD_LEN}.pkt
	seq -sX $MH_PAYLOAD_LEN | tr -d '[:digit:]' > /var/www/html/${MH_PAYLOAD_LEN}.pkt
	chmod 755 /var/www/html/${MH_PAYLOAD_LEN}.pkt

	seq -sX $MH_PAYLOAD_LEN | tr -d '[:digit:]' > /tmp/${MH_PAYLOAD_LEN}.pkt
	seq -sX 64 | tr -d '[:digit:]' > /tmp/64.pkt
	seq -sX 4096 | tr -d '[:digit:]' > /tmp/4096.pkt
	seq -sX 9000 | tr -d '[:digit:]' > /tmp/9000.pkt

	#bz1642795 sctp module need install manually
	modprobe sctp

	return 0
}

