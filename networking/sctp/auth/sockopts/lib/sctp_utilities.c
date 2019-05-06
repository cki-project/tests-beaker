/*
 * Copyright (c) 2014-2019 Red Hat, Inc. All rights reserved.
 *
 *   This copyrighted material is made available to anyone wishing
 *   to use, modify, copy, or redistribute it subject to the terms
 *   and conditions of the GNU General Public License version 2.
 *
 *   This program is distributed in the hope that it will be
 *   useful, but WITHOUT ANY WARRANTY; without even the implied
 *   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *   PURPOSE. See the GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public
 *   License along with this program; if not, write to the Free
 *   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *   Boston, MA 02110-1301, USA.
 *
 */

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>
#include <errno.h>
#include <fcntl.h>
#include <time.h>
#include <netinet/sctp.h>

#include "sctp_utilities.h"

void sctp_delay(int ms)
{
    struct timespec ts;
    ts.tv_sec = 0;
    ts.tv_nsec = (ms * 1000 * 1000);
    (void)nanosleep(&ts, NULL);
}

static sctp_assoc_t __get_assoc_id (int fd, struct sockaddr *addr)
{
	struct sctp_paddrinfo sp;
	socklen_t siz;
	socklen_t sa_len;
	int cnt = 0;

	/* First get the assoc id */
 try_again:
	siz = sizeof(sp);
	memset(&sp,0,sizeof(sp));
	if(addr->sa_family == AF_INET) {
		sa_len = sizeof(struct sockaddr_in);
	} else if (addr->sa_family == AF_INET6) {
		sa_len = sizeof(struct sockaddr_in6);
	} else {
		return ((sctp_assoc_t)0);
	}
	memcpy((caddr_t)&sp.spinfo_address, addr, sa_len);
	if(getsockopt(fd, IPPROTO_SCTP, SCTP_GET_PEER_ADDR_INFO,
		      &sp, &siz) != 0) {
		if (cnt < 1) {
			cnt++;
			sctp_delay(SCTP_SLEEP_MS);
			goto try_again;
		}
		return ((sctp_assoc_t)0);
	}
	/* BSD: We depend on the fact that 0 can never be returned */
	return (sp.spinfo_assoc_id);
}

int
sctp_bind(int fd, in_addr_t address, in_port_t port)
{
	struct sockaddr_in addr;

	memset((void *)&addr, 0, sizeof(struct sockaddr_in));
	addr.sin_family      = AF_INET;
#ifdef HAVE_SIN_LEN
	addr.sin_len	     = sizeof(struct sockaddr_in);
#endif
	addr.sin_port	     = htons(port);
	addr.sin_addr.s_addr = htonl(address);

	return (bind(fd, (struct sockaddr *)&addr, (socklen_t)sizeof(struct sockaddr_in)));
}

int sctp_get_auth_key(int fd, sctp_assoc_t assoc_id, uint16_t *keyid,
		      uint16_t *keylen, uint8_t *keytext) {
	socklen_t len;
	struct sctp_authkey *akey;
	int result;

	len = sizeof(*akey) + *keylen;
	akey = (struct sctp_authkey *)alloca(len);
	if (akey == NULL) {
		printf("could not get memory for akey\n");
		return (-1);
	}
	akey->sca_assoc_id = assoc_id;
	akey->sca_keynumber = *keyid;
	bcopy(keytext, akey->sca_key, *keylen);
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_AUTH_KEY, akey, &len);
	if (result >= 0) {
	    /* This should always fail */
	    *keyid = akey->sca_keynumber;
	    *keylen = akey->sca_keylength;
	    bcopy(akey->sca_key, keytext, *keylen);
	}
	return (result);
}

