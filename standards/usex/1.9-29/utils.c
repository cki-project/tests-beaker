/*  Author: David Anderson <anderson@redhat.com>
 *
 *  BitKeeper ID: @(#)utils.c 1.6
 *
 *  CVS: $Revision: 1.9 $ $Date: 2016/02/10 19:25:53 $
 */

#include "defs.h"

static int tty_fd = 0;
static int leftover_removal = 0;

#define MAX_LEFTOVERS 200
static char *leftovers[MAX_LEFTOVERS] = { 0 };

static jmp_buf bogus_console;

static void time_out(uint);
static void end_timer(void);  
static int same_file(char *, char *);
static int is_char_device(char *);
static int is_block_device(char *);
static uid_t owner_id(char *);
static void delete_contents(char *, int);
static int matches_pid(char *, int);
static int not_running(char *, int);
static int matches(char *, char *);
static int link_leftover(char *);
static int show_leftovers(int);
static int rm_leftovers(void);
static int not_in_list(char *);
static int file_readable(char *);


#define ENTER_BACKWARDS 1
#define MAX_SPINS 100

static int shmcpy(char *, volatile int *, int, char *, int, int, uint *);



/*
 *  Strip the linefeed off the end of a string.
 */

char *
strip_lf(char *s)
{
	if (s[strlen(s)-1] == '\n')
	    s[strlen(s)-1] = (char)NULLCHAR;
	return(s);
}

char *
strip_ending_spaces(char *s)
{
	char *p;

	if (strlen(s) == 0)
	    return(s);

	p = &s[strlen(s)-1];
	while (p >= s) {
	    if (*p == ' ')
		*p = (char)NULLCHAR;
	    else 
		break;
	    p--;
	}

	return(s);
}

char * 
strip_ending_chars(char *s, char c)
{
        char *p;

        if (strlen(s) == 0)
            return(s);

        p = &s[strlen(s)-1];
        while (p >= s) {
            if (*p == c)
                *p = (char)NULLCHAR;
	    else
		break;
            p--;
        }
        return(s);
}

char *
strip_beginning_chars(char *line, char c)
{
        char buf[STRINGSIZE*2];
        char *p;

        if (line == NULL || strlen(line) == 0)
                return(line);

        strcpy(buf, line);
        p = &buf[0];
        while (*p == c)
                p++;
        strcpy(line, p);

        return(line);
}

char *
strip_beginning_whitespace(char *line)
{
        char buf[STRINGSIZE*2];
        char *p;

        if (line == NULL || strlen(line) == 0)
                return(line);

        strcpy(buf, line);
        p = &buf[0];
        while (*p == ' ' || *p == '\t')
                p++;
        strcpy(line, p);

        return(line);
}

char *
shift_string_left(char *input, int cnt, char *buf)
{
	char *s;
        int origlen;

	if (buf) {
		strcpy(buf, input);
		s = buf;
	} else
		s = input;

        if (!cnt)
                return(s);

        origlen = strlen(s);
        memmove(s, s+cnt, (origlen-cnt));
        *(s+(origlen-cnt)) = NULLCHAR;
        return(s);
}

char *
shift_string_right(char *input, int cnt, char *buf)
{
        register int i;
	char *s;
        int origlen;

        if (buf) {
                strcpy(buf, input);
                s = buf;
        } else
                s = input;

        if (!cnt)
                return(s);

        origlen = strlen(s);
        memmove(s+cnt, s, origlen);
        *(s+(origlen+cnt)) = NULLCHAR;

        for (i = 0; i < cnt; i++)
                s[i] = ' ';

        return(s);
}

char *
mkstring(char *s, int size, ulong flags)
{
	register int i;
	int len;
	int extra;
	int left;
	int right;
	char buf[STRINGSIZE];

	len = strlen(s);
	if (size <= len) { 
		if (flags & TRUNC) 
			s[size] = NULLCHAR;
		return(s);
	}	
	extra = size - len;

	if (flags & CENTER) {
		/*
		 *  If absolute centering is not possible, justify the
		 *  string as requested -- or to the left if no justify
		 *  argument was passed in.
		 */
		if (extra % 2) {
			switch (flags & (LJUST|RJUST))
			{
			default:
			case LJUST:
				right = (extra/2) + 1;
				left = extra/2;
				break;
			case RJUST:
				right = extra/2;
				left = (extra/2) + 1;
				break;
			}
		}
		else 
			left = right = extra/2;
	
		bzero(buf, STRINGSIZE);
		for (i = 0; i < left; i++)
			strcat(buf, " ");
		strcat(buf, s);
		for (i = 0; i < right; i++)
			strcat(buf, " ");
	
		strcpy(s, buf);
		return(s);
	}

	if (flags & LJUST) {
		for (i = 0; i < extra; i++)
			strcat(s, " ");
	}

	if (flags & RJUST) {
		shift_string_right(s, extra, NULL);
	}

	return(s);
}

void
space_pad(char *s, int n)
{
	while (strlen(s) < n)
		strcat(s, " ");

}

void
char_pad(char *s, char *c, int n)
{
        while (strlen(s) < n)
                strcat(s, c);
}

int
keep_alive(void)
{
	return(TRUE);
}

/*
 *  filename:  Returns the "base" of a full pathname.
 */
char *
filename(char *path)
{
    char *ptr = path;

    while (*ptr != '\0')    /* Find the end of the path. */      
        ptr++;             
    while (*ptr != '/' && ptr != path)   
        ptr--;

    return(ptr == path ? ptr : (ptr+1)); 
}

char *
dec_node(char *s1, char *s2)
{
    char *p1, *p2;

    p1 = s1;
    p2 = s2;

    while (*p1 && (*p1 != '.'))
        *p2++ = *p1++;
    *p2 = (char)NULLCHAR;

    return(s2);
}


/*
 *  pipe_read:  Reads from the specified pipe until reaching a NULL character.
 */
int
pipe_read(int pipe, char *buffer)
{
    register int count = 0; /* Character counter. */
    char c;                 /* Character holder.  */

    while (1)
    {
        switch (read(pipe, &c, 1))
        {
            case -1:            /* The read failed, or... */
            case  0:            /* the pipe was empty.    */
                return(0);

            default:            /* Keep reading characters until a NULL. */
                *buffer++ = c;
                if (c == (char)NULLCHAR)
                    return(count);
                count++;
        }
    }
}

/*
 *  pipe_write:  Writes a buffer to a specified pipe.   
 */
int
pipe_write(int pipe, char *buffer, int count)
{
    if (count == write(pipe, buffer, count))
        return(0);
    return(-1);
}

/*
 *  time_out:  Sets up a watchdog timer, and then puts itself to
 *             sleep until the timer expires.  
 */
static void
time_out(uint seconds)            /* Seconds to time out. */
{

    sigset(SIGALRM, end_timer);   /* Tell system to call end_timer() */
                                  /* when the alarm goes off.        */

    alarm(seconds);               /* Set the alarm.              */
    pause();                      /* Wait for the alarm to ring. */
}

/*
 *  end_timer:  This function does nothing.  It works flawlessly.
 */
static void 
end_timer(void)
{ }

/*
 *  Stall for a number of microseconds.
 */
void
stall(ulong microseconds)
{
    	struct timeval delay;
    
	delay.tv_sec = 0;
	delay.tv_usec = (__time_t)microseconds;

	(void) select(0, (fd_set *) 0, (fd_set *) 0, (fd_set *) 0, &delay);
}


/*
 *  Put the current time in date@time format.
 */
char *
format_time_string(char *buf, char *input)
{
    	int argc ATTRIBUTE_UNUSED;
	char locbuf[STRINGSIZE];
    	char *argv[MAX_ARGV];

	strcpy(locbuf, input);
    	argc = parse(locbuf, argv);
	sprintf(buf, input);
	sprintf(buf, "%s%s%s@%s",
		argv[2], argv[1], &argv[4][2], argv[3]);

        return buf;
}


/*
 *  what_is:  Returns the type of file, when passed the name of the 
 *            file and a pointer to a stat buffer.
 */
