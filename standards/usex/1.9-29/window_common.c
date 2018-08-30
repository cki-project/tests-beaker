/*  Author: David Anderson <anderson@redhat.com> */

/*
 *  Collection of functions that are used in common by the output display
 *  window manager functions, currently curses_mgr() and and gtk_mgr().  
 *  There are also a number of as GTK-assist functions that are called 
 *  from within gtk_mgr.c, which has no concept of "defs.h" and
 *  therefore the inner workings of usex.
 *
 *  CVS: $Revision: 1.19 $ $Date: 2016/02/10 19:25:53 $
 */

#ifdef _GTK_
#include "gtk/gtk.h"
#endif
#include "defs.h"
#ifdef _GTK_
#include "gtk_mgr.h"
#endif

static void show_time_data(void);
static void one_minute_refresh(void);
static int allow_sys_stats_display(void);

/*
 *  Perform any remaining initializations that are common to both the
 *  curses-based and GTK-based display modes.  Most important is the
 *  release of the children to run wild...
 */
void
init_common(void)
{
    register int i;
    int iflags;

   /*
    * Forbid communications with tests that were never spawned.
    */
    for (i = 0; i < MAX_IO_TESTS; i++)
       if (Shm->ptbl[i].i_pid == NOT_RUNNING)
           Shm->ptbl[i].i_stat |= IO_DEAD;

    if (Shm->mode & PIPE_MODE) {
        for (i = 0; i < NUMSG; i++) {
	    if (Shm->win_pipe[i*2] == -1)
		continue;
            if ((iflags = fcntl(Shm->win_pipe[i*2], F_GETFL, 0)) == -1)
                Shm->perror("fcntl(F_GETFL)");
            if ((iflags = fcntl(Shm->win_pipe[i*2], F_SETFL, iflags|O_NDELAY))
                == -1)
                Shm->perror("fcntl(F_SETFL)");
            if ((iflags = fcntl(Shm->win_pipe[i*2], F_GETFL, 0)) == -1)
                Shm->perror("fcntl(F_GETFL)");
        }
    }

    if (Shm->niceval)         /* Nice the window manager by requested amount. */
        nice(Shm->niceval);

    Shm->mode &= ~(CHILD_HOLD);
}

/*
 *  Perform any USEX timer-requested functions. 
 */
void
do_timer_functions(void)
{
    	struct timer_request *treq = &Shm->timer_request;

	show_time_data();
    
    	if (treq->requests & TIMER_REQ_STOP_USEX) {
                common_kill(KILL_ALL, SHUTDOWN);  
                die(0, DIE(21), GTK_DISPLAY() ? TRUE : FALSE);           
		return;
    	}
    
    	if (treq->requests & TIMER_REQ_REFRESH) {
                if (!(Shm->mode & (DEBUG_MODE|NO_REFRESH_MODE))) 
			one_minute_refresh();
    	}
    
    	if (treq->requests & TIMER_REQ_LOAD_AVG)
    		show_load_average();

        if (treq->requests & TIMER_REQ_FREE_MEM)
                show_free_memory();

        if (treq->requests & TIMER_REQ_CPU_STATS)
                show_cpu_stats(GET_RUNTIME_STATS);

    	if (treq->requests & TIMER_REQ_CALLBACK) 
		timer_req_callback(treq);
}

/*
 *  Each second, display the data, time, and test run-time.
 */
static void
show_time_data(void)
{
    	struct timer_request *treq = &Shm->timer_request;

        if (!allow_sys_stats_display())
		return;

#ifdef _CURSES_
        mvwaddstr(Window.Date, 0, 0, treq->sys_date);
        DISPLAY(Window.Date);
        mvwaddstr(Window.Stime, 0, 0, treq->sys_time);
        DISPLAY(Window.Stime);
        mvwaddstr(Window.Test_Time, 0, 0, treq->run_time);
        DISPLAY(Window.Test_Time);
#endif
#ifdef _GTK_
	gtk_label_set_text(GTK_LABEL(Shm->wmd->datebox), treq->sys_date);
	gtk_label_set_text(GTK_LABEL(Shm->wmd->timebox), treq->sys_time);
	gtk_label_set_text(GTK_LABEL(Shm->wmd->test_time), treq->run_time);
#endif
}

/*
 *  The timer sends out a refresh signal each second, allowing the output
 *  display type to determine what, if anything, to do with it.
 */
static void
one_minute_refresh(void)
{
#ifdef _CURSES_
	refresh();
	wrefresh(curscr);
#endif
#ifdef _GTK_
	;  /* NOT APPLICABLE */
#endif
}


/* 
 *  Ignore a message, post a message, or ignore the message and retry the queue.
 */
int
verify_message(int id, unsigned char cmd, char *buffer)
{ 
	if (!IO_TEST(cmd))
		return POST_MESSAGE;
		
	if (id < 0 || id >= Shm->procno) {
		unresolved(buffer, id);
		return IGNORE_MESSAGE;
        }

        if (Shm->ptbl[id].i_stat & IO_DEAD)  /* Process is history. */
                return IGNORE_MESSAGE;

        if (Shm->ptbl[id].i_stat & (IO_BKGD|IO_HOLD|IO_HOLD_PENDING)) {
		
               	switch (cmd)
               	{
		case FILENAME:
			if (Shm->ptbl[id].i_type & (DISK_TEST|RATE_TEST))
				return POST_MESSAGE;
			else
			    	return IGNORE_MESSAGE;

		case FOPERATION:
			if (Shm->ptbl[id].i_type & 
		            (VMEM_TEST|RATE_TEST|WHET_TEST))
				return POST_MESSAGE;
			else
			    	return IGNORE_MESSAGE;

                case FSIZE:
			if (Shm->ptbl[id].i_type == DEBUG_TEST)
			    return IGNORE_MESSAGE;
                case FSTAT:
                case FPASS:     /* Let these guys through. */
		case FTRUN:
		case FFILL:
                case FERROR:
		case FCLEAR:
			return POST_MESSAGE;

                default:
			return RETRY_QUEUE;
               	}
	}

	return POST_MESSAGE;
}

/*
 *  Common usex process kill-off function.  
 */
void
common_kill(int arg1, int arg2)
{
    register int i, j;
    time_t otime, etime, stime, wtime;
    int stragglers = 0;
    int do_sysrq_t = 0;
    char buf[MESSAGE_SIZE];

    switch (arg1)
    {
    case KILL_ALL:
	if (Shm->mode & RHTS_HANG_TRACE) {
        	for (i = 0; i < Shm->procno; i++) {
	    		if (Shm->ptbl[i].i_stat & HANG) {
				do_sysrq_t++;
				break;
			}
		}
		if (do_sysrq_t)
			system("echo t > /proc/sysrq-trigger");	
	}

        if (!(Shm->mode & SCREEN_SAVED))
            save_screen(SCREEN_SAVED);

        if (arg2 == SHUTDOWN) {
            USER_MESSAGE_WAIT("killing all tests...");
	    Shm->mode |= SHUTDOWN_MODE;
	}
    
        for (i = 0; i < Shm->procno; i++) {
            if (Shm->ptbl[i].i_pid == NOT_RUNNING) 
		continue;
	    if (!(Shm->ptbl[i].i_stat & IO_DEAD)) {
	        sprintf(buf, "killing test %d", i+1);
		USER_MESSAGE_WAIT(buf);
		Shm->ptbl[i].i_stat |= EXPLICIT_KILL;	
            	if (Shm->ptbl[i].i_pid) {
                    Kill(Shm->ptbl[i].i_pid, SIGUSR1, "W7", K_IO(i));
		    if (!Shm->ptbl[i].i_internal_kill_source)
		        Shm->ptbl[i].i_internal_kill_source = 
			    "common_kill: KILL_ALL #1";
		}
	    }
	}

        for (i = 0; i < Shm->procno; i++) {    /* Kill everything. */
            if (Shm->ptbl[i].i_pid == NOT_RUNNING) 
		continue;
            if (Shm->ptbl[i].i_pid) {
                if (!(Shm->ptbl[i].i_stat & IO_DEAD)) {
                    if ((Shm->ptbl[i].i_type == BIN_TEST) &&
		        strlen(Shm->ptbl[i].curcmd)) { 
			switch (Shm->mode & (CINIT|GINIT))
			{
			case CINIT:
#ifdef _CURSES_
                            mvwaddstr(Window.P[i].action, 0, _SIZE,
                                Shm->ptbl[i].curcmd);
                            wrefresh(Window.P[i].action);
#endif
			    break;
			case GINIT:  
#ifdef _GTK_
                	    gtk_label_set_text(GTK_LABEL
				(gtk_mgr_test_widget(i, FSIZE, 
				Shm->ptbl[i].curcmd)), Shm->ptbl[i].curcmd);
#endif
			    break;
			}
                    }
		    post_test_status(i, "(WAIT)");
                }
		else {
		    set_time_of_death(i);
		    post_test_status(i, "<DEAD>");
		    sprintf(buf, "test %d dead", i+1);
		    USER_MESSAGE_WAIT(buf);
 		}
                if ((Shm->ptbl[i].i_type != VMEM_TEST) &&
                    (Shm->ptbl[i].i_pass > 0)) {
		    char curpass[STRINGSIZE];
		    sprintf(curpass, "%4ld", Shm->ptbl[i].i_pass);
		    j = strlen(curpass) > 4 ? 
			_PASS - (strlen(curpass) - 4) : _PASS;
                    switch (Shm->mode & (CINIT|GINIT))
                    {
                    case CINIT:
#ifdef _CURSES_
                        mvwaddstr(Window.P[i].action, 0, j, curpass);
                        DISPLAY(Window.P[i].action);
#endif
			break;
		    case GINIT:  
#ifdef _GTK_
                        gtk_label_set_text(GTK_LABEL
                                (Shm->wmd->test_data[i].pass),
                                strip_beginning_whitespace(curpass));
#endif
			break;
		    }
		}
            }
        }
    
        for (i = 0; i < Shm->procno; i++) {   /* Wait until funeral's over... */
            if (Shm->ptbl[i].i_pid == NOT_RUNNING) 
		continue;
            if (Shm->ptbl[i].i_pid) {
                time(&stime);
                otime = etime = stime;
		wtime = 10;
                while (1) {
                    if ((Shm->ptbl[i].i_stat & IO_DEAD) || 
                        (Kill(Shm->ptbl[i].i_pid, 0, "W8", K_IO(i)) != 0)) {
		        set_time_of_death(i);
                        Shm->ptbl[i].i_stat |= IO_DEAD;
		        post_test_status(i, "<DEAD>");
                        break;
                    }
                    if (Shm->ptbl[i].i_stat & IO_DYING) {
                        if (wtime == 10) {
                            if ((Shm->ptbl[i].i_type == BIN_TEST) &&
			        strlen(Shm->ptbl[i].curcmd)) {
                                switch (Shm->mode & (CINIT|GINIT))
                                {
                                case CINIT:
#ifdef _CURSES_
                                    mvwaddstr(Window.P[i].action, 0, _SIZE, 
                                        Shm->ptbl[i].curcmd);
                                    wrefresh(Window.P[i].action);
#endif
				    break;
			        case GINIT:  
#ifdef _GTK_
                                    gtk_label_set_text(GTK_LABEL
                                         (gtk_mgr_test_widget(i, FSIZE,
                                         Shm->ptbl[i].curcmd)), 
				         Shm->ptbl[i].curcmd);
#endif
				    break;
				}
			    }
			}
			wtime = 15;
		    }
		    else {
                        Kill(Shm->ptbl[i].i_pid, SIGUSR1, "W9", K_IO(i));
                        if (!Shm->ptbl[i].i_internal_kill_source)
                            Shm->ptbl[i].i_internal_kill_source = 
			        "common_kill: KILL_ALL #2";
		    }
                    time(&etime);
                    if (etime != otime) {
                        otime = etime;
			post_test_status(i, "(WAIT)");
                    }
                    if ((etime - stime) >= wtime) {
		        post_test_status(i, "(KILL)");
			stragglers++;
                        break;
                    }
                    if (stragglers) {
                        for (j = 0; j < i; j++) {    
                            if (Shm->ptbl[j].i_stat & IO_DEAD) {
		                set_time_of_death(i);
            		        continue;
                            }
                            if (Kill(Shm->ptbl[j].i_pid, 0, "W10", K_IO(j))) {
		                set_time_of_death(i);
                                Shm->ptbl[j].i_stat |= IO_DEAD;
		                post_test_status(i, "<DEAD>");
		                sprintf(buf, "test %d dead", i+1);
		                USER_MESSAGE_WAIT(buf);
                            }
                        }
                    }
                }

                if ((Shm->ptbl[i].i_type == DISK_TEST) &&
                     !(file_exists(Shm->ptbl[i].i_errfile)) &&
		     !SPECIAL_FILE(Shm->ptbl[i].i_sbuf.st_mode))
                     delete_file(Shm->ptbl[i].i_file, NOT_USED);
            }
        }

	wtime = 5;
        while (stragglers && wtime) {
	    stragglers = 0;
            for (i = 0; i < Shm->procno; i++) {    /* Try once more... */
                if (Shm->ptbl[i].i_pid == NOT_RUNNING) 
		    continue;
                if (Shm->ptbl[i].i_stat & IO_DEAD) {
		    set_time_of_death(i);
		    post_test_status(i, "<DEAD>");
		    sprintf(buf, "test %d dead", i+1);
		    USER_MESSAGE_WAIT(buf);
    		    continue;
		}
                if (Kill(Shm->ptbl[i].i_pid, 0, "W13", K_IO(i)) != 0) {
		    set_time_of_death(i);
                    Shm->ptbl[i].i_stat |= IO_DEAD;
		    post_test_status(i, "<DEAD>");
		    sprintf(buf, "test %d dead", i+1);
		    USER_MESSAGE_WAIT(buf);
                }
		else
		    stragglers++;
            }
	    if (stragglers) {
		sleep(1);
		wtime--;
	    }
        }
	USER_MESSAGE_WAIT("all tests are dead");
        break;

    default:
        i = arg1;
        if (Shm->ptbl[i].i_pid == NOT_RUNNING) 
	    break;
	if (!(Shm->ptbl[i].i_stat & IO_DEAD))
	    Shm->ptbl[i].i_stat |= EXPLICIT_KILL;	
        Kill(Shm->ptbl[i].i_pid, SIGUSR1, "W14", K_IO(i));
        if (!Shm->ptbl[i].i_internal_kill_source)
	        Shm->ptbl[i].i_internal_kill_source = 
		    "common_kill: explicit #1";

        if ((Shm->ptbl[i].i_type == BIN_TEST) &&
	    !(Shm->ptbl[i].i_stat & IO_DEAD)) {
            if (strlen(Shm->ptbl[i].curcmd)) {
                switch (Shm->mode & (CINIT|GINIT))
                {
                case CINIT:
#ifdef _CURSES_
                    mvwaddstr(Window.P[i].action, 0, _SIZE, 
			Shm->ptbl[i].curcmd);
                    wrefresh(Window.P[i].action);
#endif
		    break;
	        case GINIT:  
#ifdef _GTK_
                    gtk_label_set_text(GTK_LABEL
			(gtk_mgr_test_widget(i, FSIZE, Shm->ptbl[i].curcmd)), 
			Shm->ptbl[i].curcmd);
#endif
		    break;
		}
            }
	    post_test_status(i, "(WAIT)");
        }
        else {
            set_time_of_death(i);
	    post_test_status(i, "<DEAD>");
        }

        time(&stime);
        otime = etime = stime;
	wtime = 10;
        while (1) {
            if ((Shm->ptbl[i].i_stat & IO_DEAD) ||
                (Kill(Shm->ptbl[i].i_pid, 0, "W15", K_IO(i)) != 0)) {
		set_time_of_death(i);
	        post_test_status(i, "<DEAD>");
                Shm->ptbl[i].i_stat |= IO_DEAD;
                break;
            }
            if (Shm->ptbl[i].i_stat & IO_DYING) {
		if (wtime == 10) {
                    if ((Shm->ptbl[i].i_type == BIN_TEST) &&
			strlen(Shm->ptbl[i].curcmd)) {
			switch (Shm->mode & (CINIT|GINIT))
                        {
                        case CINIT:
#ifdef _CURSES_
                            mvwaddstr(Window.P[i].action, 0, _SIZE, 
                                Shm->ptbl[i].curcmd);
                            wrefresh(Window.P[i].action);
#endif
			    break;
			case GINIT:  
#ifdef _GTK_
                            gtk_label_set_text(GTK_LABEL
                                (gtk_mgr_test_widget(i, FSIZE, 
				Shm->ptbl[i].curcmd)), Shm->ptbl[i].curcmd);
#endif
			    break;
			}
    		    }
		}
		wtime = 15;
            }
	    else {
                Kill(Shm->ptbl[i].i_pid, SIGUSR1, "W16", K_IO(i));
                if (!Shm->ptbl[i].i_internal_kill_source)
                    Shm->ptbl[i].i_internal_kill_source = 
			"common_kill: explicit #2";

	    }
	    post_test_status(i, "(WAIT)");
            time(&etime);
            if (etime != otime) {
                otime = etime;
                post_test_status(i, etime & 1 ? "(----)" : "(WAIT)");
            }
            if ((etime - stime) >= wtime) {
		post_test_status(i, "(KILL)");
                Kill(Shm->ptbl[i].i_pid, SIGKILL, "W17", K_IO(i));
                break;
            }
        }

        if (Shm->ptbl[i].i_type == BIN_TEST)
            bin_cleanup(i, EXTERNAL);

        if ((Shm->ptbl[i].i_type == DISK_TEST) &&
            !(file_exists(Shm->ptbl[i].i_errfile)) &&
            !SPECIAL_FILE(Shm->ptbl[i].i_sbuf.st_mode))
            delete_file(Shm->ptbl[i].i_file, NOT_USED);

        break;
    }

    if (!(Shm->mode & (DEBUG_MODE|NO_REFRESH_MODE))) {
        switch (Shm->mode & (CINIT|GINIT))
        {
        case CINIT:
#ifdef _CURSES_
            refresh();
            wrefresh(curscr);
#endif
	    break;
        case GINIT:  /* NOT APPLICABLE */
            break;
        }
    }
}

