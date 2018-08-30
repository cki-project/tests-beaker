/*  Author: David Anderson <anderson@redhat.com> */

#include "defs.h"

/*
 *  transfer_mgr:  Performs the transfer rate test, reading user-defined 
 *                 block sizes.  The average, last, high, and low values 
 *                 are calculated each pass; the average is shown on the
 *                 test's display line.
 *
 *  BitKeeper ID: @(#)xfer_mgr.c 1.3
 *
 *  CVS: $Revision: 1.6 $ $Date: 2016/02/10 19:25:53 $
 */

void
rate_test(void)
{
	int fd = -1;
	ulong bytes, show_percent;
	size_t sz;
	ssize_t bytes_read;
    	double total_time = 0;       /* Total time to date.                */
    	double total_bytes = 0;      /* Total bytes transferred to date.   */
	time_t elapsed, now, start, end;
        PROC_TABLE *tbl = &Shm->ptbl[ID];

    	tbl->r_mean = tbl->r_last = tbl->r_high = 0;
    	tbl->r_low = 10000000000.0;

        if (CURSES_DISPLAY() && (strlen(tbl->i_file) > 23))
        	sprintf(tbl->r_display, 
			"<%s", &tbl->i_file[strlen(tbl->i_file) - 22]);
    	else 
        	sprintf(tbl->r_display, tbl->i_file);
    	io_send(FILENAME, (long)tbl->r_display, NOARG, NOARG);

	io_send(FSTAT, tbl->i_stat & IO_BKGD ? _BKGD_ : _OK_, NOARG, NOARG);

        io_send(FOPEN_, NOARG, NOARG, NOARG);   /* Display "Open" message. */

	if (tbl->i_stat & RATE_CREATE) {
		char zero_buf[8192];

		if (SPECIAL_FILE(tbl->i_sbuf.st_mode)) 
                	bail_out(fd, OPEN_ERROR, errno);  

		bzero(zero_buf, 8192);

	        if (file_exists(tbl->i_file)) {
                	errno = EEXIST;     
                	bail_out(fd, OPEN_ERROR, errno);  
            	} 

            	if ((fd = open(tbl->i_file, O_RDWR|O_CREAT|O_EXCL, 0777)) < 0)
                   	bail_out(fd, OPEN_ERROR, errno);

		switch (file_nlinks(tbl->i_file))
            	{          
            	case 1:
                	break;

            	case 0:
                	errno = ENOENT;
                	bail_out(fd, OPEN_ERROR, errno);

            	default:
                	errno = EMLINK;
                	bail_out(fd, OPEN_ERROR, errno);
            	}

		tbl->r_file_ptr = 0;
		tbl->i_fsize = tbl->i_limit * 1024;
		tbl->r_last_percent = 110;
        	tbl->r_count = tbl->i_fsize/8192;
		tbl->r_cur = 0;
		tbl->r_percent = 0;

		tbl->i_stat |= RATE_WRITE;
		while (tbl->r_file_ptr < tbl->i_fsize) {
			SEND_HEARTBEAT(ID);
			sz = ulmin((tbl->i_fsize - tbl->r_file_ptr), 8192UL);
			if (write(fd, zero_buf, sz) != sz)
                		bail_out(fd, OPEN_ERROR, errno);
			tbl->r_file_ptr = lseek(fd, 0L, FROM_CURRENT_POS);
			tbl->r_cur++;
                        tbl->r_percent = (tbl->r_cur*100)/tbl->r_count;
                        if (tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING)) 
				put_test_on_hold(tbl, ID);
		}
		tbl->i_stat &= ~RATE_WRITE;
		io_send(FCLEAR, NOARG, NOARG, NOARG);
	} else {
		if ((fd = open(tbl->i_file, O_RDONLY)) < 0)
                   	bail_out(fd, OPEN_ERROR, errno);
		if (tbl->i_limit)
			tbl->i_fsize = tbl->i_limit * 1024;
	}

        tbl->rfd = fd;

	tbl->i_stat |= IO_START;

        if (tbl->i_fsize) {
        	tbl->r_count = tbl->i_fsize/tbl->i_size;
        	show_percent = tbl->r_count;
    	} else {
        	tbl->r_count = ~0;
        	show_percent = 0;
		tbl->i_stat |= RATE_TBD;
    	}
	tbl->r_percent = 0;
    	tbl->r_last_percent = 110;

    	time(&now);
    	tbl->r_timestamp = now;
	tbl->i_stat |= RATE_START;

    	for (tbl->i_pass = 1; keep_alive(); tbl->i_pass++) 
    	{
        	if (mother_is_dead(Shm->mompid, "r1"))    /* Mom's dead. */
            		fatal(ID, "mother is dead", 0);

		io_send(FPASS, tbl->i_pass, NOARG, NOARG);

        	lseek(fd, 0L, 0);  /* Set file pointer to 0. */
        	time(&start);      /* Start the timer. */
		elapsed = 0;

        	for (tbl->r_cur = bytes = 0; tbl->r_cur < tbl->r_count; 
		     tbl->r_cur++) {

			SEND_HEARTBEAT(ID);

			if (tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING)) {
                		time(&end);                   
                		elapsed += end - start;       
				put_test_on_hold(tbl, ID);
        			time(&start);      
			}

                	if (show_percent) {
                        	tbl->r_percent = (tbl->r_cur*100)/show_percent;
                	} else if (bytes == 0) {
                        	sprintf(tbl->r_display, "read[TBD]");
                        	io_send(FOPERATION, (long)tbl->r_display,
					NOARG, NOARG);
                	}

            		if ((bytes_read = 
			    read(fd, tbl->i_read_buf, tbl->i_size)) == 
			    IO_ERROR || (bytes_read != tbl->i_size)) {

                		/* If the read operation failed, inform the */
				/* user of the system errno and suspend the */
			        /* test.  Otherwise we've reached EOF.   */

                		if (bytes_read == IO_ERROR) 
					bail_out(fd, READ_ERROR, errno);
                		
                	/* If the end of the partition was reached, use what */
                	/* we were able to read -- it's better than failing. */

                		tbl->r_count = tbl->r_cur;
                		show_percent = tbl->r_count;
				tbl->i_stat &= ~RATE_TBD;
                		break;
            		}

			tbl->r_file_ptr = lseek(fd, 0L, FROM_CURRENT_POS);
		     /* io_send(FPOINTER, tbl->r_file_ptr, NOARG, NOARG); */

            		bytes += bytes_read;
		}

        	time(&end);                   /* Stop the timer.          */
        	elapsed += end - start;       /* Figure the elapsed time. */

        	if (elapsed == 0) {
			tbl->i_stat |= RATE_NOTIME;
			io_send(FOPERATION, (long)"<NO TIME>", NOARG, NOARG);
            		paralyze(ID,
                            "no measurable time during complete read cycle", 0);
        	}

        	total_time += (double)elapsed;       
        	total_bytes += (double)bytes;       

        	/* Compute the overall mean in kbytes/sec. */

        	if ((tbl->r_mean = (total_bytes / total_time) / 1024.0) <= 0) {
            	       /* If the mean drops below zero, then an overflow has 
			* occurred.  Set total_time and total_bytes to equal 
			* the time and byte values recorded on the last pass,
		        * and re-start from there.                           
			*/
            		total_time = (double) elapsed;         
            		total_bytes = (double) bytes;      
			tbl->i_stat |= RATE_OVFLOW;
        	}

        	/* Write the average out to the display */

        	sprintf(tbl->r_display, "Rate %ld kb/s", (ulong)tbl->r_mean);
		mkstring(tbl->r_display, 16, LJUST);
                io_send(MANDATORY_FMODE, (long)tbl->r_display, 
			NOARG, NOARG);

                /* Stash the last, low and high rates if applicable. */
 
                tbl->r_last = (double)((bytes / elapsed) / 1024.0);

        	if (tbl->r_last < tbl->r_low)        
            		tbl->r_low = tbl->r_last;
        	if (tbl->r_last > tbl->r_high)
            		tbl->r_high = tbl->r_last;
	}	
}


