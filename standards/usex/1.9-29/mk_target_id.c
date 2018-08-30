/*  Author: David Anderson <anderson@redhat.com> */

/*
 *  mk_target_id.c
 *
 *  CVS: $Revision: 1.4 $ $Date: 2016/02/10 19:25:52 $
 */

#include "defs.h"

int
main(int argc, char **argv)
{
	printf("char *build_target_id = \"%s USEX_VERSION %s\";\n",
		MACHINE_TYPE, USEX_VERSION);	

	exit(0);
}

