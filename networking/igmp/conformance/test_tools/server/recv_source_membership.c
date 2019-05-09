/*
 * recv_drop_membership.c - Join multicast group only for a specific
 *                          source and then leave it in the middle of
 *                          ongoing communication
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

int recv_src_mem4(struct parameters *params)
{
	int sockfd = init_in_socket(params->multiaddr, params->port);
	int num_recv = 0;
	struct group_source_req gsr_req;
	struct ip_mreq_source mreq;
	mreq.imr_multiaddr  = params->multiaddr;
	mreq.imr_interface  = params->interface;
	mreq.imr_sourceaddr = params->sourceaddr;

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_before_join=%d\n", num_recv);

	if (setsockopt(sockfd, IPPROTO_IP, IP_ADD_SOURCE_MEMBERSHIP,
				   &(mreq), sizeof(mreq)) < 0)
	{
		perror("setsockopt");
		return -1;
	}

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_add=%d\n", num_recv);

	if (setsockopt(sockfd, IPPROTO_IP, IP_DROP_SOURCE_MEMBERSHIP,
				   &(mreq), sizeof(mreq)) < 0)
	{
		perror("setsockopt");
		return -1;
	}
	wait_for_data(sockfd, params->duration/12, 0);

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_drop=%d\n", num_recv);

	gsr_req.gsr_interface = params->if_index;
	gsr_req.gsr_group.ss_family = AF_INET;
	gsr_req.gsr_source.ss_family = AF_INET;
	((struct sockaddr_in *)&gsr_req.gsr_group)->sin_addr = params->multiaddr;
	((struct sockaddr_in *)&gsr_req.gsr_source)->sin_addr = params->sourceaddr;

	if( (setsockopt(sockfd, IPPROTO_IP, MCAST_JOIN_SOURCE_GROUP,
					&gsr_req, sizeof(gsr_req))) < 0 )
	{
		perror("setsockopt");
		return -1;
	}
	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_join=%d\n", num_recv);
	if( (setsockopt(sockfd, IPPROTO_IP, MCAST_LEAVE_SOURCE_GROUP,
					&gsr_req, sizeof(gsr_req))) < 0 )
	{
		perror("setsockopt");
		return -1;
	}
	wait_for_data(sockfd, params->duration/12, 0);
	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_leave=%d\n", num_recv);

	return 0;
}

int recv_src_mem6(struct parameters *params)
{
	int sockfd = init_in_socket6(params->multiaddr6, params->port);
	int num_recv = 0;
	struct group_source_req gsr_req6;

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_before_join=%d\n", num_recv);

	gsr_req6.gsr_interface = params->if_index;
	gsr_req6.gsr_group.ss_family = AF_INET6;
	gsr_req6.gsr_source.ss_family = AF_INET6;
	((struct sockaddr_in6 *)&gsr_req6.gsr_group)->sin6_addr = params->multiaddr6;
	((struct sockaddr_in6 *)&gsr_req6.gsr_source)->sin6_addr = params->sourceaddr6;

	if( (setsockopt(sockfd, IPPROTO_IPV6, MCAST_JOIN_SOURCE_GROUP,
					&gsr_req6, sizeof(gsr_req6))) < 0 )
	{
		perror("setsockopt");
		return -1;
	}
	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_join=%d\n", num_recv);

	if( (setsockopt(sockfd, IPPROTO_IPV6, MCAST_LEAVE_SOURCE_GROUP,
					&gsr_req6, sizeof(gsr_req6))) < 0 )
	{
		perror("setsockopt");
		return -1;
	}
	wait_for_data(sockfd, params->duration/12, 0);
	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_leave=%d\n", num_recv);

	return 0;
}

int main(int argc, char** argv)
{
	struct parameters params;
	parse_args(argc, argv, &params);
	int ret = 0;

	if ( 4 == params.protocol )
	{
		ret = recv_src_mem4(&params);
	}
	else
	{
		ret = recv_src_mem6(&params);
	}

	return ret;
}
