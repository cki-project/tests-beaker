/*  Author: David Anderson <anderson@redhat.com> */

/*
 *  CVS: $Revision: 1.4 $ $Date: 2016/02/10 19:25:51 $
 *
 */

#include "defs.h"

#ifndef HZ
#define HZ 100
#endif
#ifdef __ia64__
#undef HZ
#define HZ 1024
#endif

void
dry(void)
{
    register PROC_TABLE *tbl = &Shm->ptbl[ID];
    char buf[DHRYSTONE_BUFSIZE];
    int i, argc;
    char *ptr, *argv[MAX_ARGV];

    argc = parse(tbl->i_path, argv);
    for (i = 1; i < argc; i++) {
        if (argv[i] != NULL) {
                if (strncmp(argv[i], "-nol", 4) == 0)
                    tbl->i_stat |= IO_NOLOG;
        }
    }

    tbl->i_pass = 0;
    tbl->machine_HZ = HZ;

    io_send(FCLEAR, NOARG, NOARG, NOARG);
    io_send(FILENAME, (long)"dhrystone benchmark", NOARG, NOARG);
    io_send(FSTAT, tbl->i_stat & IO_BKGD ? _BKGD_ : _OK_, NOARG, NOARG);

    close(fileno(stdout));
    if ((stdout = tmpfile()) == NULL) {
            sprintf(buf, "tmpfile: %s", strerror(i = errno));
            io_send(FSIZE, (long)buf, NOARG, NOARG);
            paralyze(ID, "tmpfile", i);
    }

    for (EVER) {
	if (mother_is_dead(Shm->mompid, "D1")) {  /* Mom's dead. */
	    set_time_of_death(ID);
	    _exit(MOM_IS_DEAD);
        }

	SEND_HEARTBEAT(ID);

	if (tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING)) 
	    put_test_on_hold(tbl, ID);
	
        io_send(FPASS, ++(tbl->i_pass), NOARG, NOARG);
        rewind(stdout);

	while (!Proc0()) {
		SEND_HEARTBEAT(ID);
		tbl->zero_benchtime++;
	}

        rewind(stdout);
        ptr = tbl->dry_buffer;
        bzero(tbl->dry_buffer, DHRYSTONE_BUFSIZE);
        while (fgets(buf, STRINGSIZE*2, stdout)) {
                sprintf(&ptr[strlen(ptr)], buf);
                if (strneq(buf, "This machine")) {
                        parse(buf, argv);
                        tbl->dhrystones = strtoul(argv[4], 0, 10);
                        break;
                }
        }

        sprintf(buf, "%ld dhrystones/%s", tbl->dhrystones,
		CURSES_DISPLAY() ? "second" : "sec");
	mkstring(buf, 33, LJUST);
        io_send(FSIZE, (long)buf, NOARG, NOARG);
    }
}

void
dry_test_inquiry(int target, FILE *fp)
{
        PROC_TABLE *tbl = &Shm->ptbl[target];

        fprintf(fp, "\nDHRYSTONE TEST SPECIFIC:\n");
        fprintf(fp, "machine_HZ: %d dhrystones: %ld zero_benchtime: %ld dry_buffer:\n%s", 
		tbl->machine_HZ, tbl->dhrystones, tbl->zero_benchtime, tbl->dry_buffer);
}
