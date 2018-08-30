/*  Author: David Anderson <anderson@redhat.com> */

/*
 *  defs.h: is the master definition header file that is used by all of the
 *          USEX modules.
 *
 *  BitKeeper ID: @(#)defs.h 1.7
 *
 *  CVS: $Revision: 1.45 $ $Date: 2016/02/10 19:25:51 $
 */

#define USEX_VERSION  "1.9-38" 
#define COMPANY_NAME  "Red Hat, Inc."

#ifndef linux
#define TEST_AND_SET 1
#endif

#include <stdio.h>             /* A few system header files. */
#include <stdlib.h>
#include <unistd.h>
#include <term.h>
#include <curses.h>
#include <signal.h>
#ifndef MAXSIG
#define MAXSIG NSIG
#endif
#include <errno.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <setjmp.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/sem.h>
#include <sys/msg.h>
#undef MIN
#undef MAX
#include <sys/param.h>
#include <sys/socket.h>
#include <dirent.h>
#include <time.h>
#include <sys/time.h>
#include <sys/utsname.h>
#include <sys/mman.h>
#include <fstab.h>
#include <string.h>
#ifdef TEST_AND_SET
#include <sys/lock.h>
#endif
#include <sys/wait.h>
#ifdef linux
#include <linux/kernel.h>
//#include <linux/sys.h>
#endif


#undef TRUE
#define TRUE  (1)
#undef FALSE
#define FALSE (0)

#ifdef TEST_AND_SET
#define LOCK(X) (test_and_set_l(0, X))
#undef UNLOCK
#define UNLOCK(X) (*(X) = 0)
#else
#define LOCK(X)   (TRUE)
#undef UNLOCK
#define UNLOCK(X)
#endif

#define MAXLINES      (60)
#define COLS          (80)

#define NON_IO_LINES     (12)
#define MIN_IO_LINES     (12)
#define MIN_TEST_LINES   (MIN_IO_LINES + NON_IO_LINES)

#ifndef linux
extern char *sys_errlist[];
#endif

#define BOOL      unsigned int

#define BIT0      0x000001
#define BIT1      0x000002
#define BIT2      0x000004
#define BIT3      0x000008
#define BIT4      0x000010
#define BIT5      0x000020
#define BIT6      0x000040
#define BIT7      0x000080
#define BIT8      0x000100
#define BIT9      0x000200
#define BIT10     0x000400
#define BIT11     0x000800
#define BIT12     0x001000
#define BIT13     0x002000
#define BIT14     0x004000
#define BIT15     0x008000
#define BIT16     0x010000
#define BIT17     0x020000
#define BIT18     0x040000
#define BIT19     0x080000
#define BIT20     0x100000
#define BIT21     0x200000
#define BIT22     0x400000
#define BIT23     0x800000
#define BIT24    0x1000000
#define BIT25    0x2000000
#define BIT26    0x4000000
#define BIT27    0x8000000
#define BIT28   0x10000000
#define BIT29   0x20000000
#define BIT30   0x40000000
#define BIT31   0x80000000
#define BIT32  0x100000000ULL
#define BIT33  0x200000000ULL
#define BIT34  0x400000000ULL
#define BIT35  0x800000000ULL
#define BIT36 0x1000000000ULL
#define BIT37 0x2000000000ULL
#define BIT38 0x4000000000ULL
#define BIT39 0x8000000000ULL
#define BIT40 0x10000000000ULL

#define GIGABYTE (1024*1024*1024)
#define MEGABYTE (1024*1024)
#define KILOBYTE (1024)

#define NEW_LINE  (!Shm->infile ? Shm->printf("\n") : Shm->printf(""))  
#define PROMPT  if (!Shm->infile) Shm->printf
#define STRINGSIZE   100            /* Typical string size plus overflow     */
#define FATAL_STRINGSIZE 256        /* Overkill for perror, stderr usage     */
#define FGETSTRING(x) fline++; if (fgets((char *)x, (int)STRINGSIZE, (FILE *)fi) == (char *)NULL)  \
    goto prompt_bailout; \
else \
    x[strlen(x)-1] = (char)NULLCHAR;

//#define streq(X,Y)  ((X) && (Y) && (strcmp(X,Y) == 0))
//#define strneq(X,Y) ((X) && (Y) && (strncmp(X,Y,strlen(Y)) == 0))

static inline int string_exists(char *s) { return (s ? TRUE : FALSE); }
#define streq(A, B)      (string_exists((char *)A) && string_exists((char *)B) && \
        (strcmp((char *)(A), (char *)(B)) == 0))
#define strneq(A, B)     (string_exists((char *)A) && string_exists((char *)B) && \
        (strncmp((char *)(A), (char *)(B), strlen((char *)(B))) == 0))

#define MAX_IO_TESTS  (48)          /* Maximum number of I/O tests.          */
#define PATHSIZE     80             /* Maximum pathname size.                */
#define MAX_PATHNAME 60             /* Maximum io_test pathname size.        */
#undef MAX_INPUT
#define MAX_INPUT    70             /* Maximum interactive input line.       */
#ifdef INVALID
#undef INVALID
#define INVALID      (-1)           /* Generic invalid flag                  */
#else
#define INVALID      (-1)           /* Generic invalid flag                  */
#endif
#define NOT_RUNNING  (-1)           /* Generic "process not running" flag.   */
#define TOO_LARGE    (-2)           /* Buffer size too large.                */
#define FIRST_ID     'A'            /* Local pid format.                     */ 
#define END_OF_DISK  ((int)0)       /* Used if no block limit is imposed.    */
#define ONE_MINUTE   (60)           /* Sixty seconds.                        */
#define FIVE_SECONDS (5)            /* Five seconds.                         */
#define FIVE_MINUTES (5 * 60)       /* Five minutes.                         */
#define ONE_SECOND   (1)            /* One second.                           */
#define TEN_SECONDS  (10)           /* Ten seconds.                          */
#define EVER         ;keep_alive(); /* as in: for (EVER)                     */
#define UNTIL_KILLED 0x7fffffff     /* About a 68 year time out value.       */
#define IO_ERROR     (-1)           /* UNIX file calls return -1 on error.   */
#define WAIT_HERE    ;              /* For do-nothing loops.                 */
#define COMPARE_OK   (-1)           /* Otherwise compare returns offset.     */
#define MAX_ARGV     50