void
set_time_of_death(int i)
{
	char timebuf[STRINGSIZE];
	char datebuf[STRINGSIZE];

	sys_time(timebuf);
	sys_date(datebuf);

	if (i < MAX_IO_TESTS) {
		if (strlen(Shm->ptbl[i].i_time_of_death) == 0)
			sprintf(Shm->ptbl[i].i_time_of_death, "%s@%s",
				strip_beginning_whitespace(datebuf), timebuf);
	}
}

/*
 *  Child-death signal catcher.
 */
void
sigchld(int sig) 
{
	register int i;
        pid_t pid;
        int status, how; 
	int exit_status, signal_received;
	int corpse, *sigrec_ptr, *exitstat_ptr, *demise_ptr;

	console("sigchld: SIGCHLD received\n");

	while (TRUE) {

		how = 0;
		corpse = -1;
	
	        if ((pid = waitpid(-1, &status, WNOHANG)) <= 0) 
	                return;        
	
		if (WIFEXITED(status)) {
			how = BY_EXIT;
			exit_status = WEXITSTATUS(status);
			console("  sigchld: exit status %d => ", exit_status);
		} else if (WIFSIGNALED(status)) {
			how = BY_SIGNAL;
			signal_received = WTERMSIG(status);
			console("  sigchld: signal %d => ", signal_received);
		} else if (WIFSTOPPED(status)) {
			how = BY_STOP;
			signal_received = WSTOPSIG(status);
			console("  sigchld: (stopped) signal %d => ", 
				signal_received);
		} else {
			console("???\n");
			continue;        /* log this... */
		}
	
		/*
		 *  Find the corpse and get his address...
		 */
	    	for (i = 0; i < Shm->procno; i++) {
			if (Shm->ptbl[i].i_pid == pid) {
				corpse = i;
				sigrec_ptr = &Shm->ptbl[i].i_signal_received;
				exitstat_ptr = &Shm->ptbl[i].i_exit_status;
				demise_ptr = &Shm->ptbl[i].i_demise;
				console("test %d (%d)\n", i+1, pid);
			        Shm->ptbl[i].i_stat |= IO_DEAD;
			}
		}
	
		if (corpse == -1) {
			console("non-usex target pid: %d\n", pid);
			continue;
		}
	
		switch (how)
		{
		case BY_EXIT:
			if (*demise_ptr == 0)
				*demise_ptr = BY_EXIT;
			*exitstat_ptr = exit_status;
			break;
	
		case BY_SIGNAL:
			if (signal_received == SIGUSR1)  {
			    	if (*demise_ptr == 0)
					*demise_ptr = BY_SIGNAL;
			} else
				*demise_ptr = BY_SIGNAL;
			*sigrec_ptr = signal_received;
			break;
	
		case BY_STOP:
			*demise_ptr = BY_STOP;
			*sigrec_ptr = signal_received;
			break;
		}
	}
}  

#ifdef _CURSES_

#define CLEAR_LINE \
"******************************************************************************"

#define CLEAR_DEBUG_MESSAGE()                             \
	mvwaddstr(Window.Debug_Window, 0, 0, CLEAR_LINE); \
        wrefresh(Window.Debug_Window);                 

#define DISPLAY_DEBUG_MESSAGE()                        \
        len = (COLS - strlen(buffer1))/2;              \
        CLEAR_STRING(buffer2);                         \
        while (strlen(buffer2) < len)                  \
        	strcat(buffer2, "*");                  \
        strcat(buffer2, buffer1);                      \
        while (strlen(buffer2) < (COLS-2))             \
	        strcat(buffer2, "*");	               \
	mvwprintw(Window.Debug_Window, 0, 0, buffer2); \
        wrefresh(Window.Debug_Window);                 
#endif

#ifdef _GTK_
#define CLEAR_DEBUG_MESSAGE()     gtk_mgr_status_bar_message("")
#define DISPLAY_DEBUG_MESSAGE()   gtk_mgr_status_bar_message(buffer1)
#endif

void 
debug_message(ulong arg1, ulong arg2)
{
	char buffer1[STRINGSIZE];
#ifdef _CURSES_
	char buffer2[STRINGSIZE];
	int len; 
#endif
	int duration, command; 
	

	if (!WINDOW_MGR()) {
	    synchronize(ID, (char *)arg2);
	    return;
	}

	command = (int)arg1 & DMESG_MASK;
	duration = ((int)arg1) >> DURATION_SHIFT;

#ifdef _CURSES_
	/*
         *  If the debug line is in use, re-queue this request to fire off
         *  when it's scheduled to become available.
	 */
        if (Shm->debug_message_inuse && !DMESG_URGENT(command)) {
                set_timer_request(Shm->debug_message_inuse, 
			debug_message, arg1, arg2);
                return;
        }

	Shm->mode |= WINUPDATE;

	switch (command)
	{
	case DMESG_CLEAR:
		CLEAR_DEBUG_MESSAGE();
		Shm->debug_message_inuse = duration;
                break; 

	case DMESG_STAT:
		if (arg2 < Shm->statnum)  /* bail out if already superceded */
			return;
		CLEAR_DEBUG_MESSAGE();
		Shm->debug_message_inuse = duration;
       		sprintf(buffer1, 
		    "[ current test status dumped in: ux%06d_status.%ld ]",
			Shm->mompid, arg2);
		DISPLAY_DEBUG_MESSAGE();
		break;

	case DMESG_CONSOLE:
		CLEAR_DEBUG_MESSAGE();
		Shm->debug_message_inuse = duration;
                sprintf(buffer1, "[ cannot access console device: %s ]", 
			Shm->console_device);
                DISPLAY_DEBUG_MESSAGE();
		break;

	case DMESG_MEMINFO:
		CLEAR_DEBUG_MESSAGE();
		Shm->debug_message_inuse = duration;
                sprintf(buffer1,
                     "[ vmem test: unexpected /proc/meminfo output ]");
		DISPLAY_DEBUG_MESSAGE();
		break;

        case DMESG_IMMEDIATE:
	case DMESG_QUEUE:
                CLEAR_DEBUG_MESSAGE();
                Shm->debug_message_inuse = duration;
                sprintf(buffer1, "[ %s ]", (char *)arg2);
                DISPLAY_DEBUG_MESSAGE();
		break;
	}
#endif

#ifdef _GTK_
	/*
         *  If the debug line is in use, re-queue this request to fire off
         *  when it's scheduled to become available.
	 */
        if (Shm->debug_message_inuse && !DMESG_URGENT(command)) {
                set_timer_request(Shm->debug_message_inuse, 
			debug_message, arg1, arg2);
                return;  
        }

	switch (command)
	{
	case DMESG_CLEAR:
		CLEAR_DEBUG_MESSAGE();
		Shm->debug_message_inuse = duration;
                break; 

	case DMESG_STAT:
		if (arg2 < Shm->statnum)  /* bail out if already superceded */
			return;
		Shm->debug_message_inuse = duration;
       		sprintf(buffer1, 
		    "current test status dumped in: ux%06d_status.%ld",
			Shm->mompid, arg2);
		DISPLAY_DEBUG_MESSAGE();
		break;

	case DMESG_CONSOLE:
		Shm->debug_message_inuse = duration;
                sprintf(buffer1, "cannot access console device: %s", 
			Shm->console_device);
                DISPLAY_DEBUG_MESSAGE();
		break;

	case DMESG_MEMINFO:
		Shm->debug_message_inuse = duration;
                sprintf(buffer1,
                     "vmem test: unexpected /proc/meminfo output");
		DISPLAY_DEBUG_MESSAGE();
		break;

        case DMESG_IMMEDIATE:
	case DMESG_QUEUE:
                Shm->debug_message_inuse = duration;
                sprintf(buffer1, "%s", (char *)arg2);
                DISPLAY_DEBUG_MESSAGE();
		break;
	}
#endif
}


