/*  Author: David Anderson <anderson@redhat.com> */

#include "defs.h"

/*
 *  io_test:  This program is forked by usex.  It performs a continuous 
 *            read/write/compare cycle on a regular file or raw device file, or
 *            calls one of the built-in commands.  If an I/O test is run, it 
 *            first places in a buffer called i_write_buf a pattern encomposing
 *            all bit patterns in a byte, until i_write_buf is full. The size of
 *            the buffer is passed as a parameter.  Then it either opens a file
 *            in the directory requested by the user, or opens the raw device 
 *            requested by the user -- and writes the i_write_buf buffer out to 
 *            the file.  It seeks back, reads the same data into another array
 *            called i_read_buf, and compares what it read to what it wrote.
 *            It repeats this pattern of writing, seeking back, and reading 
 *            until either the disk is full, or the user-imposed block limit
 *            is reached.  At that point it starts to truncate, read, and 
 *            compare until it reaches the beginning of the file.  (It doesn't
 *            actually "truncate" the file in the true sense of the word, 
 *            because the bytes read still belong to the file.)  The file is 
 *            then closed (and deleted if it is a regular file).            
 *
 *            Throughout its lifetime, its current operation, file pointer
 *            value, pass number and status are updated on the display screen
 *            via calls to io_send(), which in turn creates messages to send to
 *            the window manager. 
 *                                                                           
 *            This routine is repeated forever until the process is killed
 *            by the user, a "compare" operation shows an error, or a 
 *            read or write error occurs.  If so, the test will be marked
 *            "DEAD" in the STAT column, and an error message posted on the
 *            appropriate test line.  If a compare error occurs, a file 
 *            indicating the position of the error, the byte read, the byte 
 *            expected, and the byte re-read from the file, is created in the 
 *            directory from which usex was invoked.
 *                                                                           
 *            The test can be interrupted by the user in order to kill the
 *            process or put it in the background (in which case only the pass 
 *            number is updated. 
 *
 *  BitKeeper ID: @(#)io_test.c 1.3
 *
 *  CVS: $Revision: 1.4 $ $Date: 2016/02/10 19:25:52 $
 */


static void io_error(int);
static void bus_error(void);                
static void fillpattern(PROC_TABLE *);

#define MAX_READ_RETRIES (3)

