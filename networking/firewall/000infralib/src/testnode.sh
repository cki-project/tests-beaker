#!/bin/sh

###########################################################
# Get Test Environment Variable
###########################################################
source ~/.profile

###########################################################
# Common Lib
###########################################################

###########################################################
# 000infralib Lib
###########################################################
source $MH_INFRA_ROOT/src/lib/wait.sh
source $MH_INFRA_ROOT/src/lib/service.sh
source $MH_INFRA_ROOT/src/lib/network.sh
source $MH_INFRA_ROOT/src/lib/netronome.sh
source $MH_INFRA_ROOT/src/lib/mellanox.sh
source $MH_INFRA_ROOT/src/lib/broadcom.sh
source $MH_INFRA_ROOT/src/lib/module.sh
source $MH_INFRA_ROOT/src/lib/netfilter.sh
source $MH_INFRA_ROOT/src/lib/netsched.sh
source $MH_INFRA_ROOT/src/lib/install.sh
source $MH_INFRA_ROOT/src/packet/send.sh
source $MH_INFRA_ROOT/src/packet/recv.sh
source $MH_INFRA_ROOT/src/packet/sock.sh

###########################################################
# network & process latency (only for send.sh & recv.sh)
###########################################################
latency()
{
	local latency=0
	for entry in $@; do
		if [ $entry == "nw" ]; then
			[ "$MH_INFRA_TYPE" == "ns" ] && { :; }
			[ "$MH_INFRA_TYPE" == "vm" ] && { latency=$((latency+1)); }
		elif [ $entry == "scapy" ]; then
			latency=$((latency+3)) 
		elif [ $entry == "nfqueue" ]; then
			latency=$((latency+3)) 
		else
			latency=$((latency+entry))
		fi
	done
	echo -n $latency
}

