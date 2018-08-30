/*  Author: David Anderson <anderson@redhat.com> 
 *
 *  BitKeeper ID: @(#)debug.c 1.2
 *
 *  CVS: $Revision: 1.6 $ $Date: 2016/02/10 19:25:51 $
 */

#include "defs.h"

static void debug_one(void);
static void db_send(char, ulong);
static void debug_blks(void);
static void debug_time(void);
static void debug_spin(void);


void
debug_test(void)
{
    register PROC_TABLE *tbl;
    int argc;
    char *argv[MAX_ARGV];
    char command[STRINGSIZE];

    tbl = &Shm->ptbl[ID];

    strcpy(command, tbl->i_file);

    if ((argc = parse(command, argv)) == 1)
	debug_one();

    switch (atoi(argv[1]))
    {
    case 1:
	debug_one();
	break;

    case 2:
	debug_blks();
	break;

    case 3:
	debug_time();
	break;

    case 4:
	debug_spin();
	break;

    case 5:
	_exit(5);

    default:  
	break;
    }

    _exit(INVAL_DEBUG_TEST);
}

static char *curses_before = "SIZE   MODE  999999999  waiting..  usex debug test        ";
static char *gtk_before = "                                                          ";
static char debug_msg[MESSAGE_SIZE];
static char banner[MESSAGE_SIZE*2];

static void
debug_one(void)
{
    register int i, j;
    register PROC_TABLE *tbl;
    char *before;
    tbl = &Shm->ptbl[ID];

    if (CURSES_DISPLAY())
	before = curses_before;
    if (GTK_DISPLAY())
	before = gtk_before;

    db_send(FSTAT, tbl->i_stat & IO_BKGD ? _BKGD_ : _OK_);

    sprintf(debug_msg, "< YOUR TEST HERE >");

    for (EVER) {
        io_send(FPASS, ++tbl->i_pass, NOARG, NOARG);
	db_send(FSIZE, (ulong)
        	"                                                          ");
 	db_send(FSIZE, (ulong)"SIZE");
        db_send(FMODE, (ulong)"MODE");
	db_send(FPOINTER, 111111111);
	db_send(FPOINTER, 222222222);
	db_send(FPOINTER, 333333333);
	db_send(FPOINTER, 444444444);
	db_send(FPOINTER, 555555555);
	db_send(FPOINTER, 666666666);
	db_send(FPOINTER, 777777777);
	db_send(FPOINTER, 888888888);
	db_send(FPOINTER, 999999999);
	db_send(FCLEAR, NOARG);
	db_send(FCOMPARE, NOARG);
	db_send(FREAD_, NOARG);
	db_send(FWRITE_, NOARG);
	db_send(FOPEN_, NOARG);
	db_send(FCLOSE, NOARG);
	db_send(FDELETE, NOARG);
	db_send(FIOCTL, NOARG);
	db_send(FSLEEP, NOARG);
	db_send(FSBRK, NOARG);
	db_send(FWAIT, NOARG);
	db_send(FILENAME, (ulong)"USEX");
	db_send(FILENAME, (ulong)"usex DEBUG");
	db_send(FILENAME, (ulong)"usex debug TEST");
	db_send(FILENAME, (ulong)"usex debug test");

	db_send(FSIZE, (ulong)before);

	for (i = 0, j = strlen(debug_msg)-1; i < strlen(debug_msg); i++, j--) {
	    strcpy(banner, before);
	    bcopy(&debug_msg[j], banner, strlen(&debug_msg[j]));
            db_send(FSIZE, (ulong)banner); 
	}

	for (i = 0; i < strlen(banner); i++) {
	    strcpy(banner, before);
	    bcopy(debug_msg, &banner[i], strlen(debug_msg));
            for (j = 0; j < i; j++)
	        banner[j] = ' ';
            banner[58] = (char)NULLCHAR;
            db_send(FSIZE, (ulong)banner); 
	}

	db_send(FSIZE, (ulong)
            "                                                          ");
    }
}


static void
db_send(char arg1, ulong arg2)
{
    register PROC_TABLE *tbl;
    tbl = &Shm->ptbl[ID];

    SEND_HEARTBEAT(ID);

    if (!(tbl->i_stat & IO_BKGD))
	io_send(arg1, arg2, NOARG, NOARG);
}

int
fdebug(char *file, char *s, int flag, int arg)
{
    FILE *fp;
    int exists;
    char tbuf[MESSAGE_SIZE*5];

    exists = file_exists(file);

    if ((fp = fopen(file, exists ? "a" : "w")) == NULL) 
        fatal(ID, file, errno);

    sys_time(tbuf);  /* If time is necessary, prepend this to next string. */

    fprintf(fp, "%s", s);   /* print the main string always */

    switch (flag)
    {
    case NOARG:
        fprintf(fp, "\n");
	break;
    case NUMBER_ARG:
        fprintf(fp, "%d (%08x)\n", arg, arg);
        break;
    case STRING_ARG:
        fprintf(fp, "%s\n", (char *)((ulong)arg));
        break;
    }

    fclose(fp);
 
    return(TRUE);
}

static void
debug_blks(void)
{
    register int i;
    char input[80], input2[100];
    register PROC_TABLE *tbl = &Shm->ptbl[ID];
    register PROC_TABLE *t;

    db_send(FSIZE, (ulong)
            "                                                          ");

    for (EVER) {
        io_send(FPASS, ++tbl->i_pass, NOARG, NOARG);
        bzero(input, 80); bzero(input2, 80);
        sprintf(input, "debug_blks: I_RINGBUFSIZE: %d  ", I_RINGBUFSIZE);
        for (i = 0; i < (Shm->procno-1); i++) {
            t = &Shm->ptbl[i];
	    sprintf(input2, "%d:%d ", i+1, t->i_blkcnt);
	    strcat(input, input2);
        }
        db_send(FSIZE, (ulong)input);
    }
}

static void
debug_time(void)
{
    char input[80];
    register PROC_TABLE *tbl = &Shm->ptbl[ID];
    time_t now;

    db_send(FSIZE, (ulong)
            "                                                          ");

    for (EVER) {
        io_send(FPASS, ++tbl->i_pass, NOARG, NOARG);
        bzero(input, 80);
	time(&now);
	sprintf(input, "%d", (uint)now);
        db_send(FSIZE, (ulong)input);
	sleep(1);
    }
}

static void
debug_spin(void)
{
    	register PROC_TABLE *tbl = &Shm->ptbl[ID];

	io_send (FILENAME, (long)"debug spin ========>end", NOARG, NOARG);
	for (EVER) {
         	io_send(FPASS, ++tbl->i_pass, NOARG, NOARG);
	}
}


void
debug_test_inquiry(int target, FILE *fp)
{
        fprintf(fp, "\nDEBUG TEST SPECIFIC:\n");
        fprintf(fp, "(unused)\n");   
}
