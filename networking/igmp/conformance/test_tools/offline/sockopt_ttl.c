/*
 * sockopt_ttl.c - IP_MULTICAST_TTL socket option test
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


void test_ttl()
{
	int value;
	size_t size = sizeof(value);

	value = 1;
	test_getsockopt("IP_MULTICAST_TTL default value",
				IP_MULTICAST_TTL, &value, size, 4);

	value = 0;
	test_sockopt_value("IP_MULTICAST_TTL set to zero",
				IP_MULTICAST_TTL, &value, size, 4);

	value = 64;
	test_sockopt_value("IP_MULTICAST_TTL set to 64",
				IP_MULTICAST_TTL, &value, size, 4);

	value = 255;
	test_sockopt_value("IP_MULTICAST_TTL set to 255",
				IP_MULTICAST_TTL, &value, size, 4);


	/*
	 * Special case:
	 * For some reason kernel accepts
	 * TTL = -1 and takes it as if it were 1
	 */
	value = -1;
	test_setsockopt("IP_MULTICAST_TTL set to -1",
				IP_MULTICAST_TTL, &value, size, 4);

	value = 1;
	test_getsockopt("IP_MULTICAST_TTL set to 1",
				IP_MULTICAST_TTL, &value, size, 4);


	/* Errors */
	value = 500;
	test_setsockopt_error("IP_MULTICAST_TTL set to 500",
				IP_MULTICAST_TTL, &value, size, EINVAL, 4);

	test_setsockopt_error("IP_MULTICAST_TTL bad optlen",
				IP_MULTICAST_TTL, &value, 0, EINVAL, 4);
}

void test_hops()
{
	int hops;
	size_t size = sizeof(hops);

	hops = 1;
	test_getsockopt("IPV6_MULTICAST_HOPS default value",
			IPV6_MULTICAST_HOPS, &hops, size, 6);

	hops = 0;
	test_sockopt_value("IPV6_MULTICAST_HOPS set to zero",
			IPV6_MULTICAST_HOPS, &hops, size, 6);

	hops = 64;
	test_sockopt_value("IPV6_MULTICAST_HOPS set to 64",
			IPV6_MULTICAST_HOPS, &hops, size, 6);

	hops = -1;
	test_setsockopt("IPV6_MULTICAST_HOPS set to -1",
			IPV6_MULTICAST_HOPS, &hops, size, 6);

	hops = 1;
	test_getsockopt("IPV6_MULTICAST_HOPS set to 1",
			IPV6_MULTICAST_HOPS, &hops, size, 6);
}

int main(int argc, char* argv[])
{
	int version = 4;
	parse_args(argc, argv, &version);
	if ( version !=4 && version != 6)
	{
		usage(argv[0]);
		return 1;
	}
	initialize(version);

	version == 4 ? test_ttl():test_hops();

	report_and_exit();
	return 0;
}
