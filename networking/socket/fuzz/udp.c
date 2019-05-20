#include "proto.h"
#include "setopt.h"

/* For UDP test*/
extern int sockfd, domain, type, protocol;
extern int port_num;
extern int udp_socket;
extern int debug;
extern char *hostname;
extern void *ptr;
extern struct server_client_num {
	int tcp_server;
	int tcp_client;
	int udp_server;
	int udp_client;
};

char *udp_port[] = {
"9980", "9981", "9982", "9983", "9984", "9985", "9986", "9987", "9988", "9989"
};

int start_udp_server(int sockfd)
{
	struct addrinfo hints;
	struct addrinfo *serv_addrs, *serv_addr;
	struct sockaddr_storage cli_addr;
	socklen_t cli_len = sizeof(struct sockaddr_storage);

	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_family = AF_UNSPEC;    /* Allow IPv4 or IPv6 */
	hints.ai_socktype = type; /* Datagram socket */
	hints.ai_flags = AI_PASSIVE;    /* For wildcard IP address */
	hints.ai_protocol = 0;          /* Any protocol */
	hints.ai_canonname = NULL;
	hints.ai_addr = NULL;
	hints.ai_next = NULL;

	/* father will return directly */
	if (fork() != 0)
		return 0;

	size_t recv_len, send_len;
	char recv_buf[MAX_LINE];

	/* init recv_buf */
	memset(recv_buf, 0, MAX_LINE);

	//printf("Got socket, Domain is %s, type is %s, port %s\n", domaintostring(domain), typetostring(type), udp_port[port_num]);

	udp_socket = 1;
	int err;
	err = set_ip_opt(&sockfd);
	if (err) {
		//fprintf(stderr, "UDP Server set ip opt failed\n");
		((struct server_client_num *)ptr)->udp_server--;
		//EXIT(EXIT_FAILURE);
		exit(EXIT_FAILURE);
	}

	if ((err = (getaddrinfo(NULL, udp_port[port_num], &hints, &serv_addrs))) != 0) {
		fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(err));
		((struct server_client_num *)ptr)->udp_server--;
		EXIT(EXIT_FAILURE);
	}

	for (serv_addr = serv_addrs; serv_addr != NULL; serv_addr = serv_addr->ai_next) {
		if (bind(sockfd, serv_addr->ai_addr, serv_addr->ai_addrlen) == 0)
			break;                  /* Success */
	}

	if (serv_addr == NULL) {               /* No address succeeded */
		//fprintf(stderr, "No more UDP Server Could bind\n");
		((struct server_client_num *)ptr)->udp_server--;
		//EXIT(EXIT_FAILURE);
		exit(EXIT_FAILURE);
	}

	freeaddrinfo(serv_addrs);           /* No longer needed */

	for ( ; ; ) {
		recv_len = recvfrom(sockfd, recv_buf, MAX_LINE, 0,
				(struct sockaddr *)&cli_addr, &cli_len);

		if (recv_len < 0) {
			perror("UDP Server recvfrom failed ");
			((struct server_client_num *)ptr)->udp_server--;
			EXIT(EXIT_FAILURE);
		}

		/*
		char addr[MAX_LINE];
		inet_ntop(domain , &cli_addr, addr, MAX_LINE);
		printf("DEBUG: Client Address is %s, len is %d\n", addr, cli_len);
		*/

		recv_buf[recv_len] = '\0';

		if (domain == AF_INET)
			send_len = sendto(sockfd, recv_buf, strlen(recv_buf), 0,
				(struct sockaddr *)&cli_addr,
				sizeof(struct sockaddr_in));
		else if (domain = AF_INET6)
			send_len = sendto(sockfd, recv_buf, strlen(recv_buf), 0,
				(struct sockaddr *)&cli_addr,
				sizeof(struct sockaddr_in6));
		if (send_len < 0) {
			perror("UDP Server sendto failed");
			((struct server_client_num *)ptr)->udp_server--;
			EXIT(EXIT_FAILURE);
		}
	}

	return 0;
}

int start_udp_client(int sockfd)
{
	struct addrinfo hints;
	struct addrinfo *result, *rp;

	size_t recv_len;
	char recv_buf[MAX_LINE];
	char send_buf[MAX_LINE];
	int count = 0;
	int err;

	/* init recv_buf */
	memset(recv_buf, 0, MAX_LINE);
	memset(&hints, 0, sizeof(struct addrinfo));

	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_DGRAM;
	hints.ai_flags = 0;
	hints.ai_protocol = 0;

	/* father will return directly */
	if (fork() != 0)
		return 0;

	//printf("Got socket, Domain is %s, type is %s, port %s\n", domaintostring(domain), typetostring(type), udp_port[port_num]);

	udp_socket = 1;
	err = set_ip_opt(&sockfd);
	if (err)
		EXIT(EXIT_FAILURE);

	sprintf(send_buf, "I'm UDP Client %d, Server Domain is %s, type %s, port %s",
			((struct server_client_num *)ptr)->udp_client,
			domaintostring(domain),
			typetostring(type),
			udp_port[port_num]);


	/* Always remember freeaddrinfo after use getaddrinfo */
	err = getaddrinfo(hostname, udp_port[port_num], &hints, &result);
	if (err != 0) {
		fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(err));
		EXIT(EXIT_FAILURE);
	}

	for (rp = result; rp != NULL; rp = rp->ai_next) {

		for ( ; ; ) {
			if (sendto(sockfd, send_buf, strlen(send_buf), 0,
						rp->ai_addr,
						rp->ai_addrlen) < 0) {
				perror("UDP Client sendto failed");
				//EXIT(EXIT_FAILURE);
				break;
			}

			while ((recv_len = recvfrom(sockfd, recv_buf, MAX_LINE, 0,
							rp->ai_addr,
							&(rp->ai_addrlen))) > 0) {
				recv_buf[recv_len] = '\0';

				count++;
				if ((count % 1000000) == 0 && debug >= 1)
					printf("UDP Client %d recv msg : \"%s\" %d times\n",
							((struct server_client_num *)ptr)->udp_client, recv_buf, count);

				// Bug 518034 kernel: udp socket NULL ptr dereference
				// if ( sendto(sockfd, recv_buf, recv_len, MSG_PROXY | MSG_MORE,
				if (sendto(sockfd, recv_buf, strlen(recv_buf), 0,
							rp->ai_addr,
							rp->ai_addrlen) < 0) {
					perror("UDP Client sendto failed");
					//((struct server_client_num *)ptr)->udp_client--;
					//EXIT(EXIT_FAILURE);
					break;
				}
			}

			if (recv_len < 0) {
				perror("UDP Client recvfrom failed ");
				//((struct server_client_num *)ptr)->udp_client--;
				//EXIT(EXIT_FAILURE);
				break;
			}
		}

	}

	/* never use *result now, free it */
	freeaddrinfo(result);

	printf("No more UDP Client could try\n");

	((struct server_client_num *)ptr)->udp_client--;
	EXIT(EXIT_FAILURE);
}