int
what_is(char *filename, struct stat *sbp)
{
    if (!filename || !strlen(filename))
        return(-1);

    if (stat(filename, sbp) == -1)  
        return(-1);                         /* This file doesn't exist. */
    else
        return(sbp->st_mode & S_IFMT);      /* Return the file type. */
}

/*
 *  Used when the stat buf is not important.
 */
int
file_exists(char *filename)
{
    struct stat sbuf;

    if (!filename || !strlen(filename))
        return(FALSE);

    if (stat(filename, &sbuf) == -1 && lstat(filename, &sbuf) == -1)
        return(FALSE);                         /* This file doesn't exist. */
    else
        return(TRUE);
}

/*
 *  Determine whether a file exists, and if so, if it's readable.
 */
static int
file_readable(char *file)
{
        long tmp;
        int fd;

        if (!file_exists(file))
                return FALSE;

        if ((fd = open(file, O_RDONLY)) < 0)
                return FALSE;

        if (read(fd, &tmp, sizeof(tmp)) != sizeof(tmp)) {
                close(fd);
                return FALSE;
        }
        close(fd);

        return TRUE;
}

/*
 *  Return the number of links to a file.
 */
nlink_t
file_nlinks(char *filename)
{
    struct stat sbuf;

    if (stat(filename, &sbuf) == -1 && lstat(filename, &sbuf) == -1)
        return(0);                      /* This file doesn't exist. */
    else
        return(sbuf.st_nlink);
}

/*
 *  Copy a file to another file or directory.
 */
int
file_copy(char *source, char *dest)
{
	char buf[MESSAGE_SIZE*2];

	sprintf(buf, "/bin/cp %s %s", source, dest);
	return(!system(buf));
}


/*
 *  Used on currently-open real files.
 */
ulong
file_size(int fd)
{
    struct stat sbuf;

    if (fstat(fd, &sbuf) == -1)
	return 0;

    return(sbuf.st_size);
}

/*
 *   Compares two real files.
 */
static int
same_file(char *f1, char *f2)
{
	struct stat sbuf1, sbuf2;

        if (!f1 || !strlen(f1) || !f2 || !strlen(f2))
            return(FALSE);

        if (stat(f1, &sbuf1) == -1)
        	return(FALSE);         
        if (stat(f2, &sbuf2) == -1)
        	return(FALSE);         

	if ((sbuf1.st_dev == sbuf2.st_dev) &&
	    (sbuf1.st_ino == sbuf2.st_ino))
		return(TRUE);

	return(FALSE);
}

/*
 *  Used when it needs to be a directory.
 */
int
is_directory(char *filename)
{
    struct stat sbuf;

    if (!filename || !strlen(filename))
	return(FALSE);

    if (stat(filename, &sbuf) == -1) 
        return(FALSE);                         /* This file doesn't exist. */

    return((sbuf.st_mode & S_IFMT) == S_IFDIR ? TRUE : FALSE);
}

/*
 *  Used when it needs to be a character device.
 */
static int
is_char_device(char *filename)
{
    struct stat sbuf;

    if (!filename || !strlen(filename))
        return(FALSE);

    if (stat(filename, &sbuf) == -1)
        return(FALSE);                         /* This file doesn't exist. */

    return((sbuf.st_mode & S_IFMT) == S_IFCHR ? TRUE : FALSE);
}

static int
is_block_device(char *filename)
{
    struct stat sbuf;

    if (!filename || !strlen(filename))
        return(FALSE);

    if (stat(filename, &sbuf) == -1)
        return(FALSE);                         /* This file doesn't exist. */

    return((sbuf.st_mode & S_IFMT) == S_IFBLK ? TRUE : FALSE);
}

uid_t
owner_id(char *filename)
{
    struct stat sbuf;

    if (!filename || !strlen(filename))
        return(-1);

    if (stat(filename, &sbuf) == -1)
        return(-1);                         /* This file doesn't exist. */

    return(sbuf.st_uid);
}


/*
 *  Generic buffer cleaner/filler.
 */

void
fillbuf(char *buf, int count, char val)
{
    while (count--)
        *buf++ = val;
}

int
atoh(char *s)
{
    int i, j, n;

    for (n = i = 0; s[i] != 0; i++) {
        switch (s[i]) 
        {
            case 'a':
            case 'b':
            case 'c':
            case 'd':
            case 'e':
            case 'f':
                j = (s[i] - 'a') + 10;
                break;
            case 'A':
            case 'B':
            case 'C':
            case 'D':
            case 'E':
            case 'F':
                j = (s[i] - 'A') + 10;
                break;
            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
            case '0':
                j = s[i] - '0';
                break;
            default:
                continue;
        }
        n = (16 * n) + j;
    }
    return(n);
}

/*
 *  file_cleanup()
 *
 *     Gets rid of any file created by any of the 12 I/O tests, of whatever
 *     form they might be.  Disk I/O files are saved if they are raw devices
 *     or have an error file associated with them.
 */
void
file_cleanup(void)
{
    register int i;
    
    for (i = 0; i < Shm->procno; i++) {
        if ((Shm->ptbl[i].i_type == DISK_TEST) &&
            !(file_exists(Shm->ptbl[i].i_errfile)) &&
            !SPECIAL_FILE(Shm->ptbl[i].i_sbuf.st_mode))
            delete_file(Shm->ptbl[i].i_file, NOT_USED);
        if (Shm->ptbl[i].i_type == BIN_TEST)
	    bin_cleanup(i, EXTERNAL);
    }
    if (strlen(Shm->ux_IO))
        delete_file(Shm->ux_IO, NOT_USED);

    if (file_exists(Shm->id_file))
    	delete_file(Shm->id_file, NOT_USED); 
}

/*
 *  Get rid of this file or else...
 */
int
delete_file(char *filename, int originator)
{
    int retry = 0;

    /* paranoia due to SVR4-EPC compiler /usr/bin wipeout -- reason TBD... */

    if (leftover_removal) { 
        char input[MESSAGE_SIZE];

	if (is_directory(filename)) {
	    char input[MESSAGE_SIZE];
            int retval;

            if (matches(filename, "/tmp/ux######_##")) {
                leftover_removal = FALSE;
                retval = delete_file(filename, NOT_USED);
                leftover_removal = TRUE;
                if (retval == FALSE)
                    Shm->directories_found++;
                return(retval);
	    }

            if (matches(filename, "/tmp/ux######_tmp")) {
                leftover_removal = FALSE;
                retval = delete_file(filename, NOT_USED);
                leftover_removal = TRUE;
                if (retval == FALSE)
                    Shm->directories_found++;
                return(retval);
            }


	    Shm->stderr("WARNING: %s is a directory: ", filename);
            Shm->stderr("remove %s?: ", filename);
            read(tty_fd, input, MESSAGE_SIZE);
            if (input[0] == 'y') {
                leftover_removal = FALSE;
		retval = delete_file(filename, NOT_USED);
                leftover_removal = TRUE;
		if (retval == FALSE)
	            Shm->directories_found++;
                return(retval);
            }

	    Shm->directories_found++;
	    return(FALSE);
        }
        else if (not_in_list(filename)) {
            Shm->stderr("WARNING: delete_file: %s: not in list!\n",
                filename);
	    return(FALSE);
	}
	if (Shm->mode & DEBUG_MODE) {
            Shm->stderr("DEBUG: Do you want to remove %s?: ", filename);
            read(tty_fd, input, MESSAGE_SIZE);
            if (input[0] != 'y') 
                return(FALSE);
	}
    }

    if (is_char_device(filename)) {
        Shm->stderr("WARNING: delete_file received char device: %s\n",
            filename);
        return(FALSE);
    }
    if (is_block_device(filename)) {
        Shm->stderr("WARNING: delete_file received block device: %s\n",
            filename);
        return(FALSE);
    }

    while (file_exists(filename)) {
        if (is_directory(filename)) {
            if (rmdir(filename)) {
		delete_contents(filename, originator);
		if (rmdir(filename)) {
		    if (errno == EPERM) {
                    	Shm->stderr(
                            "%s has owner id %d: access permission denied\n",
                                filename, owner_id(filename));
			return FALSE;
		    }
		}
		continue;
            }
        }
        else 
            unlink(filename);

        if (file_exists(filename)) {
	    if (owner_id(filename) != getuid()) {
		if (leftover_removal) {
		    Shm->stderr(
			"%s has owner id %d: access permission denied\n",
			    filename, owner_id(filename));
		    return(FALSE);
		}
	    }
            Shm->stderr("%s: cannot delete\r\n", filename);
            if (++retry == 10) {
		char buf[MESSAGE_SIZE];
		sprintf(buf, "%s: cannot delete", filename);
		if (leftover_removal) {
		    Shm->stderr("giving up on %s\n", filename);
		    return(FALSE);
		}
		else
		    fatal(originator, buf, 0);
	    }
            Shm->stderr("\rretrying...\r\n");
        }
    }
    return(TRUE);
}

