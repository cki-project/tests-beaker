/*  Author: David Anderson <anderson@redhat.com> */

#include "defs.h"

/*
 *  shell_mgr:  Repeatedly execute the shell command entered by the user.
 *
 *  BitKeeper ID: @(#)shell_mgr.c 1.5
 *
 *  CVS: $Revision: 1.9 $ $Date: 2016/02/10 19:25:52 $
 */

static void sh_pass(ulong);
static int sh_pass_strlen(ulong);
static void sh_kill_shell(int);
static void shell_fork_failure( PROC_TABLE *, int);
static int pipe_line(int, char *);


void
shell_mgr(int proc)
{
    register int i, j, k;
    register PROC_TABLE *tbl = &Shm->ptbl[proc];
    char command[MESSAGE_SIZE];
    int cstat, lp[2], out, child;
    char *argv[MAX_ARGV];
    int argc ATTRIBUTE_UNUSED;
    BOOL no_data;
    char buf[MAX_PIPELINE_READ + PIPELINE_PAD];
    time_t now;

    setpgid(getpid(), 0);   /* Ignore any error -- just continue. */

    ID = proc;

    time(&now);
    tbl->i_timestamp = now;
    tbl->i_pid = getpid();
    tbl->i_stat |= IO_START;

    tbl->shell_child = child = 0;
    signal(SIGUSR1, sh_kill_shell);
    signal(SIGINT, SIG_IGN);
    signal(SIGCHLD, SIG_DFL);

    strcpy(command, tbl->i_file);
    argc = parse(command, argv);
    sh_pass(tbl->i_pass = 1);

    for (EVER) {
	if (mother_is_dead(Shm->mompid, "S2")) { /* Mom's dead. */
	    fatal(ID, "mother is dead", 0);
	}

	if (tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING)) 
		put_test_on_hold(tbl, ID);

	tbl->i_stat |= IO_PIPE;
        if (pipe(lp) == -1) {                    /* Get a pipe to communicate */
            fatal(ID, "shell_mgr: pipe", errno);   /* with the child process. */
        }

	tbl->i_stat |= IO_FORK;

shell_fork:
	SEND_HEARTBEAT(ID);

        if ((child = fork()) == 0) {
            close(lp[0]);        /* Child has no use for "read" end of pipe. */
            close(1);            /* Child closes stdout. */
            close(2);            /* Child closes stderr. */
            dup(lp[1]);          /* Child's new stdout and stderr now becomes */
            dup(lp[1]);          /* the "write" end of pipe. */
            close(lp[1]);        /* Child then closes original "write" end. */
            sigset(SIGTERM, SIG_IGN);    /* Ignore parent signal mechanism. */
            sigset(SIGUSR1, SIG_IGN);    /* Ignore parent signal mechanism. */
	    sigset(SIGALRM, SIG_IGN);    /* Ignore parent signal mechanism. */
            sigset(SIGINT, SIG_IGN);     /* Listen to user's request. */
	    sigset(SIGHUP, SIG_DFL);     /* Broadcast to prgp on shutdown. */

	    sprintf(buf, "execvp(%s)", argv[0]);   /* Set up for failure. */
            execvp(command, argv);  /* execvp the command. */
            fatal(ID, buf, errno);  /* If it fails, "exit" back to shell_mgr. */
        }

	if (child == -1) {   /* fork() failed */
	    if (errno == EAGAIN) {
	        shell_fork_failure(tbl, USEX_FORK_FAILURE);
		goto shell_fork;
	    }
	    i = errno;
	    sprintf(buf, "shell_mgr: fork() of %s", command);
	    fatal(ID, buf, i);
	}

	tbl->i_stat &= ~(IO_PIPE|IO_FORK);
	tbl->i_stat |= IO_CHILD_RUN;

	tbl->shell_child = child;  /* Only parent touches shell_child. */
    
        close(lp[1]);   /* Close the "write" end of the pipe. */

        if (CURSES_DISPLAY() && (strlen(tbl->i_file) > 53)) {
	    char shortbuf[STRINGSIZE];

	    bzero(shortbuf, STRINGSIZE);
	    if (CURSES_DISPLAY()) {
	    	strncpy(shortbuf, tbl->i_file, 53);
	    	shortbuf[52] = '>';
	    } else 
	    	strcpy(shortbuf, tbl->i_file);

            sprintf(buf, "%c%c%s", FSHELL, tbl->i_local_pid, shortbuf);
	    if (CURSES_DISPLAY())
		strcat(buf, "  [");
        }
        else {
            sprintf(buf, "%c%c%s", FSHELL, tbl->i_local_pid, tbl->i_file);
	    if (CURSES_DISPLAY())
		strcat(buf, "  [");
	}

        out = CURSES_DISPLAY() ? strlen(buf) : 0;
    
        if (tbl->i_pass == 1) {
            strcpy(tbl->i_msgq.string, buf);
            tbl->i_msgq.string[0] = FSIZE;              /* Force display. */
	    if (CURSES_DISPLAY())
                tbl->i_msgq.string[strlen(buf)-1] = (char)NULLCHAR;
            sh_send(0);

            if (tbl->i_stat & IO_BKGD) 
                sprintf(tbl->i_msgq.string, "%c%c BKGD ", FSTAT, 
		    tbl->i_local_pid);
            else 
                sprintf(tbl->i_msgq.string, "%c%c  OK  ", FSTAT, 
                    tbl->i_local_pid);
            sh_send(0);
        } 

        no_data = TRUE;
        while ((k = pipe_line(lp[0], &buf[out])) > 0) {
            no_data = FALSE;
	    strip_lf(&buf[out]);

	    if (tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING)) {
		if (kill(child, SIGSTOP) == 0) {
		    put_test_on_hold(tbl, ID);
		    kill(child, SIGCONT);
		}
		else 
		    put_test_on_hold(tbl, ID);
	    }

            if (tbl->i_stat & IO_BKGD)
                continue;

	    if (CURSES_DISPLAY()) {
                for (j = strlen(buf); j < 60; j++)
                    buf[j] = ' ';
	        k = sh_pass_strlen(tbl->i_pass) <= 4 ? 59 :
		    59 - (sh_pass_strlen(tbl->i_pass) - 4);
                sprintf(&buf[k], "]  %4ld", tbl->i_pass);
                strcpy(tbl->i_msgq.string, buf);
	    }
	    if (GTK_DISPLAY()) {
		buf[out+80] = NULLCHAR;
                strip_lf(buf);
                mkstring(buf, 80, TRUNC|LJUST);
                sprintf(tbl->i_msgq.string, "%c%c%s", FSHELL, 
			tbl->i_local_pid, &buf[out]);
	    }
            sh_send(0);
        }
        close(lp[0]);

	tbl->i_stat &= ~IO_CHILD_RUN;
	tbl->i_stat |= IO_WAIT;
        wait(&cstat);
	tbl->i_cstat = cstat;
	tbl->i_stat &= ~IO_WAIT;
	tbl->i_stat |= IO_ADMIN2;
        
        /*
         *  Some commands always return a non-zero status, but we
         *  still want to run with impunity.
         */
        if (tbl->i_message == IGNORE_NONZERO_EXIT)
            cstat = 0;

        switch (cstat & 0xff)
        {
        case 0x00:      /* exit - high order 8 bits contain exit status */
            if (cstat & 0xff00) {
                sprintf(buf, "user command returned exit status: %d", 
	            (cstat & 0xff00) >> 8);
	        paralyze(ID, buf, 0);
            }
            break;

        case 0x7f:      /* stopped - high order 8 bits contain signal */
            sprintf(tbl->i_msgq.string, "%c%c STOP ", FSTAT, tbl->i_local_pid);
            sh_send(0);
            break;

        default:      /* terminated due to this signal - high order 8 is 00 */

            tbl->i_stat &= ~IO_BKGD;
	    if (CURSES_DISPLAY()) {
                for (i = 0; buf[i] != '['; )
                    i++;
                sprintf(&buf[++i], "terminated by signal: %d  ",
                    cstat & 0x7f);
                for (j = strlen(buf) - 1; j < 60; j++)
                    buf[j] = ' ';
                k = sh_pass_strlen(tbl->i_pass) <= 4 ? 59 :
                    59 - (sh_pass_strlen(tbl->i_pass) - 4);
                sprintf(&buf[k], "]  %4ld", tbl->i_pass);
                strcpy(tbl->i_msgq.string, buf);
	    }
	    if (GTK_DISPLAY()) {
                sprintf(buf, "terminated by signal: %d  ",
                    cstat & 0x7f);
                sprintf(tbl->i_msgq.string, "%c%c%s", FSHELL, 
			tbl->i_local_pid, buf);
	    }
            sh_send(0);
            sprintf(buf, "shell command terminated by signal: %d", 
	        cstat & 0x7f);
	    paralyze(ID, buf, 0);
        }

        tbl->shell_child = child = 0;  /* Clear records of child existence. */

        if ((tbl->i_stat & IO_BKGD) || no_data) {
            sprintf(tbl->i_msgq.string, "%c%c%4ld", FPASS, 
            tbl->i_local_pid, tbl->i_pass);
            sh_send(0);
        }

        sh_pass(++(tbl->i_pass));

	tbl->i_stat &= ~IO_ADMIN2;
    }
}


