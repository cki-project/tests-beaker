#include "proto.h"
#include "setopt.h"

/* For TCP test*/
extern int sockfd, domain, type, protocol;
extern int port_num;
extern int tcp_socket, udp_socket;
extern int debug;
extern char *hostname;
extern void *ptr;
extern struct server_client_num {
	unsigned int tcp_server;
	unsigned int tcp_client;
	unsigned int udp_server;
	unsigned int udp_client;
};

char *tcp_port[] = {
"9990", "9991", "9992", "9993", "9994", "9995", "9996", "9997", "9998", "9999"
};

void *__start_tcp_trans(void *arg)
{
	int connfd = *(int *)&arg;
	char recv_buf[MAX_LINE];
	ssize_t recv_len, send_len;
	int count = 0;

	/* init recv_buf */
	memset(recv_buf, 0, MAX_LINE);

	for ( ; ; ) {
		recv_len = recv(connfd, recv_buf, MAX_LINE, 0);
		if (recv_len == 0) {
			if (debug >= 2)
				printf("Strange, TCP Server recv nothing\n");
			continue;
		/* restart receive if Resource temporarily unavailable */
		} else if (recv_len < 0 && errno == EAGAIN) {
			if (debug >= 2)
				perror("TCP Server recv failed ");
			continue;
		} else if (recv_len < 0) {
			perror("TCP Server recv failed ");
			EXIT(EXIT_FAILURE);
		}

		recv_buf[recv_len] = '\0';

		count++;
		if ((count % 1000000) == 0) {
			printf("TCP Server recvive msg: \"%s\" %d times\n",
					recv_buf, count);
		}

		send_len = send(connfd, recv_buf, recv_len, 0);
		if (send_len < 0) {
			perror("TCP Server send error");
			EXIT(EXIT_FAILURE);
		}
	}
}

int start_tcp_server(int sockfd)
{
	int connfd;
	struct addrinfo hints;
	struct addrinfo *serv_addrs, *serv_addr;
	struct sockaddr_storage cli_addr;
	socklen_t cli_len = sizeof(struct sockaddr_storage);
	pthread_t thread;

	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_family = AF_UNSPEC;    /* Allow IPv4 or IPv6 */
	hints.ai_socktype = type; /* Datagram socket */
	hints.ai_flags = AI_PASSIVE;    /* For wildcard IP address */
	hints.ai_protocol = 0;          /* Any protocol */
	hints.ai_canonname = NULL;
	hints.ai_addr = NULL;
	hints.ai_next = NULL;

	if (fork() != 0)
		return 0;


	int err;
	tcp_socket = 1;
	err = set_ip_opt(&sockfd);
	if (err) {
		fprintf(stderr, "TCP Server set ip opt failed\n");
		((struct server_client_num *)ptr)->tcp_server--;
		EXIT(EXIT_FAILURE);
	}

	if ((err = (getaddrinfo(NULL, tcp_port[port_num], &hints, &serv_addrs))) != 0) {
		fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(err));
		((struct server_client_num *)ptr)->tcp_server--;
		EXIT(EXIT_FAILURE);
	}

	for (serv_addr = serv_addrs; serv_addr != NULL; serv_addr = serv_addr->ai_next) {
		if (bind(sockfd, serv_addr->ai_addr, serv_addr->ai_addrlen) == 0)
			break;                  /* Success */
	}

	if (serv_addr == NULL) {               /* No address succeeded */
		//fprintf(stderr, "No more TCP Server Could not bind\n");
		((struct server_client_num *)ptr)->tcp_server--;
		//EXIT(EXIT_FAILURE);
		exit(EXIT_FAILURE);
	}

	freeaddrinfo(serv_addrs);           /* No longer needed */
	printf("Got socket, Domain is %s, type is %s\n", domaintostring(domain), typetostring(type));


