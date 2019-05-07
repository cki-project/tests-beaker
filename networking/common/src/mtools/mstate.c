/*
 * mstate.c
 * This is multicast state change program. we can trigger multicast state report
 * by modify control file and send a signal. e.g. kill -SIGUSR1 `pgrep mstate`
 *
 * mcmd.txt
 * It only allow one line is described at a time at once.
 * syntax
 * <socket id> <device id> <multiucast address> <mode> <number of source> <source address ..>

 * e.g.)
 * S1 eth0 239.1.1.1 INCLUDE 1 192.168.2.1
 * S1 eth0 239.1.1.1 INCLUDE 2 192.168.2.1 192.168.2.2
 * S1 eth0 239.1.1.1 INCLUDE 0
 * S1 eth0 ff05::101 EXCLUDE 1 2000::1
 * S1 eth0 ff05::101 EXCLUDE 2 2000::1 2000::2
 * S1 eth0 ff05::101 EXCLUDE 0
 *
 * more state details, please see select_si() function
 * */

#include <sys/types.h>  /* socket, bind, setsockopt, getaddrinfo, freeaddrinfo */
#include <sys/socket.h> /* socket, bind, setsockopt, getaddrinfo, freeaddrinfo */
#include <netinet/in.h>
#include <net/if.h>     /* if_nametoindex */
#include <netdb.h>      /* getaddrinfo, freeaddrinfo */
#include <unistd.h>     /* close */
#include <ctype.h>      /* isspace */
#include <errno.h>      /* errno */
#include <stdlib.h>     /* atoi, exit */
#include <stdio.h>      /* printf, fopen, fclose, fgetc */
#include <string.h>     /* memset, memcpy, strcmp, strcpy, strerror */
#include <pthread.h>    /* sigwait */
#include <signal.h>     /* sigwait, sigemptyset, sigaddset, sigprocmask */
#include <arpa/inet.h>	/* inet_ntop */

/*****************************************************************************
  configuration

  conf_display display level
  ------------ ------------
  0 displays nothing
  1 displays any MLDv2 function call
  2 displays any function call
 *****************************************************************************/
int conf_display = 1;

/*
   conf_exec execution opportunity
   --------- ---------------------
   0 executes at a fixed interval (for debug)
   1 executes with a wakeup signal (for TAHI conformance test tool)
   */
int conf_exec = 1;

/* command file path */
char command_filepath[64]   = "./mcmd.txt";

#define WAKEUP_SIGNAL       SIGUSR1
#define WAKEUP_SIGNAL_NAME  "SIGUSR1"

/*****************************************************************************/
/* table */
/*****************************************************************************/
#define SOCKET_NUM  10
#define SRCLST_NUM  100
#define ADDR_LEN    40

/* struct address entry */
struct addr_entry {
	char addr_str[ADDR_LEN];
};
typedef struct addr_entry addr_entry_t;

/* struct command table */
struct command_table {
	char            sock_str[8];
	char            fmode_str[8];
	char            num_str[8];
	char            if_str[IF_NAMESIZE];
	addr_entry_t    mcast_entry;
	addr_entry_t    msrc_list[SRCLST_NUM];
};

/* struct socket entry */
struct socket_entry {
	char sock_str[8];
	int  sockfd;
	int  mld_exist; /* 0: nothing, 1: exist */
};
typedef struct socket_entry socket_entry_t;

/* struct socket table */
struct socket_table {
	socket_entry_t entry[SOCKET_NUM];
};

/* tables */
struct command_table command_st;
struct socket_table socket_st;
int socket_no = -1;

/*****************************************************************************/
/* proto type */
/*****************************************************************************/
/* original filter mode */
#define FMODE_INCLUDE 1
#define FMODE_EXCLUDE 2

/* original id for service intareface */
#define SI_NOSUPPORT           -1
#define SI_NEEDLESS             0
#define SI_SETSOCKOPT_GROUP     1
#define SI_SETSOCKOPT_SOURCE    2
#define SI_SETSOCKOPT_MSFILTER 10
#define SI_SETSOURCEFILTER     20

int read_command(char *);
int get_socket(int, char *);
int mcast_listen(int, int, addr_entry_t *, int, int, addr_entry_t *);
int select_si(int, int, int);
void term_func(void);
int getaddrfamily(const char *);