static void
sh_pass(ulong pass)
{
    register PROC_TABLE *tbl = &Shm->ptbl[ID];

    sprintf(tbl->i_msgq.string,"%c%c%4ld", FPASS, tbl->i_local_pid, pass);
    sh_send(0);
}

static int 
sh_pass_strlen(ulong pass)
{
	char buf[STRINGSIZE];

	sprintf(buf, "%ld", pass);
	return(strlen(buf));
}

void
sh_send(int sync)
{
    register PROC_TABLE *tbl = &Shm->ptbl[ID];

    SEND_HEARTBEAT(ID);

    /* Stash the time and message into the message storage queue */

    bzero(tbl->i_last_message[tbl->i_post], STRINGSIZE);
    time(&tbl->i_last_msgtime[tbl->i_post]);
    strncpy(tbl->i_last_message[tbl->i_post], tbl->i_msgq.string,
        min(strlen(tbl->i_msgq.string), STRINGSIZE));
    tbl->i_post = (tbl->i_post+1) % I_POSTAGE;

    tbl->i_stat |= SENDING;

    switch (Shm->mode & IPC_MODE)
    {
    case PIPE_MODE:
        pipe_write(Shm->win_pipe[ID_TO_PIPE], tbl->i_msgq.string, 
            strlen(tbl->i_msgq.string)+1);
	break;

    case MESGQ_MODE:
        if (msgsnd(tbl->i_msg_id, (struct msgbuf *)&tbl->i_msgq,
            MESSAGE_SIZE, 0) == -1 && (errno != EINTR)) {
            fatal(ID, "shell_mgr: msgsnd", errno);
        }
	break;

    case MMAP_MODE:
    case SHMEM_MODE:
        shm_write(RING_IO(ID),tbl->i_msgq.string,strlen(tbl->i_msgq.string)+1);
	break;
    }

    tbl->i_stat &= ~SENDING;

    if (sync)
	synchronize(ID, NULL);
}

