/*
 * Copyright (c) 2019 Red Hat, Inc. All rights reserved.
 *
 * This copyrighted material is made available to anyone wishing
 * to use, modify, copy, or redistribute it subject to the terms
 * and conditions of the GNU General Public License version 2.
 *
 * This program is distributed in the hope that it will be
 * useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <linux/udp.h>

#define SERVER	0
#define CLIENT	1
#define NOT_DEFINED	2
#define NR_IOVECS (10)
#define MSGSIZE (2048)
static int local_port = 0;
static char *local_host = NULL;
static char *remote_host = NULL;
static int remote_port = 0;

static int protocol = IPPROTO_UDP;
static int role = NOT_DEFINED;

struct packet {
    struct udphdr   udp;
    char	    payload[MSGSIZE];
};

void usage(char *argv0)
{
	fprintf(stderr, "\nusage:\n");
	fprintf(stderr, "\n%s -c 0:\n", argv0);
	fprintf(stderr, "\nOr:\n\n", argv0);
	fprintf(stderr, "  Server:\n");
	fprintf(stderr, "  %8s -c 1 -P local-port -l [ -r no_check6_rx] [ -R (use sock_raw)]", argv0);
	fprintf(stderr, "\n");
	fprintf(stderr, "  Client:\n");
	fprintf(stderr, "  %8s -c 1 -P local-port -h remote-addr -p remote-port -s [-t no_check6_tx ] [ -n so_no_check]\n", argv0);
	fprintf(stderr, "\n");
	fprintf(stderr, "\n");
	fflush(stderr);
	exit(1);
}

int set_get_opt_test()
{
	int sk1, sk2, val, val_get;
	int ret = 0;
	socklen_t len = sizeof(val_get);

	sk1 = socket(AF_INET, SOCK_DGRAM, 0);
	if (sk1 == -1) {
		perror("socket()");
		exit(1);
	}

	sk2 = socket(AF_INET6, SOCK_DGRAM, 0);
	if (sk2 == -1) {
		perror("socket()");
		exit(1);
	}

#ifdef SO_NO_CHECK
	printf("== set SO_NO_CHECK on UDPv4 socket ==\n");
	val = 1;
	ret = setsockopt(sk1, SOL_SOCKET, SO_NO_CHECK, (char *)&val, sizeof(val)); 
	if (ret != 0){
		perror("setsockopt(SO_NO_CHECK)");
		exit(1);
	}

	ret = getsockopt(sk1, SOL_SOCKET, SO_NO_CHECK, (char *)&val_get, &len);
	if (ret != 0) {
		perror("getsockopt(SO_NO_CHECK)");
		exit(1);
	}
	if (val != val_get) {
		fprintf(stderr, "getsockopt(SO_NO_CHECK) failed, "
				"got: %d, expect: %d\n", val_get, val);
		exit(1);
	}
#endif

#ifdef UDP_NO_CHECK6_RX
	printf("== set UDP_NO_CHECK6_RX on UDPv4 socket ==\n");
	val = 1;
	ret = setsockopt(sk1, IPPROTO_UDP, UDP_NO_CHECK6_RX, (char *)&val, sizeof(val));
	if (!ret) { // expect error, ignore error, just print out the msg
		fprintf(stderr, "Expect setsockopt(UDP_NO_CHECK6_RX)-v4 return -1\n");
		//exit(1);
	}
	printf("== set UDP_NO_CHECK6_RX on UDPv6 socket ==\n");
	val = 1;
	ret = setsockopt(sk2, IPPROTO_UDP, UDP_NO_CHECK6_RX, (char *)&val, sizeof(val));
	if (ret == -1) {
		fprintf(stderr, "setsockopt(UDP_NO_CHECK6_RX)-v6 failed\n");
		exit(1);
	}

	ret = getsockopt(sk2, IPPROTO_UDP, UDP_NO_CHECK6_RX, (char *)&val_get, &len);
	if (ret == -1) {
		fprintf(stderr, "getsockopt(UDP_NO_CHECK6_RX)-v6 failed\n");
		exit(1);
	}
	if (val != val_get) {
		fprintf(stderr, "getsockopt(UDP_NO_CHECK6_RX) failed, "
				"got: %d, expect: %d\n", val_get, val);
		exit(1);
	}
#endif
#ifdef UDP_NO_CHECK6_TX
	val = 1;
	ret = setsockopt(sk1, IPPROTO_UDP, UDP_NO_CHECK6_TX, (char *)&val, sizeof(val));
	if (!ret) { // expect error, ignore error, just print out the msg
		fprintf(stderr, "Expect setsockopt(UDP_NO_CHECK6_TX)-v4 return -1\n");
		//exit(1);
	}

	val = 1;
	ret = setsockopt(sk2, IPPROTO_UDP, UDP_NO_CHECK6_TX, (char *)&val, sizeof(val));
	if (ret == -1) {
		fprintf(stderr, "setsockopt(UDP_NO_CHECK6_TX)-v6 failed\n");
		exit(1);
	}

	ret = getsockopt(sk2, IPPROTO_UDP, UDP_NO_CHECK6_TX, (char *)&val_get, &len);
	if (ret == -1) {
		fprintf(stderr, "getsockopt(UDP_NO_CHECK6_TX)-v6 failed\n");
		exit(1);
	}
	if (val != val_get) {
		fprintf(stderr, "getsockopt(UDP_NO_CHECK6_TX) failed, got: %d, "
				"expect: %d\n", val_get, val);
		exit(1);
	}
#endif
	close(sk1);
	close(sk2);
	return ret;
}

int main(int argc, char **argv)
{
	struct addrinfo *rmt_res = NULL, *hst_res = NULL;
	struct sockaddr_storage local_addr, remote_addr;
	struct sockaddr_in6 *sin6;
	struct sockaddr_in *sin;
	struct packet udp_dgrm;
	char port_buffer[10];
	char buffer[sizeof(struct packet)];

	socklen_t addrlen, remote_addrlen;
	int c, test_case = 0;
	int sk, ret, family = AF_INET;
	int no_check6_rx = 0;
	int no_check6_tx = 0;
	int so_no_check = 0;
	int en_raw_sk = 0;

#if defined UDP_NO_CHECK6_TX && UDP_NO_CHECK6_RX
	while ((c = getopt(argc, argv, ":H:P:h:p:slRc:n:t:r:")) >= 0) {
		switch(c) {
		case 'H':
			local_host = optarg;
			break;
		case 'P':
			local_port = atoi(optarg);
			break;
		case 'h':
			remote_host = optarg;
			break;
		case 'p':
			remote_port = atoi(optarg);
			break;
		case 's':
			if (role != NOT_DEFINED) {
				printf("%s: only -s or -l\n", argv[0]);
				usage(argv[0]);
				exit(1);
			}
			role = CLIENT;
			break;
		case 'l':
			if (role != NOT_DEFINED) {
				printf("%s: only -s or -l\n", argv[0]);
				usage(argv[0]);
				exit(1);
			}
			role = SERVER;
			break;
		case 'c':
			test_case = atoi(optarg);
			break;
		case 'r':
			no_check6_rx = (atoi(optarg) == 0 ? 0:1);
			break;
		case 't':
			no_check6_tx = (atoi(optarg) == 0 ? 0:1);
			break;
		case 'n':
			so_no_check = (atoi(optarg) == 0 ? 0:1);
			break;
		case 'R':
			en_raw_sk = 1;
			break;
		default:
			usage(argv[0]);
			break;
		}
	}

	if (test_case == 0) {
		// basic test
		return set_get_opt_test();
	}

	if (NOT_DEFINED == role) {
		usage(argv[0]);
		exit(1);
	}

	if (SERVER == role && 0 == local_port && remote_port != 0) {
		fprintf(stderr, "%s: Server needs local port, "
		"not remote port\n", argv[0]);
		usage(argv[0]);
		exit(1);
	}

	if (CLIENT == role && (remote_host == NULL || remote_port == 0)) {
		fprintf(stderr, "%s: Client needs remote address, "
			"&& port\n", argv[0]);
		usage(argv[0]);
		exit(1);
	}

	if (!strcmp(local_host, "0")) {
		local_host = "0.0.0.0";
	}

	snprintf(port_buffer, 10, "%d", local_port);
	if (getaddrinfo(local_host, port_buffer, NULL, &hst_res) != 0) {
		perror("getaddrinfo(local host)");
		exit(1);
	}

	family = hst_res->ai_family;
	memcpy(&local_addr, hst_res->ai_addr, hst_res->ai_addrlen);
	addrlen = hst_res->ai_addrlen;
	freeaddrinfo(hst_res);

	if (role == CLIENT) {
		snprintf(port_buffer, 10, "%d", remote_port);
		if (getaddrinfo(remote_host, port_buffer, NULL, &rmt_res) != 0) {
			perror("getaddrinfo");
			exit(1);
		}

		assert(family == rmt_res->ai_family);

		memcpy(&remote_addr, rmt_res->ai_addr, rmt_res->ai_addrlen);
		remote_addrlen = rmt_res->ai_addrlen;
		freeaddrinfo(rmt_res);
	}
	if (family != AF_INET && family != AF_INET6) {
		fprintf(stderr, "Invalid address family:%d\n", family);
		exit(1);
	}
	if (en_raw_sk) {
		// When using sock_raw, it is not necessary to set so_no_check or
		// no_check6_tx on sender side. We can set udp checksum any value 
		// we want by sock_raw. so_no_check and no_check6_tx will leave udp
		// checksum to be 0.
		sk = socket(family, SOCK_RAW, IPPROTO_UDP);
	} else {
		sk = socket(family, SOCK_DGRAM, IPPROTO_UDP);
	}

	if (sk == -1) {
		perror("socket");
		exit(1);
	}

	if (bind(sk, (struct sockaddr *)&local_addr,
			addrlen) == -1) {
		perror("bind");
		exit(1);
	}

	if (family == AF_INET) {
		if (so_no_check) {
			// SO_NO_CHECK should work only on tx side
			ret = setsockopt(sk, SOL_SOCKET, SO_NO_CHECK, (char *)&so_no_check, sizeof(so_no_check)); 
			if (ret != 0){
				perror("setsockopt(SO_NO_CHECK)");
				exit(1);
			}
		}
	} else if (family == AF_INET6) {
		if (no_check6_rx) {
			ret = setsockopt(sk, IPPROTO_UDP, UDP_NO_CHECK6_RX, (char *)&no_check6_rx, sizeof(no_check6_rx));
			if (ret == -1) {
				perror("setsockopt(UDP_NO_CHECK6_RX)");
				exit(1);
			}
		}

		if (no_check6_tx) {
			ret = setsockopt(sk, IPPROTO_UDP, UDP_NO_CHECK6_TX, (char *)&no_check6_tx, sizeof(no_check6_tx));
			if (ret == -1) {
				perror("setsockopt(UDP_NO_CHECK6_TX)\n");
				exit(1);
			}
		}
	}

	if (role == CLIENT) {
		memset(&udp_dgrm, 0, sizeof(udp_dgrm));
		memset(&(udp_dgrm.payload), 'A', MSGSIZE);

		if (en_raw_sk) {
			udp_dgrm.udp.len = htons(sizeof(struct packet));
		} else {
			udp_dgrm.udp.len = htons(MSGSIZE);
		}

		udp_dgrm.udp.check = 0;
		udp_dgrm.udp.source = htons(local_port);
		udp_dgrm.udp.dest = htons(remote_port);

		if (en_raw_sk) {
			if (!so_no_check || !no_check6_tx) {
				if (family == AF_INET) {
					sin = (struct sockaddr_in *)&remote_addr;
					sin->sin_port = 0;
				} else if (family == AF_INET6) {
					sin6 = (struct sockaddr_in6 *)&remote_addr;
					sin6->sin6_port = 0;
				}
			}

			if (sendto(sk, &udp_dgrm, sizeof(struct packet), 0,
				(struct sockaddr *)&remote_addr, remote_addrlen) == -1) {
				perror("sendto");
				exit(1);
			}
		} else {
			if (sendto(sk, &udp_dgrm.payload, MSGSIZE, 0,
				(struct sockaddr *)&remote_addr, remote_addrlen) == -1) {
				perror("sendto");
				exit(1);
			}
		}
	} else {
		ret = recv(sk, buffer, sizeof(buffer), 0);
		if (ret == -1) {
			perror("recv");
			exit(1);
		}
		printf("received %d bytes from peer\n", ret);
		if (en_raw_sk) {
			// On the incoming side UDP seems to treat a checksum of 0 as valid.
			struct udphdr *uh = (struct udphdr *)buffer;
			if (uh->check == 0) {
				printf("udp checksum is 0\n");
			}
		}
	}
#endif
	return 0;
}
