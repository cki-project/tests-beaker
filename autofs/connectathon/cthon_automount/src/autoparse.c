#pragma ident	"$Id: autoparse.c,v 1.1 2005/10/25 22:38:34 jmoyer Exp $"

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/types.h>
#include <string.h>

#define	MAXPATHLEN	1536
#define	MAXPATHS	1000
#define	OK		0
#define	ERROR		-1

extern void filter_result(char *, int *, int *, char *);

struct path {
	char pa_path[MAXPATHLEN];
	int pa_expect;
};

int do_opendir(struct path *);


int
main(int argc, char *argv[])
{
	int err = 0, n, i;
	struct path p[MAXPATHS];
	FILE *fp;

	if (argc != 3) {
		fprintf(stderr, "\tusage: autoparse <filename> <exceptfile>\n");
		return (ERROR);
	}

	/* open the map file */
	if ((fp = fopen(argv[1], "r")) == NULL) {
		fprintf(stderr, "autoparse: file open %s failed\n", argv[1]);
		return (ERROR);
	}

	i = 0;
	while (fscanf(fp, "%s%d", (p[i].pa_path), &(p[i].pa_expect)) != EOF) {
		if (*p[i].pa_path == '\n' || *p[i].pa_path == '#') { /* skip */
			char c;
			c = *p[i].pa_path;
			while (c != '\n')
				c = fgetc(fp);
			continue;
		}
        filter_result(p[i].pa_path, &p[i].pa_expect, NULL, argv[2]);
		i++;
		if (i > MAXPATHS) {
			fprintf(stderr, "autoparse: maxpaths exceeded\n");
			return (ERROR);
		}
	}
	fclose(fp);

	n = i;
	for (i = 0; i < n; i++) {
		if (do_opendir(&p[i]) == -1)
			err++;
	}

	if (err != 0) {
		fprintf(stdout, "autoparse: FAILED: Total %d/%d tests failed\n",
			err, n);
		return (ERROR);
	}

	fprintf(stdout, "autoparse: PASSED: All %d tests passed\n", n);

	return (OK);
}

int
do_opendir(struct path *p)
{
	int err;
	DIR *dp;

	dp = opendir(p->pa_path);
	err = errno;

	if (p->pa_expect == OK && dp == NULL) {
		fprintf(stdout,
			"autoparse: FAILED: opendir(%s) unexpected error: %s\n",
			p->pa_path, strerror(err));
		return (ERROR);
	}

	if (p->pa_expect != OK && dp != NULL) {
		fprintf(stdout,
			"autoparse: FAILED: opendir(%s) unexpected success\n",
			p->pa_path);
		closedir(dp);
		return (ERROR);
	}

	if (p->pa_expect != OK && dp == NULL && err != EACCES &&
	    err != ENOENT && err != ETIMEDOUT && err != ENAMETOOLONG) {
		fprintf(stdout,
			"autoparse: FAILED: opendir(%s) unexpected error: %s\n",
			p->pa_path, strerror(err));
		return (ERROR);
	}

	if (dp != NULL)
		closedir(dp);

	if (p->pa_expect == OK)
		fprintf(stdout,
			"autoparse: PASS: opendir(%s) expected success\n",
			p->pa_path);
	else
		fprintf(stdout,
			"autoparse: PASS: opendir(%s) expected failure\n",
			p->pa_path);

	return (OK);
}