void
io_test (int id)
{
    register PROC_TABLE *tbl;        /* Pointer to process table.   */
    int fd;                          /* I/O test file descriptor.   */
    size_t bytes_written;            /* Bytes written at a time.    */ 
    size_t bytes_read;               /* Bytes read at a time. */
    long writes;                     /* Writes so far in one pass.  */
    int error_offset;		     /* Offset of error in compare  */
    int retries;
    ulong file_pointer;
    time_t now;
    int fd_sanity;
    char workbuf[STRINGSIZE];

    ID = id;
    tbl = &Shm->ptbl[ID];
    time(&now);
    tbl->i_timestamp = now;
    tbl->i_pid = getpid();
    tbl->i_post = 0;
    tbl->i_saved_errno = 0;
    tbl->i_fsize = 0;
    tbl->i_stat |= IO_START;
    sigset(SIGINT, SIG_IGN);

    if (tbl->i_stat & IO_BKGD) 
        io_send(FSTAT, _BKGD_, NOARG, NOARG);

    if (tbl->i_message == FILE_EXISTS) {
        io_send(FERROR, FILE_EXISTS, NOARG, NOARG);
	tbl->i_demise = BY_DEATH;
        fatal(ID, "test file already exists!", 0);
    } 

    sigset(SIGBUS, bus_error);

    switch (tbl->i_type)
    {
    case WHET_TEST:
    case DEBUG_TEST:
    case VMEM_TEST:
        break;

    default:           /* Allocate the read and write buffers in one shot. */
		       /* The start of the buffer is 512-byte aligned.     */

	io_send (FMALLOC, NOARG, NOARG, NOARG);
	if ((tbl->i_read_buf = malloc((tbl->i_size*2)+512)) == NULL)
	{
	        /* The system cannot handle tbl->i_size'd buffers. */
	        /* Send an error message and go into baio out. */
	
	        io_send(FERROR, ALLOC_ERROR, NOARG, NOARG);
		tbl->i_demise = BY_DEATH;
	        fatal(ID, "malloc", errno);
	 }
	 tbl->i_read_buf = (char *)roundup((ulong)tbl->i_read_buf, 512);
	
	/*
	 * Clear i_read_buf. Fill i_write_buf with an incrementing pattern. 
	 */
	 tbl->i_write_buf = &tbl->i_read_buf[tbl->i_size];
	 bzero(tbl->i_read_buf, tbl->i_size);
	 fillpattern(tbl);
	 break;
    }

    switch (tbl->i_type)
    {
    /* Branch off if this is a special case test. */

        case WHET_TEST:
            float_test();
            break;

        case DHRY_TEST:
            dry();
            break;

        case VMEM_TEST:
            vmem();
            break;

	case DEBUG_TEST:
	    debug_test();
	    break;

	case RATE_TEST:
	    rate_test();
	    break;
    }

    if (CURSES_DISPLAY() && (strlen(tbl->i_file) > 23)) 
        sprintf(workbuf, "<%s", &tbl->i_file[strlen(tbl->i_file) - 22]);
    else 
	sprintf(workbuf, tbl->i_file);
    io_send(FILENAME, (long)workbuf, NOARG, NOARG);

    /* Re-define block_limit to equal the number of user-defined buffers that */
    /* can contain the test file.  If we're going to the end of the disk,     */
    /* then forget about it and just leave block_limit equalling END_OF_DISK. */

    tbl->block_limit = (long long)tbl->i_limit;       
    if (tbl->block_limit != END_OF_DISK)
    {
        /* Limit test file length to "block_limit" number of blocks. */

        tbl->block_limit = (long long)
		(tbl->block_limit * 1024 / (int)tbl->i_size);   

        if (tbl->block_limit < 1)
        {
            /* Buffer size is larger than the user-imposed limit. */
            /* Send an error message and bail out.      */

            io_send(FERROR, BIG_BUFFER, NOARG, NOARG);  
	    set_time_of_death(ID);
	    tbl->i_demise = BY_DEATH;
	    fatal(ID, "buffer size larger than user-imposed limit", 0);
        }
    }

    /* Until death, do forever... */

    fd_sanity = 0;

    for (tbl->i_pass = 1; keep_alive(); tbl->i_pass++) 
    {
	if (mother_is_dead(Shm->mompid, "i1")) {   /* Mom's dead. */
	    fatal(ID, "mother is dead", 0);
        }

        io_send(FOPEN_, NOARG, NOARG, NOARG);   /* Display "Open" message. */

        if (SPECIAL_FILE(tbl->i_sbuf.st_mode))  /* Either open the raw device */
            fd = open(tbl->i_file, O_RDWR|O_SYNC); /* or create regular file. */
        else {
	    if (file_exists(tbl->i_file)) {
		errno = EEXIST;                    /* Check for existence    */
                bail_out(fd, OPEN_ERROR, errno);   /* each time to avoid NFS */
	    }				           /* collisions.            */

            if ((fd = open(tbl->i_file, 
		O_RDWR|O_SYNC|O_CREAT|O_EXCL, 0777)) < 0) {
                    bail_out(fd, OPEN_ERROR, errno);   
	    }

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
	}

	tbl->iofd = fd;

        if (fd == IO_ERROR)                   /* If the "open" bombed, send a */
            bail_out(fd, OPEN_ERROR, errno);  /* message and bail out. */

        if (!SPECIAL_FILE(tbl->i_sbuf.st_mode))
            chmod(tbl->i_file, 0777);

	if (tbl->i_pass > 1) {
	    if (fd != fd_sanity) 
                bail_out(NOARG, FD_SANITY, 0);
        }

        io_send(FSTAT, _OK_, NOARG, NOARG);     /* Update PASS and STAT. */     
        io_send(FPASS, tbl->i_pass, tbl->i_saved_errno, tbl->i_fsize);
	tbl->i_saved_errno = 0;

        /* The "Fill" loop. */

	io_send(FFILL, NOARG, NOARG, NOARG);

        for (tbl->i_stat |= IO_FILL, writes = bytes_written = 0;;)   
        {

	    if (tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING)) 
		put_test_on_hold(tbl, ID);

            /* Send a write message and write a buffer. */

            sprintf(tbl->display, "Fill  %s  write....", 
		adjust_size(FILE_PTR(fd), 9, workbuf, 1));
            io_send(FMODE, (long)tbl->display, NOARG, NOARG);  

            if ((bytes_written = write(fd, tbl->i_write_buf, 
	        (size_t)tbl->i_size)) == IO_ERROR) {
                if (errno == ENOSPC || errno == EFBIG || 
		    errno == ENXIO || errno == ENOMEM)
                {
                    /* End of File System was reached either   */
                    /* purposely OR inadvertantly.  Update the */
                    /* STAT column and continue on.            */

		    tbl->i_saved_errno = errno;
                    io_send(FSTAT, SPECIAL_FILE(tbl->i_sbuf.st_mode) ? 
			EOP : EOFS, NOARG, NOARG); 
                }
                else
                {
                    /* The write operation failed. Send write error */
                    /* message, close the file, and go into a coma. */

                    bail_out(fd, WRITE_ERROR, errno);
                }
            }

	    if (!tbl->i_saved_errno && (tbl->i_stat & IO_FSYNC))
		fsync(fd);
    
            /* Send a "Seek" message and then seek back the correct amount... */

            io_send(FSEEK, NOARG, NOARG, NOARG); 
            if (bytes_written != IO_ERROR)
                lseek(fd, -((off_t)bytes_written), FROM_CURRENT_POS);   
            else
                break;     /* Proceed directly to the Truncate loop. */

            /* Send "Read" message and read the buffer... */

            sprintf(tbl->display, "Fill  %s  read.....", 
		adjust_size(FILE_PTR(fd), 9, workbuf, 1));
            io_send(FMODE, (long)tbl->display, NOARG, NOARG);  

            bzero(tbl->i_read_buf, tbl->i_size);
	    bytes_read = 0;
	    file_pointer = FILE_PTR(fd);
	    retries = 0;

	    while (bytes_read != bytes_written) {
                if ((bytes_read = 
	            read(fd, tbl->i_read_buf, bytes_written)) == IO_ERROR) {
                   /* 
		    *  The read operation failed. Send read error   
                    *  message, close the file, and go into a coma. 
		    */
                    bail_out(fd, READ_ERROR, errno);
                }               

	        if (bytes_read != bytes_written) {

                    sprintf(workbuf,
                        " DISK TEST %d: ENOMEM: read CYCLE: Fill ATTEMPT: %d\n",
			    ID+1, retries+1);
                    io_send(LOG_MESSAGE, (long)workbuf, NOARG, NOARG);

                    if (retries == MAX_READ_RETRIES) 
                        bail_out(fd, READ_ERROR, errno = ENOMEM);

		    lseek(fd, file_pointer, FROM_BEGINNING);
                    sprintf(tbl->display, "Fill [ENOMEM] read retry %d", 
			++retries);
                    io_send(MANDATORY_FMODE, (long)tbl->display, NOARG, NOARG);
		    io_send(MANDATORY_FSTAT|IO_SYNC, (ulong)"<WARN>", 
			NOARG, NOARG); 

		    sleep(retries);

                    sprintf(tbl->display, "Fill                      ");
            	    io_send(MANDATORY_FMODE, (long)tbl->display, NOARG, NOARG);
		    io_send(FSTAT, tbl->i_stat & IO_BKGD ? _BKGD_ : _OK_, 
			NOARG, NOARG);
		}
	    }

            io_send(FPOINTER, FILE_PTR(fd), NOARG, NOARG); /* Update pointer. */

            /* A "real" disk compare is done only if this is a raw device. */
            /* UNIX will pass back cached buffers if it's a regular file.  */

            if ((error_offset = compare(bytes_written, fd)) != COMPARE_OK)
            {                                         /* Bail out on error. */
                    close(fd);
                    io_error((int)((writes * tbl->i_size) + error_offset));
            }

            /* Was it a full tbl->i_size'd buffer that was written last? */

            if (bytes_written == tbl->i_size) 
            {                                /* Yes it was... */
                writes++;

                /* If we've reached the user-imposed     */
                /* limit, bail out and start truncating. */

                if ((tbl->block_limit != END_OF_DISK) &&  
                    (writes == (long)tbl->block_limit)) {
                    io_send(FPOINTER, FILE_PTR(fd), NOARG, NOARG);
                    break;
                }
            }
            else  /* No, so we've run out of disk space. */
            {
                /* Seek back to the last full "tbl->i_size" buffer, */
                /* update the pointer, and break out.             */

                lseek(fd, -((off_t)bytes_written), FROM_CURRENT_POS);    
                io_send(FPOINTER, FILE_PTR(fd), NOARG, NOARG);  
                io_send(FSTAT, SPECIAL_FILE(tbl->i_sbuf.st_mode) ? EOP : EOFS,
			NOARG, NOARG); 
		tbl->i_saved_errno = INCOMPLETE_WRITE;
                break;
            }

        }    /* End of "Fill" loop. */

	tbl->i_stat &= ~IO_FILL;

        /* Start the Truncate loop. */
    
	tbl->i_fsize = file_size(fd);
        io_send(FTRUN, 0, NOARG, NOARG); 

        for (tbl->i_stat |= IO_TRUN; writes > 0;)
        {
            /* Send "Seek" message and seek back a buffer... */

            io_send(FSEEK, NOARG, NOARG, NOARG);    
            lseek(fd, (int)(-tbl->i_size), FROM_CURRENT_POS); 

            if (tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING)) 
	   	put_test_on_hold(tbl, ID); 

            /* Send "Read" message and read a buffer... */
 
            sprintf(tbl->display, "Trun  %s  read.....", 
		adjust_size(FILE_PTR(fd), 9, workbuf, 1));
            io_send(FMODE, (long)tbl->display, NOARG, NOARG);  

            bzero(tbl->i_read_buf, tbl->i_size);
            bytes_read = 0;
            io_send(FPOINTER, file_pointer = FILE_PTR(fd), NOARG, NOARG); 
            retries = 0;

            while (bytes_read != tbl->i_size) {
                if ((bytes_read =
                    read(fd, tbl->i_read_buf, tbl->i_size)) == IO_ERROR) {
                   /*
                    *  The read operation failed. Send read error
                    *  message, close the file, and go into a coma.
                    */
                    bail_out(fd, READ_ERROR, errno);
                }

                if (bytes_read != tbl->i_size) {

                    sprintf(workbuf, 
                        " DISK TEST %d: ENOMEM: read CYCLE: Trun ATTEMPT: %d\n",
			    ID+1, retries+1);
                    io_send(LOG_MESSAGE, (long)workbuf, NOARG, NOARG);

		    if (retries == MAX_READ_RETRIES)
			bail_out(fd, READ_ERROR, errno = ENOMEM);

                    lseek(fd, file_pointer, FROM_BEGINNING);
                    sprintf(tbl->display, "Trun [ENOMEM] read retry %d", 
			++retries);
                    io_send(MANDATORY_FMODE, (long)tbl->display, NOARG, NOARG);
                    io_send(MANDATORY_FSTAT|IO_SYNC, (ulong)"<WARN>",
                        NOARG, NOARG);

                    sleep(retries);

                    sprintf(tbl->display, "Trun                      ");
                    io_send(MANDATORY_FMODE, (long)tbl->display, NOARG, NOARG);
                    io_send(FSTAT, tbl->i_stat & IO_BKGD ? _BKGD_ : _OK_,
                        NOARG, NOARG);
                }
            }

            /* Send "Compare" message, and then compare */
            /* the i_write_buf to the i_read_buf.       */

            io_send(FCOMPARE, NOARG, NOARG, NOARG);  
            if ((error_offset = compare(tbl->i_size, fd)) != COMPARE_OK)
            {                                    /* Bail out on error. */
                    close(fd);
                    io_error((int)((--writes * tbl->i_size) + error_offset));
            }

            if (--writes > 0)      /* If there's still more of the file left, */
            {                         /* send a "Seek" message and seek back. */
		if (!(tbl->i_stat & IO_NOTRUNC)) {
        	    io_send(FTRUN, 1, NOARG, NOARG); 
		    ftruncate(fd, FILE_PTR(fd));
		}
                io_send(FSEEK, NOARG, NOARG, NOARG);    
                lseek(fd, (int)(-tbl->i_size), FROM_CURRENT_POS);
            }
        }  /* End of "Truncate" loop */

	tbl->i_stat &= ~IO_TRUN;

        /* Update pointer and send "Close" message. */

        io_send(FPOINTER, 0L, NOARG, NOARG);
        io_send(FCLOSE, NOARG, NOARG, NOARG);

        close(fd);                         /* Close the file. */

        if (fd == IO_ERROR)                /* If the "close" bombed, send a   */
            bail_out(fd, CLOSE_ERROR, errno);  /* message and bail out. */

	fd_sanity = fd; 	           /* Same fd should be re-assigned. */
    
        if (!SPECIAL_FILE(tbl->i_sbuf.st_mode))  /* Send "Delete" message and */
        {                                      /* delete the regular file.  */
            io_send(FDELETE, NOARG, NOARG, NOARG);   
            delete_file(tbl->i_file, ID);          
        }
    }     /* The big "for" loop. */
}         

