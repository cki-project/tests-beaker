/*
 * parameters_multicast.h - common code for parsing sender/receiver
 *                          parameters
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

#ifndef __PARAMETERS_MULTICAST_H__
#define __PARAMETERS_MULTICAST_H__

#include <stdio.h>
#include <string.h>
#include <errno.h>

#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>

#include <signal.h>
#include <time.h>

#include <getopt.h>
#include <stdlib.h>
#include <unistd.h>
#include <net/if.h>

extern int __verbosity;

/** Structure that carries test parameters */
struct parameters
{
	struct in_addr multiaddr;
	struct in_addr interface;

	struct in6_addr multiaddr6;
	struct in6_addr interface6;

	int duration; /* seconds */
	short port;
	int protocol;
	unsigned int if_index;

#ifdef RECEIVE
	struct in_addr sourceaddr;
	struct in6_addr sourceaddr6;
#endif

#ifdef SEND
	double delay;
	int ttl;
	int loop;
	int hops;
#endif
};

/** Initialize parameters struct with default values. */
void default_parameters(struct parameters* params)
{
	params->duration = 0;
	params->port = 0;
	memset(&params->multiaddr, 0, sizeof(struct in_addr));
	memset(&params->interface, 0, sizeof(struct in_addr));
	memset(&params->multiaddr6, 0, sizeof(struct in6_addr));
	memset(&params->interface6, 0, sizeof(struct in6_addr));
	params->protocol = 4;
	params->if_index = 0;
#ifdef RECEIVE
	memset(&params->sourceaddr, 0, sizeof(struct in_addr));
	memset(&params->sourceaddr6, 0, sizeof(struct in6_addr));
#endif
#ifdef SEND
	params->delay = 0.1;
	params->ttl = 1;
	params->loop = 1;
	params->hops = 1;
#endif
}

void usage(char *program_name, int retval)
{
	printf("usage: %s\n", program_name);
	printf("       -h | --help                        print this\n");
	printf("       -v | --verbose                     print additional information during the runtime\n");
	printf("       -i | --interface a.b.c.d/aa:bb::cc           local interface ipv4 or ipv6 to use for communication\n");
	printf("       -d | --duration x                  test duration\n");
	printf("       -c | --protocol x                  test protocol\n");
	printf("       -n | --if_index x                  interface name\n");

	printf("\n");

	printf("       -a | --multicast_address a.b.c.d/aa:bb::dd   multicast group address\n");
#ifdef RECEIVE
	printf("       -s | --source_address a.b.c.d/aa:bb::cc      multicast source (for SSM)\n");
#endif
	printf("       -p | --port x                      port number\n");
#ifdef SEND
	printf("\n");

	printf("       -t | --ttl x                       time to live for IP packet\n");
	printf("       -l | --loop x                      loopback multicast communication\n");
	printf("       -e | --hops x                      hops for ipv6\n");
	printf("       -f | --delay x                     delay between messages\n");
#endif

	exit(retval);
}

/** Generic function for parsing arguments */
void parse_args(int argc, char** argv, struct parameters* args)
{
#ifdef SEND
	#define __send_opts "f:t:l:e:"
#else
	#define __send_opts ""
#endif

#ifdef RECEIVE
	#define __recv_opts "s:"
	char *src_addr = "::";
#else
	#define __recv_opts ""
#endif

	char *if_addr = "::";
	char *group_addr = "::";
	static const char* opts = __send_opts __recv_opts "d:a:p:i:c:n:hv";


	static struct option long_options[] =
	{
#ifdef SEND
		{"delay",               required_argument, NULL, 'f'},
		{"ttl",	                required_argument, NULL, 't'},
		{"hops",	            required_argument, NULL, 'e'},
		{"loop",                required_argument, NULL, 'l'},
#endif
#ifdef RECEIVE
		{"source_address",      required_argument, NULL, 's'},
#endif
		{"duration",            required_argument, NULL, 'd'},
		{"multicast_address",   required_argument, NULL, 'a'},
		{"port",                required_argument, NULL, 'p'},
		{"protocol",            required_argument, NULL, 'c'},
		{"if_index",            required_argument, NULL, 'n'},
		{"interface",           required_argument, NULL, 'i'},
		{"help",                no_argument,       NULL, 'h'},
		{"verbose",             no_argument,       NULL, 'v'},
		{0,                    0,                 NULL,  0}
	};

	default_parameters(args);

	int opt;
	int option_index = 0;
	while((opt = getopt_long(argc, argv, opts, long_options,
						&option_index)) != -1) {
		switch (opt) {
#ifdef SEND
		case 'f':
			args->delay = atof(optarg);
			break;
		case 't':
			args->ttl = atoi(optarg);
			break;
		case 'e':
			args->hops = atoi(optarg);
			break;
		case 'l':
			args->loop = atoi(optarg);
			break;
#endif
#ifdef RECEIVE
		case 's':
			src_addr = optarg;
			break;
#endif
		case 'd':
			args->duration = atoi(optarg);
			break;
		case 'c':
			args->protocol = atoi(optarg);
			break;
		case 'n':
			args->if_index = if_nametoindex(optarg);
			break;
		case 'a':
			group_addr = optarg;
			break;
		case 'p':
			args->port = atoi(optarg);
			break;
		case 'i':
			if_addr = optarg;
			break;
		case 'h':
			usage(argv[0], EXIT_SUCCESS);
			break;
		case 'v':
			__verbosity = 1;
			break;
		default: /* '?' */
			fprintf(stderr, "%s: invalid options\n", argv[0]);
			usage(argv[0], EXIT_FAILURE);
		}
	}
	if ( 4 != args->protocol && 6 != args->protocol )
	{
		printf("protocol should be 4 or 6\n");
		usage(argv[0], EXIT_FAILURE);
	}
	if ( 4 == args->protocol )
	{
		if(0 == strcmp(group_addr, "::"))
		{
			group_addr = "0.0.0.0";
		}
		if( 0 == strcmp(if_addr, "::"))
		{
			if_addr = "0.0.0.0";
		}
		inet_pton(AF_INET, group_addr, &(args->multiaddr));
		inet_pton(AF_INET, if_addr, &(args->interface));
#ifdef RECEIVE
		if( 0 == strcmp(src_addr, "::"))
		{
			src_addr = "0.0.0.0";
		}
		inet_pton(AF_INET, src_addr, &(args->sourceaddr));
#endif
	}
	else
	{
		inet_pton(AF_INET6, group_addr, &(args->multiaddr6));
		inet_pton(AF_INET6, if_addr, &(args->interface6));
#ifdef RECEIVE
		inet_pton(AF_INET6, src_addr, &(args->sourceaddr6));
#endif
	}
}

#endif