/*****************************************************************************/
/* main */
/*****************************************************************************/
int main (int argc, char **argv)
{
	int rc;
	sigset_t sig_set;
	int sig_no;
	int ifd;
	int fmode;
	int src_num;
	int sockfd, family;

	/* initial */
	memset(&command_st, 0x00, sizeof(command_st));
	memset(&socket_st, 0x00, sizeof(socket_st));

	if (conf_exec == 1) {
		/* set signal */
		if (conf_display>1) printf("call sigemptyset(&sig_set)\n");
		sigemptyset(&sig_set);
		if (conf_display>1) printf("call sigaddset(&sig_set, %s(%d))\n", WAKEUP_SIGNAL_NAME, WAKEUP_SIGNAL);
		rc = sigaddset(&sig_set, WAKEUP_SIGNAL);
		if (rc != 0) {
			printf("return %d sigaddset() w/ errno %d, %s\n", rc, errno, strerror(errno));
			return (-1);
		}
		if (conf_display>1) printf("call sigprocmask(SIG_BLOCK(%d), &sig_set, NULL)\n", SIG_BLOCK);
		rc = sigprocmask(SIG_BLOCK, &sig_set, NULL);
		if (rc != 0) {
			printf("return %d sigaddset() w/ errno %d, %s\n", rc, errno, strerror(errno));
			return (-1);
		}
	}

	/* loop */
	while (1) {

		if (conf_exec == 1) {
			/* wait signal */
			if (conf_display>1) printf("call sigwait(&sig_set, &sig_no)\n");
			sigwait(&sig_set, &sig_no);
			if (sig_no != WAKEUP_SIGNAL) {
				continue;
			}
		}

		/* read command */
		rc = read_command(command_filepath);
		if (rc != 0) {
			break;
		}

		/* get & find socket */
		if ((family = getaddrfamily((char *)&command_st.mcast_entry)) == -1){
			printf("Could not get group addr family\n");
			break;
		}
		sockfd = get_socket(family, command_st.sock_str);
		if (sockfd < 0) {
			printf("Could not get sockfd\n");
			break;
		}

		/* find interface */
		if (conf_display>1) printf("call if_nametoindex(%s)\n", command_st.if_str);
		ifd = if_nametoindex(command_st.if_str);
		if (ifd == 0) {
			printf("return %d if_nametoindex() w/ errno %d, %s\n", ifd, errno, strerror(errno));
			break;
		}

		/* filter mode */
		if (strcmp(command_st.fmode_str, "INCLUDE") == 0) {
			fmode = FMODE_INCLUDE;
		}
		else if (strcmp(command_st.fmode_str, "EXCLUDE") == 0) {
			fmode = FMODE_EXCLUDE;
		}
		else {
			printf("syntax error: filter mode %s\n", command_st.fmode_str);
			break;
		}

		/* number of sources */
		if (conf_display>1) printf("call atoi(%s)\n", command_st.num_str);
		src_num = atoi(command_st.num_str);

		/****************************************/
		/* common service interface in RFC 3810 */
		/****************************************/
		rc = mcast_listen(sockfd, ifd, &command_st.mcast_entry,
				fmode, src_num, command_st.msrc_list);
		if (rc != 0) {
			printf("return %d mcast_listen() w/ errno %d, %s\n", rc, errno, strerror(errno));
			break;
		}

		if (conf_exec == 0) {
			/* sleep for a fixed interval */
			if (conf_display>1) printf("call sleep(10)\n");
			sleep(10);
		}
	}

	/* term */
	term_func();
	exit(0);
}