#define CLEAR_PROMPT_MESSAGE()                             \
        mvwaddstr(Window.Prompt_Window, 0, 0, CLEAR_LINE); \
        wrefresh(Window.Prompt_Window);                    \
        CLEAR_STRING(Shm->prompt);

#define DISPLAY_PROMPT_MESSAGE()                        \
        len = (COLS - strlen(buffer1))/2;               \
        CLEAR_STRING(buffer2);                          \
        while (strlen(buffer2) < len)                   \
                strcat(buffer2, "*");                   \
        strcat(buffer2, buffer1);                       \
        Shm->prompt_x = strlen(buffer2) - 3;            \
        while (strlen(buffer2) < (COLS-2))              \
                strcat(buffer2, "*");                   \
        mvwprintw(Window.Prompt_Window, 0, 0, buffer2); \
        wrefresh(Window.Prompt_Window);


void
prompt_message(char *s, int done)
{
#ifdef _CURSES_
       	char buffer1[STRINGSIZE];
       	char buffer2[STRINGSIZE];
       	int len;
#endif

        if (GTK_DISPLAY()) {
            return;   /* TODO */
        }

#ifdef _CURSES_
	if (!s) {
		CLEAR_PROMPT_MESSAGE();
		return;		
	}
	
       	if (Shm->mode & WINUPDATE)
                Shm->mode &= ~WINUPDATE;
       	else if (!done) {
                wmove(Window.Prompt_Window, 0, Shm->prompt_x);
                wrefresh(Window.Prompt_Window);
                return;
       	}

	if (done || !streq(s, Shm->prompt)) {
                strcpy(Shm->prompt, s);
		sprintf(buffer1, done ? "[ %s ]" : "[ %s  ]", s);
                DISPLAY_PROMPT_MESSAGE();
        }
#endif
}

/*
 *  Update a test's status.
 */
void
post_test_status(int id, char *s)
{
    char buffer[MESSAGE_SIZE];

    if (WINDOW_MGR()) {
        switch (Shm->mode & (GINIT|CINIT)) 
        {
        case CINIT:
#ifdef _CURSES_
            mvwaddstr(Window.P[id].action, 0, _STAT, s);
            wrefresh(Window.P[id].action);
#endif
            break;
        case GINIT:  
	    strcpy(buffer, s);
	    strip_beginning_chars(strip_ending_chars(buffer, ')'), '(');
	    strip_beginning_chars(strip_ending_chars(buffer, '>'), '<');
#ifdef _GTK_
	    gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].stat), buffer);
	    if (strstr(buffer, "OK"))
		gtk_mgr_test_foreground(id);
	    if (strstr(buffer, "BKGD"))
		gtk_mgr_test_background(id);
#endif
            break;
	}
    }
}

/*
 *  Clear the display screen.  (curses only)
 */
void
clear_display_screen(void)
{
#ifdef _CURSES_
	curses_clear_screen();
#endif
}

/*
 *  Perform any window-manager specific pre-shutdown procedures.
 */
void
window_manager_shutdown_notify(void)
{
#ifdef _CURSES_
	curses_shutdown();
#endif
}

/*
 *  Perform any window-manager specific shutdown procedures.
 */
void
window_manager_shutdown(void)
{
#ifdef _GTK_
	gtk_mgr_shutdown();
#endif
}


/*
 *  Get the window geometry.  For curses, get the actual text window size.
 *  For GTK, set to the maximum 80x60 to allow a maximum of 48 tests.
 */
void
get_geometry(void)
{
#ifdef _CURSES_
#undef LINES
#undef COLS
	extern int COLS;
#endif

    if (Shm->term_LINES)
	return;

    clear_display_screen();
    
#ifdef _CURSES_
    if ((LINES < 24) || (COLS < 80)) {
console("LINES: %d  COLS: %d\n", LINES, COLS);
        Shm->stderr(
  "\r\nusex: incompatible terminal geometry -- at least 80x24 is required\r\n");
        quick_die(QDIE(21)); 
    }

    Shm->term_LINES = LINES;
    Shm->term_COLS = COLS;
#endif

#ifdef _GTK_
    Shm->term_LINES = MAXLINES;
    Shm->term_COLS = 80;
#endif

    if (Shm->term_LINES >= MAXLINES)
    	Shm->max_tests = MAX_IO_TESTS;
    else
	Shm->max_tests = Shm->term_LINES - NON_IO_LINES;
}

/*
 *  Clear a bin test suite's display line.
 */
void
clear_bin_line(int id)
{
#ifdef _CURSES_
    char *spaces = "                                                          ";
#endif

    switch (Shm->mode & (CINIT|GINIT)) 
    {
    case CINIT:
#ifdef _CURSES_
        mvwaddstr(Window.P[id].action, 0, _SIZE, spaces);
        wrefresh(Window.P[id].action);
#endif
	break;
    case GINIT:  /* TODO */
	break;
    }
}

/*
 *  Once every pass through the message queue a test is made for 
 *  dead processes.  If any are found, appropriate measures are taken.
 *  The use of cycle_reads is display-dependent.
 */
int
errdaemon(int cycle_reads)
{
    register PROC_TABLE *tbl;
    char buf[FATAL_STRINGSIZE];
    int do_refresh, bin_syncs;
    register int i;

    if (CURSES_DISPLAY()) {
        if (Shm->stallvalue && (cycle_reads == 0)) {
	    stall(Shm->stallvalue);
    	    Shm->stallcnt++;
        }
    }

    for (i = do_refresh = 0; i < Shm->procno; i++) {
        tbl = &Shm->ptbl[i];

        if (tbl->i_stat & IO_DEAD) {
	    switch (tbl->i_demise) 
	    {
	    case BY_SIGNAL:
		if (!(tbl->i_stat & IO_BURIED)) {
	            tbl->i_stat |= IO_BURIED;
		    set_time_of_death(i);
		    if (strlen(tbl->i_fatal_errmsg) == 0) {
            	        sprintf(tbl->i_fatal_errmsg,
		            "usex harness %d terminated by signal: %d  (%s)",
                                i+1, tbl->i_signal_received,
			        tbl->i_time_of_death);
		    }

		    post_test_status(i, "<DEAD>");

		    if (!(tbl->i_stat & (EXPLICIT_KILL|IO_SUICIDE))) {
                        switch (Shm->mode & (CINIT|GINIT))
                        {
                        case CINIT:
#ifdef _CURSES_
                            sprintf(buf,
               "[terminated by signal: %d  (%s)                               ",
                                tbl->i_signal_received, tbl->i_time_of_death);
                            buf[57] = ']';
                            buf[58] = (char)NULLCHAR;
                    	    mvwaddstr(Window.P[i].action, 0, _SIZE, buf);
                    	    DISPLAY(Window.P[i].action);
		    	    do_refresh++;
#endif
			    break;
		        case GINIT:  
#ifdef _GTK_
                            sprintf(buf, " terminated by signal: %d  (%s) ",
                                tbl->i_signal_received, tbl->i_time_of_death);
                	    gtk_label_set_text(GTK_LABEL
				(gtk_mgr_test_widget(i, FERROR, buf)), buf);
#endif
			    break;
		        }
		    }

		    sprintf(buf, 
                        "usex harness %d terminated by signal %d  (%s)\n",
                            i+1, tbl->i_signal_received, tbl->i_time_of_death);
		    LOG(i, LOG_MESSAGE, NOARG, buf);
		}
		break;

	    case BY_EXIT:
		if (!(tbl->i_stat & IO_BURIED)) {
	            tbl->i_stat |= IO_BURIED;
		    set_time_of_death(i);
		    if (!(tbl->i_stat & EXPLICIT_KILL)) {
                        if (strlen(tbl->i_fatal_errmsg) == 0) {
                            sprintf(tbl->i_fatal_errmsg,
                               " usex harness %d exited with status: %d  (%s) ",
                                i+1, tbl->i_exit_status, tbl->i_time_of_death);
                        }
			post_test_status(i, "<EXIT>");
                        sprintf(buf,
                            "usex harness %d exited with status: %d (%s)\n",
                            i+1, tbl->i_exit_status, tbl->i_time_of_death);
                        LOG(i, LOG_MESSAGE, NOARG, buf);

			if (!(tbl->i_stat & USER_ERROR)) {
                            switch (Shm->mode & (CINIT|GINIT))
                            {
                            case CINIT:
#ifdef _CURSES_
                                sprintf(buf,
                      "[usex harness %d exited with status: %d (%s)           ",
                                    i+1, tbl->i_signal_received, 
				    tbl->i_time_of_death);
                                buf[57] = ']';
                                buf[58] = (char)NULLCHAR;
                                mvwaddstr(Window.P[i].action, 0, _SIZE, buf);
                                DISPLAY(Window.P[i].action);
#endif
                                do_refresh++;
                                break;
                            case GINIT:  /* TODO */
#ifdef _GTK_
                                sprintf(buf,
                                  "usex harness %d exited with status: %d (%s)",
                                    i+1, tbl->i_signal_received, 
                                    tbl->i_time_of_death);
                	        gtk_label_set_text(GTK_LABEL
				    (gtk_mgr_test_widget(i, FERROR, buf)), buf);
#endif
                                break;
                            }
			}
		    }
		}
		break;

            default:
		break;

	    } /* switch */

            continue;
	}

	if (!(tbl->i_stat & IO_START))
	    continue;

        if (Kill(tbl->i_pid, 0, "W3", K_IO(i))) {
            tbl->i_stat |= IO_DEAD;
	    if (strlen(tbl->i_fatal_errmsg) && tbl->i_demise == BY_EXIT) {
		post_test_status(i, "<EXIT>");
	    } else {
		if (strlen(tbl->i_fatal_errmsg) == 0) {
			set_time_of_death(i);
            		sprintf(tbl->i_fatal_errmsg,
			    "Unexplainable death of usex harness at %s (%d)",
			    tbl->i_time_of_death, tbl->i_signal_received);
		}
		post_test_status(i, "<DEAD>");
	    }
            switch (Shm->mode & (CINIT|GINIT))
            {
            case CINIT:
#ifdef _CURSES_
                DISPLAY(Window.P[i].action);
#endif
                break;
	    case GINIT:  /* TODO */
	        break;
	    }
            Kill(tbl->i_pid, SIGUSR1, "W4", K_IO(i));
	    if (!tbl->i_internal_kill_source)
	        tbl->i_internal_kill_source = "errdaemon: kill 0 failed";
#ifdef _CURSES_
	    if (!(Shm->mode & QUIET_MODE))
            	beep();
#endif
        }
	else {
            hang_check(i);   /* Check appropriate tests for possible hangs. */
        }
    }

    if (do_refresh) {
        switch (Shm->mode & (CINIT|GINIT))
	{
	case CINIT:
#ifdef _CURSES_
            refresh();
            wrefresh(curscr);
#endif
            break;
	case GINIT:  /* TODO */
	    break;
	}
    }

    if (!Shm->logfile)
	return(cycle_reads);

    for (i = 0; i < NUMSG; i++) {
	if (i < Shm->procno) {
	    if (Shm->ptbl[i].i_stat & IO_DEAD) {
		if (Shm->ptbl[i].i_abnormal_death < 2)
		    Shm->ptbl[i].i_abnormal_death++;
		if (Shm->ptbl[i].i_abnormal_death == 1) 
		    log_death(i);
	    }
        }
    }

    if (Shm->mode & SYNC_BIN_TESTS) {
    	for (i = bin_syncs = 0; i < Shm->procno; i++) {
            tbl = &Shm->ptbl[i];
            if (tbl->i_stat & BIN_SYNC)
		bin_syncs++;
	}
	if (bin_syncs == Shm->procno) {
	    char c;

	    if (Shm->bin_sync_delay == -1) {
		strcpy(Shm->input, "hit RETURN to continue: ");
		USER_PROMPT(Shm->input);
		USER_PROMPT(Shm->input);
		do {
                    c = getchar();
                }  while (c != '\r' && c != '\n' && c != 'k');
		CLEAR_PROMPT();
		CLEAR_STRING(Shm->input);
                if (c == 'k') {
                    common_kill(KILL_ALL, SHUTDOWN);
                    die(0, DIE(27), FALSE);
                }
	    } else
	        sleep(Shm->bin_sync_delay);

	    for (i = bin_syncs = 0; i < Shm->procno; i++) {
               	tbl = &Shm->ptbl[i]; 
                tbl->i_stat &= ~BIN_SYNC;
            }
	}
    }

    return(cycle_reads);
}
/*
 *  On a test-type dependent basis, determine whether the test is no longer
 *  responding with messages and/or heartbeats.
 */

