#include	"func.h"

/* convert integer error to string
 * upstream file: include/uapi/asm-generic/errno-base.h
 * upstream file: include/uapi/asm-generic/errno.h
 */
char *errtostring(int err)
{
	static char strerr[MAX_LEN];

	switch (err) {
	case EPERM:
		return "EPERM";
	case ENOENT:
		return "ENOENT";
	case ESRCH:
		return "ESRCH";
	case EINTR:
		return "EINTR";
	case EIO:
		return "EIO";
	case ENXIO:
		return "ENXIO";
	case E2BIG:
		return "E2BIG";
	case ENOEXEC:
		return "ENOEXEC";
	case EBADF:
		return "EBADF";
	case ECHILD:
		return "ECHILD";
	case EAGAIN:
		return "EAGAIN";
	case ENOMEM:
		return "ENOMEM";
	case EACCES:
		return "EACCES";
	case EFAULT:
		return "EFAULT";
	case ENOTBLK:
		return "ENOTBLK";
	case EBUSY:
		return "EBUSY";
	case EEXIST:
		return "EEXIST";
	case EXDEV:
		return "EXDEV";
	case ENODEV:
		return "ENODEV";
	case ENOTDIR:
		return "ENOTDIR";
	case EISDIR:
		return "EISDIR";
	case EINVAL:
		return "EINVAL";
	case ENFILE:
		return "ENFILE";
	case EMFILE:
		return "EMFILE";
	case ENOTTY:
		return "ENOTTY";
	case ETXTBSY:
		return "ETXTBSY";
	case EFBIG:
		return "EFBIG";
	case ENOSPC:
		return "ENOSPC";
	case ESPIPE:
		return "ESPIPE";
	case EROFS:
		return "EROFS";
	case EMLINK:
		return "EMLINK";
	case EPIPE:
		return "EPIPE";
	case EDOM:
		return "EDOM";
	case ERANGE:
		return "ERANGE";
	case EDEADLK:
		return "EDEADLK";
	case ENAMETOOLONG:
		return "ENAMETOOLONG";
	case ENOLCK:
		return "ENOLCK";
	case ENOSYS:
		return "ENOSYS";
	case ENOTEMPTY:
		return "ENOTEMPTY";
	case ELOOP:
		return "ELOOP";
	case ENOMSG:
		return "ENOMSG";
	case EIDRM:
		return "EIDRM";
	case ECHRNG:
		return "ECHRNG";
	case EL2NSYNC:
		return "EL2NSYNC";
	case EL3HLT:
		return "EL3HLT";
	case EL3RST:
		return "EL3RST";
	case ELNRNG:
		return "ELNRNG";
	case EUNATCH:
		return "EUNATCH";
	case ENOCSI:
		return "ENOCSI";
	case EL2HLT:
		return "EL2HLT";
	case EBADE:
		return "EBADE";
	case EBADR:
		return "EBADR";
	case EXFULL:
		return "EXFULL";
	case ENOANO:
		return "ENOANO";
	case EBADRQC:
		return "EBADRQC";
	case EBADSLT:
		return "EBADSLT";
	case EBFONT:
		return "EBFONT";
	case ENOSTR:
		return "ENOSTR";
	case ENODATA:
		return "ENODATA";
	case ETIME:
		return "ETIME";
	case ENOSR:
		return "ENOSR";
	case ENONET:
		return "ENONET";
	case ENOPKG:
		return "ENOPKG";
	case EREMOTE:
		return "EREMOTE";
	case ENOLINK:
		return "ENOLINK";
	case EADV:
		return "EADV";
	case ESRMNT:
		return "ESRMNT";
	case ECOMM:
		return "ECOMM";
	case EPROTO:
		return "EPROTO";
	case EMULTIHOP:
		return "EMULTIHOP";
	case EDOTDOT:
		return "EDOTDOT";
	case EBADMSG:
		return "EBADMSG";
	case EOVERFLOW:
		return "EOVERFLOW";
	case ENOTUNIQ:
		return "ENOTUNIQ";
	case EBADFD:
		return "EBADFD";
	case EREMCHG:
		return "EREMCHG";
	case ELIBACC:
		return "ELIBACC";
	case ELIBBAD:
		return "ELIBBAD";
	case ELIBSCN:
		return "ELIBSCN";
	case ELIBMAX:
		return "ELIBMAX";
	case ELIBEXEC:
		return "ELIBEXEC";
	case EILSEQ:
		return "EILSEQ";
	case ERESTART:
		return "ERESTART";
	case ESTRPIPE:
		return "ESTRPIPE";
	case EUSERS:
		return "EUSERS";
	case ENOTSOCK:
		return "ENOTSOCK";
	case EDESTADDRREQ:
		return "EDESTADDRREQ";
	case EMSGSIZE:
		return "EMSGSIZE";
	case EPROTOTYPE:
		return "EPROTOTYPE";
	case ENOPROTOOPT:
		return "ENOPROTOOPT";
	case EPROTONOSUPPORT:
		return "EPROTONOSUPPORT";
	case ESOCKTNOSUPPORT:
		return "ESOCKTNOSUPPORT";
	case EOPNOTSUPP:
		return "EOPNOTSUPP";
	case EPFNOSUPPORT:
		return "EPFNOSUPPORT";
	case EAFNOSUPPORT:
		return "EAFNOSUPPORT";
	case EADDRINUSE:
		return "EADDRINUSE";
	case EADDRNOTAVAIL:
		return "EADDRNOTAVAIL";
	case ENETDOWN:
		return "ENETDOWN";
	case ENETUNREACH:
		return "ENETUNREACH";
	case ENETRESET:
		return "ENETRESET";
	case ECONNABORTED:
		return "ECONNABORTED";
	case ECONNRESET:
		return "ECONNRESET";
	case ENOBUFS:
		return "ENOBUFS";
	case EISCONN:
		return "EISCONN";
	case ENOTCONN:
		return "ENOTCONN";
	case ESHUTDOWN:
		return "ESHUTDOWN";
	case ETOOMANYREFS:
		return "ETOOMANYREFS";
	case ETIMEDOUT:
		return "ETIMEDOUT";
	case ECONNREFUSED:
		return "ECONNREFUSED";
	case EHOSTDOWN:
		return "EHOSTDOWN";
	case EHOSTUNREACH:
		return "EHOSTUNREACH";
	case EALREADY:
		return "EALREADY";
	case EINPROGRESS:
		return "EINPROGRESS";
	case ESTALE:
		return "ESTALE";
	case EUCLEAN:
		return "EUCLEAN";
	case ENOTNAM:
		return "ENOTNAM";
	case ENAVAIL:
		return "ENAVAIL";
	case EISNAM:
		return "EISNAM";
	case EREMOTEIO:
		return "EREMOTEIO";
	case EDQUOT:
		return "EDQUOT";
	case ENOMEDIUM:
		return "ENOMEDIUM";
	case EMEDIUMTYPE:
		return "EMEDIUMTYPE";
	case ECANCELED:
		return "ECANCELED";
	case ENOKEY:
		return "ENOKEY";
	case EKEYEXPIRED:
		return "EKEYEXPIRED";
	case EKEYREVOKED:
		return "EKEYREVOKED";
	case EKEYREJECTED:
		return "EKEYREJECTED";
	case EOWNERDEAD:
		return "EOWNERDEAD";
	case ENOTRECOVERABLE:
		return "ENOTRECOVERABLE";
	case ERFKILL:
		return "ERFKILL";
#ifdef EHWPOISON
	case EHWPOISON:
		return "EHWPOISON";
#endif
	default:
		snprintf(strerr, MAX_LEN, "UNKNOW(%d)", err);
		return strerr;
	}
}