#define MAXMATCH (10)

int
delete_matching_files(char *filebase, int originator)
{
    register int i;
    int cnt, found;
    DIR *dirp;
    struct dirent *dp;
    char matches[MAXMATCH][STRINGSIZE];

    cnt = 0;

match_again:
    found = 0;
    dirp = opendir(Shm->tmpdir);
    if (!dirp)
	return cnt;

    for (dp = readdir(dirp); dp != (struct dirent *)NULL; dp = readdir(dirp)) {
	    if (strstr(dp->d_name, filebase)) {
		strcpy(matches[found++], dp->d_name);
		if (found == MAXMATCH)
		    break;
	    }
    }
    closedir(dirp);

    for (i = 0; i < found; i++) 
	delete_file(matches[i], originator);

    cnt += found;

    if (found == MAXMATCH)
	goto match_again;

    return cnt;
}

/*
 *   parse()
 *         Point successive argv pointers to the strings in cmd,
 *	   and the pass back the argument count.
 */
int
parse(char *cmd, char *argv[])
{
    register int i, j;

    i = j = 0;

    argv[j++] = cmd;

    while (1) {
        while (cmd[i] != ' ' && cmd[i] != '\t' && cmd[i] != (char)NULLCHAR && 
            cmd[i] != '\n') {
            i++;
        }

        switch(cmd[i])
        {
        case ' ':
        case '\t':
            cmd[i++] = (char)NULLCHAR;
            while (cmd[i] == ' ' || cmd[i] == '\t') {
                i++;
            }

            if (cmd[i] != (char)NULLCHAR && cmd[i] != '\n') {
                argv[j++] = &cmd[i];
                break;
            }
                        /* else fall through */
        case '\n':
            cmd[i] = (char)NULLCHAR;
                        /* keep falling... */
        case '\0':
            argv[j] = (char *)NULL;
            return(j);
        }
    }
}

int
mother_is_dead(int mompid, char *s)
{
    if (Kill(mompid, 0, s, K_OTHER))   /* Mom's dead. */
	return(TRUE);
    else if (getppid() == 1)
        return(TRUE);
    else
	return(FALSE);
}

static void
delete_contents(char *dirname, int originator)
{
    DIR *dirp;
    struct dirent *dp;
    char entry[STRINGSIZE];

    dirp = opendir(dirname);
    for (dp = readdir(dirp); dp != (struct dirent *)NULL; dp = readdir(dirp)) {
        if (strcmp(dp->d_name, ".") == 0)
            continue;
        if (strcmp(dp->d_name, "..") == 0)
            continue;
        sprintf(entry, "%s/%s", dirname, dp->d_name);
        if (is_directory(entry)) {
            delete_contents(entry, originator);
            rmdir(entry);
        }
        else {
            delete_file(entry, originator);
	}
    }
    closedir(dirp);
}

/*
 *  Act on behalf of the originator (specified by "org") to send signals
 *  any other process.  Guard against any "special case" pid arguments 
 *  being thrown around by mistake; if attempted, try to die gracefully.
 */
int
Kill(int pid, int sig, char *org, int who)
{
    register int i;
    int save_mode;

    if (pid <= 0) {
        if (Shm->mode & (CINIT|GINIT)) {
            char buf[STRINGSIZE];

            sprintf(buf, "%s kill: T%d:S%d:P%d", org, who, sig, pid);
	    USER_MESSAGE(buf);
	    if (Shm->mode & CINIT)
	        bottom_left(FALSE);
        }

        for (i = 0; i < Shm->procno; i++) {
            Shm->stderr("%s%02d:%05d:%02x", 
                i == 0 ? "\r   [" : "", 
                i+1, Shm->ptbl[i].i_pid, Shm->ptbl[i].i_stat);
            if (i == 5)
                Shm->stderr("]  \r\n   [");
            else if (i == 11)
                Shm->stderr("]  ");
            else
                Shm->stderr(" ");
            if (Shm->ptbl[i].i_pid > 0) {
		kill(Shm->ptbl[i].i_pid, SIGKILL);
                set_Kill_source(Shm->ptbl[i].i_pid, SIGKILL, org);
            }
        }

        save_mode = Shm->mode;

        for (i = 0; i < NUMSG && (Shm->mode & MESGQ_MODE); i++) {
            if (Shm->msgid[i] < 0)
                continue;
            if (msgctl(Shm->msgid[i], IPC_RMID, (struct msqid_ds *)NULL) == -1)
                Shm->perror("Kill: msgctl");
        }

        if (shmdt(Shm->shm_addr) == -1)
            Shm->perror("Kill: shmdt");

        if (shmctl(Shm->shmid, IPC_RMID, (struct shmid_ds *)NULL) == -1)
            Shm->perror("Kill: shmctl");

        if (WINDOW_MGR()) {
                save_screen(SCREEN_SAVED);
                dump_status(WINDOW_MANAGER_KILLED, NULL);

        	if (save_mode & CINIT) 
		    bottom_left(TRUE);
	}

        Shm->stderr( 
           "\r\n   [FATAL ERROR: Kill: T%d  sig: %d  origin: %s  pid: %d]\r\n", 
            who, sig, org, pid);

        if (Shm->mode & SHUTDOWN_MODE)   /* attempt clean shutdown... */
                return 0;
	
        _exit(KILL_EXIT);
    }
    else {
        set_Kill_source(pid, sig, org);
        return(kill(pid, sig));
    }
}

/*
 *  Chronicle the caller of Kill() wrapper above.
 */
void
set_Kill_source(uint pid, int sig, char *src)
{
        register int i; 
                    
        for (i = 0; sig && i < Shm->procno; i++) {
                if (Shm->ptbl[i].i_pid == pid) {
                        Shm->ptbl[i].i_killorg = src;
                        break;
                }       
        }           
}

/*
 *  Prompt the user to get rid of any perceived-as-leftover files.
 */


