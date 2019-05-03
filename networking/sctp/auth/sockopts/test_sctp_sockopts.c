#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/sctp.h>
#include <unistd.h>
#include <string.h>
#include <strings.h>
#include <errno.h>
#include <stdio.h>

#include "api_tests.h"
#include "sctp_utilities.h"

/********************************************************
 *
 * SCTP_AUTH_CHUNK tests
 *
 ********************************************************/
/*
 * TEST-TITLE authchk/gso_1_1
 * TEST-DESCR: On a 1-1 socket.
 * TEST-DESCR: Attempt to get an auth-chunk id.
 * TEST-DESCR: This should fail since its a set
 * TEST-DESCR: only option.
 */
DEFINE_APITEST(authchk, gso_1_1)
{
	int result;
	int fd;
	uint8_t chk;

	fd = sctp_one2one(0, 1, 1);
	if (fd < 0) {
		return(strerror(errno));
	}
	result = sctp_get_auth_chunk_id(fd, &chk);
	close (fd);
	if (result >= 0) {
		return "allowed get of auth chunk id";
	}
	return NULL;
}

/*
 * TEST-TITLE authchk/gso_1_M
 * TEST-DESCR: On a 1-M socket.
 * TEST-DESCR: Attempt to get an auth-chunk id.
 * TEST-DESCR: This should fail since its a set
 * TEST-DESCR: only option.
 */
DEFINE_APITEST(authchk, gso_1_M)
{
	int result;
	int fd;
	uint8_t chk;

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return(strerror(errno));
	}
	result = sctp_get_auth_chunk_id(fd, &chk);
	close (fd);
	if (result >= 0) {
		return "allowed get of auth chunk id";
	}
	return NULL;
}

/*
 * TEST-TITLE authchk/sso_1_1
 * TEST-DESCR: On a 1-1 socket.
 * TEST-DESCR: Attempt to add a data chunk (0)
 * TEST-DESCR: to the list of authenticated chunk.
 * TEST-DESCR: This should succeed.
 */
DEFINE_APITEST(authchk, sso_1_1)
{
	int result;
	int fd;
	uint8_t chk;

	fd = sctp_one2one(0, 1, 1);
	if (fd < 0) {
		return(strerror(errno));
	}
	/*
	 * Set to auth a data chunk.
	 */
	chk = 0;
	result = sctp_set_auth_chunk_id(fd, chk);
	close (fd);
	if (result < 0) {
		return(strerror(errno));
	}
	return NULL;
}

/*
 * TEST-TITLE authchk/sso_1_M
 * TEST-DESCR: On a 1-M socket.
 * TEST-DESCR: Attempt to add a data chunk (0)
 * TEST-DESCR: to the list of authenticated chunk.
 * TEST-DESCR: This should succeed.
 */
DEFINE_APITEST(authchk, sso_1_M)
{
	int result;
	int fd;
	uint8_t chk;

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return(strerror(errno));
	}
	/*
	 * Set to auth a data chunk.
	 */
	chk = 0;
	result = sctp_set_auth_chunk_id(fd, chk);
	close (fd);
	if (result < 0) {
		return(strerror(errno));
	}
	return NULL;

}

/********************************************************
 *
 * SCTP_HMAC_IDENT tests
 *
 ********************************************************/
/*
 * TEST-TITLE hmacid/sso_1_1
 * TEST-DESCR: On a 1-1 socket.
 * TEST-DESCR: Set in to prefer sha256 then sha1. If
 * TEST-DESCR: that succeeds verify our settings. If it
 * TEST-DESCR: fails then set just sha1 and verify it
 * TEST-DESCR: is set correctly.
 */
DEFINE_APITEST(hmacid, sso_1_1)
{
	int result, fd;
	socklen_t len;
	int check=2;
	char buffer[sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t)];
	struct sctp_hmacalgo *algo;

	if ((fd = sctp_one2one(0, 1, 1)) < 0) {
		return(strerror(errno));
	}

	algo = (struct sctp_hmacalgo *)buffer;
	algo->shmac_number_of_idents = 2;
	algo->shmac_idents[0] = SCTP_AUTH_HMAC_ID_SHA256;
	algo->shmac_idents[1] = SCTP_AUTH_HMAC_ID_SHA1;
	len = sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t);

	result = setsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, len);
	if (result < 0) {
		/* no sha256, retry with just sha1 */
		algo->shmac_number_of_idents = 1;
		algo->shmac_idents[0] = SCTP_AUTH_HMAC_ID_SHA1;
		len = sizeof(struct sctp_hmacalgo) + 1 * sizeof(uint16_t);
		result = setsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, len);
		if (result < 0) {
			close (fd);
			return strerror(errno);
		}
		check = 1;
	}
	memset(buffer, 0, sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t));
	len = sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t);
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, &len);
	if (result < 0) {
		close (fd);
		return strerror(errno);
	}
	close (fd);
	if (algo->shmac_number_of_idents != check) {
		return "Did not get back the expected list - size wrong";
	}
	if (check == 1) {
		if (algo->shmac_idents[0] != SCTP_AUTH_HMAC_ID_SHA1) {
			return "Wrong list";
		}
	} else {
		if (algo->shmac_idents[0] != SCTP_AUTH_HMAC_ID_SHA256) {
			return "Wrong list";
		}
		if (algo->shmac_idents[1] != SCTP_AUTH_HMAC_ID_SHA1) {
			return "Wrong list";
		}
	}
	return NULL;
}
/*
 * TEST-TITLE hmacid/gso_1_1
 * TEST-DESCR: On a 1-1 socket.
 * TEST-DESCR: Get SCTP hamc idents using getsockopt.
 */
DEFINE_APITEST(hmacid, gso_1_1)
{
	int result, fd;
	socklen_t len;
	char buffer[sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t)];
	struct sctp_hmacalgo *algo;

	if ((fd = sctp_one2one(0, 1, 1)) < 0) {
		return(strerror(errno));
	}

	algo = (struct sctp_hmacalgo *)buffer;
	memset(buffer, 0, sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t));
	len = sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t);
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, &len);
	if (result < 0) {
		close (fd);
		return strerror(errno);
	}
	close (fd);
	if (algo->shmac_number_of_idents == 1) {
		if (algo->shmac_idents[0] != SCTP_AUTH_HMAC_ID_SHA1) {
			return "Wrong HMAC_ID";
		}
	} else {
		if (algo->shmac_idents[0] != SCTP_AUTH_HMAC_ID_SHA1 ||
		    algo->shmac_idents[0] != SCTP_AUTH_HMAC_ID_SHA256) {
			return "Wrong HMAC_ID";
		}
		if (algo->shmac_idents[1] != SCTP_AUTH_HMAC_ID_SHA1 ||
		    algo->shmac_idents[1] != SCTP_AUTH_HMAC_ID_SHA256) {
			return "Wrong HMAC_ID";
		}
	}
	return NULL;
}
/*
 * TEST-TITLE hmacid/sso_1_M
 * TEST-DESCR: On a 1-M socket.
 * TEST-DESCR: Set in to prefer sha256 then sha1. If
 * TEST-DESCR: that succeeds verify our settings. If it
 * TEST-DESCR: fails then set just sha1 and verify it
 * TEST-DESCR: is set correctly.
 */
