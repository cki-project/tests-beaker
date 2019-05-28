#!/bin/sh

###########################################################
# 
###########################################################
# infrastructure      : if supported
# vm                  : ○
# namespace(iproute2) : × (namespace not supported)
###########################################################
tg_TCPOPTSTRIPv6_is_unsupported_entry()
{
	[ $1 == "function" ] && [ $2 == "fragment" ] && { return 0; }
	return 1
}
###########################################################
# https://bugzilla.redhat.com/show_bug.cgi?id=1325733
###########################################################
tg_TCPOPTSTRIPv6_function()
{
	local result=0
	##############################
	# init route forward topo
	##############################
	topo_cs_init
	topo_cs_ipv6
	##############################
	# check test environment
	##############################
	topo_cs_check ipv6
	assert_pass result "client-server topo init"
	##############################
	# do the test
	##############################
	run server ip6tables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j TCPOPTSTRIP --strip-options mss
	run server ip6tables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j NFQUEUE --queue-num 1
	run server sock server AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run client sock client AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run server recv nfqueue ipv6-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-mss
	assert_fail result "-j TCPOPTSTRIP --strip-options mss [mss option was stripped]"
	sleep 5
	run server sock server AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run client sock client AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run server recv nfqueue ipv6-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-wscale --opt-timestamp --opt-sackok
	assert_pass result "-j TCPOPTSTRIP --strip-options mss [other options were not stripped]"
	sleep 5

	run server ip6tables -t mangle -F
	run server ip6tables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j TCPOPTSTRIP --strip-options wscale
	run server ip6tables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j NFQUEUE --queue-num 1
	run server sock server AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run client sock client AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run server recv nfqueue ipv6-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-wscale
	assert_fail result "-j TCPOPTSTRIP --strip-options wscale [wscale option was stripped]"
	sleep 5
	run server sock server AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run client sock client AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run server recv nfqueue ipv6-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-mss --opt-timestamp --opt-sackok
	assert_pass result "-j TCPOPTSTRIP --strip-options wscale [other options were not stripped]"
	sleep 5

	run server ip6tables -t mangle -F
	run server ip6tables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j TCPOPTSTRIP --strip-options timestamp
	run server ip6tables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j NFQUEUE --queue-num 1
	run server sock server AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run client sock client AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run server recv nfqueue ipv6-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-timestamp
	assert_fail result "-j TCPOPTSTRIP --strip-options timestamp [timestamp option was not stripped]"
	sleep 5
	run server sock server AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run client sock client AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run server recv nfqueue ipv6-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-mss --opt-wscale --opt-sackok
	assert_pass result "-j TCPOPTSTRIP --strip-options timestamp [other options were not stripped]"
	sleep 5

	run server ip6tables -t mangle -F
	run server ip6tables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j TCPOPTSTRIP --strip-options sack
	run server ip6tables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j NFQUEUE --queue-num 1
	run server sock server AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run client sock client AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run server recv nfqueue ipv6-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-sack
	assert_fail result "-j TCPOPTSTRIP --strip-options sack [sack option was stripped]"
	sleep 5
	run server sock server AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run client sock client AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run server recv nfqueue ipv6-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-mss --opt-wscale --opt-timestamp --opt-sackok
	assert_pass result "-j TCPOPTSTRIP --strip-options sack [other options were not stripped]"
	sleep 5

	run server ip6tables -t mangle -F
	run server ip6tables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j TCPOPTSTRIP --strip-options sack-permitted
	run server ip6tables -t mangle -A INPUT -i $cs_server_if1 -p tcp  -j NFQUEUE --queue-num 1
	run server sock server AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run client sock client AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run server recv nfqueue ipv6-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-sackok
	assert_fail result "-j TCPOPTSTRIP --strip-options sack-permitted [sack-permitted option was stripped]"
	sleep 5
	run server sock server AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run client sock client AF_INET6 SOCK_STREAM $cs_server_ip1 1024 &
	run server recv nfqueue ipv6-tcp --src-ip $cs_client_ip1 --dst-ip $cs_server_ip1 --tcp-flags "S" --opt-mss --opt-wscale --opt-timestamp
	assert_pass result "-j TCPOPTSTRIP --strip-options sack-permitted [other options were not stripped]"
	sleep 5

	return $result
}