#define MESSAGE_SIZE  160           /* Max size of inter-process messages.   */
#define ERRMSG_SIZE   58            /* Max error message size on test line.  */
#define KILL          'k'           /* User input for kill command.          */
#define HOLD          'h'           /* User input for hold or help command.  */
#define HELP          'H'           /* Translation for help command.         */
#define BACKGROUND    'b'           /* User input for background command.    */
#define CONTINUE      ' '           /* Replacement for <RETURN> input.       */
#define INQUIRY       'i'           /* Generic data inquiry command.         */
#define FULL_INQUIRY  'I'           /* Verbose data inquiry command.         */
#define LAST_MESSAGE  'm'           /* Last message inquiry command.         */

#define INITIALIZED     0           /* Flag initializer.                     */

/* Bit defines used by both processes    */
/* and possibly the window manager.      */
/* Because of their dual usage, they all */
/* must be distinct from one another.    */
 
#define IO_DEAD           BIT0  /*  000001 */
#define RATE_START        BIT1  /*  000002 */
#define RATE_TBD          BIT2  /*  000004 */
#define IO_BKGD           BIT3  /*  000008 */
#define IO_TRUN           BIT4  /*  000010 */
#define RATE_WRITE        IO_TRUN
#define IO_FILL           BIT5  /*  000020 */
#define IO_DYING          BIT6  /*  000040 */
#define SENDING           BIT7  /*  000080 */
#define WAKE_ME           BIT8  /*  000100 */
#define HANG              BIT9  /*  000200 */
#define IO_LOOKUP         BIT10 /*  000400 */
#define RATE_OVFLOW       IO_LOOKUP
#define IO_PIPE           BIT11 /*  000800 */
#define RATE_NOTIME       IO_PIPE
#define IO_ADMIN1         BIT12 /*  001000 */
#define IO_SPECIAL        BIT13 /*  002000 */
#define IO_FORK           BIT14 /*  004000 */
#define IO_CHILD_RUN      BIT15 /*  008000 */
#define IO_WAIT           BIT16 /*  010000 */
#define IO_ADMIN2         BIT17 /*  020000 */
#define RING_OUT_OF_SYNC  BIT18 /*  040000 */
#define IO_HOLD_PENDING   BIT19 /*  080000 */
#define EXPLICIT_KILL     BIT20 /*  100000 */
#define IO_HOLD           BIT21 /*  200000 */
#define IO_NOLOG          BIT22 /*  400000 */
#define WAKE_UP           BIT23 /*  800000 */
#define IO_BURIED         BIT24 /* 1000000 */
#define IO_SUICIDE        BIT25 /* 2000000 */
#define IO_FSYNC          BIT26 /* 4000000 */
#define BIN_SYNC          IO_FSYNC
#define IO_START          BIT27 /* 8000000 */
#define IO_NOTRUNC        BIT28 /* 10000000 */
#define RATE_CREATE       BIT29 /* 20000000 */
#define USER_ERROR        BIT30 /* 40000000 */
#define IO_SYNC           BIT31 /* 80000000 - can be or'd with char command */

#define DISK_TEST       BIT1        /* Test type definitions for the */
#define WHET_TEST       BIT2        /* PROC_TABLE test_type field. */
#define DHRY_TEST       BIT3
#define NULL_TEST       BIT4
#define USER_TEST       BIT5
#define VMEM_TEST       BIT6
#define BIN_TEST        BIT7
#define DEBUG_TEST      BIT8
#define RATE_TEST       BIT9

#define FROM_BEGINNING   SEEK_SET
#define FROM_CURRENT_POS SEEK_CUR         
#define FILE_PTR(fd) (tbl->file_ptr = lseek(fd, 0L, FROM_CURRENT_POS))    

#define NOARG        (0)
#define BIG_BUFFER   (1)      /* Arguments io_test() sends to send()   */
#define OPEN_ERROR   (2)      /* for displaying status/error messages. */ 
#define ALLOC_ERROR  (3)
#define _OK_         (4)
#define DEAD         (5)
#define EOFS         (6)
#define WRITE_ERROR  (7)
#define READ_ERROR   (8)
#define EOP          (9)
#define IOCTL_ERROR  (10)
#define CLOSE_ERROR  (11)
#define FATAL_ERROR  (14)
#define BUS_ERROR    (15)
#define IPC_ERROR    (16)
#define _BKGD_       (17)
#define FD_SANITY    (18)
#define WARN         (19)

#define INCOMPLETE_WRITE (1000)    /* differentiate from io_test write errno */

#define FILE_EXISTS  ((int)19)

#define IGNORE_NONZERO_EXIT ((int)20)

#ifdef roundup
#undef roundup
#endif
#define roundup(x, y)  ((((x)+((y)-1))/(y))*(y))

#define _64K_        65535            /* Transfer rate test buffer size.      */
#define TEN_MEGABYTE ((int)10485760)  /* Transfer rate test value.          */