/*
 *  io_error: Indicates a disk I/O compare error by displaying something like:
 *      
 *               COMPARE ERROR: See ux12345_01.err for details
 * 
 *            on the appropriate test file line, and printing "DEAD" under   
 *            the STAT field of the test.  Then it opens a file in the  
 *            current directory of the form shown above, in which the 
 *            particulars of the comparison error are placed.  
 */

static void
io_error(int count)
{
    register int i, j, k;
    register PROC_TABLE *tbl;        /* Pointer to process table.   */
    FILE *fp1;                  /* Error and test file pointers. */
    char err_ptr_buf[MESSAGE_SIZE*2];
    int found;

    /* Create and open an error file. */

    tbl = &Shm->ptbl[ID];
    fp1 = fopen(tbl->i_errfile, "w");

    fprintf(fp1, "The first compare error was found at:\n\n");
    fprintf(fp1, "    file pointer position: 0x%08x (%d) of \"%s\"\n", count,
        count, tbl->i_file);
    fprintf(fp1, "              buffer size: 0x%lx (%ld)\n", (ulong)tbl->i_size,
	(ulong)tbl->i_size);
    fprintf(fp1, "       read buffer offset: 0x%08lx (%ld)\n", tbl->buffer_offset,
	tbl->buffer_offset);
    fprintf(fp1, "                byte read: 0x%02x (%u)\n", tbl->byte_read,
	tbl->byte_read);
    fprintf(fp1, "             byte written: 0x%02x (%u)\n", tbl->byte_written,
	tbl->byte_written);
    fprintf(fp1, "               test cycle: %s\n",
        tbl->i_stat & IO_FILL ? "fill" : "truncate");
    fprintf(fp1, "                     time: %s\n\n", 
        tbl->i_time_of_death); 

    for (i = found = 0; i < tbl->i_size; i++) {
        if (tbl->i_read_buf[i] != tbl->i_write_buf[i]) 
	    found++;
    }

    if (found) {
        fprintf(fp1, 
"A total of %d errors were found in the %ld-byte read buffer below.\n",
    found, (ulong)tbl->i_size);
        fprintf(fp1, 
"They are indicated with ^^ marks under the mis-comparing bytes:\n");
    }
    else {
        fprintf(fp1,
"However, no errors were found during a subsequent scan of the read buffer:\n");
    }

    /* Print out the entire read buffer at the bottom of the error file.  */

    fprintf(fp1, "\n");
    for (i = j = 0; i < tbl->i_size; i++)
    {
        if (i == 0) {
            fprintf(fp1, "  %06x:", i);

            found = 0;
            sprintf(err_ptr_buf, "  %06x:", i);
            for (k = 0; err_ptr_buf[k]; k++)
                err_ptr_buf[k] = ' ';
        }

        fprintf(fp1, " %s%x", tbl->i_read_buf[i] & 0xf0 ? "" : "0",
            tbl->i_read_buf[i] & 0xff);
        if (tbl->i_read_buf[i] != tbl->i_write_buf[i]) {
            found++;
            strcat(err_ptr_buf, " ^^");
        }
        else
            strcat(err_ptr_buf, "   ");

        if (++j == 16)
        {
            if (found) 
                fprintf(fp1, "\n%s", err_ptr_buf);

            j = 0;
            fprintf(fp1, "\n  %06x:", i+1);

            found = 0;
            sprintf(err_ptr_buf, "  %06x:", i+1);
            for (k = 0; err_ptr_buf[k]; k++)
                err_ptr_buf[k] = ' ';
        }
    }
    if (found) 
        fprintf(fp1, "\n%s", err_ptr_buf);
    fprintf(fp1, "\n");

    /* Clean up act. */

    fsync(fileno(fp1));
    fclose(fp1);

    /* Inform user of error via display screen. */

    io_send(COMPARE_ERR, (long)tbl->i_errfile, NOARG, NOARG);
    sprintf(err_ptr_buf, "compare error: see %s for details", tbl->i_errfile);
    paralyze(ID, err_ptr_buf, 0);
}

