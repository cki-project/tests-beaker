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

#ifndef SCTP_UTILITIES_H
#define SCTP_UTILITIES_H

#define SCTP_SLEEP_MS	100
#ifndef LINUX
#define LINUX
#endif

int sctp_one2one(unsigned short port, int should_listen, int bindall);
int sctp_one2many(unsigned short port, int bindall);

int sctp_get_auth_chunk_id(int fd, uint8_t *fill);
int sctp_set_auth_chunk_id(int fd, uint8_t chk);

/********************************************************
 *
 * SCTP_KEY tests
 *
 ********************************************************/
int sctp_get_auth_key(int fd, sctp_assoc_t assoc_id, uint16_t *keyid,
                      uint16_t *keylen, uint8_t *keytext);
int sctp_set_auth_key(int fd, sctp_assoc_t assoc_id, uint16_t keyid,
                      uint16_t keylen, uint8_t *keytext);

int sctp_get_active_key(int fd, sctp_assoc_t assoc_id, uint16_t *keyid);
int sctp_set_active_key(int fd, sctp_assoc_t assoc_id, uint16_t keyid);

int sctp_get_delete_key(int fd, sctp_assoc_t assoc_id, uint16_t *keyid);
int sctp_set_delete_key(int fd, sctp_assoc_t assoc_id, uint16_t keyid);

int sctp_get_paddr_param(int fd, sctp_assoc_t id,
                         struct sockaddr *sa,
                         uint32_t *hbinterval,
                         uint16_t *maxrxt,
                         uint32_t *pathmtu,
                         uint32_t *flags,
                         uint32_t *ipv6_flowlabel,
                         uint8_t *ipv4_tos);

int sctp_set_paddr_param(int fd, sctp_assoc_t id,
			 struct sockaddr *sa,
			 uint32_t hbinterval,
			 uint16_t maxrxt,
			 uint32_t pathmtu,
			 uint32_t flags,
			 uint32_t ipv6_flowlabel,
			 uint8_t ipv4_tos);

int sctp_set_pmtu(int fd, sctp_assoc_t id,
			struct sockaddr *sa,
			uint32_t pathmtu);

int sctp_set_pmtu_enable(int fd, sctp_assoc_t id,
			struct sockaddr *sa);

int sctp_get_interleave(int fd, int *inter);
int sctp_set_interleave(int fd, int inter);

int sctp_get_pdapi_point(int fd, int *point);
int sctp_set_pdapi_point(int fd, int point);

int sctp_enable_v4_address_mapping(int fd);
int sctp_disable_v4_address_mapping(int fd);
int sctp_v4_address_mapping_enabled(int fd);

int sctp_set_context(int fd, sctp_assoc_t id, uint32_t context);
int sctp_get_context(int fd, sctp_assoc_t id, uint32_t *context);

int sctp_set_maxseg(int fd, sctp_assoc_t id, int val);
int sctp_get_maxseg(int fd, sctp_assoc_t id, int *val);

uint32_t sctp_get_number_of_associations(int);
uint32_t sctp_get_association_identifiers(int, sctp_assoc_t [], unsigned int);

int sctp_get_ndelay(int fd, uint32_t *val);
int sctp_set_ndelay(int fd, uint32_t val);

int handle_notification(int fd, char *notify_buf);
#endif