#define NUMSG        (MAX_IO_TESTS)   /* Number of individual message queues. */

#define SHUTDOWN  (NOARG)   /* argument to common_kill() signfying shutdown. */

#define DISPLAY(window)  if (!(Shm->mode & DEBUG_MODE)) wrefresh(window)

/* These constants are the "commands" for the window manager.  They are used  */
/* by all test processes to indicate their state to the window manager, which */
/* then updates the screen accordingly.                                       */

#define FCOMPARE         'a'
#define FREAD_           'b'
#define FWRITE_          'c'
#define FSEEK            'd'
#define FOPEN_           'e'
#define FCLOSE           'f'
#define FDELETE          'g'
#define FFILL            'h'
#define FTRUN            'i'
#define FPOINTER         'j'
#define FPASS            'k'
#define FSTAT            'l'
#define BIN_TEST_MOD     'm'
#define UNUSED_CMD1      'n'
#define UNUSED_CMD2      'o'
#define UNUSED_CMD3      'p'
#define UNUSED_CMD4      'q'
#define LOAD_AVG         'r'
#define UNUSED_CMD5      's'
#define UNUSED_CMD6      't'
#define MANDATORY_CANNED 'u'
#define FERROR           'v'
#define COMPARE_ERR      'w'
#define USER_INPUT       'x'
#define REFRESH          'y'
#define STOP_USEX        'z'
#define DEBUG            'A'
#define FIOCTL           'B'
#define FSLEEP           'C'
#define FMODE            'D'
#define FILENAME         'E'
#define FSIZE            'F'
#define FCLEAR           'G'
#define FWAIT            'H'     
#define FMALLOC          'I'
#define FSHELL           'J'
#define FSBRK            'K'
#define FOPERATION       'L'
#define LAST_IOTEST_CMD  'L'
#define BUILD_INFO       'M'
#define UNUSED_CMD7      'N'
#define UNAME_INFO       'O'
#define CANNED           'P'
#define KEEP_ALIVE       'Q'
#define LOAD_AVERAGE     'R'

#define IO_TEST(x)  ((x >= FCOMPARE && x <= FSTAT) || \
                    (x >= FIOCTL && x <= LAST_IOTEST_CMD) || \
		    (x >= CANNED && x <= KEEP_ALIVE))

#define SYNCHRONIZE      'S'
#define DUMP_STATUS_FILE 'T'
#define MANDATORY_FSTAT  'U'
#define MANDATORY_FSHELL 'V'
#define MANDATORY_FMODE  'W'

typedef unsigned char uchar;
#define WINDOW_MGR_CMD(X) ((((uchar)(X) >= 'a') && ((uchar)(X) <= 'z')) || \
                           (((uchar)(X) >= 'A') && ((uchar)(X) <= 'Z')))

#define BKGD_POST  '@'

#define IGNORE_MESSAGE  (1)
#define POST_MESSAGE    (2)
#define RETRY_QUEUE     (3)

/* Debug message consists of two parts -- the command in the lower 4 bits,
 * and the duration (in seconds) of the display in the remaining bits.  
 * When the commands exceed 15, bump up the shift value.
 */
#define DURATION_SHIFT     (4)
#define DMESG_MASK       (0xf)

#define DMESG_CLEAR      (1)
#define DMESG_STAT       (2)
#define DMESG_MEMINFO    (3)
#define DMESG_IMMEDIATE  (4)
#define DMESG_QUEUE      (5)
#define DMESG_CONSOLE    (6)

#define DMESG_URGENT(c) (((c) == DMESG_CLEAR)      ||  \
		         ((c) == DMESG_STAT)       ||  \
			 ((c) == DMESG_IMMEDIATE))

#define DEBUG_MESSAGE_CLEAR(s)       (DMESG_CLEAR     | ((s) << DURATION_SHIFT))
#define DEBUG_MESSAGE_STAT(s)        (DMESG_STAT      | ((s) << DURATION_SHIFT))
#define DEBUG_MESSAGE_MEMINFO(s)     (DMESG_MEMINFO   | ((s) << DURATION_SHIFT))
#define DEBUG_MESSAGE_IMMEDIATE(s)   (DMESG_IMMEDIATE | ((s) << DURATION_SHIFT))
#define DEBUG_MESSAGE_QUEUE(s)       (DMESG_QUEUE     | ((s) << DURATION_SHIFT))
#define DEBUG_MESSAGE_CONSOLE(s)     (DMESG_CONSOLE   | ((s) << DURATION_SHIFT))

#define USER_MESSAGE(s) debug_message(DEBUG_MESSAGE_IMMEDIATE(1), (long)(s))
#define CLEAR_MESSAGE() debug_message(DEBUG_MESSAGE_CLEAR(1), 0)
#ifdef _CURSES_
#define USER_MESSAGE_WAIT(s) \
	debug_message(DEBUG_MESSAGE_IMMEDIATE(1), (long)(s))
#endif
#ifdef _GTK_
#define USER_MESSAGE_WAIT(s) gtk_mgr_status_bar_message_wait(s)
#endif

#define USER_PROMPT(s)      prompt_message(s, FALSE)
#define USER_PROMPT_END(s)  prompt_message(s, TRUE)
#define CLEAR_PROMPT()      prompt_message(NULL, TRUE)

#define NULLCHAR         ('\0')
#define CLEAR_STRING(s)  (s[0] = NULLCHAR)
#define FIRSTCHAR(s)     (s[0])
#define LASTCHAR(s)      (s[strlen(s)-1])