char *eai_error_str(int code)
{
	static char strerr[MAX_LEN];

	switch (code) {
	case EAI_AGAIN:
		return "EAI_AGAIN";
	case EAI_BADFLAGS:
		return "EAI_BADFLAGS";
	case EAI_FAIL:
		return "EAI_FAIL";
	case EAI_FAMILY:
		return "EAI_FAMILY";
	case EAI_MEMORY:
		return "EAI_MEMORY";
	case EAI_NONAME:
		return "EAI_NONAME";
	case EAI_OVERFLOW:
		return "EAI_OVERFLOW";
	case EAI_SERVICE:
		return "EAI_SERVICE";
	case EAI_SOCKTYPE:
		return "EAI_SOCKTYPE";
	case EAI_SYSTEM:
		return "EAI_SYSTEM";
	default:
		snprintf(strerr, MAX_LEN, "UNKNOW(%d)", code);
		return strerr;
	}
}

/* convert integer domain to string */
char *domaintostring(int domain)
{
	static char strdomain[MAX_LEN];

	/* If you want to know the numbers, please see
	 * upstream code include/linux/socket.h +140
	 * or gcc code /usr/include/bits/socket.h +40
	 */
	switch (domain) {
	case AF_UNSPEC:
		return "AF_UNSPEC";
	case AF_UNIX:
		return "AF_UNIX";
	case AF_INET:
		return "AF_INET";
	case AF_AX25:
		return "AF_AX25";
	case AF_IPX:
		return "AF_IPX";
	case AF_APPLETALK:
		return "AF_APPLETALK";
	case AF_NETROM:
		return "AF_NETROM";
	case AF_BRIDGE:
		return "AF_BRIDGE";
	case AF_ATMPVC:
		return "AF_ATMPVC";
	case AF_X25:
		return "AF_X25";
	case AF_INET6:
		return "AF_INET6";
	case AF_ROSE:
		return "AF_ROSE";
	case AF_DECnet:
		return "AF_DECnet";
	case AF_NETBEUI:
		return "AF_NETBEUI";
	case AF_SECURITY:
		return "AF_SECURITY";
	case AF_KEY:
		return "AF_KEY";
	case AF_NETLINK:
		return "AF_NETLINK";
	case AF_PACKET:
		return "AF_PACKET";
	case AF_ASH:
		return "AF_ASH";
	case AF_ECONET:
		return "AF_ECONET";
	case AF_ATMSVC:
		return "AF_ATMAVC";
#ifdef AF_RDS
	case AF_RDS:
		return "AF_RDS";
#endif
	case AF_SNA:
		return "AF_SNA";
	case AF_IRDA:
		return "AF_IRDA";
	case AF_PPPOX:
		return "AF_PPPOX";
	case AF_WANPIPE:
		return "AF_WANPIPE";
#ifdef AF_LLC
	case AF_LLC:
		return "AF_LLC";
#endif
#ifdef AF_CAN
	case AF_CAN:
		return "AF_CAN";
#endif
#ifdef AF_TIPC
	case AF_TIPC:
		return "AF_TIPC";
#endif
	case AF_BLUETOOTH:
		return "AF_BLUETOOTH";
#ifdef AF_IUCV
	case AF_IUCV:
		return "AF_IUCV";
#endif
#ifdef AF_RXRPC
	case AF_RXRPC:
		return "AF_RXRPC";
#endif
#ifdef AF_ISDN
	case AF_ISDN:
		return "AF_ISDN";
#endif
#ifdef AF_PHONET
	case AF_PHONET:
		return "AF_PHONET";
#endif
#ifdef AF_IEEE802154
	case AF_IEEE802154:
		return "AF_IEEE802154";
#endif
#ifdef AF_CAIF
	case AF_CAIF:
		return "AF_CAIF";
#endif
#ifdef AF_ALG
	case AF_ALG:
		return "AF_ALG";
#endif
#ifdef AF_NFC
	case AF_NFC:
		return "AF_NFC";
#endif
#ifdef AF_VSOCK
	case AF_VSOCK:
		return "AF_VSOCK";
#endif
	case AF_MAX:
		return "AF_MAX";
	default:
		snprintf(strdomain, MAX_LEN, "UNKNOW(%d)", domain);
		return strdomain;
	}
}

