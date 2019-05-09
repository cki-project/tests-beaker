/*
 * max_groups.c - discover the limit of maximum allowed groups
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

#define RECEIVE
#include "multicast_utils.h"

#define IGMP_MAX_GROUP_FILE "/proc/sys/net/ipv4/igmp_max_memberships"

int main(int argc, char** argv)
{
	struct parameters params;
	parse_args(argc, argv, &params);
	FILE *fp;
	char max_mem[16]="";
	int i = 0;

	if((fp = fopen(IGMP_MAX_GROUP_FILE, "rt")) == NULL )
	{
		printf("Open file failed\n");
	}

	for(i = 0; i < 16; i++)
	{
		max_mem[i] = fgetc(fp);
		if ( max_mem[i] == '\n')
		{
			max_mem[i] = '\0';
			break;
		}
	}
	if ( 15 == i )
	{
		max_mem[i] = '\0';
	}
	printf("max_mem setting=%d\n", atoi(max_mem));


	int sockfd = init_in_socket(params.multiaddr, params.port);

	struct ip_mreq mreq;
	struct in_addr multiaddr;
	int groups = 0;
	multiaddr.s_addr = 0xe1000001;
	mreq.imr_interface = params.interface;

	do {
		mreq.imr_multiaddr.s_addr = htonl(multiaddr.s_addr);
		if (setsockopt(sockfd, IPPROTO_IP, IP_ADD_MEMBERSHIP,
			   &(mreq), sizeof(mreq)) < 0) {
			if (errno == ENOBUFS)
				break;

			perror("setsockopt");
			return EXIT_FAILURE;
		}

		multiaddr.s_addr++;
		groups++;
	} while(1);


	printf("max_groups=%d\n", groups);
	if ( groups != atoi(max_mem))
	{
		printf("max_groups:%d not equal setting:%d\n", groups, atoi(max_mem));
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}