int
chk_leftovers(int query)
{
    DIR *dirp;
    struct dirent *dp;
    char input[MESSAGE_SIZE];
    char entry[MESSAGE_SIZE];
    char IO_file[MESSAGE_SIZE];
    int found, pid;
    FILE *fp;
    char cwd_buf[1026];
    char *cwd;

    if ((cwd = getcwd(cwd_buf, sizeof(cwd_buf)-2) ) == (char *)NULL) 
        Shm->perror("getcwd");

    found = 0;
    pid = getpid();

    dirp = opendir("/tmp");
    for (dp = readdir(dirp); dp != (struct dirent *)NULL; dp = readdir(dirp)) {
        if (matches(dp->d_name, "ux######") && matches_pid(dp->d_name, pid))
            continue;
        sprintf(entry, "/tmp/%s", dp->d_name);
        if ((matches(entry, "/tmp/ux######_IO")) &&
            (not_running(dp->d_name, TRUE))) {
            if ((fp = fopen(entry, "r")) == (FILE *)NULL)
                Shm->perror(entry);
            else {
                if (fgets(IO_file, MESSAGE_SIZE, fp) == (char *)NULL) 
                    Shm->perror(IO_file); 
                while (fgets(IO_file, MESSAGE_SIZE, fp)) {
                    IO_file[strlen(IO_file)-1] = (char)NULLCHAR;
                    if (!file_exists(IO_file))
                        continue;
		    if (Shm->mode & DEBUG_MODE)
			Shm->stderr(
			    "DEBUG: linking \"%s\" from IO_file loop\r\n",
				IO_file);
		    if (link_leftover(IO_file))
			found++;
                }
                fclose(fp);
                if (Shm->mode & DEBUG_MODE)
                    Shm->stderr("DEBUG: linking \"%s\" from /tmp _IO loop\r\n",
			entry);
		if (link_leftover(entry))
                    found++;
            }
        }
        if ((matches(entry, "/tmp/ux######")) &&
            !(matches(entry, "/tmp/ux######_IO")) &&
            (not_running(dp->d_name, FALSE))) {
            if (!file_exists(entry))
                continue;
            if (Shm->mode & DEBUG_MODE)
                Shm->stderr("DEBUG: linking \"%s\" from /tmp/ux loop\r\n", 
		    entry);
            if (link_leftover(entry))
                found++;
        }
    }
    closedir(dirp);

    if (cwd && strcmp(cwd, "/")) {
        dirp = opendir(cwd);
        for (dp = readdir(dirp); dp != (struct dirent *)NULL; 
	    dp = readdir(dirp)) {
            if (matches(dp->d_name, "ux######") && matches_pid(dp->d_name, pid))
		continue;
            if ((matches(dp->d_name, "ux######")) &&
                (not_running(dp->d_name, FALSE))) {
                sprintf(entry, "%s/%s", cwd, dp->d_name);
                if (!file_exists(entry))
                    continue;
                if (Shm->mode & DEBUG_MODE)
                    Shm->stderr("DEBUG: linking \"%s\" from  (cwd, /) loop\r\n",
			entry);
                if (link_leftover(entry))
                    found++;
            }
        }
        closedir(dirp);
    }

    dirp = opendir("/");
    for (dp = readdir(dirp); dp != (struct dirent *)NULL; dp = readdir(dirp)) {
        if (matches(dp->d_name, "ux######") && matches_pid(dp->d_name, pid))
		continue;
        if ((matches(dp->d_name, "ux######")) &&
            (not_running(dp->d_name, FALSE))) {
            sprintf(entry, "/%s", dp->d_name);
            if (!file_exists(entry))
                continue;
            if (Shm->mode & DEBUG_MODE)
                 Shm->stderr("DEBUG: linking \"%s\" from / loop\r\n", entry);
            if (link_leftover(entry))
                found++;
        }
    }
    closedir(dirp);

    if (is_directory("/usex")) {
        dirp = opendir("/usex");
        for (dp = readdir(dirp); dp != (struct dirent *)NULL; 
	    dp = readdir(dirp)) {
            if (matches(dp->d_name, "ux######") && matches_pid(dp->d_name, pid))
		continue;
            if ((matches(dp->d_name, "ux######")) &&
                (not_running(dp->d_name, FALSE))) {
                sprintf(entry, "/usex/%s", dp->d_name);
                if (!file_exists(entry))
                    continue;
                if (Shm->mode & DEBUG_MODE)
                    Shm->stderr("DEBUG: linking \"%s\" from  /usex loop\r\n", 
			entry);
                if (link_leftover(entry))
                    found++;
            }
        }
        closedir(dirp);
    }

    if (is_directory("/usr/tmp")) {
        dirp = opendir("/usr/tmp");
        for (dp = readdir(dirp); dp != (struct dirent *)NULL; 
	    dp = readdir(dirp)) {
            if (matches(dp->d_name, "ux######") && matches_pid(dp->d_name, pid))
                continue;
            if ((matches(dp->d_name, "ux######")) &&
                (not_running(dp->d_name, FALSE))) {
                sprintf(entry, "/usr/tmp/%s", dp->d_name);
                if (!file_exists(entry))
                    continue;
                if (Shm->mode & DEBUG_MODE)
                    Shm->stderr("DEBUG: linking \"%s\" from  /usr/tmp loop\r\n",
 			entry);
                if (link_leftover(entry))
                    found++;
            }
        }
        closedir(dirp);
    }

    if (found) {
        int real_found;

        real_found = found;

	if (query)
            input[0] = 'n';
	else
	    input[0] = 'y';

        tty_fd = -1;

        if ((tty_fd = open("/dev/tty", O_RDONLY)) < 0) {
            found = 0;
            sleep(Shm->mode & NOTTY ? 0 : 5);
        } else {
            if ((found = show_leftovers(found))) {
		if (query) {
                    Shm->stderr("Do you want to remove %s?: y\b", 
                        found == 1 ? "it" : "them");
                    read(tty_fd, input, MESSAGE_SIZE);
		}
	    }
        }
        if (found && ((input[0] == 'y') || (input[0] == '\n'))) {
            real_found = rm_leftovers();
	    Shm->printf("%d file%s removed.\n", real_found, 
                (real_found == 0 || real_found > 1) ? "s" : "");
        }
        if (tty_fd >= 0)
            close(tty_fd);
    }

    return (found);
}

static int
matches_pid(char *s, int pid) 
{
    int upid; 
    char filename[STRINGSIZE];
    char *p;

    strcpy(filename, s);

    for (p = filename; *p; p++) {
        if (*p < '0' || *p > '9')
            *p = (char)NULLCHAR;
    }
    upid = atoi(&filename[2]);

    if (upid == pid)
        return(TRUE);
    else
        return(FALSE);

}

static int
not_running(char *s, int check_parent)
{
    int upid, ppid; 
    char *p, save;
    char filename[STRINGSIZE], parent_pid[STRINGSIZE];
    FILE *fp;

    if (check_parent)
        sprintf(filename, "/tmp/%s", s);   /* Save the filename. */

    s += 2;  /* get past the leading "ux". */

    for (p = s, save = (char)NULLCHAR; *p; p++) {
        if (*p < '0' || *p > '9') {
            save = *p;
            *p = (char)NULLCHAR;
	    break;
        }
    }
    upid = atoi(s);
    *p = save;

    if (check_parent) {   
       /*
        *  Check whether the target usex invocation's parent is still alive.
        *  If not, consider the usex instance as bogus.
        */
        if ((fp = fopen(filename, "r")) == (FILE *)NULL)
            Shm->perror(filename);
        else {
            if  (fgets(parent_pid, MESSAGE_SIZE, fp) == (char *)NULL) 
                Shm->perror(filename);
     	else {
                ppid = atoi(parent_pid);
                fclose(fp);
                if (ppid > 0) {
		    switch (kill(ppid, 0))
                    {
		    case 0:
			break;  /* parent is definitely alive -- check child */

                    default:
			if (errno == EPERM)   /* permission problem... */
			    break;
			else
			    return(TRUE);    /* abandon child! */
		    }
                }
            }
        }
    }

   /*
    *  Either:
    *
    *    (1) We aren't dealing with the parent at all, or...
    *    (2) The parent of the target usex invocation is apparently still
    *        alive -- however it also could be a pid wrap-around.  
    *
    *  In either case, we've got to check the usex invocation itself.
    */

    if (upid > 0) {
        if (kill(upid, 0) == 0)
            return(FALSE);
        else if (errno == EPERM)
	    return(FALSE);       /* Can't touch proc -- must be alive. */
        else
            return(TRUE);
    }
    return(TRUE);
}

static int
matches(char *s1, char *s2)
{
    register int i;

    for (i = 0; s2[i]; i++) {
        if (s2[i] == '#') {
            if (s1[i] < '0' || s1[i] > '9')
		return(FALSE);
            continue;
        }
        if (s1[i] != s2[i])
            return(FALSE);
    }
    return(TRUE);
}

