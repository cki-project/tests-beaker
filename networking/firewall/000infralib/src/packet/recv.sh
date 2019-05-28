#!/bin/sh

recv()
{
	if [ $1 == "nfqueue" ]; then
		timeout $(latency nw nfqueue nw scapy 3) python3 ${BASH_SOURCE/%recv.sh/recv.py} $@
	else
		timeout $(latency nw 1 nw 1 3) $@
	fi
}