void
rate_test_inquiry(int target, FILE *fp)
{
        PROC_TABLE *tbl = &Shm->ptbl[target];

        fprintf(fp, "\nRATE TEST SPECIFIC:\n");
	fprintf(fp, "rfd: %d  r_file_ptr: %ld r_percent: %d\n", tbl->rfd, 
		tbl->r_file_ptr, tbl->r_percent);
	fprintf(fp, "r_last_percent: %d r_cur/r_count: %ld/%ld\n", 
		tbl->r_last_percent, tbl->r_cur, tbl->r_count);
	fprintf(fp, "r_mean: %d r_last: %d r_high: %d r_low: %d\n",
		(int)tbl->r_mean, (int)tbl->r_last, (int)tbl->r_high, 
		tbl->r_low == 10000000000.0 ? 0: (int)tbl->r_low);
        fprintf(fp, "r_timestamp: %s", tbl->r_timestamp ?
                ctime(&tbl->r_timestamp) : "(unused)\n");
}


int 
canned_rate(int id, char *buffer)
{
        PROC_TABLE *tbl = &Shm->ptbl[id];

	if (tbl->i_stat & RATE_WRITE) {
        	if (tbl->r_percent < 100 && 
		    tbl->r_last_percent != tbl->r_percent) {
                	sprintf(buffer, "%c%cwrite%s[%2d%%]", MANDATORY_CANNED,
                        	tbl->i_local_pid, 
				CURSES_DISPLAY() ? "" : " ",
				tbl->r_percent);
                	tbl->r_last_percent = tbl->r_percent;
                	time(&tbl->i_canned_msg_time);
                	return TRUE;
        	}
		return FALSE;
	}

	if (!(tbl->i_stat & RATE_START) || 
	    (tbl->i_stat & (RATE_TBD|RATE_NOTIME)))
		return FALSE;

	if (tbl->r_last_percent != tbl->r_percent) {
        	sprintf(buffer, "%c%cread%s[%2d%%]", MANDATORY_CANNED, 
			tbl->i_local_pid, 
			CURSES_DISPLAY() ? "" : " ",
			tbl->r_percent);
		tbl->r_last_percent = tbl->r_percent;
	        time(&tbl->i_canned_msg_time);
		return TRUE;
	}

	return FALSE;

}
