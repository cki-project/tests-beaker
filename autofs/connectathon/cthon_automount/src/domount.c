/*
 *	"$Id: domount.c,v 1.1 2005/10/25 22:38:34 jmoyer Exp $"
 *      combined with 1.3 93/03/15 NFS Rev 2 testsuite
 *	combined with 1.1 Lachman ONC Test Suite source
 *
 * domount [-u] [args]
 *
 * NOTE: This program should be suid root to work properly.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

int
main(argc, argv)
	int argc;
	char **argv;
{
	char *comm;

	if (argc > 1 && strcmp(argv[1], "-u") == 0) {
		if ((comm = getenv("UMOUNT")) != NULL)
			*++argv = comm;
		else
			*++argv = "/etc/umount";
	} else {
		if ((comm = getenv("MOUNT")) != NULL)
			*argv = comm;
		else
			*argv = "/etc/mount";
	}

	(void)setuid(0);

	printf("Using %s\n", *argv);
	(void)execv(*argv, argv);

	/* NOTREACHED */
	return 1;
}
