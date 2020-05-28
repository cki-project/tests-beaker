#!/bin/bash

TEST_ITEMS_ALL=""
source ./common/${TEST_TYPE}.sh || exit 1

# select tool to manage package, which could be "yum" or "dnf"
function select_yum_tool() {
    if [ -x /usr/bin/dnf ]; then
        echo "/usr/bin/dnf"
    elif [ -x /usr/bin/yum ]; then
        echo "/usr/bin/yum"
    else
        return 1
    fi

    return 0
}

yum=$(select_yum_tool)

for file in `find func -name "*.sh" | sort`
do
	source $file
done

nl_fib_lookup_install()
{
	${yum} install libnl3 libnl3-devel -y
	pushd tools
	gcc -g -o nl-fib-lookup nl-fib-lookup.c -I /usr/include/libnl3/ -lnl-3 -lnl-cli-3 -lnl-route-3
	cp -arf nl-fib-lookup /usr/local/bin
	popd
}
