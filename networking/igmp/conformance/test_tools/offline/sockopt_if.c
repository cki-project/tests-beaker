/*
 * sockopt_if.c - IP_MULTICAST_IF socket option test
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


void test_if()
{
	struct in_addr address;
	size_t size = sizeof(address);

	address.s_addr = INADDR_ANY;
	test_getsockopt("IP_MULTICAST_IF in_addr default value",
				IP_MULTICAST_IF, &address, size, 4);

	address.s_addr = inet_addr("127.0.0.1");
	test_sockopt_value("IP_MULTICAST_IF in_addr set to 127.0.0.1",
				IP_MULTICAST_IF, &address, size, 4);

	struct ip_mreqn mreqn;
	mreqn.imr_multiaddr.s_addr = inet_addr("239.1.2.3");
	mreqn.imr_address.s_addr = INADDR_ANY;
	mreqn.imr_ifindex = 0;

	address.s_addr = INADDR_ANY;
	test_setsockopt("IP_MULTICAST_IF ip_mreqn set to INADDR_ANY",
				IP_MULTICAST_IF, &mreqn, sizeof(mreqn), 4);
	test_getsockopt("IP_MULTICAST_IF ip_mreqn get to INADDR_ANY",
				IP_MULTICAST_IF, &address, size, 4);

	address.s_addr = inet_addr("127.0.0.1");
	mreqn.imr_address.s_addr = inet_addr("127.0.0.1");
	test_setsockopt("IP_MULTICAST_IF mreqn set to 127.0.0.1",
				IP_MULTICAST_IF, &mreqn, sizeof(mreqn), 4);
	test_getsockopt("IP_MULTICAST_IF mreqn get to 127.0.0.1",
				IP_MULTICAST_IF, &address, size, 4);

	/* Errors */
	test_setsockopt_error("IP_MULTICAST_IF bad optlen",
				IP_MULTICAST_IF, &address, 3, EINVAL, 4);

	address.s_addr = inet_addr("238.0.10.0");
	test_setsockopt_error("IP_MULTICAST_IF address 238.0.10.0",
					IP_MULTICAST_IF, &address,
					sizeof(address), EADDRNOTAVAIL, 4);
}

void test_if_v6()
{
	unsigned int addr6;
	size_t size = sizeof(addr6);

	addr6 = 0;
	test_getsockopt("IPV6_MULTICAST_IF default value",
			IPV6_MULTICAST_IF, &addr6, size, 6);

	test_sockopt_value("IPV6_MULTICAST_IF set to 0",
			IPV6_MULTICAST_IF, &addr6, size, 6);

	test_setsockopt_error("IPV6_MULTICAST_IF bad optlen",
			IPV6_MULTICAST_IF, &addr6, 3, EINVAL, 6);

	addr6 = 9999;
	test_setsockopt_error("IPV6_MULTICAST_IF index 50",
			IPV6_MULTICAST_IF, &addr6, size, ENODEV, 6);

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

	version == 4?test_if():test_if_v6();

	report_and_exit();
	return 0;
}
