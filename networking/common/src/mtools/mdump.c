/* mdump.c */
/*   Program to dump the contents of all datagrams arriving on a specified
 * multicast address and port.  The dump gives both the hex and ASCII
 * equivalents of the datagram payload.
 * See https://community.informatica.com/solutions/1470 for more info
 *
 * Author: J.P.Knight@lut.ac.uk (heavily modified by 29West/Informatica)
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted without restriction.
 *
 * Note: this program is based on the sd_listen program by Tom Pusateri
 * (pusateri@cs.duke.edu) and developed by Jon Knight (J.P.Knight@lut.ac.uk).
 *
  THE SOFTWARE IS PROVIDED "AS IS" AND INFORMATICA DISCLAIMS ALL WARRANTIES
  EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION, ANY IMPLIED WARRANTIES OF
  NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR
  PURPOSE.  INFORMATICA DOES NOT WARRANT THAT USE OF THE SOFTWARE WILL BE
  UNINTERRUPTED OR ERROR-FREE.  INFORMATICA SHALL NOT, UNDER ANY CIRCUMSTANCES,
  BE LIABLE TO LICENSEE FOR LOST PROFITS, CONSEQUENTIAL, INCIDENTAL, SPECIAL OR
  INDIRECT DAMAGES ARISING OUT OF OR RELATED TO THIS AGREEMENT OR THE
  TRANSACTIONS CONTEMPLATED HEREUNDER, EVEN IF INFORMATICA HAS BEEN APPRISED OF
  THE LIKELIHOOD OF SUCH DAMAGES.
 */

#include <stdio.h>
#include <stdlib.h>

/* Many of the following definitions are intended to make it easier to write
 * portable code between windows and unix. */

/* use our own form of getopt */
extern int toptind;
extern int toptreset;
extern char *toptarg;
int tgetopt(int nargc, char * const *nargv, const char *ostr);

#if defined(_MSC_VER)
// Windows-only includes
#include <windows.h>
#include <winsock2.h>
typedef unsigned long socklen_t;
#define SLEEP_SEC(s) Sleep((s) * 1000)
#define SLEEP_MSEC(s) Sleep(s)
#define ERRNO GetLastError()
#define CLOSESOCKET closesocket
#define TLONGLONG signed __int64

#else
// Unix-only includes
#define HAVE_PTHREAD_H
#include <signal.h>
#include <unistd.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <errno.h>
#include <pthread.h>
#include <net/if.h>
#include <netdb.h>
#define SLEEP_SEC(s) sleep(s)
#define SLEEP_MSEC(s) usleep((s) * 1000)
#define CLOSESOCKET close
#define ERRNO errno
#define SOCKET int
#define INVALID_SOCKET -1
#define SOCKET_ERROR -1
#define TLONGLONG signed long long
#endif

#if defined(_WIN32)
#   include <ws2tcpip.h>
#   include <sys\types.h>
#   include <sys\timeb.h>
#   define perror(x) fprintf(stderr,"%s: %d\n",x,GetLastError())
#else
#   include <sys/time.h>
#endif

#include <string.h>
#include <time.h>

#define MAXPDU 65536
#ifndef SO_MAX_PACING_RATE
#define SO_MAX_PACING_RATE 47
#endif


/* program name (from argv[0] */
char *prog_name = "xxx";

/* program options */
int o_family;
int o_quiet_lvl;
int o_rcvbuf_size;
int o_pause_ms;
int o_pause_num;
int o_verify;
int o_stop;
int o_tcp;
FILE *o_output;
char o_output_equiv_opt[1024];

/* program positional parameters */
//unsigned long int groupaddr;
unsigned char groupaddr[sizeof(struct in6_addr)];
unsigned short int groupport;
char *bind_if;


char usage_str[] = "[-h] [-f] [-o ofile] [-p pause_ms[/loops]] [-Q Quiet_lvl] [-q] [-r pacing_rate] [-R rcvbuf_size] [-s] [-t] [-u] [-v] group port [interface]";

void usage(char *msg)
{
	if (msg != NULL)
		fprintf(stderr, "\n%s\n\n", msg);
	fprintf(stderr, "Usage: %s %s\n\n"
			"(use -h for detailed help)\n",
			prog_name, usage_str);
}  /* usage */


