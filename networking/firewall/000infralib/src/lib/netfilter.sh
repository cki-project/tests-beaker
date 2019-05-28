#!/bin/sh

source ${BASH_SOURCE/%netfilter.sh/module.sh}
###########################################################
# netfilter rules showing/cleaning
###########################################################
netfilter_rules_show()
{
	ebtables --version > /dev/null 2>&1 && {
		echo ":: [   LOG    ] :: ebtables -t filter -L"
		ebtables -t filter -L
		echo ":: [   LOG    ] :: ebtables -t nat -L"
		ebtables -t nat -L
		echo ":: [   LOG    ] :: ebtables -t broute -L"
		ebtables -t broute -L
	}
	arptables --version > /dev/null 2>&1 && {
		echo ":: [   LOG    ] :: arptables -t filter -L"
		arptables -t filter -L
	}
	local xtables=""
	for xtables in iptables ip6tables; do
		$xtables --version > /dev/null 2>&1 || continue
		echo ":: [   LOG    ] :: $xtables -t filter -L"
		$xtables -t filter -L
		echo ":: [   LOG    ] :: $xtables -t nat -L"
		$xtables -t nat -L
		echo ":: [   LOG    ] :: $xtables -t mangle -L"
		$xtables -t mangle -L
		echo ":: [   LOG    ] :: $xtables -t raw -L"
		$xtables -t raw -L
		echo ":: [   LOG    ] :: $xtables -t security -L"
		$xtables -t security -L
	done
	nft --version > /dev/null 2>&1 && {
		local line=""
		nft list tables | while read line; do
			echo ":: [   LOG    ] :: nft list $line"
			nft list $line
		done
	}
	ipset --version > /dev/null 2>&1 && [ -n "$(ipset list)" ] && {
		echo ":: [   LOG    ] :: ipset list"
		ipset list
	}
	ipvsadm --version > /dev/null 2>&1 && {
		echo ":: [   LOG    ] :: ipvsadm -L"
		ipvsadm -L
	}
	return 0
}
netfilter_rules_clean()
{
	echo ":: [   LOG    ] :: xtables rules clean"
	local xtables=""; local table=""; local chain="";
	for xtables in ebtables arptables iptables ip6tables; do
		$xtables --version > /dev/null 2>&1 || continue
		for table in filter nat mangle raw security broute; do
			$xtables -t $table -F >/dev/null 2>&1
			$xtables -t $table -X >/dev/null 2>&1
			for chain in INPUT OUTPUT PREROUTING FORWARD POSTROUTING BROUTING; do
				$xtables -t $table -P $chain ACCEPT >/dev/null 2>&1
			done
		done
	done
	echo ":: [   LOG    ] :: nft rules clean"
	nft --version > /dev/null 2>&1 && {
		local line=""
		nft list tables | while read line; do
			nft delete $line
		done
	}
	echo ":: [   LOG    ] :: ipset rules clean"
	ipset --version > /dev/null 2>&1 && ipset destroy
	echo ":: [   LOG    ] :: ipvsadm rules clean"
	ipvsadm --version > /dev/null 2>&1 && ipvsadm -C
	return 0
}

###########################################################
# netfilter modules listing/showing/loading/unloading
###########################################################
netfilter_modules_list()
{
	local DIR_NET="/lib/modules/$(uname -r)/kernel/net"
	local DIR_NF="$DIR_NET/netfilter"
	local DIR_NFBR="$DIR_NET/bridge/netfilter"
	local DIR_NFv4="$DIR_NET/ipv4/netfilter"
	local DIR_NFv6="$DIR_NET/ipv6/netfilter"
	modules_list br_netfilter $DIR_NFBR $DIR_NFv4 $DIR_NFv6 $DIR_NF
}
netfilter_modules_show()
{
	modules_show $(netfilter_modules_list)
}
netfilter_modules_load()
{
	modules_load $(netfilter_modules_list)
}
netfilter_modules_unload()
{
	modules_unload $(netfilter_modules_show)
	# https://bugzilla.redhat.com/show_bug.cgi?id=1624626
	modules_unload nf_conntrack_ipv4 nf_conntrack_ipv6
	modules_unload nf_defrag_ipv4 nf_defrag_ipv6
}

###########################################################
# xtables nf_defrag_ipv{4,6} modules cleaning
###########################################################
netfilter_defrag_clean()
{
	# https://bugzilla.redhat.com/show_bug.cgi?id=1624626
	modules_unload nf_nat_ipv4 nf_nat_ipv6
	modules_unload nf_defrag_ipv4 nf_defrag_ipv6
}

###########################################################
# xtables bridge_netfilter modules cleaning
###########################################################
netfilter_brnf_clean()
{
	module_unload br_netfilter
	module_unload ebtable_broute
}

###########################################################
# netfilter proc kernel options listing
###########################################################
netfilter_get_bridge_options()
{
	ls /proc/sys/net/bridge/bridge-nf-* 2> /dev/null
}
netfilter_get_ipvs_options()
{
	ls /proc/sys/net/ipv4/vs/* 2> /dev/null
}
netfilter_get_conntrack_options()
{
	ls /proc/sys/net/netfilter/nf_conntrack_* 2> /dev/null
}
netfilter_options_list()
{
	netfilter_get_bridge_options
	netfilter_get_ipvs_options
	netfilter_get_conntrack_options
}
