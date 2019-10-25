#pragma ident "$Id: mounttable.c,v 1.1 2005/10/25 22:38:34 jmoyer Exp $"
#include <string.h>
#include "mounttable.h"
#include "magicdefs.h"

#ifdef USE_MNTTAB
/* getmntent takes two args */
MY_MNTTAB *my_getmntent(FILE *fp)
{
	static MY_MNTTAB mnttab;
	int ret;

	ret = getmntent(fp, &mnttab);
	if (ret == -1)
		return NULL;
	if (ret > 0) {
		fprintf(stderr, "An error occurred while calling getmntent: %d\n", ret);
		return NULL;
	}

	return &mnttab;
}
#else
/* getmntent only takes one arg */
MY_MNTTAB *my_getmntent(FILE *fp)
{
	return getmntent(fp);
}
#endif

int cmpfstype(struct statvfs *buf, const char *fsname)
{
#if USE_STATVFS
	return strcmp(buf->f_basetype, fsname);
#else
	/* We have to use super_block magic values: */
	return !(
	       (!strcmp("autofs", fsname) && buf->f_type == S_MAGIC_AUTOFS)
#if USE_TMPFS_SCAFFOLDING
	    || (!strcmp("autofs", fsname) && buf->f_type == S_MAGIC_TMPFS)
#endif
	    || (!strcmp("nfs",    fsname) && buf->f_type == S_MAGIC_NFS)
	    );
#endif
}

const char *getfsname(struct statvfs *buf)
{
#ifdef USE_STATVFS
	return buf->f_basetype;
#else
	if (buf->f_type == S_MAGIC_AUTOFS)
		return "autofs";
#if USE_TMPFS_SCAFFOLDING
	if (buf->f_type == S_MAGIC_TMPFS)
		return "autofs";
#endif
	if (buf->f_type == S_MAGIC_NFS)
		return "nfs";
	return "UNKNOWNFSTYPE";
#endif
}