static int
link_leftover(char *file)
{
    register int i;

/***
    if (is_directory(file)) {
        Shm->stderr("WARNING: Please remove %s directory by hand.\n", file);
	directories_found++;
        return(FALSE);
    }
***/

    for (i = 0; i < MAX_LEFTOVERS; i++) {
        if (leftovers[i] == (char *)NULL)
	    break;
        if (strcmp(file, leftovers[i]) == 0) 
    	    return(FALSE);
    }
    if (i == MAX_LEFTOVERS)
	return(FALSE);

    if ((leftovers[i] = (char *)malloc(strlen(file)+2)) == (char *)NULL) {
        Shm->perror("malloc");
        return(FALSE);
    }
    strcpy(leftovers[i], file);

    return(TRUE);
}

static int
show_leftovers(int count)
{
    register int i;
    int query = FALSE;
    int real_count;

    for (i = real_count = 0; i < MAX_LEFTOVERS; i++) {
        if (leftovers[i] == (char *)NULL)
            break;
        if (same_file(leftovers[i], Shm->infile))
            continue;
        if (!query) {
    	    if (count == 1)
                Shm->stderr(
              "usex: WARNING: This file appears to be a leftover usex file:\n");
            else
                Shm->stderr(
              "usex: WARNING: These files appear to be leftover usex files:\n");
	    query = TRUE;
	}
        Shm->stderr("    %s\n", leftovers[i]);
	real_count++;
    }
    
    return(real_count);
}


static int
rm_leftovers(void)
{
    register int i;
    int cnt;

    leftover_removal = TRUE;
    for (i = cnt = 0; i < MAX_LEFTOVERS; i++) {
        if (leftovers[i] == (char *)NULL)
	    break;
        if (same_file(leftovers[i], Shm->infile))
            continue;
        if (delete_file(leftovers[i], NOT_USED)) 
	    cnt++;
    }
    leftover_removal = FALSE;
    return(cnt);
}

static int
not_in_list(char *filename)
{
    register int i;

    for (i = 0; i < MAX_LEFTOVERS; i++) {
        if (strcmp(filename, leftovers[i]) == 0)
            return(FALSE);
    }
    return(TRUE);

}

/*
 *  Read a message from the appropriate test message queue.
 */
int 
get_usex_message(int queue, char *buffer)
{
        switch (Shm->mode & IPC_MODE)
        {
        case PIPE_MODE:
	    if (Shm->win_pipe[queue * 2] == -1)
		return FALSE;

            if (!(pipe_read(Shm->win_pipe[queue * 2], buffer))) {
                if (!(canned_message(queue, buffer))) {
                    return FALSE;
                }
	    }
	    return TRUE;

        case MESGQ_MODE:
	    if (Shm->msgid[queue] < 0) {
		return FALSE;
	    }

            if (msgrcv(Shm->msgid[queue],
                (struct msgbuf *)&Shm->u_msgq, MESSAGE_SIZE, 0L,
                IPC_NOWAIT) == -1) {
                if (errno != ENOMSG)
                    Shm->perror("curses_mgr: msgrcv");
	        if (!(canned_message(queue, buffer))) {
                    return FALSE;
                }
            }
            else
                strcpy(buffer, Shm->u_msgq.string);
            return TRUE;

        case MMAP_MODE:
        case SHMEM_MODE:
            if (queue >= Shm->procno)
		return FALSE;
	
            if (!(shm_read(queue, buffer))) {
	        if (!(canned_message(queue, buffer))) {
                    return FALSE;
	        }
	    }
            return TRUE;

	default:
	    return FALSE;
        }
}

/*
 *  ring_init()
 *
 *      Initialize all possible shared memory ring buffers and pointers.
 */

void
ring_init(void)
{
    register int i;

    for (i = 0; i < MAX_IO_TESTS; i++) {
        bzero(Shm->ptbl[i].i_rbuf, I_RINGBUFSIZE);
        Shm->ptbl[i].i_wptr = Shm->ptbl[i].i_rptr = 0;
        Shm->ptbl[i].i_blkcnt = 0;
	Shm->ptbl[i].i_lock = 0;
    }

    for (i = 0; i < NUMSG; i++) {
	Shm->being_read[i] = FALSE;
	Shm->being_written[i] = FALSE;
	Shm->wake_me[i] = FALSE;
    }
}

/* 
 *  Another strealined signal catcher...
 */
void
block(int useless)
{ }

/*
 *  shm_write()
 *
 *      Writes to a specified ring buffer.  
 *      Returns on successful completion.
 *
 */
void
shm_write(int ring, char *buffer, int count)
{
    char *bp;
    volatile int *wp;
    volatile int *rp ATTRIBUTE_UNUSED;
    unsigned *blks, *stat;
    int ringbufsize;
    unsigned int *lockptr;

    /*
     *  Give the window manager priority over access to the ring buffer.
     *  Only access it when being_read is FALSE, AND being_written is TRUE;
     *  To ensure this, make sure the window manager doesn't sneak in and
     *  set being_read during the window of opportunity when being_written
     *  is being set.
     */

retry_write:

    while (1) {
        while (Shm->being_read[ring])   /* Shouldn't be long... */
            ;

        Shm->being_written[ring] = TRUE;  /* Signal window manager. */

        if (Shm->being_read[ring])                /* The bitch snuck in, */
                Shm->being_written[ring] = FALSE; /* so try again... */
        else
            break;
    }

    bp = Shm->ptbl[ring].i_rbuf;
    wp = &Shm->ptbl[ring].i_wptr;
    rp = &Shm->ptbl[ring].i_rptr;
    blks = &Shm->ptbl[ring].i_blkcnt;
    stat = &Shm->ptbl[ring].i_stat;
    lockptr = &Shm->ptbl[ring].i_lock;
    ringbufsize = I_RINGBUFSIZE;

    if (Shm->being_read[ring]) {               
        Shm->being_written[ring] = FALSE;
	goto retry_write;
    }

    if (!shmcpy(bp, wp, ring, buffer, count, ringbufsize, lockptr)) {
        (*blks)++;

        /* Tell window manager to wake me */
        /* up the next time my queue is   */
        /* read.  Then take a break...    */

	*stat &= ~WAKE_UP;
        *stat |= WAKE_ME;            
        Shm->wake_me[ring] = TRUE;
	while (TRUE) {
            pause();                     
	    if (*stat & WAKE_UP)
	        break;
	}
        *stat &= ~(WAKE_ME|WAKE_UP);           
        Shm->wake_me[ring] = FALSE;

        if (!(*stat & (IO_DYING|IO_DEAD))) {
            Shm->being_written[ring] = FALSE;
	    goto retry_write;
	}
    }

    Shm->being_written[ring] = FALSE;
}

#ifdef LOCKSTATS
void
dump_ring_stats(void)
{
    register int ring;
    double write_hit_rate;
    double read_hit_rate;

    Shm->printf(
	"\r\n                 WRITE OPS                         READ OPS"); 
    Shm->printf(
    "\r\n         first max total (hit rate)       first max total (hit rate)");

    for (ring = 0; ring < NUMSG; ring++) {

	if (Shm->lockstats[ring].total_write_locks)
	     write_hit_rate = ((double)(Shm->lockstats[ring].first_write_hits)/
                 (double)(Shm->lockstats[ring].total_write_locks)) * 100.0;
	else
	     write_hit_rate = 0.0;

        if (Shm->lockstats[ring].total_read_locks)
	    read_hit_rate = ((double)(Shm->lockstats[ring].first_read_hits)/
                (double)(Shm->lockstats[ring].total_read_locks)) * 100.0;
	else
	    read_hit_rate = 0.0;

        switch (ring) 
	{
	default:
	    if (ring >= Shm->procno)
		break;
	    Shm->printf(
  "\r\nTEST %02d:      %d %d %d (%.1f%%)		%d %d %d (%.1f%%)",
		ring+1,
                Shm->lockstats[ring].first_write_hits,
                Shm->lockstats[ring].max_write_spins,
		Shm->lockstats[ring].total_write_locks,
                write_hit_rate,
                Shm->lockstats[ring].first_read_hits,
                Shm->lockstats[ring].max_read_spins,
                Shm->lockstats[ring].total_read_locks,
		read_hit_rate);
 	    break;

	}
    }
    Shm->printf("\r\n");
}
#endif


