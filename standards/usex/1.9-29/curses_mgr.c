/*  Author: David Anderson <anderson@redhat.com> */

#include "defs.h"

/*
 *  curses_mgr:  Handles all of the USEX display operations after the 
 *               initial parameter entry.  All other processes send data 
 *               for display to this module.  Upon initialization, the 
 *               window manager calls init_windows() and init_screens() 
 *               to set up the screen processing functions, define the 
 *               individual windows, and initialize the user display.
 *               Then it goes into a forever loop reading messages sent 
 *               to it via System V messages protocol, and performing the 
 *               requested action.
 *
 *               The format of the messages is as follows:
 *                                                                          
 *                   command[process id][a specific string]NULL
 *                                                                           
 *              where "command" is a character, the optional "process id" 
 *              is a byte value, the optional "specific string" is of a 
 *              variable length.  The string is read from the appropriate 
 *              message queue, and placed in a local character array called 
 *              "buffer".  A switch is done on the command which is contained 
 *              in buffer[0], and the appropriate action taken. 
 *
 *              Prior to each pass through the message queue, "/dev/tty" is
 *              read for user input.  User input is gathered in a global
 *              array, waiting for some type of delimiter, either a <RETURN>
 *              or a usex-defined character.  When this happens the user
 *              input array is passed to the input_mgr() for processing.
 *
 *  BitKeeper ID: @(#)window_mgr.c 1.4
 *
 *  CVS: $Revision: 1.8 $ $Date: 2016/02/10 19:25:51 $
 */

WINDOW_TABLE Window;           /* Table of window pointers. */

static void init_windows(void);
static void incompatible_window(void);
static void init_screens(void);
static int center(char *, char *, char *);
static void help(void);
static void interactive_inquiry(char *, FILE *, char);
static void invalid_input(void);

int
curses_mgr(int unused1, char **unused2)
{
    register int i;
    char buffer[MESSAGE_SIZE];  /* Buffer to stuff dequeued messages into.   */
    unsigned char cmd;          /* Stash for the window manager command.     */
    int id;                     /* Stash for I/O test local process ID.      */
    int last_queue = 0;         /* Message queues place holders. */
    int fd;                     /* file descriptor for "/dev/tty". */
    int iflags;                 /* Storage for fcntl flags. */
    char c;                     /* Dynamic input storage. */
    BOOL try_again = FALSE;     /* Set to retry same message queue again. */
    BOOL shellcmd = FALSE;      /* In the midst of gathering a shell command. */
    int cycle_reads = 0;        /* Number of queues read each cycle through. */
    struct timer_request *treq = &Shm->timer_request;

    init_windows();      /* Put the screen into "window" mode. */
    init_screens();      /* Display initial stuff. */

    init_common();       /* curses/GTK common initialization */

    /* Set up "/dev/tty" in O_NDELAY read mode to check for user input. */

    if (!NO_DISPLAY()) {
        fd = open("/dev/tty", O_RDONLY);
        if (fd < 0) {
             Shm->perror("/dev/tty");
             common_kill(KILL_ALL, SHUTDOWN);
             die(0, DIE(20), FALSE);
        }
        if ((iflags = fcntl(fd, F_GETFL, 0)) == -1) 
            Shm->perror("fcntl(F_GETFL)");
        if ((iflags = fcntl(fd, F_SETFL, iflags | O_NDELAY)) == -1) 
            Shm->perror("fcntl(F_SETFL)");
        if ((iflags = fcntl(fd, F_GETFL, 0)) == -1) 
            Shm->perror("fcntl(F_GETFL)");
    }

    if (Shm->stallvalue == UNSET_STALLVALUE)
	Shm->stallvalue = DEFAULT_STALLVALUE;
    else if (Shm->stallvalue > MAX_STALLVALUE)
	Shm->stallvalue = MAX_STALLVALUE;

    for (EVER) /* Read messages placed on the queue till the end of time. */
    {
	if (check_timer(treq)) {
		do_timer_functions();
	    	Shm->mode |= WINUPDATE;
	}

	if (mother_is_dead(Shm->parent_shell, "W18")) {  /* sh -c is dead. */
	    common_kill(KILL_ALL, SHUTDOWN);
	    die(0, DIE(22), FALSE);
        }

	if (NO_DISPLAY())
		goto check_messages;

        /* However, first check if there's any user input hanging around. */
        /* Stash it in the input array, and if it's a delimiter, then     */
        /* send the string to the input_mgr() for execution.              */

        if (CTRL_C_ENTERED() || read(fd, &c, 1) == 1) {

	    if (CTRL_C_ENTERED()) {
		Shm->mode &= ~CTRL_C;
		CLEAR_STRING(Shm->input);
		c = 'k';
	    }

	    if (strlen(Shm->input) >= MAX_INPUT) {
        	beep();
        	USER_PROMPT_END("sorry -- input message is too long!");
        	bzero(Shm->input, MESSAGE_SIZE);
		goto check_messages;
	    }

	    Shm->mode |= WINUPDATE;

	    if (Shm->mode & SHUTDOWN_MODE) {
		switch (c) 
		{
		case 'q':
		case 'k':
		case 'y':
		case 'Y':
			CLEAR_PROMPT();
			strcpy(Shm->input, "k");
		        save_screen(SCREEN_SAVED);
                        input_mgr();
			break;

		default:
			Shm->mode &= ~SHUTDOWN_MODE;
			bzero(Shm->input, MESSAGE_SIZE);
			CLEAR_PROMPT();
			goto check_messages;
		}
            }

            if (strlen(Shm->input) == 0) { 
		switch (c)
		{
		case 'k':
		case 'q':
		    CLEAR_PROMPT();
		    sprintf(Shm->input, "Are you sure? [y/n]: ");
		    Shm->mode |= SHUTDOWN_MODE;
		    goto check_messages;

		case 's':
		    save_screen(0);
		    break;
		}
		CLEAR_PROMPT();
	    }

            if (!shellcmd && (strlen(Shm->input) == MAX_INPUT))
                c = '\n';

            if (c == '\n' || c == '\r') {
		USER_PROMPT_END(Shm->input);
                input_mgr();
		bzero(Shm->input, MESSAGE_SIZE);
                shellcmd = FALSE;
            }
            else if (shellcmd) {
                if (c == '\b') {
                    if (strlen(Shm->input) != 0) {
                        i = strlen(Shm->input) - 1;
                        if (strlen(Shm->input) == 1 && Shm->input[0] == '!')
                            shellcmd = FALSE;
                        Shm->input[i] = ' ';
                        Shm->input[i] = (char)NULLCHAR;
                    }
                }
                else 
                    Shm->input[strlen(Shm->input)] = c;

		if (strlen(Shm->input) == 0)
			CLEAR_PROMPT();
            }
            else {
                switch (c) 
                {
		    case 's':     /* Dump a test status file */
                    case 'k':     /* Kill.                   */
                    case 'h':     /* Help or hold.           */
                    case 'd':     /* Toggle debug switch.    */
                    case 'F':     /* Save default output filename. */
                    case 'f':     /* Get input filename.     */
                    case 'b':     /* Background  (or build)  */
                    case 'i':     /* Inquiry (new style)     */
                    case 'I':     /* Inquiry (new style)     */
		    case 'm':     /* Last message query      */
                    case 'M':     /* Fatal message query     */
		    case 'u':	  /* Utsname dump (obsolete) */
                    case 'T':     /* External top session    */
                        Shm->input[strlen(Shm->input)] = c;
                        Shm->input[strlen(Shm->input)] = (char)NULLCHAR;
			USER_PROMPT_END(Shm->input);
                        input_mgr();
			bzero(Shm->input, MESSAGE_SIZE);
                        shellcmd = FALSE;
                        break;

                    case '\b':
                        if (strlen(Shm->input) != 0) {
                            i = strlen(Shm->input) - 1;
                            Shm->input[i] = (char)NULLCHAR;
			    if (strlen(Shm->input) == 0)
				CLEAR_PROMPT();
                        }
                        break;
    
                    case '!':
                        if (strlen(Shm->input) == 0) {
                            if (c == '!') {
                                shellcmd = TRUE;        
                                Shm->input[strlen(Shm->input)] = c;
			    }
                        }
			break;

                    default:
                        Shm->input[strlen(Shm->input)] = c;
                        break;
                }
            }
        }

	if (strlen(Shm->input)) 
		USER_PROMPT(Shm->input);

check_messages:

        bzero(buffer, MESSAGE_SIZE);  /* paranoia */

       /*
        * If it's necessary, aesthetic, or reasonable to read the 
        * same message queue again, just decrement "last_queue".  
        */

        if (try_again) {
            last_queue--;
            try_again = FALSE;
        }

        if (last_queue == NUMSG)
            errdaemon(cycle_reads);

        last_queue %= NUMSG;

        if (last_queue == 0)
            cycle_reads = 0;

	if (!get_usex_message(last_queue++, buffer))
	    continue;

	cycle_reads++;

        cmd = (unsigned char)buffer[0];     /* Pull out the command. */

        id = (int)(buffer[1] - FIRST_ID);   /* "id" is only present in  */
                                            /* messages from I/O tests. */

	switch (verify_message(id, cmd, buffer))
	{
	case IGNORE_MESSAGE:
		continue;

	case POST_MESSAGE:
		break;

	case RETRY_QUEUE:
        	try_again = TRUE;  /* Ignore command and clear queue. */
		continue;
	}

       /*
        * Decipher the command, go to the appropriate window,    
        * and enter either a canned string or the string passed.
        */

	Shm->mode |= WINUPDATE;

	if (!post_usex_message(id, cmd, buffer, &try_again))
	    	unresolved(buffer, last_queue-1);

    } /* for (EVER) */

    exit(0);
}

