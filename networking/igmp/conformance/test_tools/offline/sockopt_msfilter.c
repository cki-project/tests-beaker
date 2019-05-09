/*
 * sockopt_if.c - IP_MSFILTER/MCAST_MSFILTER socket option test
 * Copyright (C) 2016 Red Hat Inc.
 *
 * Author: Jianlin Shi (jishi@redhat.com)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
 * 02110-1301, USA.
 */

#include "sockopt_utils.h"



void test_ip_msfilter()
{
#define GROUP_JOIN_V4 "239.1.1.1"
#define SOURCE_V41 "192.168.1.1"
#define SOURCE_V42 "192.168.1.2"
#define SOURCE_V43 "192.168.1.3"
#define GROUP_NOTJOIN_V4 "239.1.1.2"
#define GROUP_INVALID_V4 "192.168.11.1"

	struct ip_msfilter filter;
	struct group_req group;
	struct in_addr src_addr_list[3];
	int size_filter;
	int status = 0;
	int i = 0;

	group.gr_interface = 0;
	group.gr_group.ss_family = AF_INET;
	inet_pton(AF_INET, GROUP_JOIN_V4, &((struct sockaddr_in *)&group.gr_group)->sin_addr);
	test_setsockopt("MCAST_JOIN_GROUP 239.1.1.1",
			MCAST_JOIN_GROUP, &group, sizeof(group), 4);


	inet_pton(AF_INET, GROUP_JOIN_V4, &filter.imsf_multiaddr);
	filter.imsf_interface.s_addr = htonl(INADDR_ANY);
	filter.imsf_fmode = MCAST_INCLUDE;
	filter.imsf_numsrc = 3;

	inet_pton(AF_INET, SOURCE_V41, &src_addr_list[0]);
	inet_pton(AF_INET, SOURCE_V42, &src_addr_list[1]);
	inet_pton(AF_INET, SOURCE_V43, &src_addr_list[2]);
	memcpy(filter.imsf_slist, src_addr_list, filter.imsf_numsrc * sizeof(struct in_addr));

	test_setsockopt_error("IP_MSFILTER Bad optlen",
			IP_MSFILTER, &filter, 5, EINVAL, 4);

	inet_pton(AF_INET, GROUP_NOTJOIN_V4, &filter.imsf_multiaddr);
	test_setsockopt_error("IP_MSFILTER group not joined",
			IP_MSFILTER, &filter, IP_MSFILTER_SIZE(filter.imsf_numsrc), EINVAL, 4);

	inet_pton(AF_INET, GROUP_INVALID_V4, &filter.imsf_multiaddr);
	test_setsockopt_error("IP_MSFILTER not multicast addr",
			IP_MSFILTER, &filter, IP_MSFILTER_SIZE(filter.imsf_numsrc), EINVAL, 4);

	inet_pton(AF_INET, "192.168.4.1", &filter.imsf_interface);
	inet_pton(AF_INET, GROUP_JOIN_V4, &filter.imsf_multiaddr);
	test_setsockopt_error("IP_MSFILTER no device found",
			IP_MSFILTER, &filter, IP_MSFILTER_SIZE(filter.imsf_numsrc), ENODEV, 4);

	//when getsockopt for IP_MSFILTER, error occurs with "Invalid argument"
	//But from source code of kernel, there is api for getsockopt for IP_MSFILTER
	//just run setsockopt for the moment
	filter.imsf_interface.s_addr = htonl(INADDR_ANY);
	test_setsockopt("IP_MSFILTER INCLUDE group 239.1.1.1 src 192.168.1.1 192.168.1.2 192.168.1.3",
			IP_MSFILTER, &filter, IP_MSFILTER_SIZE(filter.imsf_numsrc), 4);
	test_setsockopt("IP_MSFILTER INCLUDE group 239.1.1.1 src 192.168.1.1 192.168.1.2 192.168.1.3",
			IP_MSFILTER, &filter, IP_MSFILTER_SIZE(filter.imsf_numsrc), 4);

	filter.imsf_numsrc = 0;
	size_filter= sizeof(filter);
	status = getsockopt(__sockfd, IPPROTO_IP, IP_MSFILTER, &filter, &size_filter);
	if ( status < 0 )
	{
		error_exit("getsockopt for IP_MSFILTER");
	}
	if ( 3 != filter.imsf_numsrc || MCAST_INCLUDE != filter.imsf_fmode )
	{
		printf("fail: %s num of ip_msfilter %d should be  EXCLUDE 3\n", filter.imsf_fmode == MCAST_EXCLUDE?"EXCLUDE":"INCLUDE",filter.imsf_fmode);
		fail();
	}

	//Ditto
	inet_pton(AF_INET, GROUP_JOIN_V4, &filter.imsf_multiaddr);
	filter.imsf_interface.s_addr = htonl(INADDR_ANY);
	filter.imsf_numsrc = 3;
	filter.imsf_fmode = MCAST_EXCLUDE;
	memcpy(filter.imsf_slist, src_addr_list, filter.imsf_numsrc * sizeof(struct in_addr));
	test_setsockopt("IP_MSFILTER EXCLUDE group 239.1.1.1 src 192.168.1.1 192.168.1.2 192.168.1.3",
			IP_MSFILTER, &filter, IP_MSFILTER_SIZE(filter.imsf_numsrc), 4);

	filter.imsf_numsrc = 0;
	size_filter= sizeof(filter);
	status = getsockopt(__sockfd, IPPROTO_IP, IP_MSFILTER, &filter, &size_filter);
	if ( status < 0 )
	{
		error_exit("getsockopt for IP_MSFILTER");
	}
	if ( 3 != filter.imsf_numsrc || MCAST_EXCLUDE != filter.imsf_fmode )
	{
		printf("fail: %s num of ip_msfilter %d should be  EXCLUDE 3\n", filter.imsf_fmode == MCAST_EXCLUDE?"EXCLUDE":"INCLUDE",filter.imsf_fmode);
		fail();
	}

	group.gr_interface = 0;
	group.gr_group.ss_family = AF_INET;
	inet_pton(AF_INET, GROUP_JOIN_V4, &((struct sockaddr_in *)&group.gr_group)->sin_addr);
	test_setsockopt("MCAST_LEAVE_GROUP 239.1.1.1",
			MCAST_LEAVE_GROUP, &group, sizeof(group), 4);

#undef GROUP_JOIN_V4
#undef SOURCE_V41
#undef SOURCE_V42
#undef SOURCE_V43
#undef GROUP_NOTJOIN_V4
#undef GROUP_INVALID_V4
}

