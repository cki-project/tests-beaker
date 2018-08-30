/*  Author: David Anderson <anderson@redhat.com> */
 
/*
 *  CVS: $Revision: 1.4 $ $Date: 2016/02/10 19:25:52 $
 */

#include "defs.h"

void 
float_test(void)
{
    register int i;
    register PROC_TABLE *tbl;        
    int argc;
    char *argv[MAX_ARGV];
    char buf[WHETSTONE_BUFSIZE];
    char *MWIPS, *ptr;

    tbl = &Shm->ptbl[ID];

    argc = parse(tbl->i_path, argv);
    for (i = 1; i < argc; i++) {
        if (argv[i] != NULL) {
                if (strncmp(argv[i], "-nol", 4) == 0)
                    tbl->i_stat |= IO_NOLOG;
        }
    }

    tbl->i_pass = 0;

    io_send (FCLEAR, NOARG, NOARG, NOARG);
    io_send (FILENAME, (long)"whetstone benchmark", NOARG, NOARG);
    io_send(FSTAT, tbl->i_stat & IO_BKGD ? _BKGD_ : _OK_, NOARG, NOARG);

    bzero(tbl->whetbuf, WHETSTONE_BUFSIZE);

    argc = 2;
    argv[0] = "whetstone";
    argv[1] = "n";
    argv[2] = NULL;

    close(fileno(stdout));
    if ((stdout = tmpfile()) == NULL) {
            sprintf(buf, "tmpfile: %s", strerror(i = errno));
            io_send(FERROR, (long)buf, NOARG, NOARG);
            paralyze(ID, "tmpfile", i);
    }

    for (EVER) {
        io_send(FPASS, ++(tbl->i_pass), NOARG, NOARG);

        if (mother_is_dead(Shm->mompid, "F1")) {   /* Mom's dead. */
            set_time_of_death(ID);
            _exit(MOM_IS_DEAD);
        }

        if (tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING)) 
	    put_test_on_hold(tbl, ID);

        argc = 2;
        argv[0] = "whetstone";
        argv[1] = "n";
        argv[2] = NULL;
	rewind(stdout);
	io_send(FOPERATION, (long)"calibrate", NOARG, NOARG);

	whetstone_main(argc, argv);

	rewind(stdout);
	ptr = tbl->whetbuf;
        bzero(tbl->whetbuf, WHETSTONE_BUFSIZE);
	while (fgets(buf, WHETSTONE_BUFSIZE-1, stdout)) {
		sprintf(&ptr[strlen(ptr)], buf);
		if (strneq(buf, "MWIPS")) {
			sprintf(&ptr[strlen(ptr)],
			    "##########################################");
			parse(buf, argv);
			MWIPS = argv[1];
			break;
		}
        }
	
	sprintf(buf, "%s MWIPS", MWIPS);
	io_send(FSIZE, (long)buf, NOARG, NOARG);
	tbl->whet_mwips = atof(MWIPS);
    }
}

void 
float_test_inquiry(int id, FILE *fp)
{
        register PROC_TABLE *tbl;        
	char *ptr;

        tbl = &Shm->ptbl[id];

        fprintf(fp, "\nWHETSTONE TEST SPECIFIC:\n");

	fprintf(fp, "whet_mwips: %.3f", tbl->whet_mwips);
	ptr = tbl->whetbuf;
	while (*ptr) {
		fprintf(fp, "%c", *ptr);
		ptr++;
	}
	fprintf(fp, "\n");
}
