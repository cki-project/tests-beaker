#!/bin/sh

###########################################################
# Func : run APIs for ns/vm/py infra
###########################################################
topo_ns_run()
{
	local guest=$1; shift; local cmd=$@;
	if [ "$(echo $cmd | awk '{print $NF}')" == "reboot" ]; then
		cmd=${cmd%reboot}
cat << EOF | ip netns exec $guest bash
source $MH_INFRA_ROOT/src/testnode.sh
$cmd
EOF
		ip netns del $guest
		ip netns add $guest
	else
cat << EOF | ip netns exec $guest bash
source $MH_INFRA_ROOT/src/testnode.sh
$cmd
EOF
	fi
}
topo_vm_run()
{
	local guest=$1; shift; local cmd=$@;
	if [ "$(echo $cmd | awk '{print $NF}')" == "&" ]; then
		cmd=${cmd%&}
cat << EOF | ssh root@$(vinfo -n $guest show ip) bash &
source $MH_INFRA_ROOT/src/testnode.sh
$cmd
EOF
	else
cat << EOF | ssh root@$(vinfo -n $guest show ip) bash
source $MH_INFRA_ROOT/src/testnode.sh
$cmd
EOF
	fi
}
topo_py_run()
{
	local guest=$1; shift; local cmd=$@;
	if [ "$(echo $cmd | awk '{print $NF}')" == "&" ]; then
		cmd=${cmd%&}
cat << EOF | ssh root@$guest bash &
source $MH_INFRA_ROOT/src/testnode.sh
$cmd
EOF
	else
cat << EOF | ssh root@$guest bash
source $MH_INFRA_ROOT/src/testnode.sh
$cmd
EOF
	fi
}
topo_lo_run()
{
cat << EOF | bash
source $MH_INFRA_ROOT/src/testnode.sh
$@
EOF
}

