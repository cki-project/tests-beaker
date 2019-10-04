#pragma ident	"$Id: mopendir.c,v 1.1 2005/10/25 22:38:34 jmoyer Exp $"

#include <stdio.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <stdlib.h>
#include "test.h"

int
main (
	int argc,
	char **argv
)
{
	struct dir_list *listp, *p;
	pid_t pid;
	int fail = 0, attempt = 0, i;
	int error, res;
	int check;

	if (argc != 5) {
		fprintf(stderr, "usage: %s <data_file> <except_file> <fstype> <0|1>\n",
		    argv[0]);
		fail++;
		return (1);
	}

	check = atoi(argv[4]);		/* check MOUNT_TABLE? */

	if ((error = read_input(argv[1], argv[2], &listp))) {
		fprintf(stderr, "error reading data file %s: %d\n",
		    argv[1], error);
		fail++;
		goto done;
	}

	for (p = listp; p; p = p->next) {
		attempt++;
		if ((pid = fork()) == -1) {
			fprintf(stderr, "%s: fork failed - exiting\n", argv[0]);
			fail++;
			goto done;
		}
		if (pid == 0) {
			/*
			 * child
			 */
			_exit (do_opendir(p, check, argv[3]));
		}
	}

	/*
	 * parent
	 */
	for (i = 0; i < attempt; i++) {
		wait (&res);
		if (WIFEXITED(res)) {
			if (WEXITSTATUS(res))
				fail++;
		} else {
			fprintf(stdout, "%s: pid=%d didn't exit cleanly\n",
			    argv[0], pid);
		}
	}
done:
	if (fail) {
		fprintf(stdout, "%s:\tFAILED\n", argv[0]);
		fprintf(stdout, "\tFailed: %d of %d\n", fail, attempt);
	} else {
		fprintf(stdout, "%s:\tSUCCEEDED\n", argv[0]);
	}

	return (fail ? 1 : 0);
}
