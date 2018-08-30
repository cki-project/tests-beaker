/*  Author: David Anderson <anderson@redhat.com> */

/*
 *  vmem:  This is a virtual memory exerciser that rigorously exercises
 *         the kernel's paging mechanism and potentially the swapping
 *         algorithms.  It first expands its data area by the user requested
 *         number of megabytes, and then writes a "1" to random pages
 *         within the data space.  Since it just does memory accesses,
 *         the concept of a "pass" really doesn't apply -- so to force
 *         it into the kernel, a dance pattern is displayed every 1000
 *         memory accesses.  Putting the test in the background will
 *         override such an action.
 *
 *         Random access is the default -- sequential access is available
 *         by using the -s flag.
 *
 *  BitKeeper ID: @(#)vmem.c 1.3
 *
 *  CVS: $Revision: 1.7 $ $Date: 2016/02/10 19:25:53 $
 */

#include "defs.h"

static void over_write(char *, int, int);

void
vmem(void)
{
        register PROC_TABLE *tbl;
	register char	*ram = NULL;
	time_t		seed;
        unsigned long   i, j;
        unsigned	update = 0;
	unsigned long   logtime = 0; 
	size_t    	pagesize;
        char 		*argv[MAX_ARGV];
	int		argc;
	unsigned long   offset;

        tbl = &Shm->ptbl[ID];

        argc = parse(tbl->i_path, argv);
	for (i = 1; i < argc; i++) {
       	    if (argv[i] != NULL) {
            	if (strncmp(argv[i], "-s", 2) == 0) 
		    tbl->access_mode = SEQUENTIAL;
                if (strncmp(argv[i], "-r", 2) == 0) 
		    tbl->access_mode = RANDOM;
		if (strncmp(argv[i], "-nol", 3) == 0)
		    tbl->i_stat |= IO_NOLOG;
            }
	}

	if (!tbl->access_mode) {
       		if (streq(Shm->vmem_access, "ran"))
                	tbl->access_mode = RANDOM;
        	else if (streq(Shm->vmem_access, "seq"))
                	tbl->access_mode = SEQUENTIAL;
	}

	if (!tbl->access_mode)
             	tbl->access_mode = RANDOM;

	/*
	 *  --vmem mbs argument overrides everything.
	 */
	if (Shm->vmem_size)
		tbl->i_size = Shm->vmem_size;
       
        tbl->datasize = tbl->i_size * 1048576;
	tbl->datacount = 0.0;

	tbl->vmem_errbuf[0] = (char)NULLCHAR;

	io_send(FPASS, 1, NOARG, NOARG);  /* used by the logger only */
        io_send(FSTAT, tbl->i_stat & IO_BKGD ? _BKGD_ : _OK_, NOARG, NOARG);

        io_send(FSBRK, NOARG, NOARG, NOARG);
        while (tbl->i_size) {
    	    if ((ram = sbrk(tbl->datasize)) == (char *)-1) {
		if (strlen(tbl->vmem_errbuf) == 0)
                    io_send(FCLEAR, NOARG, NOARG, NOARG);
	        else
		    i = strlen(tbl->vmem_errbuf);

                sprintf(tbl->vmem_errbuf, "sbrk(%ld mb): %s", 
		    (ulong)tbl->i_size, strerror(errno));
	        if (strlen(tbl->vmem_errbuf) < i)
		    over_write(tbl->vmem_errbuf, i, FSIZE);
    	        io_send(FSIZE, (long)tbl->vmem_errbuf, NOARG, NOARG);
                tbl->i_size -= 1;
                tbl->datasize = tbl->i_size * 1048576;
    	    }
            else
                break;
	}

	if (tbl->i_size == 0) {
            i = errno;
	    over_write(tbl->vmem_errbuf, strlen(tbl->vmem_errbuf), FSIZE);
	    sprintf(tbl->vmem_errbuf, "sbrk: Not enough space");
    	    io_send(FSIZE, (long)tbl->vmem_errbuf, NOARG, NOARG);
	    paralyze(ID, "sbrk", i);
	}

	if (strlen(tbl->vmem_errbuf)) {
	    over_write(tbl->vmem_errbuf, strlen(tbl->vmem_errbuf), FSIZE);
            io_send(FSIZE, (long)tbl->vmembuf, NOARG, NOARG);
        }

	switch (tbl->access_mode)
	{
	case RANDOM:
        	sprintf(tbl->vmembuf, "%ld mb random        ", 
			(ulong)tbl->i_size);
		break;
	case SEQUENTIAL:
        	sprintf(tbl->vmembuf, "%ld mb sequential        ", 
			(ulong)tbl->i_size);
		break;
	}

        io_send(FSIZE, (long)tbl->vmembuf, NOARG, NOARG);
	io_send(FCLEAR, NOARG, NOARG, NOARG);

	tbl->pass_divisor = 0;
        io_send(CANNED, NOARG, NOARG, NOARG);

	time(&seed);
	srandom((unsigned)(seed/getpid()));

	pagesize = getpagesize();
	tbl->pages = tbl->datasize / pagesize;
	for (i = j = tbl->i_pass = 0; keep_alive(); tbl->i_pass++) {

	    SEND_HEARTBEAT(ID);

	    if (tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING)) 
		put_test_on_hold(tbl, ID);

	    bzero(tbl->vmembuf, STRINGSIZE);
	    switch (tbl->access_mode)
	    {
	    case SEQUENTIAL:              /* touch first byte in each page */
		offset = j * pagesize;
		if (++j == tbl->pages)
			j = 0;
		break;
					  /* touch random byte in each page */
	    case RANDOM:
		offset = (random() % (tbl->datasize / pagesize)) * pagesize;
		offset += (random() % pagesize);
		break;
	    }

            ram[offset] = 1; 

            if ((tbl->i_pass % 1000) == 0) {
                if (mother_is_dead(Shm->mompid, "V2")) {  /* Mom's dead. */
		    set_time_of_death(ID);
                    _exit(MOM_IS_DEAD);
                }

                i++;

		tbl->datacount += 1000;
		update += 1000;

		if (update > 1048576/10) {
                    if ((tbl->datacount/1073741824.0) >= 1024) {
                        sprintf(tbl->vmembuf,
                            "%.3f TB",
                                tbl->datacount/(1099511627776ULL));
                        space_pad(tbl->vmembuf, strlen("xxxx.x gb"));
                    }
                    else if ((tbl->datacount/1048576.0) >= 1024) {
                        sprintf(tbl->vmembuf,
                            "%.1f gb",
                                tbl->datacount/(1024*1024*1024));
                        space_pad(tbl->vmembuf, strlen("xxxx.x mb")); 
                    }
                    else {
                        sprintf(tbl->vmembuf, "%.1f mb",
                                tbl->datacount/(1024*1024));
                    }

                    io_send(FOPERATION, (long)tbl->vmembuf, NOARG, NOARG);

		    if (Shm->logfile && !(tbl->i_stat & IO_NOLOG)) {
		        strcpy(tbl->vmem_buffer, tbl->vmembuf);

		        if (++logtime == 10) {
				char buffer1[STRINGSIZE];
				char buffer2[STRINGSIZE];
				time_t now;

				time(&now);
                		elapsed_time(tbl->i_timestamp, now, buffer1);
                		tbl->i_timestamp = now;

                        	sprintf(buffer2,
                                  " VMEM TEST %d: (%s) 1 MB ELAPSED TIME: %s\n",
                                	ID+1, tbl->vmem_buffer, buffer1);
		            	io_send(LOG_MESSAGE, (long)buffer2, 
					NOARG, NOARG); 
			    	logtime = 0;
		        }
		    }

                    update = 0;
                }
            }
        }
}

