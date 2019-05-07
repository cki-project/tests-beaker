#!/bin/bash

# clean netns env
for net in $(ip netns list | awk '{print $1}'); do
	ip netns del $net
done
modprobe -r veth
modprobe -r bridge
