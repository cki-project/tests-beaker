/*
 * recv_simple.c - simple receiver setup for multicast tests
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

int send_simple4(struct parameters *params)
{
	int sockfd = init_in_socket(params->multiaddr, params->port);
	int num_recv = 0;
	struct ip_mreq mreq;

	mreq.imr_multiaddr = params->multiaddr;
	mreq.imr_interface = params->interface;

	if (setsockopt(sockfd, IPPROTO_IP, IP_ADD_MEMBERSHIP,
				&mreq, sizeof(mreq)) < 0)
	{
		perror("setsockopt");
		return EXIT_FAILURE;
	}
	num_recv = wait_for_data(sockfd, params->duration, 0);

	return num_recv;

}

int send_simple6(struct parameters *params)
{
	int num_recv = 0;
	int sockfd = init_in_socket6(params->multiaddr6, params->port);
	struct ipv6_mreq mreq6;

	mreq6.ipv6mr_multiaddr = params->multiaddr6;
	mreq6.ipv6mr_interface = params->if_index;

	if(setsockopt(sockfd, IPPROTO_IPV6, IPV6_JOIN_GROUP,
				&mreq6, sizeof(mreq6)) < 0)
	{
		perror("setsockopt");
		return EXIT_FAILURE;
	}
	num_recv = wait_for_data(sockfd, params->duration, 0);

	return num_recv;

}

int main(int argc, char** argv)
{
	struct parameters params;
	parse_args(argc, argv, &params);
	int num_recv = 0;

	if ( 4 == params.protocol )
	{
		num_recv = send_simple4(&params);
	}
	else
	{
		num_recv = send_simple6(&params);
	}

	printf("packets_received=%d\n", num_recv);

	return EXIT_SUCCESS;
}