static int 
shmcpy(char *bp, 
       volatile int *wp, 
       int ring, 
       char *buffer, 
       int count, 
       int ringbufsize, 
       unsigned int *lockptr)
{
    register int i, j, sum;
    unsigned long spin = 0;

    while (!LOCK(lockptr)) {
	spin++;
#ifdef LOCKSTATS
	if (spin >= MAX_SPINS) {
            Shm->lockstats[ring].max_write_spins = MAX_SPINS;
            Shm->lockstats[ring].total_write_locks += spin;
	    return(FALSE);
	}
#endif
    }

#ifdef LOCKSTATS
    if (!spin)
        Shm->lockstats[ring].first_write_hits++;
    else if (spin > Shm->lockstats[ring].max_write_spins)
        Shm->lockstats[ring].max_write_spins = spin;
    Shm->lockstats[ring].total_write_locks += (spin+1);
#endif

    for (i = sum = 0, j = *wp; i < count; i++, j++) {
        sum |= bp[j % ringbufsize];
        if (sum) {
	    UNLOCK(lockptr);
            return(FALSE);
	}
    }

#ifdef ENTER_BACKWARDS
    for (i = (count-1); i >= 0; i--) {
        bp[(*wp+i) % ringbufsize] = buffer[i];
    }
    *wp = (*wp + count) % ringbufsize;
#else
    for (i = 0; i < count; i++) {
        bp[*wp] = buffer[i];
        *wp = (*wp + 1) % ringbufsize;
    }
#endif

    UNLOCK(lockptr);
    return(TRUE);
}

/*
 *  shm_read()
 *
 *      Reads a NULL-terminated string from the specified ring buffer.
 *      Returns 0 if nothing there, count if read was successful.
 */
int
shm_read(int ring, char *buffer)
{
    register int i, count;
    register char *s = buffer;
    char *bp;
    volatile int *rp, rp1;
    int retval, pid;
    int ringbufsize;
    unsigned int *lockptr ATTRIBUTE_UNUSED;
    unsigned int *statptr;
    unsigned long spin = 0;

    Shm->being_read[ring] = TRUE;

    bp = Shm->ptbl[ring].i_rbuf;
    rp = &Shm->ptbl[ring].i_rptr;
    pid = Shm->ptbl[ring].i_pid;
    ringbufsize = I_RINGBUFSIZE;
    lockptr = &Shm->ptbl[ring].i_lock;
    statptr = &Shm->ptbl[ring].i_stat;

    if (Shm->being_written[ring] && !Shm->wake_me[ring]) {
        Shm->being_read[ring] = FALSE;
        return(FALSE);
    }

    *statptr &= ~RING_OUT_OF_SYNC;

    while (!LOCK(lockptr)) {
        spin++;
#ifdef LOCKSTATS
        if (spin >= MAX_SPINS) {
            Shm->lockstats[ring].max_read_spins = MAX_SPINS;
            Shm->lockstats[ring].total_read_locks += spin;
	    return(FALSE);
        }
#endif
    }

#ifdef LOCKSTATS
    if (!spin)
        Shm->lockstats[ring].first_read_hits++;
    else if (spin > Shm->lockstats[ring].max_read_spins)
        Shm->lockstats[ring].max_read_spins = spin;
    Shm->lockstats[ring].total_read_locks += (spin+1);
#endif

    if (bp[*rp] == (char)NULLCHAR) {
	if (Shm->wake_me[ring]) 
	    *statptr |= RING_OUT_OF_SYNC;
	retval = FALSE;
    }
    else {
#ifdef ENTER_BACKWARDS
	rp1 = *rp;
        count = 1;
        while (bp[rp1]) {
            *s++ = bp[rp1];
            rp1 = (rp1 + 1) % ringbufsize;
	    count++;
        }
        *s = (char)NULLCHAR;

        for (i = (count-1); i >= 0; i--) {
            bp[(*rp+i) % ringbufsize] = (char)NULLCHAR;
        }
        *rp = (*rp + count) % ringbufsize;
#else
        while (bp[*rp]) {
            *s++ = bp[*rp];
            bp[*rp] = (char)NULLCHAR;
            *rp = (*rp + 1) % ringbufsize;
        }
        *s = (char)NULLCHAR;
        *rp = (*rp + 1) % ringbufsize;
#endif
        retval = TRUE;
    }

    UNLOCK(lockptr);
    Shm->being_read[ring] = FALSE;

    if (Shm->wake_me[ring]) { 
        *statptr |= WAKE_UP;
        Kill(pid, SIGALRM, "L1", ring < 12 ? K_IO(ring) : ring+1);
    }

    return(retval);
}

/*
 *  Mechanism for an I/O test to ensure that all of its previous messages
 *  have been gathered and handled by the window manager.  This doesn't
 *  currently work for the transfer rate test, but shouldn't ever have to.
 */
void
synchronize(int id, char *s)
{
    register PROC_TABLE *tbl;
    char buffer[MESSAGE_SIZE*2];

    if (id >= Shm->procno)
	return;

    bzero(buffer, MESSAGE_SIZE*2);
    tbl = &Shm->ptbl[id];
    sprintf(buffer, "%c%c", SYNCHRONIZE, tbl->i_local_pid);
    if (s)
	strcat(buffer, s);

    tbl->i_stat |= IO_SYNC;

    switch (Shm->mode & IPC_MODE)
    {
    case PIPE_MODE:
        pipe_write(Shm->win_pipe[ID_TO_PIPE], buffer, strlen(buffer)+1);
        break;

    case MESGQ_MODE:
        strcpy(tbl->i_msgq.string, buffer);
        if (msgsnd(tbl->i_msg_id, (struct msgbuf *)&tbl->i_msgq,
            MESSAGE_SIZE, 0) == -1 && (errno != EINTR)) {
            fatal(id, "synchronize: msgsnd", errno);
        }
        break;

    case MMAP_MODE:
    case SHMEM_MODE:
        shm_write(RING_IO(id), buffer, strlen(buffer)+1);
        break;
    }

    while (get_i_stat(tbl) & IO_SYNC)
	stall(100000);
}

uint
get_i_stat(PROC_TABLE *tbl)
{
    volatile uint stat;

    stat = (volatile uint)tbl->i_stat;
    return(stat);
}


int
min(int a, int b)
{
    if (a <= b)
	return(a);
    else
	return(b);
}

ulong
ulmin(ulong a, ulong b)
{
    if (a <= b)
	return(a);
    else
	return(b);
}

void
fatal(int who, char *s, int test_errno)
{
    char *dest;
    int *demise_ptr;
    char workbuf[STRINGSIZE*2];
    char logbuf[STRINGSIZE*2];

    strcpy(workbuf, s);
    if (test_errno > 0) {
        strcat(workbuf, ": ");
        strcat(workbuf, strerror(test_errno));
    }

    if (who >= Shm->procno)
	return;
    set_time_of_death(who);
    dest = Shm->ptbl[who].i_fatal_errmsg;
    demise_ptr = &Shm->ptbl[who].i_demise;
    if (test_errno > 0)
		Shm->ptbl[who].i_saved_errno = test_errno;

    sprintf(logbuf, " %s TEST %d: FATAL ERROR: %s", test_type(ID), ID+1, s);
    if (test_errno > 0) {
            strcat(logbuf, ": ");
            strcat(logbuf, strerror(test_errno));
    }
    strcat(logbuf, "\n");

    io_send(LOG_MESSAGE|IO_SYNC, (long)logbuf, NOARG, NOARG);

    if (dest) {
    	bzero(dest, FATAL_STRINGSIZE);
    	strncpy(dest, workbuf, min(strlen(workbuf), FATAL_STRINGSIZE-1));
    }

    if (demise_ptr && (*demise_ptr == 0))
	*demise_ptr = BY_EXIT;

    _exit(FATAL_EXIT);
}