static void
over_write(char *buf, int cnt, int arg)
{
    register int i;

    for (i = 0; i < cnt; i++)
        buf[i] = ' ';
    buf[i] = (char)NULLCHAR;
    io_send(arg, (long)buf, NOARG, NOARG);
}

/*
 *  These two are called ONLY from the window_manager (from its context) to 
 *  create a message without the overhead of the message passing scheme.
 */

int
canned_vmem(int id, char *buffer)
{
        register PROC_TABLE *tbl;
	ulong offset = 0;
	int dance_steps;
	static int passcode = 0;

        tbl = &Shm->ptbl[id];

	if (CURSES_DISPLAY())
		dance_steps = CURSES_DANCE_STEPS;
	else if (GTK_DISPLAY())
		dance_steps = GTK_DANCE_STEPS;

	offset = (tbl->i_pass/1000);
	if (offset != tbl->pass_divisor) {
	    tbl->pass_divisor = offset;
            sprintf(buffer, "%c%c%d", CANNED, tbl->i_local_pid, 
		(passcode++ % dance_steps));
	    time(&tbl->i_canned_msg_time);
	    return(TRUE);
	}

	return(FALSE);
}

char *curses_vmem_dance(int id, char *s)
{
        register PROC_TABLE *tbl;
	static char *curses_dance_steps[CURSES_DANCE_STEPS] = {
	    "         ",
	    "*        ",
	    "**       ",
	    "***      ",
	    "****     ",
	    "*****    ",
	    "******   ",
	    "*******  ",
	    "******** ",
	    "*********",
	    "******** ",
	    "******   ",
	    "*****    ",
	    "****     ",
	    "***      ",
	    "**       ",
	    "*        ",
	};

        tbl = &Shm->ptbl[id];

	if (tbl->i_stat & IO_BKGD)
		return(curses_dance_steps[0]);
	return(curses_dance_steps[atoi(s)]);
}


void
vmem_test_inquiry(int target, FILE *fp)
{
        PROC_TABLE *tbl = &Shm->ptbl[target];

        fprintf(fp, "\nVMEM TEST SPECIFIC:\n");
        fprintf(fp, "pass_divisor: %lu vmem_buffer: \"%s\"\n", 
		tbl->pass_divisor, tbl->vmem_buffer);
	fprintf(fp, "vmembuf: \"%s\"%s", tbl->vmembuf,
		strlen(tbl->vmembuf) ? "\n" : " ");
	fprintf(fp, "vmem_errbuf: \"%s\"\n", tbl->vmem_errbuf);
	fprintf(fp, "access_mode: %s\n", 
		tbl->access_mode == RANDOM ? "RANDOM" : "SEQUENTIAL");
	fprintf(fp, 
            "datasize: %lu datacount: %.0f pages: %lu\n",
		tbl->datasize, tbl->datacount, tbl->pages);
	fprintf(fp, "dance_widget: %lx\n", (ulong)tbl->dance_widget);
}
