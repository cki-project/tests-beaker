/*
 * recv_block_source.c - Join multicast group and then block and
 *                       unblock specific sources
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

#define RECEIVE
#include "multicast_utils.h"

int recv_block_group4(struct parameters *params)
{
	int sockfd = init_in_socket(params->multiaddr, params->port);
	struct group_source_req gsr_req;
	struct ip_mreq mreq;
	mreq.imr_multiaddr  = params->multiaddr;
	mreq.imr_interface  = params->interface;

	struct ip_mreq_source mreqs;
	mreqs.imr_multiaddr  = params->multiaddr;
	mreqs.imr_interface  = params->interface;
	mreqs.imr_sourceaddr = params->sourceaddr;

	int num_recv = 0;


	if (setsockopt(sockfd, IPPROTO_IP, IP_ADD_MEMBERSHIP,
				   &(mreq), sizeof(mreq)) < 0)
	{
		perror("setsockopt");
		return -1;
	}

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_before_block=%d\n", num_recv);

	if (setsockopt(sockfd, IPPROTO_IP, IP_BLOCK_SOURCE,
				   &(mreqs), sizeof(mreqs)) < 0)
	{
		perror("setsockopt");
		return -1;
	}
	wait_for_data(sockfd, params->duration/12, 0);

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_while_block=%d\n", num_recv);

	if (setsockopt(sockfd, IPPROTO_IP, IP_UNBLOCK_SOURCE,
				   &(mreqs), sizeof(mreqs)) < 0)
	{
		perror("setsockopt");
		return -1;
	}
	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_unblock=%d\n", num_recv);

	gsr_req.gsr_interface = params->if_index;
	gsr_req.gsr_group.ss_family = AF_INET;
	gsr_req.gsr_source.ss_family = AF_INET;
	((struct sockaddr_in *)&gsr_req.gsr_group)->sin_addr = params->multiaddr;
	((struct sockaddr_in *)&gsr_req.gsr_source)->sin_addr = params->sourceaddr;

	if (setsockopt(sockfd, IPPROTO_IP, MCAST_BLOCK_SOURCE,
				   &(gsr_req), sizeof(gsr_req)) < 0)
	{
		perror("setsockopt");
		return -1;
	}
	wait_for_data(sockfd, params->duration/12, 0);

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_while_mcast_block=%d\n", num_recv);

	if (setsockopt(sockfd, IPPROTO_IP, MCAST_UNBLOCK_SOURCE,
				   &(gsr_req), sizeof(gsr_req)) < 0)
	{
		perror("setsockopt");
		return -1;
	}
	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_mcast_unblock=%d\n", num_recv);

	if (setsockopt(sockfd, IPPROTO_IP, IP_DROP_MEMBERSHIP,
				   &(mreq), sizeof(mreq)) < 0)
	{
		perror("setsockopt");
		return -1;
	}

	return 0;
}

int recv_block_group6(struct parameters *params)
{
	int sockfd = init_in_socket6(params->multiaddr6, params->port);
	struct ipv6_mreq mreq6;
	struct group_source_req gsr_req6;
	int num_recv = 0;

	mreq6.ipv6mr_multiaddr = params->multiaddr6;
	mreq6.ipv6mr_interface = params->if_index;

	if((setsockopt(sockfd, IPPROTO_IPV6, IPV6_JOIN_GROUP,
					&mreq6, sizeof(mreq6))) < 0)
	{
		perror("setsockopt");
		return -1;
	}
	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_before_block=%d\n", num_recv);

	gsr_req6.gsr_interface = params->if_index;
	gsr_req6.gsr_group.ss_family = AF_INET6;
	gsr_req6.gsr_source.ss_family = AF_INET6;
	((struct sockaddr_in6 *)&gsr_req6.gsr_group)->sin6_addr = params->multiaddr6;
	((struct sockaddr_in6 *)&gsr_req6.gsr_source)->sin6_addr = params->sourceaddr6;

	if( (setsockopt(sockfd, IPPROTO_IPV6, MCAST_BLOCK_SOURCE,
					&gsr_req6, sizeof(gsr_req6))) < 0 )
	{
		perror("setsockopt");
		return -1;
	}
	wait_for_data(sockfd, params->duration/12, 0);
	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_while_mcast_block=%d\n", num_recv);
	if( (setsockopt(sockfd, IPPROTO_IPV6, MCAST_UNBLOCK_SOURCE,
					&gsr_req6, sizeof(gsr_req6))) < 0 )
	{
		perror("setsockopt");
		return -1;
	}

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_mcast_unblock=%d\n", num_recv);

	if((setsockopt(sockfd, IPPROTO_IPV6, IPV6_LEAVE_GROUP,
					&mreq6, sizeof(mreq6))) < 0)
	{
		perror("setsockopt");
		return -1;
	}

	return 0;
}

int main(int argc, char** argv)
{
	struct parameters params;
	parse_args(argc, argv, &params);
	int ret = 0;

	if( 4 == params.protocol )
	{
		ret = recv_block_group4(&params);
	}
	else
	{
		ret = recv_block_group6(&params);
	}

	return ret;
}