/* convert integer type to string */
char *typetostring(int type)
{
	static char strtype[MAX_LEN];

	/* If you want to know the numbers, please see include/linux/net.h */
	switch (type) {
	case SOCK_STREAM:
		return "SOCK_STREAM";
	case SOCK_DGRAM:
		return "SOCK_DGRAM";
	case SOCK_RAW:
		return "SOCK_RAW";
	case SOCK_RDM:
		return "SOCK_RDM";
	case SOCK_SEQPACKET:
		return "SOCK_SEQPACKET";
#ifdef SOCK_DCCP
	case SOCK_DCCP:
		return "SOCK_DCCP";
#endif
	case SOCK_PACKET:
		return "SOCK_PACKET";
	default:
		snprintf(strtype, MAX_LEN, "UNKNOW(%d)", type);
		return strtype;
	}
}

/* convert integer protocol to string */
char *protostring(int protocol)
{
	static char strprot[MAX_LEN];

	switch (protocol) {
	case IPPROTO_NONE:
		return "IPPROTO_NONE";
	case IPPROTO_RAW:
		return "IPPROTO_RAW";
	case IPPROTO_TCP:
		return "IPPROTO_TCP";
	case IPPROTO_UDP:
		return "IPPROTO_UDP";
	case IPPROTO_IPV6:
		return "IPPROTO_IPV6";
	case IPPROTO_ICMPV6:
		return "IPPROTO_ICMPV6";
	case 0:
		return "0";
	default:
		snprintf(strprot, MAX_LEN, "UNKNOW(%d)", protocol);
		return strprot;
	}
}

