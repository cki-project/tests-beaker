#!/bin/bash
# This is used for netperf testing

# ---------- netperf test ----------
PERF_TIME=${PERF_TIME:-60}

netperf_tcp_4() {
	tcp_speed_4='none'
	echo "" > perf_result_tcp_4
	echo "netperf -4 -L ${LOCAL_ADDR4} -H ${REMOTE_ADDR4} -t TCP_STREAM -l $PERF_TIME" >> perf_result_tcp_4
	netperf -4 -L ${LOCAL_ADDR4} -H ${REMOTE_ADDR4} -t TCP_STREAM -l $PERF_TIME 2>&1 >> perf_result_tcp_4\
	&& tcp_speed_4=`cat perf_result_tcp_4 | tail -n1 | awk '{print $5}'`
	echo "" >> perf_result_tcp_4
	echo $tcp_speed_4
}
netperf_tcp_6() {
	tcp_speed_6='none'
	echo "" > perf_result_tcp_6
	echo "netperf -6 -L ${LOCAL_ADDR6} -H ${REMOTE_ADDR6} -t TCP_STREAM -l $PERF_TIME" >> perf_result_tcp_6
	netperf -6 -L ${LOCAL_ADDR6} -H ${REMOTE_ADDR6} -t TCP_STREAM -l $PERF_TIME 2>&1 >> perf_result_tcp_6\
	&& tcp_speed_6=`cat perf_result_tcp_6 | tail -n1 | awk '{print $5}'`
	echo "" >> perf_result_tcp_6
	echo $tcp_speed_6
}
netperf_udp_4() {
	udp_speed_4_send='none'
	udp_speed_4_receive='none'
	echo "" > perf_result_udp_4
	echo "netperf -4 -L ${LOCAL_ADDR4} -H ${REMOTE_ADDR4} -t UDP_STREAM -l $PERF_TIME" >> perf_result_udp_4
	netperf -4 -L ${LOCAL_ADDR4} -H ${REMOTE_ADDR4} -t UDP_STREAM -l $PERF_TIME 2>&1 >> perf_result_udp_4\
	&& udp_speed_4_send=`cat perf_result_udp_4 | tail -n3 | head -n1 | awk '{print $6}'`\
	&& udp_speed_4_receive=`cat perf_result_udp_4 | tail -n2 | head -n1 | awk '{print $4}'`
	echo "" >> perf_result_udp_4
	echo $udp_speed_4_receive
}
netperf_udp_6() {
	udp_speed_6_send='none'
	udp_speed_6_receive='none'
	echo "" > perf_result_udp_6
	echo "netperf -6 -L ${LOCAL_ADDR6} -H ${REMOTE_ADDR6} -t UDP_STREAM -l $PERF_TIME" >> perf_result_udp_6
	netperf -6 -L ${LOCAL_ADDR6} -H ${REMOTE_ADDR6} -t UDP_STREAM -l $PERF_TIME 2>&1 >> perf_result_udp_6\
	&& udp_speed_6_send=`cat perf_result_udp_6 | tail -n3 | head -n1 | awk '{print $6}'`\
	&& udp_speed_6_receive=`cat perf_result_udp_6 | tail -n2 | head -n1 | awk '{print $4}'`
	echo "" >> perf_result_udp_6
	echo $udp_speed_6_receive
}
netperf_sctp_4() {
	sctp_speed_4='none'
	echo "" > perf_result_sctp_4
	echo "netperf -4 -L ${LOCAL_ADDR4} -H ${REMOTE_ADDR4} -t SCTP_STREAM -l $PERF_TIME -- -m 4096 2" >> perf_result_sctp_4
	netperf -4 -L ${LOCAL_ADDR4} -H ${REMOTE_ADDR4} -t SCTP_STREAM -l $PERF_TIME -- -m 4096 2>&1 >> perf_result_sctp_4\
	&& sctp_speed_4=`cat perf_result_sctp_4 | tail -n1 | awk '{print $5}'`
	echo "" >> perf_result_sctp_4
	echo $sctp_speed_4
}
netperf_sctp_6() {
	sctp_speed_6='none'
	echo "" > perf_result_sctp_6
	echo "netperf -6 -L ${LOCAL_ADDR6} -H ${REMOTE_ADDR6} -t SCTP_STREAM -l $PERF_TIME -- -m 4096 2" >> perf_result_sctp_6
	netperf -6 -L ${LOCAL_ADDR6} -H ${REMOTE_ADDR6} -t SCTP_STREAM -l $PERF_TIME -- -m 4096 2>&1 >> perf_result_sctp_6\
	&& sctp_speed_6=`cat perf_result_sctp_6 | tail -n1 | awk '{print $5}'`
	echo "" >> perf_result_sctp_6
	echo $sctp_speed_6
}

netperf_test() {

	local log_printf_format="||  %-80s||  %-10s||  %-10s||  %-20s||  %-20s||  %-10s||  %-10s||\n"
	local error_count=0
	local test_items=${1:-''}

	PERF_TEST=${PERF_TEST:-"tcp udp sctp"}

	for func in $PERF_TEST; do
		netperf_${func}_4
		cat perf_result_${func}_4
		netperf_${func}_6
		cat perf_result_${func}_6
	done

	if [ ! -f "/tmp/${JOBID}_perf.log" ]; then
		touch /tmp/${JOBID}_perf.log
		printf "$log_printf_format" "Test Items" "IPv4 TCP" "IPv6 TCP" "IPv4 UDP" "IPv6 UDP" "IPv4 SCTP" "IPv6 SCTP" >> /tmp/${JOBID}_perf.log
		printf "$log_printf_format" "----------" "--------" "--------" "--------" "--------" "---------" "---------" >> /tmp/${JOBID}_perf.log
	fi
	printf "$log_printf_format" "$test_items" "$tcp_speed_4" "$tcp_speed_6" "$udp_speed_4_send/$udp_speed_4_receive" "$udp_speed_6_send/$udp_speed_6_receive" "$sctp_speed_4" "$sctp_speed_6" >> /tmp/${JOBID}_perf.log

	pkill -9 netserver
	rm -rf perf_result*

	[ $sctp_speed_6 = 'none' ] && let error_count++
	[ $sctp_speed_4 = 'none' ] && let error_count++
	[ $udp_speed_6_send = 'none' ] && let error_count++
	[ $udp_speed_4_send = 'none' ] && let error_count++
	[ $udp_speed_6_receive = 'none' ] && let error_count++
	[ $udp_speed_4_receive = 'none' ] && let error_count++
	[ $tcp_speed_6 = 'none' ] && let error_count++
	[ $tcp_speed_4 = 'none' ] && let error_count++

	unset sctp_speed_6
	unset sctp_speed_4
	unset udp_speed_6_send
	unset udp_speed_6_receive
	unset udp_speed_4_send
	unset udp_speed_4_receive
	unset tcp_speed_6
	unset tcp_speed_4

	return $error_count
}