void
paralyze(int who, char *s, int test_errno)
{
    char *dest;
    int *demise_ptr;
    char workbuf[STRINGSIZE*2];
    char logbuf[STRINGSIZE*2];

    strcpy(workbuf, s);
    if (test_errno > 0) {
        strcat(workbuf, ": ");
        strcat(workbuf, strerror(test_errno));
    }

    if (who >= Shm->procno)
        return;
    set_time_of_death(who);
    dest = Shm->ptbl[who].i_fatal_errmsg;
    demise_ptr = &Shm->ptbl[who].i_demise;
    if (test_errno > 0) 
	Shm->ptbl[who].i_saved_errno = test_errno;
    Shm->ptbl[who].i_stat |= IO_SUICIDE;

    sprintf(logbuf, " %s TEST %d: FATAL ERROR: %s", test_type(ID), ID+1, s);
    if (test_errno > 0) {
        strcat(logbuf, ": ");
        strcat(logbuf, strerror(test_errno));
    }
    strcat(logbuf, "\n");
    io_send(LOG_MESSAGE|IO_SYNC, (long)logbuf, NOARG, NOARG);

    if (dest) {
    	bzero(dest, FATAL_STRINGSIZE);
    	strncpy(dest, workbuf, min(strlen(workbuf), FATAL_STRINGSIZE-1));
    }

    if (demise_ptr)
	*demise_ptr = BY_DEATH;

    io_send(FSTAT, DEAD, NOARG, NOARG);

    for (EVER)
        time_out(UNTIL_KILLED);

    /* NOTREACHED */
    _exit(PARALYZE_EXIT);
}

char *
test_type(int id)
{

    static char *type_strings[] = {
        "DISK",
        "WHETSTONE",
        "DHRYSTONE",
        "NULL",
        "USER",
        "VMEM",
        "BIN",
        "DEBUG",
	"RATE",
    };

    switch (Shm->ptbl[id].i_type)
    {
    case DISK_TEST:  return(type_strings[0]);
    case WHET_TEST:  return(type_strings[1]);
    case DHRY_TEST:  return(type_strings[2]);
    case NULL_TEST:  return(type_strings[3]);
    case USER_TEST:   return(type_strings[4]);
    case VMEM_TEST:  return(type_strings[5]);
    case BIN_TEST:   return(type_strings[6]);
    case DEBUG_TEST: return(type_strings[7]);
    case RATE_TEST:  return(type_strings[8]);
    default:         return("");
    }
}

int                     
count_bits_long(long val)
{                       
        register int i, cnt;
        int total;
                        
        cnt = sizeof(long) * 8;

        for (i = total = 0; i < cnt; i++) {
                if (val & 1)
                        total++;
                val >>= 1;
        }

        return total;
}


#ifdef NOTDEF
struct fstab {
        char    *fs_spec;               /* block special device name */
        char    *fs_file;               /* file system path prefix */
        char    *fs_type;               /* FSTAB_* */
        int     fs_freq;                /* dump frequency, in days */
        int     fs_passno;              /* pass number on parallel dump */
        char    *fs_vfstype;            /* File system type, ufs, nfs */
        char    *fs_mntops;             /* Mount options ala -o */
};
#endif

int
get_swap_file(char *buf)
{
	struct fstab *fs;
	FILE *fp;
	char input[STRINGSIZE];
	int retval; 
	int argc ATTRIBUTE_UNUSED;
	char *argv[MAX_ARGV];

	while ((fs = getfsent())) {
		if (strcmp(fs->fs_file, "swap") == 0) {
		       	console("fs_spec: %s (%s)\n", fs->fs_spec, 
				filename(fs->fs_spec)); 
			strcpy(buf, fs->fs_spec);
			return(TRUE);
		}
	}

	if ((fp = popen("/sbin/swapon -s", "r")) == NULL)
		return FALSE;

	retval = FALSE;

 	while (fgets(input, STRINGSIZE, fp) != NULL) {
		if (strstr(input, "Filename"))
			continue;
		argc = parse(input, argv);
		if (streq(argv[1], "partition")) {
			strcpy(buf, argv[0]);
			retval = TRUE;
			break;
		}
	}
	pclose(fp);

	return(retval);
}

#ifdef linux
ulong
get_free_memory(void)
{
#ifdef UNRELIABLE
        /*
         *  The use of sysinfo would be preferable, but the structure
         *  definition has changed from OS revision to revision, making
         *  it impossible to run the same usex executable on different
         *  revisions.
         */
        struct sysinfo info;

        if (sysinfo(&info) == 0)
                return(info.freeram);
        else
                return(0);
#endif
#ifdef PROC_MEMINFO

MemTotal:    127644 kB         2.2.5
MemFree:      14268 kB
MemShared:    79652 kB
Buffers:       2668 kB
Cached:       39644 kB

MemTotal:   2006688 kB         2.3.99
MemFree:    1424840 kB
MemShared:        0 kB
Buffers:     346808 kB
Cached:       89584 kB

#endif

    	int found, argc;
    	char *argv[MAX_ARGV];
    	char buf[STRINGSIZE*2];
	double availmem;
	ulong value;
    	FILE *pp;

    	if ((pp = popen("cat /proc/meminfo", "r")) == NULL)
		return 0;

	found = 0;
	availmem = 0.0;

    	while (fgets(buf, STRINGSIZE*2, pp)) {
		if (strncmp(buf, "MemFree: ", strlen("MemFree: ")) == 0) {
        		argc = parse(buf, argv);
        		if ((argc == 3) && streq(argv[2], "kB")) {
				found++;
				value = atol(argv[1]) * 1024;
				availmem += value;	
				console("MemFree: %ld  availmem: %.0f\n",
					value, availmem);
			}
		}

		if (strncmp(buf, "Cached: ", strlen("Cached: ")) == 0) {
                        argc = parse(buf, argv);
                        if ((argc == 3) && streq(argv[2], "kB")) {
                                found++;
                                value = atol(argv[1]) * 1024;
                                availmem += value;
				console("Cached: %ld  availmem: %.0f\n",
					value, availmem);
                        }
		}

		if (strncmp(buf, "Buffers: ", strlen("Buffers: ")) == 0) {
                        argc = parse(buf, argv);
                        if ((argc == 3) && streq(argv[2], "kB")) {
                                found++;
                                value = atol(argv[1]) * 1024;
                                availmem += value;
				console("Buffers: %ld  availmem: %.0f\n",
					value, availmem);
                        }
		}
    	}
	pclose(pp);

	if (found != 3) {
		set_timer_request(1, debug_message, 
			DEBUG_MESSAGE_MEMINFO(5), 0);
		if (!found)
			return 0;
	}

	return ((ulong)((availmem * .75)/1048576));
}
#else
unsigned long
get_free_memory(void)
{
	return 0;
}
#endif

/*
 *  These comparison functions must return an integer less  than,
 *  equal  to,  or  greater than zero if the first argument is
 *  considered to be respectively  less  than,  equal  to,  or
 *  greater than the second.  If two members compare as equal,
 *  their order in the sorted array is undefined.
 */

int
compare_ints(const void *v1, const void *v2)
{
        int *i1, *i2;

        i1 = (int *)v1;
        i2 = (int *)v2;

        if (*i1 < *i2)
                return -1;
        if (*i1 == *i2)
                return 0;
        else /* (*i1 > *i2) */
                return 1;

}

void
console_init(int sig)
{
        if (!strlen(Shm->console_device)) {
                Shm->confd = -1;
                return;
        }

	switch (sig)
	{
	case SIGALRM:
        	if (Shm->mode & CONS_PENDING)
                	longjmp(bogus_console, 1);
		return;

	case 0:
		if (Shm->mode & CONS_INIT)
			return;
		Shm->mode |= CONS_INIT;
		break;
	}

        if ((Shm->confd = open(Shm->console_device, O_WRONLY)) < 0) {
                set_timer_request(1, debug_message, DEBUG_MESSAGE_CONSOLE(5),0);
                return;
        }

	Shm->mode |= CONS_PENDING;

        if (setjmp(bogus_console)) {
        	Shm->confd = -1;
		Shm->mode &= ~CONS_PENDING;
                set_timer_request(1, debug_message, DEBUG_MESSAGE_CONSOLE(5),0);
                return;
        } 

        signal(SIGALRM, console_init);
        alarm(4);
        write(Shm->confd, "\n", 1);
        alarm(0);
        Shm->mode &= ~CONS_PENDING;
        signal(SIGALRM, SIG_DFL);

    	console("window manager: %d\n", Shm->mompid);
}

