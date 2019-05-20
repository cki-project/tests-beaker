#include	"func.h"

int set_ip_opt(int *sock);

/*
 * for socket level
 * include/linux/socket.h
 * */
#ifndef SOL_UDPLITE
#define SOL_UDPLITE		136
#endif

/*
 * for socket options
 * include/uapi/asm-generic/socket.h
 */

#ifndef SO_REUSEPORT
#define SO_REUSEPORT	15
#endif
#ifndef SO_TIMESTAMPNS
#define SO_TIMESTAMPNS		35
#endif
#ifndef SO_MARK
#define SO_MARK			36
#endif
#ifndef SO_TIMESTAMPING
#define SO_TIMESTAMPING		37
#endif
#ifndef SO_PROTOCOL
#define SO_PROTOCOL		38
#endif
#ifndef SO_DOMAIN
#define SO_DOMAIN		39
#endif
#ifndef SO_RXQ_OVFL
#define SO_RXQ_OVFL             40
#endif
#ifndef	SO_WIFI_STATUS
#define	SO_WIFI_STATUS	41
#endif
#ifndef	SO_PEEK_OFF
#define	SO_PEEK_OFF	42
#endif
#ifndef	SO_NOFCS
#define	SO_NOFCS	43
#endif
#ifndef SO_LOCK_FILTER
#define SO_LOCK_FILTER	44
#endif
#ifndef SO_SELECT_ERR_QUEUE
#define SO_SELECT_ERR_QUEUE	45
#endif
#ifndef SO_BUSY_POLL
#define SO_BUSY_POLL	46
#endif

/*
 * for ip options
 * include/uapi/linux/in.h
 * */
#ifndef IP_IPSEC_POLICY
#define IP_IPSEC_POLICY	16
#endif
#ifndef IP_XFRM_POLICY
#define IP_XFRM_POLICY	17
#endif
#ifndef IP_PASSSEC
#define IP_PASSSEC	18
#endif
#ifndef IP_TRANSPARENT
#define IP_TRANSPARENT	19
#endif
#ifndef IP_ORIGDSTADDR
#define IP_ORIGDSTADDR       20
#endif
#ifndef IP_NODEFRAG
#define	IP_NODEFRAG	22
#endif
#ifndef IP_MULTICAST_ALL
#define IP_MULTICAST_ALL	49
#endif
#ifndef IP_UNICAST_IF
#define IP_UNICAST_IF	50
#endif

/*
 * for mroute options
 *
 * */
#ifndef MRT_TABLE
#define MRT_TABLE	(MRT_BASE+9)
#endif
#ifndef MRT_ADD_MFC_PROXY
#define MRT_ADD_MFC_PROXY       (MRT_BASE+10)
#endif
#ifndef MRT_DEL_MFC_PROXY
#define MRT_DEL_MFC_PROXY       (MRT_BASE+11)
#endif

/*
 * for tcp options
 * include/uapi/linux/tcp.h
 * */
#ifndef TCP_CONGESTION
#define TCP_CONGESTION		13
#endif
#ifndef TCP_MD5SIG
#define TCP_MD5SIG		14
#endif
#ifndef TCP_THIN_LINEAR_TIMEOUTS
#define TCP_THIN_LINEAR_TIMEOUTS	16
#endif
#ifndef TCP_THIN_DUPACK
#define TCP_THIN_DUPACK		17
#endif
#ifndef TCP_USER_TIMEOUT
#define TCP_USER_TIMEOUT	18
#endif
#ifndef TCP_REPAIR
#define TCP_REPAIR		19
#endif
#ifndef TCP_REPAIR_QUEUE
#define TCP_REPAIR_QUEUE	20
#endif
#ifndef TCP_QUEUE_SEQ
#define TCP_QUEUE_SEQ		21
#endif
#ifndef TCP_REPAIR_OPTIONS
#define TCP_REPAIR_OPTIONS	22
#endif
#ifndef TCP_FASTOPEN
#define TCP_FASTOPEN		23
#endif
#ifndef TCP_TIMESTAMP
#define TCP_TIMESTAMP		24
#endif

/*
 * for udp options
 * include/uapi/linux/udp.h
 * include/net/udplite.h
 * */
#ifndef UDP_CORK
#define UDP_CORK	1
#endif
#ifndef UDP_ENCAP
#define UDP_ENCAP	100
#endif
#ifndef UDPLITE_SEND_CSCOV
#define UDPLITE_SEND_CSCOV	10
#endif
#ifndef UDPLITE_RECV_CSCOV
#define UDPLITE_RECV_CSCOV	11
#endif

/*
 * for sctp options
 * include/uapi/linux/sctp.h
 * */
#ifndef SCTP_GET_ASSOC_ID_LIST
#define SCTP_GET_ASSOC_ID_LIST	29
#endif
#ifndef SCTP_AUTO_ASCONF
#define SCTP_AUTO_ASCONF	30
#endif
#ifndef SCTP_PEER_ADDR_THLDS
#define SCTP_PEER_ADDR_THLDS	31
#endif
