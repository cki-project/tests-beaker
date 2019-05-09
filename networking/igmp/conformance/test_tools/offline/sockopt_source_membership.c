/*
 * sockopt_source_membership.c - IP_ADD/DROP_SOURCE_MEMBERSHIP socket
 *				 option test
 *
 * Copyright (C) 2012 Red Hat Inc.
 *
 * Author: Radek Pazdera (rpazdera@redhat.com)
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


void test_add_source_membership()
{
	struct ip_mreq_source mreq;

	mreq.imr_multiaddr.s_addr = inet_addr("127.0.0.1");
	mreq.imr_interface.s_addr = inet_addr("127.0.0.1");
	mreq.imr_sourceaddr.s_addr = inet_addr("192.168.0.1");
	test_setsockopt_error("IP_ADD_SOURCE_MEMBERSHIP Bad multicast address",
			IP_ADD_SOURCE_MEMBERSHIP, &mreq, sizeof(mreq), EINVAL, 4);


	mreq.imr_multiaddr.s_addr = inet_addr("239.1.2.3");
	mreq.imr_interface.s_addr = inet_addr("255.255.255.255");
	mreq.imr_sourceaddr.s_addr = inet_addr("192.168.0.1");
	test_setsockopt_error("IP_ADD_SOURCE_MEMBERSHIP Bad interface",
			IP_ADD_SOURCE_MEMBERSHIP, &mreq, sizeof(mreq), ENODEV, 4);


	test_setsockopt_error("IP_ADD_SOURCE_MEMBERSHIP Bad optlen",
			IP_ADD_SOURCE_MEMBERSHIP, &mreq, 2, EINVAL, 4);
}

void test_drop_source_membership()
{
	struct ip_mreq_source mreq;

	mreq.imr_multiaddr.s_addr = inet_addr("127.0.0.1");
	mreq.imr_interface.s_addr = inet_addr("127.0.0.1");
	mreq.imr_sourceaddr.s_addr = inet_addr("192.168.0.1");
	test_setsockopt_error("IP_DROP_SOURCE_MEMBERSHIP Bad multicast address",
			IP_DROP_SOURCE_MEMBERSHIP, &mreq, sizeof(mreq), EINVAL, 4);

	mreq.imr_multiaddr.s_addr = inet_addr("239.1.2.3");
	mreq.imr_interface.s_addr = inet_addr("127.0.0.1");
	mreq.imr_sourceaddr.s_addr = inet_addr("192.168.0.1");
	test_setsockopt_error("IP_DROP_SOURCE_MEMBERSHIP Not a member",
			IP_DROP_SOURCE_MEMBERSHIP, &mreq, sizeof(mreq), EINVAL, 4);

	mreq.imr_multiaddr.s_addr = inet_addr("239.1.2.3");
	mreq.imr_interface.s_addr = inet_addr("255.255.255.255");
	mreq.imr_sourceaddr.s_addr = inet_addr("192.168.0.1");
	test_setsockopt_error("IP_DROP_SOURCE_MEMBERSHIP No device found",
			IP_DROP_SOURCE_MEMBERSHIP, &mreq, sizeof(mreq), ENODEV, 4);

	test_setsockopt_error("IP_DROP_SOURCE_MEMBERSHIP Bad optlen",
			IP_DROP_SOURCE_MEMBERSHIP, &mreq, 5, EINVAL, 4);
}

int main()
{
	initialize(4);

	test_add_source_membership();
	test_drop_source_membership();

	report_and_exit();
	return 0;
}