#define LOG_START        ((char)(1+' '))
#define LOG_END          ((char)(2+' '))
#define LOG_MESSAGE      ((char)(3+' '))
#define LOG_IO_PASS      ((char)(4+' '))

struct timer_callback {
	uint time;
	uint seq;
	int active;
	void (*func)(ulong, ulong);
	ulong arg1;
	ulong arg2;
};
#define TIMER_CALLBACKS (20)

struct timer_request {
	ulong requests;
	uint sequence;
	char sys_time[STRINGSIZE];
	char sys_date[STRINGSIZE];
	char run_time[STRINGSIZE];
	struct timer_callback callbacks[TIMER_CALLBACKS];
};

#define TIMER_REQ_STOP_USEX    0x1     /* timer requests to window manager */
#define TIMER_REQ_REFRESH      0x2
#define TIMER_REQ_LOAD_AVG     0x4
#define TIMER_REQ_FREE_MEM     0x8
#define TIMER_REQ_CALLBACK    0x10
#define TIMER_REQ_FAILED      0x20
#define TIMER_REQ_CPU_STATS   0x40

#define _ACTION       0       /* Offsets from the beginning */
#define _SIZE         4       /* of each IO Test window.    */
#define _MODE        11
#define _POINTER     17
#define _OPERATION   28
#define _FILENAME    39
#define _PASS        64
#define _STAT        69

#define DEBUG_MODE      BIT0      /* Bit defines for shmem mode flag. */
#define BKGD_MODE       BIT1
#define AT_KLUDGE       BIT2
#define NO_REFRESH_MODE BIT3
#define CHILD_HOLD      BIT4
#define SAVE_DEFAULT    BIT5
#define AUTO_INFILE     BIT6
#define CINIT           BIT7
#define PIPE_MODE       BIT8
#define MESGQ_MODE      BIT9
#define SHMEM_MODE      BIT10
#define MMAP_MODE       BIT11
#define IPC_MODE        (PIPE_MODE|MESGQ_MODE|SHMEM_MODE|MMAP_MODE)
#define WINUPDATE       BIT12
#define QUIET_MODE	BIT13
#define IGNORE_BIN_EXIT BIT14
#define MLOCK_MODE      BIT15
#define NO_STATS        BIT16
#define SCREEN_SAVED    BIT17
#define SYNC_BIN_TESTS  BIT18
#define BAD_INPUT_FILE  BIT19
#define SHUTDOWN_MODE   BIT20
#define CTRL_C          BIT21
#define BIN_INIT        BIT22
#define NOTTY           BIT23
#define CONS_PENDING    BIT24
#define CONS_INIT       BIT25
#define NODISPLAY       BIT26
#define DROPCORE        BIT27
#define MMAP_DZERO      BIT28
#define MMAP_ANON       BIT29
#define MMAP_FILE       BIT30
#define RCHOME          BIT31
#define RCLOCAL         BIT32
#define MORE            BIT34
#define LESS            BIT35
#define GTK_MODE        BIT36
#define CURSES_MODE     BIT37
#define GINIT           BIT38
#define SYS_STATS       BIT39
#define RHTS_HANG_TRACE BIT40

#define CTRL_C_ENTERED()  (Shm->mode & CTRL_C)
#define NO_DISPLAY()      (Shm->mode & NODISPLAY)
#define GTK_DISPLAY()     (Shm->mode & GTK_MODE)
#define CURSES_DISPLAY()  (Shm->mode & CURSES_MODE)

#define ID_TO_PIPE     (1 + (ID * 2)) 
#define TESTNUM(x) (((x)->i_local_pid - FIRST_ID) + 1)

#define SPECIAL_FILE(x) (((x & S_IFMT) == S_IFCHR) || ((x & S_IFMT) == S_IFBLK))
#define EXEMPT S_IFCHR    /* make builtin tests act like raw devices */

#define KILL_ALL  (-1)

#define NOT_USED    (-1)

#define INTERNAL    0     /* for bin_cleanup() file removal procedure */
#define EXTERNAL    1

#define QUERY  1          /* for -c or -C to query for removal or not */

#define NUMBER_ARG  (NOARG+1)   /* fdebug args to go along with NOARG */
#define STRING_ARG  (NOARG+2) 

#define K_OTHER  0      /* Kill codes (debug) */
#define K_IO(x)  (x+1)

#define I_RINGBUFSIZE  (512) 
#define T_RINGBUFSIZE  (64) 
#define X_RINGBUFSIZE  (256) 
#define RING_IO(x)  (x)          /* 0 through 47 - just uses IO test ID */

/* 
 * exit codes
 */
#define NORMAL_EXIT         0
#define MALLOC_ERROR       21
#define QUICK_DIE          22
#define SH_KILL_SHELL      23
#define MOM_IS_DEAD        24
#define INVAL_DEBUG_TEST   25
#define BIN_MGR_K          26
#define BIN_TIME_TO_DIE_1  27
#define BIN_TIME_TO_DIE_2  28
#define BIN_TIME_TO_DIE_3  29
#define BIN_KILL_CHILD     30
#define BIN_BAILOUT        31
#define KILL_EXIT          32
#define FATAL_EXIT         33
#define PARALYZE_EXIT      34
#define SHELL_MGR_FAILED   35
#define BIN_MGR_FAILED     36
#define IO_TEST_FAILED     37
#define SHMGET_ERROR       38
#define SHMAT_ERROR        39
#define INITSCR_ERROR      40
#define START_SHELL_EXIT   41
#define USEX_KILL_POPEN    42
#define RHTS_BAD_ARG       43

