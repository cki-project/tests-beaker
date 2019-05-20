#include	"setopt.h"

/* char iface[IFNAMSIZ] = "eth0"; */
char *iface;
int set_iface;
int raw_socket;
int tcp_socket;
int udp_socket;
int sctp_socket;

/* SOL_RAW */
// TODO: it seem kernel didn't check socket type in net/ipv4/raw.c??
int raw_opts [] = {-1, ICMP_FILTER, 255};

/* SOL_SOCKET */
int socket_opts[] = {-1, 0, SO_DEBUG, SO_REUSEADDR, SO_TYPE, SO_ERROR,
	SO_DONTROUTE, SO_BROADCAST, SO_SNDBUF, SO_RCVBUF, SO_SNDBUFFORCE,
	SO_RCVBUFFORCE, SO_KEEPALIVE, SO_OOBINLINE, SO_NO_CHECK, SO_PRIORITY,
	SO_LINGER, SO_BSDCOMPAT, SO_REUSEPORT, SO_PASSCRED, SO_PEERCRED,
	//This option will make tcp recvmsg too slow, disable it before fix
	//SO_RCVLOWAT,
	SO_SNDLOWAT, SO_RCVTIMEO, SO_SNDTIMEO,
	SO_SECURITY_AUTHENTICATION, SO_SECURITY_ENCRYPTION_TRANSPORT,
	SO_SECURITY_ENCRYPTION_NETWORK, SO_BINDTODEVICE, SO_ATTACH_FILTER,
	SO_DETACH_FILTER, SO_PEERNAME, SO_TIMESTAMP, SO_ACCEPTCONN, SO_PEERSEC,
	SO_PASSSEC, SO_TIMESTAMPNS, SO_MARK, SO_TIMESTAMPING, SO_PROTOCOL,
	SO_DOMAIN, SO_RXQ_OVFL, SO_WIFI_STATUS, SO_PEEK_OFF, SO_NOFCS,
	SO_LOCK_FILTER, SO_SELECT_ERR_QUEUE, SO_BUSY_POLL, 255};

/* IPPROTO_IP */
int ip_opts[] = {-1, 0, IP_TOS, IP_TTL, IP_HDRINCL, IP_OPTIONS, IP_ROUTER_ALERT,
	IP_RECVOPTS, IP_RETOPTS, IP_PKTINFO, IP_PKTOPTIONS, IP_MTU_DISCOVER,
	IP_RECVERR, IP_RECVTTL, IP_RECVTOS, IP_MTU, IP_FREEBIND, IP_IPSEC_POLICY,
	IP_XFRM_POLICY, IP_PASSSEC, IP_TRANSPARENT, IP_ORIGDSTADDR,
	//This option will make tcp recvmsg too slow, disable it before fix
	//IP_MINTTL,
	IP_NODEFRAG, IP_MULTICAST_IF, IP_MULTICAST_TTL, IP_MULTICAST_LOOP,
	IP_ADD_MEMBERSHIP, IP_DROP_MEMBERSHIP, IP_UNBLOCK_SOURCE,
	IP_BLOCK_SOURCE, IP_ADD_SOURCE_MEMBERSHIP, IP_DROP_SOURCE_MEMBERSHIP,
	IP_MSFILTER, MCAST_JOIN_GROUP, MCAST_BLOCK_SOURCE, MCAST_UNBLOCK_SOURCE,
	MCAST_LEAVE_GROUP, MCAST_JOIN_SOURCE_GROUP, MCAST_LEAVE_SOURCE_GROUP,
	MCAST_MSFILTER, IP_MULTICAST_ALL, IP_UNICAST_IF, 255};

/* IPPROTO_IGMP */
int mroute_opts[] = {-1, 0, 1,MRT_INIT, MRT_DONE, MRT_ADD_VIF, MRT_DEL_VIF,
	MRT_ADD_MFC, MRT_DEL_MFC, MRT_VERSION, MRT_ASSERT, MRT_PIM, MRT_TABLE,
	MRT_ADD_MFC_PROXY, MRT_DEL_MFC_PROXY, 255};

/* SOL_TCP */
int tcp_opts[] = {-1, 0, TCP_NODELAY, TCP_MAXSEG, TCP_CORK, TCP_KEEPIDLE,
	TCP_KEEPINTVL, TCP_KEEPCNT, TCP_SYNCNT, TCP_LINGER2, TCP_DEFER_ACCEPT,
	TCP_WINDOW_CLAMP, TCP_INFO, TCP_QUICKACK, TCP_CONGESTION, TCP_MD5SIG,
	TCP_THIN_LINEAR_TIMEOUTS, TCP_THIN_DUPACK, TCP_USER_TIMEOUT,
	TCP_REPAIR, TCP_REPAIR_QUEUE, TCP_QUEUE_SEQ, TCP_REPAIR_OPTIONS,
	TCP_FASTOPEN, TCP_TIMESTAMP, 255};