/*
 *  wind_intr:  If user input was detected at the top of the loop,
 *              this "interrupt" routine is called by the input_mgr()
 *              to perform an immediate response.
 */

void 
wind_intr(void)
{
    char c, wind_buffer[MESSAGE_SIZE];     /* Storage buffer.    */
    register int i, j, k;  
    char buffer1[MESSAGE_SIZE];
    FILE *fp;

    strcpy(wind_buffer, Shm->mom);

    /* Perform the command. The cases are fairly self-explanatory. */

    switch (wind_buffer[0])
    {
	case BUILD_INFO:
        case UNAME_INFO:
        case INQUIRY:
	case FULL_INQUIRY:
        case LAST_MESSAGE:
        case '!':
            touchwin(stdscr);  
            touchwin(Window.Help_Window);  
            wclear(Window.Help_Window); 
            wrefresh(Window.Help_Window); 
            move(0,0);
            reset_shell_mode();
            /* signal(SIGCHLD, SIG_DFL); */
	    if ((wind_buffer[0] == INQUIRY) || 
	        (wind_buffer[0] == FULL_INQUIRY)) {
		fp = open_output_pipe();
                interactive_inquiry(&wind_buffer[1], fp, wind_buffer[0]);
		close_output_pipe();
            }
	    else if (wind_buffer[0] == LAST_MESSAGE) {
		fp = open_output_pipe();
                last_message_query(wind_buffer[1], fp, TRUE);
		close_output_pipe();
	    }
	    else if (wind_buffer[0] == BUILD_INFO) {
		Shm->printf("%s\r\n", build_date);
		Shm->printf("%s\r\n", build_machine);
		Shm->printf("%s\r\n", build_id);
		Shm->printf("%s\r\n\r\n", build_sum);
            }
            else if (wind_buffer[0] == UNAME_INFO) {
                Shm->printf(" sysname: %s\r\n", Shm->utsname.sysname);
                Shm->printf("nodename: %s\r\n", Shm->utsname.nodename);
                Shm->printf(" release: %s\r\n", Shm->utsname.release);
                Shm->printf(" version: %s\r\n", Shm->utsname.version);
                Shm->printf(" machine: %s\r\n\r\n", Shm->utsname.machine);
#ifdef LOCKSTATS
		dump_ring_stats();
#endif
            }
	    else if (wind_buffer[0] == DUMP_STATUS_FILE) {
		dump_status(INTERACTIVE_STATUS, NULL);
	    }
	    else
                system(&wind_buffer[1]);
            /* signal(SIGCHLD, SIG_IGN); */
            reset_prog_mode();
            if ((strncmp(wind_buffer, "!sh", strlen("!sh")) != 0) &&
                (strncmp(wind_buffer, "!csh", strlen("!csh")) != 0)) {
                Shm->printf("\nEnter <RETURN> to continue: ");
                fflush(stdout);
                fflush(stdin);
                do {
                     c = getchar();   
                } while (c != '\r' && c != '\n');
            }
            wclear(Window.Help_Window); 
            wrefresh(Window.Help_Window);
            refresh();
            wrefresh(curscr);
            break;

	case DUMP_STATUS_FILE:
	    dump_status(INTERACTIVE_STATUS, NULL);
	    break;

        case DEBUG:
	    if (Shm->mode & DEBUG_MODE)
		CLEAR_MESSAGE();
	    else
		USER_MESSAGE("Debug ON");
            if (Shm->mode & DEBUG_MODE)
                Shm->mode &= ~DEBUG_MODE;
            else
                Shm->mode |= DEBUG_MODE;
            if (!(Shm->mode & DEBUG_MODE))    /* Put the asterisk back... */
            {
                for (i = 0; i < Shm->procno; ++i)
                    wrefresh(Window.P[i].action);

                wrefresh(Window.Date);
                wrefresh(Window.Stime);
                wrefresh(Window.Test_Time);

                mvwaddstr(Window.Debug_Window, 0, 0, Shm->mode & AT_KLUDGE ? 
                    " " : "*");
                wrefresh(Window.Debug_Window);  
                refresh();
                wrefresh(curscr);  
            }
            break;

        case REFRESH:
            switch (wind_buffer[1])    
            {
                case KILL: 
                    Shm->mode |= NO_REFRESH_MODE;  /* Kill automatic refresh. */
                    break;
                case CONTINUE:
                    Shm->mode &= ~NO_REFRESH_MODE;  /* Restore auto refresh. */
                case '\0':
                    refresh();
                    wrefresh(curscr);   /* Just refresh the screen. */
            }
	    CLEAR_MESSAGE();
	    CLEAR_PROMPT();
            break;

        case STOP_USEX:
            common_kill(KILL_ALL, SHUTDOWN);   /* Kill everybody else... */
            die(0, DIE(24), FALSE);            /* Then commit suicide.   */

        case HELP:
            help();

            for (i = 0; (i < COLS) && (Shm->mode & AT_KLUDGE); i++)
            {
                move(Shm->lines_used-1, i); /* Re-display the "lost" last */
                printw("*");        /* line on DEC terminals.  (Don't ask...) */
            }
            refresh();
            wrefresh(curscr);     /* Just refresh the screen. */
            break;

        case USER_INPUT:
            USER_MESSAGE(wind_buffer + 1);
            break;

        case FSTAT:
            i = atoi(wind_buffer + 2);
	    k = 0;

            if ((Shm->ptbl[i].i_stat & IO_DEAD) && (wind_buffer[1] != KILL)) {
                sprintf(wind_buffer, "<DEAD>"); 
                mvwaddstr(Window.P[i].action, 0, _STAT, wind_buffer);
                wrefresh(Window.P[i].action);
                break;
	    }
	
            switch(wind_buffer[1])
            {
                case KILL:  
                    common_kill(i, NOARG);
                    if (Shm->ptbl[i].i_stat & IO_DEAD) {
                        sprintf(wind_buffer, "<DEAD>"); 
		    }
                    else {
                        sprintf(wind_buffer, "(KILL)"); 
		    }
                    break;

		case HOLD:
console("received HOLD for %d\n", i);
		    k = HOLD;
                case BACKGROUND:     /* Clear a few windows first. */
                    switch (Shm->ptbl[i].i_type)
                    {
                    case VMEM_TEST:
                        if (k != HOLD) {
                            mvwaddstr(Window.P[i].action, 0, 
				_PASS-5, "         ");
                            wrefresh(Window.P[i].action);
			}
                        break;
		    case WHET_TEST:
		    case RATE_TEST:
                        sprintf(wind_buffer, k == HOLD ? " WAIT " : " BKGD ");
                        mvwaddstr(Window.P[i].action, 0, _STAT, wind_buffer);
			break;
		    case DHRY_TEST:
                    case BIN_TEST:
                        break;
                    default:
                        if (Shm->mode & AT_KLUDGE) {
                            sprintf(wind_buffer,"--------------------------");
                            mvwaddstr(Window.P[i].action, 0, _MODE,wind_buffer);
                            mvwaddstr(Window.P[i].action, 0, _STAT, "------");
                            wrefresh(Window.P[i].action);
                        }
                        sprintf(wind_buffer,"                          ");
                        mvwaddstr(Window.P[i].action, 0, _MODE, wind_buffer);
                        sprintf(wind_buffer, k == HOLD ? " WAIT " : " BKGD ");
                        mvwaddstr(Window.P[i].action, 0, _STAT, wind_buffer);
                        break;
                    }

                    switch (Shm->ptbl[i].i_type)
                    {
                        case WHET_TEST:
		        case DEBUG_TEST:
			    break;

			case DISK_TEST:
                            mvwaddstr(Window.P[i].action, 0, _OPERATION,
                                "         ");
                            DISPLAY(Window.P[i].action);
                            mvwaddstr(Window.P[i].action, 0, _MODE,
                                Shm->ptbl[i].i_stat & IO_FILL ?  
				"Fill" : "Trun");
                            DISPLAY(Window.P[i].action);
			    break;

                        case DHRY_TEST:
			case VMEM_TEST:
                        case BIN_TEST:
                            sprintf(wind_buffer, k == HOLD ? 
				" WAIT " : " BKGD ");
                            break;
                        case USER_TEST:
                	    bzero(wind_buffer, MESSAGE_SIZE);
                	    sprintf(wind_buffer,
                  "                                                         ]");
                            for (j = 0; (j < 53) && Shm->ptbl[i].i_file[j]; j++)
                                wind_buffer[j] = Shm->ptbl[i].i_file[j];

                            if (strlen(Shm->ptbl[i].i_file) > 53) {
                                sprintf(&wind_buffer[52], ">  [ ]");
                            }
                            else
                                wind_buffer[j+2] = '[';
                            mvwprintw(Window.P[i].action, 0,_SIZE, "%s", 
				wind_buffer);
                            sprintf(wind_buffer, k == HOLD ?
				" WAIT " : " BKGD ");
                            break;
                        default:
                            mvwprintw (Window.P[i].action, 0, _SIZE, "%5s", 
				adjust_size(Shm->ptbl[i].i_size, 5, 
				buffer1, 0));
                    }
                    wrefresh (Window.P[i].action);
                    break;

                case CONTINUE:
                    if (Shm->ptbl[i].i_type == DISK_TEST) 
                    {
                       /*
                        *  Display instant Fill/Trun message. 
                        */
                        if (Shm->ptbl[i].i_stat & IO_FILL) 
                            mvwaddstr(Window.P[i].action, 0, _MODE, "Fill");
                        else
                            mvwaddstr(Window.P[i].action, 0, _MODE, "Trun");
                    }

                    switch (Shm->ptbl[i].i_type)
                    {
                        case WHET_TEST:
			case DEBUG_TEST:
                        case DHRY_TEST:
                        case VMEM_TEST:
                        case USER_TEST:
                        case BIN_TEST:
                            break;
                        default:
                            mvwprintw (Window.P[i].action, 0, _SIZE, "%5s", 
			        adjust_size(Shm->ptbl[i].i_size, 5,
                                buffer1, 0));
                    }
                    wrefresh(Window.P[i].action);
                    sprintf(wind_buffer, "  OK  ");
                    break;

                default:
                    return;
            }
            mvwaddstr(Window.P[i].action, 0, _STAT, wind_buffer);
            wrefresh(Window.P[i].action);
            break;

        default:
            break;

    }  /* switch */

    if ((Shm->mode & DEBUG_MODE))              
    {                       /* When in the debug mode, put the cursor in the */
                            /* bottom left-hand corner of the display screen. */

        mvwaddstr(Window.Debug_Window, 0, 0, "-");  /* In order to do so,   */
        wrefresh(Window.Debug_Window);              /* curses requires that */
        mvwaddstr(Window.Debug_Window, 0, 0, " ");  /* a "change" to the    */
        wrefresh(Window.Debug_Window);              /* window is made.      */
    }
}

