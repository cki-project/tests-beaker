/*
 * sockopt_utils.h - common tools for writing sockopt conformance tests
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

#ifndef __SOCKOPT_UTILS_H__
#define __SOCKOPT_UTILS_H__

#define __SUCCESS_CODE 0
#define __FAILURE_CODE 1

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <getopt.h>

int __test_status = 1;
int __sockfd;

int usage(char *program_name)
{
	printf ("usage:%s -v 4/6\n", program_name);
	return 0;
}

int parse_args(int argc, char **argv, int *version)
{
	static struct option long_options[] =
	{
		{"version",               required_argument, NULL, 'v'},
		{0,                    0,                 NULL,  0}
	};
	static const char* opts="v:";
	int opt;
	int option_index=0;
	while((opt = getopt_long(argc, argv, opts, long_options,
					&option_index)) != -1)
	{
		switch(opt){
			case 'v':
				*version=atoi(optarg);
				break;
			default:
				printf("just need -v para,useless para:%c:%s",opt,optarg);
				usage(argv[0]);
		}
	}
	return 0;
}

void fail()
{
	__test_status = 0;
}

void report_and_exit()
{
	close(__sockfd);

	if (__test_status) {
		printf("status=pass\n");
		exit(__SUCCESS_CODE);
	} else {
		printf("status=fail\n");
		exit(__FAILURE_CODE);
	}
}

void error_exit(char* what)
{
	int code = errno;
	printf("error_message=%s %s\n", what, strerror(code));
	fail();
	report_and_exit();
}

void initialize(int version)
{
	__sockfd = socket((version == 4?AF_INET:AF_INET6), SOCK_DGRAM, 0);
	if (__sockfd < 0)
		error_exit("socket()");
}

void test_getsockopt(char* test_name, int optname, void *expected_optval,
						socklen_t expected_optlen, int version)
{
	int status;
	socklen_t size = expected_optlen;
	void* value = malloc(size);

	if (value == NULL)
		error_exit("malloc()");

	memset(value, 0, size);

	status = getsockopt(__sockfd, (version == 4?IPPROTO_IP:IPPROTO_IPV6), optname, value, &size);
	if (status < 0)
		error_exit("getsockopt()");

	if (expected_optlen != size) {
		printf("%s=fail: size of the returned struct differ\n", test_name);
		fail();
	} else {
		socklen_t i;
		for (i = 0; i < size; i++)
			if (((char*) value)[i] != ((char*) expected_optval)[i])
			{
				free(value);
				printf("%s=fail: received value of the option "
					   "differs from expected one\n", test_name);
				fail();
				return;
			}

		 printf("%s=pass\n", test_name);
	}

	free(value);
}


void test_setsockopt(char* test_name, int optname, void *optval,
						socklen_t optlen, int version)
{
	int status;

	status = setsockopt(__sockfd, (version == 4?IPPROTO_IP:IPPROTO_IPV6), optname, optval, optlen);
	if (status < 0)
		error_exit("setsockopt()");

	printf("%s=pass\n", test_name);
}

void test_sockopt_value(char* test_name, int optname,
						void *optval, socklen_t optlen, int version)
{
	test_setsockopt(test_name, optname, optval, optlen, version);
	test_getsockopt(test_name, optname, optval, optlen, version);
}

void test_setsockopt_error(char* test_name, int optname, void *optval,
				socklen_t optlen, int expected_errorcode, int version)
{
	int status;

	status = setsockopt(__sockfd, (version == 4?IPPROTO_IP:IPPROTO_IPV6), optname, optval, optlen);
	if (status < 0) {
		if (errno != expected_errorcode) {
			printf("%s=fail: error codes don't "
				   "match (expected %d, got %d)\n", test_name,
						expected_errorcode, errno);
			fail();
		} else {
			printf("%s=pass\n", test_name);
		}
	} else {
		printf("%s=fail: no error occured\n", test_name);
		fail();
	}
}

void test_getsockopt_error(char* test_name, int optname, void *optval,
				socklen_t optlen, int expected_errorcode, int version)
{
	int status;
	socklen_t size = optlen;

	status = getsockopt(__sockfd, (version == 4?IPPROTO_IP:IPPROTO_IPV6), optname, optval, &size);
	if (status < 0) {
		if (errno != expected_errorcode) {
			printf("%s=fail: error codes don't "
				   "match (expected %d, got %d)\n", test_name,
						expected_errorcode, errno);
			fail();
		} else {
			printf("%s=pass\n", test_name);
		}
	} else {
		printf("%s=fail: no error occured\n", test_name);
		fail();
	}
}

#endif
