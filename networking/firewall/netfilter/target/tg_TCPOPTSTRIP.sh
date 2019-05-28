#!/bin/sh

###########################################################
# 
###########################################################
# infrastructure      : if supported
# vm                  : ○
# namespace(iproute2) : × (namespace not supported)
###########################################################
tg_TCPOPTSTRIP_is_unsupported_entry()
{
	[ $1 == "function" ] && [ $2 == "fragment" ] && { return 0; }
	return 1
}
tg_TCPOPTSTRIP_function()
{
	local result=0
	##############################
	# init route forward topo
	##############################
	topo_cs_init
	topo_cs_ipv4
	##############################
	# check test environment
	##############################
	topo_cs_check ipv4
	assert_pass result "client-server topo init"
	##############################
	# do the test
	##############################
        run server iptables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j TCPOPTSTRIP --strip-options mss
        run server iptables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j NFQUEUE --queue-num 1
	run client send scapy ip-tcp cs --opt-mss 500 --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood &
	run server recv nfqueue ip-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-mss 500
	assert_fail result "-j TCPOPTSTRIP --strip-options mss [mss option was stripped]"
	run client send scapy ip-tcp cs --opt-mss 500 --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood &
	run server recv nfqueue ip-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood
	assert_pass result "-j TCPOPTSTRIP --strip-options mss [other options were not stripped]"

	run server iptables -t mangle -F
        run server iptables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j TCPOPTSTRIP --strip-options wscale
        run server iptables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j NFQUEUE --queue-num 1
	run client send scapy ip-tcp cs --opt-mss 500 --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood &
	run server recv nfqueue ip-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-wscale 10
	assert_fail result "-j TCPOPTSTRIP --strip-options wscale [wscale option was stripped]"
	run client send scapy ip-tcp cs --opt-mss 500 --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood &
	run server recv nfqueue ip-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-mss 500 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood
	assert_pass result "-j TCPOPTSTRIP --strip-options wscale [other options were not stripped]"

	run server iptables -t mangle -F
        run server iptables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j TCPOPTSTRIP --strip-options timestamp
        run server iptables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j NFQUEUE --queue-num 1
	run client send scapy ip-tcp cs --opt-mss 500 --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood &
	run server recv nfqueue ip-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-timestamp 100000
	assert_fail result "-j TCPOPTSTRIP --strip-options timestamp [timestamp option was not stripped]"
	run client send scapy ip-tcp cs --opt-mss 500 --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood &
	run server recv nfqueue ip-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-mss 500 --opt-wscale 10  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood
	assert_pass result "-j TCPOPTSTRIP --strip-options timestamp [other options were not stripped]"

	run server iptables -t mangle -F
        run server iptables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j TCPOPTSTRIP --strip-options sack
        run server iptables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j NFQUEUE --queue-num 1
	run client send scapy ip-tcp cs --opt-mss 500 --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood &
	run server recv nfqueue ip-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-sack bbbbb
	assert_fail result "-j TCPOPTSTRIP --strip-options sack [sack option was stripped]"
	run client send scapy ip-tcp cs --opt-mss 500 --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood &
	run server recv nfqueue ip-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-mss 500 --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sackok --opt-mood
	assert_pass result "-j TCPOPTSTRIP --strip-options sack [other options were not stripped]"

	run server iptables -t mangle -F
        run server iptables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j TCPOPTSTRIP --strip-options sack-permitted
        run server iptables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j NFQUEUE --queue-num 1
	run client send scapy ip-tcp cs --opt-mss 500 --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood &
	run server recv nfqueue ip-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-sackok
	assert_fail result "-j TCPOPTSTRIP --strip-options sack-permitted [sack-permitted option was stripped]"
	run client send scapy ip-tcp cs --opt-mss 500 --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-sackok --opt-mood &
	run server recv nfqueue ip-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-mss 500 --opt-wscale 10 --opt-timestamp 100000  --opt-altchksum aaaaaaaaaa --opt-altchksumopt --opt-sack bbbbb --opt-mood
	assert_pass result "-j TCPOPTSTRIP --strip-options sack-permitted [other options were not stripped]"

	return $result
}