/* convert integer level to string
 * upstream file : include/uapi/linux/in.h
 */
char *leveltostring(int level)
{
	static char strlevel[MAX_LEN];

	switch (level) {
	case SOL_SOCKET:
		return "SOL_SOCKET";
	case IPPROTO_IP:
		return "IPPROTO_IP";
	case IPPROTO_IPV6:
		return "IPPROTO_IPV6";
	case IPPROTO_ICMPV6:
		return "IPPROTO_ICMPV6";
	case IPPROTO_TCP:
		return "IPPROTO_TCP";
	case IPPROTO_SCTP:
		return "IPPROTO_SCTP";
	default:
		snprintf(strlevel, MAX_LEN, "UNKNOW(%d)", level);
		return strlevel;
	}
}

/* convert socket integer protocol to string
 * upstream file : include/uapi/asm-generic/socket.h
 */
char *soopttostring(int optname)
{
	static char strlopt[MAX_LEN];

	switch (optname) {
	case SO_DEBUG:
		return "SO_DEBUG";
	case SO_REUSEADDR:
		return "SO_REUSEADDR";
	case SO_TYPE:
		return "SO_TYPE";
	case SO_ERROR:
		return "SO_ERROR";
	case SO_DONTROUTE:
		return "SO_DONTROUTE";
	case SO_BROADCAST:
		return "SO_BROADCAST";
	case SO_SNDBUF:
		return "SO_SNDBUF";
	case SO_RCVBUF:
		return "SO_RCVBUF";
	case SO_KEEPALIVE:
		return "SO_KEEPALIVE";
	case SO_OOBINLINE:
		return "SO_OOBINLINE";
	case SO_NO_CHECK:
		return "SO_NO_CHECK";
	case SO_PRIORITY:
		return "SO_PRIORITY";
	case SO_LINGER:
		return "SO_LINGER";
	case SO_BSDCOMPAT:
		return "SO_BSDCOMPAT";
#ifdef SO_REUSEPORT
	case SO_REUSEPORT:
		return "SO_REUSEPORT";
#endif
	case SO_PASSCRED:
		return "SO_PASSCRED";
	case SO_PEERCRED:
		return "SO_PEERCRED";
	case SO_RCVLOWAT:
		return "SO_RCVLOWAT";
	case SO_SNDLOWAT:
		return "SO_SNDLOWAT";
	case SO_RCVTIMEO:
		return "SO_RCVTIMEO";
	case SO_SNDTIMEO:
		return "SO_SNDTIMEO";
	case SO_SECURITY_AUTHENTICATION:
		return "SO_SECURITY_AUTHENTICATION";
	case SO_SECURITY_ENCRYPTION_TRANSPORT:
		return "SO_SECURITY_ENCRYPTION_TRANSPORT";
	case SO_SECURITY_ENCRYPTION_NETWORK:
		return "SO_SECURITY_ENCRYPTION_NETWORK";
	case SO_BINDTODEVICE:
		return "SO_BINDTODEVICE";
	case SO_ATTACH_FILTER:
		return "SO_ATTACH_FILTER";
	case SO_DETACH_FILTER:
		return "SO_DETACH_FILTER";
	case SO_PEERNAME:
		return "SO_PEERNAME";
	case SO_TIMESTAMP:
		return "SO_TIMESTAMP";
	case SO_ACCEPTCONN:
		return "SO_ACCEPTCONN";
	case SO_PEERSEC:
		return "SO_PEERSEC";
	case SO_SNDBUFFORCE:
		return "SO_SNDBUFFORCE";
	case SO_RCVBUFFORCE:
		return "SO_RCVBUFFORCE";
	case SO_PASSSEC:
		return "SO_PASSSEC";
#ifdef SO_TIMESTAMPNS
	case SO_TIMESTAMPNS:
		return "SO_TIMESTAMPNS";
#endif
#ifdef SO_MARK
	case SO_MARK:
		return "SO_MARK";
#endif
#ifdef SO_TIMESTAMPING
	case SO_TIMESTAMPING:
		return "SO_TIMESTAMPING";
#endif
#ifdef SO_PROTOCOL
	case SO_PROTOCOL:
		return "SO_PROTOCOL";
#endif
#ifdef SO_DOMAIN
	case SO_DOMAIN:
		return "SO_DOMAIN";
#endif
#ifdef SO_RXQ_OVFL
	case SO_RXQ_OVFL:
		return "SO_RXQ_OVFL";
#endif
#ifdef SO_WIFI_STATUS
	case SO_WIFI_STATUS:
		return "SO_WIFI_STATUS";
#endif
#ifdef SO_PEEK_OFF
	case SO_PEEK_OFF:
		return "SO_PEEK_OFF";
#endif
#ifdef SO_NOFCS
	case SO_NOFCS:
		return "SO_NOFCS";
#endif
#ifdef SO_LOCK_FILTER
	case SO_LOCK_FILTER:
		return "SO_LOCK_FILTER";
#endif
	default:
		snprintf(strlopt, MAX_LEN, "UNKNOW(%d)", optname);
		return strlopt;
	}
}

