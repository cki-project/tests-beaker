#!/bin/bash

dir_path=`dirname $BASH_SOURCE`
source $dir_path/func_lib

#Parameters

TEST_ITEMS_ALL="$TEST_ITEMS_ALL basic_pmtu mtu_expire multi_pmtu del_route_while_pmtu pmtu_traffic ip_mtu_lock mtu_firsthop ip_no_pmtu_disc_test min_pmtu_test"

pmtu_test()
{

rlPhaseStartSetup pmtu_env_setup_$DO_SEC

	rlRun "default_pmtu_setup"
	rlRun "$CLIENTNS ip addr sh"
	rlRun "$SERVERNS ip addr sh"
	rlRun "$CLIENTNS ping ${veth0_server_ip[4]} -c 5"
	rlRun "$CLIENTNS ping6 ${veth0_server_ip[6]} -c 5"

rlPhaseEnd

for item in $TEST_ITEMS
do
	$item
done

rlPhaseStartCleanup
	#unset para
	rlRun "default_pmtu_cleanup"
rlPhaseEnd
}
