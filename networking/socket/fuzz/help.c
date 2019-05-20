#include "func.h"

char pro_name[] = "Socket";
char usage_str[] = "[-d] [-h] [-t] [-u] [-H remote host]";

/* usage only for option tips */
void usage(char *msg)
{
	if (msg != NULL)
		fprintf(stderr, "\n%s\n\n", msg);

	fprintf(stderr, "Usage: %s %s\n\n"
			"(use -h for detailed help)\n",
			pro_name, usage_str);
	exit(EXIT_FAILURE);
}

/* help() is used for detailed info */
void help(char *msg)
{
	if (msg != NULL)
		fprintf(stderr, "\n%s\n\n", msg);
	fprintf(stderr, "Usage: %s %s\n", pro_name, usage_str);
	fprintf(stderr, "Where:\n"
			"  -d : enable debug, 1 simple debug, 2 more details\n"
			"  -h : help\n"
			"  -H : remote host name, default is localhost\n"
			"  -t : only run tcp testing\n"
			"  -u : only run udp testing\n"
	);
}