void
hang_check(int test)
{
    register PROC_TABLE *tbl;
    register int i;
    char *lastmsg ATTRIBUTE_UNUSED;
    time_t lasttime = 0;
    time_t now;
    int heartbeat;
    int canned;

    tbl = &Shm->ptbl[test];

    time((time_t *)&now);
    canned = FALSE;
    heartbeat = Shm->heartbeat & ((long long)1 << test) ? TRUE : FALSE;
    if (heartbeat) {
        time((time_t *)&tbl->i_last_heartbeat);
        CLEAR_HEARTBEAT(test); 
    }

    switch (tbl->i_type)
    {
    case WHET_TEST:
	break;         /* don't bother with this one... */

    case VMEM_TEST:
    case RATE_TEST:
	canned = TRUE;

    case DHRY_TEST:
    case DISK_TEST:
    case BIN_TEST:
	/*
         *  Presume (i_post-1) is last, but make sure...
 	 */
	i = tbl->i_post ? tbl->i_post - 1 : I_POSTAGE - 1;

	lasttime = tbl->i_last_msgtime[i];
        lastmsg = tbl->i_last_message[i];

        for (i = 0; i < I_POSTAGE; i++) {
	    if (tbl->i_last_msgtime[i] > lasttime) {
		lasttime = tbl->i_last_msgtime[i];
                lastmsg = tbl->i_last_message[i];
	    }
	}

	if (lasttime > now)   /* message posted since time() done above. */
	    break;

	if (tbl->i_last_heartbeat > lasttime)
	    lasttime = tbl->i_last_heartbeat;

	if (canned) {   /* canned message since last regular message? */
	    if (tbl->i_canned_msg_time > lasttime)
		lasttime = tbl->i_canned_msg_time;
	}

	if ((lasttime) && ((now - lasttime) > Shm->hangtime)) {
	    if (!heartbeat && !(tbl->i_stat & HANG) && 
		!(tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING))) {
        	if ((tbl->i_type == BIN_TEST) && (tbl->bin_child == 0))
                    clear_bin_line(test);
		tbl->i_stat |= HANG;
	        post_test_status(test, "<HANG>");
	    }
	}
	else if ((lasttime) && tbl->i_stat & HANG) {   /* started up again... */
		tbl->i_stat &= ~HANG;
		if (tbl->i_stat & IO_BKGD)
		    post_test_status(test, " BKGD ");
		else
		    post_test_status(test, "  OK  ");
	}
	break;

    default:
	break;
    }
}

/*
 *  Position the cursor at the bottom left of the window.  (curses only)
 *  If end_windows is TRUE, reset the shell mode and end curses entirely.
 */
void
bottom_left(int end_windows)
{
#ifdef _CURSES_
	mvcur(0, Shm->term_COLS-1, Shm->term_LINES-1, 0);

	if (end_windows) {
        	reset_shell_mode();
                endwin();
	}
#endif
}

/*
 *  SIGUSR1/SIGUSR2 signal handler for window manager to dump status.
 */
void
dump_status_signal(int sig)
{
	save_screen(0);
	dump_status(SIGNAL_STATUS, NULL);
}


/*
 *  Dump a status file.
 */
void
dump_status(int source, FILE *fp)
{
	register int i;
	char statfile[STRINGSIZE];
	char buffer1[STRINGSIZE];
	char buffer2[STRINGSIZE];
	char buffer3[STRINGSIZE];

        sys_date(buffer1);
        sys_time(buffer2);
        run_time(buffer3, NULL);

	i = 1;

	if (fp == NULL) {
		do {
			sprintf(statfile, "ux%06d_status.%d", Shm->mompid, i++);
		} while (file_exists(statfile));
	
	    	if ((fp = fopen(statfile, "w+")) == NULL) {
			Shm->perror("cannot create status file");
			return;
		}
	
		Shm->statnum = i-1;
		fprintf(fp, "%sUSEX VERSION: %s\n", SEPARATOR, USEX_VERSION);
	} 

       	fprintf(fp, "%sTEST SUMMARIES:\n\n", SEPARATOR);
       	test_summaries(fp);

	fprintf(fp, "%sUSEX TEST STATUS AT: %s@%s TEST TIME: %s\n%s", 
		SEPARATOR, buffer1, buffer2, buffer3, SEPARATOR); 

        for (i = 0; i < Shm->procno; i++) {
		if (Shm->ptbl[i].i_pid != NOT_RUNNING) {
			fprintf(fp, "\n%s TEST %d:\n", test_type(i), i+1);
                	test_inquiry(i, fp, TRUE);
			fprintf(fp, "\n%s", SEPARATOR);
		}
	}

	fprintf(fp, "\nUSEX SHARED MEMORY DATA:\n\n");
	usex_inquiry(fp);
	fprintf(fp, "\n%s", SEPARATOR);

	switch (source)
	{
	case REPORTFILE_STATUS:
		return;

	case WINDOW_MANAGER_KILLED:
#ifdef _CURSES_
                fprintf(fp, "\nFINAL SCREEN:\n\n");
                dump_screen(fp);
#endif
		debug_message(DEBUG_MESSAGE_STAT(2), (ulong)Shm->statnum);
		break;

	case INTERACTIVE_STATUS:
        case SIGNAL_STATUS:
#ifdef _CURSES_
                fprintf(fp, "\nCURRENT SCREEN:\n\n");
                dump_screen(fp);
#endif	
		set_timer_request(1, debug_message, DEBUG_MESSAGE_STAT(2), 
			(ulong)Shm->statnum);
		break;
	}

	fclose(fp);
}

void
save_screen(uint mark)
{
#ifdef _CURSES_
	register int i, j;
	wchar_t wide;
#endif


	if (GTK_DISPLAY())
		return;   /* TODO */

	if (!(Shm->mode & CINIT))
		return;

#ifdef _CURSES_
        for (i = 0; i < Shm->lines_used; i++) {
                for (j = 0; j < COLS; j++) {
                        move(i, j);
                        innwstr((char *)&wide, (int)1);
#if defined(__powerpc__) || defined(__s390__) || defined(__s390x__)
                        Shm->screen_buf[i][j] = (wide >> 24) & 0x7f; 
#else
                        Shm->screen_buf[i][j] = wide & 0x7f; 
#endif
                }
        }

	Shm->mode |= mark;
#endif
}

void
dump_screen(FILE *fp)
{
	register int i, j, cols;

	if (GTK_DISPLAY())
		return;

	if (!(Shm->mode & CINIT))
	    	return;
	
	cols = Shm->term_COLS ? Shm->term_COLS : COLS;

        for (i = 0; (i < Shm->lines_used); i++) {
                for (j = 0; j < cols; j++) {
                        if ((Shm->screen_buf[i][j] >= ' ') &&
                            (Shm->screen_buf[i][j] < 0x7f))
                            	fprintf(fp, "%c", Shm->screen_buf[i][j]);
                        else
                                fprintf(fp, "?");
                }
                fprintf(fp, "\n");
        }
}


