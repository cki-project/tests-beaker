#!/bin/bash

MULTIADDR="239.1.2.3"
INTERFACE="eth1"

QUERY_VER=2
REP_VER="any"

DURATION=10

dump_file=`mktemp`

tcpdump -i$INTERFACE -n igmp >$dump_file 2>/dev/null &
tcpdump_pid=$!

sleep $DURATION
kill $tcpdump_pid

## query
if [ "$QUERY_VER" == "1" ]; then
    target_addr="224.0.0.1"
else
    target_addr="$MULTIADDR"
fi

query=`cat $dump_file | grep "> $target_addr: igmp query v$QUERY_VER"`
echo "$query"
if [ -n "$query" ]; then
    echo "query=yes"
else
    echo "query=no"
fi


## report
if [ "$REP_VER" == "3" ]; then
    target_addr="224.0.0.22"
else
    target_addr="$MULTIADDR"
fi

if [ "$REP_VER" == "any" ]; then
    REP_VER="[123]"
fi

report=`cat $dump_file | grep "> $target_addr: igmp v$REP_VER report"`
echo "$report"
if [ -n "$report" ]; then
    echo "report=yes"
else
    echo "report=no"
fi

rm -rf $DUMP_FILE
