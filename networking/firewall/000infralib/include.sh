#!/bin/sh

MH_INFRA_ROOT=$(dirname $(readlink -f $BASH_SOURCE))

if test -e ~/.profile; then
	echo "WARNING: Please update the test environment and ~/.profile file if your"
	echo "         environment variables (MH_INFRA_TYPE or MH_PAYLOAD_LEN) have been changed:"
	echo "         $ rm -f ~/.profile"
	echo "         $ /mnt/tests/kernel/networking/firewall/000infralib/runtest.sh"
	echo "WARNING: Please update ~/.profile file if your environment variables"
	echo "         (any but except MH_INFRA_TYPE and MH_PAYLOAD_LEN) has been changed:"
	echo "         $ /mnt/tests/kernel/networking/firewall/000infralib/runtest.sh"
	source ${MH_INFRA_ROOT}/src/controller.sh
else
	echo "WARNING: Only atomic functions for single-host testing were included."
	echo "         If you want to use more functions on multi-host testing,"
	echo "         please init the test environment and create ~/.profile file first:"
	echo "         $ /mnt/tests/kernel/networking/firewall/000infralib/runtest.sh"
	source ${MH_INFRA_ROOT}/src/lib/repo.sh
	source ${MH_INFRA_ROOT}/src/lib/install.sh
	source ${MH_INFRA_ROOT}/src/lib/wait.sh
	source ${MH_INFRA_ROOT}/src/lib/service.sh
	source ${MH_INFRA_ROOT}/src/lib/module.sh
	source ${MH_INFRA_ROOT}/src/lib/netfilter.sh
	source ${MH_INFRA_ROOT}/src/lib/netsched.sh
	source ${MH_INFRA_ROOT}/src/lib/network.sh
	source ${MH_INFRA_ROOT}/src/lib/mellanox.sh
	source ${MH_INFRA_ROOT}/src/lib/netronome.sh
fi