/*
 *  init_windows: Defines all of the windows on the user display screen  
 *                via the "subwin" or "newwin" system calls.  The number
 *                of test file windows is variable according to the "procno" 
 *                variable entered by the user. 
 */

static void
init_windows(void)
{
    register int i;  
    int lines_used;

    initscr();              /* Put terminal into window mode.                 */
    if (stdscr == (WINDOW *)NULL) {
        fprintf(stderr, 
	    "usex: curses initscr() function failed to initialize stdscr.\r\n");
        die(0, DIE(25), FALSE);
    }
    crmode();               /* Preserves function of editing and signal keys. */
    noecho();               /* Turns off character echo mode.                 */
    nonl();                 /* <RETURN> key is not mapped to CR-LF.           */
    leaveok(stdscr, TRUE);      /* Leave cursor at last character displayed.  */
    scrollok(stdscr, FALSE);    /* Not OK to scroll the standard screen.      */

    /* The I/O Test WINDOWS. */

    /* The subwin() call requires the following arguments:  */
    /*  subwin("subwindow of", lines, length, x-pos, y-pos) */

    for (i = 0; i < Shm->procno; ++i) 
	leaveok((Window.P[i].action = subwin(stdscr, 1, 77, i + 3, 3)), TRUE);

    /* The fixed windows. */
    lines_used = Shm->lines_used;
    leaveok((Window.Date = subwin(stdscr, 1, 8, lines_used-2, 5)), TRUE); 
    leaveok((Window.Stime = subwin(stdscr, 1, 8, lines_used-2, 14)), TRUE);
    leaveok((Window.Test_Time = subwin(stdscr, 1, 9, lines_used-7, 68)), TRUE);
#ifdef NOTDEF
    leaveok((Window.Mean_Rate = subwin(stdscr, 1, 20, lines_used-5, 35)), TRUE);
    leaveok((Window.High_Rate = subwin(stdscr, 1, 20, lines_used-4, 35)), TRUE);
    leaveok((Window.Low_Rate = subwin(stdscr, 1, 20, lines_used-3, 35)), TRUE);
    leaveok((Window.Last_Rate = subwin(stdscr, 1, 20, lines_used-2, 35)), TRUE);
    leaveok((Window.Xfer_Pass = subwin(stdscr, 1, 18, lines_used-5, 50)), TRUE);
    leaveok((Window.Xfer_Stat = subwin(stdscr, 1, 18, lines_used-3, 50)), TRUE);
#endif
    leaveok((Window.Cpu_Stats = subwin(stdscr, 1, 40, lines_used-7, 27)), TRUE);
    leaveok((Window.Page_Stats = subwin(stdscr, 3, 52, lines_used-4, 27)),TRUE);
#ifdef NOTDEF
    leaveok((Window.Load = subwin(stdscr, 1, 12, lines_used-5, 67)), TRUE);
    leaveok((Window.Free = subwin(stdscr, 1, 12, lines_used-4, 67)), TRUE);
#endif
    leaveok((Window.Help_Window = newwin(lines_used, COLS, 0, 0)), TRUE);
    leaveok((Window.Debug_Window = subwin(stdscr, 1, COLS-2, lines_used-1, 0)), 
	FALSE);
    leaveok((Window.Prompt_Window = subwin(stdscr, 1, COLS-2, lines_used-9, 0)),
	FALSE);

    for (i = 0; i < Shm->procno; ++i)
	if (!Window.P[i].action)
	    incompatible_window();

    if (!Window.Date || !Window.Stime || !Window.Test_Time || 
#ifdef NOTDEF
        !Window.Mean_Rate || !Window.High_Rate  || !Window.Low_Rate ||
        !Window.Last_Rate || !Window.Xfer_Pass || !Window.Xfer_Stat ||
	!Window.Load || !Window.Free ||
#endif
	!Window.Help_Window || !Window.Debug_Window || !Window.Cpu_Stats)
	    incompatible_window();
}