/*****************************************************************************/
/* read command */
/*****************************************************************************/
int read_command(char *filepath) {
	int id=0, i=0;
	FILE *fp;
	int c;

	/* clear command table */
	memset(&command_st, 0x00, sizeof(command_st));

	/* open command file */
	if (conf_display>1) printf("call fopen(%s, r)\n", filepath);
	fp = fopen(filepath, "r");
	if (fp == NULL) {
		printf("fopen() w/ errno %d, %s\n", errno, strerror(errno));
		return (-1);
	}

	/* read & strage command */
	while (1) {
		c = fgetc(fp);
		if (c == EOF) {
			break;
		}
		if (isspace(c)) {
			if (i != 0) {
				/* next word */
				id ++;
				i = 0;
			}
			continue;
		}
		switch (id) {
		case 0: /* socket */
			command_st.sock_str[i] = (char)c;
			break;
		case 1: /* interface */
			command_st.if_str[i] = (char)c;
			break;
		case 2: /* multicast address */
			command_st.mcast_entry.addr_str[i] = (char)c;
			break;
		case 3: /* filter mode */
			command_st.fmode_str[i] = (char)c;
			break;
		case 4: /* number of sources */
			command_st.num_str[i] = (char)c;
			break;
		default: /* source */
			command_st.msrc_list[id - 5].addr_str[i] = (char)c;
			break;
		}
		i++;
	}

	/* close file */
	if (conf_display>1) printf("call fclose(fp)\n");
	fclose(fp);

	if (id < 4) {
		printf("syntax error: few arguments %d < 4\n", id);
		return (-1);
	}

	return (0);
}

/*****************************************************************************/
/* get socket */
/*****************************************************************************/
int get_socket(int family, char *sock_str) {
	int i;
	int n = -1;
	int sockfd;

	/* serch */
	for (i=0; i<SOCKET_NUM; i++) {
		/* verify ID */
		if (strcmp(sock_str, socket_st.entry[i].sock_str) == 0) {
			/* Bingo! Already exist */
			/* current number in socket_st */
			socket_no = i;
			return (socket_st.entry[i].sockfd);
		}
		/* prepare emtpy entry */
		else if ((n == -1) && socket_st.entry[i].sockfd == 0) {
			break;
		}
	}

	/* get empty entry */
	if (i == SOCKET_NUM) {
		printf("error: socket table is an overflow, %d entry\n", SOCKET_NUM);
		return (-1);
	}

	/* create socket */
	if (conf_display>1) printf("call socket(PF_INET6, SOCK_DGRAM, IPPROTO_UDP)\n");
	sockfd = socket(family, SOCK_DGRAM, IPPROTO_UDP);
	if (sockfd < 0) {
		printf("return %d socket() w/ errno %d, %s\n", sockfd, errno, strerror(errno));
		return (-1);
	}

	/* set new entry */
	strcpy(socket_st.entry[i].sock_str, sock_str);
	socket_st.entry[i].sockfd = sockfd;
	socket_st.entry[i].mld_exist = 0;
	/* current number in socket_st */
	socket_no = i;

	return (sockfd);
}