void test_mcast_msfilter_v4()
{
#define GROUP_JOIN_V4 "239.1.1.1"
#define SOURCE_V41 "192.168.1.1"
#define SOURCE_V42 "192.168.1.2"
#define SOURCE_V43 "192.168.1.3"
#define GROUP_NOTJOIN_V4 "239.1.1.2"
#define GROUP_INVALID_V4 "192.168.11.1"

	struct group_req group;
	struct group_filter gr_filter;
	struct sockaddr_in *psin4;
	int status = 0;
	int size_grfilter = 0;

	group.gr_interface = 1;
	group.gr_group.ss_family = AF_INET;
	inet_pton(AF_INET, GROUP_JOIN_V4, &((struct sockaddr_in *)&group.gr_group)->sin_addr);
	test_setsockopt("MCAST_JOIN_GROUP 239.1.1.1",
			MCAST_JOIN_GROUP, &group, sizeof(group), 4);

	gr_filter.gf_interface = 1;
	gr_filter.gf_group.ss_family = AF_INET;
	inet_pton(AF_INET, GROUP_JOIN_V4, &((struct sockaddr_in *)&gr_filter.gf_group)->sin_addr);
	gr_filter.gf_numsrc = 3;
	gr_filter.gf_fmode = MCAST_INCLUDE;

	psin4 = (struct sockaddr_in *)&gr_filter.gf_slist[0];
	psin4->sin_family = AF_INET;
	inet_pton(PF_INET, SOURCE_V41, &psin4->sin_addr);

	psin4 = (struct sockaddr_in *)&gr_filter.gf_slist[1];
	psin4->sin_family = AF_INET;
	inet_pton(PF_INET, SOURCE_V42, &psin4->sin_addr);

	psin4 = (struct sockaddr_in *)&gr_filter.gf_slist[2];
	psin4->sin_family = AF_INET;
	inet_pton(PF_INET, SOURCE_V43, &psin4->sin_addr);

	test_setsockopt_error("MCAST_MSFILTER Bad optlen",
			MCAST_MSFILTER, &gr_filter, 5, EINVAL, 4);

	inet_pton(AF_INET, GROUP_INVALID_V4, &((struct sockaddr_in *)&gr_filter.gf_group)->sin_addr);
	test_setsockopt_error("MCAST_MSFILTER not multicast addr",
			MCAST_MSFILTER, &gr_filter, GROUP_FILTER_SIZE(gr_filter.gf_numsrc), EINVAL, 4);

	inet_pton(AF_INET, GROUP_NOTJOIN_V4, &((struct sockaddr_in *)&gr_filter.gf_group)->sin_addr);
	test_setsockopt_error("MCAST_MSFILTER group not joined",
			MCAST_MSFILTER, &gr_filter, GROUP_FILTER_SIZE(gr_filter.gf_numsrc), EINVAL, 4);

	inet_pton(AF_INET, GROUP_JOIN_V4, &((struct sockaddr_in *)&gr_filter.gf_group)->sin_addr);
	gr_filter.gf_interface = 500;
	test_setsockopt_error("MCAST_MSFILTER no device found",
			MCAST_MSFILTER, &gr_filter, GROUP_FILTER_SIZE(gr_filter.gf_numsrc), ENODEV, 4);

	gr_filter.gf_interface = 1;
	test_setsockopt("MCAST_MSFILTER INCLUDE group 239.1.1.1 src 192.168.1.1.1 192.168.1.2 192.168.1.3",
			MCAST_MSFILTER, &gr_filter, GROUP_FILTER_SIZE(gr_filter.gf_numsrc), 4);
	test_setsockopt("MCAST_MSFILTER INCLUDE group 239.1.1.1 src 192.168.1.1.1 192.168.1.2 192.168.1.3",
			MCAST_MSFILTER, &gr_filter, GROUP_FILTER_SIZE(gr_filter.gf_numsrc), 4);

	gr_filter.gf_numsrc = 0;
	gr_filter.gf_fmode = MCAST_EXCLUDE;
	size_grfilter = sizeof(gr_filter);
	status = getsockopt(__sockfd, IPPROTO_IP, MCAST_MSFILTER, &gr_filter, &size_grfilter);
	if ( status < 0 )
	{
		error_exit("getsockopt for MCAST_MSFILTER");
	}
	if ( 3 != gr_filter.gf_numsrc || MCAST_INCLUDE != gr_filter.gf_fmode )
	{
		printf("fail: %s num of mcast_msfilter %d should be  INCLUDE 3\n", gr_filter.gf_fmode == MCAST_EXCLUDE?"EXCLUDE":"INCLUDE",gr_filter.gf_numsrc);
		fail();
	}

	psin4 = (struct sockaddr_in *)&gr_filter.gf_slist[0];
	psin4->sin_family = AF_INET;
	inet_pton(PF_INET, SOURCE_V41, &psin4->sin_addr);

	psin4 = (struct sockaddr_in *)&gr_filter.gf_slist[1];
	psin4->sin_family = AF_INET;
	inet_pton(PF_INET, SOURCE_V42, &psin4->sin_addr);

	psin4 = (struct sockaddr_in *)&gr_filter.gf_slist[2];
	psin4->sin_family = AF_INET;
	inet_pton(PF_INET, SOURCE_V43, &psin4->sin_addr);

	gr_filter.gf_fmode = MCAST_EXCLUDE;
	test_setsockopt("MCAST_MSFILTER EXCLUDE group 239.1.1.1 src 192.168.1.1.1 192.168.1.2 192.168.1.3",
			MCAST_MSFILTER, &gr_filter, GROUP_FILTER_SIZE(gr_filter.gf_numsrc), 4);

	gr_filter.gf_numsrc = 0;
	size_grfilter = sizeof(gr_filter);
	status = getsockopt(__sockfd, IPPROTO_IP, MCAST_MSFILTER, &gr_filter, &size_grfilter);
	if ( status < 0 )
	{
		error_exit("getsockopt for MCAST_MSFILTER");
	}
	if ( 3 != gr_filter.gf_numsrc || MCAST_EXCLUDE != gr_filter.gf_fmode )
	{
		printf("fail: %s num of mcast_msfilter %d should be  INCLUDE 3\n", gr_filter.gf_fmode == MCAST_EXCLUDE?"EXCLUDE":"INCLUDE",gr_filter.gf_numsrc);
		fail();
	}

	group.gr_interface = 1;
	group.gr_group.ss_family = AF_INET;
	inet_pton(AF_INET, GROUP_JOIN_V4, &((struct sockaddr_in *)&group.gr_group)->sin_addr);
	test_setsockopt("MCAST_LEAVE_GROUP 239.1.1.1",
			MCAST_LEAVE_GROUP, &group, sizeof(group), 4);

#undef GROUP_JOIN_V4
#undef SOURCE_V41
#undef SOURCE_V42
#undef SOURCE_V43
#undef GROUP_NOTJOIN_V4
#undef GROUP_INVALID_V4
}