static void
incompatible_window(void)
{
    sprintf(Shm->saved_error_msg,
 "\r\nusex: incompatible terminal geometry -- at least 80x24 is required\r\n");

    die(0, DIE(26), FALSE);
}

/*
 *  init_screens: Initializes the user display screen.  It is only called 
 *                once upon initialization by curses_mgr().
 */

static void
init_screens(void)
{
    register int i, j, smp; 
    char buffer1[STRINGSIZE];
    char buffer2[STRINGSIZE];

    /* Initialize the Standard Screen. */

    if (!(Shm->mode & AT_KLUDGE))
    {
        for (i = 0; i < COLS; ++i)   
        {
            move(0, i);    /* First draw a box around a 24 X 80 display area. */
            printw("*");
            move(Shm->lines_used-1, i);
            printw("*");
        }

        for (i = 0; i < Shm->lines_used; ++i)
        {
            move(i, 0);
            printw("*");
            move(i, 79);
            printw("*");
        }
    }

    /* Print the I/O TEST headers at the top. */

    move(1, 2);
    printw(
" ID  BSIZE  MODE   POINTER   OPERATION         FILE NAME         PASS  STAT");

    if (!(Shm->mode & AT_KLUDGE))
    {
        move(2, 2);
        printw(
" --  -----  ----  ---------  ---------  -----------------------  ----  ----");

    /* Separate the I/O TEST area from the rest of the screen. */

        move(Shm->lines_used-9, 1);
        for (i = 0; i < 78; ++i)
            printw("*");
    }

    /* Initialize the bottom part of the screen. */

    move(Shm->lines_used-8, 2);
    printw(
" Unix System EXerciser  %c  USER SYSTEM IDLE  LOADAVG  TASKS/RUN   TEST TIME",
        (Shm->mode & AT_KLUDGE) ? ' ' : '*');

    move(Shm->lines_used-7, 2);
    printw(
"                        %c                                       ",
        (Shm->mode & AT_KLUDGE) ? ' ' : '*');

    move(Shm->lines_used-6, 2);
    printw(
"                        %c                                                  ",
        (Shm->mode & AT_KLUDGE) ? ' ' : '*');

    move(Shm->lines_used-5, 2);
    printw(
"                        %c  PAGE-IN PAGE-OUT  FREEMEM  FREESWAP   CSW   INTR",
        (Shm->mode & AT_KLUDGE) ? ' ' : '*');

    move(Shm->lines_used-4, 2);
    printw(
"                        %c                                       ",
        (Shm->mode & AT_KLUDGE) ? ' ' : '*');

#ifdef USEX_VERSION
    move(Shm->lines_used-7, center("USEX Version ", USEX_VERSION, buffer1));
    printw(buffer1);
#else
    if (strncmp(SCCS_id, "@(#)", 4) == 0) {
        char *ptr;

        ptr = &SCCS_id[strlen(SCCS_id)];
        while (*ptr != '\t')
            ptr--;
        ptr++;
	move(Shm->lines_used-7, center("USEX Version ", ptr, buffer1));
        printw(buffer1);
    }
    else {
	move(Shm->lines_used-7, center("USEX Version", "???", buffer1));
        printw(buffer1);
    }
#endif

    move(Shm->lines_used-3, 13);
    printw("             %c  SWAP-IN SWAP-OUT  BUFFERS   CACHED   FORKS",
        (Shm->mode & AT_KLUDGE) ? ' ' : '*');

    move(Shm->lines_used-2, 13);
    printw("             %c                                       ",
        (Shm->mode & AT_KLUDGE) ? ' ' : '*');

    /* 
     *  Display the utsname information.
     */

    smp = show_cpu_stats(GET_SMP_COUNT);

    if (smp) 
        sprintf(buffer1, 
	    "%s - %s (%d)", dec_node(Shm->utsname.nodename, buffer2), 
	    Shm->utsname.machine, smp);
    else
        sprintf(buffer1, 
	    "%s - %s", dec_node(Shm->utsname.nodename, buffer2), 
	    Shm->utsname.machine);

    move(Shm->lines_used-5, center(buffer1, "", buffer2));
    printw(buffer2);

    sprintf(buffer1, "%s %s", Shm->utsname.sysname, Shm->utsname.release);

    if (strlen(buffer1) > 25)
	buffer1[25] = (char)NULLCHAR;
    move(Shm->lines_used-4, center(buffer1, "", buffer2));
    printw(buffer2);

    if (!(Shm->mode & DEBUG_MODE))
        refresh();            /* Now refresh the whole screen. */

    /* Initialize and refresh the running I/O TEST windows. */

    for (i = 0; i < Shm->procno; ++i)
    {
        mvwprintw (Window.P[i].action, 0, _ACTION, "%2d", (i + 1));
        DISPLAY (Window.P[i].action);

        if ((Shm->ptbl[i].i_stat & (IO_FORK|IO_ADMIN1|IO_PIPE)) == IO_FORK) {
            sprintf(buffer2, "<FORK ERROR>");
            mvwaddstr(Window.P[i].action, 0, _SIZE, buffer2);
            DISPLAY (Window.P[i].action);
            mvwaddstr(Window.P[i].action, 0, _STAT, "<EXIT>");
            DISPLAY (Window.P[i].action);
            Shm->ptbl[i].i_stat |= IO_DEAD;
            continue;
        }

        switch (Shm->ptbl[i].i_type)
        {
            case WHET_TEST:
                mvwprintw (Window.P[i].action, 0, _FILENAME, "%-19s", 
                    "whetstone benchmark");
                break;

            case VMEM_TEST:
                mvwprintw (Window.P[i].action, 0, _FILENAME, "%-19s", 
                    "virtual memory test");
                break;

            case DHRY_TEST:
                mvwprintw (Window.P[i].action, 0, _FILENAME, "%-19s", 
                    "dhrystone benchmark");
                break;

            case BIN_TEST:
                mvwprintw (Window.P[i].action, 0, _FILENAME, "%-19s",
                    "bin command suite");
                break;

            case USER_TEST:
		bzero(buffer1, STRINGSIZE);
		sprintf(buffer1,
                  "                                                         ]");
		for (j = 0; (j < 53) && Shm->ptbl[i].i_file[j]; j++)
	            buffer1[j] = Shm->ptbl[i].i_file[j];

                if (strlen(Shm->ptbl[i].i_file) > 53) {
                     sprintf(&buffer1[52], ">  [ ]");
                }
		else
                     buffer1[j+2] = '[';
                mvwprintw(Window.P[i].action, 0,_SIZE, "%s", buffer1);
                break;

            case DEBUG_TEST:
                mvwprintw (Window.P[i].action, 0, _FILENAME, "%-19s",
                    "usex debug test");
                break;

	    case RATE_TEST:
                mvwprintw (Window.P[i].action, 0, _MODE, "%s", "Rate");
		/* FALLTHROUGH */

            case DISK_TEST:
               	mvwprintw(Window.P[i].action, 0,_SIZE, "%5s", 
			adjust_size(Shm->ptbl[i].i_size, 5, buffer1, 0));
		break;
        }
        if (Shm->ptbl[i].i_type != VMEM_TEST)
            mvwaddstr(Window.P[i].action, 0, _PASS, "   1");
        if (Shm->ptbl[i].i_type == BIN_TEST)
            mvwaddstr(Window.P[i].action, 0, _STAT, " BKGD ");
        else
            mvwaddstr(Window.P[i].action, 0, _STAT, 
            (Shm->mode & BKGD_MODE) ? " BKGD " : "  OK  ");
        DISPLAY (Window.P[i].action);
    }

    Shm->mode |= CINIT;
}

