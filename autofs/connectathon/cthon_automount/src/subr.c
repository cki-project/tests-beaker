#pragma ident	"$Id: subr.c,v 1.1 2005/10/25 22:38:34 jmoyer Exp $"

/******************************************************************************
 * NOTES:
 * 	- do_opendir currently only understands fstype = "autofs" | "nfs"
 *****************************************************************************/

/******************************************************************************
 * Linux compatibility CHANGELOG
 *
 * Mike W <michael.waychison@sun.com>
 *  - use struct mntent (mntent.h) instread of struct mnt (sys/mnttab.h)
 *  - use statfs in lieu of statvfs
 *****************************************************************************/

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>
#include <stdlib.h>
#include <sys/types.h>
#include <fcntl.h>
#include <sys/param.h>
#include <dirent.h>
#include "mounttable.h"
#include "test.h"
#include "magicdefs.h"

extern int errno;

#define	LINESZ 1024

int
read_input(
	char *data_file,
	char *except_file,
	struct dir_list **listpp
)
{
	FILE *fp;
	char line[LINESZ];
	char *lp;
	struct dir_list *listp, *prev;
	int len = 0;

	*listpp = NULL;
	if ((fp = fopen(data_file, "r")) == NULL) {
		fprintf(stderr, "couldn't open %s for reading.\n", data_file);
		return (1);
	}

	while (!feof(fp)) {
		/*
		 * read data file one line at a time
		 */
		if (fgets(line, LINESZ, fp) == NULL) {
			return (0);	/* EOF */
		}
		len = strlen(line);
		if (len <= 0) {
			continue;
		}
		lp = &line[len - 1];

trim:
		/* trim trailing white space */
		while (lp >= line && isspace(*(char *)lp))
			*lp-- = '\0';
		if (lp < line) {			/* empty line */
			continue;
		}

		/*
		 * Ignore comments. Comments start with '#'
		 * which must be preceded by a whitespace, unless
		 * if '#' is the first character in the line.
		 */
		lp = line;
		while ((lp = strchr(lp, '#'))) {
			if (lp == line || isspace(*(lp-1))) {
				*lp-- = '\0';
				goto trim;
			}
			lp++;
		}

		listp = (struct dir_list *) malloc(sizeof (*listp));
		if (listp == NULL) {
			fprintf(stderr, "read_input: malloc failed\n");
			return (ENOMEM);
		}
		(void) memset((char *)listp, 0, sizeof (*listp));

		/*
		 * get first string from line which corresponds to
		 * the path
		 */
		lp = line;
		while (!isspace(*lp) && (lp < line + len))
			lp++;
		/*
		 * at end of path string
		 */
		*(lp++) = '\0';		/* now line contains only path string */

		/*
		 * get second and last component, the expected result
		 */
		while (isspace(*lp) && (lp < line + len))
			lp++;
		if (lp < line + len) {
			listp->error = atoi(lp);
		} else {
			fprintf(stderr,
			    "'%s' not in expected format - ignoring\n", line);
			continue;
		}
		listp->error = atoi(lp);
		listp->dir = (char *) malloc(len - strlen(lp));
		if (listp->dir == NULL) {
			fprintf(stderr, "read_input: malloc failed\n");
			return (ENOMEM);
		}
		(void) strcpy(listp->dir, line);
		filter_result(listp->dir, &listp->error, &listp->nocheck, except_file);
		/*
		 * Append element to list
		 */
		if (*listpp == NULL)
			*listpp = listp;	/* first element */
		else
			prev->next = listp;	/* append */
		prev = listp;
	}
	return (0);
}


/*
 * returns 0 if MOUNT_TABLE was read successfully, errno otherwise.
 * if MOUNT_TABLE ok, then *times contains the number of occurances
 * of mntpnt in the MOUNT_TABLE
 */
