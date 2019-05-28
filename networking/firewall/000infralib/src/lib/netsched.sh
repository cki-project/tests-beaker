#!/bin/sh

source ${BASH_SOURCE/%netsched.sh/module.sh}
###########################################################
# tc rules cleaning
###########################################################
netsched_rules_clean()
{
	for ifname in $(ip link | grep mtu | awk '{print $2}'); do
		local ifname=${ifname%:}
		local ifname=${ifname%@*}
		tc qdisc del dev $ifname root > /dev/null 2>&1
		tc qdisc del dev $ifname ingress > /dev/null 2>&1
		tc qdisc del dev $ifname handle ffff: parent ffff:fff1 > /dev/null 2>&1
	done
	return 0
}
netsched_rules_show()
{
	for ifname in $(ip link | grep mtu | awk '{print $2}'); do
		local ifname=${ifname%:}
		local ifname=${ifname%@*}
		echo "# tc qdisc show dev $ifname"
		tc qdisc show dev $ifname
	done
	return 0
}

###########################################################
# net/sched modules getting/loading/unloading
###########################################################
netsched_modules_list()
{
	local DIR_NET="/lib/modules/$(uname -r)/kernel/net"
	local DIR_SCH="$DIR_NET/sched"
	modules_list $DIR_SCH
}
netsched_modules_show()
{
	modules_show $(netsched_modules_list)
}
netsched_modules_load()
{
	modules_load $(netsched_modules_list)
}
netsched_modules_unload()
{
	modules_unload $(netsched_modules_show)
}