int sctp_set_auth_key(int fd, sctp_assoc_t assoc_id, uint16_t keyid,
		      uint16_t keylen, uint8_t *keytext) {
	socklen_t len;
	struct sctp_authkey *akey;
	int result;

	len = sizeof(*akey) + keylen;
	akey = (struct sctp_authkey *)alloca(len);
	if (akey == NULL) {
		printf("could not get memory for akey\n");
		return (-1);
	}
	akey->sca_assoc_id = assoc_id;
	akey->sca_keynumber = keyid;
	akey->sca_keylength = keylen;
	bcopy(keytext, akey->sca_key, keylen);
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_AUTH_KEY, akey, len);
	return (result);
}

int sctp_get_active_key(int fd, sctp_assoc_t assoc_id, uint16_t *keyid) {
	socklen_t len;
	struct sctp_authkeyid akey;
	int result;

	len = sizeof(akey);
	akey.scact_assoc_id = assoc_id;
	akey.scact_keynumber = *keyid;
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_AUTH_ACTIVE_KEY,
			    &akey, &len);
	if (result >= 0) {
		*keyid = akey.scact_keynumber;
	}
	return (result);
}


int sctp_set_active_key(int fd, sctp_assoc_t assoc_id, uint16_t keyid) {
	socklen_t len;
	struct sctp_authkeyid akey;
	int result;

	len = sizeof(akey);
	akey.scact_assoc_id = assoc_id;
	akey.scact_keynumber = keyid;
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_AUTH_ACTIVE_KEY,
			    &akey, len);
	return (result);
}


int sctp_get_delete_key(int fd, sctp_assoc_t assoc_id, uint16_t *keyid) {
	socklen_t len;
	struct sctp_authkeyid akey;
	int result;

	len = sizeof(akey);
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_AUTH_DELETE_KEY,
			    &akey, &len);
	if (result >= 0) {
	    /* This should always fail */
	    *keyid = akey.scact_keynumber;
	}
	return (result);
}

int sctp_set_delete_key(int fd, sctp_assoc_t assoc_id, uint16_t keyid) {
	socklen_t len;
	struct sctp_authkeyid akey;
	int result;

	len = sizeof(akey);
	akey.scact_assoc_id = assoc_id;
	akey.scact_keynumber = keyid;
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_AUTH_DELETE_KEY,
			    &akey, len);
	return (result);
}


int sctp_one2one(unsigned short port, int should_listen, int bindall)
{
	int fd;

	if ((fd = socket(AF_INET, SOCK_STREAM, IPPROTO_SCTP)) < 0)
		return -1;

	if (sctp_bind(fd, bindall?INADDR_ANY:INADDR_LOOPBACK, 0) < 0) {
		close(fd);
		return -1;
	}
	if (should_listen) {
		if (listen(fd, 1) < 0) {
			close(fd);
			return -1;
		}
	}
	return fd;
}

int sctp_one2many(unsigned short port, int bindall)
{
	int fd;
	struct sockaddr_in addr;

	if ((fd = socket(AF_INET, SOCK_SEQPACKET, IPPROTO_SCTP)) < 0)
		return -1;

	memset((void *)&addr, 0, sizeof(struct sockaddr_in));
	addr.sin_family      = AF_INET;
#ifdef HAVE_SIN_LEN
	addr.sin_len	     = sizeof(struct sockaddr_in);
#endif
	addr.sin_port	     = htons(port);
	if (bindall) {
		addr.sin_addr.s_addr = 0;
	} else {
		addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	}

	if (bind(fd, (struct sockaddr *)&addr, (socklen_t)sizeof(struct sockaddr_in)) < 0) {
		close(fd);
		return -1;
	}

	if (listen(fd, 1) < 0) {
		close(fd);
		return -1;
	}
	return(fd);
}

int sctp_get_auth_chunk_id(int fd, uint8_t *fill)
{
	int result;
	socklen_t len;
	struct sctp_authchunk ch;

	len = sizeof(ch);
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_AUTH_CHUNK,
			    &ch, &len);
	if(result >= 0) {
		/* We really expect this to ALWAYS fail */
		*fill = ch.sauth_chunk;
	}
	return(result);
}