/* convert integer protocol to string
 * upstream file : include/uapi/linux/in.h
 */
char *ipopttostring(int optname)
{
	static char strlopt[MAX_LEN];

	switch (optname) {
	case IP_TOS:
		return "IP_TOS";
	case IP_TTL:
		return "IP_TTL";
	case IP_HDRINCL:
		return "IP_HDRINCL";
	case IP_OPTIONS:
		return "IP_OPTIONS";
	case IP_ROUTER_ALERT:
		return "IP_ROUTER_ALERT";
	case IP_RECVOPTS:
		return "IP_RECVOPTS";
	case IP_RETOPTS:
		return "IP_RETOPTS";
	case IP_PKTINFO:
		return "IP_PKTINFO";
	case IP_PKTOPTIONS:
		return "IP_PKTOPTIONS";
	case IP_MTU_DISCOVER:
		return "IP_MTU_DISCOVER";
	case IP_RECVERR:
		return "IP_RECVERR";
	case IP_RECVTTL:
		return "IP_RECVTTL";
	case IP_RECVTOS:
		return "IP_RECVTOS";
	case IP_MTU:
		return "IP_MTU";
	case IP_FREEBIND:
		return "IP_FREEBIND";
#ifdef IP_IPSEC_POLICY
	case IP_IPSEC_POLICY:
		return "IP_IPSEC_POLICY";
#endif
#ifdef IP_XFRM_POLICY
	case IP_XFRM_POLICY:
		return "IP_XFRM_POLICY";
#endif
	case IP_PASSSEC:
		return "IP_PASSSEC";
#ifdef IP_TRANSPARENT
	case IP_TRANSPARENT:
		return "IP_TRANSPARENT";
#endif
#ifdef IP_ORIGDSTADDR
	case IP_ORIGDSTADDR:
		return "IP_ORIGDSTADDR";
#endif
	case IP_MINTTL:
		return "IP_MINTTL";
#ifdef IP_NODEFRAG
	case IP_NODEFRAG:
		return "IP_NODEFRAG";
#endif
	case IP_MULTICAST_IF:
		return "IP_MULTICAST_IF";
	case IP_MULTICAST_TTL:
		return "IP_MULTICAST_TTL";
	case IP_MULTICAST_LOOP:
		return "IP_MULTICAST_LOOP";
	case IP_ADD_MEMBERSHIP:
		return "IP_ADD_MEMBERSHIP";
	case IP_DROP_MEMBERSHIP:
		return "IP_DROP_MEMBERSHIP";
	case IP_UNBLOCK_SOURCE:
		return "IP_UNBLOCK_SOURCE";
	case IP_BLOCK_SOURCE:
		return "IP_BLOCK_SOURCE";
	case IP_ADD_SOURCE_MEMBERSHIP:
		return "IP_ADD_SOURCE_MEMBERSHIP";
	case IP_DROP_SOURCE_MEMBERSHIP:
		return "IP_DROP_SOURCE_MEMBERSHIP";
	case IP_MSFILTER:
		return "IP_MSFILTER";
	case MCAST_JOIN_GROUP:
		return "MCAST_JOIN_GROUP";
	case MCAST_BLOCK_SOURCE:
		return "MCAST_BLOCK_SOURCE";
	case MCAST_UNBLOCK_SOURCE:
		return "MCAST_UNBLOCK_SOURCE";
	case MCAST_LEAVE_GROUP:
		return "MCAST_LEAVE_GROUP";
	case MCAST_JOIN_SOURCE_GROUP:
		return "MCAST_JOIN_SOURCE_GROUP";
	case MCAST_LEAVE_SOURCE_GROUP:
		return "MCAST_LEAVE_SOURCE_GROUP";
	case MCAST_MSFILTER:
		return "MCAST_MSFILTER";
#ifdef IP_IP_UNICAST_IF
	case IP_MULTICAST_ALL:
		return "IP_MULTICAST_ALL";
#endif
#ifdef IP_UNICAST_IF
	case IP_UNICAST_IF:
		return "IP_UNICAST_IF";
#endif
	default:
		snprintf(strlopt, MAX_LEN, "UNKNOW(%d)", optname);
		return strlopt;
	}
}

