/*
 * recv_membership.c - Join multicast group and leave it
 *                     in the middle of communication
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

int main(int argc, char** argv)
{
	struct parameters params;
	parse_args(argc, argv, &params);

	int sockfd = init_in_socket(params.multiaddr, params.port);

	struct ip_mreq mreq;
	mreq.imr_multiaddr = params.multiaddr;
	mreq.imr_interface = params.interface;

	int num_recv = 0;

	if (setsockopt(sockfd, IPPROTO_IP, IP_ADD_MEMBERSHIP,
			   &(mreq), sizeof(mreq)) < 0) {
		perror("setsockopt");
		return EXIT_FAILURE;
	}

	num_recv = wait_for_data(sockfd, params.duration/6, 0);
	printf("Report sent--packets_received=%d\n", num_recv);




//xijia
        struct ip_mreq_source mreqs;
        mreqs.imr_multiaddr  = params.multiaddr;
        mreqs.imr_interface  = params.interface;
	//if (params.sourceaddr.s_addr)
            mreqs.imr_sourceaddr = params.sourceaddr;
        //mreqs.imr_sourceaddr.s_addr = inet_addr("10.66.86.91");
        //else
	   // mreqs.imr_sourceaddr.s_addr = inet_addr("1.66.86.191");

        if (setsockopt(sockfd, IPPROTO_IP, IP_ADD_SOURCE_MEMBERSHIP,
                                   &(mreqs), sizeof(mreqs)) < 0)
        {
                perror("setsockopt");
                return -1;
        }
		wait_for_data(sockfd, params.duration/12, 0);

        num_recv = wait_for_data(sockfd, params.duration/6, 0);
        printf("AddSrcMember--packets_received=%d\n", num_recv);

	// drop src filter
        if (setsockopt(sockfd, IPPROTO_IP, IP_DROP_SOURCE_MEMBERSHIP,
                                   &(mreqs), sizeof(mreqs)) < 0)
        {
                perror("setsockopt");
                return -1;
        }
		wait_for_data(sockfd, params.duration/12, 0);
        num_recv = wait_for_data(sockfd, params.duration/6, 0);
        printf("DropSrcMember--packets_received=%d\n", num_recv);

//xijia

/*
	num_recv = wait_for_data(sockfd, params.duration/2, 0);
	printf("packets_received=%d\n", num_recv);

	if (setsockopt(sockfd, IPPROTO_IP, IP_DROP_MEMBERSHIP,
			   &(mreq), sizeof(mreq)) < 0) {
		perror("setsockopt");
		return EXIT_FAILURE;
	}


	num_recv = wait_for_data(sockfd, params.duration/2, 0);

	printf("packets_received_after_drop=%d\n", num_recv);
*/

	return EXIT_SUCCESS;
}