#define MAX_PIPELINE_READ  4096   /* bin_mgr and shell_mgr requirements */
#define PIPELINE_PAD       16
#define USEX_FORK_FAILURE  1
#define CMD_FORK_FAILURE   2



typedef struct {                /* usex message queue definition. */
  int type;
  char string[MESSAGE_SIZE]; 
} U_MSGQ;

#define X_POSTAGE     (10)
#define T_POSTAGE     (10)
#define I_POSTAGE     (30)

#define TIME_SIZE     (12)  

#define POST_IO(x)  (FIRST_ID + x)

#define ALL_MESSAGES     (NUMSG+1)   /* args to last_message_query() */
#define FATAL_MESSAGES   (NUMSG+2)

#define BY_DEATH  1
#define BY_EXIT   2
#define BY_SIGNAL 3
#define BY_STOP   4

#define DIE(X)  (X)
#define QDIE(X) (-(X))

#define LOCKSTATS 1
#ifdef LOCKSTATS
struct lockstats {
    unsigned long first_write_hits;
    unsigned long max_write_spins;
    unsigned long total_write_locks;
    unsigned long first_read_hits;
    unsigned long max_read_spins;
    unsigned long total_read_locks;
};
#endif

struct ps_list {
        char ps_line[MESSAGE_SIZE];
        struct ps_list *next;
}; 

#define PS_LIST_INIT   (1)
#define PS_LIST_READ   (2)
#define PS_LIST_VERIFY (3)

#define MAX_CHAR_PATTERNS (256) /* maximum unique patterns per 8-bit char */
#define MAX_PATTERN_WORDS (MAX_CHAR_PATTERNS/sizeof(int))

struct io_test_specific {
	long long block_limit;
	int iofd;
	ulong file_ptr;
        char display[STRINGSIZE];
	unsigned char byte_read; 
	unsigned char byte_written;
	long buffer_offset;
};
#define iofd           i_u.io_test.iofd
#define block_limit    i_u.io_test.block_limit
#define display        i_u.io_test.display
#define byte_read      i_u.io_test.byte_read
#define byte_written   i_u.io_test.byte_written
#define buffer_offset  i_u.io_test.buffer_offset
#define file_ptr       i_u.io_test.file_ptr
 
struct vmem_specific {
	ulong pass_divisor;
	char vmem_buffer[MESSAGE_SIZE];	
        char vmembuf[STRINGSIZE];
        char vmem_errbuf[STRINGSIZE];
        unsigned long datasize;
        double datacount;
        unsigned long pages;
        int access_mode;
	void *dance_widget;
};
#define vmem_buffer      i_u.vmem.vmem_buffer
#define vmembuf          i_u.vmem.vmembuf
#define vmem_errbuf      i_u.vmem.vmem_errbuf
#define pass_divisor     i_u.vmem.pass_divisor
#define datasize         i_u.vmem.datasize
#define datacount        i_u.vmem.datacount
#define pages            i_u.vmem.pages
#define access_mode      i_u.vmem.access_mode
#define dance_widget     i_u.vmem.dance_widget

#define RANDOM      1
#define SEQUENTIAL  2
 
#define DHRYSTONE_BUFSIZE (512)
struct dry_specific {
	int machine_HZ;
	ulong dhrystones;
	char dry_buffer[DHRYSTONE_BUFSIZE];	
        ulong zero_benchtime;
};

#define machine_HZ   i_u.dry.machine_HZ
#define dry_buffer   i_u.dry.dry_buffer
#define dhrystones   i_u.dry.dhrystones
#define zero_benchtime  i_u.dry.zero_benchtime
 
#define WHETSTONE_BUFSIZE (1300)
struct float_specific {
	char whetbuf[WHETSTONE_BUFSIZE];
	double whet_mwips;
};
#define whetbuf      i_u._float.whetbuf
#define whet_mwips   i_u._float.whet_mwips
 
struct bin_commands {
    	char *cmd;
    	unsigned long long cmdflags;
    	char *cmdpath;
    	char *cleanup;
};

struct bin_test_mod {
	struct bin_commands *bp;
	ulong cmdflag;
	struct bin_test_mod *next;
};

struct bin_specific  {
	int time_to_die;
	int bin_child;
        int max_cmds;
	int cmds_found;
	int cmds_per_pass;
	int cmd_cnt;
	int *bin_order;
	int cur_order;
	int not_found;
	int excluded;
	int exclusive;
	ulong max_pass;
	ulong bin_flags;
	struct bin_commands *cur_bp;
	struct bin_commands null_cmd;
	struct bin_commands *BP;
	struct bin_test_mod test_mod;
	struct bin_test_mod *test_mod_list;
	char curcmd[MESSAGE_SIZE];
	char tmp_file[MESSAGE_SIZE];
	char tmp_file_2[MESSAGE_SIZE];
	char tmp_C_file[MESSAGE_SIZE];
	char tmp_default[MESSAGE_SIZE];
	char tmp_concat[MESSAGE_SIZE*2];
};

#define time_to_die   i_u.bin.time_to_die
#define bin_child     i_u.bin.bin_child
#define max_cmds      i_u.bin.max_cmds
#define cmds_found    i_u.bin.cmds_found
#define cmds_per_pass i_u.bin.cmds_per_pass
#define cmd_cnt       i_u.bin.cmd_cnt
#define max_pass      i_u.bin.max_pass
#define not_found     i_u.bin.not_found
#define excluded      i_u.bin.excluded
#define exclusive     i_u.bin.exclusive
#define bin_flags     i_u.bin.bin_flags
#define bin_order     i_u.bin.bin_order
#define cur_order     i_u.bin.cur_order
#define cur_bp        i_u.bin.cur_bp
#define null_cmd      i_u.bin.null_cmd
#define BP            i_u.bin.BP
#define curcmd        i_u.bin.curcmd
#define test_mod      i_u.bin.test_mod
#define test_mod_list i_u.bin.test_mod_list
#define tmp_file      i_u.bin.tmp_file
#define tmp_file_2    i_u.bin.tmp_file_2 
#define tmp_C_file    i_u.bin.tmp_C_file
#define tmp_concat    i_u.bin.tmp_concat
#define tmp_default   i_u.bin.tmp_default

