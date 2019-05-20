/* This is a include file for C networking programs */

/* include functions */
/* printf fprintf */
#include	<stdio.h>

/* perror() also need stdio.h */
#include	<errno.h>

/* variable argument lists */
#include	<stdarg.h>

/* exit() */
#include	<stdlib.h>

/* bzero() strcmp() */
#include	<string.h>

/* write() read() */
#include	<unistd.h>

/* getaddrinfo() freeaddrinfo() */
#include	<netdb.h>

/* write() read() */
#include	<unistd.h>

/* for struct timeval and gettimeofday */
#include	<time.h>
#include	<sys/time.h>

/* socket() connect() */
#include	<sys/types.h>
#include	<sys/socket.h>

/* For AF_UNIX AF_LOCAL sockets */
#include <sys/un.h>

/* inet_pton() */
#include	<arpa/inet.h>

/* if_nametoindex() if_indextoname() */
#include	<net/if.h>

/* all IPPROTO_IPV6 Options */
#include	<netinet/in.h>
#include	<netinet/ip.h>
#include	<netinet/ip6.h>

/* for TCP/UDP/SCTP/ICMP/IGMP */
#include	<netinet/tcp.h>
#include	<netinet/udp.h>
#include	<netinet/sctp.h>
#include	<linux/icmp.h>
#include	<linux/mroute.h>

/* pthread_create */
#include	<pthread.h>

/* for semaphore */
#include	<semaphore.h>

/* for shared memory */
#include	<sys/mman.h>
#include	<sys/stat.h>
#include	<fcntl.h>

#define TRUE 1
#define true TRUE
#define FALSE 0
#define false FALSE
#define	MAXLINE	1024
#define	MAX_LEN	1024
#define	LISTENQ	10
#define	MAX_CLIENTS 10
#define	MADDR6	"ff01::123"
#define	SUCCEED 0

#define EXIT(x) do { fprintf(stdout, "Exit, file: '%s', line: %d\n", __FILE__, __LINE__);  exit(x);  } while (0)

#ifndef IP_MTU
#define IP_MTU 14
#endif

#ifndef IP_FREEBIND
#define IP_FREEBIND 15
#endif

#ifndef IP_PASSSEC
#define IP_PASSSEC 18
#endif

#ifndef IP_RECVORIGDSTADDR
#define IP_RECVORIGDSTADDR 20
#endif

#ifndef IP_MINTTL
#define IP_MINTTL 21
#endif

#define TCP_PORT 9998
/* This is used when you want to get a port pointer */
#define TCPPORT "9998"
#define UDP_PORT 9999
#define UDPPORT "9999"
#define MAX_LINE 1024
#define MAX_LISTEN 20
