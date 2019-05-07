/* This program is used for recving multicast message. It will receive $num
 * multicast messages and exit.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>

#define BUF_SIZE 8192

void usage(char *name)
{
	printf("%s: -i interface [-f family] [-g group] [-n max_num] [-h]\n", name);
	printf("\t -f: family , 4 or 6, default is 4\n");
	printf("\t -g: group address\n");
	printf("\t -i: interface\n");
	printf("\t -n: max recv msg number, default is 3\n");
	printf("\t -h: help message\n");
	printf("\n");
	printf("\t e.g.: %s -i em1\n", name);
	printf("\t e.g.: %s -f 4 -g 224.1.1.1 -i em1\n", name);
	printf("\t e.g.: %s -f 6 -g ff02::123 -i em1\n", name);

	exit(0);

}

int main(int argc, char *argv[])
{
	struct addrinfo hints;
	struct addrinfo *result, *rp;
	char buf[BUF_SIZE];
	int sockfd;
	char *port = "9999";
	int opt;
	unsigned int interface = 0;
	int nread, err;
	int n, num = 3;
	int family = AF_INET;
	char *group_addr = NULL;

	/* Get options */
	while ((opt = getopt(argc, argv, "f:g:i:n:p:h")) != -1) {
		switch(opt) {
		case 'f':
			if (atoi(optarg) == 4)
				family = AF_INET;
			else
				family = AF_INET6;
			break;
		case 'g':
			group_addr = optarg;
			break;
		case 'i':
			interface = if_nametoindex(optarg);
			break;
		case  'n':
			num = atoi(optarg);
			break;
		case  'p':
			port = optarg;
			break;
		case  'h':
			usage(argv[0]);
			break;
		default:
			break;
		}
	}

	if (interface == 0) {
		printf("Please give an interface\n");
		exit(EXIT_FAILURE);
	}

	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_family = family;        /* Allow IPv4 or IPv6 */
	hints.ai_socktype = SOCK_DGRAM;    /* UDP DGRAM socket */
	hints.ai_flags = AI_PASSIVE;        /* For wildcard IP address */
	hints.ai_protocol = 0;              /* Any protocol */
	hints.ai_canonname = NULL;
	hints.ai_addr = NULL;
	hints.ai_next = NULL;

	err = getaddrinfo(NULL, port, &hints, &result);
	if (err != 0) {
		fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(err));
		exit(EXIT_FAILURE);
	}

	/* getaddrinfo() returns a list of address structures.
	   Try each address until we successfully bind(2).
	   If socket(2) (or bind(2)) fails, we (close the socket
	   and) try the next address. */

	for (rp = result; rp != NULL; rp = rp->ai_next) {
		if ((sockfd = socket(rp->ai_family, rp->ai_socktype,
						rp->ai_protocol)) == -1 )
			continue;

		if (bind(sockfd, rp->ai_addr, rp->ai_addrlen) == 0)
			break;                  /* Success */

		close(sockfd);
	}

	if (rp == NULL) {               /* No address succeeded */
		fprintf(stderr, "Could not bind\n");
		exit(EXIT_FAILURE);
	}

	freeaddrinfo(result);           /* No longer needed */

	/* Init group addr */
	if (group_addr == NULL) {
		group_addr = family == AF_INET6 ? "ff02::123" : "239.0.0.123";
	}
	struct sockaddr_storage gr_group;
	memset(&gr_group, 0, sizeof(struct sockaddr_storage));
	gr_group.ss_family = family;
	err = inet_pton(family, group_addr, family == AF_INET6 ?
			(void *)(&((struct sockaddr_in6 *)&gr_group)->sin6_addr) :
			(void *)(&((struct sockaddr_in *)&gr_group)->sin_addr));
	if (err <= 0) {
		if (err == 0)
			fprintf(stderr, "inet_pton group_addr: Not in presentation format\n");
		else
			perror("inet_pton group_addr");
		exit(EXIT_FAILURE);
	}

	/* init group_req */
	struct group_req group;
	group.gr_interface = interface;
	group.gr_group = gr_group;

	if (setsockopt(sockfd, (family == AF_INET6) ? IPPROTO_IPV6 : IPPROTO_IP,
				MCAST_JOIN_GROUP, &group,
				sizeof(struct group_req)) == -1) {
		perror("setsockopt MACST_JOIN_GROUP");
		exit(EXIT_FAILURE);
	}

	/* Read message */
	struct sockaddr_storage peer_addr;
	socklen_t peer_addr_len;
	memset(&peer_addr, 0, sizeof(struct sockaddr_storage));
	for (n =0 ; n < num; n++) {
		peer_addr_len = sizeof(struct sockaddr_storage);
		nread = recvfrom(sockfd, buf, BUF_SIZE, 0,
				(struct sockaddr *) &peer_addr, &peer_addr_len);
		if (nread == -1) {
			n--;
			continue;               /* Ignore failed request */
		}

		printf("Received \'%s\' ", buf);
		if(inet_ntop(family, family == AF_INET6 ?
		    (void *)(&((struct sockaddr_in6 *)&peer_addr)->sin6_addr) :
		    (void *)(&((struct sockaddr_in *)&peer_addr)->sin_addr),
		    buf, INET6_ADDRSTRLEN) == NULL) {
			perror("inet_ntop peer_addr");
			exit(EXIT_FAILURE);
		} else {
			printf("from %s, group %s\n", buf, group_addr);
		}
	}

	close(sockfd);
	exit(EXIT_SUCCESS);
}