static int
center(char *s1, char *s2, char *buf)
{
    sprintf(buf, "%s%s", s1, s2);

    if (strlen(buf) >= 25)
	return(1);
    else if (strlen(buf) == 24)
	return(2);
    else 
        return(1 + ((25 - strlen(buf))/2));
}

/*
 *  help:  Clears the current screen contents and puts up the HELP window, 
 *         which contains a summary of all of the user input commands available
 *         during USEX run-time.  It is shown after the user enters initial 
 *         parameters, and whenever "h" is typed at the keyboard.  
 */

static char *help_window[] = 
{
"****************[ SUMMARY OF INTERACTIVE RUNTIME COMMANDS ]*****************",
"*                                                                          *",
"*  h           Display this HELP window.                                   *",
"*  <RETURN>    Refresh the display screen.                                 *",
"*  ![command]  Go into a UNIX shell, or run a command.  Follow w/<RETURN>. *",
"*  d           Enter/Leave DEBUG mode.  No screen updates will occur.      *",
"*  f or F      Display input file name or display and save input file name.*",
"*  tk          Kill all tests.                                             *",
"*  tb          Put test displays in background (BKGD) mode.                *",
"*  th          Put all tests in HOLD mode.                                 *",
"*  t<RETURN>   Resume full display for all tests.                          *",
"*  t#k         Kill test #.                                                *",
"*  t#b         Put test # display in background (BKGD) mode.               *",
"*  t#h         Put test # in HOLD mode.                                    *",
"*  t#m         Display last set of messages from test #.                   *",
"*  t#i         Inquiry of internal state of test #.                        *",
"*  t#<RETURN>  Resume full display for test #.                             *",
"*  m           Display last set of messages from all tests.                *",
"*  M           Display fatal error messages from all dead tests.           *",
"*  i or I      Inquiry of usex internal state.                             *",
"*  s           Save snapshot of usex internal state in a file.             *",
"*  k or q      Kill USEX completely.                                       *",
"*                                                                          *",
"************************[ Hit <RETURN> to continue ]************************",
NULL
};

