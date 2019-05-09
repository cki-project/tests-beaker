/*
 * sockopt_group.c - IPV6_JOIN_GROUP/IPV6_LEAVE_GROUP/MCAST_JOIN_GROUP/
 * MCAST_LEAVE_GROUP socket option test
 * Copyright (C) 2016 Red Hat Inc.
 *
 * Author:Jianlin Shi(jishi@redhat.com)
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



void test_ipv6_group()
{
#define V6GROUP_JOIN "ff05::1"
#define V6_GROUP_INVALID "2012::1"
#define V6_GROUP_NOTJOIN "ff05::2"
	struct ipv6_mreq mreq_test;
	size_t size = sizeof(mreq_test);
	int ret;

	/* IPV6_JOIN_GROUP */
	ret = inet_pton(AF_INET6, V6GROUP_JOIN, &mreq_test.ipv6mr_multiaddr);
	mreq_test.ipv6mr_interface = 0;

	test_setsockopt_error("IPV6_JOIN_GROUP bad optlen",
			IPV6_JOIN_GROUP, &mreq_test, 5, EINVAL, 6);

	ret = inet_pton(AF_INET6, V6_GROUP_INVALID, &mreq_test.ipv6mr_multiaddr);
	test_setsockopt_error("IPV6_JOIN_GROUP bad multicast addr",
			IPV6_JOIN_GROUP, &mreq_test, size, EINVAL, 6);

	ret = inet_pton(AF_INET6, V6GROUP_JOIN, &mreq_test.ipv6mr_multiaddr);
	mreq_test.ipv6mr_interface = 500;
	test_setsockopt_error("IPV6_JOIN_GROUP no device found",
			IPV6_JOIN_GROUP, &mreq_test, size, ENODEV, 6);

	ret = inet_pton(AF_INET6, V6GROUP_JOIN, &mreq_test.ipv6mr_multiaddr);
	mreq_test.ipv6mr_interface = 0;
	test_setsockopt("IPV6_JOIN_GROUP ff05::1",
			IPV6_JOIN_GROUP, &mreq_test, size, 6);

	test_setsockopt_error("IPV6_JOIN_GROUP group have joined",
			IPV6_JOIN_GROUP, &mreq_test, size, EADDRINUSE, 6);

	/*IPV6_LEAVE_GROUP*/

	mreq_test.ipv6mr_interface = 0;
	ret = inet_pton(AF_INET6, V6GROUP_JOIN, &mreq_test.ipv6mr_multiaddr);
	test_setsockopt_error("IPV6_LEAVE_GROUP Bad optlen",
			IPV6_LEAVE_GROUP, &mreq_test, 5, EINVAL, 6);

	ret = inet_pton(AF_INET6, V6_GROUP_INVALID, &mreq_test.ipv6mr_multiaddr);
#ifndef EL6
	test_setsockopt_error("IPV6_LEAVE_GROUP not multicast addr",
			IPV6_LEAVE_GROUP, &mreq_test, size, EINVAL, 6);
#else
	test_setsockopt_error("IPV6_LEAVE_GROUP not multicast addr",
			IPV6_LEAVE_GROUP, &mreq_test, size, EADDRNOTAVAIL, 6);
#endif

	//FIXME setsockopt return EADDRNOTAVAIL rather than ENODEV, it means
	//that it check ipv6mr_multiaddr first
	ret = inet_pton(AF_INET6, V6GROUP_JOIN, &mreq_test.ipv6mr_multiaddr);
	mreq_test.ipv6mr_interface = 500;
	test_setsockopt_error("IPV6_LEAVE_GROUP No device found",
			IPV6_LEAVE_GROUP, &mreq_test, size, EADDRNOTAVAIL, 6);

	mreq_test.ipv6mr_interface = 0;
	ret = inet_pton(AF_INET6, V6GROUP_JOIN, &mreq_test.ipv6mr_multiaddr);
	test_setsockopt("IPV6_LEAVE_GROUP ff05::1",
			IPV6_LEAVE_GROUP, &mreq_test, size, 6);

	ret = inet_pton(AF_INET6, V6_GROUP_NOTJOIN, &mreq_test.ipv6mr_multiaddr);
	test_setsockopt_error("IPV6_LEAVE_GROUP group not joined",
			IPV6_LEAVE_GROUP, &mreq_test, size, EADDRNOTAVAIL, 6);