int sctp_set_auth_chunk_id(int fd, uint8_t chk)
{
	int result;
	socklen_t len;
	struct sctp_authchunk ch;

	len = sizeof(ch);
	ch.sauth_chunk = chk;
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_AUTH_CHUNK,
			    &ch, len);
	return(result);

}

int sctp_socketpair_reuse(int fd, int *fds, int bindall)
{
	struct sockaddr_in addr;
	socklen_t addr_len;


	/* Get any old port, but no listen */
	fds[0] = sctp_one2one(0, 0, bindall);
	if (fds[0] < 0) {
		close(fd);
		return -1;
	}
	addr_len = (socklen_t)sizeof(struct sockaddr_in);
	if (getsockname (fd, (struct sockaddr *) &addr, &addr_len) < 0) {
		close(fd);
		close(fds[0]);
		return -1;
	}
	if (bindall) {
		addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	}
	if (connect(fds[0], (struct sockaddr *) &addr, addr_len) < 0) {
		close(fd);
		close(fds[0]);
		return -1;
	}

	if ((fds[1] = accept(fd, NULL, 0)) < 0) {
		close(fd);
		close(fds[0]);
		return -1;
	}
	return 0;
}

int sctp_socketstar(int *fd, int *fds, unsigned int n)
{
	struct sockaddr_in addr;
	socklen_t addr_len;
	unsigned int i, j;

	if ((*fd = socket(AF_INET, SOCK_SEQPACKET, IPPROTO_SCTP)) < 0)
	return -1; 

	memset((void *)&addr, 0, sizeof(struct sockaddr_in));
	addr.sin_family      = AF_INET;
#ifdef HAVE_SIN_LEN
	addr.sin_len	     = sizeof(struct sockaddr_in);
#endif
	addr.sin_port	     = htons(0);
	addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

	if (bind(*fd, (struct sockaddr *)&addr, (socklen_t)sizeof(struct sockaddr_in)) < 0) {
		close(*fd);
		return -1;
	}

	addr_len = (socklen_t)sizeof(struct sockaddr_in);
	if (getsockname (*fd, (struct sockaddr *) &addr, &addr_len) < 0) {
		close(*fd);
		return -1;
	}

	if (listen(*fd, 1) < 0) {
		close(*fd);
		return -1;
	}

	for (i = 0; i < n; i++){
		if ((fds[i] = socket(AF_INET, SOCK_SEQPACKET, IPPROTO_SCTP)) < 0) {
			close(*fd);
			for (j = 0; j < i; j++ )
				close(fds[j]); 
			return -1;
		}

		if (connect(fds[i], (struct sockaddr *) &addr, addr_len) < 0) {
			close(*fd); 
			for (j = 0; j <= i; j++ )
				close(fds[j]);
			return -1;
		}
	}

	return 0;
}

/* If fds[0] != -1 its a valid 1-2-M socket already open
 * that is to be used with the new association
 */
int
sctp_socketpair_1tom(int *fds, sctp_assoc_t *ids, int bindall)
{
	int fd;
	struct sockaddr_in addr;
	socklen_t addr_len;
	int set=0;
	sctp_assoc_t aid;

	fd = sctp_one2many(0, bindall);
	if (fd == -1) {
		printf("Can't get socket\n");
		return -1;
	}

	if(fds[0] == -1) {
		fds[0] = sctp_one2many(0, bindall);
		if (fds[0]  < 0) {
			close(fd);
			return -1;
		}
	}
	set = 1;
	addr_len = (socklen_t)sizeof(struct sockaddr_in);
	if (getsockname (fd, (struct sockaddr *) &addr, &addr_len) < 0) {
		if(set)
			close(fds[0]);
		close(fd);
		return -1;
	}
	if (bindall) {
		addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	}
	if (sctp_connectx(fds[0], (struct sockaddr *) &addr, 1, &aid) < 0) {
		close(fd);
		if(set)
			close(fds[0]);
		return -1;
	}
	fds[1] = fd;
	/* Now get the assoc-id's if the caller wants them */
	if(ids == NULL)
		return 0;

	ids[0] = aid;

	if (getsockname (fds[0], (struct sockaddr *) &addr, &addr_len) < 0) {
		close(fd);
		printf("Can't get socket name2\n");
		if (set)
			close (fds[0]);
		return -1;
	}
	if (bindall) {
		addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	}
	ids[1] = __get_assoc_id (fds[1], (struct sockaddr *)&addr);
	return 0;
}

