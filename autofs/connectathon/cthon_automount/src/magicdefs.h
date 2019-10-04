#pragma ident "$Id: magicdefs.h,v 1.1 2005/10/25 22:38:34 jmoyer Exp $"
#ifndef _MAGICDEFS_H
#define _MAGICDEFS_H

#define AUTOFS "autofs" /* The value we see from getmntent */

#ifdef __linux__
#define S_MAGIC_NFS 		0x6969

#if AUTOFSNG
#undef AUTOFS
#define AUTOFS "autofsng"
#define S_MAGIC_TMPFS		0x01021994
#define S_MAGIC_AUTOFS		0x7d92b1a0 /* magic for autofsng */

#else /* standard Linux automounter, v3 or v4 */

#define S_MAGIC_AUTOFS		0x0187    /* magic for autofs v3 and v4 */

#endif /* AUTOFSNG */
#endif /* __linux__ */

#endif
