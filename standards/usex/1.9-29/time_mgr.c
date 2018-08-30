/*  Author: David Anderson <anderson@redhat.com> 
 *
 *  BitKeeper ID: @(#)time_mgr.c 1.2
 *
 *  CVS: $Revision: 1.5 $ $Date: 2016/02/10 19:25:52 $
 */
 
#include "defs.h"

int
check_timer(struct timer_request *treq)
{
	static time_t usex_last_time = 0;
	time_t cur_time;

        time(&cur_time);                  /* Do something every second. */
	if (cur_time == usex_last_time)
		return(FALSE);
	else
		usex_last_time = cur_time;

	sys_date(treq->sys_date);
        sys_time(treq->sys_time);         
	run_time(treq->run_time, &treq->requests);

	return(TRUE);
}

/*
 *  run_time:  Gets the current time and subtracts it from the
 *             startup time, does some conversions, and places the run time
 *             in the buffer that is passed to it.  The startup time is 
 *             initialized on the first call to this routine, and its value 
 *             is saved in the variable "initial_time".
 *
 *             Requests for stopping usex, refreshing the screen and
 *             checking the load average are returned in the requests
 *             argument at the proper times.
 */

void
run_time(char *buffer, ulong *requests)
{
    register int i;
    time_t sav_time, cur_time;    /* Gets current time with each call.       */
    ulong hours, mins, secs;      /* Calculation variables.                  */
    struct timer_callback *tc;
    static time_t initial_time = 0; 

    time(&cur_time);            /* Obtain the current time. */

    if (!initial_time)          
        initial_time = cur_time; 

    cur_time -= initial_time; /* Determint time elapsed since startup and now.*/
    sav_time = cur_time;    /* Save value in seconds before mucking around. */

    hours = cur_time/(60*60);     /* Perform the arithmetic to obtain the  */
    cur_time %= (60*60);          /* hours, minutes and seconds.           */
    mins = cur_time/60;         
    secs = cur_time%60;

    /* Prepare the buffer for the window manager. */

    sprintf(buffer, "%.3ld:%.2ld:%.2ld", hours, mins, secs);

    /* Set up the request bitmap, if any */

    if (!requests)
	return;

    *requests &= TIMER_REQ_FAILED;
    /*
     * Refresh the screen on the minute. 
     */
    if (streq(&buffer[7], "00")) {
	if (!streq(buffer, "000:00:00"))
		*requests |= TIMER_REQ_REFRESH;
        if (Shm->logfile) {
            char logbuf[STRINGSIZE];
	    char timebuf[STRINGSIZE];
	    char datebuf[STRINGSIZE];

	    sys_time(timebuf);
	    sys_date(datebuf);
            sprintf(logbuf, "-- %s@%s -- %s --\n", datebuf, timebuf, buffer);
            LOG(NOARG, LOG_MESSAGE, NOARG, logbuf);
        }
    }

    /*
     * If something is not done every second, key in on the second number.
     */
    switch (buffer[8])
    {
    case '0':
	break;
    case '1':
	break;
    case '2':
	break;
    case '3':
	break;
    case '4':
	break;
    case '5':
	break;
    case '6':
	break;
    case '7':
	break;
    case '8':
	break;
    case '9':
	break;
    }

    *requests |= TIMER_REQ_LOAD_AVG | TIMER_REQ_FREE_MEM;
    *requests |= TIMER_REQ_CPU_STATS;   /* show cpu stats each second */

   /*
    * If kill_time is non-zero and the current elapsed time
    * is greater than kill_time, forget any of the above or below 
    * and signal the window manager to stop immediately.
    */
    if (Shm->time_to_kill && (sav_time >= Shm->time_to_kill)) {
        *requests = TIMER_REQ_STOP_USEX;
	return;
    }

   /*
    * Check for any other timer requests.
    */
   for (i = 0; i < TIMER_CALLBACKS; i++) {
	tc = &Shm->timer_request.callbacks[i];
        if (tc->time) {
	    tc->time--;
	    if (tc->time == 0) 
    		*requests |= TIMER_REQ_CALLBACK;
	}
   }

   /*
    *  Help out in debug message control.
    */
    if (Shm->debug_message_inuse > 0) 
	Shm->debug_message_inuse--;
    else if (Shm->debug_message_inuse < 0) 
        Shm->debug_message_inuse = 0;
}

/*
 *  set_timer_request:  Call a function some number of seconds later.
 *                      This can only be called by the window manager.
 */