struct shell_specific {
	int shell_child;
};
#define shell_child     i_u.shell.shell_child

struct rate_specific {
        int rfd;
        char r_display[STRINGSIZE];
        ulong r_file_ptr;
	ulong r_cur;
	ulong r_count;
	uint r_percent;
	uint r_last_percent;
        double r_mean;         /* Overall mean for all runs.  */
        double r_last;         /* Last result.                */
        double r_high;         /* Highest result to date.     */
        double r_low;          /* Lowest result to date.      */
    	time_t r_timestamp;
};
#define rfd             i_u.rate.rfd
#define r_file_ptr      i_u.rate.r_file_ptr
#define r_cur           i_u.rate.r_cur
#define r_count         i_u.rate.r_count
#define r_display       i_u.rate.r_display
#define r_percent       i_u.rate.r_percent
#define r_mean          i_u.rate.r_mean
#define r_last          i_u.rate.r_last
#define r_high          i_u.rate.r_high
#define r_low           i_u.rate.r_low
#define r_timestamp     i_u.rate.r_timestamp
#define r_last_percent  i_u.rate.r_last_percent

struct debug_specific {
	int unused;
};

 
union test_specific {
	struct float_specific _float;
	struct bin_specific bin;
	struct shell_specific shell;
	struct debug_specific debug;
	struct dry_specific dry;
	struct vmem_specific vmem;
	struct io_test_specific io_test;
	struct rate_specific rate;
};

typedef struct
{
        unsigned int i_pid;             /* PID of the child process.         */ 
        char i_local_pid;               /* Local ID for I/O tests.           */
        unsigned int i_stat;            /* The window manager status keeper. */
        unsigned int i_type;            /* Type of I/O test.                 */
        int i_msg_id;                   /* Message ID used by test.          */
        U_MSGQ i_msgq;                  /* This test's message queue.        */
        size_t i_size;                  /* Buffer size of file to tested.    */ 
        ulong i_limit;                  /* Maximum size of file to tested.   */ 
        char i_file[STRINGSIZE];        /* Full test filename.               */
        char i_errfile[STRINGSIZE];     /* Error file name.                  */
        char i_path[PATHSIZE];          /* Pathname entered during prompt(). */
	char i_time_of_death[STRINGSIZE];  /* Time of death obviously.       */
	int i_signal_received;          /* externally generated signal       */
	int i_exit_status;
	int i_abnormal_death;           /* errdeamon discovery.              */
	int i_demise;                   /* see BY_* defines above.           */
	int i_cstat;                    /* bin or shell command cstat        */ 
	char *i_internal_kill_source;   /* source of internal kill signal.   */
        char *i_killorg;                /* source of fatal Kill()            */
	int i_post;     		/* Index of stored messages.         */
	char i_last_message[I_POSTAGE][STRINGSIZE]; /* Last messages posted. */
	time_t i_last_msgtime[I_POSTAGE]; /* Time they were posted. */
	time_t i_canned_msg_time;       /* Last canned message time.         */
	time_t i_last_heartbeat;        /* Last heartbeat time.              */
        struct stat i_sbuf;             /* Storage for stat() call.          */
        char *i_read_buf;               /* Holder for IO test read           */
        char *i_write_buf;              /* and write buffers.                */
        unsigned long i_pass;           /* Current pass count.               */
	unsigned long i_fsize;          /* File size at last pass completion */
	int i_saved_errno;              /* Used however the test wants.      */
        int i_message;                  /* Message from mod to children.     */
	volatile int i_rptr;            /* Ring buffer read offset.          */
	volatile int i_wptr;            /* Ring buffer write offset.         */
	unsigned i_blkcnt;		/* Times spent sleeping on ring.     */
	unsigned int i_lock;
	union test_specific i_u;        /* test-specific structures */
        time_t i_timestamp;
        char i_rbuf[I_RINGBUFSIZE];
        char i_fatal_errmsg[FATAL_STRINGSIZE];
} PROC_TABLE;

typedef struct
{
     struct                /* Windows for each test line. */
     {
        WINDOW *action;
     } P[MAX_IO_TESTS];  
                    
     WINDOW *Date;         /* The rest of the windows. */
     WINDOW *Stime;
     WINDOW *Test_Time;
     WINDOW *Cpu_Stats;
     WINDOW *Page_Stats;
     WINDOW *Help_Window;
     WINDOW *Debug_Window;
     WINDOW *Prompt_Window;
} WINDOW_TABLE;


