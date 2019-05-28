#!/bin/sh

send()
{
	if [ $1 == "scapy" ]; then
		sleep $(latency nw nfqueue)
		local cmd=${@/scapy/}
		timeout $(latency scapy) python3 ${BASH_SOURCE/%send.sh/send.py} $cmd
	else
		sleep $(latency nw 1)
		timeout 1 $@
	fi
}
send2()
{
	declare -A timeout
	timeout["ssh"]="3"
	timeout["ftp"]="5"
	timeout["curl"]="5"

	if [ $1 == "ssh" ]; then
		local cmd=${@/ssh/}
		ssh -o ConnectTimeout=${timeout["ssh"]} $cmd
	elif [ $1 == "curl" ]; then
		local cmd=${@/curl/}
		curl --connect-timeout ${timeout["curl"]} --max-time $((${timeout["curl"]}*2)) $cmd
	elif [ $1 == "ftp" ]; then
		local cmd=${@/ftp/}
		timeout ${timeout["ftp"]} ftp -n 2> errfile << !
open $cmd
user anonymous ''
ls
bye
!
		local result=$?
		[ $result -ne 0 ] && { return $result; }
		[ -s errfile ] && { return 1; } || { return 0; }
	else
		timeout 3 $@
	fi
}