DEFINE_APITEST(hmacid, sso_1_M)
{
	int result, fd;
	socklen_t len;
	int check=2;
	char buffer[sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t)];
	struct sctp_hmacalgo *algo;

	if ((fd = sctp_one2many(0, 1)) < 0) {
		return(strerror(errno));
	}

	algo = (struct sctp_hmacalgo *)buffer;
	algo->shmac_number_of_idents = 2;
	algo->shmac_idents[0] = SCTP_AUTH_HMAC_ID_SHA256;
	algo->shmac_idents[1] = SCTP_AUTH_HMAC_ID_SHA1;
	len = sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t);

	result = setsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, len);
	if (result < 0) {
		/* no sha256, retry with just sha1 */
		algo->shmac_number_of_idents = 1;
		algo->shmac_idents[0] = SCTP_AUTH_HMAC_ID_SHA1;
		len = sizeof(struct sctp_hmacalgo) + 1 * sizeof(uint16_t);
		result = setsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, len);
		if (result < 0) {
			close (fd);
			return strerror(errno);
		}
		check = 1;
	}
	memset(buffer, 0, sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t));
	len = sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t);
	result = getsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, &len);
	if (result < 0) {
		close (fd);
		return strerror(errno);
	}
	close (fd);
	if (check == 1) {
		if (algo->shmac_idents[0] != SCTP_AUTH_HMAC_ID_SHA1) {
			return "Wrong list";
		}
	} else {
		if (algo->shmac_idents[0] != SCTP_AUTH_HMAC_ID_SHA256) {
			return "Wrong list";
		}
		if (algo->shmac_idents[1] != SCTP_AUTH_HMAC_ID_SHA1) {
			return "Wrong list";
		}
	}
	return NULL;
}

/*
 * TEST-TITLE hmacid/sso_bad_1_1
 * TEST-DESCR: On a 1-1 socket.
 * TEST-DESCR: Set in to prefer id 2960 (bogus) then sha1.
 * TEST-DESCR: Validate that the request is rejected.
 */
DEFINE_APITEST(hmacid, sso_bad_1_1)
{
	int result, fd;
	socklen_t len;
	char buffer[sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t)];
	struct sctp_hmacalgo *algo;

	if ((fd = sctp_one2one(0, 1, 1)) < 0) {
		return(strerror(errno));
	}

	algo = (struct sctp_hmacalgo *)buffer;
	algo->shmac_number_of_idents = 2;
	algo->shmac_idents[0] = 1960;
	algo->shmac_idents[1] = SCTP_AUTH_HMAC_ID_SHA1;
	len = sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t);
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, len);
	close(fd);

	if (result >= 0) {
		return "was able to set bogus hmac id 2960";
	}
	return NULL;
}

/*
 * TEST-TITLE hmacid/sso_bad_1_M
 * TEST-DESCR: On a 1-M socket.
 * TEST-DESCR: Set in to prefer id 2960 (bogus) then sha1.
 * TEST-DESCR: Validate that the request is rejected.
 */
DEFINE_APITEST(hmacid, sso_bad_1_M)
{
	int result, fd;
	socklen_t len;
	char buffer[sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t)];
	struct sctp_hmacalgo *algo;

	if ((fd = sctp_one2many(0, 1)) < 0) {
		return(strerror(errno));
	}

	algo = (struct sctp_hmacalgo *)buffer;
	algo->shmac_number_of_idents = 2;
	algo->shmac_idents[0] = 1960;
	algo->shmac_idents[1] = SCTP_AUTH_HMAC_ID_SHA1;
	len = sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t);
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, len);
	close(fd);

	if (result >= 0) {
		return "was able to set bogus hmac id 2960";
	}
	return NULL;
}

/*
 * TEST-TITLE hmacid/sso_nosha1_1_1
 * TEST-DESCR: On a 1-1 socket.
 * TEST-DESCR: Set to prefer only sha256 without
 * TEST-DESCR: including sha1. The test should fail
 * TEST-DESCR: since sha1 is required to be in the list.
 */
DEFINE_APITEST(hmacid, sso_nosha1_1_1)
{
	int result, fd;
	socklen_t len;
	char buffer[sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t)];
	struct sctp_hmacalgo *algo;

	if ((fd = sctp_one2one(0, 1, 1)) < 0) {
		return(strerror(errno));
	}
	algo = (struct sctp_hmacalgo *)buffer;
	algo->shmac_number_of_idents = 2;
	algo->shmac_idents[0] = SCTP_AUTH_HMAC_ID_SHA256;
	algo->shmac_idents[1] = SCTP_AUTH_HMAC_ID_SHA1;
	len = sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t);
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, len);
	if (result < 0) {
		/* no sha256, retry with just sha1 */
		close (fd);
		return "Can't run test SHA256 not supported";
	}
	algo->shmac_number_of_idents = 1;
	algo->shmac_idents[0] = SCTP_AUTH_HMAC_ID_SHA256;
	len = sizeof(struct sctp_hmacalgo) + 1 * sizeof(uint16_t);
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, len);
	close (fd);
	if (result >= 0) {
		return "Was allowed to set only SHA256";
	}
	return NULL;
}

/*
 * TEST-TITLE hmacid/sso_nosha1_1_M
 * TEST-DESCR: On a 1-M socket.
 * TEST-DESCR: Set to prefer only sha256 without
 * TEST-DESCR: including sha1. The test should fail
 * TEST-DESCR: since sha1 is required to be in the list.
 */
DEFINE_APITEST(hmacid, sso_nosha1_1_M)
{
	int result, fd;
	socklen_t len;
	char buffer[sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t)];
	struct sctp_hmacalgo *algo;

	if ((fd = sctp_one2many(0, 1)) < 0) {
		return(strerror(errno));
	}
	algo = (struct sctp_hmacalgo *)buffer;
	algo->shmac_number_of_idents = 2;
	algo->shmac_idents[0] = SCTP_AUTH_HMAC_ID_SHA256;
	algo->shmac_idents[1] = SCTP_AUTH_HMAC_ID_SHA1;
	len = sizeof(struct sctp_hmacalgo) + 2 * sizeof(uint16_t);
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, len);
	if (result < 0) {
		/* no sha256, retry with just sha1 */
		close (fd);
		return "Can't run test SHA256 not supported";
	}
	algo->shmac_number_of_idents = 1;
	algo->shmac_idents[0] = SCTP_AUTH_HMAC_ID_SHA256;
	len = sizeof(struct sctp_hmacalgo) + 1 * sizeof(uint16_t);
	result = setsockopt(fd, IPPROTO_SCTP, SCTP_HMAC_IDENT, algo, len);
	close (fd);
	if (result >= 0) {
		return "Was allowed to set only SHA256";
	}
	return NULL;
}

/********************************************************
 *
 * SCTP_AUTH_KEY tests
 *
 ********************************************************/
/* endpoint tests */
/*
 * TEST-TITLE authkey/gso_def_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you cannot set the default endpoint keynumber (0)
 * TEST-DESCR: using getsockopt.
 */