/*
	if (bind(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
		perror("TCP Server bind failed ");
		((struct server_client_num *)ptr)->tcp_server--;
		EXIT(EXIT_FAILURE);
	} */
	if (listen(sockfd, MAX_LISTEN) < 0) {
		perror("TCP Server listen failed ");
		((struct server_client_num *)ptr)->tcp_server--;
		EXIT(EXIT_FAILURE);
	}

	while (1) {
		connfd = accept(sockfd, (struct sockaddr *)&cli_addr, &cli_len);
		if (connfd < 0) {
			if (errno == EAGAIN) {
				if (debug >= 2)
					perror("TCP Server accept failed ");
				continue;
			} else {
				perror("TCP Server accept failed ");
				((struct server_client_num *)ptr)->tcp_server--;
				EXIT(EXIT_FAILURE);
			}
		}

		err = pthread_create(&thread, NULL, __start_tcp_trans, (void *)connfd);
		if (err < 0) {
			fprintf(stderr, "pthread_create failed: \"%s\"\n",
					strerror(err));
			((struct server_client_num *)ptr)->tcp_server--;
			EXIT(EXIT_FAILURE);
		}
	}

	return 1;
}

int start_tcp_client(int sockfd)
{
	struct addrinfo hints;
	struct addrinfo *result, *rp;
	ssize_t send_len, recv_len;
	char recv_buf[MAX_LINE];
	char send_buf[MAX_LINE];
	int err;

	/* init recv_buf */
	memset(recv_buf, 0, MAX_LINE);

	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_flags = 0;
	hints.ai_protocol = 0;

	if (fork() != 0)
		return 0;

	//printf("Got socket, Domain is %s, type is %s\n", domaintostring(domain), typetostring(type));
	/* Always remember freeaddrinfo after use getaddrinfo */
	err = getaddrinfo(hostname, tcp_port[port_num], &hints, &result);
	if (err != 0) {
		fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(err));
		((struct server_client_num *)ptr)->tcp_client--;
		EXIT(EXIT_FAILURE);
	}

	sprintf(send_buf, "I'm TCP Client %d, Server Domain is %s, type %s, port %s",
			((struct server_client_num *)ptr)->tcp_client,
			domaintostring(domain),
			typetostring(type),
			tcp_port[port_num]);

	tcp_socket = 1;
	/* Is it ok to set ip options before connect to an ip ? */
	err = set_ip_opt(&sockfd);
	if (err) {
		fprintf(stderr, "TCP Client set ip opt failed\n");
		((struct server_client_num *)ptr)->tcp_client--;
		EXIT(EXIT_FAILURE);
	}

	for (rp = result; rp != NULL; rp = rp->ai_next) {
		if (connect(sockfd, rp->ai_addr, rp->ai_addrlen) != -1)
			break;
	}

	if (rp == NULL) {               /* No address succeeded */
		//printf("TCP Client connect %s failed : %s", hostname, strerror(errno));
		//fprintf(stderr, "No more TCP Client Could bind\n");
		((struct server_client_num *)ptr)->tcp_client--;
		//EXIT(EXIT_FAILURE);
		exit(EXIT_FAILURE);
	}

	/* never use *result now, free it */
	freeaddrinfo(result);

	send_len = send(sockfd, send_buf, strlen(send_buf), 0);
	if (send_len < 0) {
		perror("TCP Client send error");
		((struct server_client_num *)ptr)->tcp_client--;
		EXIT(EXIT_FAILURE);
	}

	for ( ; ; ) {
		recv_len = recv(sockfd, recv_buf, MAX_LINE, 0);
		if (recv_len == 0) {
			if (debug >= 2)
				printf("Strange, TCP Client recv nothing\n");
			continue;
		} else if (recv_len < 0 && errno == EAGAIN) {
			if (debug >= 2)
				perror("TCP Client recv failed ");
			continue;
		} else if (recv_len < 0) {
			perror("TCP Client recv failed ");
			((struct server_client_num *)ptr)->tcp_client--;
			EXIT(EXIT_FAILURE);
		}

		recv_buf[recv_len] = '\0';

		send_len = send(sockfd, recv_buf, strlen(recv_buf), 0);
		if (send_len < 0) {
			perror("TCP Client send error");
			((struct server_client_num *)ptr)->tcp_client--;
			EXIT(EXIT_FAILURE);
		}
	}
	/* shouldn't out from for loop ... */
	return 1;
}