int mcast_listen(int sockfd, int ifd, addr_entry_t *mcast_entry,
		int fmode, int src_num, addr_entry_t *msrc_list)
{
	struct sockaddr_storage group_addr, src_addr_list[SRCLST_NUM];
	struct addrinfo hints;
	struct addrinfo *res;
	int i, rc, si_id;
	int af, level;
	int optname;
	char *toptname;
	void *optval;
	socklen_t optlen;
	struct group_req mcast_req;
	struct group_source_req mcast_src_req;
	struct group_filter * mcast_filter_req = (struct group_filter *)malloc(GROUP_FILTER_SIZE(SRCLST_NUM));

	memset(&group_addr, 0, sizeof(struct sockaddr_storage));
	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_flags = AI_NUMERICHOST;
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = 0;
	hints.ai_protocol = 0;

	memset(src_addr_list, 0, sizeof(src_addr_list));
	if (conf_display>1)
		printf("call getaddrinfo(%s, NULL, &hints, &res)\n",
				mcast_entry->addr_str);
	rc = getaddrinfo(mcast_entry->addr_str, NULL, &hints, &res);
	if (rc != 0) {
		printf("return %d getaddrinfo() w/ errno %d, %s\n",
				rc, errno, gai_strerror(errno));
		free(mcast_filter_req);
		return (-1);
	}

	af = res->ai_family;
	level = af == AF_INET ? IPPROTO_IP : IPPROTO_IPV6;
	memcpy(&group_addr, res->ai_addr, res->ai_addrlen);
	freeaddrinfo(res);


	/* multicast source list */
	for (i=0; i<src_num; i++) {
		if (conf_display>1)
			printf("call getaddrinfo(%s, NULL, &hints, &res)\n",
				msrc_list[i].addr_str);
		rc = getaddrinfo(msrc_list[i].addr_str, NULL, &hints, &res);
		if (rc != 0) {
			printf("return %d getaddrinfo() w/ errno %d, %s\n",
					rc, errno, gai_strerror(errno));
			free(mcast_filter_req);
			return (-1);
		}
		memcpy(&src_addr_list[i], res->ai_addr, res->ai_addrlen);
		freeaddrinfo(res);
	}

	/*********************************************************************/
	/* service interface depend on implementation */
	/*********************************************************************/
	si_id = select_si(fmode, src_num, socket_st.entry[socket_no].mld_exist);
	switch (si_id) {
	case SI_NEEDLESS:
		printf("INFO: Needless.\n");
		break;

	case SI_SETSOCKOPT_GROUP:
		/* option */
		if (fmode == FMODE_INCLUDE) {
			optname = MCAST_LEAVE_GROUP;
			toptname = "MCAST_LEAVE_GROUP";
		} else { /* FMODE_EXCLUDE */
			optname = MCAST_JOIN_GROUP;
			toptname = "MCAST_JOIN_GROUP";
		}

		/* option data */
		optval = &mcast_req;

		/* interface index */
		mcast_req.gr_interface = ifd;
		/* multicast address */
		memcpy(&mcast_req.gr_group, &group_addr, sizeof(struct sockaddr_storage));

		/* option data length */
		optlen = sizeof(struct group_req);

		if (conf_display>0)
			printf("call setsockopt(%d, IPPROTO_IPV6(%d), %s(%d), optval, %d)\n",
				sockfd, level, toptname, optname, optlen);
		rc = setsockopt(sockfd, level, optname, optval, optlen);
		if (rc != 0) {
			printf("return %d setsockopt() w/ errno %d, %s\n", rc, errno, strerror(errno));
			if ((errno != EADDRINUSE) && (errno != EADDRNOTAVAIL)) {
				free(mcast_filter_req);
				return (-1);
			}
		}

		/* current number in socket_st */
		if (fmode == FMODE_INCLUDE) {
			socket_st.entry[socket_no].mld_exist = 0;
		}
		else { /* FMODE_EXCLUDE */
			socket_st.entry[socket_no].mld_exist = 1;
		}
		break;

	case SI_SETSOCKOPT_SOURCE:
		/* option */
		if (fmode == FMODE_INCLUDE) {
			optname = MCAST_JOIN_SOURCE_GROUP;
			toptname = "MCAST_JOIN_SOURCE_GROUP";
		}
		else { /* FMODE_EXCLUDE */
			optname = MCAST_BLOCK_SOURCE;
			toptname = "MCAST_BLOCK_SOURCE";
		}

		/* option data */
		optval = &mcast_src_req;
		mcast_src_req.gsr_interface = ifd;
		memcpy(&mcast_src_req.gsr_group, &group_addr, sizeof(struct sockaddr_storage));
		memcpy(&mcast_src_req.gsr_source, &src_addr_list[0], sizeof(struct sockaddr_storage));

		/* option data length */
		optlen = sizeof(struct group_source_req);

		if (conf_display>0)
			printf("call setsockopt(%d, IPPROTO_IPV6(%d), %s(%d), optval, %d)\n",
				sockfd, level, toptname, optname, optlen);
		rc = setsockopt(sockfd, level, optname, optval, optlen);
		if (rc != 0) {
			printf("return %d setsockopt() w/ errno %d, %s\n", rc, errno, strerror(errno));
			if ((errno != EADDRINUSE) && (errno != EADDRNOTAVAIL)) {
				free(mcast_filter_req);
				return (-1);
			}
		}

		/* current number in socket_st */
		socket_st.entry[socket_no].mld_exist = 1;
		break;

	case SI_SETSOCKOPT_MSFILTER:
		/* option */
		optname = MCAST_MSFILTER;
		toptname = "MCAST_MSFILTER";

		/* option data */
		optval = mcast_filter_req;

		/* interface index */
		mcast_filter_req->gf_interface = ifd;
		/* multicast address */
		memcpy(&mcast_filter_req->gf_group, &group_addr, sizeof(struct sockaddr_storage));
		/* filter mode */
		if (fmode == FMODE_INCLUDE) {
			mcast_filter_req->gf_fmode = MCAST_INCLUDE;
		}
		else { /* FMODE_EXCLUDE */
			mcast_filter_req->gf_fmode = MCAST_EXCLUDE;
		}
		/* number of sources */
		mcast_filter_req->gf_numsrc = src_num;
		/* source addresses */
		memcpy(mcast_filter_req->gf_slist, src_addr_list, src_num * sizeof(struct sockaddr_storage));

		/* option data length */
		optlen = GROUP_FILTER_SIZE(src_num);

		if (conf_display>0)
			printf("call setsockopt(%d, IPPROTO_IPV6(%d), %s(%d), optval, %d)\n",
				sockfd, level, toptname, optname, optlen);
		rc = setsockopt(sockfd, level, optname, optval, optlen);
		if (rc != 0) {
			printf("return %d setsockopt() w/ errno %d, %s\n", rc, errno, strerror(errno));
			if ((errno != EADDRINUSE) && (errno != EADDRNOTAVAIL)) {
				free(mcast_filter_req);
				return (-1);
			}
		}
		break;

	default:
		printf("INFO: NO SUPPORT.\n");
		break;
	}

	free(mcast_filter_req);
	return 0;
}