/* convert IPv6 integer protocol to string
 * upstream file : include/uapi/linux/in6.h
 */
char *ipv6opttostring(int optname)
{
	static char strlopt[MAX_LEN];

	switch (optname) {
	case IPV6_ADDRFORM:
		return "IPV6_ADDRFORM";
#ifdef IPV6_2292PKTINFO
	case IPV6_2292PKTINFO:
		return "IPV6_2292PKTINFO";
#endif
#ifdef IPV6_2292HOPOPTS
	case IPV6_2292HOPOPTS:
		return "IPV6_2292HOPOPTS";
#endif
#ifdef IPV6_2292DSTOPTS
	case IPV6_2292DSTOPTS:
		return "IPV6_2292DSTOPTS";
#endif
#ifdef IPV6_2292RTHDR
	case IPV6_2292RTHDR:
		return "IPV6_2292RTHDR";
#endif
#ifdef IPV6_2292PKTOPTIONS
	case IPV6_2292PKTOPTIONS:
		return "IPV6_2292PKTOPTIONS";
#endif
	case IPV6_CHECKSUM:
		return "IPV6_CHECKSUM";
#ifdef IPV6_2292HOPLIMIT
	case IPV6_2292HOPLIMIT:
		return "IPV6_2292HOPLIMIT";
#endif
	case IPV6_NEXTHOP:
		return "IPV6_NEXTHOP";
	case IPV6_AUTHHDR:
		return "IPV6_AUTHHDR";
	case IPV6_UNICAST_HOPS:
		return "IPV6_UNICAST_HOPS";
	case IPV6_MULTICAST_IF:
		return "IPV6_MULTICAST_IF";
	case IPV6_MULTICAST_HOPS:
		return "IPV6_MULTICAST_HOPS";
	case IPV6_MULTICAST_LOOP:
		return "IPV6_MULTICAST_LOOP";
	case IPV6_JOIN_GROUP:
		return "IPV6_JOIN_GROUP";
	case IPV6_LEAVE_GROUP:
		return "IPV6_LEAVE_GROUP";
	case IPV6_ROUTER_ALERT:
		return "IPV6_ROUTER_ALERT";
	case IPV6_MTU_DISCOVER:
		return "IPV6_MTU_DISCOVER";
	case IPV6_MTU:
		return "IPV6_MTU";
	case IPV6_RECVERR:
		return "IPV6_RECVERR";
	case IPV6_V6ONLY:
		return "IPV6_V6ONLY";
	case IPV6_JOIN_ANYCAST:
		return "IPV6_JOIN_ANYCAST";
	case IPV6_LEAVE_ANYCAST:
		return "IPV6_LEAVE_ANYCAST";
	case IPV6_IPSEC_POLICY:
		return "IPV6_IPSEC_POLICY";
	case IPV6_XFRM_POLICY:
		return "IPV6_XFRM_POLICY";
#ifdef IPV6_RECVPKTINFO
	case IPV6_RECVPKTINFO:
		return "IPV6_RECVPKTINFO";
#endif
	case IPV6_PKTINFO:
		return "IPV6_PKTINFO";
#ifdef IPV6_RECVHOPLIMIT
	case IPV6_RECVHOPLIMIT:
		return "IPV6_RECVHOPLIMIT";
#endif
	case IPV6_HOPLIMIT:
		return "IPV6_HOPLIMIT";
#ifdef IPV6_RECVHOPOPTS
	case IPV6_RECVHOPOPTS:
		return "IPV6_RECVHOPOPTS";
#endif
	case IPV6_HOPOPTS:
		return "IPV6_HOPOPTS";
#ifdef IPV6_RTHDRDSTOPTS
	case IPV6_RTHDRDSTOPTS:
		return "IPV6_RTHDRDSTOPTS";
#endif
#ifdef IPV6_RECVRTHDR
	case IPV6_RECVRTHDR:
		return "IPV6_RECVRTHDR";
#endif
	case IPV6_RTHDR:
		return "IPV6_RTHDR";
#ifdef IPV6_RECVDSTOPTS
	case IPV6_RECVDSTOPTS:
		return "IPV6_RECVDSTOPTS";
#endif
	case IPV6_DSTOPTS:
		return "IPV6_DSTOPTS";
#ifdef IPV6_RECVTCLASS
	case IPV6_RECVTCLASS:
		return "IPV6_RECVTCLASS";
#endif
#ifdef IPV6_TCLASS
	case IPV6_TCLASS:
		return "IPV6_TCLASS";
#endif
	case MCAST_JOIN_GROUP:
		return "MCAST_JOIN_GROUP";
	case MCAST_LEAVE_GROUP:
		return "MCAST_LEAVE_GROUP";
	case MCAST_BLOCK_SOURCE:
		return "MCAST_BLOCK_SOURCE";
	case MCAST_UNBLOCK_SOURCE:
		return "MCAST_UNBLOCK_SOURCE";
	case MCAST_JOIN_SOURCE_GROUP:
		return "MCAST_JOIN_SOURCE_GROUP";
	case MCAST_LEAVE_SOURCE_GROUP:
		return "MCAST_LEAVE_SOURCE_GROUP";
#ifdef IPV6_ADDR_PREFERENCES
	case IPV6_ADDR_PREFERENCES:
		return "IPV6_ADDR_PREFERENCES";
#endif
#ifdef IPV6_ORIGDSTADDR
	case IPV6_ORIGDSTADDR:
		return "IPV6_ORIGDSTADDR";
#endif
#ifdef IPV6_TRANSPARENT
	case IPV6_TRANSPARENT:
		return "IPV6_TRANSPARENT";
#endif
#ifdef IPV6_UNICAST_IF
	case IPV6_UNICAST_IF:
		return "IPV6_UNICAST_IF";
#endif
	default:
		snprintf(strlopt, MAX_LEN, "UNKNOW(%d)", optname);
		return strlopt;
	}
}