/* SOL_UDP, SOL_UDPLITE */
int udp_opts[] = {-1, 0, UDP_CORK, UDP_ENCAP, UDPLITE_SEND_CSCOV,
	UDPLITE_RECV_CSCOV, 255};

/* SOL_SCTP */
int sctp_opts[] = {-1, SCTP_RTOINFO, SCTP_ASSOCINFO, SCTP_INITMSG,
	SCTP_NODELAY, SCTP_AUTOCLOSE, SCTP_SET_PEER_PRIMARY_ADDR,
	SCTP_PRIMARY_ADDR, SCTP_ADAPTATION_LAYER, SCTP_DISABLE_FRAGMENTS,
	SCTP_PEER_ADDR_PARAMS, SCTP_DEFAULT_SEND_PARAM, SCTP_EVENTS,
	SCTP_I_WANT_MAPPED_V4_ADDR, SCTP_MAXSEG, SCTP_STATUS,
	SCTP_GET_PEER_ADDR_INFO, SCTP_DELAYED_ACK_TIME, SCTP_CONTEXT,
	SCTP_FRAGMENT_INTERLEAVE, SCTP_PARTIAL_DELIVERY_POINT, SCTP_MAX_BURST,
	SCTP_AUTH_CHUNK, SCTP_HMAC_IDENT, SCTP_AUTH_KEY, SCTP_AUTH_ACTIVE_KEY,
	SCTP_AUTH_DELETE_KEY, SCTP_PEER_AUTH_CHUNKS, SCTP_LOCAL_AUTH_CHUNKS,
	SCTP_GET_ASSOC_NUMBER, SCTP_GET_ASSOC_ID_LIST, SCTP_AUTO_ASCONF,
	SCTP_PEER_ADDR_THLDS, SCTP_SOCKOPT_BINDX_ADD, SCTP_SOCKOPT_BINDX_REM,
	SCTP_SOCKOPT_PEELOFF, SCTP_SOCKOPT_CONNECTX_OLD, SCTP_GET_PEER_ADDRS,
	SCTP_GET_LOCAL_ADDRS, SCTP_SOCKOPT_CONNECTX, SCTP_SOCKOPT_CONNECTX3,
	SCTP_GET_ASSOC_STATS, 255};