/*****************************************************************************/
/* Select Function */
/* current exist means whether we have a group(not source) on this socket */
/*
   OS       filter   num of current
            mode     source exist   function              memo
   -------- -------- ------ ------- --------              ----
   Linux    INCLUDE       0 nothing			NEEDLESS
            INCLUDE       0 exist   setsockopt() with MCAST_LEAVE_GROUP == MCAST_MSFILTER, INCLUDE
            INCLUDE       1 nothing setsockopt() with MCAST_JOIN_SOURCE_GROUP
            INCLUDE       1 exist   setsockopt() with MCAST_MSFILTER, INCLUDE
            INCLUDE      >1 nothing			NO SUPPORT
            INCLUDE      >1 exist   setsockopt() with MCAST_MSFILTER, INCLUDE
            EXCLUDE       0 nothing setsockopt() with IPV6_JOIN_GROUP
            EXCLUDE       0 exist   setsockopt() with MCAST_MSFILTER, EXCLUDE
            EXCLUDE      >0 nothing			NO SUPPORT
            EXCLUDE      >0 exist   setsockopt() with MCAST_MSFILTER, EXCLUDE

*/
/*****************************************************************************/
int select_si(int fmode, int srcnum, int exist) {
	int si_id = SI_NOSUPPORT;

	if (fmode == FMODE_INCLUDE) {
		if (srcnum == 0) {
			if (exist == 0)
				si_id = SI_NEEDLESS;
			else
				si_id = SI_SETSOCKOPT_GROUP;
		} else if (srcnum == 1) {
			if (exist == 0)
				si_id = SI_SETSOCKOPT_SOURCE;
			else
				si_id = SI_SETSOCKOPT_MSFILTER;
		}
		else {
			if (exist == 0)
				si_id = SI_NOSUPPORT;
			else
				si_id = SI_SETSOCKOPT_MSFILTER;
		}
	}
	else { /* (fmode == FMODE_EXCLUDE) */
		if (srcnum == 0) {
			if (exist == 0)
				si_id = SI_SETSOCKOPT_GROUP;
			else
				si_id = SI_SETSOCKOPT_MSFILTER;
		} else {
			if (exist == 0)
				si_id = SI_NOSUPPORT;
			else
				si_id = SI_SETSOCKOPT_MSFILTER;
		}
	}
	return (si_id);
}

/*****************************************************************************/
/* term func */
/*****************************************************************************/
void term_func (void) {
	int i;

	/* close socket */
	for (i=0; i<SOCKET_NUM; i++) {
		if (socket_st.entry[i].sockfd != 0) {
			if (conf_display>1) printf("call close(%d)\n", socket_st.entry[i].sockfd);
			close(socket_st.entry[i].sockfd);
			memset(&socket_st.entry[i], 0x00, sizeof(socket_entry_t));
		}
	}
}

int getaddrfamily(const char *addr)
{
	struct addrinfo hint, *info =0;
	memset(&hint, 0, sizeof(hint));
	hint.ai_family = AF_UNSPEC;
	hint.ai_flags = AI_NUMERICHOST;
	int ret = getaddrinfo(addr, 0, &hint, &info);
	if (ret)
		return -1;
	int result = info->ai_family;
	freeaddrinfo(info);
	return result;
}