void
console(char *fmt, ...)
{
        char buf[MAX_PIPELINE_READ];
        va_list ap;

        va_start(ap, fmt);
        (void)vsnprintf(buf, MAX_PIPELINE_READ, fmt, ap);
        va_end(ap);

        if (Shm->confd < 0)
                return;

	if (!(Shm->mode & CONS_INIT)) {
		console_init(0);
		if (Shm->confd < 0)
			return;
	}

        if (!fmt)
                return;

        if (write(Shm->confd, buf, strlen(buf)) != strlen(buf)) {
		Shm->confd = -1;
		set_timer_request(1, debug_message, 
			DEBUG_MESSAGE_CONSOLE(5), 0);
                return;
        }
}


char *
adjust_size(size_t size, int flen, char *outbuf, int rjust)
{
	register int i;
	size_t max;
	double mbs ATTRIBUTE_UNUSED;
	char buf[STRINGSIZE];
        char fmt[STRINGSIZE];

	bzero(buf, STRINGSIZE);
	for (i = 0; i < flen; i++)
	    buf[i] = '9';

        max = atol(buf);

	if (size <= max) {
		if (rjust) {
	    		sprintf(buf, "%lu", (ulong)size);
			sprintf(fmt, "%%%ds", flen);
			sprintf(outbuf, fmt, buf);
		} else
	    		sprintf(outbuf, "%lu", (ulong)size);
		return outbuf;
	}

	buf[strlen(buf)-1] = NULLCHAR;
	max = atol(buf) * 1024;

	if ((size <= max) && ((size % 1024) == 0)) {
		if (rjust) {
	    		sprintf(buf, "%ldK", (ulong)(size/1024));
			sprintf(fmt, "%%%ds", flen);
			sprintf(outbuf, fmt, buf);
		} else
	    		sprintf(outbuf, "%ldK", (ulong)(size/1024));
		return outbuf;
	}

	mbs = (double)size;

	if (rjust) {
		sprintf(buf, "%.1fM", size/(double)(1024*1024));
		sprintf(fmt, "%%%ds", flen);
		sprintf(outbuf, fmt, buf);
	} else 
		sprintf(outbuf, "%.1fM", size/(double)(1024*1024));

	return outbuf;
}

/*
 *  Determine whether a string contains only decimal characters.
 *  If count is non-zero, limit the search to count characters.
 */
int
decimal(char *s, int count)
{
    	char *p;
	int cnt;

	if (!count)
		strip_lf(s);
	else
		cnt = count;

    	for (p = &s[0]; *p; p++) {
	        switch(*p)
	        {
	            case '0':
	            case '1':
	            case '2':
	            case '3':
	            case '4':
	            case '5':
	            case '6':
	            case '7':
	            case '8':
	            case '9':
	            case ' ':
	                break;
	            default:
	                return FALSE;
	        }

		if (count && (--cnt == 0))
			break;
    	}

    	return TRUE;
}

FILE *
open_output_pipe(void)
{
	FILE *fp;

	if (Shm->opipe) {
		pclose(Shm->opipe);
		USER_MESSAGE("WARNING: opipe was left open");
	}

	if (!(Shm->mode & (MORE|LESS))) {
		if (file_exists("/usr/bin/less"))
			Shm->mode |= LESS;
		else if (file_exists("/bin/more"))
			Shm->mode |= MORE;
	}

	sigset(SIGPIPE, SIG_IGN);

	switch (Shm->mode & (MORE|LESS))
	{
	case MORE:
        	if (!(fp = Shm->opipe = popen("/bin/more", "w")))
			fp = stdout;
		break;

	case LESS:
        	if (!(fp = Shm->opipe = popen("/usr/bin/less -E -X", "w")))
        		fp = stdout;
		break;

	default:
		fp = stdout;
		break;
	}

	return fp;
}

void
close_output_pipe(void)
{
	if (Shm->opipe) {
		pclose(Shm->opipe);
                Shm->opipe = NULL;
	}
}

/*
 *  Debug routine to stop whatever's going on in its tracks.
 */
void
drop_core(char *s)
{
        if (s)
                Shm->stderr(s);

        kill(getpid(), 3);

}

/*
 *  Append a two-character string to a number to make 1, 2, 3 and 4 into
 *  1st, 2nd, 3rd, 4th, and so on...
 */
char *
ordinal(int val, char *buf)
{
        char *p1;

        sprintf(buf, "%d", val);
        p1 = &buf[strlen(buf)-1];

        switch (*p1)
        {
        case '1':
                strcat(buf, "st");
                break;
        case '2':
                strcat(buf, "nd");
                break;
        case '3':
                strcat(buf, "rd");
                break;
        default:
                strcat(buf, "th");
                break;
        }

        return buf;
}

int
is_mount_point(int id, char *dirname, int readable, char *device)
{
	FILE *fp;
	char buffer[256];
	int argc;
	char *path;
	char *argv[MAX_ARGV];
	struct stat sbuf;
	int retval;
	PROC_TABLE *tbl;

	if (id >= 0) {
		tbl = &Shm->ptbl[id];
		path = tbl->i_path;
	} else
		path = dirname;

        if ((fp = fopen("/etc/mtab", "r")) == NULL)
                return FALSE;

	retval = FALSE;

	while (fgets(buffer, 256-1, fp)) {
		if ((argc = parse(buffer, argv)) != 6)
			continue;

		if (streq(argv[1], path)) {
			if (what_is(argv[0], &sbuf) == S_IFBLK) {
				if (readable && !file_readable(argv[0])) 
					break;
				if (id >= 0) {
					strcpy(tbl->i_path, argv[0]);
					bcopy(&sbuf, &tbl->i_sbuf, 
						sizeof(struct stat));
				}
				if (device) 
					strcpy(device, argv[0]);
				retval = TRUE;
				break;
			}
		}
	}

	fclose(fp);
	return retval;
}

/*
 *  Parse the "from" string and copy the requested token to the "to" string.
 */
char *
get_token(char *from, char *to, int token, int *tokret)
{
	int argc;
        char *argv[MAX_ARGV*2];

	to[0] = NULLCHAR;

	argc = parse(from, argv);
	if (token < argc) 
		strcpy(to, argv[token]);

	*tokret = argc;

	return to;
}

/*
 *  Put a test in HOLD mode while keeping the heartbeat alive.
 */
void
put_test_on_hold(PROC_TABLE *tbl, int id)
{
	while (tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING)) {
		if ((tbl)->i_stat & IO_HOLD_PENDING) {                      
        		(tbl)->i_stat |= IO_HOLD;                           
                	(tbl)->i_stat &= ~IO_HOLD_PENDING;                  
    			switch (tbl->i_type)
    			{
    			case DISK_TEST:  
 			case WHET_TEST:  
    			case DHRY_TEST:  
    			case NULL_TEST:  
    			case VMEM_TEST:  
    			case DEBUG_TEST: 
    			case RATE_TEST:  
                        	io_send(MANDATORY_FSTAT|IO_SYNC, 
					(ulong)" HOLD ", NOARG, NOARG);
				break;

    			case BIN_TEST:   
    				sprintf(tbl->i_msgq.string, "%c%c HOLD ", 
        				MANDATORY_FSTAT, tbl->i_local_pid);
    				bin_send(SYNCHRONIZE);
			        break;

    			case USER_TEST:  
    				sprintf(tbl->i_msgq.string, "%c%c HOLD ", 
        				MANDATORY_FSTAT, tbl->i_local_pid);
    				sh_send(SYNCHRONIZE);
				break;
			}
        	}                                                       
        	sleep(1);                                               
        	SEND_HEARTBEAT(ID);                                     
	}
}
