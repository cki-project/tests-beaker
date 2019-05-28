#!/bin/sh

ping_pass()
{
	local field
	for field in $@; do
		ipcalc -c4s $field > /dev/null 2>&1 && { local cmd="ping"; break; }
		ipcalc -c6s $field > /dev/null 2>&1 && { local cmd="ping6"; break; }
	done
	wait_pass $cmd $@
}
ping_fail()
{
	local field
	for field in $@; do
		ipcalc -c4s $field > /dev/null 2>&1 && { local cmd="ping"; break; }
		ipcalc -c6s $field > /dev/null 2>&1 && { local cmd="ping6"; break; }
	done
	wait_fail $cmd $@
}
wait_pass()
{
	local result=1
	for count in $(seq 30); do
		$@ && { result=0; break; }
	done
	return $result
}
wait_fail()
{
	local result=1
	for count in $(seq 30); do
		$@ || { result=0; break; }
	done
	return $result
}
wait_start()
{
	if [ $# -eq 2 ]; then
		local proto=$1
		local port=$2
	else
		local proc=$1
		declare -A timeout
		timeout["ncat"]="1"
		timeout["sipp"]="1"
		timeout["omping"]="1"
		timeout["sctp_test"]="1"
		timeout["netserver"]="1"
		timeout["sleep"]="1"
		timeout["tcpdump"]="1"
		timeout["conntrackd"]="1"
		timeout["keepalived"]="1"
	fi
	local result=0
	for count in $(seq 30); do
		if [ $# -eq 2 ]; then
			netstat -an | grep -w LISTEN | grep $proto | awk '{print $4}' | grep -wq :$port$ && { sleep 1; break; }
		else
			pgrep $proc > /dev/null 2>&1 && { sleep ${timeout[$proc]}; break; }
		fi
		sleep 1
		[ $count -eq 30 ] && { result=1; }
	done
	return $result
}
wait_written()
{
	local file=$1; local result=0; local count;
	for count in $(seq 30); do
		test -s $file && { sleep 1; break; }
		[ $count -eq 30 ] && { result=1; }
		sleep 1
	done
	return $result
}