static void
sh_kill_shell(int unused)
{
    PROC_TABLE *tbl = &Shm->ptbl[ID];
    int status;

    tbl->i_stat |= IO_DYING;

    if (tbl->shell_child) {
        Kill(tbl->shell_child, SIGKILL, "S1", K_IO(ID));
        wait(&status);
    }

    tbl->i_stat &= ~IO_DYING;
    tbl->i_stat |= IO_DEAD;
    set_time_of_death(ID);

    sigset(SIGHUP, SIG_IGN);
    kill(-getpgrp(), SIGHUP);

    _exit(SH_KILL_SHELL);  /* NOTREACHED */
}

#ifdef USELESS
char *clean  = "                                                          ";
#endif

static void
shell_fork_failure( PROC_TABLE *tbl, int who)
{
    char eagain[80];
    int pad;

    sprintf(tbl->i_msgq.string, "%c%c<WARN>", 
	MANDATORY_FSTAT, tbl->i_local_pid);
    sh_send(SYNCHRONIZE); 

    if (who == USEX_FORK_FAILURE) {
	sprintf(eagain, "usex: fork: %s", strerror(EAGAIN));
	if (CURSES_DISPLAY()) {
            pad = sh_pass_strlen(tbl->i_pass) <= 4 ? 58 :
                58 - (sh_pass_strlen(tbl->i_pass) - 4);
            space_pad(eagain, pad);
            sprintf(tbl->i_msgq.string, 
    	    "%c%c%s  %4ld <WARN>", MANDATORY_FSHELL, tbl->i_local_pid, eagain,
		tbl->i_pass);
	}
	if (GTK_DISPLAY()) {
            sprintf(tbl->i_msgq.string, "%c%c%s", 
		MANDATORY_FSHELL, tbl->i_local_pid, eagain);
	}
        sh_send(SYNCHRONIZE); 
    }

    sleep(5);

    sprintf(tbl->i_msgq.string, "%c%c %s ", 
	MANDATORY_FSTAT, tbl->i_local_pid,
	tbl->i_stat & IO_BKGD ? "BKGD" : " OK ");
    sh_send(0);
}


