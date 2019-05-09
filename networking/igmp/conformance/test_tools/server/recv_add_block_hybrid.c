/*
 * igmp_add_block_hybrid.c - Join multicast group and then add/drop block and
 *                       unblock specific sources
 * For igmp INCLUDE/EXCLUDE filter mode hybrid test.
 *
 * Copyright (C) 2012 Red Hat Inc.
 *
 * Author: Jia Xiao dong (xijia@redhat.com)
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

int main(int argc, char** argv)
{
	struct parameters params;
	parse_args(argc, argv, &params);

	int sockfd = init_in_socket(params.multiaddr, params.port);
	
	/*for reuse addr*/
	int one=1;
        if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one)) < 0) {
	          perror("setsockopt SO_REUSEADDR failed");
	          exit(1);
	}

	int num_report = 0;
	int num_add_src = 0;
	int num_drop_src = 0;
	int num_block_src = 0;
	int num_unblock_src = 0;
	
	/*For igmp INCLUDE filter mode*/ 

	struct ip_mreq mreq;
	mreq.imr_multiaddr  = params.multiaddr;
	mreq.imr_interface  = params.interface;

	struct ip_mreq_source mreqs, mreqs_add;
	mreqs.imr_multiaddr  = params.multiaddr;
	mreqs.imr_interface  = params.interface;
	mreqs.imr_sourceaddr = params.sourceaddr;

	mreqs_add.imr_multiaddr  = params.multiaddr;
	mreqs_add.imr_interface  = params.interface;
	mreqs_add.imr_sourceaddr.s_addr = params.sourceaddr.s_addr+ntohs(0x1);

	if (setsockopt(sockfd, IPPROTO_IP, IP_ADD_MEMBERSHIP,
				   &(mreq), sizeof(mreq)) < 0)
	{
		perror("setsockopt");
		return -1;
	}

	num_report = wait_for_data(sockfd, params.duration/6, 0);
        printf("report--packets_received=%d\n", num_report);

        if (setsockopt(sockfd, IPPROTO_IP, IP_ADD_SOURCE_MEMBERSHIP,
                                &(mreqs), sizeof(mreqs)) < 0)
        {
                   perror("setsockopt");
                   return -1;
        }
		wait_for_data(sockfd, params.duration/12, 0);

        num_add_src = wait_for_data(sockfd, params.duration/6, 0);
        printf("AddSrcMember--packets_received=%d\n", num_add_src);

        if (setsockopt(sockfd, IPPROTO_IP, IP_DROP_SOURCE_MEMBERSHIP,
                                &(mreqs), sizeof(mreqs)) < 0)
        {
                   perror("setsockopt");
                   return -1;
        }
		wait_for_data(sockfd, params.duration/12, 0);

        num_drop_src = wait_for_data(sockfd, params.duration/6, 0);
        printf("DropSrcMember--packets_received=%d\n", num_drop_src);

	/*another socket session for igmp EXCLUDE filter*/
	/*Set reuse port op*/
	int sockfd2 = socket(AF_INET, SOCK_DGRAM, 0);
	if (sockfd2 < 0)	{
		perror("socket()");
		exit(EXIT_FAILURE);
	}
	
	//for reuse addr
        if (setsockopt(sockfd2, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one)) < 0) {
           perror("setsockopt SO_REUSEADDR failed");
           exit(1);
        }
        //printf("Reusing the address...\r\n");

	struct sockaddr_in addr;
	addr.sin_family = AF_INET;
	addr.sin_port = htons(params.port);
	addr.sin_addr = params.multiaddr;
	memset(&(addr.sin_zero), 0, sizeof(addr.sin_zero));

	if (bind(sockfd2, (struct sockaddr*) &addr, sizeof(addr)) < 0) {
		perror("bind()");
		exit(EXIT_FAILURE);
	}
	//init socket2 over
	
        mreq.imr_multiaddr  = params.multiaddr;
        mreq.imr_interface  = params.interface;

        mreqs.imr_multiaddr  = params.multiaddr;
        mreqs.imr_interface  = params.interface;
        mreqs.imr_sourceaddr = params.sourceaddr;

        if (setsockopt(sockfd2, IPPROTO_IP, IP_ADD_MEMBERSHIP,
                                   &(mreq), sizeof(mreq)) < 0)
        {
                perror("setsockopt");
                return -1;
        }

	if (setsockopt(sockfd2, IPPROTO_IP, IP_BLOCK_SOURCE,
				   &(mreqs), sizeof(mreqs)) < 0)
	{
		perror("setsockopt");
		return -1;
	}
	wait_for_data(sockfd2, params.duration/12, 0);
	num_block_src = wait_for_data(sockfd2, params.duration/6, 0);
        printf("BlockSrcMember--packets_received=%d\n", num_block_src);
	
	if (setsockopt(sockfd2, IPPROTO_IP, IP_UNBLOCK_SOURCE,
				   &(mreqs), sizeof(mreqs)) < 0)
	{
		perror("setsockopt");
		return -1;
	}
	wait_for_data(sockfd2, params.duration/12, 0);

	num_unblock_src = wait_for_data(sockfd2, params.duration/6, 0);
        printf("UnblockSrcMember--packets_received=%d\n", num_unblock_src);

	return EXIT_SUCCESS;
}