void help(char *msg)
{
	if (msg != NULL)
		fprintf(stderr, "\n%s\n\n", msg);
	fprintf(stderr, "Usage: %s %s\n", prog_name, usage_str);
	fprintf(stderr, "Where:\n"
			"  -h : help\n"
			"  -f : Choose address family, -f 4 or -f 6, IPv4 by default\n"
			"  -o ofile : print results to file (in addition to stdout)\n"
			"  -p pause_ms[/num] : milliseconds to pause after each receive [0: no pause]\n"
			"                      and number of loops to apply the pause [0: all loops]\n"
			"  -Q Quiet_lvl : set quiet level [0] :\n"
			"                 0 - print full datagram contents\n"
			"                 1 - print datagram summaries\n"
			"                 2 - no print per datagram (same as '-q')\n"
			"  -q : no print per datagram (same as '-Q 2')\n"
			"  -r : tcp pacing rate, value is in bytes per second [0]\n"
			"  -R : rcvbuf_size : size (bytes) of UDP receive buffer (SO_RCVBUF) [4194304]\n"
			"                   (use 0 for system default buff size)\n"
			"  -s : stop execution when status msg received\n"
			"  -t : Use TCP (use '0.0.0.0' for group)\n"
			"  -v : verify the sequence numbers\n"
			"\n"
			"  group : multicast address to receive (required, use '0.0.0.0' for unicast)\n"
			"  port : destination port (required)\n"
			"  interface : optional IP addr of local interface (for multi-homed hosts) [INADDR_ANY]\n"
	);
}  /* help */


/* faster routine to replace inet_ntoa() (from tcpdump) */
char *intoa(unsigned int addr)
{
	register char *cp;
	register unsigned int byte;
	register int n;
	static char buf[sizeof(".xxx.xxx.xxx.xxx")];

	addr = ntohl(addr);
	// NTOHL(addr);
	cp = &buf[sizeof buf];
	*--cp = '\0';

	n = 4;
	do {
		byte = addr & 0xff;
		*--cp = byte % 10 + '0';
		byte /= 10;
		if (byte > 0) {
			*--cp = byte % 10 + '0';
			byte /= 10;
			if (byte > 0)
				*--cp = byte + '0';
		}
		*--cp = '.';
		addr >>= 8;
	} while (--n > 0);

	return cp + 1;
}  /* intoa */


char *format_time(const struct timeval *tv)
{
	static char buff[sizeof(".xx:xx:xx.xxxxxx")];
	int min;

	unsigned int h = localtime((time_t *)&tv->tv_sec)->tm_hour;
	min = (int)(tv->tv_sec % 86400);
	sprintf(buff,"%02d:%02d:%02d.%06d",h,((int)min%3600)/60,(int)min%60,(int)tv->tv_usec);
	return buff;
}  /* format_time */


void dump(FILE *ofile, const char *buffer, int size)
{
	int i,j;
	unsigned char c;
	char textver[20];

	for (i=0;i<(size >> 4);i++) {
		for (j=0;j<16;j++) {
			c = buffer[(i << 4)+j];
			fprintf(ofile, "%02x ",c);
			textver[j] = ((c<0x20)||(c>0x7e))?'.':c;
		}
		textver[j] = 0;
		fprintf(ofile, "\t%s\n",textver);
	}
	for (i=0;i<size%16;i++) {
		c = buffer[size-size%16+i];
		fprintf(ofile, "%02x ",c);
		textver[i] = ((c<0x20)||(c>0x7e))?'.':c;
	}
	for (i=size%16;i<16;i++) {
		fprintf(ofile, "   ");
		textver[i] = ' ';
	}
	textver[i] = 0;
	fprintf(ofile, "\t%s\n",textver); fflush(ofile);
}  /* dump */


void currenttv(struct timeval *tv)
{
#if defined(_WIN32)
	struct _timeb tb;
	_ftime(&tb);
	tv->tv_sec = tb.time;
	tv->tv_usec = 1000*tb.millitm;
#else
	gettimeofday(tv,NULL);
#endif /* _WIN32 */
}  /* currenttv */