int
sctp_get_primary(int fd, sctp_assoc_t id, struct sockaddr *sa, socklen_t *alen)
{
	struct sctp_setprim prim;
	socklen_t len, clen;
	int result;
	struct sockaddr *lsa;

	len = sizeof(prim);
	memset(&prim, 0, sizeof(prim));
	prim.ssp_assoc_id = id;
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_PRIMARY_ADDR,
			    &prim, &len);
	lsa = (struct sockaddr *)&prim.ssp_addr;
	if(lsa->sa_family == AF_INET)
		clen = sizeof(struct sockaddr_in);
	else if (lsa->sa_family == AF_INET6)
		clen = sizeof(struct sockaddr_in6);
	else {
		errno = EFAULT;
		return -1;
	}
	if(*alen > clen)
		len = clen;
	else
		len = *alen;

	memcpy(sa, lsa, len);
	*alen = clen;
	return(result);
}

int sctp_get_paddr_param(int fd, sctp_assoc_t id,
			 struct sockaddr *sa,
			 uint32_t *hbinterval,
			 uint16_t *maxrxt,
			 uint32_t *pathmtu,
			 uint32_t *flags,
			 uint32_t *ipv6_flowlabel,
			 uint8_t *ipv4_tos)
{
	struct sctp_paddrparams param;
	socklen_t len;
	int result;
	memset(&param, 0, sizeof(param));
	param.spp_assoc_id = id;
	if(sa) {
		if (sa->sa_family == AF_INET) {
			memcpy(&param.spp_address, sa, sizeof(struct sockaddr_in));
		} else if (sa->sa_family == AF_INET6) {
			memcpy(&param.spp_address, sa, sizeof(struct sockaddr_in6));
		} else {
			errno = EINVAL;
			return -1;
		}
	} else {
		struct sockaddr *sa;
		sa = (struct sockaddr *)&param.spp_address;
		sa->sa_family = AF_INET;
	}
	len = sizeof(param);
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_PEER_ADDR_PARAMS,
			    &param, &len);
	if (result < 0) {
		return (result);
	}
	if (hbinterval) {
		*hbinterval = param.spp_hbinterval;
	}
	if (maxrxt) {
		*maxrxt = param.spp_pathmaxrxt;
	}
	if (pathmtu) {
		*pathmtu  = param.spp_pathmtu;
	}
	if (flags) {
		*flags = param.spp_flags;
	}
#ifndef LINUX
	if (ipv6_flowlabel) {
		*ipv6_flowlabel = param.spp_ipv6_flowlabel;
	}
	if (ipv4_tos) {
		*ipv4_tos = param.spp_ipv4_tos;
	}
#endif
	return (result);
}