void
set_timer_request(uint when, void *func, ulong arg1, ulong arg2)
{
    register int i;
    struct timer_callback *tc;

    if (!WINDOW_MGR())
	return;

    for (i = 0; i < TIMER_CALLBACKS; i++) {
	tc = &Shm->timer_request.callbacks[i];
        if (!tc->active) {
            tc->func = func;
	    tc->seq = Shm->timer_request.sequence++;
            tc->arg1 = arg1;
            tc->arg2 = arg2;
	    tc->time = when;
	    tc->active = TRUE;
	    return;
        }
    }

    Shm->timer_request.requests |= TIMER_REQ_FAILED;

    return;
}

/*
 *  timer_req_callback:  Kick off all routines schedule to go now, in the
 *                       order in which they were queued.
 */                       
void
timer_req_callback(struct timer_request *treq)
{
    register int i;
    struct timer_callback *tc;
    int index[TIMER_CALLBACKS];
    int cnt;

    if (treq->requests & TIMER_REQ_FAILED) {
	USER_MESSAGE("timer callback failed!");
        treq->requests &= ~TIMER_REQ_FAILED;
    }

    bzero(index, sizeof(int)*TIMER_CALLBACKS);

    for (i = cnt = 0; i < TIMER_CALLBACKS; i++) {
       	tc = &treq->callbacks[i];
        if (tc->active && !tc->time) 
	    index[cnt++] = i;
    }

    if (cnt > 1) 
	qsort(&index[0], cnt, sizeof(int), compare_ints);

    for (i = 0; i < cnt; i++) {
        tc = &treq->callbacks[index[i]];
        tc->func(tc->arg1, tc->arg2);
        tc->active = FALSE;
    }
}

/*
 *  elapsed_time:  Figure out time elapsed between start and stop.
 */

void
elapsed_time(time_t start, time_t stop, char *buffer)
{
    time_t elapsed;               /* Time between start and stop. */
    ulong hours, mins, secs;      /* Calculation variables.       */

    elapsed = stop - start;

    hours = elapsed/(60*60);     /* Perform the arithmetic to obtain the  */
    elapsed %= (60*60);          /* hours, minutes and seconds.           */
    mins = elapsed/60;
    secs = elapsed%60;

    sprintf(buffer, "%.3ld:%.2ld:%.2ld", hours, mins, secs);
}

/*
 *  sys_date:  Makes time() and ctime() UNIX system calls, extracts 
 *             the date from the return values, and places it in a buffer
 *             in a prescribed format.  The ctime() returns a pointer to a 
 *             26-character string of the in the following format:
 *
 *                 Sun Sep 16 01:03:52 1985\n\0  
 *                                                                          
 *             It is converted by this routine into the following format:     
 *                                                                           
 *                 16Sep85\0              
 */
void
sys_date(char *buffer)
{
    register int i;          
    time_t my_time;           /* Receives time from time() call.       */
    char *ascii_time;         /* Receives pointer to time/date string. */

    time(&my_time);                    /* Get the time.                  */
    ascii_time = ctime(&my_time);      /* Convert it to an ascii string. */

    /* Fill in the buffer with a string the window manager understands. */

    for (i = 0; i < 2; ++i)            /* Place day of month into the buffer. */
        buffer[i] = ascii_time[i+8];
    if (buffer[1] == ' ')              /* Replace any spaces in the "day" */
        buffer[1] = '0';               /* spot with a "0".                */

    for (i = 2; i < 5; ++i)            /* Place the month into the buffer. */
        buffer[i] = ascii_time[i + 2];

    for (i = 5; i < 7; ++i)            /* Place the year into the buffer. */
        buffer[i] = ascii_time[i + 17];

    buffer[i] = (char)NULLCHAR;        /* Make a string out of it. */
}

/*
 *  sys_time:  Makes time() and ctime() UNIX calls, extracts 
 *             the time from the return values, and places it in a buffer 
 *             in a prescribed format.  The ctime() call returns a pointer 
 *             to a 26-character string of the following format:  
 *
 *                Sun Sep 16 01:03:52 1985\n\0                             
 */
void
sys_time(char *buffer)  /* Buffer to stuff the ASCII-ized time in. */
{
    register int i;   
    time_t my_time;          /* Receives time from time() call.       */
    char *ascii_time;        /* Receives pointer to time/date string. */

    time((time_t *)&my_time);              /* Get the time.           */
    ascii_time = ctime(&my_time);          /* Convert it to a string. */

    for (i = 0; i < 8; ++i)               
        buffer[i] = ascii_time[i + 11];   
    buffer[i] = (char)NULLCHAR;
}

