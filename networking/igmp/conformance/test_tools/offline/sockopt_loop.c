/*
 * sockopt_loop.c - IP_MULTICAST_LOOP socket option test
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


void test_loop()
{
	int value;
	size_t size = sizeof(value);

	value = 1;
	test_getsockopt("IP_MULTICAST_LOOP default value",
				IP_MULTICAST_LOOP, &value, size, 4);

	value = 0;
	test_sockopt_value("IP_MULTICAST_LOOP set to zero",
				IP_MULTICAST_LOOP, &value, size, 4);

	/* Errors */
	test_setsockopt_error("IP_MULTICAST_LOOP bad optlen",
				IP_MULTICAST_LOOP, &value, 0, EINVAL, 4);
}

void test_loop_v6()
{
	int value;
	size_t size = sizeof(value);

	value = 1;
	test_getsockopt("IPV6_MULTICAST_LOOP default value",
			IPV6_MULTICAST_LOOP, &value, size, 6);

	value = 0;
	test_sockopt_value("IPV6_MULTICAST_LOOP set to zero",
			IPV6_MULTICAST_LOOP, &value, size, 6);

	/*Error*/
	test_setsockopt_error("IPV6_MULTICAST_LOOP bad optlen",
			IPV6_MULTICAST_LOOP, &value, 0, EINVAL, 6);
	value = 2;
	test_setsockopt_error("IPV6_MULTICAST_LOOP set to 2",
			IPV6_MULTICAST_LOOP, &value, size, EINVAL, 6);

	value = -1;
	test_setsockopt_error("IPV6_MULTICAST_LOOP set to -1",
			IPV6_MULTICAST_LOOP, &value, size, EINVAL, 6);
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

	version == 4?test_loop():test_loop_v6();

	report_and_exit();
	return 0;
}