void
test_inquiry(int target, FILE *fp, int show_messages)
{
	int others;
	extern __const char *__const sys_siglist[_NSIG];
	PROC_TABLE *tbl;
	
	tbl = &Shm->ptbl[target];

	fprintf(fp, "i_pid: %d i_local_pid: \'%c\' i_type: %s\n",
		tbl->i_pid, tbl->i_local_pid, test_type(target));
	fprintf(fp, "i_stat: %x (", tbl->i_stat);
	others = 0;
	if (tbl->i_stat & IO_START)
		fprintf(fp, "%sIO_START", others++ ? "|" : "");
	if (tbl->i_stat & RATE_START)
		fprintf(fp, "%sRATE_START", others++ ? "|" : "");
	if (tbl->i_stat & RATE_TBD)
		fprintf(fp, "%sRATE_TBD", others++ ? "|" : "");
	if (tbl->i_stat & IO_SYNC)
		fprintf(fp, "%sIO_SYNC", others++ ? "|" : "");
	if (tbl->i_stat & IO_BKGD)
		fprintf(fp, "%sIO_BKGD", others++ ? "|" : "");
	if (tbl->i_stat & IO_DEAD)
		fprintf(fp, "%sIO_DEAD", others++ ? "|" : "");
	if (tbl->i_stat & IO_FILL)
		fprintf(fp, "%sIO_FILL", others++ ? "|" : "");
	if (tbl->i_stat & IO_TRUN) 
		fprintf(fp, tbl->i_type == RATE_TEST ? 
			"%sRATE_WRITE" : "%sIO_TRUN", others++ ? "|" : "");
	if (tbl->i_stat & IO_DYING)
		fprintf(fp, "%sIO_DYING", others++ ? "|" : "");
	if (tbl->i_stat & SENDING)
		fprintf(fp, "%sSENDING", others++ ? "|" : "");
	if (tbl->i_stat & WAKE_ME)
		fprintf(fp, "%sWAKE_ME", others++ ? "|" : "");
	if (tbl->i_stat & HANG)
		fprintf(fp, "%sHANG", others++ ? "|" : "");
	if (tbl->i_stat & IO_LOOKUP)
		fprintf(fp, 
	            tbl->i_type == RATE_TEST ? "%sRATE_OVFLOW" : "%sIO_LOOKUP",
			others++ ? "|" : "");
	if (tbl->i_stat & IO_PIPE)
		fprintf(fp, 
		    tbl->i_type == RATE_TEST ? "%sRATE_NOTIME" : "%sIO_PIPE", 
			others++ ? "|" : "");
	if (tbl->i_stat & IO_ADMIN1)
		fprintf(fp, "%sIO_ADMIN1", others++ ? "|" : "");
	if (tbl->i_stat & IO_SPECIAL)
		fprintf(fp, "%sIO_SPECIAL", others++ ? "|" : "");
	if (tbl->i_stat & IO_FORK)
		fprintf(fp, "%sIO_FORK", others++ ? "|" : "");
	if (tbl->i_stat & IO_CHILD_RUN)
		fprintf(fp, "%sIO_CHILD_RUN", others++ ? "|" : "");
	if (tbl->i_stat & IO_WAIT)
		fprintf(fp, "%sIO_WAIT", others++ ? "|" : "");
	if (tbl->i_stat & IO_ADMIN2)
		fprintf(fp, "%sIO_ADMIN2", others++ ? "|" : "");
	if (tbl->i_stat & IO_HOLD_PENDING)
		fprintf(fp, "%sIO_HOLD_PENDING", others++ ? "|" : "");
	if (tbl->i_stat & RING_OUT_OF_SYNC)
		fprintf(fp, "%sRING_OUT_OF_SYNC", others++ ? "|" : "");
	if (tbl->i_stat & EXPLICIT_KILL)
		fprintf(fp, "%sEXPLICIT_KILL", others++ ? "|" : "");
	if (tbl->i_stat & IO_HOLD)
		fprintf(fp, "%sIO_HOLD", others++ ? "|" : "");
	if (tbl->i_stat & IO_NOLOG)
		fprintf(fp, "%sIO_NOLOG", others++ ? "|" : "");
	if (tbl->i_stat & IO_FSYNC)
		fprintf(fp, 
		    tbl->i_type == BIN_TEST ? "%sBIN_SYNC" : "%sIO_FSYNC", 
		others++ ? "|" : "");
	if (tbl->i_stat & WAKE_UP)
		fprintf(fp, "%sWAKE_UP", others++ ? "|" : "");
	if (tbl->i_stat & IO_BURIED)
		fprintf(fp, "%sIO_BURIED", others++ ? "|" : "");
	if (tbl->i_stat & IO_SUICIDE)
		fprintf(fp, "%sIO_SUICIDE", others++ ? "|" : "");
	if (tbl->i_stat & IO_NOTRUNC)
		fprintf(fp, "%sIO_NOTRUNC", others++ ? "|" : "");
	if (tbl->i_stat & RATE_CREATE)
		fprintf(fp, "%sRATE_CREATE", others++ ? "|" : "");
	if (tbl->i_stat & USER_ERROR)
		fprintf(fp, "%sUSER_ERROR", others++ ? "|" : "");
	fprintf(fp, ")\n");

	fprintf(fp, "i_msg_id: %d i_msgq.type: %d i_msgq.string: ",
		tbl->i_msg_id, 
		tbl->i_msgq.type);
	if (strlen(tbl->i_msgq.string))
		fprintf(fp, "\n  \"%s\"\n", tbl->i_msgq.string);
	else
		fprintf(fp, "(empty)\n");
	fprintf(fp, "i_size: %ld%s i_limit: ", (ulong)tbl->i_size,
		tbl->i_type == VMEM_TEST ? "mb" : "");
	if (tbl->i_type == DISK_TEST) {
		if (!tbl->i_limit)
			fprintf(fp, "EOFS ");
		else
			fprintf(fp, "%ldkb ", tbl->i_limit);
	} else if (tbl->i_type == RATE_TEST) {
                if (!tbl->i_limit)
                        fprintf(fp, "EOF ");
                else
                        fprintf(fp, "%ldkb ", tbl->i_limit);
	} else
		fprintf(fp, "%ld ", tbl->i_limit);
	fprintf(fp, "i_fsize: %ld\n", tbl->i_fsize);
	if (file_exists(tbl->i_errfile))
	     fprintf(fp, "i_errfile: \"%s\" ", tbl->i_errfile);
	else
	     fprintf(fp, "i_errfile: (none) ");
	fprintf(fp, " i_path: \"%s\"\n", tbl->i_path);

	fprintf(fp, "i_file: \"%s\" i_time_of_death: \"%s\"\n",
		tbl->i_file, tbl->i_time_of_death);
	fprintf(fp, "i_cstat: %x (%d)\n", tbl->i_cstat,
		(tbl->i_cstat & 0xff00) >> 8);
	fprintf(fp, "i_signal_received: %d ",
		tbl->i_signal_received);
	if (tbl->i_signal_received && (tbl->i_signal_received <= _NSIG))
		fprintf(fp, "(%s) ", sys_siglist[tbl->i_signal_received]);
	
	fprintf(fp, " i_exit_status: %d ", tbl->i_exit_status);
	switch (tbl->i_exit_status)
	{
	case MALLOC_ERROR:
		fprintf(fp, "(MALLOC_ERROR)");  break;
	case SH_KILL_SHELL:
		fprintf(fp, "(SH_KILL_SHELL)");  break;
	case MOM_IS_DEAD:
		fprintf(fp, "(MOM_IS_DEAD)");  break;
	case INVAL_DEBUG_TEST:
		fprintf(fp, "(INVAL_DEBUG_TEST)");  break;
	case BIN_MGR_K:
		fprintf(fp, "(BIN_MGR_K)");  break;
	case BIN_TIME_TO_DIE_1:
		fprintf(fp, "(BIN_TIME_TO_DIE_1)");  break;
	case BIN_TIME_TO_DIE_2:
		fprintf(fp, "(BIN_TIME_TO_DIE_2)");  break;
	case BIN_TIME_TO_DIE_3:
		fprintf(fp, "(BIN_TIME_TO_DIE_3)");  break;
	case BIN_KILL_CHILD:
		fprintf(fp, "(BIN_KILL_CHILD)");  break;
	case BIN_BAILOUT:  
		fprintf(fp, "(BIN_BAILOUT)");  break;
        case KILL_EXIT:   
		fprintf(fp, "(KILL_EXIT)");  break;
	case FATAL_EXIT:
		fprintf(fp, "(FATAL_EXIT)");  break;
	case PARALYZE_EXIT:
		fprintf(fp, "(PARALYZE_EXIT)");  break;
	case NORMAL_EXIT:
		break;
	default:
		fprintf(fp, "(unexpected)");  break;
	}
	fprintf(fp, "\n");

	fprintf(fp, "i_killorg: %s i_abnormal_death: %d i_demise: ",
		tbl->i_killorg ? tbl->i_killorg : "n/a",
		tbl->i_abnormal_death);

        switch (tbl->i_demise)
        {
        case 0:
            fprintf(fp, "(none)\n");
            break;
        case BY_DEATH: 
            fprintf(fp, "BY_DEATH\n");
            break;
        case BY_EXIT:   
            fprintf(fp, "BY_EXIT\n");
            break;
        case BY_SIGNAL:
            fprintf(fp, "BY_SIGNAL\n");
            break;
        case BY_STOP:
            fprintf(fp, "BY_STOP\n");
            break;
        default:
            fprintf(fp, "unknown: %d\n", tbl->i_demise);
            break;
        }
    
       fprintf(fp, "i_internal_kill_source: [%s]\n",  
                tbl->i_internal_kill_source ? tbl->i_internal_kill_source : "");

	fprintf(fp, 
	  "i_post: %d i_last_message/i_last_msgtime: ",
		tbl->i_post);

	if (!show_messages)
		fprintf(fp, "(use \"t%dm\" command)\n", target+1);
	else
		fprintf(fp, "(see below)\n");

        fprintf(fp, "i_sbuf: &%lx i_read_buf: %lx i_write_buf: %lx\n",
                (ulong)&tbl->i_sbuf, (ulong)tbl->i_read_buf, (ulong)tbl->i_write_buf);

	fprintf(fp, 
		"i_pass: %ld  i_saved_errno: %d i_message: %d\n",
		tbl->i_pass, tbl->i_saved_errno, tbl->i_message);

	fprintf(fp, 
	    "i_rptr: %d i_wptr: %d i_blkcnt: %d i_lock: %d\n",
		tbl->i_rptr, tbl->i_wptr, tbl->i_blkcnt, tbl->i_lock); 
	fprintf(fp, "i_timestamp: %s", tbl->i_timestamp ? 
		ctime(&tbl->i_timestamp) : "(unused)\n");

	fprintf(fp, "i_canned_msg_time: %s\n", 
		tbl->i_canned_msg_time ? 
		strip_lf(ctime(&tbl->i_canned_msg_time)) : "(unused)");
	fprintf(fp, "i_last_heartbeat: %s\n", 
		tbl->i_last_heartbeat ? 
		strip_lf(ctime(&tbl->i_last_heartbeat)) : "(unused)");

	switch (tbl->i_type)
	{
    	case DISK_TEST:  
		disk_test_inquiry(target, fp);
		break;
    	case WHET_TEST: 
		float_test_inquiry(target, fp);
		break;
    	case DHRY_TEST:  
		dry_test_inquiry(target, fp);
		break;
    	case USER_TEST:  
		shell_cmd_inquiry(target, fp);
		break;
    	case VMEM_TEST:  
		vmem_test_inquiry(target, fp);
		break;
    	case BIN_TEST:   
		bin_test_inquiry(target, fp);
		break;
    	case DEBUG_TEST: 
		debug_test_inquiry(target, fp);
		break;
	case RATE_TEST:
		rate_test_inquiry(target, fp);
		break;
	}

	if (show_messages) {
        	fprintf(fp, "\n");
        	last_message_query(FIRST_ID+target, fp, FALSE);
	}

        fprintf(fp, "FATAL ERROR MESSAGE: ");
	if (strlen(tbl->i_fatal_errmsg))
		fprintf(fp, "\n%s\n", tbl->i_fatal_errmsg);
	else
		fprintf(fp, "(none)\n");
	
	fflush(fp);
}

void
test_summaries(FILE *fp)
{
	register int i;
	double fsize;
		
        for (i = 0; i < Shm->procno; i++) {
                switch (Shm->ptbl[i].i_type)
                {       
                case RATE_TEST:
                case DISK_TEST:
                        fprintf(fp, " %s TEST %d: PASS: %ld ",
                                test_type(i),
                                i+1, Shm->ptbl[i].i_pass);
                        fprintf(fp, "FILE: %s ", Shm->ptbl[i].i_file);
			fprintf(fp, "SIZE: %ld/", (ulong)Shm->ptbl[i].i_size);
			if (Shm->ptbl[i].i_limit) {
				fsize = Shm->ptbl[i].i_limit * 1024;
    				if (fsize >= (GIGABYTE)) 
        				fprintf(fp, "%.1f gb ", 
						fsize/(double)GIGABYTE);
    				else if (fsize >= (100*MEGABYTE))
        				fprintf(fp, "%d mb ", 
						(int)(fsize/(double)MEGABYTE));
    				else if (fsize >= MEGABYTE)
        				fprintf(fp, "%.1f mb ", 
						fsize/(double)MEGABYTE);
    				else
        				fprintf(fp, "%ld kb ", 
						(ulong)(fsize/(double)KILOBYTE));
			} else
				fprintf(fp, "(unlimited) ");
                        break;

		case BIN_TEST:
                        fprintf(fp, " %s TEST %d: PASS: %ld ",
                                test_type(i),
                                i+1, Shm->ptbl[i].i_pass);
			fprintf(fp, "CMDS: %d ",
				Shm->ptbl[i].cmds_per_pass);
			break;

		case USER_TEST:
                        fprintf(fp, " %s TEST %d: PASS: %ld ",
                                test_type(i),
                                i+1, Shm->ptbl[i].i_pass);
                        fprintf(fp, "CMD: %s ", Shm->ptbl[i].i_file);
			break;

               	case VMEM_TEST: 
               		fprintf(fp, " %s TEST %d: %ld mb %s WRITES: %ld (%s) ",
                                test_type(i), 
                                i+1, (ulong)Shm->ptbl[i].i_size, 
                    		Shm->ptbl[i].access_mode == RANDOM ? 
				"random" : "sequential",
                                Shm->ptbl[i].i_pass,
				Shm->ptbl[i].vmem_buffer);
                        break;

		case DHRY_TEST:
                        fprintf(fp, " %s TEST %d: PASS: %ld ",
                                test_type(i),
                                i+1, Shm->ptbl[i].i_pass);
			fprintf(fp, "DHRYSTONES: %ld ", 
				Shm->ptbl[i].dhrystones);
			break;

		case WHET_TEST:
                        fprintf(fp, " %s TEST %d: PASS: %ld ",
                                test_type(i),
                                i+1, Shm->ptbl[i].i_pass);
			fprintf(fp, "MWIPS: %.3f ", Shm->ptbl[i].whet_mwips);
			break;
                        
               	default:    
                        fprintf(fp, " %s TEST %d: PASS: %ld ",  
                                test_type(i),
                                i+1, Shm->ptbl[i].i_pass);
                        break;  
               	}       

                if (Shm->ptbl[i].i_blkcnt)
                	fprintf(fp, "BLOCKS: %d ", Shm->ptbl[i].i_blkcnt);

                if (Shm->ptbl[i].i_abnormal_death) {
                         fprintf(fp, "%s: %s\n",
                                 Shm->ptbl[i].i_stat & EXPLICIT_KILL ?
                                 "EXPLICITLY KILLED AT" :
                                 "ABNORMAL DEATH AT",
                                 Shm->ptbl[i].i_time_of_death);
                } else
                         fprintf(fp, "\n");
	}

        fprintf(fp, "\n");
}

static char *fatal_hdr = 
"=========================== FATAL ERROR MESSAGE =============================";