void
shell_cmd_inquiry(int target, FILE *fp)
{
        PROC_TABLE *tbl = &Shm->ptbl[target];

        fprintf(fp, "\nUSER SPECIFIC:\n");
        fprintf(fp, "shell_child: %d\n", tbl->shell_child);
}


/*
 * pipe_line:  Read the child's output from the the common pipe, and 
 *             copy the output a line at a time to the mother's buffer.
 */

static int
pipe_line(int pipe, char *buffer)
{
    register int throw_away = FALSE;  /* Character throw_away flag. */
    register int count = 0;           /* Character counter. */
    char c;                           /* Character holder.  */
    char *start = buffer;
    register PROC_TABLE *tbl = &Shm->ptbl[ID];

    for (EVER)
    {
        switch (read(pipe, &c, 1))
        {
            case -1:            /* The read failed */
		if (errno == EINTR)  
			continue;
		return(-1);

            case  0:            /* The pipe was empty. */
                return(-1);

            default:              
		if (throw_away) {
		    if (c == (char)NULLCHAR || c == '\n') 
			goto stash_message;
		    else
			break;
		}
                                  /* Keep reading characters until a */
                if (c < ' ') {    /* NULL or a LINEFEED is read. */
                    switch (c) 
                    {
                    case '\0':
                        *buffer++ = c;
                        goto stash_message;
                    case '\n':
                        *buffer++ = c;
                        count++;
                        *buffer = (char)NULLCHAR;
                        goto stash_message;
                    case '\t':
                        sprintf(buffer, "    ");
                        buffer += 4;
                        count += 4;
                        break;
		    case '\b':
			if (count) {
			    buffer--;
			    count--;
			}
			break;
                    default:
                        *buffer++ = '^';
                        *buffer++ = c + '@';
                        count += 2;
                    }
                }
                else {
                    *buffer++ = c;
                    count++;
                }

	        break;	
        }

	if (count >= (MAX_PIPELINE_READ)) {
	    throw_away = TRUE;
	    *buffer = (char)NULLCHAR;
	}
    }

stash_message:


    if (tbl->i_stat & IO_BKGD) {
        bzero(tbl->i_last_message[tbl->i_post], STRINGSIZE);
        time(&tbl->i_last_msgtime[tbl->i_post]);
        tbl->i_last_message[tbl->i_post][0] = BKGD_POST;
        strncpy(&tbl->i_last_message[tbl->i_post][1], start,
            min(strlen(start), STRINGSIZE-1));
        tbl->i_post = (tbl->i_post+1) % I_POSTAGE;
    }

    return(count);
}