static char *AT_help_window[] = 
{
"                  SUMMARY OF INTERACTIVE RUNTIME COMMANDS                   ",
"                                                                            ",
"   h           Display this HELP window.                                    ",
"   <RETURN>    Refresh the display screen.                                  ",
"   ![command]  Go into a UNIX shell, or run a command.  Follow w/<RETURN>.  ",
"   d           Enter/Leave DEBUG mode.  No screen updates will occur.       ",
"   f or F      Display input file name or display and save input file name. ",
"   tk          Kill all tests.                                              ",
"   tb          Put test displays in background (BKGD) mode.                 ",
"   th          Put all tests in HOLD mode.                                  ",
"   t<RETURN>   Resume full display for all tests.                           ",
"   t#k         Kill test #.                                                 ",
"   t#b         Put test # display in background (BKGD) mode.                ",
"   t#h         Put test # in HOLD mode.                                     ",
"   t#m         Display last set of messages from test #.                    ",
"   t#i         Inquiry of internal state of test #.                         ",
"   t#<RETURN>  Resume full display for test #.                              ",
"   m           Display last set of messages from all tests.                 ",
"   M           Display fatal error messages from all dead tests.            ",
"   i or I      Inquiry of usex internal state.                              ",
"   s           Save snapshot of usex internal state in a file.              ",
"   k or q      Kill USEX completely.                                        ",
"                                                                            ",
"                          Hit <RETURN> to continue.                         ",
NULL
};

static void
help(void)
{
    register int i;

    /* "Touch" the stdscr and all of its subwindows, */
    /* effectively "saving" its current contents for */
    /* the next refresh() call.                      */

    touchwin(stdscr);  

    if (strcmp(getenv("TERM"), "sun") == 0)
    {
        werase(curscr);     /* Unfortunately, this is terminal-dependent.  */
        wrefresh(curscr);   /* Motorola's System V would core-dump here... */
    }                       /* yet the Sun terminals require these lines.  */

    wclear(Window.Help_Window);      /* Clear and then fill the HELP window. */
    wrefresh(Window.Help_Window);
    for (i = 0; i < MIN_TEST_LINES; i++)
        mvwaddstr(Window.Help_Window, i, 2, 
            (Shm->mode & AT_KLUDGE) ? AT_help_window[i] : help_window[i]);

    wrefresh(Window.Help_Window);     /* Display it. */

    do {
         i = getchar();               /* Force a <RETURN> from the user. */
    } while (i != '\r' && i != '\n');
}
 
/*
 *  New and improved general all-purpose inquiry command.
 */
static void
interactive_inquiry(char *spec, FILE *fp, char type)
{
    register int i;
    PROC_TABLE *tbl;
    char binstats[STRINGSIZE];
    int target;

    if (strlen(spec)) {
	target = atoi(spec);
	test_inquiry(target, fp, TRUE);
	return;
    }

    if (type == FULL_INQUIRY) {
	usex_inquiry(fp);
    }

    for (i = 0; i < Shm->procno; i++) {
        tbl = &Shm->ptbl[i];
        fprintf(fp, "%d: %s", TESTNUM(tbl), TESTNUM(tbl) < 10 ? " " : "");
        if ((tbl->i_stat & (IO_FORK|IO_PIPE)) == (IO_FORK|IO_PIPE)) {
            fprintf(fp, "shell manager: performing fork() operation\r\n");
            continue;
        }
        if ((tbl->i_stat & (IO_FORK|IO_ADMIN1)) == (IO_FORK|IO_ADMIN1)) {
            fprintf(fp, "bin test manager: performing fork() operation\r\n");
            continue;
        }
	if ((tbl->i_stat & IO_FORK) == IO_FORK) {
	    fprintf(fp, "initial fork failed\r\n");	
	    continue;
	}

        if (tbl->i_type == BIN_TEST)
            sprintf(binstats, "bin[%d]", tbl->cmds_found);

        if (tbl->i_blkcnt)
            fprintf(fp, "%d stat %06x pass %ld blks %d file \"%s\" ",
                tbl->i_pid, tbl->i_stat, tbl->i_pass, 
		tbl->i_blkcnt, 
		(tbl->i_type == BIN_TEST) ? binstats : tbl->i_file);
        else 
            fprintf(fp, "%d stat %06x pass %ld file \"%s\" ", tbl->i_pid, 
                tbl->i_stat, tbl->i_pass, 
		(tbl->i_type == BIN_TEST) ? binstats : tbl->i_file);
	
        if (strlen(tbl->i_time_of_death))
            fprintf(fp, "-- died %s\r\n", tbl->i_time_of_death);
        else
	    fprintf(fp, "\r\n");
    }
}
 
