#pragma ident	"$Id: doautomount.c,v 1.1 2005/10/25 22:38:34 jmoyer Exp $"
/*
 * doautomount [args]
 * NOTE: This program should be suid root to work properly.
 */

#include <sys/types.h>
#include <stdio.h>
#include <unistd.h>

int main(argc, argv)
	int argc;
	char **argv;
{
	char *comm;
	extern char *getenv();

	if ((comm = getenv("AUTOMOUNT")) != NULL)
		*argv = comm;
	else
		*argv = "/usr/lib/fs/autofs/automount";

	(void)setuid(0);

	(void)execv(*argv, argv);

	/* NOTREACHED */
	return 1;
}