int
last_message_query(int which, FILE *fp, int show_fatal)
{
    register int i, j, k, c;
    PROC_TABLE *tbl;
    char input[STRINGSIZE], *ptr;
    char previous[STRINGSIZE];
    char timebuf[STRINGSIZE];
    int retval = 0;

    previous[0] = (char)NULLCHAR; 

    switch (which) 
    {
    case FATAL_MESSAGES:
        strcpy(input, fatal_hdr);
        input[47] = 'S';
        input[48] = ' ';
        fprintf(fp, "%s\n", input);
        for (i = 0; i < Shm->procno; i++) {
	    tbl = &Shm->ptbl[i];
	    if (strlen(tbl->i_fatal_errmsg))
                fprintf(fp, "TEST %d:\n%s\n", i+1, tbl->i_fatal_errmsg);
	}
	break;

    case ALL_MESSAGES:
	for (i = 0; i < Shm->procno; i++) {
	    if (last_message_query(i + FIRST_ID, fp, show_fatal) == 'q')
		return retval;
	    if (fp == stdout) {
                Shm->printf(":");
                fflush(stdout);
                fgets((char *)input, STRINGSIZE, stdin);
                Shm->printf("\r");
                if (input[0] == 'q') {
		    retval = 'q';
                    return retval;
    	        }
	    }
	}

	break;

    default:
        k = which - FIRST_ID;
	tbl = &Shm->ptbl[k];
        fprintf(fp, "TEST %d MESSAGES:\n", k+1); 
	j = tbl->i_post;
        for (i = c = 1; i < I_POSTAGE; i++) {
            ptr = tbl->i_last_message[j];
	    if (strlen(ptr) > 0) {
		strcpy(input, ctime(&tbl->i_last_msgtime[j]));
		if (strcmp(input, previous) != 0) {
		    strcpy(previous, input);
                    fprintf(fp, "[%s]\n", 
			format_time_string(timebuf, input));
		    c++;
		}
		if (WINDOW_MGR_CMD(*ptr) && (*(ptr+1) == tbl->i_local_pid)) {
		    fprintf(fp, "[%c] ", *ptr);
		    ptr += 2;
		}
                fprintf(fp, "%s\n", strip_lf(ptr));

		c++;
	    }
            j = (j+1) % I_POSTAGE;
            if ((fp == stdout) && c && (c >= (Shm->lines_used-1))) {
		c = 0;
		Shm->printf(":");
		fflush(stdout);
                fgets((char *)input, STRINGSIZE, stdin);
		Shm->printf("\r");
		if (input[0] == 'q') {
		    retval = 'q';
		    break;
		}
	    }
        }

	fprintf(fp, "\nRING BUFFER: ");
        for (i = 0; i < I_RINGBUFSIZE; i++) {
                if (i == 0 || i == 64 || i == 128 || i == 192 ||
                    i == 256 || i == 320 || i == 384 || i == 448)
                	fprintf(fp, "\n  ");
                fprintf(fp, "%c", isprint(tbl->i_rbuf[i]) ?  
			tbl->i_rbuf[i] : '.');
        }
	fprintf(fp, "\n\n");

	if (show_fatal) {
       		fprintf(fp, "FATAL ERROR MESSAGE: ");
        	if (strlen(tbl->i_fatal_errmsg))
                	fprintf(fp, "\n%s\n\n", tbl->i_fatal_errmsg);
        	else
                	fprintf(fp, "(none)\n\n");
	} 
	break;
    }

    return(retval);
}

/*
 *  Depending upon the window manager type, determine whether a 
 *  system stats display update should be allowed.
 */
static int
allow_sys_stats_display(void)
{
	int allow;
	
	allow = TRUE;

	switch (Shm->mode & (GINIT|CINIT))
	{
	case GINIT:
        	if (Shm->mode & (NO_STATS|SHUTDOWN_MODE))
			allow = FALSE;
		break;

	case CINIT:
        	if (Shm->mode & (DEBUG_MODE|NO_STATS))
			allow = FALSE;
		break;

	default:
		allow = FALSE;
		break;
	}

	return allow;
}

/*
 * Show the load average.
 */
void
show_load_average(void)
{
    FILE *fp;
    char buf1[256];
    char buf2[256];
    int argc;
    char *p, *tasks, *runnable;
    char *argv[MAX_ARGV];
    
    if (!allow_sys_stats_display())
       	return;

    if (((fp = fopen("/proc/loadavg", "r")) != NULL) && 
        fgets(buf1, 256, fp)) {
        argc = parse(buf1, argv);
	fclose(fp);
    }
    else 
	return;

    if (argc != 5)
	return;

    runnable = argv[3];
    p = strstr(argv[3], "/");
    *p = '\0';
    tasks = p+1;

#ifdef _CURSES_
    mvwaddstr(Window.Cpu_Stats, 0, 20, mkstring(argv[0], 7, CENTER|RJUST));
    wrefresh(Window.Cpu_Stats);

    sprintf(buf2, "%d", atoi(tasks));
    mvwaddstr(Window.Cpu_Stats, 0, 27, mkstring(buf2, 7, RJUST));
    wrefresh(Window.Cpu_Stats);

    mvwaddstr(Window.Cpu_Stats, 0, 34, "/");

    sprintf(buf2, "%d", atoi(runnable));
    mvwaddstr(Window.Cpu_Stats, 0, 35, mkstring(buf2, 5, LJUST));
    wrefresh(Window.Cpu_Stats);
#endif
#ifdef _GTK_
    gtk_label_set_text(GTK_LABEL(Shm->wmd->loadavg), argv[0]);
    sprintf(buf2, "%d / %d", atoi(tasks), atoi(runnable));
    gtk_label_set_text(GTK_LABEL(Shm->wmd->tasks_run), buf2);
#endif
}

/*
 *  Show user/system/idle cpu usage
 */ 
static struct cpu_stats {
	int init;
	ulong user;
	ulong sys;
	ulong idle;
	ulong page_in;
	ulong page_out;
	ulong swap_in;
	ulong swap_out;
	ulong ctxt;
	ulong procs;
	double intr;
} cpu_stats = { 0 };

int
show_cpu_stats(int type)
{
	char buf1[STRINGSIZE];
	char buf2[STRINGSIZE];
	char intrbuf[65536];
	FILE *fp;
	int argc;
	int intr, smp;
    	char *argv[MAX_ARGV];
	char *p1, *useless;
	ulong tot_user, tot_sys, tot_idle;
	ulong cnt_user, cnt_sys, cnt_idle;
	ulong mod_user, mod_sys, mod_idle;
	ulong pct_user, pct_sys, pct_idle;
	ulong user, sys, idle;
	ulong cnt_page_in, cnt_page_out;
	ulong page_in, page_out;
	ulong cnt_swap_in, cnt_swap_out;
	ulong swap_in, swap_out;
	ulong cnt_ctxt, ctxt;
	ulong cnt_procs, procs;
	ulong total;
	double cnt_intr, tot_intr;

    	if ((type != GET_SMP_COUNT) && !(Shm->mode & (CINIT|GINIT)))
        	return 0;

        if ((fp = fopen("/proc/stat", "r")) == NULL) 
		return 0;

	intr = smp = 0;
	page_in = page_out = swap_in = swap_out = 0;
        bzero(intrbuf, 4096);
	bzero(buf2, STRINGSIZE);

        while (fgets(buf2, STRINGSIZE-1, fp)) {
		strcpy(buf1, buf2);
		argc = parse(buf1, argv);
		if (intr || (argc > 1 && streq(argv[0], "intr"))) {
			intr++;
			strcpy(&intrbuf[strlen(intrbuf)], buf2);
			if (strstr(buf2, "\n")) {
				intr = 0;
			}
		}
		else if (argc >= 5 && streq(argv[0], "cpu")) {
       			tot_user = strtoul(argv[1], &useless, 0) + 
       			       strtoul(argv[2], &useless, 0);
       			tot_sys = strtoul(argv[3], &useless, 0);
       			tot_idle = strtoul(argv[4], &useless, 0);
			if (argc >= 6)	/* I/O wait == idle if present */
       			       tot_idle += strtoul(argv[5], &useless, 0);
			if (argc >= 7)	/* hard interrupts == system if present */
       			       tot_sys += strtoul(argv[6], &useless, 0);
			if (argc >= 8)	/* soft interrupts == system if present */
       			       tot_sys += strtoul(argv[7], &useless, 0);
		} else if (argc >= 5 && strneq(argv[0], "cpu") &&
			isdigit(argv[0][3])) {
			smp++;
		} else if (argc == 3 && strneq(argv[0], "page")) {
       			page_in = strtoul(argv[1], &useless, 0);
       			page_out = strtoul(argv[2], &useless, 0);
                } else if (argc == 3 && strneq(argv[0], "swap")) {
                        swap_in = strtoul(argv[1], &useless, 0);
                        swap_out = strtoul(argv[2], &useless, 0);
                } else if (argc == 2 && strneq(argv[0], "ctxt")) {
                        ctxt = strtoul(argv[1], &useless, 0);
                } else if (argc == 2 && strneq(argv[0], "processes")) {
                        procs = strtoul(argv[1], &useless, 0);
                }
		bzero(buf2, STRINGSIZE);
	}

	fclose(fp);

	if (file_exists("/proc/vmstat") && 
	    ((fp = fopen("/proc/vmstat", "r")) != NULL)) {
        	while (fgets(buf2, STRINGSIZE-1, fp)) {
                	strcpy(buf1, buf2);
                	argc = parse(buf1, argv);
			if (argc != 2)
				continue;
               		if (strneq(argv[0], "pgpgin")) {
       				page_in = strtoul(argv[1], &useless, 0);
			} 
               		if (strneq(argv[0], "pgpgout")) {
       				page_out = strtoul(argv[1], &useless, 0);
			}
               		if (strneq(argv[0], "pswpin")) {
       				swap_in = strtoul(argv[1], &useless, 0);
			}
               		if (strneq(argv[0], "pswpout")) {
       				swap_out = strtoul(argv[1], &useless, 0);
			}
		}
	        bzero(buf2, STRINGSIZE);
		fclose(fp);
	}

	if (type == GET_SMP_COUNT)
		return smp;

	if (!cpu_stats.init) {                /* Store the initial totals */
		cpu_stats.user = tot_user;
		cpu_stats.sys = tot_sys;
		cpu_stats.idle = tot_idle;
		cpu_stats.page_in = page_in;
		cpu_stats.page_out = page_out;
		cpu_stats.swap_in = swap_in;
		cpu_stats.swap_out = swap_out;
		cpu_stats.ctxt = ctxt;
		cpu_stats.procs = procs;
        	cpu_stats.intr = 0.0;
        	p1 = strtok(intrbuf, " ");        /* intr */
        	while ((p1 = strtok(NULL, " "))) 
                	cpu_stats.intr += (double)strtoul(p1, 0, 10);
		cpu_stats.init = TRUE;
		return 0;
	}

	cnt_user = tot_user - cpu_stats.user;  /* Count total since last time */
	cnt_sys = tot_sys - cpu_stats.sys;
	cnt_idle = tot_idle - cpu_stats.idle;

        cpu_stats.user = tot_user;             /* Store the latest totals */
        cpu_stats.sys = tot_sys;
        cpu_stats.idle = tot_idle;

	total = cnt_user + cnt_sys + cnt_idle;  
	if (total == 0)
		goto no_pct;

	user = (cnt_user * 10000)/total;
	sys = (cnt_sys * 10000)/total;
	idle = (cnt_idle * 10000)/total;

	pct_user = user/100;
	pct_sys = sys/100;
	pct_idle = idle/100;

	mod_user = user % 100;
	mod_sys = sys % 100;
	mod_idle = idle % 100;

	if ((pct_user + pct_sys + pct_idle) > 100) 
		goto no_pct;

	if ((pct_user + pct_sys + pct_idle) != 100) {
		if ((mod_idle > mod_user) && (mod_idle > mod_sys)) {
			pct_idle++;
		} else if ((mod_sys > mod_user) && (mod_sys > mod_idle))
			pct_sys++;
		else if ((mod_user > mod_sys) && (mod_user > mod_idle))
			pct_user++;
	}

	sprintf(buf1, "%3ld%%  %3ld%%  %3ld%%",
		pct_user, pct_sys, pct_idle);

    	if (allow_sys_stats_display()) {
#ifdef _CURSES_
        	mvwaddstr(Window.Cpu_Stats, 0, 2, buf1);
        	wrefresh(Window.Cpu_Stats);
#endif
#ifdef _GTK_
		gtk_progress_bar_update(
			GTK_PROGRESS_BAR(Shm->wmd->user_pct), 
			(gfloat)((gfloat)(pct_user)/100));
		gtk_progress_bar_update(
			GTK_PROGRESS_BAR(Shm->wmd->system_pct), 
			(gfloat)((gfloat)(pct_sys)/100));
		gtk_progress_bar_update(
			GTK_PROGRESS_BAR(Shm->wmd->idle_pct), 
			(gfloat)((gfloat)(pct_idle)/100));
#endif
	}

no_pct:

	cnt_page_in = page_in - cpu_stats.page_in;
	cnt_page_out = page_out - cpu_stats.page_out;
	cpu_stats.page_in = page_in;
	cpu_stats.page_out = page_out;

        cnt_swap_in = swap_in - cpu_stats.swap_in;
        cnt_swap_out = swap_out - cpu_stats.swap_out;
        cpu_stats.swap_in = swap_in;
        cpu_stats.swap_out = swap_out;

	sprintf(buf1, "%ld", cnt_page_in);
	sprintf(buf2, "%ld", cnt_page_out);

    	if (allow_sys_stats_display()) {
#ifdef _CURSES_
        	mvwaddstr(Window.Page_Stats, 0, 2, 
			mkstring(buf1, 7, CENTER|RJUST));
        	wrefresh(Window.Page_Stats);
        	mvwaddstr(Window.Page_Stats, 0, 10, 
			mkstring(buf2, 7, CENTER|RJUST));
        	wrefresh(Window.Page_Stats);
#endif
#ifdef _GTK_
		gtk_label_set_text(GTK_LABEL(Shm->wmd->page_in), buf1);
		gtk_label_set_text(GTK_LABEL(Shm->wmd->page_out), buf2);
#endif
	}

	sprintf(buf1, "%ld", cnt_swap_in);
        sprintf(buf2, "%ld", cnt_swap_out);

    	if (allow_sys_stats_display()) {
#ifdef _CURSES_
        	mvwaddstr(Window.Page_Stats, 2, 2, 
			mkstring(buf1, 7, CENTER|RJUST));
        	wrefresh(Window.Page_Stats);
        	mvwaddstr(Window.Page_Stats, 2, 10, 
			mkstring(buf2, 7, CENTER|RJUST));
        	wrefresh(Window.Page_Stats);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->swap_in), buf1);
                gtk_label_set_text(GTK_LABEL(Shm->wmd->swap_out), buf2);
		
