#!/bin/bash
# This is for network operations

# variables for setting up IP address
IPVER=${IPVER:-"4 6"}

# variables to save result of test iface and IP address
export CUR_IFACE=
export TEST_IFACE=
export SER_ADDR4=
export SER_ADDR6=
export CLI_ADDR4=
export CLI_ADDR6=
export LOCAL_ADDR4=
export LOCAL_ADDR6=
export REMOTE_ADDR4=
export REMOTE_ADDR6=
export LOCAL_IFACE_MAC=
export REMOTE_IFACE_MAC=

# ---------------------- network service  ------------------

#restart network service, for "service network restart" failed at rhel7
pure_restart_network()
{
    pkill -9 dhclient
    ip link set $1 down &> /dev/null
    ip link set $1 up &> /dev/null
    sleep 10
    if [ "$IPVER" != "6" ]; then
        dhclient $1
    else
        dhclient -6 $1
    fi
}

# Get interface's name by MAC address
# @arg1: interface' MAC address (format: 00:c0:dd:1a:44:8c)
# output: interface's name
mac2name()
{
    local mac="$1"
    local name="mac2name-error"
    local target=""
    local ethX=""

    for ethX in `ls /sys/class/net`; do
        # skip virtual device
        if ethtool -i $ethX 2>/dev/null | grep -q "bus-info: [0-9].*"; then
            target=`get_iface_mac $ethX`
               if [ "$mac" = "$target" ]; then
                    name=$ethX
                    break
               fi
        fi
   done
   echo $name
}

# Pipe into mac2name
# example: echo 00:c0:dd:1a:44:8c | macs2name
macs2name()
{
    local mac=""
    while read mac; do
        mac2name $mac
    done
}

get_cur_iface()
{
    if [ "$IPVER" != "6" ]; then
        ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'
    else
        ip -6 route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'
    fi
}

get_default_iface() { get_cur_iface "$@"; }

get_iface_list()
{
    local dev_list
    if [ "$(GetDistroRelease)" -ge 7 ]; then
        # when running in netns on rhel6, 'find /sys/class/net/ -type l' get all intefaces of host
        # not netns
        dev_list=$(find /sys/class/net/ -type l | awk -F'/' '!/lo|sit|usb|ib/{print $5}' | sort -u)
    else
        # when running in netns, 'cat /proc/net/dev' can always get all interfaces in the netns.
        # This should work on rhel6/7/8 ... But for minimal impact, use it on rhel6 or before only
        dev_list=$(cat /proc/net/dev | tail -n +3 | awk -F':' '!/lo|sit|usb|ib/{print $1}' | sort -u)
    fi
    for dev in ${dev_list}
    do
        # exclude usb network card
        if ethtool -i $dev | grep -qiE "bus-info.*usb"
        then
            continue
        else
            echo $dev
        fi
    done
}


get_sec_iface()
{
    iface_list=$(get_iface_list)
    for name in $iface_list
    do
        ip link set $name up
        sleep 10
        if [ "$name" = $(get_cur_iface) ];then
            continue
        elif [ "`ethtool $name | grep 'Link detected: yes'`" ];then
            echo $name
            return 0
        fi
            ip link set $name down
    done
    return 1
}

get_unused_iface()
{
    cur_num=1
    iface_num=$1
    iface_list=$(get_iface_list)
    for name in $iface_list
        do
            ip link set $name up
            sleep 10
            if [ "$name" = $(get_cur_iface) ];then
                continue
            elif [ "`ethtool $name | grep 'Link detected: yes'`" ] && [ $cur_num -lt $iface_num ];then
                let cur_num++
                continue
            elif [ "`ethtool $name | grep 'Link detected: yes'`" ];then
                echo $name
                return 0
            fi
            ip link set $name down
        done
    return 1
}


# Get IP4 interface
get_iface_ip4()
{
    ip addr show dev $1 | awk -F'[/ ]' '/inet / {print $6}' | head -n1
}

# Get IP6 interface
get_iface_ip6()
{
    # Do not select link local address
    ip addr show dev $1 | grep -v fe80 | grep inet6 -m 1 | awk '{print $2}' | cut -d'/' -f1
}

#get IP6 address
get_ip6_laddr()
{
    ip addr show dev $1 | awk '/fe80/{print $2}' | cut -d'/' -f1
}