char *opttostring(int level, int optname)
{
	static char str[MAX_LEN];

	switch (level) {
	case SOL_SOCKET:
		snprintf(str, MAX_LEN, "level %s, optname %s",
				leveltostring(level), soopttostring(optname));
		break;
	case IPPROTO_IP:
		snprintf(str, MAX_LEN, "level %s, optname %s",
				leveltostring(level), ipopttostring(optname));
		break;
	case IPPROTO_IPV6:
		snprintf(str, MAX_LEN, "level %s, optname %s",
				leveltostring(level), ipv6opttostring(optname));
		break;
	default:
		snprintf(str, MAX_LEN, "level %s, optname UNKNOWN(%d)",
				leveltostring(level), optname);
		break;
	}
	return str;
}

/* This function contains the optnames that cant be used for setsockopt
 * return 0 if the optname is an exception
 * return -1 if the optname is not an exception
 */
int setsockopt_exception(int level, int optname)
{
	if (level == SOL_SOCKET) {
		switch (optname) {
		case SO_ACCEPTCONN:
#ifdef SO_DOMAIN
		case SO_DOMAIN:
#endif
		case SO_ERROR:
		case SO_PEERCRED:

#ifdef SO_PROTOCOL
		case SO_PROTOCOL:
#endif
		case SO_TYPE:
			return 0;
		default:
			return -1;
		}
	} else if (level == IPPROTO_IP) {
		switch (optname) {
		case IP_MTU:
			return 0;
		default:
			return -1;
		}
	}
	return -1;
}