#endif
	}

        cnt_ctxt = ctxt - cpu_stats.ctxt;
        cpu_stats.ctxt = ctxt;
	sprintf(buf1, "%ld", cnt_ctxt);

    	if (allow_sys_stats_display()) {
#ifdef _CURSES_
        	mvwaddstr(Window.Page_Stats, 0, 38, 
			mkstring(buf1, 7, CENTER|RJUST));
        	wrefresh(Window.Page_Stats);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->csw), buf1);
#endif
	}

	tot_intr = 0.0;
	p1 = strtok(intrbuf, " ");  /* intr */
	while ((p1 = strtok(NULL, " "))) {
    		tot_intr += (double)strtoul(p1, 0, 10);
	}
	cnt_intr = tot_intr - cpu_stats.intr;
	cpu_stats.intr = tot_intr;

	sprintf(buf1, "%lu", (ulong)cnt_intr);

    	if (allow_sys_stats_display()) {
#ifdef _CURSES_
        	mvwaddstr(Window.Page_Stats, 0, 45, 
			mkstring(buf1, 6, CENTER|RJUST));
        	wrefresh(Window.Page_Stats);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->interrupts), buf1);
#endif
	}

        cnt_procs = procs - cpu_stats.procs;
        cpu_stats.procs = procs;
        sprintf(buf1, "%ld", cnt_procs);

    	if (allow_sys_stats_display()) {
#ifdef _CURSES_
        	mvwaddstr(Window.Page_Stats, 2, 38, 
			mkstring(buf1, 7, CENTER|RJUST));
        	wrefresh(Window.Page_Stats);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->forks), buf1);
#endif
	}

	return 0;
}

/*
 * Show the amount of free memory and swap.
 */

#ifdef PROC_MEMINFO
        total:    used:    free:  shared: buffers:  cached:
Mem:  130707456 53870592 76836864 11128832 12701696 25362432
#endif

void
show_free_memory(void)
{
    FILE *fp;
    int new_meminfo;
    int argc ATTRIBUTE_UNUSED;
    char buf1[256];
    char buf2[256];
    char membuf[STRINGSIZE];
    char swapbuf[STRINGSIZE];
    char *argv[MAX_ARGV];
    double freemem, freeswap, buffers, cached;
    
    if (!allow_sys_stats_display())
	return;

    if ((fp = fopen("/proc/meminfo", "r")) == NULL)
	return;

    new_meminfo = FALSE;
    freemem = freeswap = buffers = cached = 0;
    membuf[0] = swapbuf[0] = 0;

    while (fgets(buf1, 256, fp)) { 
	if (strneq(buf1, "Mem: ")) 
            strcpy(membuf, buf1);
        
        if (strneq(buf1, "Swap: ")) 
            strcpy(swapbuf, buf1);

	if (strneq(buf1, "MemTotal:")) {
	    new_meminfo = TRUE;
	    break;
	}
    }

    if (new_meminfo) {
        while (fgets(buf1, 256, fp)) { 
	    if (strneq(buf1, "MemFree:")) {
                argc = parse(buf1, argv);
        	if (decimal(argv[1], 0)) {
        	    freemem = (double)strtoull(argv[1], 0, 10);
		    freemem *= 1024;
		}
	    } 

           if (strneq(buf1, "SwapFree:")) {
                argc = parse(buf1, argv);
                if (decimal(argv[1], 0)) {
                    freeswap = (double)strtoull(argv[1], 0, 10);
                    freeswap *= 1024;
                }
            }

            if (strneq(buf1, "Buffers:")) {
                argc = parse(buf1, argv);
                if (decimal(argv[1], 0)) {
                    buffers = (double)strtoull(argv[1], 0, 10);
                    buffers *= 1024;
                }
            }

            if (strneq(buf1, "Cached:")) {
                argc = parse(buf1, argv);
                if (decimal(argv[1], 0)) {
                    cached = (double)strtoull(argv[1], 0, 10);
                    cached *= 1024;
                }
            }
        }
        fclose(fp);
    } else {
        fclose(fp);

        if (!strlen(membuf) || !strlen(swapbuf))
	    return;

        argc = parse(membuf, argv);
        if (!decimal(argv[3], 0))
	    return;
        freemem = (double)strtoull(argv[3], 0, 10);
    }

    if (freemem >= (GIGABYTE)) 
	sprintf(buf2, "%.1f gb", freemem/(double)GIGABYTE);
    else if (freemem >= (100*MEGABYTE))
	sprintf(buf2, "%d mb", (int)(freemem/(double)MEGABYTE));
    else if (freemem >= MEGABYTE)
	sprintf(buf2, "%.1f mb", freemem/(double)MEGABYTE);
    else
	sprintf(buf2, "%ld kb", (ulong)(freemem/(double)KILOBYTE));

#ifdef _CURSES_
    mvwaddstr(Window.Page_Stats, 0, 20, mkstring(buf2, 7, CENTER|RJUST));
    wrefresh(Window.Page_Stats);
#endif
#ifdef _GTK_
    gtk_label_set_text(GTK_LABEL(Shm->wmd->free_mem), buf2);
#endif

    if (!new_meminfo) {
        if (!decimal(argv[5], 0))
            return;
        buffers = (double)strtoull(argv[5], 0, 10);
    }

    if (buffers >= (GIGABYTE))
        sprintf(buf2, "%.1f gb", buffers/(double)GIGABYTE);
    else if (buffers >= (100*MEGABYTE))
        sprintf(buf2, "%d mb", (int)(buffers/(double)MEGABYTE));
    else if (buffers >= MEGABYTE)
        sprintf(buf2, "%.1f mb", buffers/(double)MEGABYTE);
    else
        sprintf(buf2, "%ld kb", (ulong)(buffers/(double)KILOBYTE));

#ifdef _CURSES_
    mvwaddstr(Window.Page_Stats, 2, 20, mkstring(buf2, 7, CENTER|RJUST));
    wrefresh(Window.Page_Stats);
#endif
#ifdef _GTK_
    gtk_label_set_text(GTK_LABEL(Shm->wmd->buffers), buf2);
#endif

    if (!new_meminfo) {
        if (!decimal(argv[6], 0))
            return;
        cached = (double)strtoull(argv[6], 0, 10);
    }

    if (cached >= (GIGABYTE))
        sprintf(buf2, "%.1f gb", cached/(double)GIGABYTE);
    else if (cached >= (100*MEGABYTE))
        sprintf(buf2, "%d mb", (int)(cached/(double)MEGABYTE));
    else if (cached >= MEGABYTE)
        sprintf(buf2, "%.1f mb", cached/(double)MEGABYTE);
    else
        sprintf(buf2, "%ld kb", (ulong)(cached/(double)KILOBYTE));

#ifdef _CURSES_
    mvwaddstr(Window.Page_Stats, 2, 29, mkstring(buf2, 7, CENTER|RJUST));
    wrefresh(Window.Page_Stats);
#endif
#ifdef _GTK_
    gtk_label_set_text(GTK_LABEL(Shm->wmd->cached), buf2);
#endif

    if (!new_meminfo) {
        argc = parse(swapbuf, argv);
        if (!decimal(argv[3], 0))
            return;
       freeswap = (double)strtoull(argv[3], 0, 10);
    }

    if (freeswap >= (GIGABYTE))
        sprintf(buf2, "%.1f gb", freeswap/(double)GIGABYTE);
    else if (freeswap >= (100*MEGABYTE))
        sprintf(buf2, "%d mb", (int)(freeswap/(double)MEGABYTE));
    else if (freeswap >= MEGABYTE)
        sprintf(buf2, "%.1f mb", freeswap/(double)MEGABYTE);
    else
        sprintf(buf2, "%ld kb", (ulong)(freeswap/(double)KILOBYTE));

#ifdef _CURSES_
    mvwaddstr(Window.Page_Stats, 0, 29, mkstring(buf2, 8, CENTER|RJUST));
    wrefresh(Window.Page_Stats);
#endif
#ifdef _GTK_
    gtk_label_set_text(GTK_LABEL(Shm->wmd->free_swap), buf2);
#endif
}

/*
 *  Avoid the overhead of message passing entirely by allowing a test
 *  to post a message in the context of the window manager, or to allow
 *  the window manager to create a message string from the test's shared
 *  data.
 */

int
canned_message(int id, char *buffer)
{
	switch (Shm->ptbl[id].i_type)
	{
	case VMEM_TEST:
	    return(canned_vmem(id, buffer));

	case RATE_TEST:
	    return(canned_rate(id, buffer));

	default:
	    break;
	}

        return (FALSE);
}

void
unresolved(char *buffer, int id)
{
    char tmp[MESSAGE_SIZE];

    buffer[MESSAGE_SIZE-1] = (char)NULLCHAR;

    sprintf(tmp, "unresolved message: [%02x%02x%02x%02x%02x]",
        buffer[0] & 0xff, buffer[1] & 0xff, buffer[2] & 0xff,
        buffer[3] & 0xff, buffer[4] & 0xff);
    USER_MESSAGE(tmp);

    switch (id)
    {
    default:
	if (id >= Shm->procno) 
            sprintf(Shm->unresolved, "%s test ?: \"%s\"", tmp, buffer);
	else
            sprintf(Shm->unresolved, "%s test %d: \"%s\"", tmp, id+1, buffer);
        break;
    }
}

/*
 *  Decode a usex message and post it in a display-dependent manner.
 */

int
post_usex_message(int id, unsigned char cmd, char *buffer, BOOL *try_again)
{
	register int i ATTRIBUTE_UNUSED;
	char buffer1[MESSAGE_SIZE];
	char *ptr1, *ptr2;
	int logarg1;
    	long logarg2;

        switch (cmd)
        {
	    case FOPERATION:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, buffer+2);
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
		gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			strip_beginning_chars(strip_ending_chars
			(strip_ending_chars(buffer+2, '.'), '>'), '<'));
#endif
                break;

            case FSBRK:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "sbrk.....");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			"sbrk");
#endif
                break;

            case FMALLOC:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "malloc...");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			"malloc");
#endif
                break;

            case FCLEAR:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "          ");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(gtk_mgr_test_widget(id, cmd, 
			NULL)), " ");
#endif
                break;

            case FCOMPARE:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "compare..");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			"compare");
#endif
                break;

            case FREAD_:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "read.....");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			"read");
#endif
                break;

            case FWRITE_:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "write....");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			"write");
#endif
                break;

            case FSEEK:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "seek.....");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			"seek");
#endif
                break;

            case FOPEN_:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "open.....");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			"open");
#endif
                break;

            case FCLOSE:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "close....");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			"close");
#endif
                break;

            case FDELETE:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "delete...");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			"delete");
