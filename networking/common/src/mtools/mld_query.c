#include	<stdio.h>
#include	<stdlib.h>
#include	<string.h>
#include	<unistd.h>
#include	<error.h>
#include	<netdb.h>
#include	<getopt.h>
#include	<arpa/inet.h>
#include	<sys/types.h>
#include	<sys/socket.h>
#include	<netinet/in.h>
#include	<netinet/ip6.h>
#include	<netinet/icmp6.h>

#define	BUFFSIZE 4096
#define HOPOPT_SPACE(len)	((len + 1) << 3)

/*get the definition of mldv2_query from include/net
  in linux kernel code */
struct mldv2_hdr
{
	struct icmp6_hdr mld_icmp6_hdr;
	struct in6_addr  mld_addr;
	uint8_t mld_flags;
	uint8_t mld_qqic;
	uint16_t src_num;
	struct in6_addr mld2_srcs[0];
};

void usage(char *name)
{
	printf("%s: [-v] [-h]\n", name);
	printf("\t -v: mld version, 1 or 2, default is 2\n");
	printf("\t -i: interface\n");
	printf("\t -n: no route allert\n");
	printf("\t -t: query times, default is 1\n");
	printf("\t -h: help message\n");
	printf("\t -g: group address\n");
	printf("\t -s: src address list, only support v2\n");
	//add a new parameter response time
	printf("\t -r: response time\n");
	printf("\n");
	printf("\t e.g.: %s -v 1 -i em1\n", name);
	printf("\t e.g.: %s -v 2 -i em1 -g ff0e::1 -s '2000::1 2000::2'\n", name);
	exit(0);

}