#undef V6GROUP_JOIN
#undef V6_GROUP_INVALID
#undef V6_GROUP_NOTJOIN
}

void test_mcast_group_v6()
{
#define MCASTV6_GROUP_JOIN "ff06::1"
#define MCASTV6_GROUP_NOTJOIN "ff06::2"
#define MCASTV6_GROUP_INVALID "2011::1"
	struct group_req group;
	size_t size = sizeof(group);
	int ret;

	/*MCAST_JOIN_GROUP*/

	group.gr_interface = 0;
	group.gr_group.ss_family = AF_INET6;
	inet_pton(AF_INET6, MCASTV6_GROUP_JOIN, &((struct sockaddr_in6 *)&group.gr_group)->sin6_addr);

	test_setsockopt_error("MCAST_JOIN_GROUP Bad optlen",
			MCAST_JOIN_GROUP, &group, 5, EINVAL, 6);

	ret = inet_pton(AF_INET6, MCASTV6_GROUP_INVALID, &((struct sockaddr_in6 *)&group.gr_group)->sin6_addr);
	test_setsockopt_error("MCAST_JOIN_GROUP not multicast address",
			MCAST_JOIN_GROUP, &group, size, EINVAL, 6);

	group.gr_interface = 500;
	ret = inet_pton(AF_INET6, MCASTV6_GROUP_JOIN, &((struct sockaddr_in6 *)&group.gr_group)->sin6_addr);
	test_setsockopt_error("MCAST_JOIN_GROUP no device found",
			MCAST_JOIN_GROUP, &group, size, ENODEV, 6);

	group.gr_interface = 0;
	inet_pton(AF_INET6, MCASTV6_GROUP_JOIN, &((struct sockaddr_in6 *)&group.gr_group)->sin6_addr);
	test_setsockopt("MCAST_JOIN_GROUP ff06::1",
			MCAST_JOIN_GROUP, &group, size, 6);

	test_setsockopt_error("MCAST_JOIN_GROUP have joined",
			MCAST_JOIN_GROUP, &group, size, EADDRINUSE, 6);

	/*MCAST_LEAVE_GROUP*/

	group.gr_interface = 0;
	ret = inet_pton(AF_INET6, MCASTV6_GROUP_JOIN, &((struct sockaddr_in6 *)&group.gr_group)->sin6_addr);
	test_setsockopt_error("MCAST_LEAVE_GROUP Bad optlen",
			MCAST_LEAVE_GROUP, &group, 5, EINVAL, 6);

	ret = inet_pton(AF_INET6, MCASTV6_GROUP_INVALID, &((struct sockaddr_in6 *)&group.gr_group)->sin6_addr);
#ifndef EL6
	test_setsockopt_error("MCAST_LEAVE_GROUP not multicast addr",
			MCAST_LEAVE_GROUP, &group, size, EINVAL, 6);
#else
	test_setsockopt_error("MCAST_LEAVE_GROUP not multicast addr",
			MCAST_LEAVE_GROUP, &group, size, EADDRNOTAVAIL, 6);
#endif

	//FIXME the same problem as IPV6_LEAVE_GROUP
	group.gr_interface = 500;
	ret = inet_pton(AF_INET6, MCASTV6_GROUP_JOIN, &((struct sockaddr_in6 *)&group.gr_group)->sin6_addr);
	test_setsockopt_error("MCAST_LEAVE_GROUP no device found",
			MCAST_LEAVE_GROUP, &group, size, EADDRNOTAVAIL, 6);

	group.gr_interface = 0;
	ret = inet_pton(AF_INET6, MCASTV6_GROUP_JOIN, &((struct sockaddr_in6 *)&group.gr_group)->sin6_addr);
	test_setsockopt("MCAST_LEAVE_GROUP ff06::1",
			MCAST_LEAVE_GROUP, &group, size, 6);

	ret = inet_pton(AF_INET6, MCASTV6_GROUP_NOTJOIN, &((struct sockaddr_in6 *)&group.gr_group)->sin6_addr);
	test_setsockopt_error("MCAST_LEAVE_GROUP multicast not joined",
			MCAST_LEAVE_GROUP, &group, size, EADDRNOTAVAIL, 6);
#undef MCASTV6_GROUP_JOIN
#undef MCASTV6_GROUP_NOTJOIN
#undef MCASTV6_GROUP_INVALID
}

