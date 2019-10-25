#pragma ident	"$Id: test.h,v 1.1 2005/10/25 22:38:34 jmoyer Exp $"

/*
 * AUTO_MNTPNT specifies the common mntpnt for automonted directories
 * This is the directory where all mountpoints are mounted and symlinks
 * point to. i.e. "/tmp_mnt"
 * This should be set to a NULL string "" when mounts are done in place,
 * such is the case of "autofs".
 */
#define	AUTO_MNTPNT	""

struct dir_list {
	char *dir;			/* stat(dir/.auto_test) */
	int error;			/* error = 0 if expect success */
					/* error != 0 if expect error */
	int nocheck;    /* do not check the map table */
	struct dir_list *next;
};
extern int read_input(char *, char *, struct dir_list **);
extern int search_mnttab(char *, int *);
extern int do_opendir(struct dir_list *, int, char *);
extern void filter_result(char *, int *, int *, char *);
