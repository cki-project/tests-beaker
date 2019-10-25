#pragma ident	"$Id: opendir.c,v 1.1 2005/10/25 22:38:34 jmoyer Exp $"

#include <stdio.h>
#include <stdlib.h>
#include "test.h"

int
main (
	int argc,
	char **argv
)
{
	struct dir_list *listp, *p;
	int error;
	int fail = 0, attempt = 0;
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
		if (do_opendir(p, check, argv[3]) != 0)
			fail++;
	}

done:
	if (!fail) {
		fprintf(stdout, "%s:\tSUCCEEDED\n", argv[0]);
	} else {
		fprintf(stdout, "%s:\tFAILED\n", argv[0]);
		fprintf(stdout, "\tFailed: %d of %d\n", fail, attempt);
	}

	return (fail ? 1 : 0);
}