int main(int argc, char **argv)
{
	int opt;
	int num;
	int num_parms;
	char equiv_cmd[1024];
	char *buff;
	SOCKET listensock;
	SOCKET sock;
	socklen_t fromlen = sizeof(struct sockaddr);
	int default_rcvbuf_sz, cur_size, sz;
	int num_rcvd;
//	int num_sent;
	long msg_rcvd;
	long msg_sent;
	struct sockaddr_storage name;
	struct sockaddr_in *name4;
	struct sockaddr_in6 *name6;
	struct sockaddr src;
	char hbuf[NI_MAXHOST], sbuf[NI_MAXSERV];
	char *gaddr;
//	struct ip_mreq imr;
	struct group_req req;
	struct timeval tv;
	float perc_loss;
	int cur_seq;
	char *pause_slash;
	unsigned o_rate = 0;
	socklen_t rate_len;

	prog_name = argv[0];

	buff = malloc(65536 + 1);  /* one extra for trailing null (if needed) */
	if (buff == NULL) { fprintf(stderr, "malloc failed\n"); exit(1); }

#if defined(_WIN32)
	{
		WSADATA wsadata;  int wsstatus;
		if ((wsstatus = WSAStartup(MAKEWORD(2,2), &wsadata)) != 0) {
			fprintf(stderr,"%s: WSA startup error - %d\n", argv[0], wsstatus);
			exit(1);
		}
	}
#else
	signal(SIGPIPE, SIG_IGN);
#endif /* _WIN32 */

	/* get system default value for socket buffer size */
	if((sock = socket(PF_INET,SOCK_DGRAM,0)) == INVALID_SOCKET) {
		fprintf(stderr, "ERROR: ");  perror("socket");
		exit(1);
	}
	sz = sizeof(default_rcvbuf_sz);
	if (getsockopt(sock,SOL_SOCKET,SO_RCVBUF,(char *)&default_rcvbuf_sz,
			(socklen_t *)&sz) == SOCKET_ERROR) {
		fprintf(stderr, "ERROR: ");  perror("getsockopt - SO_RCVBUF");
		exit(1);
	}
	CLOSESOCKET(sock);

	/* default values for options */
	o_family = AF_INET;
	o_quiet_lvl = 0;
	o_rcvbuf_size = 0x400000;  /* 4MB */
	o_pause_ms = 0;
	o_pause_num = 0;
	o_verify = 0;
	o_stop = 0;
	o_tcp = 0;
	o_output = NULL;
	o_output_equiv_opt[0] = '\0';

	/* default values for optional positional params */
	bind_if = NULL;

	while ((opt = tgetopt(argc, argv, "hf:qQ:p:r:R:o:vst")) != EOF) {
		switch (opt) {
		  case 'h':
			help(NULL);  exit(0);
			break;
		  case 'f':
			if (atoi(toptarg) == 6)
				o_family = AF_INET6;
			else if (atoi(toptarg) != 4) {
				usage("Error : family must be 4 or 6\n");
				exit(1);
			}
			break;
		  case 'q':
			o_quiet_lvl = 2;
			break;
		  case 'Q':
			o_quiet_lvl = atoi(toptarg);
			break;
		  case 'p':
			pause_slash = strchr(toptarg, '/');
			if (pause_slash)
				o_pause_num = atoi(pause_slash+1);
			o_pause_ms = atoi(toptarg);
			break;
		  case 'r':
			o_rate = atoi(toptarg);
			break;
		  case 'R':
			o_rcvbuf_size = atoi(toptarg);
			if (o_rcvbuf_size == 0)
				o_rcvbuf_size = default_rcvbuf_sz;
			break;
		  case 'v':
			o_verify = 1;
			break;
		  case 's':
			o_stop = 1;
			break;
		  case 't':
			o_tcp = 1;
			break;
		  case 'o':
			if (strlen(toptarg) > 1000) {
				fprintf(stderr, "ERROR: file name too long (%s)\n", toptarg);
				exit(1);
			}
			o_output = fopen(toptarg, "w");
			if (o_output == NULL) {
				fprintf(stderr, "ERROR: ");  perror("fopen");
				exit(1);
			}
			sprintf(o_output_equiv_opt, "-o %s ", toptarg);
			break;
		  default:
			usage("unrecognized option");
			exit(1);
			break;
		}  /* switch */
	}  /* while opt */

	num_parms = argc - toptind;

	/* handle positional parameters */
	if (num_parms == 2) {
		gaddr = malloc(sizeof(argv[toptind]));
		gaddr = argv[toptind];
		if ((num = inet_pton(o_family, argv[toptind], groupaddr)) == 0){
			fprintf(stderr, "inet_pton Not valid address.\n");
			exit(1);
		} else if ( num < 0){
			perror("inet_pton failed ");
			exit(1);
		}
		groupport = (unsigned short)atoi(argv[toptind+1]);
		sprintf(equiv_cmd, "mdump %s-p%d -Q%d -R%d %s%s%s%s %s",
				o_output_equiv_opt, o_pause_ms, o_quiet_lvl, o_rcvbuf_size,
				o_stop ? "-s " : "",
				o_tcp ? "-t " : "",
				o_verify ? "-v " : "",
				argv[toptind],argv[toptind+1]);
		printf("Equiv cmd line: %s\n", equiv_cmd); fflush(stdout);
		if (o_output) { fprintf(o_output, "Equiv cmd line: %s\n", equiv_cmd); fflush(o_output); }
	} else if (num_parms == 3) {
		gaddr = malloc(sizeof(argv[toptind]));
		gaddr = argv[toptind];
		if ((num = inet_pton(o_family, argv[toptind], groupaddr)) == 0){
			fprintf(stderr, "inet_pton Not valid address.\n");
			exit(1);
		} else if ( num < 0){
			perror("inet_pton failed ");
			exit(1);
		}
		groupport = (unsigned short)atoi(argv[toptind+1]);
		bind_if  = argv[toptind+2];
		sprintf(equiv_cmd, "mdump %s-p%d -Q%d -R%d %s%s%s%s %s %s",
				o_output_equiv_opt, o_pause_ms, o_quiet_lvl, o_rcvbuf_size,
				o_stop ? "-s " : "",
				o_tcp ? "-t " : "",
				o_verify ? "-v " : "",
				argv[toptind],argv[toptind+1],argv[toptind+2]);
		printf("Equiv cmd line: %s\n", equiv_cmd); fflush(stdout);
		if (o_output) { fprintf(o_output, "Equiv cmd line: %s\n", equiv_cmd); fflush(o_output); }
	} else {
		usage("need 2-3 positional parameters");
		exit(1);
	}
	
	if (o_tcp && strcmp(gaddr,"0.0.0.0") != 0 && strcmp(gaddr, "::") != 0) {
		usage("-t incompatible with non-zero multicast group");
	}

	if (o_tcp) {
		if (o_family == AF_INET) {
			if((listensock = socket(PF_INET,SOCK_STREAM,0)) == INVALID_SOCKET) {
				fprintf(stderr, "ERROR: ");  perror("socket");
				exit(1);
			}
		} else {
			if((listensock = socket(PF_INET6,SOCK_STREAM,0)) == INVALID_SOCKET) {
				fprintf(stderr, "ERROR: ");  perror("socket");
				exit(1);
			}	
		}
		memset((char *)&name,0,sizeof(name));
		if (o_family == AF_INET) {
			name4 = (struct sockaddr_in *)&name;
			name4->sin_family = AF_INET;
			name4->sin_addr = *(struct in_addr *)groupaddr;
			name4->sin_port = htons(groupport);
		} else {
			name6 = (struct sockaddr_in6 *)&name;
			name6->sin6_family = AF_INET6;
			name6->sin6_addr = *(struct in6_addr *)groupaddr;
			name6->sin6_port = htons(groupport);
		}
		if (bind(listensock,(struct sockaddr *)&name,sizeof(name)) == SOCKET_ERROR) {
			fprintf(stderr, "ERROR: ");  perror("bind");
			exit(1);
		}
		if(listen(listensock, 1) == SOCKET_ERROR) {
			fprintf(stderr, "ERROR: ");  perror("listen");
			exit(1);
		}

		if((sock = accept(listensock,(struct sockaddr *)&src,&fromlen)) == INVALID_SOCKET) {
			fprintf(stderr, "ERROR: ");  perror("accept");
			exit(1);
		}
	} else {
		if (o_family == AF_INET) {
			if((sock = socket(PF_INET,SOCK_DGRAM,0)) == INVALID_SOCKET) {
				fprintf(stderr, "ERROR: ");  perror("socket");
				exit(1);
			}
		} else {
			if((sock = socket(PF_INET6,SOCK_DGRAM,0)) == INVALID_SOCKET) {
				fprintf(stderr, "ERROR: ");  perror("socket");
				exit(1);
			}	
		}
	}

	/* set pacing rate */
	if ( o_rate != 0 ) {
		rate_len = sizeof(o_rate);
		if (setsockopt(sock,SOL_SOCKET,SO_MAX_PACING_RATE, &o_rate, rate_len) == SOCKET_ERROR) {
			fprintf(stderr, "WARNING: ");  perror("setsockopt - SO_MAX_PACING_RATE");
		}

		o_rate = 0;
		if (getsockopt(sock,SOL_SOCKET,SO_MAX_PACING_RATE, &o_rate, &rate_len) == SOCKET_ERROR) {
			fprintf(stderr, "WARNING: ");  perror("getsockopt - SO_MAX_PACING_RATE");
		} else {
			printf("getsockopt SO_MAX_PACING_RATE val is %ld\n", o_rate);
		}
	}
	if(setsockopt(sock,SOL_SOCKET,SO_RCVBUF,(const char *)&o_rcvbuf_size,
			sizeof(o_rcvbuf_size)) == SOCKET_ERROR) {
		printf("WARNING: setsockopt - SO_RCVBUF\n"); fflush(stdout);
		if (o_output) { fprintf(o_output, "WARNING: "); perror("setsockopt - SO_RCVBUF"); fflush(o_output); }
	}
	sz = sizeof(cur_size);
	if (getsockopt(sock,SOL_SOCKET,SO_RCVBUF,(char *)&cur_size,
			(socklen_t *)&sz) == SOCKET_ERROR) {
		fprintf(stderr, "ERROR: ");  perror("getsockopt - SO_RCVBUF");
		exit(1);
	}
	if (cur_size < o_rcvbuf_size) {
		printf("WARNING: tried to set SO_RCVBUF to %d, only got %d\n", o_rcvbuf_size, cur_size); fflush(stdout);
		if (o_output) { fprintf(o_output, "WARNING: tried to set SO_RCVBUF to %d, only got %d\n", o_rcvbuf_size, cur_size); fflush(o_output); }
	}

	opt = 1;
	if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, (char *)&opt, sizeof(opt)) == SOCKET_ERROR) {
		fprintf(stderr, "ERROR: ");  perror("setsockopt SO_REUSEADDR");
		exit(1);
	}

	if (! o_tcp) {
		
		memset((char *)&name,0,sizeof(name));
		if (o_family == AF_INET) {
			name4 = (struct sockaddr_in *)&name;
			name4->sin_family = AF_INET;
			name4->sin_addr = *(struct in_addr *)groupaddr;
			name4->sin_port = htons(groupport);
		} else {
			name6 = (struct sockaddr_in6 *)&name;
			name6->sin6_family = AF_INET6;
			name6->sin6_addr = *(struct in6_addr *)groupaddr;
			name6->sin6_port = htons(groupport);
		}
		if (bind(sock,(struct sockaddr *)&name,sizeof(name)) == SOCKET_ERROR) {
			/* So OSes don't want you to bind to the m/c group. */
			if (o_family == AF_INET)
				name4->sin_addr.s_addr = htonl(INADDR_ANY);
			else
				name6->sin6_addr = in6addr_any;

			if (bind(sock,(struct sockaddr *)&name, sizeof(name)) == SOCKET_ERROR) {
				fprintf(stderr, "ERROR: ");  perror("bind");
				exit(1);
			}
		}

		/* Set gourp interface */
		if (strcmp(gaddr,"0.0.0.0") != 0 && strcmp(gaddr, "::") != 0) {
			bzero(&req, sizeof(req));
			if (bind_if != NULL) {
				req.gr_interface = if_nametoindex(bind_if);
			} else {
				req.gr_interface = 0;
			}
			if (o_family == AF_INET ) {
				struct sockaddr_in *sin4;
				sin4 = (struct sockaddr_in *)&req.gr_group;
				sin4->sin_family = AF_INET;
				sin4->sin_addr = *(struct in_addr *)groupaddr;
				sin4->sin_port = htons(groupport);
			} else {
				struct sockaddr_in6 *sin6;
				sin6 = (struct sockaddr_in6 *)&req.gr_group;
				sin6->sin6_family = AF_INET6;
				sin6->sin6_addr = *(struct in6_addr *)groupaddr;
				sin6->sin6_port = htons(groupport);
			}

			if (o_family == AF_INET) {
				if (setsockopt(sock, IPPROTO_IP, MCAST_JOIN_GROUP, &req, sizeof(req)) < 0) {
					perror("setsockopt - MCAST_JOIN_GRIOUP");
					exit(1);
				}
			} else {
				if (setsockopt(sock, IPPROTO_IPV6, MCAST_JOIN_GROUP, &req, sizeof(req)) < 0) {
					perror("setsockopt - MCAST_JOIN_GRIOUP");
					exit(1);
				}	
			}
		}

	}

	cur_seq = 0;
	num_rcvd = 0;
	msg_rcvd = 0;
	for (;;) {
		if (o_tcp) {
			cur_size = recv(sock,buff,65536,0);
			if (cur_size == 0) {
				printf("EOF\n");
				if (o_output) { fprintf(o_output, "EOF\n"); }
				break;
			}
		} else {
			cur_size = recvfrom(sock,buff,65536,0,
					(struct sockaddr *)&src,&fromlen);
		}
		if (cur_size == SOCKET_ERROR) {
			fprintf(stderr, "ERROR: ");  perror("recv");
			exit(1);
		}

		/* Use getnameinfo to get address and port, the len should be equal to sockadr_in6 to support ipv6 */
		if (( num = getnameinfo(&src, sizeof(struct sockaddr_in6), hbuf, sizeof(hbuf), sbuf, sizeof(sbuf), NI_NUMERICHOST && NI_NUMERICSERV)) != 0) {
			fprintf(stderr, "Error : getnameinfo error : %s", gai_strerror(num));
			exit(1);
		}

		if (o_quiet_lvl == 0) {  /* non-quiet: print full dump */
			currenttv(&tv);
			printf("%s %s.%s %d bytes:\n",
					format_time(&tv), hbuf, sbuf, cur_size);
			dump(stdout, buff,cur_size);
			if (o_output) {
				fprintf(o_output, "%s %s.%s %d bytes:\n",
						format_time(&tv), hbuf, sbuf, cur_size);
				dump(o_output, buff,cur_size);
			}
		}
		if (o_quiet_lvl == 1) {  /* semi-quiet: print datagram summary */
			currenttv(&tv);
			printf("%s %s.%s %d bytes\n",  /* no colon */
					format_time(&tv), hbuf, sbuf, cur_size);
			fflush(stdout);
			if (o_output) {
				fprintf(o_output, "%s %s.%s %d bytes\n",  /* no colon */
						format_time(&tv), hbuf, sbuf, cur_size);
				fflush(o_output);
			}
		}

		if (cur_size > 5 && memcmp(buff, "echo ", 5) == 0) {
			/* echo command */
			buff[cur_size] = '\0';  /* guarantee trailing null */
			if (buff[cur_size - 1] == '\n')
				buff[cur_size - 1] = '\0';  /* strip trailing nl */
			printf("%s\n", buff); fflush(stdout);
			if (o_output) { fprintf(o_output, "%s\n", buff); fflush(o_output); }

			/* reset stats */
			num_rcvd = 0;
			cur_seq = 0;
			msg_rcvd = 0;
		}
		else if (cur_size > 5 && memcmp(buff, "stat ", 5) == 0) {
			/* when sender tells us to, calc and print stats */
			buff[cur_size] = '\0';  /* guarantee trailing null */
			/* 'stat' message contains num msgs sent */
			// here we use msg_sent instead
			//num_sent = atoi(&buff[5]);
			msg_sent = atol(&buff[5]);
			perc_loss = (float)(msg_sent - msg_rcvd) * 100.0 / (float)msg_sent;
			printf("%ld msgs(bytes) sent, %ld (bytes) received (not including 'stat')\n", msg_sent, msg_rcvd);
			printf("%f%% loss\n", perc_loss);
			fflush(stdout);
			if (o_output) {
				fprintf(o_output, "%ld msgs (bytes) sent, %ld (bytes) received (not including 'stat')\n", msg_sent, msg_rcvd);
				fprintf(o_output, "%f%% loss\n", perc_loss);
				fflush(o_output);
			}

			if (o_stop)
				exit(0);

			/* reset stats */
			num_rcvd = 0;
			cur_seq = 0;
			msg_rcvd = 0;
		}
		else {  /* not a cmd */
			if (o_pause_ms > 0 && ( (o_pause_num > 0 && num_rcvd < o_pause_num)
									|| (o_pause_num == 0) )) {
				SLEEP_MSEC(o_pause_ms);
			}

			if (o_verify) {
				buff[cur_size] = '\0';  /* guarantee trailing null */
				if (cur_seq != strtol(&buff[8], NULL, 16)) {
					printf("Expected seq %x (hex), got %s\n", cur_seq, &buff[8]);
					fflush(stdout);
					/* resyncronize sequence numbers in case there is loss */
					cur_seq = strtol(&buff[8], NULL, 16);
				}
			}

			++num_rcvd;
			++cur_seq;
			msg_rcvd = cur_size + msg_rcvd;
		}
	}  /* for ;; */

	CLOSESOCKET(sock);
	if (o_tcp)
		CLOSESOCKET(listensock);

	exit(0);
}  /* main */