int sctp_set_paddr_param(int fd, sctp_assoc_t id,
			 struct sockaddr *sa,
			 uint32_t hbinterval,
			 uint16_t maxrxt,
			 uint32_t pathmtu,
			 uint32_t flags,
			 uint32_t ipv6_flowlabel,
			 uint8_t ipv4_tos)
{
	struct sctp_paddrparams param;
	socklen_t len;
	int result;

	memset(&param, 0, sizeof(param));
	param.spp_assoc_id = id;
	if(sa) {
		if (sa->sa_family == AF_INET) {
			memcpy(&param.spp_address, sa, sizeof(struct sockaddr_in));
		} else if (sa->sa_family == AF_INET6) {
			memcpy(&param.spp_address, sa, sizeof(struct sockaddr_in6));
		} else {
			errno = EINVAL;
			return -1;
		}
	} else {
		struct sockaddr *sa;
		sa = (struct sockaddr *)&param.spp_address;
		sa->sa_family = AF_INET;
	}
	param.spp_hbinterval = hbinterval;
	param.spp_pathmaxrxt = maxrxt;
	param.spp_pathmtu = pathmtu;
	param.spp_flags = flags;
#ifndef LINUX
	param.spp_ipv6_flowlabel = ipv6_flowlabel;
	param.spp_ipv4_tos = ipv4_tos;
#endif
	len = sizeof(param);
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_PEER_ADDR_PARAMS,
			    &param, len);
	return(result);

}

int
sctp_set_pmtu(int fd, sctp_assoc_t id,
	      struct sockaddr *sa,
	      uint32_t pathmtu)
{
	int result;
	uint32_t flags;
	flags = SPP_PMTUD_DISABLE;
	result	= sctp_set_paddr_param(fd, id, sa,
				       0,
				       0,
				       pathmtu,
				       flags,
				       0,
				       0);
	return (result);
}

int
sctp_set_pmtu_enable(int fd, sctp_assoc_t id,
		     struct sockaddr *sa)
{
	int result;
	uint32_t flags;
	flags = SPP_PMTUD_ENABLE;
	result	= sctp_set_paddr_param(fd, id, sa,
				       0,
				       0,
				       0,
				       flags,
				       0,
				       0);
	return (result);
}

int sctp_get_interleave(int fd, int *inter)
{
	int result;
	socklen_t len;

	len = sizeof(*inter);
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_FRAGMENT_INTERLEAVE,
			    inter, &len);
	return(result);

}

int sctp_set_interleave(int fd, int inter)
{
	int result;
	socklen_t len;

	len = sizeof(inter);
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_FRAGMENT_INTERLEAVE,
			    &inter, len);
	return(result);
}

int sctp_get_pdapi_point(int fd, int *point)
{
	int result;
	socklen_t len;

	len = sizeof(*point);
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_PARTIAL_DELIVERY_POINT,
			    point, &len);
	return(result);

}

int sctp_set_pdapi_point(int fd, int point)
{
	int result;
	socklen_t len;

	len = sizeof(point);
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_PARTIAL_DELIVERY_POINT,
			    &point, len);
	return(result);
}

int sctp_enable_v4_address_mapping(int fd)
{
	const int on = 1;
	socklen_t length;

	length = (socklen_t)sizeof(int);
	return (setsockopt(fd, IPPROTO_SCTP, SCTP_I_WANT_MAPPED_V4_ADDR, &on, length));
}

int sctp_disable_v4_address_mapping(int fd)
{
	const int off = 0;
	socklen_t length;

	length = (socklen_t)sizeof(int);
	return (setsockopt(fd, IPPROTO_SCTP, SCTP_I_WANT_MAPPED_V4_ADDR, &off, length));
}

int sctp_v4_address_mapping_enabled(int fd)
{
	int onoff;
	socklen_t length;

	length = (socklen_t)sizeof(int);
	(void)getsockopt(fd, IPPROTO_SCTP, SCTP_I_WANT_MAPPED_V4_ADDR, &onoff, &length);
	return (onoff);
}

int sctp_set_context(int fd, sctp_assoc_t id, uint32_t context)
{
	int result;
	socklen_t len;
	struct sctp_assoc_value av;

	len = sizeof(av);
	av.assoc_id = id;
	av.assoc_value = context;

	result = setsockopt(fd, IPPROTO_SCTP, SCTP_CONTEXT,
			    &av, len);
	return(result);

}