void
clear_field(int id, int offset, int length)
{
    char buf[STRINGSIZE];

    if (Shm->mode & AT_KLUDGE) {
        fillbuf(buf, length, '-');
        buf[length] = (char)NULLCHAR;
        mvwaddstr(Window.P[id].action, 0, offset, buf);
        wrefresh(Window.P[id].action);
    }

    fillbuf(buf, length, ' ');
    buf[length] = (char)NULLCHAR;
    mvwaddstr(Window.P[id].action, 0, offset, buf);
    wrefresh(Window.P[id].action);
}


/*
 *  Handle switched Shm->printf(), Shm->perror() and Shm->stderr() calls.
 */
void
curses_printf(char *fmt, ...)
{
        char buf[MAX_PIPELINE_READ];
        va_list ap;

        va_start(ap, fmt);
        (void)vsnprintf(buf, MAX_PIPELINE_READ, fmt, ap);
        va_end(ap);

        if (NO_DISPLAY())
                return;

        fprintf(stdout, buf);
}


void 
curses_perror(char *msg)
{
	if (NO_DISPLAY())
		return;

        perror(msg);
}

void 
curses_stderr(char *fmt, ...)
{
        char buf[MAX_PIPELINE_READ];
        va_list ap;

        va_start(ap, fmt);
        (void)vsnprintf(buf, MAX_PIPELINE_READ, fmt, ap);
        va_end(ap);

	if (NO_DISPLAY())
		return;

	fprintf(stderr, buf);
}


/*
 *  input_mgr:  Responsible for accepting interactive user input while
 *              USEX is underway.  Decodes the input and sends messages
 *              to the appropriate process(es) as required by the command.
 *              The input string is gathered from within curses_mgr() and
 *              sent here upon receipt of a delimiter character.
 */