/* tgetopt.c - (renamed from BSD getopt) - this source was adapted from BSD
 *
 * Copyright (c) 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifdef _BSD
extern char *__progname;
#else
#define __progname "tgetopt"
#endif

int	topterr = 1,		/* if error message should be printed */
	toptind = 1,		/* index into parent argv vector */
	toptopt,			/* character checked for validity */
	toptreset;		/* reset getopt */
char	*toptarg;		/* argument associated with option */

#define	BADCH	(int)'?'
#define	BADARG	(int)':'
#define	EMSG	""

/*
 * tgetopt --
 *	Parse argc/argv argument vector.
 */
int
tgetopt(nargc, nargv, ostr)
	int nargc;
	char * const *nargv;
	const char *ostr;
{
	static char *place = EMSG;		/* option letter processing */
	char *oli;				/* option letter list index */

	/* really reset */
	if (toptreset) {
		topterr = 1;
		toptind = 1;
		toptopt = 0;
		toptreset = 0;
		toptarg = NULL;
		place = EMSG;
	}
	if (!*place) {		/* update scanning pointer */
		if (toptind >= nargc || *(place = nargv[toptind]) != '-') {
			place = EMSG;
			return (-1);
		}
		if (place[1] && *++place == '-') {	/* found "--" */
			++toptind;
			place = EMSG;
			return (-1);
		}
	}					/* option letter okay? */
	if ((toptopt = (int)*place++) == (int)':' ||
	    !(oli = strchr(ostr, toptopt))) {
		/*
		 * if the user didn't specify '-' as an option,
		 * assume it means -1.
		 */
		if (toptopt == (int)'-')
			return (-1);
		if (!*place)
			++toptind;
		if (topterr && *ostr != ':')
			(void)fprintf(stderr,
			    "%s: illegal option -- %c\n", __progname, toptopt);
		return (BADCH);
	}
	if (*++oli != ':') {			/* don't need argument */
		toptarg = NULL;
		if (!*place)
			++toptind;
	}
	else {					/* need an argument */
		if (*place)			/* no white space */
			toptarg = place;
		else if (nargc <= ++toptind) {	/* no arg */
			place = EMSG;
			if (*ostr == ':')
				return (BADARG);
			if (topterr)
				(void)fprintf(stderr,
				    "%s: option requires an argument -- %c\n",
				    __progname, toptopt);
			return (BADCH);
		}
	 	else				/* white space */
			toptarg = nargv[toptind];
		place = EMSG;
		++toptind;
	}
	return (toptopt);			/* dump back option letter */
}  /* tgetopt */
