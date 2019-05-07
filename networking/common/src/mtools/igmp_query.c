/*
 * TODO:
 * rfc3376 4.1.3. Group Address
 * The Group Address field is set to zero when sending a General Query,
 * and set to the IP multicast address being queried when sending a
 * Group-Specific Query or Group-and-Source-Specific Query
 *
 * */
#include	<stdio.h>
#include	<stdlib.h>
#include	<string.h>
#include	<error.h>
#include	<unistd.h>
#include	<time.h>
#include	<netdb.h>	/* hstrerror */
#include	<getopt.h>		/* getopt_long */
#include	<arpa/inet.h>	/* inet_ntop, inet_pton */
#include	<sys/socket.h>
#include	<netinet/in.h>	/* struct sockaddr_in */
#include	<netinet/ip.h>
#include	<netinet/igmp.h>
#include	<linux/igmp.h>  /*igmpv3_query */

#define PORT 22345
#define BUFFSIZE 4096

/*
struct igmp {
	u_int8_t igmp_type;
	u_int8_t igmp_code;
	u_int16_t igmp_cksum;
	struct in_addr igmp_group;
};
*/

/*struct igmpv3_query {
	uint8_t igmp_type;
	uint8_t igmp_code;	
	uint16_t igmp_cksum;
	struct in_addr igmp_group;
#if defined(BYTE_ORDER) && (BYTE_ORDER == LITTLE_ENDIAN)
    uint8_t  qrv:3,
             suppress:1,
             resv:4;
#else
    uint8_t  resv:4,
	     suppress:1,
	     qrv:3;
#endif
	uint8_t  qqic;
	uint16_t nsrcs;
	uint32_t srcs[0];
};
*/

void usage(char *name)
{
	printf("%s: [-v] [-h]\n", name);
	printf("\t -v: igmp version, 1, 2 or 3, default is 2\n");
	printf("\t -i: interface\n");
	printf("\t -t: query times, default is 1\n");
	printf("\t -h: help message\n");
	printf("\t -g: group address\n");
	printf("\t -s: src address list, only support v3\n");
	printf("\n");
	printf("\t e.g.: %s -v 3 -i em1\n", name);
	printf("\t e.g.: %s -v 3 -i em1 -g 239.1.1.1 -s '192.168.1.1 192.168.1.2'\n", name);
	exit(0);

}

unsigned short in_chksum(unsigned short *addr, int len)
{
	register int nleft = len;
	register int sum = 0;
	u_short answer = 0;

	while (nleft > 1) {
		sum += *addr++;
		nleft -= 2;
	}

	if (nleft == 1) {
		*(u_char *)(&answer) = *(u_char *)addr;
		sum += answer;
	}

	sum = (sum >> 16) + (sum & 0xffff);
	sum += (sum >> 16);
	answer = ~sum;
	return(answer);
}

int main(int argc,char *argv[])
{
	int sockfd, opt, version;
	int times = 1;
	int igmph_len = 8;
	char *interface;
	char buf[BUFFSIZE];
	struct sockaddr_in dst;
	struct iphdr *iph = (struct iphdr *)buf;
	struct igmpv3_query *igmph = (struct igmpv3_query *)(buf + sizeof(struct iphdr));
	uint16_t num_src = 0;
	char multi_src[256][16] = {""};
	char src_list[1024] = "";
	char *group_addr = "000.000.000.000";
	struct in_addr src_addr_list[256];

	/* Get options */
	while ((opt = getopt(argc, argv, "v:i:t:g:s:h")) != -1) {
		switch(opt) {
		case 'v':
			version = atoi(optarg);
			if ( version == 3 )
				igmph_len = 12;
			break;
		case 'i':
			interface = optarg;
			break;
		case 't':
			times = atoi(optarg);
			break;
		case 'g':
			group_addr = optarg;
			break;
		case 's':
			strcpy(src_list, optarg);
			break;
		case 'h':
			usage(argv[0]);
			break;
		default:
			break;
		}
	}

	memset(&dst, 0, sizeof(struct sockaddr_in));
	dst.sin_family = AF_INET;
	dst.sin_addr.s_addr = inet_addr("224.0.0.1");

	/* init ip header */
	memset(iph, 0, sizeof(struct iphdr));
	iph->version = 4;
	iph->ihl = 5;
	iph->tos = 0;
	iph->tot_len = sizeof(struct iphdr) + igmph_len;
	iph->id = htons(54321);
	iph->frag_off = 0;
	iph->ttl = 1;
	iph->protocol = IPPROTO_IGMP;
	iph->check = 0;
	iph->saddr = inet_addr("0.0.0.0");
	iph->daddr = inet_addr("224.0.0.1");

	/*init igmp query header*/
	memset(igmph, 0, igmph_len);
	igmph->type = IGMP_HOST_MEMBERSHIP_QUERY;
	if (version != 1)
		igmph->code = 0x64;	/* 10s */
	if ( 2 == version )
	{
		if ( 0 != strcmp(group_addr, "000.000.000.000") )
		{
			printf("group_addr is %s\n", group_addr);
			inet_pton(AF_INET, group_addr, &(igmph->group));
		}
	}
	else if( 3 == version  )
	{
		if ( 0 != strcmp(group_addr, "000.000.000.000") )
		{
			inet_pton(AF_INET, group_addr, &(igmph->group));
			if (  0 != strcmp(src_list, "") )
			{
				int tmp_i = 0;
				char *tmp_locate;
				char *tmp_src_list;
				tmp_src_list =  src_list;
				while( (tmp_locate = strchr(tmp_src_list, ' ')) != NULL )
				{
					*tmp_locate = '\0';
					memcpy(multi_src[num_src], tmp_src_list, (tmp_locate - tmp_src_list));
					num_src++;
					tmp_src_list = tmp_locate + 1;
				}
				strcpy(multi_src[num_src], tmp_src_list);
				num_src++;
				igmph_len = 12 + num_src * 4;
				igmph->nsrcs = htons(num_src);
				for( tmp_i=0; tmp_i<num_src; tmp_i++)
				{
					inet_pton(AF_INET, multi_src[tmp_i], &src_addr_list[tmp_i]);
				}
				memcpy(igmph->srcs, src_addr_list, num_src * sizeof(struct in_addr));
			}
		}

	}
	igmph->csum = in_chksum((unsigned short *)igmph, igmph_len);
	/* FIXME: could not send query msg if we set qrv and qqic
	igmph->qrv = 2;
	igmph->qqic = 0x7d;
	*/

	if ((sockfd = socket(AF_INET, SOCK_RAW, IPPROTO_RAW)) < 0 ) {
		perror("socket error ");
		exit(1);
	}

	if (interface && setsockopt(sockfd, SOL_SOCKET, SO_BINDTODEVICE,
				interface, sizeof(interface)) == -1) {
			perror("bind to interface failed");
			exit(EXIT_FAILURE);
	}


	while(1) {
		if (sendto(sockfd, buf, sizeof(struct iphdr)+igmph_len, 0,
		    (struct sockaddr *)&dst, sizeof(struct sockaddr_in)) < 0) {
			perror("sendto error ");
			exit(1);
		}

		if ( --times < 1)
			break;

		sleep(125);
	}

	if ( close(sockfd) < 0 ) {
		perror("close error ");
		exit(1);
	}

	return 0;
}