DEFINE_APITEST(authkey, gso_def_1_1)
{
	int fd, result;
	uint16_t keyid, keylen;
	uint8_t keytext[128];

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keylen = sizeof(keytext);
	keyid = 0;
	result = sctp_get_auth_key(fd, 0, &keyid, &keylen, keytext);
	if (result >= 0) {
		close(fd);
		return "was able to get auth key";
	}
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE authkey/gso_def_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you cannot set the default endpoint keynumber (0)
 * TEST-DESCR: using getsockopt.
 */
DEFINE_APITEST(authkey, gso_def_1_M)
{
	int fd, result;
	uint16_t keyid, keylen;
	uint8_t keytext[128];

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keylen = sizeof(keytext);
	keyid = 0;
	result = sctp_get_auth_key(fd, 0, &keyid, &keylen, keytext);
	if (result >= 0) {
		close(fd);
		return "was able to get auth key";
	}
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE authkey/gso_new_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you cannot get/set a new endpoint keynumber using getsockopt.
 */
DEFINE_APITEST(authkey, gso_new_1_1)
{
	int fd, result;
	uint16_t keyid, keylen;
	uint8_t keytext[128];

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keylen = sizeof(keytext);
	keyid = 0x1234;
	result = sctp_get_auth_key(fd, 0, &keyid, &keylen, keytext);
	if (result >= 0) {
		close(fd);
		return "was able to get auth key";
	}
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE authkey/gso_new_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you cannot get/set a new endpoint keynumber using getsockopt.
 */
DEFINE_APITEST(authkey, gso_new_1_M)
{
	int fd, result;
	uint16_t keyid, keylen;
	uint8_t keytext[128];

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keylen = sizeof(keytext);
	keyid = 0x1234;
	result = sctp_get_auth_key(fd, 0, &keyid, &keylen, keytext);
	if (result >= 0) {
		close(fd);
		return "was able to get auth key";
	}
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE authkey/sso_def_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you can overwrite the endpoint default keynumber 0,
 * TEST-DESCR: which should have been the NULL key
 */
DEFINE_APITEST(authkey, sso_def_1_1)
{
	int fd, result;
	uint16_t keyid, keylen;
	char *keytext = "This is my key";

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* overwrite the default key */
	keylen = sizeof(*keytext);
	keyid = 0;
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "failed to set auth key";
	}
	/* No way to tell if it was really written ok */
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE authkey/sso_def_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you can overwrite the endpoint default keynumber 0,
 * TEST-DESCR: which should have been the NULL key
 */
DEFINE_APITEST(authkey, sso_def_1_M)
{
	int fd, result;
	uint16_t keyid, keylen;
	char *keytext = "This is my key";

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* overwrite the default key */
	keylen = sizeof(*keytext);
	keyid = 0;
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "failed to set auth key";
	}
	/* No way to tell if it was really written ok */
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE authkey/sso_new_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you can add a new endpoint keynumber 0xFFFF
 */
DEFINE_APITEST(authkey, sso_new_1_1)
{
	int fd, result;
	uint16_t keyid, keylen;
	char *keytext = "This is my new key";

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* add a new key id */
	keylen = sizeof(*keytext);
	keyid = 0xFFFF;
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "failed to set auth key";
	}
	/* No way to tell if it was really written ok */
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE authkey/sso_new_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you can add a new endpoint keynumber 0xFFFF
 */
DEFINE_APITEST(authkey, sso_new_1_M)
{
	int fd, result;
	uint16_t keyid, keylen;
	char *keytext = "This is my new key";

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* add a new key id */
	keylen = sizeof(*keytext);
	keyid = 0xFFFF;
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "failed to set auth key";
	}
	/* No way to tell if it was really written ok */
	close(fd);
	return NULL;
}


/* assoc tests */
/*
 * TEST-TITLE authkey/gso_a_def_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you cannot get the SCTP_AUTH_KEY option on an assoc
 */
DEFINE_APITEST(authkey, gso_a_def_1_1)
{
	int fd, fds[2], result;
	uint16_t keyid, keylen;
	uint8_t keytext[128];

	fds[0] = fds[1] = -1;
	fd = sctp_one2one(0, 1, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	result = sctp_socketpair_reuse(fd, fds, 1);
	if (result < 0) {
		close(fd);
		return (strerror(errno));
	}
	keylen = sizeof(keytext);
	keyid = 0;
	result = sctp_get_auth_key(fds[1], 0, &keyid, &keylen, keytext);
	if (result >= 0) {
		close(fd);
		close(fds[0]);
		close(fds[1]);
		return "was able to get auth key";
	}
	close(fd);
	close(fds[0]);
	close(fds[1]);
	return NULL;
}

/*
 * TEST-TITLE authkey/gso_a_def_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you cannot get the SCTP_AUTH_KEY option on an assoc
 */
DEFINE_APITEST(authkey, gso_a_def_1_M)
{
	int fds[2], result;
	sctp_assoc_t ids[2];
	uint16_t keyid, keylen;
	uint8_t keytext[128];

	fds[0] = fds[1] = -1;
	fds[0] = sctp_one2many(0, 1);
	if (fds[0] < 0) {
		return (strerror(errno));
	}
	result = sctp_socketpair_1tom(fds, ids, 1);
	if (result < 0) {
		close(fds[0]);
		return (strerror(errno));
	}
	keylen = sizeof(keytext);
	keyid = 0;
	result = sctp_get_auth_key(fds[0], ids[0], &keyid, &keylen, keytext);
	if (result >= 0) {
		close(fds[0]);
		close(fds[1]);
		return "was able to get auth key";
	}
	close(fds[0]);
	close(fds[1]);
	return NULL;
}

/*
 * TEST-TITLE authkey/sso_a_def_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you can overwrite the assoc default keynumber 0,
 * TEST-DESCR: which should have been the NULL key
 * TEST-DESCR: and inherited from the endpoint
 */
DEFINE_APITEST(authkey, sso_a_def_1_1)
{
	int fd, fds[2], result;
	uint16_t keyid, keylen;
	char *keytext = "This is my key";

	fds[0] = fds[1] = -1;
	fd = sctp_one2one(0, 1, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	result = sctp_socketpair_reuse(fd, fds, 1);
	if (result < 0) {
		close(fd);
		return (strerror(errno));
	}
	/* overwrite the default key */
	keylen = sizeof(*keytext);
	keyid = 0;
	result = sctp_set_auth_key(fds[1], 0, keyid, keylen,
				   (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		close(fds[0]);
		close(fds[1]);
		return strerror(errno);
	}
	/* No way to tell if it was really written ok */
	close(fd);
	close(fds[0]);
	close(fds[1]);
	return NULL;
}

/*
 * TEST-TITLE authkey/sso_a_def_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you can overwrite the assoc default keynumber 0,
 * TEST-DESCR: which should have been the NULL key
 * TEST-DESCR: and inherited from the endpoint
 */
DEFINE_APITEST(authkey, sso_a_def_1_M)
{
	int fds[2], result;
	sctp_assoc_t ids[2];
	uint16_t keyid, keylen;
	char *keytext = "This is my key";

	fds[0] = sctp_one2many(0, 1);
	if (fds[0] < 0) {
		return (strerror(errno));
	}
	result = sctp_socketpair_1tom(fds, ids, 1);
	if (result < 0) {
		close(fds[0]);
		return (strerror(errno));
	}
	/* overwrite the default key */
	keylen = sizeof(*keytext);
	keyid = 0;
	result = sctp_set_auth_key(fds[0], ids[0], keyid, keylen,
				   (uint8_t *)keytext);
	if (result < 0) {
		close(fds[0]);
		close(fds[1]);
		return "failed to set auth key";
	}
	/* No way to tell if it was really written ok */
	close(fds[0]);
	close(fds[1]);
	return NULL;
}

/*
 * TEST-TITLE authkey/sso_a_new_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you can add a new assoc keynumber 0xFFFF
 */
DEFINE_APITEST(authkey, sso_a_new_1_1)
{
	int fd, fds[2], result;
	uint16_t keyid, keylen;
	char *keytext = "This is my new key";

	fds[0] = fds[1] = -1;
	fd = sctp_one2one(0, 1, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	result = sctp_socketpair_reuse(fd, fds, 1);
	if (result < 0) {
		close(fd);
		return (strerror(errno));
	}
	/* add a new key id */
	keylen = sizeof(*keytext);
	keyid = 0xFFFF;
	result = sctp_set_auth_key(fds[1], 0, keyid, keylen,
				   (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		close(fds[0]);
		close(fds[1]);
		return "failed to set auth key";
	}
	/* No way to tell if it was really written ok */
	close(fd);
	close(fds[0]);
	close(fds[1]);
	return NULL;
}

/*
 * TEST-TITLE authkey/sso_a_new_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you can add a new assoc keynumber 0xFFFF
 */
DEFINE_APITEST(authkey, sso_a_new_1_M)
{
	int fds[2], result;
	sctp_assoc_t ids[2];
	uint16_t keyid, keylen;
	char *keytext = "This is my new key";

	fds[0] = fds[1] = -1;
	fds[0] = sctp_one2many(0, 1);
	if (fds[0] < 0) {
		return (strerror(errno));
	}
	result = sctp_socketpair_1tom(fds, ids, 1);
	if (result < 0) {
		close(fds[0]);
		return (strerror(errno));
	}
	/* add a new key id */
	keylen = sizeof(*keytext);
	keyid = 0xFFFF;
	result = sctp_set_auth_key(fds[0], ids[0], keyid, keylen,
				   (uint8_t *)keytext);
	if (result < 0) {
		close(fds[0]);
		close(fds[1]);
		return "failed to set auth key";
	}
	/* No way to tell if it was really written ok */
	close(fds[0]);
	close(fds[1]);
	return NULL;
}

/********************************************************
 *
 * SCTP_AUTH_ACTIVE_KEY tests
 *
 ********************************************************/
/*
 * TEST-TITLE actkey/gso_def_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you can get the default active endpoint keynumber
 * TEST-DESCR: which should be keynumber 0
 */
DEFINE_APITEST(actkey, gso_def_1_1)
{
	int fd, result;
	uint16_t keyid;

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keyid = 0xff;
	result = sctp_get_active_key(fd, 0, &keyid);
	close(fd);
	if (result < 0) {
		return "was unable to get active key";
	}
	if (keyid != 0) {
		return "default key not key 0";
	}
	return NULL;
}

/*
 * TEST-TITLE actkey/gso_def_1_M
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you can get the default active endpoint keynumber
 * TEST-DESCR: which should be keynumber 0
 */
DEFINE_APITEST(actkey, gso_def_1_M)
{
	int fd, result;
	uint16_t keyid;

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keyid = 0xff;
	result = sctp_get_active_key(fd, 0, &keyid);
	close(fd);
	if (result < 0) {
		return "was unable to get active key";
	}
	if (keyid != 0) {
		return "default key not key 0";
	}
	return NULL;
}

/*
 * TEST-TITLE actkey/sso_def_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you can set the default endpoint keynumber active again
 */
DEFINE_APITEST(actkey, sso_def_1_1)
{
	int fd, result;
	uint16_t keyid, verify_keyid;

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keyid = 0;
	result = sctp_set_active_key(fd, 0, keyid);
	if (result < 0) {
		close(fd);
		return "was unable to set key active";
	}
	result = sctp_get_active_key(fd, 0, &verify_keyid);
	close(fd);
	if (result < 0) {
		return "was unable to get active key";
	}
	if (verify_keyid != keyid) {
		return "active key was not set";
	}
	return NULL;
}

/*
 * TEST-TITLE actkey/sso_def_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you can set the default endpoint keynumber active again
 */
DEFINE_APITEST(actkey, sso_def_1_M)
{
	int fd, result;
	uint16_t keyid, verify_keyid;

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keyid = 0;
	result = sctp_set_active_key(fd, 0, keyid);
	if (result < 0) {
		return "was unable to set key active";
	}
	result = sctp_get_active_key(fd, 0, &verify_keyid);
	close(fd);
	if (result < 0) {
		return "was unable to get active key";
	}
	if (verify_keyid != keyid) {
		return "active key was not set";
	}
	return NULL;
}

/*
 * TEST-TITLE actkey/sso_inval_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you cannot set an unknown keynumber to be active
 */
DEFINE_APITEST(actkey, sso_inval_1_1)
{
	int fd, result;
	uint16_t keyid;

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keyid = 0x1234;
	result = sctp_set_active_key(fd, 0, keyid);
	close(fd);
	if (result >= 0) {
		return "was able to set unknown key active";
	}
	return NULL;
}

/*
 * TEST-TITLE actkey/sso_inval_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you cannot set an unknown keynumber to be active
 */
DEFINE_APITEST(actkey, sso_inval_1_M)
{
	int fd, result;
	uint16_t keyid;

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keyid = 0x1234;
	result = sctp_set_active_key(fd, 0, keyid);
	close(fd);
	if (result >= 0) {
		return "was able to set unknown key active";
	}
	return NULL;
}

/*
 * TEST-TITLE actkey/sso_new_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you can add a new keynumber and set it active.
 * TEST-DESCR: Validates you can also get the new active keynumber.
 */
DEFINE_APITEST(actkey, sso_new_1_1)
{
	int fd, result;
	uint16_t keyid, verify_keyid, keylen;
	char *keytext = "This is my new key";

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keylen = sizeof(*keytext);
	keyid = 0xFFFF;
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "failed to set auth key";
	}
	result = sctp_set_active_key(fd, 0, keyid);
	if (result < 0) {
		close(fd);
		return "was unable to set new key active";
	}
	result = sctp_get_active_key(fd, 0, &verify_keyid);
	close(fd);
	if (result < 0) {
		return "was unable to get active key";
	}
	if (verify_keyid != keyid) {
		return "new active key was not set";
	}
	return NULL;
}

/*
 * TEST-TITLE actkey/sso_new_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you can add a new keynumber and set it active.
 * TEST-DESCR: Validates you can also get the new active keynumber.
 */
DEFINE_APITEST(actkey, sso_new_1_M)
{
	int fd, result;
	uint16_t keyid, verify_keyid, keylen;
	char *keytext = "This is my new key";

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keylen = sizeof(*keytext);
	keyid = 0xFFFF;
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "failed to set auth key";
	}
	result = sctp_set_active_key(fd, 0, keyid);
	if (result < 0) {
		close(fd);
		return "was unable to set new key active";
	}
	result = sctp_get_active_key(fd, 0, &verify_keyid);
	close(fd);
	if (result < 0) {
		return "was unable to get active key";
	}
	if (verify_keyid != keyid) {
		return "new active key was not set";
	}
	return NULL;
}

/*
 * TEST-TITLE actkey/sso_inhdef_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: an assoc inherits the endpoint default active keynumber.
 */
DEFINE_APITEST(actkey, sso_inhdef_1_1)
{
	int fd, fds[2], result;
	uint16_t keyid, a_keyid;

	/* does the new assoc inherit the default active key from the ep? */
	fd = sctp_one2one(0, 1, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	result = sctp_get_active_key(fd, 0, &keyid);
	if (result < 0) {
		close(fd);
		return "was unable to get active key";
	}
	result = sctp_socketpair_reuse(fd, fds, 1);
	if (result < 0) {
		close(fd);
		return (strerror(errno));
	}
	result = sctp_get_active_key(fds[1], 0, &a_keyid);
	close(fd);
	close(fds[0]);
	close(fds[1]);
	if (result < 0) {
		return "was unable to get assoc active key";
	}
	if (a_keyid != keyid) {
		return "did not inherit from ep";
	}
	return NULL;
}

/*
 * TEST-TITLE actkey/sso_inhdef_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: an assoc inherits the endpoint default active keynumber.
 */
DEFINE_APITEST(actkey, sso_inhdef_1_M)
{
	int fds[2], result;
	sctp_assoc_t ids[2];
	uint16_t keyid, a_keyid;
	char *ret = NULL;

	/* does the new assoc inherit the default active key from the ep? */
	fds[0] = fds[1] = -1;
	fds[0] = sctp_one2many(0, 1);
	if (fds[0] < 0) {
		return (strerror(errno));
	}
	result = sctp_get_active_key(fds[0], 0, &keyid);
	if (result < 0) {
		close(fds[0]);
		return "was unable to get ep active key";
	}

	result = sctp_socketpair_1tom(fds, ids, 1);
	if (result < 0) {
		close(fds[0]);
		return (strerror(errno));
	}
	result = sctp_get_active_key(fds[0], ids[0], &a_keyid);
	if (result < 0) {
		ret = "was unable to get assoc active key";
		goto out;
	}
	if (a_keyid != keyid) {
		ret = "did not inherit default active key";
		goto out;
	}
 out:
	close(fds[0]);
	close(fds[1]);
	return (ret);
}

/*
 * TEST-TITLE actkey/sso_inhnew_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: an assoc inherits the endpoint active keynumber.
 */
DEFINE_APITEST(actkey, sso_inhnew_1_1)
{
	int fd, fds[2], result;
	uint16_t keyid, a_keyid, keylen;
	char *keytext = "This is my new key";
	char *ret = NULL;

	/* does the new assoc inherit the new active key from the ep? */
	fd = sctp_one2one(0, 1, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* add a new key to the ep */
	keylen = sizeof(*keytext);
	keyid = 0xFFFF;
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "failed to set auth key";
	}
	result = sctp_set_active_key(fd, 0, keyid);
	if (result < 0) {
		close(fd);
		return "was unable to set new key active";
	}
	/* create a new assoc */
	result = sctp_socketpair_reuse(fd, fds, 1);
	if (result < 0) {
		close(fd);
		return (strerror(errno));
	}
	/* verify the assoc inherits the ep active key */
	result = sctp_get_active_key(fds[1], 0, &a_keyid);
	if (result < 0) {
		ret = "was unable to get active key";
		goto out;
	}
	if (a_keyid != keyid) {
		ret = "new active key was not set";
		goto out;
	}
 out:
	close(fd);
	close(fds[0]);
	close(fds[1]);
	return (ret);
}

/*
 * TEST-TITLE actkey/sso_inhnew_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: an assoc inherits the endpoint active keynumber.
 */
DEFINE_APITEST(actkey, sso_inhnew_1_M)
{
	int fds[2], result;
	sctp_assoc_t ids[2];
	uint16_t keyid, a_keyid, keylen;
	char *keytext = "This is my new key";
	char *ret = NULL;

	/* does the new assoc inherit the new active key from the ep? */
	fds[0] = fds[1] = -1;
	fds[0] = sctp_one2many(0, 1);
	if (fds[0] < 0) {
		return (strerror(errno));
	}
	/* add a new key to the ep */
	keylen = sizeof(*keytext);
	keyid = 0xFFFF;
	result = sctp_set_auth_key(fds[0], 0, keyid, keylen,
				   (uint8_t *)keytext);
	if (result < 0) {
		close(fds[0]);
		return "failed to set auth key";
	}
	result = sctp_set_active_key(fds[0], 0, keyid);
	if (result < 0) {
		close(fds[0]);
		return "was unable to set new key active";
	}
	/* create a new assoc */
	result = sctp_socketpair_1tom(fds, ids, 1);
	if (result < 0) {
		close(fds[0]);
		return (strerror(errno));
	}
	/* verify the assoc inherits the ep active key */
	result = sctp_get_active_key(fds[0], ids[0], &a_keyid);
	if (result < 0) {
		ret = "was unable to get assoc active key";
		goto out;
	}
	if (a_keyid != keyid) {
		ret = "did not inherit default active key";
		goto out;
	}
 out:
	close(fds[0]);
	close(fds[1]);
	return (ret);
}

/*
 * TEST-TITLE actkey/sso_achg_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: changing the assoc active keynumber leaves the ep active
 * TEST-DESCR: keynumber the same.
 */
DEFINE_APITEST(actkey, sso_achg_1_1)
{
	int fd, fds[2], result;
	uint16_t def_keyid, keyid, a_keyid, keylen;
	char *keytext = "This is my new key";
	char *ret = NULL;

	/* does changing the assoc active key leave the ep alone? */
	fd = sctp_one2one(0, 1, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* get the default key */
	result = sctp_get_active_key(fd, 0, &def_keyid);
	if (result < 0) {
		close(fd);
		return "was unable to get default active key";
	}
	/* add a new key */
	keylen = sizeof(*keytext);
	keyid = 1;
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "failed to set auth key";
	}
	/* create a new assoc */
	result = sctp_socketpair_reuse(fd, fds, 1);
	if (result < 0) {
		close(fd);
		return (strerror(errno));
	}
	/* get assoc's active key, should be default key */
	result = sctp_get_active_key(fds[1], 0, &a_keyid);
	if (result < 0) {
		ret = "was unable to get active key";
		goto out;
	}
	if (a_keyid != def_keyid) {
		ret = "new active key was not set";
		goto out;
	}
	/* set assoc's active key */
	result = sctp_set_active_key(fds[1], 0, keyid);
	if (result < 0) {
		ret = "was unable to set assoc active key";
		goto out;
	}
	result = sctp_get_active_key(fds[1], 0, &a_keyid);
	if (result < 0) {
		ret = "was unable to get active key";
		goto out;
	}
	if (a_keyid != keyid) {
		ret = "new active key was not set";
		goto out;
	}
	/* make sure ep active key didn't change */
	result = sctp_get_active_key(fd, 0, &keyid);
	if (result < 0) {
		ret = "was unable to get ep active key back";
		goto out;
	}
	if (keyid != def_keyid) {
		ret = "ep active key changed";
		goto out;
	}

 out:
	close(fd);
	close(fds[0]);
	close(fds[1]);
	return (ret);
}

/*
 * TEST-TITLE actkey/sso_achg_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: changing the assoc active keynumber leaves the ep active
 * TEST-DESCR: keynumber the same.
 */
DEFINE_APITEST(actkey, sso_achg_1_M)
{
	int fds[2], result;
	sctp_assoc_t ids[2];
	uint16_t def_keyid, keyid, a_keyid, keylen;
	char *keytext = "This is my new key";
	char *ret = NULL;

	/* does changing the assoc active key leave the ep alone? */
	fds[0] = fds[1] = -1;
	fds[0] = sctp_one2many(0, 1);
	if (fds[0] < 0) {
		return (strerror(errno));
	}
	/* get the default key */
	result = sctp_get_active_key(fds[0], 0, &def_keyid);
	if (result < 0) {
		close(fds[0]);
		return "was unable to geet default active key";
	}
	/* add a new key */
	keylen = sizeof(*keytext);
	keyid = 1;
	result = sctp_set_auth_key(fds[0], 0, keyid, keylen,
				   (uint8_t *)keytext);
	if (result < 0) {
		close(fds[0]);
		return "failed to set auth key";
	}
	/* create a new assoc */
	result = sctp_socketpair_1tom(fds, ids, 1);
	if (result < 0) {
		close(fds[0]);
		return (strerror(errno));
	}
	/* get assoc's active key, should be default key */
	result = sctp_get_active_key(fds[0], ids[0], &a_keyid);
	if (result < 0) {
		ret = "was unable to get active key";
		goto out;
	}
	if (a_keyid != def_keyid) {
		ret = "new active key was not set";
		goto out;
	}
	/* set assoc's active key */
	result = sctp_set_active_key(fds[0], ids[0], keyid);
	if (result < 0) {
		ret = "was unable to set assoc active key";
		goto out;
	}
	result = sctp_get_active_key(fds[0], ids[0], &a_keyid);
	if (result < 0) {
		ret = "was unable to get active key";
		goto out;
	}
	if (a_keyid != keyid) {
		ret = "new active key was not set";
		goto out;
	}
	/* make sure ep active key didn't change */
	result = sctp_get_active_key(fds[0], 0, &keyid);
	if (result < 0) {
		ret = "was unable to get ep active key back";
		goto out;
	}
	if (keyid != def_keyid) {
		ret = "ep active key changed";
		goto out;
	}

 out:
	close(fds[0]);
	close(fds[1]);
	return (ret);
}

/********************************************************
 *
 * SCTP_AUTH_DELETE_KEY tests
 *
 ********************************************************/
/*
 * NOTE: These tests assume SCTP_AUTH_KEY and SCTP_AUTH_ACTIVE_KEY socket
 * options are WORKING.  Any failure in AUTH_KEY or AUTH_ACTIVE_KEY will
 * likely fail additional tests in this suite.
 */

/*
 * TEST-TITLE delkey/gso_def_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you cannot delete the default endpoint key using getsockopt.
 */
DEFINE_APITEST(delkey, gso_def_1_1)
{
	int fd, result;
	uint16_t keyid;

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keyid = 0;
	result = sctp_get_delete_key(fd, 0, &keyid);
	close(fd);
	if (result >= 0) {
		return "was able to get delete key?";
	}
	return NULL;
}

/*
 * TEST-TITLE delkey/gso_def_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you cannot delete the default endpoint key using getsockopt.
 */
DEFINE_APITEST(delkey, gso_def_1_M)
{
	int fd, result;
	uint16_t keyid;

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keyid = 0;
	result = sctp_get_delete_key(fd, 0, &keyid);
	close(fd);
	if (result >= 0) {
		return "was able to get delete key?";
	}
	return NULL;
}

/*
 * TEST-TITLE delkey/gso_inval_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you cannot delete an unknown keynumber using getsockopt.
 */
DEFINE_APITEST(delkey, gso_inval_1_1)
{
	int fd, result;
	uint16_t keyid;

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keyid = 0x1234;
	result = sctp_get_delete_key(fd, 0, &keyid);
	close(fd);
	if (result >= 0) {
		return "was able to get delete key?";
	}
	return NULL;
}

/*
 * TEST-TITLE delkey/gso_inval_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you cannot delete an unknown keynumber using getsockopt.
 */
DEFINE_APITEST(delkey, gso_inval_1_M)
{
	int fd, result;
	uint16_t keyid;

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	keyid = 0x1234;
	result = sctp_get_delete_key(fd, 0, &keyid);
	close(fd);
	if (result >= 0) {
		return "was able to get delete key?";
	}
	return NULL;
}

/*
 * TEST-TITLE delkey/sso_def_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you cannot delete the default endpoint key because it is
 * TEST-DESCR: the current active keynumber.
 */
DEFINE_APITEST(delkey, sso_def_1_1)
{
	int fd, result;
	uint16_t keyid;

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* delete the default, active key */
	keyid = 0;
	result = sctp_get_delete_key(fd, 0, &keyid);
	if (result >= 0) {
		close(fd);
		return "was able to delete default active key";
	}
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE delkey/sso_def_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you cannot delete the default endpoint key because it is
 * TEST-DESCR: the current active keynumber.
 */
DEFINE_APITEST(delkey, sso_def_1_M)
{
	int fd, result;
	uint16_t keyid;

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* delete the default, active key */
	keyid = 0;
	result = sctp_get_delete_key(fd, 0, &keyid);
	if (result >= 0) {
		close(fd);
		return "was able to delete default active key";
	}
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE delkey/sso_inval_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you cannot delete a keynumber that has not been previously
 * TEST-DESCR: added using SCTP_AUTH_KEY.
 */
DEFINE_APITEST(delkey, sso_inval_1_1)
{
	int fd, result;
	uint16_t keyid;

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* delete a non-existant key */
	keyid = 1234;
	result = sctp_get_delete_key(fd, 0, &keyid);
	if (result >= 0) {
		close(fd);
		return "was able to delete non-existant key";
	}
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE delkey/sso_inval_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you cannot delete a keynumber that has not been previously
 * TEST-DESCR: added using SCTP_AUTH_KEY.
 */
DEFINE_APITEST(delkey, sso_inval_1_M)
{
	int fd, result;
	uint16_t keyid;

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* delete a non-existant key */
	keyid = 1234;
	result = sctp_set_delete_key(fd, 0, keyid);
	if (result >= 0) {
		close(fd);
		return "was able to delete non-existant key";
	}
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE delkey/sso_new_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you can delete a newly added keynumber that has not been
 * TEST-DESCR: made active. Note this tries to delete the deleted keynumber
 * TEST-DESCR: to make sure the delete actually occurred.
 */
DEFINE_APITEST(delkey, sso_new_1_1)
{
	int fd, result;
	uint16_t keyid, keylen;
	char *keytext = "This is my new key";

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* add a new key */
	keyid = 1;
	keylen = sizeof(*keytext);
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "was unable to add key";
	}

	/* delete the key */
	result = sctp_set_delete_key(fd, 0, keyid);
	if (result < 0) {
		close(fd);
		return "was unable to delete key";
	}
	/* delete again to make sure it's really gone */
	result = sctp_set_delete_key(fd, 0, keyid);
	if (result >= 0) {
		close(fd);
		return "was able to re-delete key";
	}
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE delkey/sso_new_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you can delete a newly added keynumber that has not been
 * TEST-DESCR: made active. Note this tries to delete the deleted keynumber
 * TEST-DESCR: to make sure the delete actually occurred.
 */
DEFINE_APITEST(delkey, sso_new_1_M)
{
	int fd, result;
	uint16_t keyid, keylen;
	char *keytext = "This is my new key";

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* add a new key */
	keyid = 1;
	keylen = sizeof(*keytext);
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "was unable to add key";
	}

	/* delete the key */
	result = sctp_set_delete_key(fd, 0, keyid);
	if (result < 0) {
		close(fd);
		return "was unable to delete key";
	}
	/* delete again to make sure it's really gone */
	result = sctp_set_delete_key(fd, 0, keyid);
	if (result >= 0) {
		close(fd);
		return "was able to re-delete key";
	}
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE delkey/sso_newact_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you cannot delete a newly added keynumber that has been
 * TEST-DESCR: made active.
 */
DEFINE_APITEST(delkey, sso_newact_1_1)
{
	int fd, result;
	uint16_t keyid, keylen;
	char *keytext = "This is my new key";

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* add and activate a new key */
	keyid = 0xFFFF;
	keylen = sizeof(*keytext);
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "was unable to add key";
	}
	result = sctp_set_active_key(fd, 0, keyid);
	if (result < 0) {
		close(fd);
		return "was unable to set active key";
	}

	/* delete the key */
	result = sctp_set_delete_key(fd, 0, keyid);
	if (result >= 0) {
		close(fd);
		return "was able to delete an active key";
	}
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE delkey/sso_newact_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you cannot delete a newly added keynumber that has been
 * TEST-DESCR: made active.
 */
DEFINE_APITEST(delkey, sso_newact_1_M)
{
	int fd, result;
	uint16_t keyid, keylen;
	char *keytext = "This is my new key";

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* add and activate a new key */
	keyid = 1;
	keylen = sizeof(*keytext);
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "was unable to add key";
	}
	result = sctp_set_active_key(fd, 0, keyid);
	if (result < 0) {
		close(fd);
		return "was unable to set active key";
	}

	/* delete the key */
	result = sctp_set_delete_key(fd, 0, keyid);
	if (result >= 0) {
		close(fd);
		return "was able to delete an active key";
	}
	close(fd);
	return NULL;
}

/*
 * TEST-TITLE delkey/sso_zero_1_1
 * TEST-DESCR: Validates on a 1-1 model socket that
 * TEST-DESCR: you can delete the default endpoint keynumber 0 after a
 * TEST-DESCR: new keynumber that has been added to the endpoint.
 * TEST-DESCR: Note this tries to delete the deleted keynumber
 * TEST-DESCR: to make sure the delete actually occurred.
 */
DEFINE_APITEST(delkey, sso_zero_1_1)
{
	int fd, result;
	uint16_t keyid, keylen;
	char *keytext = "This is my new key";

	fd = sctp_one2one(0, 0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* add and activate a new key */
	keyid = 1;
	keylen = sizeof(*keytext);
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "was unable to add key";
	}
	result = sctp_set_active_key(fd, 0, keyid);
	if (result < 0) {
		close(fd);
		return "was unable to set active key";
	}

	/* delete default key 0 */
	keyid = 0;
	result = sctp_set_delete_key(fd, 0, keyid);
	if (result < 0) {
		close(fd);
		return "was unable to delete key";
	}
	/* delete again to make sure it's really gone */
	result = sctp_set_delete_key(fd, 0, keyid);
	if (result >= 0) {
		close(fd);
		return "was able to re-delete key";
	}

	close(fd);
	return NULL;
}

/*
 * TEST-TITLE delkey/sso_zero_1_M
 * TEST-DESCR: Validates on a 1-many model socket that
 * TEST-DESCR: you can delete the default endpoint keynumber 0 after a
 * TEST-DESCR: new keynumber that has been added to the endpoint.
 * TEST-DESCR: Note this tries to delete the deleted keynumber
 * TEST-DESCR: to make sure the delete actually occurred.
 */
DEFINE_APITEST(delkey, sso_zero_1_M)
{
	int fd, result;
	uint16_t keyid, keylen;
	char *keytext = "This is my new key";

	fd = sctp_one2many(0, 1);
	if (fd < 0) {
		return (strerror(errno));
	}
	/* add and activate a new key */
	keyid = 1;
	keylen = sizeof(*keytext);
	result = sctp_set_auth_key(fd, 0, keyid, keylen, (uint8_t *)keytext);
	if (result < 0) {
		close(fd);
		return "was unable to add key";
	}
	result = sctp_set_active_key(fd, 0, keyid);
	if (result < 0) {
		close(fd);
		return "was unable to set active key";
	}

	/* delete default key 0 */
	keyid = 0;
	result = sctp_set_delete_key(fd, 0, keyid);
	if (result < 0) {
		close(fd);
		return "was unable to delete key";
	}
	/* delete again to make sure it's really gone */
	result = sctp_set_delete_key(fd, 0, keyid);
	if (result >= 0) {
		close(fd);
		return "was able to re-delete key";
	}
	close(fd);
	return NULL;
}

#ifndef SCTP_ASCONF
#define SCTP_ASCONF	0xC1
#endif

#ifndef SCTP_ASCONF_ACK
#define SCTP_ASCONF_ACK	0x80
#endif
/*
 * TEST-TITLE read/auth_p_chklist
 * TEST-DESCR: Setup an association on a 1-M socket
 * TEST-DESCR: and get the peer authentication chunk lists. Validate
 * TEST-DESCR: that asconf and asconf-ack are in the list. Note
 * TEST-DESCR: that this test will fail if the peer does not support
 * TEST-DESCR: the add-ip extension.
 */
DEFINE_APITEST(read, auth_p_chklist)
{
	int fds[2], result, i, j;
	sctp_assoc_t ids[2];
	uint8_t asconf=0, asconf_ack=0;
	uint8_t buffer[260];
	struct sctp_authchunks *auth;
	socklen_t len;
	int cnt = 0;

	fds[0] = fds[1] = -1;
	result = sctp_socketpair_1tom(fds, ids, 1);
	if(result < 0) {
		return(strerror(errno));
	}
 try_again:
	memset(buffer, 0, sizeof(buffer));
	auth = (struct sctp_authchunks *)buffer;
	auth->gauth_assoc_id = ids[0];
	len = sizeof(buffer);
	result = getsockopt(fds[0], IPPROTO_SCTP, SCTP_PEER_AUTH_CHUNKS,
			    auth, &len);
	if (result < 0) {
		close(fds[0]);
		close(fds[1]);
		return(strerror(errno));
	}
	j = len - sizeof(sctp_assoc_t);
	if(j > 260)
		j = 256;

	for (i=0; i<j; i++) {
		if(auth->gauth_chunks[i] == SCTP_ASCONF) {
			asconf = 1;
		}
		if(auth->gauth_chunks[i] == SCTP_ASCONF_ACK) {
			asconf_ack = 1;
		}
	}
	if ((asconf_ack == 0) || (asconf == 0)) {
		if (cnt < 1) {
			cnt++;
			sctp_delay(SCTP_SLEEP_MS);
			goto try_again;
		}
		close(fds[0]);
		close(fds[1]);
		return "Did not see ASCONF/ASCONF-ACK in list";
	}
	close(fds[0]);
	close(fds[1]);
	return NULL;
}

/*
 * TEST-TITLE read/auth_p_chklist
 * TEST-DESCR: Setup an association on a 1-M socket
 * TEST-DESCR: and get the local authentication chunk lists. Validate
 * TEST-DESCR: that asconf and asconf-ack are in the list.
 */
DEFINE_APITEST(read, auth_l_chklist)
{
	int fds[2], result, i,j;
	sctp_assoc_t ids[2];
	uint8_t buffer[260];
	uint8_t asconf=0, asconf_ack=0;
	struct sctp_authchunks *auth;
	socklen_t len;

	fds[0] = fds[1] = -1;
	result = sctp_socketpair_1tom(fds, ids, 1);
	if(result < 0) {
		return(strerror(errno));
	}
	memset(buffer, 0, sizeof(buffer));
	auth = (struct sctp_authchunks *)buffer;
	auth->gauth_assoc_id = ids[0];
	len = sizeof(buffer);
	result = getsockopt(fds[0], IPPROTO_SCTP, SCTP_LOCAL_AUTH_CHUNKS,
			    auth, &len);
	if (result < 0) {
		close(fds[0]);
		close(fds[1]);
		return(strerror(errno));
	}
	close(fds[0]);
	close(fds[1]);
	j = len - sizeof(sctp_assoc_t);
	if(j > 260)
		j = 256;

	for (i=0; i<j; i++) {
		if(auth->gauth_chunks[i] == SCTP_ASCONF) {
			asconf = 1;
		}
		if(auth->gauth_chunks[i] == SCTP_ASCONF_ACK) {
			asconf_ack = 1;
		}
	}
	if ((asconf_ack == 0) || (asconf == 0)) {
		return "Did not see ASCONF/ASCONF-ACK in list";
	}
	return NULL;
}

/********************************************************
 *
 * SCTP_ASSOCLIST tests
 *
 ********************************************************/

/*
 * TEST-TITLE assoclist/gso_numbers_zero
 * TEST-DESCR: Open a 1-1 socket and validate that
 * TEST-DESCR: it has no associations.
 */
DEFINE_APITEST(assoclist, gso_numbers_zero)
{
	int fd, result;

	//if ((fd = socket(AF_INET, SOCK_STREAM, IPPROTO_SCTP)) < 0)
	if ((fd = socket(AF_INET, SOCK_SEQPACKET, IPPROTO_SCTP)) < 0)
		return strerror(errno);

	result = sctp_get_number_of_associations(fd);

	close(fd);

	if (result == 0)
		return NULL;
	else
		return "Wrong number of associations";
}

#define NUMBER_OF_ASSOCS 12

/*
 * TEST-TITLE assoclist/gso_numbers_pos
 * TEST-DESCR: Open a 1-M socket, and create
 * TEST-DESCR: a number of associations (using seperate fd's) to
 * TEST-DESCR: it. Validate that the number of associations
 * TEST-DESCR: returned is the number we created.
 */
DEFINE_APITEST(assoclist, gso_numbers_pos)
{
	int fd, fds[NUMBER_OF_ASSOCS], result;
	unsigned int i;

	if (sctp_socketstar(&fd, fds, NUMBER_OF_ASSOCS) < 0)
		return strerror(errno);

	sctp_delay(SCTP_SLEEP_MS);
	result = sctp_get_number_of_associations(fd);

	close(fd);
	for (i = 0; i < NUMBER_OF_ASSOCS; i++)
		close(fds[i]);

	if (result == NUMBER_OF_ASSOCS)
		return NULL;
	else
		return "Wrong number of associations";
}

/*
 * TEST-TITLE assoclist/gso_ids_no_assoc
 * TEST-DESCR: Open a 1-1 socket, and get the
 * TEST-DESCR: assocation list. Verify that no
 * TEST-DESCR: association id's are returned.
 */
DEFINE_APITEST(assoclist, gso_ids_no_assoc)
{
	int fd, result;
	sctp_assoc_t id;

	//if ((fd = socket(AF_INET, SOCK_STREAM, IPPROTO_SCTP)) < 0)
	if ((fd = socket(AF_INET, SOCK_SEQPACKET, IPPROTO_SCTP)) < 0)
		return strerror(errno);

	if (sctp_get_number_of_associations(fd) != 0) {
		close(fd);
		return "Wrong number of identifiers";
	}
#ifdef SCTP_GET_ASSOC_ID_LIST
	result = sctp_get_association_identifiers(fd, &id, 1);
	close(fd);
	if (result == 0)
		return NULL;
	else
		return "Wrong number of identifiers";
#else
	close(fd);
	return NULL;
#endif
}

/*
 * TEST-TITLE assoclist/gso_ids_buf_fit
 * TEST-DESCR: Open a 1-M socket and create a
 * TEST-DESCR: number of assocaitions connected to
 * TEST-DESCR: the 1-M socket. Get the association
 * TEST-DESCR: identifiers and validate that they are not
 * TEST-DESCR: duplicated.
 */
DEFINE_APITEST(assoclist, gso_ids_buf_fit)
{
	int fd, fds[NUMBER_OF_ASSOCS], result;
	sctp_assoc_t ids[NUMBER_OF_ASSOCS];
	unsigned int i, j;

	if (sctp_socketstar(&fd, fds, NUMBER_OF_ASSOCS) < 0)
		return strerror(errno);
	sctp_delay(SCTP_SLEEP_MS);

	if (sctp_get_number_of_associations(fd) != NUMBER_OF_ASSOCS) {
		close(fd);
		for (i = 0; i < NUMBER_OF_ASSOCS; i++)
			close(fds[i]);
		return "Wrong number of associations";
	}

#ifdef SCTP_GET_ASSOC_ID_LIST
	result = sctp_get_association_identifiers(fd, ids, NUMBER_OF_ASSOCS);
#endif

	close(fd);
	for (i = 0; i < NUMBER_OF_ASSOCS; i++)
		close(fds[i]);

#ifdef SCTP_GET_ASSOC_ID_LIST
	if (result == NUMBER_OF_ASSOCS) {
		for (i = 0; i < NUMBER_OF_ASSOCS; i++)
			for (j = 0; j < NUMBER_OF_ASSOCS; j++)
				if ((i != j) && (ids[i] == ids[j]))
					return "Same identifier for different associations";
		return NULL;
	} else
		return "Wrong number of identifiers";
#else
	return NULL;
#endif
}

/*
 * TEST-TITLE assoclist/gso_ids_buf_large
 * TEST-DESCR: Create a number of associations connected
 * TEST-DESCR: to our 1-M socket. Get the number of
 * TEST-DESCR: assocations passing in a larger buffer
 * TEST-DESCR: then needed i.e. 1 extra id. Then validate
 * TEST-DESCR: that no duplicate association id is given.
 */
DEFINE_APITEST(assoclist, gso_ids_buf_large)
{
	int fd, fds[NUMBER_OF_ASSOCS + 1], result;
	sctp_assoc_t ids[NUMBER_OF_ASSOCS];
	unsigned int i, j;

	if (sctp_socketstar(&fd, fds, NUMBER_OF_ASSOCS) < 0)
		return strerror(errno);
	sctp_delay(SCTP_SLEEP_MS);

	if (sctp_get_number_of_associations(fd) != NUMBER_OF_ASSOCS) {
		close(fd);
		for (i = 0; i < NUMBER_OF_ASSOCS; i++)
			close(fds[i]);
		return "Wrong number of associations";
	}
#ifdef SCTP_GET_ASSOC_ID_LIST
	result = sctp_get_association_identifiers(fd, ids, NUMBER_OF_ASSOCS + 1);
#endif
	close(fd);
	for (i = 0; i < NUMBER_OF_ASSOCS; i++)
		close(fds[i]);

#ifdef SCTP_GET_ASSOC_ID_LIST
	if (result == NUMBER_OF_ASSOCS) {
		for (i = 0; i < NUMBER_OF_ASSOCS; i++)
			for (j = 0; j < NUMBER_OF_ASSOCS; j++)
				if ((i != j) && (ids[i] == ids[j]))
					return "Same identifier for different associations";
		return NULL;
	} else
		return "Wrong number of identifiers";
#else
	return NULL;
#endif
}

/*
 * TEST-TITLE assoclist/gso_ids_buf_small
 * TEST-DESCR: Create a number of associations
 * TEST-DESCR: on a 1-M socket, then request the
 * TEST-DESCR: association id's but give too small
 * TEST-DESCR: of a list. Validate that we can retrieve
 * TEST-DESCR: the list, even though we do not get all
 * TEST-DESCR: of them.
 */
DEFINE_APITEST(assoclist, gso_ids_buf_small)
{
	int fd, fds[NUMBER_OF_ASSOCS], result;
	sctp_assoc_t ids[NUMBER_OF_ASSOCS];
	unsigned int i;

	if (sctp_socketstar(&fd, fds, NUMBER_OF_ASSOCS) < 0)
		return strerror(errno);
	sctp_delay(SCTP_SLEEP_MS);

	if (sctp_get_number_of_associations(fd) != NUMBER_OF_ASSOCS) {
		close(fd);
		for (i = 0; i < NUMBER_OF_ASSOCS; i++)
			close(fds[i]);
		return strerror(errno);
	}
#ifdef SCTP_GET_ASSOC_ID_LIST
	result = sctp_get_association_identifiers(fd, ids, NUMBER_OF_ASSOCS - 1);
#endif
	close(fd);
	for (i = 0; i < NUMBER_OF_ASSOCS; i++)
		close(fds[i]);
#ifdef SCTP_GET_ASSOC_ID_LIST
	if (result > 0)
		return "getsockopt successful";
	else
#endif
		return NULL;
}