/* This function contains the optnames that cant be used for getsockopt
 * return 0 if the optname is an exception
 * return -1 if the optname is not an exception
 */
int getsockopt_exception(int level, int optname)
{
	if (level == SOL_SOCKET) {
		switch (optname) {
		case SO_BROADCAST:
			return 0;
		default:
			return -1;
		}
	} else if (level == IPPROTO_IP) {
		switch (optname) {
		case IP_ADD_MEMBERSHIP:
			return 0;
		default:
			return -1;
		}
	}
	return -1;
}

void err_sys(const char *fmt)
{
	perror(fmt);
	exit(EXIT_FAILURE);
}

int test_setsockopt(int sockfd, int level, int optname, const void *optval,
		socklen_t optlen)
{
	int return_value;
	errno = 0;

	return_value = setsockopt(sockfd, level, optname, optval, optlen);
	if (return_value == -1) {
		if (errno == EBADF && setsockopt_exception(level, optname) != -1) {
			if (debug >= 3)
				fprintf(stderr, "Warning : setsockopt doesn't support %s, it is read-only\n",
						opttostring(level, optname));
		/* errno 92: Protocol not availabl, 93-97 : protocol, socket
		 * Operation, family not supported
		 */
		} else if (errno >= ENOPROTOOPT && errno <= EAFNOSUPPORT) {
			if (debug >= 3)
				fprintf(stderr, "Warning : Your system should not support %s, returned %s : %s\n",
						opttostring(level, optname), errtostring(errno), strerror(errno));
		} else if (errno < ENOPROTOOPT || errno > EAFNOSUPPORT) {
			if (debug >= 2)
				fprintf(stderr, "setsockopt %s, return %s\n", opttostring(level, optname), errtostring(errno));
			err_sys("setsockopt error");
		}
	}
	return return_value;
}

int test_getsockopt(int sockfd, int level, int optname, void *optval, socklen_t *optlen)
{
	int return_value;
	errno = 0;

	return_value = getsockopt(sockfd, level, optname, optval, optlen);
	if (return_value == -1) {
		if (errno == EBADF && getsockopt_exception(level, optname) != -1) {
			if (debug >= 3)
				fprintf(stderr, "Warning : getsockopt doesn't support %s, it only valid for setsockopt\n",
					opttostring(level, optname));
			return return_value;
		/* Protocol/Socket/Address/Family not support/available */
		} else if (errno >= ENOPROTOOPT && errno <= EAFNOSUPPORT) {
			if (debug >= 3)
				fprintf(stderr, "Warning : Your system should not support %s, returned %s : %s\n",
						opttostring(level, optname), errtostring(errno), strerror(errno));
			return return_value;
		}
		if (errno < ENOPROTOOPT || errno > EAFNOSUPPORT) {
			if (debug >= 2)
				fprintf(stderr, "getsockopt %s, return %s\n", opttostring(level, optname), errtostring(errno));
			err_sys("getsockopt error");
		}
	}
	return return_value;
}

int test_sockopt(int sockfd, int level, int optname, void *optval, socklen_t optlen)
{
	test_setsockopt(sockfd, level, optname, optval, optlen);
	test_getsockopt(sockfd, level, optname, optval, &optlen);

	return 0;
}