struct shm_buf
{
    long long mode;
    struct shm_buf *shm_tmp;
    key_t shmid;
    char *shm_addr;
    int mmfd;
    int max_tests;
    char *TERM;
    int term_LINES;              /* The actual number of terminal lines */
    int term_COLS;               /* The actual number of terminal columns */
    int lines_used;              /* Lines used based upon user test requests */
    int shm_size;
    int parent_shell;
    int die_caller;
    int hanging_tcnt;
    PROC_TABLE ptbl[MAX_IO_TESTS];
    char mom[MESSAGE_SIZE]; 
    char input[MESSAGE_SIZE]; 
    U_MSGQ u_msgq;
    int msgid[NUMSG];
    int win_pipe[NUMSG * 2];
    int wake_me[NUMSG];
    volatile int being_read[NUMSG];
    volatile int being_written[NUMSG];
    long long heartbeat;          
#define SEND_HEARTBEAT(id)   Shm->heartbeat |= ((long long)1 << (id))
#define CLEAR_HEARTBEAT(id)  Shm->heartbeat &= ~((long long)1 << (id))
    int procno;
#define DEFAULT_HANGTIME  (60*10)  /* 10 minutes quiescent time allowed. */
    uint hangtime;
#define UNSET_STALLVALUE (0xdeadbeef)
#define DEFAULT_STALLVALUE (250000)
#define MAX_STALLVALUE (1000000-1)
    ulong stallcnt;
    ulong stallvalue;
    int bin_sync_delay;
    int bin_cmds_found;
#define WINDOW_MGR() (Shm->mompid == getpid())
    int mompid;
    int confd;
    char *infile;
    char *outfile;
    char *pattern;
    int bad_fline;
    int niceval;
    int time_to_kill;
    int vmem_size;           
    char *vmem_access;
    int ioflags;
    char *transfer_rate_option;   /* to control -e xfer rate test device */
    int statnum;
    int directories_found;
    char screen_buf[MAXLINES][COLS];
    char default_file[STRINGSIZE]; /* Default output file name storage. */
    char console_device[STRINGSIZE];
    char tmpdir[STRINGSIZE];
    char id_file[STRINGSIZE];
    char ux_IO[STRINGSIZE];           /* Storage of disk I/O test file names. */
    char saved_error_msg[STRINGSIZE*2];
    char ext_terminal[STRINGSIZE];
    char *logfile;
    char *reportfile;
    char *origdir;
    struct utsname utsname;
    int prompt_x;
    int debug_message_inuse;
    char prompt[MESSAGE_SIZE];
    char unresolved[MESSAGE_SIZE*2];
    struct timer_request timer_request; 
#ifdef LOCKSTATS
    struct lockstats lockstats[NUMSG];
#endif
    FILE *opipe;
    struct ps_list *ps_list;
    int (*window_manager)(int, char **);  /* display window manager          */
    void (*printf)(char *fmt, ...);       /* printf() message handler        */
    void (*stderr)(char *fmt, ...);       /* fprintf(stderr) message handler */
    void (*perror)(char *);               /* perror() message handler        */
    void (*win_specific)(char *);         /* window specific function        */
    struct window_manager_data *wmd;      /* window manager specific struct  */
    void (*dump_win_mgr_data)(FILE *);    /* dump window manager data        */
};

#ifdef linux
static inline void sigset(int sig,void *func)
{
	struct sigaction sa;

	bzero(&sa, sizeof(struct sigaction));

	sa.sa_handler = func;
	sigaction(sig,&sa,0);
}
#ifdef innwstr
#undef innwstr
#endif
#define innwstr innstr
#endif


/*
 *  usex.c
 */
struct shm_buf *Shm;
extern int ID;

#define SEPARATOR "--------------------------------------------------------------------------------\n"

void log_entry(unsigned long, unsigned long, unsigned long, void *);
#define LOG  if (Shm->logfile) log_entry
void log_death(int);
void die(int, int, int); 
void quick_die(int);
void usex_inquiry(FILE *);
void process_list(int, FILE *);

/*
 *  gtk_mgr.c
 */
int gtk_mgr_main(int, char **);
void gtk_mgr_perror(char *);
void gtk_mgr_printf(char *fmt, ...);
void gtk_mgr_stderr(char *fmt, ...);
void dump_gtk_mgr_data(FILE *);
void gtk_mgr_status_bar_message(char *);
void gtk_mgr_status_bar_message_wait(char *);
void *gtk_mgr_test_widget(int, unsigned char, char *);
void gtk_mgr_test_background(int);
void gtk_mgr_test_foreground(int);
void gtk_mgr_display_external(FILE *, char *);
void gtk_mgr_specific(char *);
void gtk_mgr_vmem_dance(int, int);
void gtk_mgr_shutdown(void);

/*      
 *  window_manager.c  
 */     
void window_manager_init(int *, char ***);

/*
 *  utils.c
 */

char *test_type(int);
char *filename(char *);
int compare_ints(const void *, const void *);
char *strip_lf(char *);
char *strip_ending_spaces(char *);
char *strip_beginning_whitespace(char *);
char *strip_beginning_chars(char *, char);
char *strip_ending_chars(char *, char);
void space_pad(char *, int);
void char_pad(char *, char *, int);
int keep_alive(void);
char *filename(char *);
char *dec_node(char *, char *);
int get_usex_message(int, char *);
int pipe_read(int, char *);
int pipe_write(int, char *, int);
char *format_time_string(char *, char *);
int what_is(char *, struct stat *);
int file_exists(char *);
nlink_t file_nlinks(char *);
int is_directory(char *);
int file_copy(char *, char *);
ulong file_size(int);
void fillbuf(char *, int, char);
int atoh(char *);
int count_bits_long(long);
void file_cleanup(void);
int delete_file(char *, int);
int parse(char *, char **);
int mother_is_dead(int, char *);
int Kill(int, int, char *, int);
void set_Kill_source(uint, int, char *);
int chk_leftovers(int);
void ring_init(void);
void block(int);
void shm_write(int, char *, int);
int shm_read(int, char *);
int min(int, int);
ulong ulmin(ulong, ulong);
void fatal(int, char *, int);
void paralyze(int, char *, int);
int get_swap_file(char *);
ulong get_free_memory(void);
int compare_ints(const void *, const void *);
void console_init(int);
void console(char *fmt, ...);
int decimal(char *, int);
char *adjust_size(size_t, int, char *, int);
FILE *open_output_pipe(void);
void close_output_pipe(void);
void synchronize(int, char *);
uint get_i_stat(PROC_TABLE *);
void stall(ulong);
char *ordinal(int, char *);
char *shift_string_left(char *, int, char *);
char *shift_string_right(char *, int, char *);
char *mkstring(char *, int, ulong);
int is_mount_point(int, char *, int, char *);
#define CENTER (0x1)
#define LJUST  (0x2)
#define RJUST  (0x4)
#define TRUNC  (0x8)
void set_heartbeat(int);
void clear_heartbeat(int);
char *get_token(char *, char *, int, int *);
void put_test_on_hold(PROC_TABLE *, int);
int delete_matching_files(char *, int);
void drop_core(char *);
#ifdef LOCKSTATS
void dump_ring_stats(void);
#endif

