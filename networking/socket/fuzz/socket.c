#include "network.h"
#include "func.h"
#include "proto.h"
#include "setopt.h"

/* Some global prarmaters */
//int tcp_server, udp_server;
//int tcp_client, udp_client;
int sockfd, domain, type, protocol;
int port_num;
int debug;
char *hostname = "localhost";

void *ptr;
struct server_client_num {
	unsigned int tcp_server;
	unsigned int tcp_client;
	unsigned int udp_server;
	unsigned int udp_client;
	unsigned int sctp_server;
	unsigned int sctp_client;
};

void tcp_test(int sockfd)
{
	if (((struct server_client_num *)ptr)->tcp_server < MAX_CLIENTS)  {
		((struct server_client_num *)ptr)->tcp_server++;
		if (debug >= 1)
			printf("Start TCP Server %d\n", ((struct server_client_num *)ptr)->tcp_server);
		start_tcp_server(sockfd);
	} else if (((struct server_client_num *)ptr)->tcp_client < MAX_CLIENTS) {
		((struct server_client_num *)ptr)->tcp_client++;
		if (debug >= 1)
			printf("Start TCP Cleint %d\n", ((struct server_client_num *)ptr)->tcp_client);
		start_tcp_client(sockfd);
	}
}

void udp_test(int sockfd)
{
	if (((struct server_client_num *)ptr)->udp_server < MAX_CLIENTS)  {
		((struct server_client_num *)ptr)->udp_server++;
		if (debug >= 1)
			printf("Start UDP Server %d\n", ((struct server_client_num *)ptr)->udp_server);
		start_udp_server(sockfd);
	} else if (((struct server_client_num *)ptr)->udp_client < MAX_CLIENTS) {
		((struct server_client_num *)ptr)->udp_client++;
		if (debug >= 1)
			printf("Start UDP Cleint %d\n", ((struct server_client_num *)ptr)->udp_client);
		start_udp_client(sockfd);
	}
}

void sctp_test(int sockfd)
{
	if (((struct server_client_num *)ptr)->sctp_server < MAX_CLIENTS)  {
		((struct server_client_num *)ptr)->sctp_server++;
		if (debug >= 1)
			printf("Start UDP Server %d\n", ((struct server_client_num *)ptr)->sctp_server);
		start_sctp_server(sockfd);
	} else if (((struct server_client_num *)ptr)->sctp_client < MAX_CLIENTS) {
		((struct server_client_num *)ptr)->sctp_client++;
		if (debug >= 1)
			printf("Start UDP Cleint %d\n", ((struct server_client_num *)ptr)->sctp_client);
		start_sctp_client(sockfd);
	}
}

void do_nothing()
{

}

int main(int argc, char *argv[])
{
	int opt, fd;
	//int family;
	/* set sepc to 1 when want to run a specific protocol */
	int spec, igmp, tcp, udp, sctp;
	spec = igmp = tcp = udp = sctp = 0;

	//struct timeval t;
	/* get time seed */
	//gettimeofday(&t, NULL);
	//srand(t.tv_usec * t.tv_sec);

	while ((opt = getopt(argc, argv, "d:hH:f:itus")) != -1) {
		switch (opt) {
		case 'd':
			debug = atoi(optarg);
			break;
		case 'h':
			help(NULL);  EXIT(0);
			break;
		case 'H':
			hostname = optarg;
			break;
		//case 'f':
		//	family = atoi(optarg);
		//	break;
		case 'i':
			igmp = 1;
			spec = 1;
			break;
		case 't':
			tcp = 1;
			spec = 1;
			break;
		case 'u':
			udp = 1;
			spec = 1;
			break;
		case 's':
			sctp = 1;
			spec = 1;
			break;
		default:	/* ? */
			usage("unrecognized option");
			break;
		}  /* switch */
	}  /* while opt */

	/* Create and map the shared memory to our process */
	if ((fd = shm_open("SHARE_MEMORY", O_CREAT | O_TRUNC | O_RDWR, 0666)) < 0) {
		perror("shm_open error");
		EXIT(EXIT_FAILURE);
	}

	if (ftruncate(fd, sizeof(struct server_client_num)) < 0) {
		perror("ftruncate error");
		EXIT(EXIT_FAILURE);
	}

	if ((ptr = mmap(0, sizeof(struct server_client_num), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)) < 0) {
		perror("mmap error");
		EXIT(EXIT_FAILURE);
	}

	close(fd);

	while (1) {
		sockfd = -1;
		while (sockfd  < 0) {

			domain = rand(-5, 44);
			type = rand(-2, 12);

			if (sctp && likely())
				protocol = IPPROTO_SCTP;
			else if (likely())
				protocol = 0;
			else
				protocol = rand(-1, 256);

			sockfd = socket(domain, type, protocol);
			if (sockfd != -1) {
				/* OK , we got a valid sockfd */
				if (debug >= 3)
					printf("Got valid socket, Domain is %s"
							", type is %s\n",
							domaintostring(domain),
							typetostring(type));
			} else {
				if (debug >= 3)
					printf(".");
			}
		}

		// Rand port_num for tcp and udp
		port_num = rand(0, 9);

		switch (type) {
		case SOCK_STREAM:
			if (domain == AF_INET || domain == AF_INET6) {
				if (!spec || tcp)
					tcp_test(sockfd);
				/* one-to-one stye sctp */
				else if (!spec || sctp)
					sctp_test(sockfd);
			}
			break;
		case SOCK_DGRAM:
			if (domain == AF_INET || domain == AF_INET6) {
				if (!spec || udp)
					udp_test(sockfd);
			}
			break;
		case SOCK_SEQPACKET:
			if (domain == AF_INET || domain == AF_INET6) {
				/* one-to-many stye sctp */
				if (!spec || sctp)
					//sctp_test(sockfd);
					do_nothing();
			}
			close(sockfd);
			break;
		default:
			close(sockfd);
			break;
		}
	}
}