/*
 *  io_send:  Deciphers the flag and then places a formatted
 *            data string onto the window manager queue.                        
 */
void
io_send(ulong arg0, long arg1, long arg2, long arg3)
{
    register PROC_TABLE *tbl;        /* Pointer to process table.   */
    char buffer[STRINGSIZE*2];  
    uchar flag;

    tbl = &Shm->ptbl[ID];
    SEND_HEARTBEAT(ID);

    flag = (uchar)(arg0 & 0xff);     

    switch (flag)
    {
        case FCOMPARE:         /* Depending upon the flag sent, fill the */
        case FREAD_:            /* buffer with an appropriate string.     */
        case FWRITE_:
        case FOPEN_:
        case FCLOSE:
        case FDELETE:
        case FIOCTL:
        case FSLEEP:
        case FWAIT:
        case FMALLOC:
        case FSBRK: 
            if (tbl->i_stat & IO_BKGD) 
                goto done_sending;
        case FCLEAR:
        case FFILL:
            sprintf(buffer, "%c%c", flag, tbl->i_local_pid); 
            break;

	case MANDATORY_FSTAT:
            sprintf(buffer, "%c%c%s", flag, tbl->i_local_pid, (char *)arg1); 
            break;

        case FTRUN: 
            if ((tbl->i_stat & IO_BKGD) && arg1)
                goto done_sending;
            sprintf(buffer, "%c%c%d", flag, tbl->i_local_pid, (int)arg1);
            break;

        case FSEEK:
            goto done_sending;   /* Excess baggage... */

	case FOPERATION:
	    if (!(tbl->i_type & (RATE_TEST|WHET_TEST|VMEM_TEST)))
                if (tbl->i_stat & IO_BKGD)
                    goto done_sending;
            sprintf(buffer, "%c%c%s", flag, tbl->i_local_pid, (char *)arg1);
            break;

        case FPOINTER:
            if (tbl->i_stat & IO_BKGD) 
                goto done_sending;
            sprintf(buffer, "%c%c%9ld", flag, tbl->i_local_pid, arg1);
            break;

        case FPASS:
            if (tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING)) 
		put_test_on_hold(tbl, ID);
	    
	    if (arg2 && !arg3)
            	sprintf(buffer, "%c%c%4d:%d", flag, tbl->i_local_pid, 
		    (int)arg1, (int)arg2);
	    else if (arg3)
            	sprintf(buffer, "%c%c%4d:%d:%lu", flag, tbl->i_local_pid, 
		    (int)arg1, (int)arg2, (ulong)arg3);
	    else
            	sprintf(buffer, "%c%c%4d", flag, tbl->i_local_pid, (int)arg1);
            break;

        case FMODE: 
	    if (tbl->i_stat & IO_BKGD)
		goto done_sending;
        case MANDATORY_FMODE:
            sprintf(buffer, "%c%c%s", flag, tbl->i_local_pid, (char *)arg1);
            break;

        case FSIZE:
        case FILENAME:
            sprintf(buffer, "%c%c%s", flag, tbl->i_local_pid, (char *)arg1);
            break;

        case FSTAT:
            if (arg1 == DEAD)
                sprintf(buffer, "%c%c DEAD ", flag, tbl->i_local_pid);
            else if (arg1 == _OK_)
                sprintf(buffer, "%c%c  OK  ", flag, tbl->i_local_pid);
            else if (arg1 == EOFS)
                sprintf(buffer, "%c%c EOFS ", flag, tbl->i_local_pid);
            else if (arg1 == _BKGD_)
                sprintf(buffer, "%c%c BKGD ", flag, tbl->i_local_pid);
            else if (arg1 == EOP)
                sprintf(buffer, "%c%c EOP  ", flag, tbl->i_local_pid);
            else if (arg1 == WARN)
                sprintf(buffer, "%c%c<WARN>", flag, tbl->i_local_pid);
            break;

        case FERROR:
            switch (arg1)
            {
            case FILE_EXISTS:
                sprintf(buffer, "%c%cFATAL ERROR: %s already exists ",
                    flag, tbl->i_local_pid, tbl->i_file);
                break;
            case FD_SANITY:
                sprintf(buffer, "%c%cFILE DESCRIPTOR OUT OF SYNC ", flag, 
                tbl->i_local_pid);
		break;
            case BIG_BUFFER:
                sprintf(buffer, "%c%cBUFFER SIZE > LIMIT ", flag, 
                tbl->i_local_pid);
                break;
            case OPEN_ERROR:
                sprintf(buffer, "%c%copen: %s", flag, 
                    tbl->i_local_pid, strerror(errno));
                break;
            case ALLOC_ERROR:
                sprintf(buffer, "%c%cmalloc: %s", flag, 
                    tbl->i_local_pid, strerror(errno));
                break;
            case WRITE_ERROR:
                sprintf(buffer, "%c%cwrite: %s", flag, 
                    tbl->i_local_pid, strerror(errno));
                break;
            case READ_ERROR:
                sprintf(buffer, "%c%cread: %s", flag, 
                    tbl->i_local_pid, strerror(errno));
                break;
            case IOCTL_ERROR:
                sprintf(buffer, "%c%cioctl: %s", flag, 
                    tbl->i_local_pid, strerror(errno));
                break;
            case CLOSE_ERROR:
                sprintf(buffer, "%c%cclose: %s", flag, 
                    tbl->i_local_pid, strerror(errno));
                break;
            case BUS_ERROR:
                sprintf(buffer, "%c%cBUS ERROR", flag, tbl->i_local_pid);
                break;
           /*
            *  Warning: we are assuming that arg is a pointer here since
            *           it is not one of the low-numbered error codes.
            */
            default:
                sprintf(buffer, "%c%c%s", flag, tbl->i_local_pid, (char *)arg1);
                break;
            }
            break;

	case LOG_MESSAGE:
	    if (tbl->i_stat & IO_NOLOG)
		return;
            sprintf(buffer, "%c%c%s", flag, tbl->i_local_pid, (char *)arg1);
            break;

        case COMPARE_ERR:
            sprintf(buffer,"%c%c%s COMPARE ERROR: ", COMPARE_ERR, 
                tbl->i_local_pid, tbl->i_stat & IO_FILL ? "Fill" : "Trun");
            sprintf(&buffer[21]," See %s for details.    ", (char *)arg1);
            break;
 
        case CANNED:
            sprintf(buffer, "%c%c%d", flag, tbl->i_local_pid, (int)arg1);
            break;

	case KEEP_ALIVE:
            sprintf(buffer, "%c%c", flag, tbl->i_local_pid);
            break;

        case STOP_USEX:
            sprintf(buffer, "%c", flag);
            break;

	default:
	    return;
    } 

    /* Stash the time and message into the message storage queue */
	
    bzero(tbl->i_last_message[tbl->i_post], STRINGSIZE);
    time(&tbl->i_last_msgtime[tbl->i_post]);  
    strncpy(tbl->i_last_message[tbl->i_post], buffer, 
	min(strlen(buffer), STRINGSIZE-1));
    tbl->i_post = (tbl->i_post+1) % I_POSTAGE;

    /* Put the buffer onto the message queue. */

    tbl->i_stat |= SENDING;

    switch (Shm->mode & IPC_MODE)
    {
    case PIPE_MODE:
        pipe_write(Shm->win_pipe[ID_TO_PIPE], buffer, strlen(buffer)+1);
	break;

    case MESGQ_MODE:
        strcpy(tbl->i_msgq.string, buffer);
        if (msgsnd(tbl->i_msg_id, (struct msgbuf *)&tbl->i_msgq, 
	    MESSAGE_SIZE, 0) == -1 && (errno != EINTR)) {
            fatal(ID, "io_test: msgsnd", errno); 
        }
	break;

    case MMAP_MODE:
    case SHMEM_MODE:
        shm_write(RING_IO(ID), buffer, strlen(buffer)+1);
	break;
    }

    tbl->i_stat &= ~SENDING;

