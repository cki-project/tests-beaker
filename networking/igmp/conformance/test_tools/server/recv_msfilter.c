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

int recv_msfilter4(struct parameters *params)
{
	int sockfd = init_in_socket(params->multiaddr, params->port);
	int num_recv = 0;
	struct group_filter gr_filter;
	struct sockaddr_in *psin4;
	struct ip_msfilter filter;
	filter.imsf_multiaddr = params->multiaddr;
	filter.imsf_interface = params->interface;
	filter.imsf_fmode = MCAST_INCLUDE;
	filter.imsf_numsrc = 1;
	filter.imsf_slist[0] = params->sourceaddr;

	struct ip_mreq mreq;
	mreq.imr_multiaddr  = params->multiaddr;
	mreq.imr_interface  = params->interface;

	if (setsockopt(sockfd, IPPROTO_IP, IP_ADD_MEMBERSHIP,
				&(mreq), sizeof(mreq)) < 0)
	{
		perror("setsockopt");
		return -1;
	}

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_before_msfilter=%d\n", num_recv);

	if (setsockopt(sockfd, IPPROTO_IP, IP_MSFILTER,
				&(filter), sizeof(filter)) < 0)
	{
		perror("setsockopt");
		return -1;
	}

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_include=%d\n", num_recv);

	filter.imsf_fmode = MCAST_EXCLUDE;
	if (setsockopt(sockfd, IPPROTO_IP, IP_MSFILTER,
				&(filter), sizeof(filter)) < 0)
	{
		perror("setsockopt");
		return -1;
	}
	wait_for_data(sockfd, params->duration/12, 0);

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_exclude=%d\n", num_recv);

	gr_filter.gf_interface = params->if_index;
	gr_filter.gf_group.ss_family = AF_INET;
	((struct sockaddr_in *)&gr_filter.gf_group)->sin_addr = params->multiaddr;
	gr_filter.gf_numsrc = 1;
	gr_filter.gf_fmode = MCAST_INCLUDE;

	psin4 = (struct sockaddr_in *)&gr_filter.gf_slist[0];
	psin4->sin_family = AF_INET;
	psin4->sin_addr = params->sourceaddr;

	if (setsockopt(sockfd, IPPROTO_IP, MCAST_MSFILTER,
				&(gr_filter), sizeof(gr_filter)) < 0)
	{
		perror("setsockopt");
		return -1;
	}
	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_mcast_include=%d\n", num_recv);

	gr_filter.gf_fmode = MCAST_EXCLUDE;
	if (setsockopt(sockfd, IPPROTO_IP, MCAST_MSFILTER,
				&(gr_filter), sizeof(gr_filter)) < 0)
	{
		perror("setsockopt");
		return -1;
	}
	wait_for_data(sockfd, params->duration/12, 0);

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_mcast_exclude=%d\n", num_recv);

	return 0;
}

int recv_msfilter6(struct parameters *params)
{
	int sockfd = init_in_socket6(params->multiaddr6, params->port);
	int num_recv = 0;
	struct group_req group;
	struct group_filter gr_filter;
	struct sockaddr_in6 *psin6;

	group.gr_interface = params->if_index;
	group.gr_group.ss_family = AF_INET6;
	((struct sockaddr_in6 *)&group.gr_group)->sin6_addr = params->multiaddr6;

	gr_filter.gf_interface = params->if_index;
	gr_filter.gf_group.ss_family = AF_INET6;
	((struct sockaddr_in6 *)&gr_filter.gf_group)->sin6_addr = params->multiaddr6;
	gr_filter.gf_fmode = MCAST_INCLUDE;
	gr_filter.gf_numsrc = 1;
	psin6 = (struct sockaddr_in6 *)&gr_filter.gf_slist[0];
	psin6->sin6_family = AF_INET6;
	psin6->sin6_addr = params->sourceaddr6;

	if( (setsockopt(sockfd, IPPROTO_IPV6, MCAST_JOIN_GROUP,
					&group, sizeof(group))) < 0 )
	{
		perror("setsockopt");
		return -1;
	}

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_before_msfilter=%d\n", num_recv);
	if( (setsockopt(sockfd, IPPROTO_IPV6, MCAST_MSFILTER,
					&gr_filter, sizeof(gr_filter))) < 0 )
	{
		perror("setsockopt");
		return -1;
	}
	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_mcast_include=%d\n", num_recv);
	gr_filter.gf_fmode = MCAST_EXCLUDE;
	if( (setsockopt(sockfd, IPPROTO_IPV6, MCAST_MSFILTER,
					&gr_filter, sizeof(gr_filter))) < 0 )
	{
		perror("setsockopt");
		return -1;
	}
	wait_for_data(sockfd, params->duration/12, 0);

	num_recv = wait_for_data(sockfd, params->duration/6, 0);
	printf("packets_received_after_mcast_exclude=%d\n", num_recv);

	group.gr_interface = params->if_index;
	group.gr_group.ss_family = AF_INET6;
	((struct sockaddr_in6 *)&group.gr_group)->sin6_addr = params->multiaddr6;
	if( (setsockopt(sockfd, IPPROTO_IPV6, MCAST_LEAVE_GROUP,
					&group, sizeof(group))) < 0 )
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

	if ( 4 == params.protocol )
	{
		ret = recv_msfilter4(&params);
	}
	else
	{
		ret = recv_msfilter6(&params);
	}

	return ret;
}