void
input_mgr(void)
{
    register int i, j;    
    char buffer[STRINGSIZE*2];
    char *usefile;

    /* Normal input should not exceed window area. */

    if (strlen(Shm->input) >= MAX_INPUT)  
    {
        beep();
	USER_PROMPT_END("sorry -- input message is too long!");
        return;
    }

    switch (Shm->input[0])    /* Decompose the message and ship it out to */
    {                         /* the curses_mgr() for immediate action.   */

    /* Shell command. */

    case '!':
	if (streq(Shm->input, "!"))
	    sprintf(Shm->input, "!sh");
        strcpy(Shm->mom, Shm->input);
        wind_intr();
	return;

    /* Inquiry command. */

    case 'i':
    case 'I':
        sprintf(Shm->mom, "%c", FULL_INQUIRY);
        wind_intr();
        break;

    case 'M':
    case 'm':
        sprintf(Shm->mom, "%c%c", LAST_MESSAGE, 
            Shm->input[0] == 'm' ? ALL_MESSAGES : FATAL_MESSAGES);
        wind_intr();
        break;

    case 'F':
	Shm->mode |= SAVE_DEFAULT;
        /* FALLTHROUGH */
    case 'f':
	usefile = (char *)NULL;

        if (Shm->infile && (strcmp(Shm->outfile, Shm->default_file) != 0))
	    usefile = Shm->outfile;
        else if (Shm->infile && (strcmp(Shm->infile, Shm->outfile) != 0))
            usefile = Shm->infile;
        else if (Shm->outfile)
	    usefile = Shm->outfile;
        else if (Shm->infile)
            usefile = Shm->infile;

	if (!usefile) {
		Shm->mode &= ~SAVE_DEFAULT;
		sprintf(buffer, "input file: (none)");
	} else if (Shm->mode & SAVE_DEFAULT)
		sprintf(buffer, "input file: %s (saved)", usefile);
	else
		sprintf(buffer, "input file: %s (enter \"F\" to save)", 
			usefile);
	USER_MESSAGE(buffer);
        return;

    /* Toggle the DEBUG switch. */

    case 'd':
        sprintf(Shm->mom, "%c", DEBUG);
        wind_intr();
        return;

    /* Help command. */
            
    case 'h':
        sprintf(Shm->mom, "%c", HELP);
        wind_intr();
        strcat(Shm->input,"         ");
        break;

    /* Toggle the REFRESH switch. */

    case 'r':
        switch (Shm->input[1])
        {
        case 'k':
            sprintf(Shm->mom, "%c%c", REFRESH, KILL);
            wind_intr();
            break;
        case '\0':
            sprintf(Shm->mom, "%c%c", REFRESH, CONTINUE);
            wind_intr();
            break;
        default:
	    invalid_input();
            break;
        }
        break;

    /* Refresh command via <RETURN>. */

    case '\0':
        sprintf(Shm->mom, "%c", REFRESH);
        wind_intr();                           
        break;

    /* The Big Kill. */

    case 'q':
    case 'k':
        sprintf(Shm->mom, "%c", STOP_USEX);
        wind_intr();                           
        break;

    case 's':
        sprintf(Shm->mom, "%c", DUMP_STATUS_FILE);
        wind_intr();                           
        break;

    /* Load average */

    case 'l':
        switch(Shm->input[1])
        {
	case '\0':
	    sprintf(Shm->mom,"%c%c", LOAD_AVERAGE, CONTINUE);
            wind_intr();
            break;
        case KILL:
            sprintf(Shm->mom,"%c%c", LOAD_AVERAGE, KILL);
            wind_intr();                           
	    break;
	}
	break;

    /* I/O Test commands. */

    case 't':  
        switch (Shm->input[1])
        {
            /* If just "t<RETURN>", "tk", "tb" or "ts" was  */
            /* entered, send the appropriate message to all */
            /* of the I/O tests that are alive.             */

        case '\0':
        case KILL:
	case HOLD:
        case BACKGROUND:
	    if (!Shm->procno) {
		invalid_input();
		return;
	    }

            for (i = 0; i < Shm->procno; i++) {

                if (Shm->ptbl[i].i_stat & IO_DEAD)
                    continue;

                switch (Shm->input[1])
                {
                case '\0':
                    Shm->ptbl[i].i_stat &= 
			~(IO_BKGD|IO_HOLD|IO_HOLD_PENDING|HANG);
                    sprintf(Shm->mom,"%c%c%d", FSTAT, CONTINUE, i); 
                    wind_intr();                           
                    break;

                case KILL:
                    common_kill(KILL_ALL, MAX_IO_TESTS);
		    file_cleanup();
                    break;

                case BACKGROUND:
                    Shm->ptbl[i].i_stat &= ~(IO_HOLD|IO_HOLD_PENDING|HANG);
                    Shm->ptbl[i].i_stat |= IO_BKGD;
                    sprintf(Shm->mom,"%c%c%d", FSTAT, BACKGROUND, i);
                    wind_intr();                           
                    break;

                case HOLD:
                    Shm->ptbl[i].i_stat |= IO_HOLD_PENDING;
                    sprintf(Shm->mom,"%c%c%d", FSTAT, HOLD, i);
                    wind_intr();                           
                    break;

                default:    /* The number entered was OK, */
                            /* but the command was bogus. */
                    invalid_input();
                    break;

                } /* inner switch on Shm->input[1] */
            }  /* for */   
            break;

        default:  
            /* This must be directed to an individual test. */
            /* But first check for a bogus entry/number.    */

            if ((Shm->input[1] < '0' || Shm->input[1] > '9') ||
                (i = abs(atoi(Shm->input + 1))) == 0 || 
		(i > Shm->procno) ||
                ((Shm->ptbl[i-1].i_stat & IO_DEAD) && 
		 (Shm->input[i >= 10 ? 3 : 2] != LAST_MESSAGE) &&  
		 (Shm->input[i >= 10 ? 3 : 2] != INQUIRY) &&
		 (Shm->input[i >= 10 ? 3 : 2] != FULL_INQUIRY)))
                    invalid_input();
            else {
                /* Get command index based on test number. */

                j = (i >= 10) ? 3 : 2;
                --i;

                switch (Shm->input[j])
                {
		case FULL_INQUIRY:
        	    sprintf(Shm->mom, "%c%d", FULL_INQUIRY, i);
        	    wind_intr();
		    break;

                case INQUIRY:
        	    sprintf(Shm->mom, "%c%d", INQUIRY, i);
        	    wind_intr();
		    break;

		case LAST_MESSAGE:
            	    sprintf(Shm->mom,"%c%c", LAST_MESSAGE, POST_IO(i));
                    wind_intr();                           
		    break;  

                case '\0':
                    Shm->ptbl[i].i_stat &= 
			~(IO_BKGD|IO_HOLD|IO_HOLD_PENDING|HANG);
                    sprintf(Shm->mom,"%c%c%d", FSTAT, CONTINUE, i); 
                    wind_intr();                           
                    break;

                case KILL:
                    if (!SPECIAL_FILE(Shm->ptbl[i].i_sbuf.st_mode))
                        delete_file(Shm->ptbl[i].i_file, NOT_USED);    
                    sprintf(Shm->mom,"%c%c%d", FSTAT, KILL, i);
                    wind_intr();                           
                    break;

                case BACKGROUND:
                    Shm->ptbl[i].i_stat &= ~(IO_HOLD|IO_HOLD_PENDING|HANG);
                    Shm->ptbl[i].i_stat |= IO_BKGD;
                    sprintf(Shm->mom,"%c%c%d", FSTAT, BACKGROUND, i);
                    wind_intr();                           
                    break;

		case HOLD:
		    Shm->ptbl[i].i_stat |= IO_HOLD_PENDING;
                    sprintf(Shm->mom,"%c%c%d", FSTAT, HOLD, i);
                    wind_intr();                           
                    break;

                default:    /* The number entered was OK, */
                            /* but the command was bogus. */

                    invalid_input();
                    break;

                } /* inner switch on Shm->input[j] */
            } /* else */
            break; /* break from default */
        } /* switch on Shm->input[1] */

        break; /* break from case 't' */

    case 'u':
        sprintf(Shm->mom, "%c", UNAME_INFO);
        wind_intr();                           
        break;

    case 'b':
        sprintf(Shm->mom, "%c", BUILD_INFO);
        wind_intr();                           
	break;

    case 'T':
	if (strlen(Shm->ext_terminal)) {
		sprintf(buffer, "%s", Shm->ext_terminal);
		strcat(buffer, " -e /usr/bin/top &");
		system(buffer);
	} else if (file_exists("/usr/X11R6/bin/xterm") && file_exists("/usr/bin/top"))
        	system("/usr/X11R6/bin/xterm -font fixed -e /usr/bin/top &");
        else
                system("xterm -font fixed -e /usr/bin/top &");
        break;

    default:  
        invalid_input();
        break;

    }  /* big switch */
}

static void
invalid_input(void)
{
	char buf[STRINGSIZE*2];

	beep();
	sprintf(buf, "invalid input: %s", Shm->input);
        buf[MAX_INPUT-1] = NULLCHAR;
        USER_MESSAGE(buf);
}

/*
 *  Actually called a number of times, this routine sets up curses, clears
 *  the screen, and then ends curses mode.
 */
void
curses_clear_screen(void)
{
        initscr();      /* Clear the display screen. */
        if (stdscr == NULL) {
            Shm->stderr("usex: curses initscr() failed to initialize stdscr\n");
            quick_die(QDIE(20));
        }
        clear();
        refresh();
        endwin();
}

/*
 *  Shut down curses -- called by die() via window_manager_shutdown_notify().
 */
void
curses_shutdown(void)
{
        wclear(stdscr);
        move(Shm->lines_used-1, 0);
        reset_shell_mode();
        endwin();
}

/*
 *  Handle any --win arguments.
 */
void curses_specific(char *args)
{
        int i, argc;
        char *p1, *argv[MAX_ARGV];
        char argbuf[STRINGSIZE];

        if (strstr(args, ",")) {
                strcpy(argbuf, args);
                while ((p1 = strstr(argbuf, ",")))
                        *p1 = ' ';
                argc = parse(argbuf, argv);
        } else {
                argc = 1;
                argv[0] = args;
        }

        for (i = 0; i < argc; i++) {
                if (streq(argv[i], "your arg here")) {
                        ;
                }
        }
}