void test_mcast_msfilter_v6()
{
#define GROUP_JOIN_V6 "ff08::1"
#define SOURCE_V61 "2000::1"
#define SOURCE_V62 "2000::2"
#define SOURCE_V63 "2000::3"
#define GROUP_NOTJOIN_V6 "ff08::2"
#define GROUP_INVALID_V6 "2001::1"


	struct group_req group;
	struct group_filter gr_filter;
	struct sockaddr_storage src_addr_list[3];
	struct sockaddr_in6 *psin6;
	int i = 0;
	int status = 0;
	int size_grfilter = 0;

	group.gr_interface = 1;
	group.gr_group.ss_family = AF_INET6;
	inet_pton(AF_INET6, GROUP_JOIN_V6, &((struct sockaddr_in6 *)&group.gr_group)->sin6_addr);
	test_setsockopt("MCAST_JOIN_GROUP ff08::1",
		 MCAST_JOIN_GROUP, &group, sizeof(group), 6);

	gr_filter.gf_interface = 1;
	gr_filter.gf_group.ss_family = AF_INET6;
	inet_pton(AF_INET6, GROUP_JOIN_V6, &((struct sockaddr_in6 *)&gr_filter.gf_group)->sin6_addr);
	gr_filter.gf_fmode = MCAST_INCLUDE;
	gr_filter.gf_numsrc = 3;

	psin6 = (struct sockaddr_in6 *)&gr_filter.gf_slist[0];
	psin6->sin6_family = AF_INET6;
	inet_pton(PF_INET6, SOURCE_V61, &psin6->sin6_addr);

	psin6 = (struct sockaddr_in6 *)&gr_filter.gf_slist[1];
	psin6->sin6_family = AF_INET6;
	inet_pton(PF_INET6, SOURCE_V62, &psin6->sin6_addr);

	psin6 = (struct sockaddr_in6 *)&gr_filter.gf_slist[2];
	psin6->sin6_family = AF_INET6;
	inet_pton(PF_INET6, SOURCE_V63, &psin6->sin6_addr);

	test_setsockopt_error("MCAST_MSFILTER Bad optlen",
			MCAST_MSFILTER, &gr_filter, 5, EINVAL, 6);

	inet_pton(AF_INET6, GROUP_NOTJOIN_V6, &((struct sockaddr_in6 *)&gr_filter.gf_group)->sin6_addr);
	test_setsockopt_error("MCAST_MSFITLER group not joined",
			MCAST_MSFILTER, &gr_filter, GROUP_FILTER_SIZE(gr_filter.gf_numsrc), EINVAL, 6);

	inet_pton(AF_INET6, GROUP_INVALID_V6, &((struct sockaddr_in6 *)&gr_filter.gf_group)->sin6_addr);
	test_setsockopt_error("MCAST_MSFITLER not multicast addr",
			MCAST_MSFILTER, &gr_filter, GROUP_FILTER_SIZE(gr_filter.gf_numsrc), EINVAL, 6);

	gr_filter.gf_interface = 500;
	inet_pton(AF_INET6, GROUP_JOIN_V6, &((struct sockaddr_in6 *)&gr_filter.gf_group)->sin6_addr);
	test_setsockopt_error("MCAST_MSFITLER no device found",
			MCAST_MSFILTER, &gr_filter, GROUP_FILTER_SIZE(gr_filter.gf_numsrc), ENODEV, 6);

	gr_filter.gf_interface = 1;
	test_setsockopt("MCAST_MSFILTER INCLUDE group ff08::1 src 2000::1 2000::2 2000::3",
		 MCAST_MSFILTER, &gr_filter, GROUP_FILTER_SIZE(gr_filter.gf_numsrc), 6);
	test_setsockopt("MCAST_MSFILTER INCLUDE group ff08::1 src 2000::1 2000::2 2000::3",
		 MCAST_MSFILTER, &gr_filter, GROUP_FILTER_SIZE(gr_filter.gf_numsrc), 6);

	gr_filter.gf_fmode = MCAST_EXCLUDE;
	gr_filter.gf_numsrc = 0;
	size_grfilter = sizeof(gr_filter);
	status = getsockopt(__sockfd, IPPROTO_IPV6, MCAST_MSFILTER, &gr_filter, &size_grfilter);
	if ( status < 0 )
	{
		error_exit("getsockopt for MCAST_MSFILTER");
	}
	if ( 3 != gr_filter.gf_numsrc || MCAST_INCLUDE != gr_filter.gf_fmode )
	{
		printf("fail: %s num of mcast_msfilter %d should be  INCLUDE 3\n", gr_filter.gf_fmode == MCAST_EXCLUDE?"EXCLUDE":"INCLUDE",gr_filter.gf_numsrc);
		fail();
	}

	gr_filter.gf_fmode = MCAST_EXCLUDE;
	test_setsockopt("MCAST_MSFILTER EXCLUDE group ff08::1 src 2000::1 2000::2 2000::3",
		 MCAST_MSFILTER, &gr_filter, GROUP_FILTER_SIZE(gr_filter.gf_numsrc), 6);

	gr_filter.gf_numsrc = 0;
	size_grfilter = sizeof(gr_filter);
	status = getsockopt(__sockfd, IPPROTO_IPV6, MCAST_MSFILTER, &gr_filter, &size_grfilter);
	if ( status < 0 )
	{
		error_exit("getsockopt for MCAST_MSFILTER");
	}
	if ( 3 != gr_filter.gf_numsrc || MCAST_EXCLUDE != gr_filter.gf_fmode )
	{
		printf("fail: %s num of mcast_msfilter %d should be  EXCLUDE 3\n", gr_filter.gf_fmode == MCAST_EXCLUDE?"EXCLUDE":"INCLUDE",gr_filter.gf_numsrc);
		fail();
	}

	group.gr_interface = 1;
	group.gr_group.ss_family = AF_INET6;
	inet_pton(AF_INET6, GROUP_JOIN_V6, &((struct sockaddr_in6 *)&group.gr_group)->sin6_addr);
	test_setsockopt("MCAST_LEAVE_GROUP ff08::1",
		 MCAST_LEAVE_GROUP, &group, sizeof(group), 6);

#undef GROUP_JOIN_V6
#undef SOURCE_V61
#undef SOURCE_V62
#undef SOURCE_V63
#undef GROUP_NOTJOIN_V6
#undef GROUP_INVALID_V6
}

int main(int argc, char *argv[])
{
	int version=4;
	parse_args(argc, argv, &version);
	if ( version !=4 && version != 6)
	{
		usage(argv[0]);
		return 1;
	}
	initialize(version);

	if ( 4 == version )
	{
		test_ip_msfilter();
		test_mcast_msfilter_v4();
	}
	else
	{
		test_mcast_msfilter_v6();
	}

	report_and_exit();
	return 0;
}