void test_mcast_group_v4()
{
#define MCASTV4_GROUP_JOIN "239.1.1.4"
#define MCASTV4_GROUP_INVALID "192.168.1.11"
#define MCASTV4_GROUP_NOTJOIN "239.1.1.11"

	struct group_req group;
	size_t size = sizeof(group);
	int ret;

	/*MCAST_JOIN_GROUP*/
	group.gr_interface = 0;
	group.gr_group.ss_family = AF_INET;
	inet_pton(AF_INET, MCASTV4_GROUP_JOIN, &((struct sockaddr_in *)&group.gr_group)->sin_addr);

	test_setsockopt_error("MCAST_JOIN_GROUP Bad optlen",
			MCAST_JOIN_GROUP, &group, 5, EINVAL, 4);

	inet_pton(AF_INET, MCASTV4_GROUP_INVALID, &((struct sockaddr_in *)&group.gr_group)->sin_addr);
	test_setsockopt_error("MCAST_JOIN_GROUP not multicast addr",
			MCAST_JOIN_GROUP, &group, size, EINVAL, 4);

	group.gr_interface = 500;
	inet_pton(AF_INET, MCASTV4_GROUP_JOIN, &((struct sockaddr_in *)&group.gr_group)->sin_addr);
	test_setsockopt_error("MCAST_JOIN_GROUP no device found",
			MCAST_JOIN_GROUP, &group, size, ENODEV, 4);

	group.gr_interface = 0;
	inet_pton(AF_INET, MCASTV4_GROUP_JOIN, &((struct sockaddr_in *)&group.gr_group)->sin_addr);
	test_setsockopt("MCAST_JOIN_GROUP group 239.1.1.4",
			MCAST_JOIN_GROUP, &group, size, 4);

	test_setsockopt_error("MCAST_JOIN_GROUP group have joined",
			MCAST_JOIN_GROUP, &group, size, EADDRINUSE, 4);

	/*MCAST_LEAVE_GROUP*/
	test_setsockopt_error("MCAST_LEAVE_GROUP Bad optlen",
			MCAST_LEAVE_GROUP, &group, 5, EINVAL, 4);

	inet_pton(AF_INET, MCASTV4_GROUP_INVALID, &((struct sockaddr_in *)&group.gr_group)->sin_addr);
	test_setsockopt_error("MCAST_LEAVE_GROUP not multicast addr",
			MCAST_LEAVE_GROUP, &group, size, EADDRNOTAVAIL, 4);

	group.gr_interface = 500;
	inet_pton(AF_INET, MCASTV4_GROUP_JOIN, &((struct sockaddr_in *)&group.gr_group)->sin_addr);
#ifndef EL6
	test_setsockopt_error("MCAST_LEAVE_GROUP no device found",
			MCAST_LEAVE_GROUP, &group, size, EADDRNOTAVAIL, 4);
#else
	test_setsockopt_error("MCAST_LEAVE_GROUP no device found",
			MCAST_LEAVE_GROUP, &group, size, ENODEV, 4);
#endif

	group.gr_interface = 0;
	inet_pton(AF_INET, MCASTV4_GROUP_JOIN, &((struct sockaddr_in *)&group.gr_group)->sin_addr);
	test_setsockopt("MCAST_LEAVE_GROUP group 239.1.1.4",
			MCAST_LEAVE_GROUP, &group, size, 4);

	inet_pton(AF_INET, MCASTV4_GROUP_NOTJOIN, &((struct sockaddr_in *)&group.gr_group)->sin_addr);
	test_setsockopt_error("MCAST_LEAVE_GROUP group not joined",
			MCAST_LEAVE_GROUP, &group, size, EADDRNOTAVAIL, 4);
#undef MCASTV4_GROUP_JOIN
#undef MCASTV4_GROUP_INVALID
#undef MCASTV4_GROUP_NOTJOIN
}

int main(int argc, char* argv[])
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
		test_mcast_group_v4();
	}
	else
	{
		test_ipv6_group();
		test_mcast_group_v6();
	}

	report_and_exit();
	return 0;
}
