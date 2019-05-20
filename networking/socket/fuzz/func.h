#include	"network.h"

extern int debug;

char *errtostring(int error);
char *domaintostring(int domain);
char *typetostring(int type);
char *soopttostring(int optname);
char *ipopttostring(int optname);
char *ipv6opttostring(int optname);

char *opttostring(int level, int optname);

void err_sys(const char *fmt);
int test_setsockopt(int sockfd, int level, int optname, const void *optval, socklen_t optlen);
int test_getsockopt(int sockfd, int level, int optname, void *optval, socklen_t *optlen);
int test_sockopt(int sockfd, int level, int optname, void *optval, socklen_t optlen);

void usage(char *msg);
void help(char *msg);


int tst_rand(int start, int end);
int likely();
int unlikely();
#define rand tst_rand
