/* This program is used for sending mulitcast message. After start, it will run
 * as a daemon and keep sending message to the multicast group.
 */
#include <netdb.h>
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <net/if.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>

#define IFNAMESIZE 128
void usage(char *name)
{
	printf("%s: [-f family] [-g group] [-p port] [-m message] [ -i interface ] [-h]\n", name);
	printf("\t -f: family , 4 or 6, default is 4\n");
	printf("\t -g: group address\n");
	printf("\t -p: port\n");
	printf("\t -m: message\n");
	printf("\t -i: interface\n");
	printf("\t -h: help message\n");
	printf("\n");
	printf("\t e.g.: %s\n", name);
	printf("\t e.g.: %s -f 4 -g 224.1.1.1 -p 9999 -i em1\n", name);
	printf("\t e.g.: %s -f 6 -g ff02::123 -m ping -i em1\n", name);
	printf("\n");
	printf("\t Note: this program will be a daemon and send multicast message forever,\n");
	printf("\t       please remember kill it if you do not need any more\n");

	exit(0);

}

int set_socket_iface(int family, int sockfd, char *ifname)
{
	struct ifreq ifreq;
	struct in_addr inaddr;
	unsigned int interface;
	int fd;

	fd = socket(AF_INET, SOCK_DGRAM, 0);
	/* IP_MULTICAST_IF need struct in_addr
	 * IPV6_MULTICAST_IF only need interface index
	 */
	if (family == AF_INET) {
		if (ifname == NULL) {
			inaddr.s_addr = htonl(INADDR_ANY);
		} else {
			ifreq.ifr_addr.sa_family = AF_INET;
			strncpy(ifreq.ifr_name, ifname, IFNAMSIZ-1);

			if (ioctl(fd, SIOCGIFADDR, &ifreq) < 0) {
				perror("Do ioctl failed");
				return -1;
			}
			close(fd);

			memcpy(&inaddr,
					&((struct sockaddr_in *) &ifreq.ifr_addr)->sin_addr,
					sizeof(struct in_addr));
		}

		if (setsockopt(sockfd, IPPROTO_IP, IP_MULTICAST_IF,
					&inaddr , sizeof(struct in_addr)) == -1) {
			perror("setsockopt IP_MULTICAST_IF");
			return -1;
		}

	} else if (family == AF_INET6) {
		if (ifname == NULL)
			interface = 0;
		else
			interface = if_nametoindex(ifname);

		if (setsockopt(sockfd, IPPROTO_IPV6, IPV6_MULTICAST_IF,
					(const char*)&interface, sizeof(interface)) == -1) {
			perror("setsockopt IPV6_MULTICAST_IF");
			return -1;
		}
	} else {
		fprintf(stderr, "unknown ai_family\n");
	}

	return 0;
}
int main(int argc, char *argv[])
{
	struct addrinfo hints;
	struct addrinfo *result, *rp;
	char *group_addr = NULL;
	char *port = "9999";
	char *message = "ping";
	int family;
	int sockfd, err;
	int opt;
	size_t len;
	char *ifname = NULL;

	/* Get options */
	while ((opt = getopt(argc, argv, "f:g:m:p:i:h")) != -1) {
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
		case 'p':
			port = optarg;
			break;
		case 'm':
			message = optarg;
			break;
		case 'i':
			ifname = optarg;
			break;
		case 'h':
			usage(argv[0]);
			break;
		default:
			break;
		}
	}

	/* Obtain address(es) matching host/port */

	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_family = family;    /* Allow IPv4 or IPv6 */
	hints.ai_socktype = SOCK_DGRAM; /* Datagram socket */
	hints.ai_flags = 0;
	hints.ai_protocol = 0;          /* Any protocol */

	if (group_addr == NULL) {
		group_addr = family == AF_INET6 ? "ff02::123" : "239.0.0.123";
	}
	err = getaddrinfo(group_addr, port, &hints, &result);
	if (err != 0) {
		fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(err));
		exit(EXIT_FAILURE);
	}

	/* getaddrinfo() returns a list of address structures.
	   Try each address until we successfully connect(2).
	   If socket(2) (or connect(2)) fails, we (close the socket
	   and) try the next address. */

	for (rp = result; rp != NULL; rp = rp->ai_next) {
		sockfd = socket(rp->ai_family, rp->ai_socktype,
				rp->ai_protocol);
		if (sockfd == -1)
			continue;

		if (set_socket_iface(rp->ai_family, sockfd, ifname) == -1)
			continue;

		if (connect(sockfd, rp->ai_addr, rp->ai_addrlen) != -1)
			break;                  /* Success */

		close(sockfd);
	}

	if (rp == NULL) {               /* No address succeeded */
		fprintf(stderr, "Could not connect\n");
		exit(EXIT_FAILURE);
	}


	/* Send remaining command-line arguments as separate
	   datagrams, and read responses from server */

	daemon(0, 0);
	for (;;) {
		len = strlen(message) + 1;
		/* +1 for terminating null byte */

		if (sendto(sockfd, message, len, 0, rp->ai_addr, rp->ai_addrlen) != len) {
			fprintf(stderr, "partial/failed write\n");
			exit(EXIT_FAILURE);
		}

		sleep(1);
	}

	freeaddrinfo(result);           /* No longer needed */
	exit(EXIT_SUCCESS);
}