int sctp_get_context(int fd, sctp_assoc_t id, uint32_t *context)
{
	int result;
	socklen_t len;
	struct sctp_assoc_value av;

	len = sizeof(av);
	av.assoc_id = id;
	av.assoc_value = 0;

	result = getsockopt(fd, IPPROTO_SCTP, SCTP_CONTEXT,
			    &av, &len);
	*context = av.assoc_value;
	return(result);
}

int sctp_get_ndelay(int fd, uint32_t *val)
{
	int result;
	socklen_t len;
	len = sizeof(*val);
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_NODELAY,
			    val, &len);
	return (result);
}

int sctp_set_ndelay(int fd, uint32_t val)
{
	int result;
	socklen_t len;
	len = sizeof(val);

	result = setsockopt(fd, IPPROTO_SCTP, SCTP_NODELAY,
			    &val, len);
	return(result);
}


int sctp_get_maxseg(int fd, sctp_assoc_t id, int *val)
{
	socklen_t len;
	struct sctp_assoc_value av;
	int result;

	av.assoc_id = id;
	av.assoc_value = 0;

	len = sizeof(av);
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_MAXSEG,
			    &av, &len);
	*val = av.assoc_value;
	return(result);

}

int sctp_set_maxseg(int fd, sctp_assoc_t id, int val)
{
	socklen_t len;
	int result;
	struct sctp_assoc_value av;
	len = sizeof(av);
	av.assoc_id = id;
	av.assoc_value = val;

	result = setsockopt(fd, IPPROTO_SCTP, SCTP_MAXSEG,
			    &av, len);
	return(result);
}

uint32_t
sctp_get_number_of_associations(int fd)
{
	uint32_t number;
	socklen_t len;

	len = (socklen_t) sizeof(uint32_t);
	if (getsockopt(fd, IPPROTO_SCTP, SCTP_GET_ASSOC_NUMBER, (void *)&number, &len) < 0)
		return -1;
	else
		return number;
}

#ifdef SCTP_GET_ASSOC_ID_LIST
uint32_t
sctp_get_association_identifiers(int fd, sctp_assoc_t ids[], unsigned int n)
{
	socklen_t len;
	char *buf;
	unsigned int i;
	uint32_t number;

	len = (socklen_t) (n * sizeof(sctp_assoc_t)) + sizeof(uint32_t);
	buf = (char *)malloc(len);
	if (getsockopt(fd, IPPROTO_SCTP, SCTP_GET_ASSOC_ID_LIST, (void *)buf, &len) < 0) {
		free(buf);
		return -1;
	} else {
		for (i = 0; i < ((struct sctp_assoc_ids *)buf)->gaids_number_of_ids; i++) {
			ids[i] = ((struct sctp_assoc_ids *)buf)->gaids_assoc_id[i];
		}
		number = ((struct sctp_assoc_ids *)buf)->gaids_number_of_ids;
		free(buf);
		return(number);
	}
}
#endif


