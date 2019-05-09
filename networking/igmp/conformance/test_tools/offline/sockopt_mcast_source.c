/*
 * sockopt_source_membership.c - MCAST_BLOCK_SOURCE/MCAST_UNBLOCK_SOURCE/
 * MCAST_JOIN_SOURCE_GROUP/MCAST_LEAVE_SOURCE_GROUP socket
 *				 option test
 *
 * Copyright (C) 2016 Red Hat Inc.
 *
 * Author: Jianlin Shi(jishi@redhat.com)
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


void test_mcast_join_leave_source_v4()
{

#define V4GROUP_JOIN "239.1.1.2"
#define V4SOURCE_JOIN "192.168.111.1"
#define V4GROUP_NOTJOIN "239.1.1.3"
#define V4SOURCE_NOTJOIN "192.168.111.2"
#define V4GROUP_INVALID "192.168.1.11"
	struct group_source_req group_sr;
	size_t size = sizeof(group_sr);

	/*MCAST_JOIN_SOURCE_GROUP*/
	group_sr.gsr_interface = 0;
	group_sr.gsr_group.ss_family = AF_INET;
	group_sr.gsr_source.ss_family = AF_INET;
	inet_pton(AF_INET, V4GROUP_JOIN, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	inet_pton(AF_INET, V4SOURCE_JOIN, &((struct sockaddr_in *)&group_sr.gsr_source)->sin_addr);

	test_setsockopt_error("MCAST_JOIN_SOURCE_GROUP Bad optlen",
			MCAST_JOIN_SOURCE_GROUP, &group_sr, 5, EINVAL, 4);

	inet_pton(AF_INET, V4GROUP_INVALID, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	test_setsockopt_error("MCAST_JOIN_SOURCE_GROUP not multicast addr",
			MCAST_JOIN_SOURCE_GROUP, &group_sr, size, EINVAL, 4);

	group_sr.gsr_interface = 500;
	inet_pton(AF_INET, V4GROUP_JOIN, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	test_setsockopt_error("MCAST_JOIN_SOURCE_GROUP no device found",
			MCAST_JOIN_SOURCE_GROUP, &group_sr, size, ENODEV, 4);

	group_sr.gsr_interface = 0;
	inet_pton(AF_INET, V4GROUP_JOIN, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	inet_pton(AF_INET, V4SOURCE_JOIN, &((struct sockaddr_in *)&group_sr.gsr_source)->sin_addr);
	test_setsockopt("MCAST_JOIN_SOURCE_GROUP group 239.1.1.2 src 192.168.111.1",
			MCAST_JOIN_SOURCE_GROUP, &group_sr, size, 4);

	test_setsockopt_error("MCAST_JOIN_SOURCE_GROUP group have joined",
			MCAST_JOIN_SOURCE_GROUP, &group_sr, size, EADDRNOTAVAIL, 4);

	/*MCAST_LEAVE_SOURCE_GROUP*/
	group_sr.gsr_interface = 0;
	inet_pton(AF_INET, V4GROUP_JOIN, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	test_setsockopt_error("MCAST_LEAVE_SOURCE_GROUP Bad optlen",
			MCAST_LEAVE_SOURCE_GROUP, &group_sr, 5, EINVAL, 4);

	inet_pton(AF_INET, V4GROUP_INVALID, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	test_setsockopt_error("MCAST_LEAVE_SOURCE_GROUP not multicast addr",
			MCAST_LEAVE_SOURCE_GROUP, &group_sr, size, EINVAL, 4);

	group_sr.gsr_interface = 500;
	inet_pton(AF_INET, V4GROUP_JOIN, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	test_setsockopt_error("MCAST_LEAVE_SOURCE_GROUP no device found",
			MCAST_LEAVE_SOURCE_GROUP, &group_sr, size, ENODEV, 4);

	group_sr.gsr_interface = 0;
	inet_pton(AF_INET, V4GROUP_JOIN, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	inet_pton(AF_INET, V4SOURCE_NOTJOIN, &((struct sockaddr_in *)&group_sr.gsr_source)->sin_addr);
	test_setsockopt_error("MCAST_LEAVE_SOURCE_GROUP source not joined",
			MCAST_LEAVE_SOURCE_GROUP, &group_sr, size, EADDRNOTAVAIL, 4);

	inet_pton(AF_INET, V4GROUP_NOTJOIN, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	inet_pton(AF_INET, V4SOURCE_JOIN, &((struct sockaddr_in *)&group_sr.gsr_source)->sin_addr);
	test_setsockopt_error("MCAST_LEAVE_SOURCE_GROUP group not joined",
			MCAST_LEAVE_SOURCE_GROUP, &group_sr, size, EINVAL, 4);

	inet_pton(AF_INET, V4GROUP_JOIN, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	test_setsockopt("MCAST_LEAVE_SOURCE_GROUP group 192.168.1.1.1 src 192.168.111.1",
			MCAST_LEAVE_SOURCE_GROUP, &group_sr, size, 4);

#undef V4GROUP_JOIN
#undef V4SOURCE_JOIN
#undef V4GROUP_NOTJOIN
#undef V4SOURCE_NOTJOIN
#undef V4GROUP_INVALID
}

void test_mcast_join_leave_source_v6()
{
#define V6GROUP_JOIN "ff07::1"
#define V6SOURCE_JOIN "2000::1"
#define V6GROUP_INVALID "2001::1"
#define V6GROUP_NOTJOIN "ff08::1"
#define V6SOURCE_NOTJOIN "2002::1"
	struct group_source_req group_sr;
	size_t size = sizeof(group_sr);

	/*MCAST_JOIN_SOURCE_GROUP*/
	group_sr.gsr_interface = 0;
	group_sr.gsr_group.ss_family = AF_INET6;
	group_sr.gsr_source.ss_family = AF_INET6;
	inet_pton(AF_INET6, V6GROUP_JOIN, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	inet_pton(AF_INET6, V6SOURCE_JOIN, &((struct sockaddr_in6 *)&group_sr.gsr_source)->sin6_addr);

	test_setsockopt_error("MCAST_JOIN_SOURCE_GROUP Bad optlen",
			MCAST_JOIN_SOURCE_GROUP, &group_sr, 5, EINVAL, 6);

	inet_pton(AF_INET6, V6GROUP_INVALID, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	test_setsockopt_error("MCAST_JOIN_SOURCE_GROUP not multicast addr",
			MCAST_JOIN_SOURCE_GROUP, &group_sr, size, EINVAL, 6);

	inet_pton(AF_INET6, V6GROUP_JOIN, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	group_sr.gsr_interface = 500;
	test_setsockopt_error("MCAST_JOIN_SOURCE_GROUP no device found",
			MCAST_JOIN_SOURCE_GROUP, &group_sr, size, ENODEV, 6);

	group_sr.gsr_interface = 0;
	inet_pton(AF_INET6, V6GROUP_JOIN, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	inet_pton(AF_INET6, V6SOURCE_JOIN, &((struct sockaddr_in6 *)&group_sr.gsr_source)->sin6_addr);
	test_setsockopt("MCAST_JOIN_SOURCE_GROUP group ff07::1 src 2000::1",
			MCAST_JOIN_SOURCE_GROUP, &group_sr, size, 6);

	test_setsockopt_error("MCAST_JOIN_SOURCE_GROUP group have joined",
			MCAST_JOIN_SOURCE_GROUP, &group_sr, size, EADDRNOTAVAIL, 6);

	/*MCAST_LEAVE_SOURCE_GROUP*/
	group_sr.gsr_interface = 0;
	inet_pton(AF_INET6, V6GROUP_JOIN, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	test_setsockopt_error("MCAST_LEAVE_SOURCE_GROUP Bad optlen",
			MCAST_LEAVE_SOURCE_GROUP, &group_sr, 5, EINVAL, 6);

	inet_pton(AF_INET6, V6GROUP_INVALID, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	test_setsockopt_error("MCAST_LEAVE_SOURCE_GROUP not multicast addr",
			MCAST_LEAVE_SOURCE_GROUP, &group_sr, size, EINVAL, 6);

	inet_pton(AF_INET6, V6GROUP_JOIN, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	group_sr.gsr_interface = 500;
	test_setsockopt_error("MCAST_LEAVE_SOURCE_GROUP no device found",
			MCAST_LEAVE_SOURCE_GROUP, &group_sr, size, ENODEV, 6);

	inet_pton(AF_INET6, V6GROUP_JOIN, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	inet_pton(AF_INET6, V6SOURCE_NOTJOIN, &((struct sockaddr_in6 *)&group_sr.gsr_source)->sin6_addr);
	group_sr.gsr_interface = 0;
	test_setsockopt_error("MCAST_LEAVE_SOURCE_GROUP source not joined",
			MCAST_LEAVE_SOURCE_GROUP, &group_sr, size, EADDRNOTAVAIL, 6);

	inet_pton(AF_INET6, V6GROUP_NOTJOIN, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	inet_pton(AF_INET6, V6SOURCE_JOIN, &((struct sockaddr_in6 *)&group_sr.gsr_source)->sin6_addr);
	test_setsockopt_error("MCAST_LEAVE_SOURCE_GROUP group not joined",
			MCAST_LEAVE_SOURCE_GROUP, &group_sr, size, EINVAL, 6);

	group_sr.gsr_interface = 0;
	inet_pton(AF_INET6, V6GROUP_JOIN, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	inet_pton(AF_INET6, V6SOURCE_JOIN, &((struct sockaddr_in6 *)&group_sr.gsr_source)->sin6_addr);
	test_setsockopt("MCAST_LEAVE_SOURCE_GROUP group ff07::1 src 2000::1",
			MCAST_LEAVE_SOURCE_GROUP, &group_sr, size, 6);

#undef V6GROUP_JOIN
#undef V6SOURCE_JOIN
#undef V6GROUP_INVALID
#undef V6GROUP_NOTJOIN
#undef V6SOURCE_NOTJOIN
}

void test_mcast_block_unblock_source_v4()
{
#define V4GROUP_BLOCK "239.1.1.5"
#define V4SOURCE_BLOCK "192.168.111.1"
#define V4GROUP_INVALID "192.168.1.11"
#define V4GROUP_NOTBLOCK "239.1.1.6"
#define V4SOURCE_NOTBLOCK "192.168.111.2"
	struct group_req group;
	struct group_source_req group_sr;
	size_t size = sizeof(group_sr);

	group.gr_interface = 0;
	group.gr_group.ss_family = AF_INET;
	inet_pton(AF_INET, V4GROUP_BLOCK, &((struct sockaddr_in *)&group.gr_group)->sin_addr);
	test_setsockopt("MCAST_JOIN_GROUP 239.1.1.5",
			MCAST_JOIN_GROUP, &group, sizeof(group), 4);

	/*MCAST_BLOCK_SOURCE*/
	group_sr.gsr_interface = 0;
	group_sr.gsr_group.ss_family = AF_INET;
	group_sr.gsr_source.ss_family = AF_INET;
	inet_pton(AF_INET, V4GROUP_BLOCK, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	inet_pton(AF_INET, V4SOURCE_BLOCK, &((struct sockaddr_in *)&group_sr.gsr_source)->sin_addr);

	test_setsockopt_error("MCAST_BLOCK_SOURCE Bad optlen",
			MCAST_BLOCK_SOURCE, &group_sr, 5, EINVAL, 4);

	inet_pton(AF_INET, V4GROUP_INVALID, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	test_setsockopt_error("MCAST_BLOCK_SOURCE not multicast addr",
			MCAST_BLOCK_SOURCE, &group_sr, size, EINVAL, 4);

	inet_pton(AF_INET, V4GROUP_BLOCK, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	group_sr.gsr_interface = 500;
	test_setsockopt_error("MCAST_BLOCK_SOURCE no device found",
			MCAST_BLOCK_SOURCE, &group_sr, size, ENODEV, 4);

	group_sr.gsr_interface = 0;
	inet_pton(AF_INET, V4GROUP_BLOCK, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	inet_pton(AF_INET, V4SOURCE_BLOCK, &((struct sockaddr_in *)&group_sr.gsr_source)->sin_addr);
	test_setsockopt("MCAST_BLOCK_SOURCE group 239.1.1.5 src 192.168.111.1",
			MCAST_BLOCK_SOURCE, &group_sr, size, 4);

	test_setsockopt_error("MCAST_BLOCK_SOURCE group and source have blocked",
			MCAST_BLOCK_SOURCE, &group_sr, size, EADDRNOTAVAIL, 4);

	inet_pton(AF_INET, V4GROUP_NOTBLOCK, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	test_setsockopt_error("MCAST_BLOCK_SOURCE group not joined",
			MCAST_BLOCK_SOURCE, &group_sr, size, EINVAL, 4);

	/*MCAST_UNBLOCK_SOURCE*/
	inet_pton(AF_INET, V4GROUP_BLOCK, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	inet_pton(AF_INET, V4SOURCE_NOTBLOCK, &((struct sockaddr_in *)&group_sr.gsr_source)->sin_addr);
	test_setsockopt_error("MCAST_UNBLOCK_SOURCE source not blocked",
			MCAST_UNBLOCK_SOURCE, &group_sr, size, EADDRNOTAVAIL, 4);

	inet_pton(AF_INET, V4GROUP_NOTBLOCK, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	inet_pton(AF_INET, V4SOURCE_BLOCK, &((struct sockaddr_in *)&group_sr.gsr_source)->sin_addr);
	test_setsockopt_error("MCAST_UNBLOCK_SOURCE group not blocked",
			MCAST_UNBLOCK_SOURCE, &group_sr, size, EINVAL, 4);

	inet_pton(AF_INET, V4SOURCE_BLOCK, &((struct sockaddr_in *)&group_sr.gsr_source)->sin_addr);
	test_setsockopt_error("MCAST_UNBLOCK_SOURCE Bad optlen",
			MCAST_UNBLOCK_SOURCE, &group_sr, 5, EINVAL, 4);

	inet_pton(AF_INET, V4GROUP_INVALID, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	test_setsockopt_error("MCAST_UNBLOCK_SOURCE not multicast addr",
			MCAST_UNBLOCK_SOURCE, &group_sr, size, EINVAL, 4);

	group_sr.gsr_interface = 500;
	inet_pton(AF_INET, V4GROUP_BLOCK, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	test_setsockopt_error("MCAST_UNBLOCK_SOURCE no device found",
			MCAST_UNBLOCK_SOURCE, &group_sr, size, ENODEV, 4);

	group_sr.gsr_interface = 0;
	inet_pton(AF_INET, V4GROUP_BLOCK, &((struct sockaddr_in *)&group_sr.gsr_group)->sin_addr);
	test_setsockopt("MCAST_UNBLOCK_SOURCE group 239.1.1.5 src 192.168.111.1",
			MCAST_UNBLOCK_SOURCE, &group_sr, size, 4);

	test_setsockopt("MCAST_LEAVE_GROUP 239.1.1.5",
			MCAST_LEAVE_GROUP, &group, sizeof(group), 4);
#undef V4GROUP_BLOCK
#undef V4SOURCE_BLOCK
#undef V4GROUP_INVALID
#undef V4GROUP_NOTBLOCK
#undef V4SOURCE_NOTBLOCK
}

void test_mcast_block_unblock_source_v6()
{
#define V6GROUP_BLOCK "ff08::1"
#define V6SOURCE_BLOCK "2000::1"
#define V6GROUP_INVALID "2002::1"
#define V6SOURCE_NOTBLOCK "2001::1"
#define V6GROUP_NOTBLOCK "ff09::1"

	struct group_req group;
	struct group_source_req group_sr;
	size_t size = sizeof(group_sr);

	group.gr_interface = 0;
	group.gr_group.ss_family = AF_INET6;
	inet_pton(AF_INET6, V6GROUP_BLOCK, &((struct sockaddr_in6 *)&group.gr_group)->sin6_addr);
	test_setsockopt("MCAST_JOIN_GROUP ff08::1",
			MCAST_JOIN_GROUP, &group, sizeof(group), 6);

	/*MCAST_BLOCK_SOURCE*/
	group_sr.gsr_interface = 0;
	group_sr.gsr_group.ss_family = AF_INET6;
	group_sr.gsr_source.ss_family = AF_INET6;
	inet_pton(AF_INET6, V6GROUP_BLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	inet_pton(AF_INET6, V6SOURCE_BLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_source)->sin6_addr);

	test_setsockopt_error("MCAST_BLOCK_SOURCE Bad optlen",
			MCAST_BLOCK_SOURCE, &group_sr, 5, EINVAL, 6);

	inet_pton(AF_INET6, V6GROUP_INVALID, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	test_setsockopt_error("MCAST_BLOCK_SOURCE not multicast addr",
			MCAST_BLOCK_SOURCE, &group_sr, size, EINVAL, 6);

	group_sr.gsr_interface = 500;
	inet_pton(AF_INET6, V6GROUP_BLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	test_setsockopt_error("MCAST_BLOCK_SOURCE no device found",
			MCAST_BLOCK_SOURCE, &group_sr, size, ENODEV, 6);

	group_sr.gsr_interface = 0;
	inet_pton(AF_INET6, V6GROUP_BLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	inet_pton(AF_INET6, V6SOURCE_BLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_source)->sin6_addr);
	test_setsockopt("MCAST_BLOCK_SOURCE group ff08::1 src 2000::1",
			MCAST_BLOCK_SOURCE, &group_sr, size, 6);

	group_sr.gsr_interface = 0;
	inet_pton(AF_INET6, V6GROUP_NOTBLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	test_setsockopt_error("MCAST_BLOCK_SOURCE group not joined",
			MCAST_BLOCK_SOURCE, &group_sr, size, EINVAL, 6);

	/*MCAST_UNBLOCK_SOURCE*/
	inet_pton(AF_INET6, V6GROUP_BLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	inet_pton(AF_INET6, V6SOURCE_NOTBLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_source)->sin6_addr);
	test_setsockopt_error("MCAST_UNBLOCK_SOURCE source not blocked",
			MCAST_UNBLOCK_SOURCE, &group_sr, size, EADDRNOTAVAIL, 6);

	inet_pton(AF_INET6, V6GROUP_NOTBLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	inet_pton(AF_INET6, V6SOURCE_BLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_source)->sin6_addr);
	test_setsockopt_error("MCAST_UNBLOCK_SOURCE group not blocked",
			MCAST_UNBLOCK_SOURCE, &group_sr, size, EINVAL, 6);

	inet_pton(AF_INET6, V6SOURCE_BLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_source)->sin6_addr);
	test_setsockopt_error("MCAST_UNBLOCK_SOURCE Bad optlen",
			MCAST_UNBLOCK_SOURCE, &group_sr, 5, EINVAL, 6);

	inet_pton(AF_INET6, V6GROUP_INVALID, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	test_setsockopt_error("MCAST_UNBLOCK_SOURCE not multicast addr",
			MCAST_UNBLOCK_SOURCE, &group_sr, size, EINVAL, 6);

	inet_pton(AF_INET6, V6GROUP_BLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	inet_pton(AF_INET6, V6SOURCE_BLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_source)->sin6_addr);
	group_sr.gsr_interface = 500;
	test_setsockopt_error("MCAST_UNBLOCK_SOURCE no device found",
			MCAST_UNBLOCK_SOURCE, &group_sr, size, ENODEV, 6);

	inet_pton(AF_INET6, V6GROUP_BLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_group)->sin6_addr);
	inet_pton(AF_INET6, V6SOURCE_BLOCK, &((struct sockaddr_in6 *)&group_sr.gsr_source)->sin6_addr);
	group_sr.gsr_interface = 0;
	test_setsockopt("MCAST_UNBLOCK_SOURCE group ff08::1 src 2000::1",
			MCAST_UNBLOCK_SOURCE, &group_sr, size, 6);

	test_setsockopt("MCAST_LEAVE_GROUP ff08::1",
			MCAST_LEAVE_GROUP, &group, sizeof(group), 6);
#undef V6GROUP_BLOCK
#undef V6SOURCE_BLOCK
#undef V6GROUP_INVALID
#undef V6SOURCE_NOTBLOCK
#undef V6GROUP_NOTBLOCK
}

int main(int argc, char* argv[])
{
	int version = 4;
	parse_args(argc, argv, &version);
	if ( version !=4 && version != 6 )
	{
		usage(argv[0]);
		return 1;
	}
	initialize(version);

	if (4 == version )
	{
		test_mcast_join_leave_source_v4();
		test_mcast_block_unblock_source_v4();
	}
	else
	{
		test_mcast_join_leave_source_v6();
		test_mcast_block_unblock_source_v6();
	}

	report_and_exit();
	return 0;
}