done_sending:

    if (arg0 & IO_SYNC)
	synchronize(ID, NULL);
}

/*
 *  bail_out:  Generic bail out routine.
 */
void
bail_out(int fd, int error, int errnum)
{
    register PROC_TABLE *tbl;        /* Pointer to process table.   */
    char buf[STRINGSIZE];

    tbl = &Shm->ptbl[ID];

    /* A read, write, open, close or ioctl operation failed. */
    /* Send a message, close the file, and go into a coma.   */

    if (error != OPEN_ERROR)
        close(fd);

    switch (error) 
    {
    case OPEN_ERROR:
        sprintf(buf, "open(%s)", tbl->i_file); 
	break;
    case FD_SANITY:
	sprintf(buf, "file descriptor overflow!");
	break;
    case WRITE_ERROR:
        sprintf(buf, "write"); 
	break;
    case READ_ERROR:
        sprintf(buf, "read"); 
	break;
    case CLOSE_ERROR:
        sprintf(buf, "close"); 
	break;
    }

    io_send(FERROR, error, NOARG, NOARG);
    tbl->i_demise = BY_DEATH;
    fatal(ID, buf, errnum);
} 

/*
 * compare:  Generic buffer compare routine.
 */

int
compare(long arg, int fd)
{
    register long i; 
    size_t count;
    register PROC_TABLE *tbl;        /* Pointer to process table.   */

    tbl = &Shm->ptbl[ID];
    if (tbl->i_type == DISK_TEST)
        count = arg;
    else
        count = tbl->i_size;

    io_send(FCOMPARE, NOARG, NOARG, NOARG);
    for (i = 0; i < count; i++) {
        if ((tbl->byte_read = tbl->i_read_buf[i]) != 
            (tbl->byte_written = tbl->i_write_buf[i])) {
	    set_time_of_death(ID);
            if (tbl->i_type == DISK_TEST)   /* Disk tests want offset. */
                return(tbl->buffer_offset = i);
            else
                close(arg);
            io_error(0);
        }
    }

    return(COMPARE_OK);
}