#endif
                break;

            case FIOCTL:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "ioctl....");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			"ioctl");
#endif
                break;

            case FSLEEP:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "sleep....");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			"sleep");
#endif
                break;

            case FWAIT:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _OPERATION, "waiting..");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].operation),
			"waiting");
#endif
                break;

            case FFILL:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _MODE, "Fill");
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].mode),
			"Fill");
#endif
                break;

            case FTRUN:
		switch (atoi(buffer+2))
		{
		case 0:
#ifdef _CURSES_
                	mvwaddstr(Window.P[id].action, 0, _MODE, "Trun");
			touchwin(Window.P[id].action);
                	DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                	gtk_label_set_text(GTK_LABEL
				(Shm->wmd->test_data[id].mode), "Trun");
#endif
			break;
		case 1:
			if (!(Shm->ptbl[id].i_stat & IO_BKGD)) {
#ifdef _CURSES_
                		mvwaddstr(Window.P[id].action, 0, _OPERATION, 
					"truncate.");
                		DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                		gtk_label_set_text(GTK_LABEL
					(Shm->wmd->test_data[id].operation),
					"truncate");
#endif
			}
			break;
		}
                break;

            case FPASS:
	        logarg1 = 0;
		logarg2 = 0;
		if ((ptr1 = strstr(buffer+2, ":"))) {
		    *ptr1 = 0;
		    ptr1++;
		    if ((ptr2 = strstr(ptr1, ":"))) {
			*ptr2 = 0;
			ptr2++;
			logarg2 = atol(ptr2);
		    }
                    logarg1 = atoi(ptr1);	           
		}

		i = strlen(buffer + 2) > 4 ? 
			_PASS - (strlen(buffer + 2) - 4) : _PASS;

		if (!(Shm->ptbl[id].i_stat & IO_NOLOG)) {
                    char logbuf[MESSAGE_SIZE];

		    logbuf[0] = 0;

		    switch (Shm->ptbl[id].i_type)
		    {
		    case DISK_TEST:
			if (logarg2) {
			    switch (logarg1)
			    {
			    case 0:
				sprintf(logbuf, "FILESIZE: %ld", logarg2);
				break;

			    case INCOMPLETE_WRITE:
			        sprintf(logbuf, 
				    "FILESIZE: %ld [INCOMPLETE WRITE]",
					logarg2);
				break;

			    default:			    
			        sprintf(logbuf, 
				    "FILESIZE: %ld [EOFS ERRNO: %d]",
				        logarg2, logarg1);
				break;
			    }
			}
                        LOG(id, LOG_IO_PASS, atoi(buffer+2), strlen(logbuf) ?
			    logbuf : NULL);
			break;
		
		    case DHRY_TEST:
                        LOG(id, LOG_IO_PASS, atoi(buffer+2), 
				(void *)Shm->ptbl[id].dhrystones);
			break;

                    case WHET_TEST:
			sprintf(buffer1, "%.3f MWIPS", 
				Shm->ptbl[id].whet_mwips);
                        LOG(id, LOG_IO_PASS, atoi(buffer+2), (void *)buffer1);
                        break;

		    case RATE_TEST:
			sprintf(buffer1, "%s: %ld kbytes/sec", 
				Shm->ptbl[id].i_path,
				(ulong)Shm->ptbl[id].r_mean);
                        LOG(id, LOG_IO_PASS, atoi(buffer+2), buffer1);
			break;

		    default: 
		        LOG(id, LOG_IO_PASS, atoi(buffer+2), NULL); 
			break;
		    }
		}

		if (Shm->ptbl[id].i_type != VMEM_TEST) {
#ifdef _CURSES_
                	mvwaddstr(Window.P[id].action, 0, i-1, " ");
                	mvwaddstr(Window.P[id].action, 0, i, buffer + 2);
                	DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
			gtk_label_set_text(GTK_LABEL
				(Shm->wmd->test_data[id].pass),
				strip_beginning_whitespace(buffer+2));
#endif
		}
                break;

	    case LOG_MESSAGE:
               	LOG(id, LOG_MESSAGE, NOARG, buffer+2);
		break;

            case FPOINTER:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _POINTER, 
		    adjust_size(strtoul(buffer + 2, 0, 10), 9, buffer1, 1));
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
		gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].fpointer),
			adjust_size(strtoul(strip_beginning_whitespace
				(buffer+2), 0, 10), 9, buffer1, 1));
#endif
                break;

            case MANDATORY_FSTAT:
		if (strstr(buffer+2, "HOLD") && 
		    !(Shm->ptbl[id].i_stat & IO_HOLD)) 
			break; 
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _STAT, buffer + 2);
                DISPLAY(Window.P[id].action);
		if (strcmp(buffer + 2, "<WARN>") == 0)
		    if (!(Shm->mode & QUIET_MODE))
               		beep(); 
#endif
#ifdef _GTK_
                if (strcmp(buffer + 2, "<WARN>") == 0) {
                    if (!(Shm->mode & QUIET_MODE))
                        beep();
		    sprintf(buffer + 2, "WARN");
		}
		gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].stat),
			buffer+2);
		if (strstr(buffer+2, "BKGD"))
		  	gtk_mgr_test_background(id);
		if (strstr(buffer+2, "OK"))
		  	gtk_mgr_test_foreground(id);
#endif
		break;

            case FSTAT:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _STAT, buffer + 2);
#endif
#ifdef _GTK_
		strcpy(buffer1, buffer+2);
#endif

                /* Overwrite any "lagging" status with the last */
                /* "real-time" update from the input manager.   */

                if (strcmp(" DEAD ", buffer + 2) == 0) {
                    Shm->ptbl[id].i_stat |= IO_DEAD;
#ifdef _CURSES_
                    mvwaddstr(Window.P[id].action, 0, _STAT, "<DEAD>");
#endif
#ifdef _GTK_
		    strcpy(buffer1, "DEAD");
#endif
                    Kill(Shm->ptbl[id].i_pid, SIGUSR1, "W1", K_IO(id));
		    if (!Shm->ptbl[id].i_internal_kill_source)
		        Shm->ptbl[id].i_internal_kill_source = 
			    "curses_mgr: FSTAT DEAD";
                }
                else if (Shm->ptbl[id].i_stat & IO_HOLD) {
#ifdef _CURSES_
                    mvwaddstr(Window.P[id].action, 0, _STAT, " HOLD ");
#endif
#ifdef _GTK_
		    strcpy(buffer1, "HOLD");
#endif
                    *try_again = TRUE;
                }
                else if (Shm->ptbl[id].i_stat & IO_BKGD) {
#ifdef _CURSES_
                    mvwaddstr(Window.P[id].action, 0, _STAT, " BKGD ");
#endif
#ifdef _GTK_
		    strcpy(buffer1, "BKGD");
                    gtk_mgr_test_background(id);
#endif
                    *try_again = TRUE;
                }
                else if (Shm->ptbl[id].i_stat & IO_DEAD) {
#ifdef _CURSES_
                    mvwaddstr(Window.P[id].action, 0, _STAT, "<DEAD>");
		    if (!(Shm->mode & QUIET_MODE))
                        beep();
#endif
#ifdef _GTK_
		    strcpy(buffer1, "DEAD");
		    if (!(Shm->mode & QUIET_MODE))
                        beep();
#endif
                    *try_again = TRUE;
                }
                else if ((strcmp(" BKGD ", buffer + 2) == 0) &&
                    (Shm->ptbl[id].i_type == BIN_TEST) &&
                    !(Shm->ptbl[id].i_stat & IO_BKGD)) {
                    *try_again = TRUE;
                    break;
                }
		else if (strstr(buffer +2, "OK")) {
#ifdef _GTK_
               	    gtk_mgr_test_foreground(id);
#endif
		}
#ifdef _CURSES_
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
		gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].stat),
			buffer1);
#endif
                break;

	    case MANDATORY_FMODE:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _MODE, buffer + 2);
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
		gtk_label_set_text(gtk_mgr_test_widget(id, cmd, buffer+2),
			buffer+2);
#endif
                break;

            case FMODE:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _MODE, buffer + 2);
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
                gtk_label_set_text(gtk_mgr_test_widget(id, cmd, buffer+2),
                        buffer+2);
#endif
                break;

            case FERROR:
#ifdef _CURSES_
                clear_field(id, _SIZE, strlen(buffer+2) > 35 ? 
                    ERRMSG_SIZE : 35);
                mvwaddstr(Window.P[id].action, 0, _SIZE, buffer + 2);
                mvwaddstr(Window.P[id].action, 0, _STAT, "<DEAD>");
                wrefresh(Window.P[id].action);
#endif
#ifdef _GTK_
		gtk_label_set_text(GTK_LABEL(gtk_mgr_test_widget(id, cmd,
                        buffer+2)), buffer+2);
		post_test_status(id, "DEAD");
#endif
                Shm->ptbl[id].i_stat |= IO_DEAD;
                Kill(Shm->ptbl[id].i_pid, SIGUSR1, "W2", K_IO(id));
		if (!Shm->ptbl[id].i_internal_kill_source)
		    Shm->ptbl[id].i_internal_kill_source = "curses_mgr: FERROR";
                break;

            case COMPARE_ERR:
#ifdef _CURSES_
                mvwaddstr(stdscr, (id + 3), 14, buffer + 2);
                if (!(Shm->mode & DEBUG_MODE))
                {
                    refresh();           /* Refresh the screen    */
                    wrefresh(curscr);    /* with a compare error. */
                }
#endif
#ifdef _GTK_
                gtk_label_set_text(GTK_LABEL(gtk_mgr_test_widget(id, cmd,
                        buffer+2)), buffer+2);
#endif
                break;

            case MANDATORY_FSHELL:
            case FSIZE:
            case FSHELL:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _SIZE, buffer + 2);
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
		gtk_label_set_text(GTK_LABEL(gtk_mgr_test_widget(id, cmd, 
			buffer+2)), buffer+2);
#endif
                break;

            case FILENAME:
#ifdef _CURSES_
                mvwaddstr(Window.P[id].action, 0, _FILENAME, buffer + 2);
                DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
		gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].filename),
			buffer+2);
#endif
                break;

            case MANDATORY_CANNED:
            case CANNED:
                switch (Shm->ptbl[id].i_type) 
                {
		case RATE_TEST:
#ifdef _CURSES_
                	mvwaddstr(Window.P[id].action, 0, _OPERATION, buffer+2);
                	DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
			gtk_label_set_text(GTK_LABEL
				(Shm->wmd->test_data[id].operation),
				buffer+2);
#endif
			break;

		case VMEM_TEST:
		    if (Shm->ptbl[id].pass_divisor == 0) {
                    	Shm->ptbl[id].pass_divisor++;
		    } 
		    else {
#ifdef _CURSES_
			if (*(buffer + 2) == (char)NULLCHAR) {
			    unresolved(buffer, id);
			    break;
			}

			sprintf(buffer, "virtual memory test %s",
				curses_vmem_dance(id, buffer+2));

                	mvwaddstr(Window.P[id].action, 0, _FILENAME, buffer);
                	DISPLAY(Window.P[id].action);
#endif
#ifdef _GTK_
			gtk_mgr_vmem_dance(id, atoi(buffer+2));
#endif
		    }
                }
                break;

            case STOP_USEX:
                common_kill(KILL_ALL, SHUTDOWN);   /* Kill everybody else... */
                die(0, DIE(23), FALSE);            /* Then commit suicide.   */

            case REFRESH:
#ifdef _CURSES_
                if (Shm->mode & (DEBUG_MODE | NO_REFRESH_MODE))    
                    break;                  /* Ignore time manager refresh */
                else                        /* calls when either of these  */
                {                           /* two flags are set.          */
                    refresh();
                    wrefresh(curscr);
                }
#endif
#ifdef _GTK_
		;  /* NOT APPLICABLE */
#endif
                break;

	    case SYNCHRONIZE:
		Shm->ptbl[id].i_stat &= ~IO_SYNC;
		if (strlen(buffer) > 2)
		     USER_MESSAGE(&buffer[2]);
		break;

	    case KEEP_ALIVE:
		break;

	    case BIN_TEST_MOD:
		console("BIN_TEST_MOD: %d => %lx %lx\n",
		    id+1, 
		    Shm->ptbl[id].test_mod.bp,
		    Shm->ptbl[id].test_mod.cmdflag);
		bin_test_mod_callback(&Shm->ptbl[id]);
		break;

            default:
		return FALSE;

        } /* switch */

	return TRUE;
}
