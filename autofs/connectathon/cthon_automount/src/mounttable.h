#pragma ident "$Id: mounttable.h,v 1.1 2005/10/25 22:38:34 jmoyer Exp $"
#include <stdio.h>

#ifdef USE_MNTTAB
/* Solaris style */
#include <sys/mnttab.h>
typedef struct mnttab MY_MNTTAB;
#else
/* Linux style below */
#include <mntent.h>
typedef struct mntent MY_MNTTAB;
#endif
MY_MNTTAB *my_getmntent(FILE *fp);

#ifdef USE_STATVFS
/* Solaris style */
#include <sys/statvfs.h>
#else
/* Linux style */
#include <sys/statfs.h>
#define statvfs statfs
#define mnt_mountp mnt_dir
#define mnt_fstype mnt_type
#endif

int cmpfstype(struct statvfs *buf, const char *fsname);
const char *getfsname(struct statvfs *buf);