void 
bus_error(void)
{
    register PROC_TABLE *tbl;        /* Pointer to process table.   */

    tbl = &Shm->ptbl[ID];

    io_send(FERROR, BUS_ERROR, NOARG, NOARG);
    tbl->i_demise = BY_DEATH;
    fatal(ID, "bus error signal", 0);
}

/*
 *  The pattern file can consist of a list of 32-bit words expressed
 *  as hexadecimal ASCII expressions, such as deadbeef, a5a5a5a5, 0, etc.
 *
 *  If the pattern filename specified does not exist, and the pattern file
 *  name entered is "ID", then the buffer is filled with the same character,
 *  that being the test ID.
 */
static void
fillpattern(PROC_TABLE *tbl)
{
    register int i, j, k, m, s;
    FILE *fp;
    int save_errno;
    unsigned int wc;
    unsigned int words[MAX_PATTERN_WORDS];  
    char input[STRINGSIZE];

    if (Shm->pattern) {
	if ((fp = fopen(Shm->pattern, "r")) == NULL) {
            save_errno = errno;
            if (streq(Shm->pattern, "ID"))
		goto id_pattern;
            else
                fatal(ID, Shm->pattern, save_errno);
        }

 	wc = 0;
        while (fgets(input, STRINGSIZE, fp) != NULL) {
	    words[wc++] = atoh(input);
	    if (wc == MAX_PATTERN_WORDS)
		break;
	}
	fclose(fp);

        for (i = j = k = 0; k < tbl->i_size; i++) {
            for (m = 0, s = 24; m < 4; m++, s -= 8)
            	tbl->i_write_buf[k++] = (unsigned char)(words[j] >> s);

            if (++j == wc)
		j = 0;
        }

        return;
    }
    
    for (i = 0, j = ID+1; i < tbl->i_size; i++, j++)
        tbl->i_write_buf[i] = (unsigned char)j;
    return;

id_pattern:
    for (i = 0; i < tbl->i_size; i++)
        tbl->i_write_buf[i] = (unsigned char)ID+1;
    return;
  
}


