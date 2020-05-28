#!/bin/bash

[ $TEST_TYPE = "netns" ] && . ./common/netns.sh

for file in `find func -name "*.sh" | sort`
do
	source $file
done

iproute_upstream_install()
{
	local retval=0
	ip netns && return 0
        wget https://git.kernel.org/pub/scm/network/iproute2/iproute2.git/snapshot/iproute2-4.9.0.tar.gz
        tar -xvf iproute2-4.9.0.tar.gz
	pushd iproute2-4.9.0
	./configure && make && make install
	retval=$?
	popd
	return $retval
}