/*
 *  io_test.c 
 */
void io_test(int);
void io_send(ulong, long, long, long);
int compare(long, int);
void disk_test_inquiry(int, FILE *);
void bail_out(int , int , int );

/*
 *  time_mgr.c
 */
int check_timer(struct timer_request *);
void set_timer_request(uint, void *, ulong, ulong);
void timer_req_callback(struct timer_request *);
void elapsed_time(time_t, time_t, char *);
void run_time(char *, ulong *);
void sys_date(char *);
void sys_time(char *);

/*
 *  xfer_mgr.c
 */
void rate_test(void);
void rate_test_inquiry(int, FILE *);
int canned_rate(int, char *);

/*
 *  input_mgr.c 
 */
void input_mgr(void);

/*
 *  curses_mgr.c
 */
WINDOW_TABLE Window;           /* Table of curses window pointers. */
int curses_mgr(int, char **);
void clear_field(int, int, int);
void wind_intr(void);
void curses_perror(char *);
void curses_stderr(char *fmt, ...);
void curses_printf(char *fmt, ...);
void curses_clear_screen(void);
void curses_shutdown(void);
void curses_specific(char *);

/*
 *  window_common.c
 */
void init_common(void);
int verify_message(int, unsigned char, char *);
int post_usex_message(int, unsigned char, char *, BOOL *);
void do_timer_functions(void);
void common_kill(int, int);
void set_time_of_death(int);
void sigchld(int);
void debug_message(ulong, ulong);
void prompt_message(char *, int);
void post_test_status(int, char *);
void clear_bin_line(int);
void get_geometry(void);
int errdaemon(int);
void hang_check(int);
void bottom_left(int);
void clear_display_screen(void);
void dump_status_signal(int);
void dump_status(int, FILE *);
#define WINDOW_MANAGER_KILLED (0)
#define INTERACTIVE_STATUS    (1)
#define SIGNAL_STATUS         (2)
#define REPORTFILE_STATUS     (3)
void test_inquiry(int, FILE *, int);
void test_summaries(FILE *);
int last_message_query(int, FILE *, int);
void save_screen(uint);
void dump_screen(FILE *);
void show_load_average(void); 
void window_manager_shutdown_notify(void);
void window_manager_shutdown(void);
void show_free_memory(void);
int show_cpu_stats(int);
#define GET_RUNTIME_STATS (0)
#define GET_SMP_COUNT     (1)
int canned_message(int , char *);
void unresolved(char *, int);

/*
 *  float.c
 */ 
void float_test(void);
void float_test_inquiry(int, FILE *);

/*
 *  whetstone.c
 */
void whetstone_main(int, char **);

/*
 *  dry.c 
 */ 
void dry(void);
void dry_test_inquiry(int, FILE *);

/*
 *  dhrystone.c
 */
int Proc0(void);

/*
 *  shell_mgr.c 
 */
void shell_mgr(int);
void shell_cmd_inquiry(int, FILE *);
void sh_send(int);

/*
 *  bin_mgr.c
 */ 
void bin_mgr(int);
void bin_mgr_init(void);
void bin_exclude(char *);
int bin_exclusive(char *);
int bin_cleanup(int, int);
void bin_test_inquiry(int, FILE *);
int bin_test_exists(char *);
void bin_test_mod_callback(PROC_TABLE *);
void bin_send(int);

/*
 *  vmem.c
 */
void vmem(void);
int canned_vmem(int, char *);
#define CURSES_DANCE_STEPS (17)
#define GTK_DANCE_STEPS    (9)
char *curses_vmem_dance(int, char *s);
void vmem_test_inquiry(int, FILE *);

/*
 *  debug.c
 */
void debug_test(void);
int fdebug(char *, char *, int, int);
void debug_test_inquiry(int, FILE *);

/*
 *  output_switch.c
 */
void output_switch(int, char **);

/*
 *  build.c
 */
extern char *build_date, *build_machine, *build_id, *build_sum;

#ifndef linux
extern char *sys_errlist[];
#endif

#ifdef __alpha__
#define MACHINE_TYPE "ALPHA" 
#endif
#ifdef __i386__
#define MACHINE_TYPE "X86" 
#endif
#ifdef __powerpc__
#define MACHINE_TYPE "PPC" 
#endif
#ifdef __ia64__
#define MACHINE_TYPE "IA64" 
#endif
#ifndef MACHINE_TYPE
#define MACHINE_TYPE "UNKNOWN" 
#endif

#ifndef ATTRIBUTE_UNUSED
#define ATTRIBUTE_UNUSED __attribute__ ((__unused__))
#endif
