/*
 * A little case to join multicast address on specific address and interface
 * Usage:
 * IPv4 : ./join_group -f 4 -g 224.1.1.1 -s 10.66.13.37 -i em1
 * IPv6 : ./join_group -f 6 -g ff02::123 -s 2012::100 -i em1
 * */
#include	<stdio.h>
#include	<stdlib.h>
#include	<unistd.h>
#include	<string.h>
#include	<errno.h>
#include	<net/if.h>
#include	<arpa/inet.h>
#include	<sys/socket.h>
#include	<sys/types.h>

void usage(char *name)
{
	printf("%s: [-h] [-f] [-g] [-s] [-i] [-l]\n", name);
	printf("\t -f: family , 4 or 6, default is 6\n");
	printf("\t -g: group address\n");
	printf("\t -s: source address\n");
	printf("\t -i: interface\n");
	printf("\t -b: block source group, default is join\n");
	printf("\t -n: group number, default is 1\n");
	printf("\t -t: sleep time after join group, default is 99999\n");
	printf("\t -d: enable debug\n");
	printf("\t -h: help message\n");
	printf("\n");
	printf("\t e.g.: %s -f 4 -g 224.1.1.1 -s 10.66.13.37 -i em1\n", name);
	printf("\t e.g.: %s -f 6 -g ff02::123 -s 2012::100 -i em1\n", name);

	exit(0);

}

int main(int argc, char *argv[])
{
	int sockfd;
	int err;
	int opt;
	int family = AF_INET6;
	int interface = 0;
	char *group_addr = "ff02::123";
	char *source_addr = "::";
	/* source address or interface, any one is ok */
	int soi = 0;
	int block = 0;
	int num = 0, group_num = 1;
	int debug = 0;
	int time = 99999;

	/* Get options */
	while ((opt = getopt(argc, argv, "f:g:s:i:l:n:t:bdh")) != -1) {
		switch(opt) {
		case 'f':
			if (atoi(optarg) == 4) {
				family = AF_INET;
				if (strcmp(source_addr, "::") == 0)
					source_addr = "0.0.0.0";
			}
			break;
		case 'g':
			group_addr = optarg;
			break;
		case 's':
			source_addr = optarg;
			soi = 1;
			break;
		case 'i':
			interface = if_nametoindex(optarg);
			soi = 1;
			break;
		case  'b':
			block = 1;
			break;
		case  'n':
			group_num = atoi(optarg);
			break;
		case  't':
			time = atoi(optarg);
			break;
		case  'd':
			debug = 1;
			break;
		case  'h':
			usage(argv[0]);
			break;
		default:
			break;
		}
	}

	if (soi == 0) {
		printf("Please give an interface or source address\n");
		exit(EXIT_FAILURE);
	}

	/* init group_addr and source_addr */
	struct sockaddr_storage gsr_group;
	struct sockaddr_storage gsr_source;
	memset(&gsr_group, 0, sizeof(struct sockaddr_storage));
	memset(&gsr_source, 0, sizeof(struct sockaddr_storage));

	gsr_group.ss_family = family;
	gsr_source.ss_family = family;
	err = inet_pton(family, group_addr, family == AF_INET6 ? (void *)(&((struct sockaddr_in6 *)&gsr_group)->sin6_addr) :
		(void *)(&((struct sockaddr_in *)&gsr_group)->sin_addr));
	if (err <= 0) {
		if (err == 0)
			fprintf(stderr, "inet_pton group_addr: Not in presentation format\n");
		else
			perror("inet_pton group_addr");
		exit(EXIT_FAILURE);
	}
	err = inet_pton(family, source_addr, family == AF_INET6 ? (void *)(&((struct sockaddr_in6 *)&gsr_source)->sin6_addr) :
		(void *)(&((struct sockaddr_in *)&gsr_source)->sin_addr));
	if (err <= 0) {
		if (err == 0)
			fprintf(stderr, "inet_pton group_addr: Not in presentation format\n");
		else
			perror("inet_pton group_addr");
		exit(EXIT_FAILURE);
	}


	if ((sockfd = socket(family, SOCK_DGRAM, 0)) == -1) {
		perror("socket");
		exit(EXIT_FAILURE);
	}

	for(num = 0; num < group_num; num ++) {
		/* init group_req */
		struct group_req group;
		group.gr_interface = interface;
		group.gr_group = gsr_group;

		/* init group_source_req */
		struct group_source_req src_group;
		src_group.gsr_interface = interface;
		src_group.gsr_group = gsr_group;
		src_group.gsr_source= gsr_source;

		if (strcmp(source_addr, "::") == 0 || strcmp(source_addr, "0.0.0.0") == 0 || 1 == block ) {
			if (setsockopt(sockfd, (family == AF_INET6) ? IPPROTO_IPV6 : IPPROTO_IP,
						MCAST_JOIN_GROUP, &group,
						sizeof(struct group_req)) == -1) {
				perror("setsockopt");
				exit(EXIT_FAILURE);
			}

			if ( 1 == block )
			{
				if (setsockopt(sockfd, family == AF_INET6? IPPROTO_IPV6 : IPPROTO_IP,
							MCAST_BLOCK_SOURCE, &src_group, sizeof(struct group_source_req)) == -1) {
					perror("setsockopt");
					exit(EXIT_FAILURE);
				}
			}
		} else {
			if (setsockopt(sockfd, family == AF_INET6? IPPROTO_IPV6 : IPPROTO_IP,
						MCAST_JOIN_SOURCE_GROUP, &src_group, sizeof(struct group_source_req)) == -1) {
				perror("setsockopt");
				exit(EXIT_FAILURE);
			}
		}

		/* make sure we set the value we want */
		if ( debug ) {
			char group_buff[INET6_ADDRSTRLEN], source_buff[INET6_ADDRSTRLEN];
			if(inet_ntop(family, family == AF_INET6 ? (void *)(&((struct sockaddr_in6 *)&gsr_group)->sin6_addr) :
				(void *)(&((struct sockaddr_in *)&gsr_group)->sin_addr),
						group_buff, INET6_ADDRSTRLEN) == NULL) {
				perror("inet_ntop group_addr");
				exit(EXIT_FAILURE);
			}
			if(inet_ntop(family, family == AF_INET6 ? (void *)(&((struct sockaddr_in6 *)&gsr_source)->sin6_addr) :
				(void *)&((struct sockaddr_in *)&gsr_source)->sin_addr,
						source_buff, INET6_ADDRSTRLEN) == NULL) {
				perror("inet_ntop source_addr");
				exit(EXIT_FAILURE);
			}
			printf("group address is %s, source address is %s\n", group_buff, source_buff);
		}

		/* address plus 1 after join group so we can start from the fisrt on */
		if (family == AF_INET)
			((struct sockaddr_in *)&gsr_group)->sin_addr.s_addr = htonl(ntohl(((struct sockaddr_in *)&gsr_group)->sin_addr.s_addr) + 1);
		else
			((uint32_t *)&((struct sockaddr_in6 *)&gsr_group)->sin6_addr)[3] = htonl(ntohl(((uint32_t *)&((struct sockaddr_in6 *)&gsr_group)->sin6_addr)[3]) + 1);

	}
	/* sleep 10s to make sure kernel send IGMP message */
	sleep(time);
	close(sockfd);
	return 0;
}