int handle_notification(int fd,char *notify_buf)
{
	union sctp_notification *snp;
	struct sctp_assoc_change *sac;
	struct sctp_paddr_change *spc;
	struct sctp_remote_error *sre;
	struct sctp_send_failed *ssf;
	struct sctp_shutdown_event *sse;
	struct sctp_authkey_event *auth;
#if defined(__BSD_SCTP_STACK__)
	struct sctp_stream_reset_event *strrst;
#endif
	int asocDown;
	char *str;
	char buf[256];
	struct sockaddr_in *sin;
	struct sockaddr_in6 *sin6;

	asocDown = 0;
	snp = (union sctp_notification *)notify_buf;
	switch(snp->sn_header.sn_type) {
	case SCTP_ASSOC_CHANGE:
		sac = &snp->sn_assoc_change;
		switch(sac->sac_state) {

		case SCTP_COMM_UP:
			str = "COMMUNICATION UP";
			break;
		case SCTP_COMM_LOST:
			str = "COMMUNICATION LOST";
			asocDown = 1;
			break;
		case SCTP_RESTART:
			str = "RESTART";
			break;
		case SCTP_SHUTDOWN_COMP:
			str = "SHUTDOWN COMPLETE";
			asocDown = 1;
			break;
		case SCTP_CANT_STR_ASSOC:
			str = "CANT START ASSOC";
			asocDown = 1;
			break;
		default:
			str = "UNKNOWN";
		} /* end switch(sac->sac_state) */
		printf("SCTP_ASSOC_CHANGE: %s, sac_error=0x%x assoc=0x%x\n",
		       str,
		       (uint32_t)sac->sac_error,
		       (uint32_t)sac->sac_assoc_id);
		break;
	case SCTP_PEER_ADDR_CHANGE:
		spc = &snp->sn_paddr_change;
		switch(spc->spc_state) {
		case SCTP_ADDR_AVAILABLE:
			str = "ADDRESS AVAILABLE";
			break;
		case SCTP_ADDR_UNREACHABLE:
			str = "ADDRESS UNAVAILABLE";
			break;
		case SCTP_ADDR_REMOVED:
			str = "ADDRESS REMOVED";
			break;
		case SCTP_ADDR_ADDED:
			str = "ADDRESS ADDED";
			break;
		case SCTP_ADDR_MADE_PRIM:
			str = "ADDRESS MADE PRIMARY";
			break;
#if defined(__BSD_SCTP_STACK__)
		case SCTP_ADDR_CONFIRMED:
			str = "ADDRESS CONFIRMED";
			break;
#endif
		default:
			str = "UNKNOWN";
		} /* end switch */
		sin6 = (struct sockaddr_in6 *)&spc->spc_aaddr;
		if (sin6->sin6_family == AF_INET6) {
			char scope_str[16];
			snprintf(scope_str, sizeof(scope_str)-1, " scope %u",
				 sin6->sin6_scope_id);
			inet_ntop(AF_INET6, (char*)&sin6->sin6_addr, buf, sizeof(buf));
			strcat(buf, scope_str);
		} else {
			sin = (struct sockaddr_in *)&spc->spc_aaddr;
			inet_ntop(AF_INET, (char*)&sin->sin_addr, buf, sizeof(buf));
		}
		printf("SCTP_PEER_ADDR_CHANGE: %s, addr=%s, assoc=0x%x\n",
		       str, buf, (uint32_t)spc->spc_assoc_id);
		break;
	case SCTP_REMOTE_ERROR:
		sre = &snp->sn_remote_error;
		printf("SCTP_REMOTE_ERROR: assoc=0x%x\n",
		       (uint32_t)sre->sre_assoc_id);
		break;
	// Support SCTP_AUTH_NEWKEY only on Linux currently
	case SCTP_AUTHENTICATION_INDICATION:
	{
		auth = (struct sctp_authkey_event *)&snp->sn_authkey_event;
		printf("SCTP_AUTHKEY_EVENT: assoc=0x%x - ",
		       (uint32_t)auth->auth_assoc_id);
		switch(auth->auth_indication) {
		case SCTP_AUTH_NEWKEY:
			printf("AUTH_NEWKEY");
			break;
#if defined(__BSD_SCTP_STACK__)
		case SCTP_AUTH_NO_AUTH:
			printf("AUTH_NO_AUTH");
			break;
		case SCTP_AUTH_FREE_KEY:
			printf("AUTH_FREE_KEY");
			break;
#endif
		default:
			printf("Indication 0x%x", auth->auth_indication);
		}
		printf(" key %u, alt_key %u\n", auth->auth_keynumber,
		       auth->auth_altkeynumber);
		break;
	}
#if defined(__BSD_SCTP_STACK__)
	case SCTP_SENDER_DRY_EVENT:
	  break;
	case SCTP_STREAM_RESET_EVENT:
	{
#if defined(UPDATED_SRESET)
		int len;
		char *strscope="unknown";
#endif
		strrst = (struct sctp_stream_reset_event *)&snp->sn_strreset_event;
		printf("SCTP_STREAM_RESET_EVENT: assoc=0x%x\n",
		       (uint32_t)strrst->strreset_assoc_id);
#if defined(UPDATED_SRESET)
		if(strrst->strreset_flags & SCTP_STRRESET_FAILED) {
			printf("Failed\n");
			break;
		}
		if (strrst->strreset_flags & SCTP_STRRESET_INBOUND_STR) {
			strscope = "inbound";
		} else if (strrst->strreset_flags & SCTP_STRRESET_OUTBOUND_STR) {
			strscope = "outbound";
		}
		if (strrst->strreset_flags & SCTP_STRRESET_ADD_STREAM) {
		  printf("Added streams %s new stream total is:%d\n",
				 strscope,
				 strrst->strreset_list[0]
				 );
		  break;
		}
		if(strrst->strreset_flags & SCTP_STRRESET_ALL_STREAMS) {
			printf("All %s streams have been reset\n",
			       strscope);
		} else {
			int i,cnt=0;
			len = ((strrst->strreset_length - sizeof(struct sctp_stream_reset_event))/sizeof(uint16_t));
			printf("Streams ");
			for ( i=0; i<len; i++){
				cnt++;
				printf("%d",strrst->strreset_list[i]);
				if ((cnt % 16) == 0) {
					printf("\n");
				} else {
					printf(",");
				}
			}
			if((cnt % 16) == 0) {
				/* just put out a cr */
				printf("Have been reset %s\n",strscope);
			} else {
				printf(" have been reset %s\n",strscope);
			}
		}
#endif
	}
	break;
#endif
	case SCTP_SEND_FAILED:
	{
		char *msg;
		static char msgbuf[200];
		ssf = &snp->sn_send_failed;
		if(ssf->ssf_flags == SCTP_DATA_UNSENT)
			msg = "data unsent";
		else if(ssf->ssf_flags == SCTP_DATA_SENT)
			msg = "data sent";
		else{
			sprintf(msgbuf,"unknown flags:%d",ssf->ssf_flags);
			msg = msgbuf;
		}
		printf("SCTP_SEND_FAILED: assoc=0x%x flag indicate:%s\n",
		       (uint32_t)ssf->ssf_assoc_id,msg);

	}

		break;
	case SCTP_ADAPTATION_INDICATION:
	  {
	    struct sctp_adaptation_event *ae;
	    ae = &snp->sn_adaptation_event;
	    printf("SCTP_ADAPTION_INDICATION: assoc=0x%x - indication:0x%x\n",
		   (uint32_t)ae->sai_assoc_id, (uint32_t)ae->sai_adaptation_ind);
	  }
	  break;
	case SCTP_PARTIAL_DELIVERY_EVENT:
	  {
	    struct sctp_pdapi_event *pdapi;

	    pdapi = &snp->sn_pdapi_event;
	    printf("SCTP_PD-API event:%u\n",
		   pdapi->pdapi_indication);
	    if(pdapi->pdapi_indication == SCTP_PARTIAL_DELIVERY_ABORTED){
	      printf("PDI - Aborted\n");
	    }
	  }
	  break;

	case SCTP_SHUTDOWN_EVENT:
		sse = &snp->sn_shutdown_event;
		printf("SCTP_SHUTDOWN_EVENT: assoc=0x%x\n",
		       (uint32_t)sse->sse_assoc_id);
		break;
	default:
		printf("Unknown notification event type=0x%x\n", 
		       snp->sn_header.sn_type);
	} /* end switch(snp->sn_header.sn_type) */
	return asocDown;
}