int
search_mnttab(
	char *mntpnt,
	int *times
)
{
	FILE *fp;
	MY_MNTTAB *mnt;
	struct flock fl = {F_RDLCK, SEEK_SET, 0, 0, 0};
	char tmp[MAXPATHLEN];
	int error = 0;

	*times = 0;
	if ((fp = fopen(MOUNT_TABLE, "r")) == NULL) {
		error = errno;
		fprintf(stderr, "search_mnttab: could not open %s error=%d\n",
		    MOUNT_TABLE, error);
		return (error);
	}
	rewind(fp);

	if ((fcntl(fileno(fp), F_SETLKW, &fl)) < 0) {
		error = errno;
		fprintf(stderr, "search_mnttab: could not lock %s\n",
		    MOUNT_TABLE);
		fclose(fp);
		return (error);
	}

	while ((mnt = my_getmntent(fp)) != NULL) {
		if (error)
			break;
		(void) sprintf(tmp, "%s%s", AUTO_MNTPNT, mntpnt);
		if ((strcmp(mnt->mnt_mountp, tmp) == 0) &&
		    (strcmp(mnt->mnt_fstype, AUTOFS) != 0)) {
			(*times)++;
		}
	}

	fclose(fp);
	return (error == -1 ? 0 : error);
}

/*
 * returns 0 if opendir returns the expected result; errno otherwise
 * check MNTTAB for mounted path if 'check' is non-zero
 * checks that the file system mounted is 'fstype' if 'fstype' is not NULL.
 *
 */
int
do_opendir(
	struct dir_list *p,
	int check,
	char *fstype
)
{
	DIR *dirp;
	struct statvfs buf;
	int error = 0, times;

	fprintf(stdout, "\t%s", p->dir);
	if (p->error)
		fprintf(stdout, "\texpect failure\n");
	else
		fprintf(stdout, "\texpect success\n");

	if ((dirp = opendir(p->dir)) == NULL) {
		if (!p->error) {
			/*
			 * expected success but failed
			 */
			error = errno;
			fprintf(stdout,
			    "\topendir(%s) unexpected error %d\n",
			    p->dir, error);
		}
	} else {
		if (closedir(dirp)) {
			fprintf(stdout,
			    "closedir(%s) failed - errno=%d - ignored\n",
			    p->dir, errno);
		}

		if (p->error) {
			/*
			 * succeeded, but expected failure
			 */
			error = 1;
			fprintf(stdout,
			    "\topendir(%s) expected error but succeeded.\n",
			    p->dir);
			goto done;
		}

		/*
		 * sucessful opendir(). Check proper filesystem
		 * has been mounted?
		 */
        check = p->nocheck ? 0 : check;
		if (check) {
			if ((error = search_mnttab(p->dir, &times))) {
				fprintf(stderr, "search_mnttab failed\n");
				error = 1;
				goto done;
			}
			if (times != 1) {
				error = 1;
				fprintf(stdout,
				    "error: %s found %d times in %s expected one.\n",
				    p->dir, times, MOUNT_TABLE);
				goto done;
			}
		}

		if (!check && 0 == strcmp(fstype, "nfs")) {
			//if we said no check mount table, then there is no meanings to
			//check the fstype
			fstype = NULL;
		}

		if (fstype) {
			/*
			 * check if fstype matches
			 */
			if (statvfs(p->dir, &buf) == -1) {
				error = errno;
				fprintf(stderr,
				    "opendir: statfs failed, errno=%d\n",
				    error);
				goto done;
			}
			if (cmpfstype(&buf, fstype))
			{
				/*
				 * filesystem types don't match
				 */
				error = 1;
				fprintf(stderr,
				    "error:%s - fstype=%s expected %s\n",
				    p->dir, getfsname(&buf), fstype);
			}
		}
	}
done:
	if (error)
		fprintf(stdout, "\t%s\t- NOT OK -\n", p->dir);
	else
		fprintf(stdout, "\t%s\t- OK -\n", p->dir);

	return (error);
}