void
disk_test_inquiry(int target, FILE *fp)
{
	register int i, j, k, m, s;
        PROC_TABLE *tbl = &Shm->ptbl[target];
	char input[STRINGSIZE];
	FILE *pfp;
	uchar pattern[MAX_CHAR_PATTERNS]; 
        unsigned int wc;
    	unsigned int words[MAX_PATTERN_WORDS];  

        fprintf(fp, "\nDISK TEST SPECIFIC:\n");
	fprintf(fp, "iofd: %d file_ptr: %ld display: \"%s\"\n", tbl->iofd,
		tbl->file_ptr, tbl->display);
	fprintf(fp, "block_limit: ");
	if (!tbl->block_limit)
		fprintf(fp, "END_OF_DISK ");
	else
		fprintf(fp, "%lld ", tbl->block_limit);
        fprintf(fp, "byte_read: %02x byte_written: %02x buffer_offset: %ld\n",
		tbl->byte_read, tbl->byte_written, tbl->buffer_offset);

	/*
	 *  The write buffer is malloc'd by each test individually, so is
	 *  not accessible by the window manager.  So recreate it...
	 */
	bzero(pattern, MAX_CHAR_PATTERNS);

	fprintf(fp, "test file pattern:");

	if (streq(Shm->pattern, "ID")) {
    		for (i = 0; i < MAX_CHAR_PATTERNS; i++)
        		pattern[i] = (unsigned char)(target+1);

	} else if (Shm->pattern) {
            	if ((pfp = fopen(Shm->pattern, "r")) == NULL) {
			Shm->perror(Shm->pattern);
			return;
		}

        	wc = 0;
		bzero(pattern, MAX_CHAR_PATTERNS);
        	while (fgets(input, STRINGSIZE, pfp) != NULL) {
            		words[wc++] = atoh(input);
            		if (wc == MAX_PATTERN_WORDS)
                		break;
        	}
		fclose(pfp);

        	for (i = j = k = 0; k < MAX_CHAR_PATTERNS; i++) {
            		for (m = 0, s = 24; m < 4; m++, s -= 8)
                		pattern[k++] = (unsigned char)(words[j] >> s);

            		if (++j == wc)
                		j = 0;
        	}

        } else {
    		for (i = 0, j = target+1; i < MAX_CHAR_PATTERNS; i++, j++)
        		pattern[i] = (unsigned char)j;
	}

        for (i = 0; i < MAX_CHAR_PATTERNS; i++) {
                if (i == tbl->i_size) 
                        break;
                if ((i == 0) || ((i%32) == 0))
                        fprintf(fp, "\n  ");
                fprintf(fp, "%02x", pattern[i]);
        }

        fprintf(fp, "\n");
}