int
main(int argc, char * argv[])
{
	int opt;
	int len;
	int sockfd;
	int version = 2;	//use mldv2 by default
	int no_alert = 0;
	int times = 1;
	//define a new parameter 
	int response = 10000;   //use 10s by default
	char sendbuf[BUFFSIZE];
	char *interface;
	char *dst = "ff02::1";
	struct mldv2_hdr *mld_hdr;
	struct sockaddr_in6 whereto;
	char hhopt[HOPOPT_SPACE(1)];
	int optlen;
	uint16_t num_src = 0;
	char multi_src[256][40] = {""};
	char src_list[1024] = {""};
	char *group_addr = "0000:0000:0000:0000:0000:0000:0000:0000";
	struct in6_addr src_addr_list[256];

	/* Get options */
	while ((opt = getopt(argc, argv, "v:i:d:nt:g:s:hr:")) != -1) {
		switch(opt) {
		case 'v':
			if (atoi(optarg) == 1)	// only accept version = 1
				version = 1;
			break;
		case 'i':
			interface = optarg;
			break;
		case 'd':
			dst = (char *)&optarg;
			break;
		case  'n':
			no_alert = 1;
			break;
		case  't':
			times = atoi(optarg);
			break;
		case  'g':
			group_addr = optarg;
			break;
		case 's':
			strcpy(src_list, optarg);
			break;
		case  'h':
			usage(argv[0]);
			break;
		case  'r':
			response = atoi(optarg);
			break;
		default:
			break;
		}
	}

	if ( (sockfd = socket(PF_INET6, SOCK_RAW, IPPROTO_ICMPV6)) < 0) {
		perror("socket error ");
		exit(1);
	}

	/* init hop by hop with router alert*/
	optlen = sizeof(hhopt);
	memset(hhopt, 0, optlen);
	struct ip6_hbh hbh;
	struct ip6_opt_router alert;
	struct ip6_opt padn;
	hbh.ip6h_nxt = 58;
	hbh.ip6h_len = 0;
	alert.ip6or_type = IP6OPT_ROUTER_ALERT;
	alert.ip6or_len = sizeof(alert.ip6or_value);
	*((short *)&alert.ip6or_value) = IP6_ALERT_MLD;
	padn.ip6o_type = IP6OPT_PADN;
	padn.ip6o_len = 0;

	*((struct ip6_hbh *)hhopt) = hbh;
	*((struct ip6_opt_router  *)(hhopt + sizeof(struct ip6_hbh))) = alert;
	*((struct ip6_opt *)(hhopt + 6)) = padn;

	if (!no_alert) {
		if (setsockopt(sockfd, IPPROTO_IPV6, IPV6_HOPOPTS,
					(void *)&hhopt, sizeof(hhopt)) == -1) {
			perror("setsockopt IPV6_ROUTER_ALERT");
			exit(1);
		}
	}

	if (interface && setsockopt(sockfd, SOL_SOCKET, SO_BINDTODEVICE,
				interface, sizeof(interface)) == -1) {
			perror("bind to interface failed");
			exit(EXIT_FAILURE);
	}

	memset(&whereto, 0, sizeof(whereto));
	whereto.sin6_family = AF_INET6;
	whereto.sin6_port = htons(IPPROTO_ICMPV6);
	if (inet_pton(AF_INET6, dst, (void *)&whereto.sin6_addr) <=0 ){
		perror("inet_pton ns error ");
		exit(1);
	}

	memset(sendbuf, 0, sizeof(sendbuf));
	mld_hdr = (struct mldv2_hdr *) sendbuf;
	mld_hdr->mld_type = MLD_LISTENER_QUERY;
	mld_hdr->mld_code = 0;
	mld_hdr->mld_cksum = 0;
	//mld_hdr->mld_maxdelay = 0x1027;		// 10000
	mld_hdr->mld_maxdelay = htons(response);
	mld_hdr->mld_reserved = 0x0;
	mld_hdr->mld_flags = 0x02;
	mld_hdr->mld_qqic = 125;
	mld_hdr->src_num = 0;


	//len = sizeof(struct mld_hdr);
	len = (version ==2) ? sizeof(struct mldv2_hdr) : sizeof(struct mld_hdr);

	if ( 1 == version )
	{
		if( 0 != strcmp(group_addr, "0000:0000:0000:0000:0000:0000:0000:0000") )
		{
			inet_pton(AF_INET6, group_addr, (void *)&(mld_hdr->mld_addr));
		}
	}
	else if ( 2 == version  )
	{
		if( 0 != strcmp(group_addr, "0000:0000:0000:0000:0000:0000:0000:0000") )
		{
			inet_pton(AF_INET6, group_addr, (void *)&(mld_hdr->mld_addr));
			if(  0 != strcmp(src_list, "") )
			{
				int tmp_i = 0;
				char *tmp_locate;
				char *tmp_src_list;
				tmp_src_list = src_list;
				while( (tmp_locate = strchr(tmp_src_list, ' ')) != NULL )
				{
					*tmp_locate = '\0';
					memcpy(multi_src[num_src], tmp_src_list, (tmp_locate - tmp_src_list));
					num_src++;
					tmp_src_list = tmp_locate + 1;
				}
				strcpy(multi_src[num_src], tmp_src_list);
				num_src++;
				mld_hdr->src_num = htons(num_src);
				for( tmp_i = 0; tmp_i < num_src; tmp_i++ )
				{
					inet_pton(AF_INET6, multi_src[tmp_i], &src_addr_list[tmp_i]);
				}
				memcpy(mld_hdr->mld2_srcs, src_addr_list, num_src * sizeof(struct in6_addr));
				/*have to add num_src of in6_addr for len*/
				len = sizeof(struct mldv2_hdr) + (num_src) * sizeof(struct in6_addr);
			}
		}
	}

	while(1) {
		if ( sendto(sockfd, sendbuf, len, 0, (const struct sockaddr *) &whereto,
					sizeof(struct sockaddr_in6)) < 0) {
			perror("sendto error ");
			exit(1);
		}

		// break directly after timeout
		if ( --times < 1)
			break;

		sleep(125);
	}

	return 0;
}
