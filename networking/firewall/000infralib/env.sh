#!/bin/sh

###########################################################
# directory settings
###########################################################
[ -z "$MH_COMMON_ROOT" ] && {
	export MH_COMMON_ROOT="/mnt/tests/kernel/networking/common"
}
[ -z "$MH_INFRA_ROOT" ] && {
	export MH_INFRA_ROOT="$(dirname $(readlink -f $BASH_SOURCE))"
}
###########################################################
# test environment settings #1
###########################################################
[ -z "$MH_PAYLOAD_LEN" ] && {
	export MH_PAYLOAD_LEN=64
}
[ -z "$MH_INFRA_TYPE" ] && {
	export MH_INFRA_TYPE="ns"
}
###########################################################
# test environment settings #2
###########################################################
[ $MH_INFRA_TYPE == "ns" ] && {
	export MH_AS_A_CONTROLLER=true
	export MH_AS_A_TESTNODE=true
}
[ $MH_INFRA_TYPE == "vm" ] && {
	if [ -z $(virt-what) ]; then
		export MH_AS_A_CONTROLLER=true
		export MH_AS_A_TESTNODE=false
	elif [ $(virt-what) == "ibm_power-lpar_dedicated" ]; then
		export MH_AS_A_CONTROLLER=true
		export MH_AS_A_TESTNODE=false
	else
		export MH_AS_A_CONTROLLER=false
		export MH_AS_A_TESTNODE=true
	fi
}
###########################################################
# test entry settings
###########################################################
# MH_OFFLOADS is for the following BZ:
# https://bugzilla.redhat.com/show_bug.cgi?id=1343816 
[ -z "$MH_OFFLOADS" ] && {
	export MH_OFFLOADS=""
}
[ -z "$MH_TEST_LEVELS" ] && {
	export MH_TEST_LEVELS="basic function fuzz performance integration regression"
}
[ -z "$MH_TEST_ENTRIES" ] && {
	export MH_TEST_ENTRIES=""
}
[ -z "$MH_SKIP_ENTRIES" ] && {
	export MH_SKIP_ENTRIES=""
}
[ -z "$MH_NFT_IS_INET" ] && {
	export MH_NFT_IS_INET=false
}
[ -z "$MH_XT_IS_COMPAT" ] && {
	export MH_XT_IS_COMPAT=false
}
# MH_BR_OPENSTACK is for the following BZ:
# https://bugzilla.redhat.com/show_bug.cgi?id=1430571
[ -z "$MH_BR_OPENSTACK" ] && {
	export MH_BR_OPENSTACK=false
}
# MH_BR_VNIC is for the following BZ:
# https://bugzilla.redhat.com/show_bug.cgi?id=1319883
[ -z "$MH_BR_VNIC" ] && {
	export MH_BR_VNIC="nic"
}
# MH_TC_VNIC is for the following BZ (unfinished):
# https://bugzilla.redhat.com/show_bug.cgi?id=1649876
[ -z "$MH_TC_VNIC" ] && {
	export MH_TC_VNIC="nic"
}
# MH_TC_WITH_DMAC is for ...
[ -z "$MH_TC_WITH_DMAC" ] && {
	export MH_TC_WITH_DMAC=false
}
# the following two variables will be deprecated
[ -z "$MH_PKT_TYPES" ] && {
	export MH_PKT_TYPES="normal fragment"
}
[ -z "$MH_RULE_TYPES" ] && {
	export MH_RULE_TYPES="xt nft"
}
modinfo nf_tables > /dev/null 2>&1 || {
	export MH_RULE_TYPES="xt"
}
###########################################################
# kernel-version settings only for vm infra
###########################################################
[ -z "$MH_KERNEL" ] && {
	export MH_KERNEL=$(uname -r)
}
[ -z "$MH_IS_DEBUG" ] && {
	export MH_IS_DEBUG=false
}
###########################################################
# write ~/.profile file
###########################################################
cat << EOF >> ~/.profile
# $(date)
# directory settings
export MH_COMMON_ROOT="$MH_COMMON_ROOT"
export MH_INFRA_ROOT="$MH_INFRA_ROOT"
# test environment settings
export MH_PAYLOAD_LEN="$MH_PAYLOAD_LEN"
export MH_INFRA_TYPE="$MH_INFRA_TYPE"
export MH_AS_A_CONTROLLER="$MH_AS_A_CONTROLLER"
export MH_AS_A_TESTNODE="$MH_AS_A_TESTNODE"
# test entry settings
export MH_OFFLOADS="$MH_ON_OFFLOADS"
export MH_TEST_LEVELS="$MH_TEST_LEVELS"
export MH_TEST_ENTRIES="$MH_TEST_ENTRIES"
export MH_SKIP_ENTRIES="$MH_SKIP_ENTRIES"
export MH_NFT_IS_INET="$MH_NFT_IS_INET"
export MH_XT_IS_COMPAT="$MH_XT_IS_COMPAT"
export MH_BR_OPENSTACK="$MH_BR_OPENSTACK"
export MH_BR_VNIC="$MH_BR_VNIC"
export MH_TC_VNIC="$MH_TC_VNIC"
export MH_TC_WITH_DMAC="$MH_TC_WITH_DMAC"
# the following two variables will be deprecated
export MH_PKT_TYPES="$MH_PKT_TYPES"
export MH_RULE_TYPES="$MH_RULE_TYPES"
# kvm infra settings
export MH_KERNEL="$MH_KERNEL"
export MH_IS_DEBUG="$MH_IS_DEBUG"
# machine infra settings
export SERVERS="$SERVERS"
export CLIENTS="$CLIENTS"
export NIC_NUM="$NIC_NUM"
export NIC_DRIVER="$NIC_DRIVER"
export NIC_VENDOR="$NIC_VENDOR"
export NIC_DEVICE="$NIC_DEVICE"
# the following two variables will be deprecated
export MH_MT_ENTRIES="$MH_MT_ENTRIES"
export MH_TG_ENTRIES="$MH_TG_ENTRIES"

EOF