void *__set_ip_opt(void *arg)
{
	int i;
	int sockfd = *((int *)arg);

	//int rand_255 = rand() % 255 + 1;	// rand from 1-255
	int rand_255 = rand(1, 255);	// rand from 1-255
	//int on = 1;
	//int off = 0;
	//int max = 255;
	int min = 1;
	int value;
	int mtu_discover = IP_PMTUDISC_DO;
	socklen_t len = sizeof(int);

	/* There is a hidden danger to initialize all value outside the loop.
	 * getsockopt will overlap the initial value
	 */
	socklen_t if_len = sizeof(iface);

	struct ip_mreqn mreqn, mreqm;
	memset(&mreqn, 0, sizeof(struct ip_mreqn));
	memset(&mreqm, 0, sizeof(struct ip_mreqn));
	mreqn.imr_multiaddr.s_addr = inet_addr("224.1.1.1");
	mreqn.imr_address.s_addr = INADDR_ANY;
	if (set_iface == 1)
		mreqn.imr_ifindex = if_nametoindex(iface);
	else
		mreqn.imr_ifindex = 0;
	socklen_t mreqn_len = sizeof(mreqn);
	socklen_t mreqm_len = sizeof(mreqm);

	struct linger {
		int l_onoff;
		int l_linger;
	} line;
	line.l_onoff = 1;
	line.l_linger = 1;
	socklen_t line_len = sizeof(line);

	int buf = 65535;
	socklen_t buf_len = sizeof(buf);

	struct timeval time;
	time.tv_sec = 3;
	time.tv_usec = 0;
	socklen_t time_len = sizeof(time);

	//struct sockaddr addr;
	//socklen_t addr_len = sizeof(addr);

	char ip_opt[50];
	socklen_t ip_opt_len = sizeof(ip_opt);

	while (1) {
		//int on_off = rand() % 2;
		int on_off = rand(0, 1);
		for (i = 0; i < sizeof(socket_opts) / sizeof(socket_opts[0]); i++) {
			//printf("sockfd %d, %s\n", sockfd, opttostring(SOL_SOCKET, socket_opts[i]));
			switch (socket_opts[i]) {
			case SO_ACCEPTCONN:
				if (tcp_socket == 1) {
					test_setsockopt(sockfd, SOL_SOCKET, socket_opts[i], &on_off, len);
					test_getsockopt(sockfd, SOL_SOCKET, socket_opts[i], &value, &len);
				}
				break;
			case SO_TYPE:
			case SO_PROTOCOL:
			case SO_DOMAIN:
			case SO_ERROR:
			case SO_PEERCRED:
			case SO_SNDLOWAT:
				test_setsockopt(sockfd, SOL_SOCKET, socket_opts[i], &on_off, len);
				test_getsockopt(sockfd, SOL_SOCKET, socket_opts[i], &value, &len);
				break;

			case SO_PEEK_OFF:
			case SO_RCVBUFFORCE:
			case SO_SNDBUFFORCE:
				test_setsockopt(sockfd, SOL_SOCKET, socket_opts[i], &on_off, len);
				test_getsockopt(sockfd, SOL_SOCKET, socket_opts[i], &value, &len);
				break;

			// we need bind to a valid device if we want send msg at the same time
			case SO_BINDTODEVICE:
				if (set_iface == 1)
					test_setsockopt(sockfd, SOL_SOCKET, socket_opts[i], iface, if_len);
				break;


			case SO_PEERNAME:
			case SO_PEERSEC:
				/* Only used for connected link like TCP, sikp on UDP */
				//test_getsockopt(sockfd, SOL_SOCKET, socket_opts[i], &addr, &addr_len, 0);
				break;

			case SO_BROADCAST:
			case SO_BSDCOMPAT: /* This socket is obsoleted */
			case SO_DEBUG:
			case SO_DONTROUTE:
			case SO_KEEPALIVE:
			case SO_MARK:
			case SO_NO_CHECK:
			case SO_NOFCS:
			case SO_OOBINLINE:
			case SO_PASSCRED:
			case SO_PASSSEC:
			case SO_PRIORITY:
			case SO_REUSEADDR:
			case SO_RXQ_OVFL:
			case SO_TIMESTAMP:
			case SO_TIMESTAMPNS:
			case SO_TIMESTAMPING:
				test_setsockopt(sockfd, SOL_SOCKET, socket_opts[i], &on_off, len);
				test_getsockopt(sockfd, SOL_SOCKET, socket_opts[i], &value, &len);
				break;

			case SO_LINGER:
				test_sockopt(sockfd, SOL_SOCKET, socket_opts[i], &line, line_len);
				break;

			case SO_RCVBUF:
			case SO_RCVLOWAT:
			case SO_SNDBUF:
				test_sockopt(sockfd, SOL_SOCKET, socket_opts[i], &buf, buf_len);
				break;

			case SO_RCVTIMEO:
			case SO_SNDTIMEO:
				test_sockopt(sockfd, SOL_SOCKET, socket_opts[i], &time, time_len);
				break;

			case SO_ATTACH_FILTER:
			case SO_DETACH_FILTER:
				/* Don't know how to set struct sock_fprog, skip this */
				break;

			default:
				test_setsockopt(sockfd, SOL_SOCKET, socket_opts[i], &on_off, len);
				test_getsockopt(sockfd, SOL_SOCKET, socket_opts[i], &value, &len);
				/* Do not kill the thread, just break */
				break;
			}
		}

		for (i = 0; i < sizeof(ip_opts) / sizeof(ip_opts[0]); i++) {
			//printf("sockfd %d, level %d, name %d\n", sockfd, IPPROTO_IP, ip_opts[i]);
			switch (ip_opts[i]) {

			/* Begin IP socket options */
			case IP_ADD_MEMBERSHIP:
			case IP_DROP_MEMBERSHIP:
				if (udp_socket == 1) {
					test_setsockopt(sockfd, IPPROTO_IP, ip_opts[i], &mreqn, mreqn_len);
					test_getsockopt(sockfd, IPPROTO_IP, ip_opts[i], &mreqm, &mreqm_len);
				}
				break;

			case IP_MINTTL:
				test_setsockopt(sockfd, IPPROTO_IP, ip_opts[i], &min, len);
				test_getsockopt(sockfd, IPPROTO_IP, ip_opts[i], &value, &len);
				break;

			case IP_MULTICAST_IF:
				if (udp_socket == 1) {
					test_setsockopt(sockfd, IPPROTO_IP, ip_opts[i], &mreqn, mreqn_len);
					test_getsockopt(sockfd, IPPROTO_IP, ip_opts[i], &mreqm, &mreqm_len);
				}
				break;

			case IP_RECVERR:
				// this option will receive icmp error msg
				break;

			case IP_TTL:
				test_setsockopt(sockfd, IPPROTO_IP, ip_opts[i], &rand_255, len);
				test_getsockopt(sockfd, IPPROTO_IP, ip_opts[i], &value, &len);
				break;

			case IP_MULTICAST_LOOP:
			case IP_MULTICAST_TTL:
				if (udp_socket == 1) {
					test_setsockopt(sockfd, IPPROTO_IP, ip_opts[i], &on_off, len);
					test_getsockopt(sockfd, IPPROTO_IP, ip_opts[i], &value, &len);
				}
				break;

			case IP_FREEBIND:
				/* this only affect for UDP socket */
			case IP_PASSSEC:
			case IP_PKTINFO:
				/* No supported for SOCK_STREAM sockets */
			case IP_RECVOPTS:
				/* not support in rhel5 */
			case IP_RECVORIGDSTADDR:
			case IP_RECVTOS:
			case IP_RECVTTL:
			case IP_RETOPTS:
			case IP_TOS:
				test_setsockopt(sockfd, IPPROTO_IP, ip_opts[i], &on_off, len);
				test_getsockopt(sockfd, IPPROTO_IP, ip_opts[i], &value, &len);
				break;

			case IP_HDRINCL:
			case IP_ROUTER_ALERT:
			case IP_NODEFRAG:
				/*  Only valid for SOCK_RAW sockets */
				if (raw_socket == 1) {
					test_setsockopt(sockfd, IPPROTO_IP, ip_opts[i], &on_off, len);
					test_getsockopt(sockfd, IPPROTO_IP, ip_opts[i], &value, &len);
				}
				break;

			case IP_MTU:
				/* We should have a tcp connection
				 * when set this value
				 */
				if (tcp_socket == 2)
					test_getsockopt(sockfd, IPPROTO_IP, ip_opts[i], &value, &len);
				break;

			case IP_MTU_DISCOVER:
				test_setsockopt(sockfd, IPPROTO_IP, ip_opts[i], &mtu_discover, len);
				test_getsockopt(sockfd, IPPROTO_IP, ip_opts[i], &value, &len);
				break;

			case IP_OPTIONS:
				test_setsockopt(sockfd, IPPROTO_IP, ip_opts[i], NULL, 0);
				test_getsockopt(sockfd, IPPROTO_IP, ip_opts[i], &ip_opt, &ip_opt_len);
				break;

			default:
				test_setsockopt(sockfd, IPPROTO_IP, ip_opts[i], &on_off, len);
				test_getsockopt(sockfd, IPPROTO_IP, ip_opts[i], &value, &len);
				/* Do not kill the thread, just break */
				break;
			}
		}
		for (i = 0; i < sizeof(tcp_opts) / sizeof(tcp_opts[0]); i++) {
			switch (tcp_opts[i]) {
			case TCP_NODELAY:
				test_setsockopt(sockfd, SOL_TCP, tcp_opts[i], &on_off, len);
				test_getsockopt(sockfd, SOL_TCP, tcp_opts[i], &value, &len);
				break;
			default:
				test_setsockopt(sockfd, SOL_TCP, tcp_opts[i], &on_off, len);
				test_getsockopt(sockfd, SOL_TCP, tcp_opts[i], &value, &len);
				break;
			}
		}
		for (i = 0; i < sizeof(udp_opts) / sizeof(udp_opts[0]); i++) {
			switch (udp_opts[i]) {
			case UDP_CORK:
			case UDP_ENCAP:
				test_setsockopt(sockfd, SOL_UDP, udp_opts[i], &on_off, len);
				test_getsockopt(sockfd, SOL_UDP, udp_opts[i], &value, &len);
				break;
			default:
				test_setsockopt(sockfd, SOL_UDP, udp_opts[i], &on_off, len);
				test_getsockopt(sockfd, SOL_UDP, udp_opts[i], &value, &len);
				break;
			}
		}
		for (i = 0; i < sizeof(sctp_opts) / sizeof(sctp_opts[0]); i++) {
			switch (sctp_opts[i]) {
			case SCTP_RTOINFO:
				test_setsockopt(sockfd, SOL_SCTP, sctp_opts[i], &on_off, len);
				test_getsockopt(sockfd, SOL_SCTP, sctp_opts[i], &value, &len);
				break;
			default:
				test_setsockopt(sockfd, SOL_UDP, sctp_opts[i], &on_off, len);
				test_getsockopt(sockfd, SOL_UDP, sctp_opts[i], &value, &len);
				break;
			}
		}
	}
}

int set_ip_opt(int *sockfd)
{
	pthread_t thread;
	int err;
	err = pthread_create(&thread, NULL, __set_ip_opt, sockfd);
	if (err) {
		fprintf(stderr, "pthread_create failed: \"%s\"\n",
				strerror(err));
		return err;
	}
	return 0;
}
