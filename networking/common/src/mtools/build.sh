#!/bin/bash

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

which gcc 2>/dev/null || ${yum} install -y gcc

install_dir=/usr/local/bin

set -x
gcc -o $install_dir/msend msend.c
gcc -o $install_dir/mdump mdump.c
gcc -o $install_dir/mpong mpong.c -lm
gcc -o $install_dir/mstate mstate.c
gcc -o $install_dir/join_group join_group.c
gcc -o $install_dir/send_multicast send_multicast.c
gcc -o $install_dir/recv_multicast recv_multicast.c
gcc -o $install_dir/mld_query mld_query.c
gcc -o $install_dir/igmp_query igmp_query.c
