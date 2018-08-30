/*  Author: David Anderson <anderson@redhat.com> */

#include "defs.h"

/*
 *  bin_mgr: repeatedly execute a set of commands from various "bin" directories
 *
 *  BitKeeper ID: @(#)bin_mgr.c 1.4
 *
 *  CVS: $Revision: 1.22 $ $Date: 2016/02/10 19:25:51 $
 */

#define IGNORE_EXIT          BIT0
#define MAKE_TMP_OBJ         BIT1
#define MAKE_TMP_OBJ_2       BIT2
#define MAKE_TMP_ASCII       BIT3
#define MAKE_TMP_CFILE       BIT4
#define MAKE_TMP_NAME        BIT5
#define MAKE_TMP_NAME_TWICE  BIT6
#define MAKE_TMP_NAME_2      BIT7

#define MAKE_UU_FILE      BIT8

#define RM_TMP_FILES      BIT9

#define CONCAT_ARGS       BIT10
#define NO_SPACE          BIT11
#define EXTRA_ADD_ON      BIT12
#define USE_ITSELF        BIT13
#define LIMIT_OUTPUT      BIT14
#define LEADER            BIT15
#define FOLLOW            BIT16
#define CLOSE_STDERR      BIT17
#define NO_SHOW           BIT18
#undef WAIT
#define WAIT              BIT19
#define MAKE_UID_ARG      BIT20
#define MAKE_GID_ARG      BIT21
#define STDIN_FROM_NULL   BIT22
#define CLOSE_STDOUT      BIT23
#define STDOUT_TO_NULL    BIT24

#define  BIN              BIT25   /* keep this group witin 32 bits */
#define  USR_BIN          BIT26
#define  USR_UCB          BIT27
#define  USR_SBIN         BIT28 
#define  NOT_FOUND        BIT29
#define  BIN_EXCLUSIVE    BIT30
#define  BIN_EXCLUDED     BIT31

#define  DEFAULT_FILE     BIT32
#define  DEFAULT_FILE_2   BIT33
#define  DEV_NULL         BIT34
#define  LOCALHOST        BIT35
#define  DDHELP           BIT36
#define  CMD_SPECIFIC     BIT37

#define MAX_LINES  (100)

#define LOCATIONS    (BIN|USR_BIN|USR_UCB|USR_SBIN|NOT_FOUND)
#define BIN_LOCATION (BIN|USR_BIN|USR_UCB|USR_SBIN)

#define MAKE_FILES (MAKE_TMP_OBJ|MAKE_TMP_OBJ_2|MAKE_TMP_ASCII|MAKE_TMP_NAME| \
        MAKE_TMP_NAME_2|MAKE_TMP_CFILE|MAKE_TMP_NAME_TWICE| \
     	MAKE_UID_ARG|MAKE_GID_ARG|MAKE_UU_FILE|DEFAULT_FILE|DEFAULT_FILE_2| \
	DEV_NULL|LOCALHOST|DDHELP)

#define MAX_OUTPUT_LINES(x)  (char *)(x)
#define END_OF_LIST          0,0,0,0,

#define BIN_EXCL    BIT0
#define BIN_MON     BIT1
#define BIN_DEBUG   BIT2
#define BIN_UPDATE  BIT3
#define BIN_CLEAN   BIT4

static struct bin_commands bin_commands[] = {
/*
 *  First, the "clean" commands - they make no use of any temporary files
 *  created by usex; the few WAIT'ables make their own temporary files.
 */
    {"a2p", DEV_NULL, 0, 0},
    {"ab -V", 0, 0, 0},
    {"access -x", USE_ITSELF, 0, 0},
    {"apropos apropos", IGNORE_EXIT, 0, 0},
    {"ar", STDOUT_TO_NULL|CMD_SPECIFIC, 0, 0},
    {"arch", 0, 0, 0},
    {"ash", DEV_NULL, 0, 0},
    {"at", IGNORE_EXIT, 0, 0},
    {"atq", 0, 0, 0},
    {"atrm", IGNORE_EXIT, 0, 0},
    {"automount --version", 0, 0, 0},
    {"awk {print}", STDIN_FROM_NULL, 0, 0},
    {"bash", DEV_NULL, 0, 0},
    {"bc", STDIN_FROM_NULL, 0, 0},
    {"basename", USE_ITSELF, 0, 0},
    {"cat", DEFAULT_FILE, 0, 0},
    {"cal", 0, 0, 0},
    {"captoinfo", STDOUT_TO_NULL|IGNORE_EXIT, 0, 0},
    {"cdp -v", 0, 0, 0},
    {"ci", STDIN_FROM_NULL|CLOSE_STDERR|IGNORE_EXIT, 0, 0},
    {"cksum", USE_ITSELF, 0, 0},
    {"clear", 0, 0, 0},
    {"co", STDIN_FROM_NULL|CLOSE_STDERR|IGNORE_EXIT, 0, 0},
    {"col", STDIN_FROM_NULL, 0, 0},
    {"colcrt", STDIN_FROM_NULL, 0, 0},
    {"colrm 1", STDIN_FROM_NULL, 0, 0},
    {"comm", DEFAULT_FILE_2, 0, 0},
    {"cp", DEFAULT_FILE|DEV_NULL, 0, 0},
    {"cpio -o", STDIN_FROM_NULL|STDOUT_TO_NULL, 0, 0},
    {"crontab -z", IGNORE_EXIT, 0, 0},     /* to avoid filling cron logs */
    {"csh", IGNORE_EXIT|DEV_NULL, 0, 0},
    {"csplit", IGNORE_EXIT, 0, 0},
    {"ctags", DDHELP, 0, 0},
    {"cu", IGNORE_EXIT, 0, 0},
    {"cut -di -f1", DEFAULT_FILE, 0, 0},
    {"cvs -v", 0, 0, 0},
    {"date", 0, 0, 0},
    {"dc", STDIN_FROM_NULL, 0, 0},
    {"dd of=/dev/null if=", USE_ITSELF|NO_SPACE, 0, 0},
    {"ddate", 0, 0, 0},
    {"dip -v", IGNORE_EXIT, 0, 0},
    {"dircolors", IGNORE_EXIT, 0, 0},
    {"dirname", DEFAULT_FILE, 0, 0},
    {"df /", 0, 0, 0},
    {"diff", DEFAULT_FILE_2, 0, 0},
    {"dmesg", 0, 0, 0},
    {"doexec", IGNORE_EXIT|USE_ITSELF, 0, 0},
    {"domainname", 0, 0, 0},
    {"dos --version", IGNORE_EXIT, 0, 0},
    {"du -s", USE_ITSELF, 0, 0},
    {"dumpkeys --keys-only", IGNORE_EXIT, 0, 0},
    {"echo", USE_ITSELF, 0, 0},
    {"ed", STDIN_FROM_NULL|DEFAULT_FILE, 0, 0},
    {"egrep bin", DEFAULT_FILE, 0, 0},
    {"eject -n", IGNORE_EXIT, 0, 0},
    {"elmalias nobody", 0, 0, 0},
    {"env", 0, 0, 0},
    {"etags", DDHELP, 0, 0},
    {"etex", DDHELP, 0, 0},
    {"ex", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"expand", DEFAULT_FILE, 0, 0},
    {"expr 1+1", 0, 0, 0},
    {"factor 1024", IGNORE_EXIT, 0, 0},
    {"false", IGNORE_EXIT, 0, 0},
    {"fgrep bin", DEFAULT_FILE, 0, 0},
    {"file", USE_ITSELF, 0, 0},
    {"find /bin -print", STDOUT_TO_NULL, 0, 0},
    {"finger", 0, 0, 0},
    {"flex", DDHELP, 0, 0},
    {"fmt", DEFAULT_FILE, 0, 0},
    {"fold", DEFAULT_FILE, 0, 0},
    {"free", 0, 0, 0},
    {"funzip", IGNORE_EXIT, 0, 0},
    {"fuser -V", 0, 0, 0},
    {"fwhois", IGNORE_EXIT, 0, 0},
    {"gasp", 0, 0, 0},
    {"gawk {print}", DEFAULT_FILE, 0, 0},
    {"gdb -v", 0, 0, 0},
    {"gencat", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"getconf ARG_MAX", 0, 0, 0},
    {"getopt abc", 0, 0, 0},
    {"gimp -h", IGNORE_EXIT, 0, 0},
    {"git --help", IGNORE_EXIT, 0, 0},
    {"glib-config --libs --cflags", 0, 0, 0},
    {"gmake", DEV_NULL, 0, 0},
    {"gprof", IGNORE_EXIT, 0, 0},
    {"grep bin", DEFAULT_FILE, 0, 0},
    {"groups", IGNORE_EXIT, 0, 0},
    {"gs", DDHELP, 0, 0},
    {"gsbj", IGNORE_EXIT, 0, 0},
    {"gsdj", IGNORE_EXIT, 0, 0},
    {"gsdj500", IGNORE_EXIT, 0, 0},
    {"gslj", IGNORE_EXIT, 0, 0},
    {"gslp", IGNORE_EXIT, 0, 0},
    {"gsnd", DDHELP, 0, 0},
    {"guile", DDHELP, 0, 0},
    {"gunzip", STDIN_FROM_NULL|STDOUT_TO_NULL|CLOSE_STDERR|IGNORE_EXIT, 0, 0},
    {"gzip", STDIN_FROM_NULL|STDOUT_TO_NULL|CLOSE_STDERR, 0, 0},
    {"head", DEFAULT_FILE, 0, 0},
    {"hexdump", USE_ITSELF, 0, 0},
    {"hostname", 0, 0, 0},
    {"iconv", STDIN_FROM_NULL|CLOSE_STDERR|IGNORE_EXIT, 0, 0},
    {"id", IGNORE_EXIT, 0, 0},
    {"ident", USE_ITSELF, 0, 0},
    {"ifnames", DEV_NULL, 0, 0},
    {"inc -v", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"info", DDHELP, 0, 0},
    {"infocmp -C", 0, 0, 0},
    {"ipcalc", IGNORE_EXIT, 0, 0},
    {"ipcrm", IGNORE_EXIT, 0, 0},
    {"ipcs", IGNORE_EXIT|LIMIT_OUTPUT, 0, 0},  
    {"ispell -v", 0, 0, 0},
    {"join", DEFAULT_FILE_2, 0, 0},
    {"jpegtran", DDHELP|IGNORE_EXIT, 0, 0},
    {"kbd_mode", IGNORE_EXIT, 0, 0},
    {"kill -l", 0, 0, 0},
    {"last -n 10", IGNORE_EXIT, 0, 0},
    {"less", DEFAULT_FILE, 0, 0},
    {"lesskey", IGNORE_EXIT|DEV_NULL, 0, 0},
    {"lha", IGNORE_EXIT, 0, 0},
    {"locale", 0, 0, 0},
    {"localedef", IGNORE_EXIT, 0, 0},
    {"lockfile -v", IGNORE_EXIT, 0, 0},
    {"logname", IGNORE_EXIT, 0, 0},
    {"look look", IGNORE_EXIT, 0, 0},
    {"lookbib -v", IGNORE_EXIT, 0, 0},
    {"lpc help", IGNORE_EXIT, 0, 0},
    {"lpq", IGNORE_EXIT, 0, 0},
    {"lptest", 0, 0, 0},
    {"ls -l", USE_ITSELF, 0, 0},
    {"lsattr", 0, 0, 0},
    {"lynx -help", 0, 0, 0},
    {"mag 1", IGNORE_EXIT, 0, 0},
    {"man man", IGNORE_EXIT, 0, 0},
    {"m4", DEFAULT_FILE, 0, 0},
    {"mail -f /dev/null", IGNORE_EXIT, 0, 0},
    {"mailq", IGNORE_EXIT, 0, 0},
    {"mailstats", IGNORE_EXIT, 0, 0},
    {"make", DEV_NULL, 0, 0},
    {"man -f man", IGNORE_EXIT, 0, 0},
    {"merge", DEV_NULL|WAIT|DEFAULT_FILE_2, 0, 0},
    {"mesg", IGNORE_EXIT, 0, 0}, 
    {"more", DEV_NULL, 0, 0},
    {"mount", 0, 0, 0},
    {"mpost -v", 0, 0, 0},
    {"mt status", IGNORE_EXIT, 0, 0},
    {"mutt -v", 0, 0, 0},
    {"mxtar", DDHELP, 0, 0},
    {"namei", USE_ITSELF, 0, 0},
    {"neqn", STDIN_FROM_NULL, 0, 0},
    {"netscape -v", 0, 0, 0},
    {"netstat -r", 0, 0, 0},
    {"newer", DEFAULT_FILE_2, 0, 0},
    {"next -v", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"nfsstat", IGNORE_EXIT, 0, 0},
    {"nice", 0, 0, 0},
    {"nl", DEFAULT_FILE, 0, 0},
    {"nmblookup", IGNORE_EXIT, 0, 0},
    {"nohup /bin/ls", STDOUT_TO_NULL, 0, 0},
    {"nroff", DEFAULT_FILE, 0, 0},
    {"objcopy", DDHELP, 0, 0},
    {"objdump --section-headers", USE_ITSELF, 0, 0},
    {"od -c", DEFAULT_FILE, 0, 0},
    {"odvips", DDHELP, 0, 0},
    {"otangle", DDHELP, 0, 0},
    {"paste", DEFAULT_FILE_2, 0, 0},
    {"patch", STDIN_FROM_NULL, 0, 0},
    {"pathchk", USE_ITSELF, 0, 0},
    {"perl -V", 0, 0, 0},
    {"perldoc -h", IGNORE_EXIT, 0, 0},
    {"pick -h", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"ping -c 1", LOCALHOST|IGNORE_EXIT, 0, 0},
    {"play -h", IGNORE_EXIT, 0, 0},
    {"pmap_dump", 0, 0, 0},
    {"praliases", 0, 0, 0},
    {"prev -v", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"printenv", 0, 0, 0},
    {"printf hello\\n", 0, 0, 0},
    {"pr", DEFAULT_FILE, 0, 0},
    {"printmail", DEV_NULL, 0, 0},
    {"procmail -v", 0, 0, 0},
    {"prompter -h", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"ps aux", IGNORE_EXIT, 0, 0},   
    {"pstree", IGNORE_EXIT, 0, 0},   
    {"pwd", 0, 0, 0},
    {"quota -u root", IGNORE_EXIT, 0, 0},
    {"ranlib", IGNORE_EXIT, 0, 0},
    {"rcp", DEFAULT_FILE|DEV_NULL, 0, 0},
    {"rcs", IGNORE_EXIT, 0, 0},
    {"rcsdiff", IGNORE_EXIT, 0, 0},
    {"rcsclean -n", 0, 0, 0},
    {"rcsmerge -j", IGNORE_EXIT, 0, 0},
    {"renice", IGNORE_EXIT, 0, 0},
    {"rdate", IGNORE_EXIT|LOCALHOST, 0, 0},
    {"rdist -V", 0, 0, 0},
    {"reset", IGNORE_EXIT, 0, 0},
    {"refer", DEV_NULL, 0, 0},
    {"refile -v", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"renice", IGNORE_EXIT, 0, 0},
    {"repl -v", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"rev", DEFAULT_FILE, 0, 0},
    {"rlog", IGNORE_EXIT, 0, 0},
    {"rlogin", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"rpcgen", IGNORE_EXIT, 0, 0},
    {"rpcinfo -p", IGNORE_EXIT|LOCALHOST, 0, 0},
    {"rsh", IGNORE_EXIT, 0, 0},
    {"rup", LOCALHOST|IGNORE_EXIT, 0, 0},
    {"ruptime", LOCALHOST|IGNORE_EXIT, 0, 0},
    {"rusers", LOCALHOST|IGNORE_EXIT, 0, 0},
    {"rwho", LOCALHOST|IGNORE_EXIT, 0, 0},
    {"rx", DDHELP, 0, 0},
    {"rz", DDHELP, 0, 0},
    {"safe_finger", IGNORE_EXIT, 0, 0},
    {"sdiff", DEFAULT_FILE_2, 0, 0},
    {"sed -n -e 1p", DEFAULT_FILE, 0, 0},
    {"sendmail -bp", IGNORE_EXIT, 0, 0},
    {"setserial -V", 0, 0, 0},
    {"seq", DDHELP, 0, 0},
    {"sh", DEV_NULL, 0, 0},
    {"show -v", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"showkey", DDHELP|IGNORE_EXIT, 0, 0},
    {"showmount", DDHELP, 0, 0},
    {"size", USE_ITSELF, 0, 0},
    {"skill -l", 0, 0, 0},
    {"sleep 1", 0, 0, 0},
    {"slist", IGNORE_EXIT, 0, 0},
    {"slocate", 0, 0, 0},
    {"snice -L", 0, 0, 0},
    {"sort", DEFAULT_FILE, 0, 0},
    {"sortm -help", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"spell", USE_ITSELF, 0, 0},
    {"splac", IGNORE_EXIT, 0, 0},
    {"splash", IGNORE_EXIT, 0, 0},
    {"sq", STDIN_FROM_NULL, 0, 0},
    {"strace", USE_ITSELF|WAIT|IGNORE_EXIT, 0, 0},
    {"strings", DEFAULT_FILE, 0, 0},
    {"stty -a", IGNORE_EXIT, 0, 0},
    {"suidperl -h", 0, 0, 0},
    {"sum", USE_ITSELF, 0, 0},
    {"sx", DDHELP, 0, 0},
    {"sy", DDHELP, 0, 0},
    {"sync", 0, 0, 0},
    {"tail", DEFAULT_FILE, 0, 0},
    {"tcl", DEV_NULL, 0, 0},
    {"tee", STDIN_FROM_NULL|STDOUT_TO_NULL, 0, 0},
    {"telnet", STDIN_FROM_NULL, 0, 0},
    {"test 0", 0, 0, 0},
    {"thumbnail", IGNORE_EXIT, 0, 0},
    {"tic", IGNORE_EXIT, 0, 0},
    {"tie", IGNORE_EXIT, 0, 0},
    {"time /bin/ls /bin/ls", 0, 0, 0},
    {"tload -V", 0, 0, 0},
    {"toe -V", 0, 0, 0},
    {"tput", IGNORE_EXIT, 0, 0},
    {"tr -d x", STDIN_FROM_NULL, 0, 0},
    {"traceroute", LOCALHOST|IGNORE_EXIT, 0, 0},
    {"true", 0, 0, 0},
    {"tset", IGNORE_EXIT, 0, 0},
    {"tsort", DEV_NULL, 0, 0},
    {"tty", IGNORE_EXIT, 0, 0},
    {"ul", DEV_NULL, 0, 0},
    {"umount", IGNORE_EXIT, 0, 0},
    {"uname", 0, 0, 0},
    {"unexpand", DEFAULT_FILE, 0, 0},
    {"uniq", DEFAULT_FILE, 0, 0},
    {"unshar", DDHELP, 0, 0},
    {"unsq", STDIN_FROM_NULL, 0, 0},
    {"uuname -l", 0, 0, 0},
    {"uptime", 0, 0, 0},
    {"users", 0, 0, 0},
    {"usleep 1000000", 0, 0, 0},
    {"uuencode", DEFAULT_FILE_2, 0, 0},
    {"uux", IGNORE_EXIT, 0, 0},
    {"vdir", IGNORE_EXIT, 0, 0},
    {"viamail -version", IGNORE_EXIT, 0, 0},
    {"vmstat", 0, 0, 0},
    {"wc -l", DEFAULT_FILE, 0, 0},
    {"weave", DDHELP, 0, 0},
    {"whatis", DEV_NULL|IGNORE_EXIT, 0, 0},
    {"whatnow -v", STDIN_FROM_NULL|IGNORE_EXIT, 0, 0},
    {"whereis whereis", 0, 0, 0},
    {"which which", IGNORE_EXIT, 0, 0},
    {"who", 0, 0, 0},
    {"whoami", 0, 0, 0},
    {"xargs", STDIN_FROM_NULL, 0, 0},
    {"yacc", IGNORE_EXIT, 0, 0},
    {"yes --version", 0, 0, 0},
    {"ypwhich", DDHELP, 0, 0}, 
    {"zdump eastern", 0, 0, 0},
    {"zcmp", IGNORE_EXIT, 0, 0},
    {"zdiff", IGNORE_EXIT, 0, 0},
    {"zgrep", IGNORE_EXIT, 0, 0},
    {"zic -v", 0, 0, 0},
    {"zip -h", 0, 0, 0},
    {"zipgrep", IGNORE_EXIT, 0, 0},
    {"zipinfo", 0, 0, 0},
    {"zipnote", 0, 0, 0},
    {"zipsplit", 0, 0, 0},

/*
 *  For debugging purposes, the following command can be put into place
 *  in one of the bin directories.
 */
    {"dummy_command", 0, 0, 0},

/*
 *  The rest of the commands are exevcp()'able but use temporary files that
 *  are created by usex.  Several compiler-related functions are WAITable:
 */
    {"cc -o", MAKE_TMP_NAME|MAKE_TMP_CFILE|CONCAT_ARGS|WAIT|RM_TMP_FILES, 0, 0},
    {"chgrp", MAKE_GID_ARG|MAKE_TMP_OBJ|RM_TMP_FILES, 0, 0},
    {"chown", MAKE_UID_ARG|MAKE_TMP_OBJ|RM_TMP_FILES|IGNORE_EXIT, 0, 0},
    {"chmod 777", MAKE_TMP_OBJ|RM_TMP_FILES, 0, 0},
    {"cmp", MAKE_TMP_OBJ|MAKE_TMP_OBJ_2|CONCAT_ARGS|RM_TMP_FILES, 0, 0},
    {"cproto", MAKE_TMP_CFILE|WAIT|RM_TMP_FILES, 0, 0},
    {"gctags -x", MAKE_TMP_CFILE|WAIT|RM_TMP_FILES, 0, 0},
    {"epp", IGNORE_EXIT|MAKE_TMP_CFILE|WAIT|RM_TMP_FILES, 0, 0},
    {"ln", MAKE_TMP_OBJ|MAKE_TMP_NAME_2|CONCAT_ARGS|RM_TMP_FILES, 0, 0},
    {"ln -s", MAKE_TMP_OBJ|MAKE_TMP_NAME_2|CONCAT_ARGS|RM_TMP_FILES, 0, 0},
    {"mkfifo", MAKE_TMP_NAME|RM_TMP_FILES, 0, 0},
    {"mv", MAKE_TMP_OBJ|MAKE_TMP_NAME_2|CONCAT_ARGS|RM_TMP_FILES, 0, 0},
    {"protoize", MAKE_TMP_CFILE|WAIT|RM_TMP_FILES, 0, 0},
    {"unprotoize", MAKE_TMP_CFILE|WAIT|RM_TMP_FILES, 0, 0},
    {"pstruct", MAKE_TMP_CFILE|WAIT|RM_TMP_FILES|IGNORE_EXIT, 0, 0},
    {"rm -f", MAKE_TMP_OBJ, 0, 0},
    {"tar cvf ", MAKE_TMP_NAME|MAKE_TMP_OBJ_2|CONCAT_ARGS|RM_TMP_FILES, 0, 0},
    {"tcl", DEV_NULL, 0, 0},
    {"touch", MAKE_TMP_OBJ|RM_TMP_FILES, 0, 0},
    {"uudecode", MAKE_UU_FILE|RM_TMP_FILES, 0, 0},

/*
 *  The remaining files are paired for one reason or another.
 */
/* WARNING: strip must be preceded by cc -o */
    {"cc -o", NO_SHOW|LEADER|MAKE_TMP_NAME|MAKE_TMP_CFILE|CONCAT_ARGS|WAIT, 0, 0},
    {"strip", FOLLOW|MAKE_TMP_NAME|RM_TMP_FILES|WAIT, 0, 0},

/* WARNING: as must be preceded by cc -S */
    {"cc -S", NO_SHOW|LEADER|MAKE_TMP_CFILE|WAIT, 0, 0},
    {"as -o", FOLLOW|MAKE_TMP_NAME_TWICE|RM_TMP_FILES|EXTRA_ADD_ON|WAIT, 0, ".s"},

/* WARNING: ld must be preceded by cc -c */
    {"cc -c", NO_SHOW|LEADER|MAKE_TMP_CFILE|WAIT, 0, 0},
    {"ld -o", FOLLOW|MAKE_TMP_NAME_TWICE|RM_TMP_FILES|EXTRA_ADD_ON|WAIT, 0, ".o"},

/* WARNING: nm must be preceded by cc -c */
    {"cc -c", NO_SHOW|LEADER|MAKE_TMP_CFILE|WAIT, 0, 0},
    {"nm", FOLLOW|MAKE_TMP_NAME|RM_TMP_FILES|EXTRA_ADD_ON, 0, ".o"},

/* WARNING: "compress" must be followed by "uncompress" */
    {"compress", LEADER|MAKE_TMP_ASCII|WAIT, 0, 0},
    {"uncompress", FOLLOW|MAKE_TMP_NAME|RM_TMP_FILES|EXTRA_ADD_ON, 0, ".Z"},

/* WARNING: "mkdir" must be followed by "rmdir" */
    {"mkdir", LEADER|MAKE_TMP_NAME|WAIT, 0, 0},
    {"rmdir", FOLLOW|MAKE_TMP_NAME|WAIT, 0, 0},

/* WARNING: "zcat" must be preceded by "compress" */
    {"compress", NO_SHOW|LEADER|MAKE_TMP_ASCII|WAIT, 0, 0},
    {"zcat", FOLLOW|MAKE_TMP_NAME|RM_TMP_FILES|EXTRA_ADD_ON, 0, ".Z"},

    {END_OF_LIST}
};

static void kill_child(void); 
static void bin_pass(ulong);
static int pipe_line(int, char *);
static int bin_pass_strlen(ulong);
static void rm_tmp_files(struct bin_commands *);
static char *make_tmp_file(struct bin_commands *);
static int init_order(void);
static struct bin_commands *find_cmd(char *, int, int);
static struct bin_commands *get_next_bp(void);
static void bin_bailout(char *);
static void fill_action(char *, char *);
static void bin_fork_failure(PROC_TABLE *, int);
static int resource_unavailable(char *s, struct bin_commands *, PROC_TABLE *);
static int search_for_commands(PROC_TABLE *); 
static int command_location(struct bin_commands *);
static char *get_command_name(struct bin_commands *, char *);
static void dump_not_found(PROC_TABLE *, FILE *);
static void dump_excluded(PROC_TABLE *, FILE *);
static void dump_exclusive(PROC_TABLE *, FILE *);
static void sync_with_window_mgr(PROC_TABLE *);
static void size_command_window(PROC_TABLE *);
static void do_cmd_specific(void);


void
bin_mgr_init(void)
{
	if (Shm->mode & BIN_INIT)
		return;

	Shm->bin_cmds_found = search_for_commands(NULL);

	Shm->mode |= BIN_INIT;
}

void
bin_mgr(int proc)
{
    register int i, j, k;
    register PROC_TABLE *tbl = &Shm->ptbl[proc];
    char command[MESSAGE_SIZE];
    char path[MESSAGE_SIZE];
    int cstat, lp[2], out;
    long long found;
    char *argv[MAX_ARGV];
    int argc;
    char *cmdptr;
    int data_lines, max_lines;
    char buf[MAX_PIPELINE_READ + PIPELINE_PAD];
    struct bin_commands *bp;
    int child;
    time_t now;
    int nullfd;

    setpgid(getpid(), 0);   /* Ignore any error -- just continue. */
    setenv("DISPLAY", ":0.0", TRUE);
    if (!streq(Shm->tmpdir, "/tmp"))
    	setenv("TMPDIR", Shm->tmpdir, TRUE);

    ID = proc;

    time(&now);
    tbl->i_timestamp = now;
    tbl->i_pid = getpid();
    tbl->i_stat |= IO_START;
    tbl->i_stat |= IO_BKGD;         /* Default mode is in background */
    sigset(SIGUSR1, kill_child);
    sigset(SIGINT, SIG_IGN);
    signal(SIGCHLD, SIG_DFL);
    child = tbl->bin_child = tbl->cmd_cnt = 0;
    tbl->max_pass = 0;
    tbl->cur_order = -1;
    tbl->BP = &tbl->null_cmd;

    if (chdir(Shm->tmpdir) != 0) 
        fatal(ID, Shm->tmpdir, errno);

    /*
     *  Certain files must exist in known locations for the bin_mgr to work.
     */
    if (!file_exists("/bin/ls")) 
        fatal(ID, "bin_mgr: /bin/ls", errno);

    if (!file_exists("/bin/cp")) 
        fatal(ID, "bin_mgr: /bin/cp", errno);
    
    if (!file_exists("/bin/mkdir")) 
        fatal(ID, "bin_mgr: /bin/mkdir", errno);
    
    if (!file_exists("/bin/rm")) 
        fatal(ID, "bin_mgr: /bin/rm", errno);
    
    if (!file_exists("/dev/null"))
        fatal(ID, "bin_mgr: /dev/null", errno);

    bzero(tbl->tmp_file, MESSAGE_SIZE);
    bzero(tbl->tmp_file_2, MESSAGE_SIZE);
    bzero(tbl->tmp_C_file, MESSAGE_SIZE);
    bzero(tbl->tmp_concat, MESSAGE_SIZE*2);

    sprintf(tbl->tmp_file,   "%s/ux%06d_%02d", Shm->tmpdir, Shm->mompid, ID+1);
    sprintf(tbl->tmp_file_2, "%s/ux%06d_%02d_2", Shm->tmpdir,Shm->mompid, ID+1);
    sprintf(tbl->tmp_C_file, "%s/ux%06d_%02d.c", Shm->tmpdir,Shm->mompid, ID+1);

    if (Shm->outfile && !streq(Shm->outfile, Shm->default_file)) {
    	sprintf(tbl->tmp_default, "%s/%s", Shm->tmpdir, Shm->outfile);
    } else if (strlen(Shm->default_file))
	strcpy(tbl->tmp_default, Shm->default_file);
    else {
        fatal(ID, "no default file?", 0);
    }

    if ((nullfd = open("/dev/null", O_RDWR)) < 0)
	fatal(ID, "bin_mgr: cannot open /dev/null", errno);
	
    do_cmd_specific();

    if (Shm->mode & IGNORE_BIN_EXIT)
        for (bp = &bin_commands[0]; bp->cmd != 0; bp++)
        	bp->cmdflags |= IGNORE_EXIT;

    strcpy(command, tbl->i_file);
    argc = parse(command, argv);

    for (i = 1; i < argc; i++) {
        if (strncmp(argv[i], "!", 1) == 0) {
            cmdptr = &argv[i][1];
            if (strlen(cmdptr))
	    	bin_exclude(cmdptr);
	    continue;
        }

	if (strncmp(argv[i], "-", 1) != 0) { 
	    cmdptr = argv[i];
            if (strlen(cmdptr))
	    	bin_exclusive(cmdptr);
	    continue;
	}

        if (strncmp(argv[i], "-v", 2) == 0) 
 	    tbl->i_stat &= ~IO_BKGD; /* -v is only way to start verbose */

        if (strncmp(argv[i], "-m", 2) == 0) {
            tbl->bin_flags |= BIN_MON;
        }
        if (strncmp(argv[i], "-p", 2) == 0) {
            if (strlen(argv[i]) > strlen("-p")) 
                tbl->max_pass = atol(&argv[i][2]);
        }
        if (strncmp(argv[i], "-i", 2) == 0) {
            if (strlen(argv[i]) > strlen("-i")) {
                if ((bp = find_cmd(&argv[i][2], 0, 0))) 
		    bp->cmdflags |= IGNORE_EXIT;
            }
            else {
    		for (bp = &bin_commands[0]; bp->cmd != 0; bp++)
        	     bp->cmdflags |= IGNORE_EXIT;
	    }
	}
        if (strcmp(argv[i], "-d") == 0)
 	    tbl->bin_flags |= BIN_DEBUG;
        if (strcmp(argv[i], "-k") == 0) {
	    set_time_of_death(ID);
            _exit(BIN_MGR_K); 
	}
	if (strncmp(argv[i], "-nol", 4) == 0)
	    tbl->i_stat |= IO_NOLOG;
    }

    if (tbl->bin_flags & BIN_DEBUG)
        Shm->stderr("\rBIN_DEBUG: ON\r\n");

    tbl->max_cmds = init_order();

    tbl->cmds_found = search_for_commands(tbl);

    if ((i = bin_exclusive(NULL))) {
	tbl->bin_flags |= BIN_EXCL;
	tbl->cmds_per_pass = i;
    } else
	tbl->cmds_per_pass = tbl->cmds_found;

    if (tbl->bin_flags & BIN_UPDATE)
    	sync_with_window_mgr(tbl);

    if (GTK_DISPLAY()) 
	size_command_window(tbl);

    bin_pass(tbl->i_pass = 1);

    if (tbl->i_stat & IO_BKGD) 
        sprintf(tbl->i_msgq.string, "%c%c BKGD ", FSTAT,
            tbl->i_local_pid);
    else 
        sprintf(tbl->i_msgq.string, "%c%c  OK  ", FSTAT,
            tbl->i_local_pid);
    bin_send(0);

    for (EVER) {

        if (tbl->i_stat & (IO_HOLD|IO_HOLD_PENDING)) 
 	    put_test_on_hold(tbl, ID);

	if (Shm->mode & SYNC_BIN_TESTS) {
		synchronize(ID, NULL);
		tbl->i_stat |= BIN_SYNC;
		while (get_i_stat(tbl) & BIN_SYNC)
			stall(50000);
	}

	tbl->i_stat |= IO_LOOKUP;

	if (mother_is_dead(Shm->mompid, "B6")) {  /* Mom's dead. */
            bin_cleanup(ID, INTERNAL);
	    fatal(ID, "mother is dead", 0);
        }

	while ((bp = get_next_bp())) {

            if (bp->cmdflags & BIN_EXCLUDED) 
		continue;

	    if (tbl->bin_flags & BIN_EXCL) {
		if (bp->cmdflags & BIN_EXCLUSIVE)
		    break;
		else
		    continue;
	    }

	    break;
	}
        tbl->BP = bp;

	strcpy(tbl->i_file, tbl->BP->cmd);   /* Stash aside for inquiry... */

        if (tbl->cmd_cnt++ >= tbl->cmds_per_pass) {
            tbl->i_pass++;
            tbl->cmd_cnt = 0;
            bin_pass(tbl->i_pass);
            if (tbl->max_pass && (tbl->i_pass > tbl->max_pass)) 
                bin_bailout("reached maximum pass count");
        }

        /*
         *  Force the command to come out of /bin, /usr/bin, 
	 *  /usr/ccs/bin or /usr/ucb.
         */
        found = FALSE;
        strcpy(command, bp->cmd);
        argc = parse(command, argv);

        /*
         *  If output from a command is to be restricted, the bp->cleanup 
         *  field is used as a "maximum lines to read" value.
         */ 
        max_lines = (bp->cmdflags & LIMIT_OUTPUT) ? MAX_LINES : 0;

	/*
         *  After the first pass, we know where the command is, 
         *  or if it can't be found at all.
         */
	switch (bp->cmdflags & LOCATIONS)
	{
        case BIN:         
	    sprintf(path, "/bin/%s", argv[0]);
	    goto bin;
        case USR_BIN:    
	    sprintf(path, "/usr/bin/%s", argv[0]);
	    goto usr_bin; 
        case USR_UCB: 
	    sprintf(path, "/usr/ucb/%s", argv[0]);
	    goto usr_ucb; 
        case USR_SBIN:    
	    sprintf(path, "/usr/sbin/%s", argv[0]);
	    goto usr_sbin;
        case NOT_FOUND:   
            goto cmd_not_found;
	}

	if (!found) {
            sprintf(path, "/bin/%s", argv[0]);
            if (file_exists(path)) {
bin:            bp->cmdpath = path;
                sprintf(command, "/bin/%s", bp->cmd);
                if (bp->cmdflags & (MAKE_FILES)) {
    	            strcat(command, bp->cmdflags & NO_SPACE ? "" : " ");
                    strcat(command, make_tmp_file(bp));
                }
                if (bp->cmdflags & USE_ITSELF) {
                    strcat(command, bp->cmdflags & NO_SPACE ? "" : " ");
                    strcat(command, bp->cmdpath);
                }
                if (bp->cmdflags & EXTRA_ADD_ON)
                    strcat(command, bp->cleanup);
                argc = parse(command, argv);
                found = (ulong)BIN;
		bp->cmdflags |= BIN;
            }
        }

        if (!found) {
            sprintf(path, "/usr/bin/%s", argv[0]);
            if (file_exists(path)) {
usr_bin:        bp->cmdpath = path;
                sprintf(command, "/usr/bin/%s", bp->cmd);
                if (bp->cmdflags & (MAKE_FILES)) {
	            strcat(command, bp->cmdflags & NO_SPACE ? "" : " ");
                    strcat(command, make_tmp_file(bp));
                }
                if (bp->cmdflags & EXTRA_ADD_ON)
                    strcat(command, bp->cleanup);
                if (bp->cmdflags & USE_ITSELF) {
                    strcat(command, bp->cmdflags & NO_SPACE ? "" : " ");
                    strcat(command, bp->cmdpath);
                }
                argc = parse(command, argv);
                found = (ulong)USR_BIN;
		bp->cmdflags |= USR_BIN;
            }
        }

        if (!found) {
            sprintf(path, "/usr/ucb/%s", argv[0]);
            if (file_exists(path)) {
usr_ucb:        bp->cmdpath = path;
                sprintf(command, "/usr/ucb/%s", bp->cmd);
                if (bp->cmdflags & (MAKE_FILES)) {
                    strcat(command, bp->cmdflags & NO_SPACE ? "" : " ");
                    strcat(command, make_tmp_file(bp));
                }
                if (bp->cmdflags & EXTRA_ADD_ON)
                    strcat(command, bp->cleanup);
                if (bp->cmdflags & USE_ITSELF) {
                    strcat(command, bp->cmdflags & NO_SPACE ? "" : " ");
                    strcat(command, bp->cmdpath);
                }
                argc = parse(command, argv);
                found = (ulong)USR_UCB;
		bp->cmdflags |= USR_UCB;
            }
        }

        if (!found) {
            sprintf(path, "/usr/sbin/%s", argv[0]);
            if (file_exists(path)) {
usr_sbin:       bp->cmdpath = path;
                sprintf(command, "/usr/sbin/%s", bp->cmd);
                if (bp->cmdflags & (MAKE_FILES)) {
                    strcat(command, bp->cmdflags & NO_SPACE ? "" : " ");
                    strcat(command, make_tmp_file(bp));
                }
                if (bp->cmdflags & EXTRA_ADD_ON)
                    strcat(command, bp->cleanup);
                if (bp->cmdflags & USE_ITSELF) {
                    strcat(command, bp->cmdflags & NO_SPACE ? "" : " ");
                    strcat(command, bp->cmdpath);
                }
                argc = parse(command, argv);
                found = (ulong)USR_SBIN;
		bp->cmdflags |= USR_SBIN;
            }
        }

        if (!found) {
cmd_not_found:
	    bp->cmdflags |= NOT_FOUND;
            bin_cleanup(ID, INTERNAL);   /* Could be a follower... */
            continue;
        }

	strcpy(tbl->i_file, tbl->BP->cmdpath);  /* Stash aside for inquiry... */
	fill_action(tbl->curcmd, tbl->BP->cmdpath);  /* for common_kill() */

	tbl->i_stat &= ~IO_LOOKUP;
	tbl->i_stat |= IO_PIPE;
        if (pipe(lp) == -1) {             /* Get a pipe to communicate */
            i = errno;                    /* with the child process.   */
	    tbl->i_stat |= IO_DEAD|IO_SUICIDE;
            bin_cleanup(ID, INTERNAL);
	    fatal(ID, "bin_mgr: pipe", i);
        }
	tbl->i_stat &= ~IO_PIPE;
	tbl->i_stat |= IO_ADMIN1;

        if (tbl->time_to_die) {    /* Don't even bother... */
            bin_cleanup(ID, INTERNAL);
	    tbl->i_stat |= IO_DEAD;
            set_time_of_death(ID);
            _exit(BIN_TIME_TO_DIE_1);
        }

        if (tbl->bin_flags & BIN_MON) {
            Shm->stderr("\n\r%s %s start...\r\n", bp->cmdpath,
                bp->cmdflags & WAIT ? "(WAIT)" : "");
            sleep(1); 
        }

	tbl->i_stat |= IO_FORK;

bin_fork:
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
            sigset(SIGINT, SIG_IGN);     /* Ignore user's signal mechanism. */
	    sigset(SIGHUP, SIG_DFL);     /* Broadcast to prgp on shutdown. */

            for (i = 0; i < argc; i++)
                printf("%s ", argv[i]);
            printf("\n");

            if (bp->cmdflags & STDOUT_TO_NULL) {
                close(1);
                dup(nullfd);
            }

	    if (bp->cmdflags & STDIN_FROM_NULL) {
		close(0);
                dup(nullfd);
	    }

	    if (bp->cmdflags & CLOSE_STDOUT) 
                close(1);

            if (bp->cmdflags & CLOSE_STDERR)
                close(2);

	    sprintf(buf, "execvp(%s)", bp->cmdpath);   /* Set up for failure. */
            execvp(bp->cmdpath, argv);        /* execvp the command. */

            fatal(ID, buf, errno);  /* If it fails, "exit" back to shell_mgr. */
        }

        if (child == -1) {  /* fork() failed */
	    if (errno == EAGAIN) {
	        bin_fork_failure(tbl, USEX_FORK_FAILURE);
		goto bin_fork;
	    }
            i = errno;
	    bin_cleanup(ID, INTERNAL);
            sprintf(buf, "bin_mgr: fork() of %s", bp->cmd);
            fatal(ID, buf, i);
        }

	tbl->i_stat &= ~(IO_FORK|IO_ADMIN1);
	tbl->i_stat |= IO_CHILD_RUN;
    
        tbl->bin_child = child;  /* Only parent touches bin_child field. */

        close(lp[1]);   /* Close the "write" end of the pipe. */

	if (CURSES_DISPLAY()) {
            sprintf(buf, "%c%c%s  [", FSIZE, tbl->i_local_pid, bp->cmdpath);
            out = strlen(buf);
            k = bin_pass_strlen(tbl->i_pass) <= 4 ? 60 :
                60 - (bin_pass_strlen(tbl->i_pass) - 4);
            for (j = strlen(buf); j < 60; j++)
                buf[j] = ' ';
            buf[k-1] = ']';
            buf[k] = (char)NULLCHAR;
            strcpy(tbl->i_msgq.string, buf);
            if (!(bp->cmdflags & NO_SHOW))
                 bin_send(0);
            buf[j] = (char)NULLCHAR;
	}

        if (GTK_DISPLAY()) { 
            sprintf(buf, bp->cmdpath);
            sprintf(tbl->i_msgq.string, 
	        "%c%c%s", FSIZE, tbl->i_local_pid, 
		mkstring(buf, tbl->i_limit, CENTER));
            if (!(bp->cmdflags & NO_SHOW))
                 bin_send(0);
	    out = 0;
        }

        data_lines = 0;
        while (pipe_line(lp[0], &buf[out]) > 0) {
            data_lines++;
	    if (CURSES_DISPLAY()) {
                for (j = strlen(buf) - 1; j < 60; j++)
                    buf[j] = ' ';
                k = bin_pass_strlen(tbl->i_pass) <= 4 ? 59 :
                    59 - (bin_pass_strlen(tbl->i_pass) - 4);
                sprintf(&buf[k], "]  %4ld", tbl->i_pass);
                strcpy(tbl->i_msgq.string, buf);
                tbl->i_msgq.string[0] = FSHELL; 
	    }
	    if (GTK_DISPLAY()) {
		strip_lf(buf);
		mkstring(buf, 80, TRUNC|LJUST);
                sprintf(tbl->i_msgq.string, "%c%c%s", FSHELL, 
                        tbl->i_local_pid, buf); 
	    }

            if ((bp->cmdflags & LIMIT_OUTPUT) && (data_lines >= max_lines)) { 
                Kill(child, SIGKILL, "B1", K_IO(ID));
                wait(&cstat);
                while (Kill(child, 0, "B2", K_IO(ID)) == 0)
                    sleep(1);
            }

            if (tbl->i_stat & IO_BKGD) 
                    continue;

            if (!(bp->cmdflags & NO_SHOW)) 
                bin_send(0);

            if (tbl->time_to_die) 
                break;
        }
        close(lp[0]);

	tbl->i_stat &= ~IO_CHILD_RUN;
	tbl->i_stat |= IO_WAIT;
        wait(&cstat);
	tbl->i_cstat = cstat;
	tbl->i_stat &= ~IO_WAIT;
	tbl->i_stat |= IO_ADMIN2;

        if (tbl->bin_flags & BIN_MON) {
            sleep(1); 
            Shm->stderr("\r%s %s done.\r\n", bp->cmdpath,
                bp->cmdflags & WAIT ? "(WAIT)" : "");
        }

        if (tbl->time_to_die) {
            bin_cleanup(ID, INTERNAL);
	    tbl->i_stat |= IO_DEAD;
	    set_time_of_death(ID);
            _exit(BIN_TIME_TO_DIE_2);
        }

        /*
         *  Try to keep these temporary objects under control.
         */

        if (bp->cmdflags & RM_TMP_FILES) {
	    tbl->bin_flags |= BIN_CLEAN;
	    rm_tmp_files(bp);
	    tbl->bin_flags &= ~BIN_CLEAN;
	}

        /*
         *  Some commands always return a non-zero status, or had to be
         *  shutdown for verbage control.
         */
        if ((bp->cmdflags & LIMIT_OUTPUT) && (data_lines >= max_lines))
            cstat = 0;
        if (bp->cmdflags & IGNORE_EXIT) 
            cstat = 0;

        switch (cstat & 0xff)
        {
        case 0x00:      /* exit - high order 8 bits contain exit status */
            if (cstat & 0xff00) {
                /*
                 *  Dump the last line read.
                 */
		if (CURSES_DISPLAY()) {
                    for (j = strlen(buf) - 1; j < 60; j++)
                        buf[j] = ' ';
                    k = bin_pass_strlen(tbl->i_pass) <= 4 ? 59 :
                    	59 - (bin_pass_strlen(tbl->i_pass) - 4);
                    sprintf(&buf[k], "]  %4ld <WARN>", tbl->i_pass);
    		    if (!(bp->cmdflags & IGNORE_EXIT))
    	       	        buf[0] = MANDATORY_FSHELL;
    		    else
    		        buf[0] = MANDATORY_FSHELL;  /* ?? */
    
                    strcpy(tbl->i_msgq.string, buf);
		}
		if (GTK_DISPLAY()) {
                    sprintf(tbl->i_msgq.string, "%c%c%s", MANDATORY_FSHELL,
                        tbl->i_local_pid, buf);
		}
                bin_send(SYNCHRONIZE);

		if (resource_unavailable(tbl->i_msgq.string, bp, tbl)) {
		    bin_fork_failure(tbl, CMD_FORK_FAILURE);

		    tbl->bin_flags |= BIN_CLEAN;
                    rm_tmp_files(bp);
                    tbl->bin_flags &= ~BIN_CLEAN;

		    if (bp->cmdflags & LEADER) 
			get_next_bp();   /* throw away FOLLOWer */    
		    
		    break;
		}

                if (!(bp->cmdflags & IGNORE_EXIT)) {
                    sprintf(buf, "%s returned exit status: %d",
			bp->cmd, (cstat & 0xff00) >> 8);
                    bin_bailout(buf);
                }
            }
            break;

        case 0x7f:      /* stopped - high order 8 bits contain signal */
            sprintf(tbl->i_msgq.string, "%c%c STOP ", FSTAT, tbl->i_local_pid);
            bin_send(0);
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
                k = bin_pass_strlen(tbl->i_pass) <= 4 ? 59 :
                    59 - (bin_pass_strlen(tbl->i_pass) - 4);
                sprintf(&buf[k], "]  %4ld", tbl->i_pass);
                strcpy(tbl->i_msgq.string, buf);
	    }
            if (GTK_DISPLAY()) {
                sprintf(buf, "terminated by signal: %d",
                    cstat & 0x7f);
                sprintf(tbl->i_msgq.string, "%c%c%s", FSHELL,
                        tbl->i_local_pid, buf);
            }
            bin_send(0);
	    sprintf(buf, "%s terminated by signal: %d", bp->cmd, cstat & 0x7f);
            bin_bailout(buf);
        }

	/* fdebug("/tmp/usex.out", bp->cmd, NOARG, NOARG); */

        tbl->bin_child = child = 0;  /* Clear records of child's existence. */

        tbl->BP = &tbl->null_cmd;

	if (tbl->time_to_die) {
            bin_cleanup(ID, INTERNAL);
	    tbl->i_stat |= IO_DEAD;
            set_time_of_death(ID);
            _exit(BIN_TIME_TO_DIE_3);
        }
	tbl->i_stat &= ~IO_ADMIN2;
    }
}

static void
bin_pass(ulong pass)
{
    register PROC_TABLE *tbl = &Shm->ptbl[ID];

    sprintf(tbl->i_msgq.string,"%c%c%4ld", FPASS, tbl->i_local_pid, pass);
    bin_send(0);
}

static int
bin_pass_strlen(ulong pass)
{
	char buf[STRINGSIZE];

	sprintf(buf, "%ld", pass);
	return(strlen(buf));
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
    char c;                       /* Character holder.  */
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
        if (tbl->time_to_die) {
            *buffer = (char)NULLCHAR;
            goto stash_message;
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

void
bin_send(int sync)
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
            fatal(ID, "bin_mgr: msgsnd", errno);
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
kill_child(void)
{
    PROC_TABLE *tbl = &Shm->ptbl[ID];
    int status;
    pid_t ret;

    if (Shm->mode & PIPE_MODE)
        close(Shm->win_pipe[ID_TO_PIPE]);

    tbl->i_stat |= IO_DYING;
    tbl->time_to_die++;

    if (tbl->time_to_die > 1)
        return;

    if (tbl->bin_child && (tbl->BP->cmdflags & WAIT)) {
        return;
    }

    if (tbl->bin_child) {
       Kill(tbl->bin_child, SIGKILL, "B3", K_IO(ID)); /* Make sure it's dead. */
	while ((ret = waitpid(tbl->bin_child, &status, WNOHANG)) != 
	   tbl->bin_child){
	   if (Kill(tbl->bin_child, 0, "B4", K_IO(ID)) != 0)
		break;
           bin_cleanup(ID, INTERNAL);
           Kill(tbl->bin_child, SIGKILL, "B5", K_IO(ID));
	}
    }

    bin_cleanup(ID, INTERNAL);
    tbl->i_stat &= ~IO_DYING;
    tbl->i_stat |= IO_DEAD;

    set_time_of_death(ID);

    sigset(SIGHUP, SIG_IGN);
    kill(-getpgrp(), SIGHUP);

    _exit(BIN_KILL_CHILD);  /* NOTREACHED */
}

/*
 *  Clean up any tmp files that belong to BIN_TEST "i".
 *  This is called from external routines, so the use of "ID" is
 *  inappropriate; 
 */
int
bin_cleanup(int i, int originator)
{
    DIR *dirp;
    struct dirent *dp;
    PROC_TABLE *tbl = &Shm->ptbl[i];
    char lookfor[MESSAGE_SIZE];
    char entry[MESSAGE_SIZE];
    int found = 0;
    int retry = 0;

    if (tbl->i_type != BIN_TEST)   /* shouldn't ever happen... */
	return(0);

    if ((originator == INTERNAL) && (tbl->BP->cmdflags & RM_TMP_FILES))
	rm_tmp_files(tbl->BP);

try_again:

    sprintf(lookfor, "/tmp/ux%06d_%02d", Shm->mompid, i+1);

    if (originator == EXTERNAL)
	delete_matching_files(filename(lookfor), i);

    found = 0;
    dirp = opendir("/tmp");
    for (dp = readdir(dirp); dp != (struct dirent *)NULL; dp = readdir(dirp)) {
        sprintf(entry, "/tmp/%s", dp->d_name);
        if (strncmp(lookfor, entry, strlen(lookfor)) == 0) {
            found++;
            delete_file(entry, originator == INTERNAL ? i : NOT_USED);
        }
    }
    closedir(dirp);

    if (!found)
        return(found+retry);

    dirp = opendir("/tmp");
    for (dp = readdir(dirp); dp != (struct dirent *)NULL; dp = readdir(dirp)) {
        sprintf(entry, "/tmp/%s", dp->d_name);
        if (strncmp(lookfor, entry, strlen(lookfor)) == 0) {
            if (retry++)
            Shm->stderr("\rbin_cleanup: cannot remove %s; retrying...\r\n", 
		entry);
            delete_file(entry, originator == INTERNAL ? i : NOT_USED);
            break;
        }
    }
    closedir(dirp);

    if (retry) {
        sleep(1);
        goto try_again;
    }

    return(found+retry);
}

static void
rm_tmp_files(struct bin_commands *bp)
{
    PROC_TABLE *tbl = &Shm->ptbl[ID];

    if (tbl->bin_flags & BIN_DEBUG)
	Shm->stderr("\r\n[ rm_tmp_files: %s ]", bp->cmd);

    delete_matching_files(filename(tbl->tmp_file), ID);
}

static char *
make_tmp_file(struct bin_commands *bp)
{
    register int i;
    char tmp[MESSAGE_SIZE];
    PROC_TABLE *tbl = &Shm->ptbl[ID];
    char *obj = bp->cmdpath;

    if (!(bp->cmdflags & FOLLOW)) 
	rm_tmp_files(bp);

    if (bp->cmdflags & DEFAULT_FILE_2) {
	sprintf(tbl->tmp_concat, "%s %s", tbl->tmp_default, tbl->tmp_default);
	/*
         * for potential 3 arg users...
	 */
	if (bp->cmdflags & DEFAULT_FILE) {
	    sprintf(tbl->tmp_concat, "%s %s %s", 
		tbl->tmp_default, tbl->tmp_default, tbl->tmp_default);
	}
	if (bp->cmdflags & DEV_NULL) {
            sprintf(tbl->tmp_concat, 
		"/dev/null %s %s", tbl->tmp_default, tbl->tmp_default);
	}
	return(tbl->tmp_concat);
    }

    if (bp->cmdflags & DEFAULT_FILE) {
	if (bp->cmdflags & DEV_NULL) {
	    sprintf(tbl->tmp_concat, "%s /dev/null", tbl->tmp_default);
	    return(tbl->tmp_concat);
	}
        return(tbl->tmp_default);
    }

    if (bp->cmdflags & DEV_NULL) 
	return("/dev/null");

    if (bp->cmdflags & DDHELP)
	return("--help");

    if (bp->cmdflags & LOCALHOST)
        return("localhost");

    if (bp->cmdflags & MAKE_UU_FILE) {
        FILE *fp;

        if ((fp = fopen(tbl->tmp_file, "w")) == (FILE *)NULL) {
            i = errno;
            bin_cleanup(ID, INTERNAL);
            sprintf(tmp, "fopen(%s)", tbl->tmp_file);
            fatal(ID, tmp, i);
        }
        fprintf(fp, "begin 644 %s\n`\nend\n", tbl->tmp_file_2);
        fclose(fp);
    }

    if (bp->cmdflags & MAKE_TMP_OBJ) {
        sprintf(tmp, "cp %s %s", obj, tbl->tmp_file);
tmpobj1:
        if (system(tmp)) {
	    if (errno == EAGAIN || errno == ENOENT || errno == EINTR) {
		bin_fork_failure(tbl, USEX_FORK_FAILURE);
                goto tmpobj1;
	    }
            i = errno;
            bin_cleanup(ID, INTERNAL);
	    fatal(ID, tmp, i);
        }
    }

    if (bp->cmdflags & MAKE_TMP_OBJ_2) {
        sprintf(tmp, "cp %s %s", obj, tbl->tmp_file_2);
tmpobj2:
        if (system(tmp)) {
            if (errno == EAGAIN || errno == ENOENT || errno == EINTR) {
		bin_fork_failure(tbl, USEX_FORK_FAILURE);
                goto tmpobj2;
            }
            i = errno;
            bin_cleanup(ID, INTERNAL);
	    fatal(ID, tmp, i);
        }
    }

    if (bp->cmdflags & MAKE_TMP_ASCII) {
        FILE *fp;
        if ((fp = fopen(tbl->tmp_file, "w")) == (FILE *)NULL) {
            i = errno;
            bin_cleanup(ID, INTERNAL);
            sprintf(tmp, "fopen(%s)", tbl->tmp_file);
            fatal(ID, tmp, i);
        }

	for (i = 0; i < 10; i++)
	    fprintf(fp, "abcdefghijklmnopqrstuvwxyz\n");
	fclose(fp);
    }

    if (bp->cmdflags & MAKE_TMP_CFILE) {
        FILE *fp;

	if ((fp = fopen(tbl->tmp_C_file, "w")) == (FILE *)NULL) {
            i = errno;
            bin_cleanup(ID, INTERNAL);
            sprintf(tmp, "fopen(%s)", tbl->tmp_C_file);
            fatal(ID, tmp, i);
        }
        fprintf(fp, "main() {return(0);}\n");
        fclose(fp);
        if (!(bp->cmdflags & (CONCAT_ARGS))) {
            return(tbl->tmp_C_file);
	}
    }

    if (bp->cmdflags & CONCAT_ARGS) {
        if (bp->cmdflags & MAKE_TMP_CFILE) {
            sprintf(tbl->tmp_concat, "%s %s", tbl->tmp_file, tbl->tmp_C_file);
            return(tbl->tmp_concat);
        }
        if (bp->cmdflags & (MAKE_TMP_NAME_2|MAKE_TMP_OBJ_2)) {
            sprintf(tbl->tmp_concat, "%s %s", tbl->tmp_file, tbl->tmp_file_2);
            return(tbl->tmp_concat);
        }
    }

    if (bp->cmdflags & MAKE_TMP_NAME_TWICE) {
        sprintf(tbl->tmp_concat, "%s/ux%06d_%02d %s/ux%06d_%02d", 
	    Shm->tmpdir, Shm->mompid, ID+1, 
	    Shm->tmpdir, Shm->mompid, ID+1);  
	return(tbl->tmp_concat);

    }

    if (bp->cmdflags & MAKE_GID_ARG) {
	sprintf(tbl->tmp_concat, "%d %s", getgid(), tbl->tmp_file);
	return(tbl->tmp_concat);
    }

    if (bp->cmdflags & MAKE_UID_ARG) {
	sprintf(tbl->tmp_concat, "%d %s", getuid(), tbl->tmp_file);
	return(tbl->tmp_concat);
    }

    return(tbl->tmp_file);
}

/*
 *  Allocate an array of bp's in which a random stuffing of pointers 
 *  to entries in the bin_commands[] is built.  Return the number of
 *  commands.
 */

static int
init_order(void)
{
    register int i, j, k;
    struct bin_commands *bp;
    int found = 0;
    int cnt = 0;
    PROC_TABLE *tbl = &Shm->ptbl[ID];
    char buf[STRINGSIZE];

    for (bp = &bin_commands[0]; bp->cmd != 0; bp++)
        cnt++;

    tbl->bin_order = (int *)malloc(cnt * sizeof(int));

    for (i = 0; i < cnt; i++)
        tbl->bin_order[i] = (int)NULLCHAR;

    j = k = 0;
    srand((Shm->mode & SYNC_BIN_TESTS) ? 1 : getpid()); 

    while (j < cnt) {
        i = rand() % cnt;
        if (tbl->bin_order[i] == (int)NULLCHAR) 
            tbl->bin_order[i] = j++;
        k++;
    }

    if (tbl->bin_flags & BIN_DEBUG) {
        Shm->stderr("\rcnt: %d  attempts: %d\r\n", cnt, k);
        for (i = 0; i < cnt; i++)
            Shm->stderr("[%3d]", tbl->bin_order[i]);
        Shm->stderr("\r\n");
        for (bp = &bin_commands[0]; bp->cmd != 0; bp++)
            Shm->stderr("[%s]", bp->cmd);
        Shm->stderr("\r\n");
    }

    for (i = 0; i < cnt; i++) {
        found = 0;
        for (j = 0; j < cnt; j++) {
            if (tbl->bin_order[j] == i)
                found++;
        }
        if (found != 1) {
            sprintf(buf, "init_order: found(%d): %d\n", i, found);
            fatal(ID, buf, 0);
        }
    }

    return(cnt);
}

static struct bin_commands *
find_cmd(char *command, int offset, int flag)
{
    struct bin_commands *bp;
    char buf[STRINGSIZE];

    for (bp = &bin_commands[offset]; bp->cmd != 0; bp++) {
        if (bp->cmdflags & (NOT_FOUND|BIN_EXCLUDED))
	    continue;

        if (streq(get_command_name(bp, buf), command)) {
            if (flag == LEADER) {
                while(bp->cmdflags & FOLLOW) {
                    bp--;
		}
            }
            return(bp);
        }
    }

    return((struct bin_commands *)NULL);
}

static struct bin_commands *
get_next_bp(void)
{
    PROC_TABLE *tbl = &Shm->ptbl[ID];

    if (tbl->cur_order == -1)
        tbl->cur_order = 0;
    else if (tbl->cur_bp->cmdflags & LEADER)
        return(++(tbl->cur_bp));
    else if ((tbl->cur_bp->cmdflags & FOLLOW) && 
	((tbl->cur_bp+1)->cmdflags & FOLLOW))      /* double follow??? */
        return(++(tbl->cur_bp));
    else if (++(tbl->cur_order) == tbl->max_cmds)
        tbl->cur_order = 0;

    tbl->cur_bp = &bin_commands[tbl->bin_order[tbl->cur_order]];
    while (tbl->cur_bp->cmdflags & FOLLOW) {
        if (++(tbl->cur_order) == tbl->max_cmds)
            tbl->cur_order = 0;
        tbl->cur_bp = &bin_commands[tbl->bin_order[tbl->cur_order]];
    }
        
    return(tbl->cur_bp);
}


void
bin_exclude(char *s)
{
    	struct bin_commands *bp;

	if (!WINDOW_MGR())
		Shm->ptbl[ID].bin_flags |= BIN_UPDATE;		

     	while ((bp = find_cmd(s, 0, LEADER))) {
		bp->cmdflags |= BIN_EXCLUDED;
            	if (bp->cmdflags & LEADER) {
                	bp++;
			bp->cmdflags |= BIN_EXCLUDED;
            	}
    	}
}

int
bin_exclusive(char *s)
{
    struct bin_commands *bp;
    char cmdbuf[STRINGSIZE];
    int found;

    if (!s) {
    	for (found = 0, bp = &bin_commands[0]; bp->cmd != 0; bp++) {
	    if (bp->cmdflags & BIN_EXCLUSIVE)
		found++;
	}

	if (!found && (bp->cmdflags & BIN_EXCLUSIVE)) {
            PROC_TABLE *tbl = &Shm->ptbl[ID];
	    if (CURSES_DISPLAY()) {
	        sprintf(tbl->i_msgq.string, 
		    "%c%c[ERROR: no specified tests found]", 
		    FSIZE, tbl->i_local_pid);
	    }
	    if (GTK_DISPLAY()) {
	        sprintf(tbl->i_msgq.string, 
		    "%c%cERROR: no specified tests found", 
		    MANDATORY_FSHELL, tbl->i_local_pid);
	    }
            bin_send(SYNCHRONIZE);
	    Shm->ptbl[ID].i_stat |= USER_ERROR;
	    fatal(ID, "no specified tests found", 0);
	}

	return found;
    }

    if (!WINDOW_MGR()) 
	Shm->ptbl[ID].bin_flags |= BIN_UPDATE;		

    for (found = 0, bp = &bin_commands[0]; bp->cmd != 0; bp++) {
	if (bp->cmdflags & BIN_EXCLUSIVE)
	    continue;

        if (streq(s, get_command_name(bp, cmdbuf))) {
            if (bp->cmdflags & FOLLOW) {
    	 	bp->cmdflags |= BIN_EXCLUSIVE;
    		(bp-1)->cmdflags |= BIN_EXCLUSIVE;
    		found++;
    		continue;
    	    }
    
    	    if ((bp->cmdflags & (NO_SHOW|LEADER)) == (NO_SHOW|LEADER)) 
    		continue;
    	    
    	    bp->cmdflags |= BIN_EXCLUSIVE;
    	    found++;
    
            if (bp->cmdflags & LEADER) {
		bp++;
    		bp->cmdflags |= BIN_EXCLUSIVE;
	    }
        }
    }
                                    /* pass-through flag from usex.c is */
    bp->cmdflags |= BIN_EXCLUSIVE;  /* stored in the NULL-terminator bp */
                                    /* and is checked when s is NULL.   */
    return found;
}

static void
bin_bailout(char *s)
{
    PROC_TABLE *tbl = &Shm->ptbl[ID];

    bin_cleanup(ID, INTERNAL);
    if (tbl->time_to_die) {
	set_time_of_death(ID);
        _exit(BIN_BAILOUT);
    }
    else
	paralyze(ID, s, 0);
}

static void
fill_action(char *buf, char *cmd)
{
    register int j;

    if (CURSES_DISPLAY()) {
        sprintf(buf, "%s  [", cmd);
        for (j = strlen(buf); j < 58; j++) 
            buf[j] = ' ';
        buf[j-1] = ']';
        buf[j] = (char)NULLCHAR;
    }

    if (GTK_DISPLAY()) 
        sprintf(buf, "%s", cmd);
}

#ifdef USELESS
/*char *eagain = "usex: fork: Resource temporarily unavailable              ";*/
char *clean  = "                                                          ";
#endif

static void
bin_fork_failure(PROC_TABLE *tbl, int who)
{
    char eagain[80];
    int pad;

    sprintf(tbl->i_msgq.string, "%c%c<WARN>", 
	MANDATORY_FSTAT, tbl->i_local_pid);
    bin_send(SYNCHRONIZE);

    if (who == USEX_FORK_FAILURE) {
	sprintf(eagain, "usex: fork: %s", strerror(EAGAIN));
	if (CURSES_DISPLAY()) {
            pad = bin_pass_strlen(tbl->i_pass) <= 4 ? 58 :
                58 - (bin_pass_strlen(tbl->i_pass) - 4);
            space_pad(eagain, pad);
            sprintf(tbl->i_msgq.string, 
    	        "%c%c%s  %4ld <WARN>", MANDATORY_FSHELL, 
			tbl->i_local_pid, eagain, tbl->i_pass);
	}
        if (GTK_DISPLAY()) {
            sprintf(tbl->i_msgq.string, "%c%c%s",
                MANDATORY_FSHELL, tbl->i_local_pid, eagain);
        }
        bin_send(SYNCHRONIZE); 
    }

    sleep(5);

    sprintf(tbl->i_msgq.string, "%c%c %s ", 
	MANDATORY_FSTAT, tbl->i_local_pid,
	tbl->i_stat & IO_BKGD ? "BKGD" : " OK ");
    bin_send(0); 
}

static int
resource_unavailable(char *s, struct bin_commands *bp, PROC_TABLE *tbl)
{
    char *p;
    register int i;

    for (p = s; *p; p++) {
	switch (*p)
	{
	case 'E':
	    if (strncmp(p, "ERROR: Cannot fork",
                strlen("ERROR: Cannot fork")) == 0)
                    return(TRUE);
            if (strncmp(p, "ERROR: /bin/ls not executed",
                strlen("ERROR: /bin/ls not executed")) == 0)
                    return(TRUE);
	    if (strncmp(p, "ERROR: fork()",
                strlen("ERROR: fork()")) == 0)
                    return(TRUE);
            if (strncmp(p, "ERROR: No process",
                strlen("ERROR: No process")) == 0)
                    return(TRUE);
	    if (strncmp(p, "Error: no more processes",
		strlen("Error: no more processes")) == 0)
		    return(TRUE);
            break;

	case 'R':	
	    if (strncmp(p, "Resource temporarily",
	        strlen("Resource temporarily")) == 0)
		    return(TRUE);
	    break;

	case 'P':
	    if (strncmp(p, "Process table full",
	        strlen("Process table full")) == 0)
		    return(TRUE);
	    break;

	case 'O':
            if (strncmp(p, "Operation would block",
                strlen("Operation would block")) == 0)
                    return(TRUE);

        case 'N':
            if (strncmp(p, "Not enough space",
                strlen("Not enough space")) == 0)
                    return(TRUE);

        case 'I':
            if (strncmp(p, "Insufficient memory",
                strlen("Insufficient memory")) == 0)
                    return(TRUE);

        case 'C':
            if (strncmp(p, "Couldn't invoke sadc",
                strlen("Couldn't invoke sadc")) == 0)
                    return(TRUE);
            if (strncmp(p, "Cannot fork",
                strlen("Cannot fork")) == 0)
                    return(TRUE);
            break;

	default:
	    break;
	}
    }

    /*
     *  Special cases...
     */
    if (strncmp(bp->cmd, "timex", strlen("timex")) == 0) {
        for (i = 0; i < I_POSTAGE; i++) {
            p = tbl->i_last_message[i];
            if (strncmp(p, "Try again", strlen("Try again")) == 0) {
		if (CURSES_DISPLAY()) {
	            sprintf(tbl->i_msgq.string, 
               "%c%c/bin/timex  [Try again.                                  ]",
			 FSIZE, tbl->i_local_pid);
		}
		if (GTK_DISPLAY()) {
	            sprintf(tbl->i_msgq.string, "%c%cTry again",
			FSHELL, tbl->i_local_pid);
		}
		bin_send(0);
		return(TRUE);
	    }
        }
    }

    return(FALSE);
}


void
bin_test_inquiry(int target, FILE *fp)
{
        PROC_TABLE *tbl = &Shm->ptbl[target];
	char buf[STRINGSIZE];
	int others;

	fprintf(fp, "\nBIN TEST SPECIFIC:\n");
	fprintf(fp, 
	    "max_cmds: %d cmds_found: %d cmd_cnt: %d cmds_per_pass: %d\n",
		tbl->max_cmds, 
		tbl->cmds_found, tbl->cmd_cnt, tbl->cmds_per_pass);		

	dump_not_found(tbl, fp);
	dump_excluded(tbl, fp);
	dump_exclusive(tbl, fp);

	fprintf(fp, 
	"test_mod: %lx test_mod_list: %lx time_to_die: %d max_pass: %ld\n",
		(ulong)&tbl->test_mod, (ulong)tbl->test_mod_list,
		tbl->time_to_die, tbl->max_pass); 
	fprintf(fp,"bin_order: %lx cur_order: %d cur_bp: %lx bin_child: %d\n",
		(ulong)tbl->bin_order, tbl->cur_order, (ulong)tbl->cur_bp, tbl->bin_child);
	fprintf(fp, "null_cmd: %lx BP: %lx (\"%s\") ",
		(ulong)&tbl->null_cmd, (ulong)tbl->BP, 
		tbl->BP && (tbl->BP != &tbl->null_cmd) ? 
		get_command_name(tbl->BP, buf) : "");
	if (count_bits_long(tbl->bin_flags) > 1)
		fprintf(fp, "\n");
	fprintf(fp, "bin_flags: %lx (", tbl->bin_flags);
	others = 0;
	if (tbl->bin_flags & BIN_EXCL)
		fprintf(fp, "%sBIN_EXCL", others++ ? "|" : "");
	if (tbl->bin_flags & BIN_DEBUG)
		fprintf(fp, "%sBIN_DEBUG", others++ ? "|" : "");
	if (tbl->bin_flags & BIN_MON)
		fprintf(fp, "%sBIN_MON", others++ ? "|" : "");
	if (tbl->bin_flags & BIN_UPDATE)
		fprintf(fp, "%sBIN_UPDATE", others++ ? "|" : "");
	if (tbl->bin_flags & BIN_CLEAN)
		fprintf(fp, "%sBIN_CLEAN", others++ ? "|" : "");
	fprintf(fp, ")\n");
	fprintf(fp, "curcmd: \"%s\"\n", tbl->curcmd);
	fprintf(fp, "tmp_file: \"%s\"\ntmp_file_2: \"%s\"\n",
		tbl->tmp_file, tbl->tmp_file_2);
	fprintf(fp, "tmp_C_file: \"%s\"\ntmp_default: \"%s\"\n",
		tbl->tmp_C_file, tbl->tmp_default);
	fprintf(fp, "tmp_concat: \"%s\"\n", tbl->tmp_concat);
}

static void
dump_not_found(PROC_TABLE *tbl, FILE *fp)
{
	int others, cnt;
     	struct bin_commands *bp;
    	char buf[STRINGSIZE];

	fprintf(fp, "not_found: %d (", tbl->not_found);

    	for (others = cnt = 0, bp = &bin_commands[0]; bp->cmd != 0; bp++) {
		if (bp->cmdflags & NOT_FOUND) {
			cnt++;
			fprintf(fp, "%s%s", others++ ? "," : "", 
				get_command_name(bp, buf));
		}
	}
	fprintf(fp, ")\n");
}

static void 
dump_excluded(PROC_TABLE *tbl, FILE *fp)
{
	int others;
        struct bin_commands *bp;
        char buf[STRINGSIZE];
	char *delim;
	struct bin_test_mod *mp;

	fprintf(fp, "excluded: %d ", tbl->excluded);
	if (!tbl->excluded) {
		fprintf(fp, "\n");
		return;
	}
	fprintf(fp, "(");

        for (others = 0, bp = &bin_commands[0]; bp->cmd != 0; bp++) {
		delim = (bp->cmdflags & FOLLOW) ? "-" : ",";

		if (bp->cmdflags & BIN_EXCLUDED) {
			fprintf(fp, "%s%s", others++ ? delim : "", 
				get_command_name(bp, buf));
		}

        	for (mp = tbl->test_mod_list; mp; mp = mp->next) {
			if ((mp->bp == bp) && (mp->cmdflag & BIN_EXCLUDED)) {
				fprintf(fp, "%s%s", others++ ? delim : "", 
					get_command_name(bp, buf));
			}
		}
        }

	fprintf(fp, ")\n");
}

static void
dump_exclusive(PROC_TABLE *tbl, FILE *fp)
{
        int others;
        struct bin_commands *bp;
        char buf[STRINGSIZE];
        char *delim;
        struct bin_test_mod *mp;

        fprintf(fp, "exclusive: %d ", tbl->exclusive);
        if (!tbl->exclusive) {
                fprintf(fp, "\n");
                return;
        }
        fprintf(fp, "(");

        for (others = 0, bp = &bin_commands[0]; bp->cmd != 0; bp++) {
                delim = (bp->cmdflags & FOLLOW) ? "-" : ",";

                if (bp->cmdflags & BIN_EXCLUSIVE) {
                        fprintf(fp, "%s%s", others++ ? delim : "",
                                get_command_name(bp, buf));
                }

                for (mp = tbl->test_mod_list; mp; mp = mp->next) {
                        if ((mp->bp == bp) && (mp->cmdflag & BIN_EXCLUSIVE)) {
                                fprintf(fp, "%s%s", others++ ? delim : "",
                                        get_command_name(bp, buf));
                        }
                }
        }

        fprintf(fp, ")\n");
}


/*
 *  This routine is called twice -- once by the window manager on behalf
 *  of all bin tests (so the command path search only has to be done once),
 *  and then by each test to determine the not_found and excluded counts.
 *  Note that the second per-test call is quick because command_location() 
 *  only has to return bit-flag settings the second time it is called.
 */
static int
search_for_commands(PROC_TABLE *tbl)
{
	int cnt, location;
        struct bin_commands *bp;

        for (bp = &bin_commands[0]; bp->cmd != 0; bp++) {
		switch (location = command_location(bp))
		{
		case BIN:
		case USR_BIN:
		case USR_UCB:
		case USR_SBIN:
			bp->cmdflags |= location;
                        if (bp->cmdflags & BIN_EXCLUSIVE) {
				if (tbl)
					tbl->exclusive++;
                        }
			break;

		default:
			if (bp->cmdflags & BIN_EXCLUDED) {
				if (tbl) 
					tbl->excluded++;
				break;
			}

			if (tbl)
				tbl->not_found++;

			bp->cmdflags |= NOT_FOUND;
			if (bp->cmdflags & LEADER) {
				(bp+1)->cmdflags &= ~LOCATIONS;
				(bp+1)->cmdflags |= NOT_FOUND;
				if (tbl)
					tbl->not_found++;
			}
			if (bp->cmdflags & FOLLOW) {
				(bp-1)->cmdflags &= ~LOCATIONS;
				(bp-1)->cmdflags |= NOT_FOUND;
				if (tbl)
					tbl->not_found++;
			}
			break;
		}
	}

        for (cnt = 0, bp = &bin_commands[0]; bp->cmd != 0; bp++) {
		if (bp->cmdflags & NOT_FOUND)
			continue;
		cnt++;
	}

	return cnt;
}


static int
command_location(struct bin_commands *bp)
{
        char path[STRINGSIZE];
        char cmd[STRINGSIZE];

	if (bp->cmdflags & (NOT_FOUND|BIN_EXCLUDED))
		return FALSE;

	if (bp->cmdflags & BIN_LOCATION)
		return (bp->cmdflags & BIN_LOCATION);

	get_command_name(bp, cmd);

        sprintf(path, "/bin/%s", cmd);
	if (file_exists(path)) 
		return BIN;

        sprintf(path, "/usr/bin/%s", cmd);
	if (file_exists(path)) 
		return USR_BIN;

        sprintf(path, "/usr/ucb/%s", cmd);
	if (file_exists(path)) 
		return USR_UCB;

        sprintf(path, "/usr/sbin/%s", cmd);
	if (file_exists(path)) 
		return USR_SBIN;

	return FALSE;
}

int
bin_test_exists(char *cmd)
{
	char bpcmd[STRINGSIZE];
	struct bin_commands *bp;

        for (bp = &bin_commands[0]; bp->cmd != 0; bp++) {
		get_command_name(bp, bpcmd);
		if (streq(cmd, bpcmd)) 
			if (command_location(bp) & BIN_LOCATION)
				return TRUE;
	}
	return FALSE;
}

static char *
get_command_name(struct bin_commands *bp, char *buf)
{
        register int i;
        char *p1;

        for (i = 0, p1 = bp->cmd; *p1; i++, p1++) {
                if (*p1 == ' ')
                        break;
                buf[i] = *p1;
        }
        buf[i] = NULLCHAR;

	return buf;
}

/*
 *  Update the window manager with bin test command modifications made
 *  locally.  The window manager will call bin_test_mod_callback() in
 *  its own context to update the appropriate bin_test_mod_list.
 */
static void
sync_with_window_mgr(PROC_TABLE *tbl)
{
	struct bin_commands *bp;

        for (bp = &bin_commands[0]; bp->cmd != 0; bp++) {
		if (bp->cmdflags & BIN_EXCLUSIVE) {
			tbl->test_mod.bp = bp;
			tbl->test_mod.cmdflag = BIN_EXCLUSIVE;
            		sprintf(tbl->i_msgq.string, 
				"%c%c", BIN_TEST_MOD, tbl->i_local_pid);
			bin_send(SYNCHRONIZE);
		}
		if (bp->cmdflags & BIN_EXCLUDED) {
                        tbl->test_mod.bp = bp;
                        tbl->test_mod.cmdflag = BIN_EXCLUDED;
            		sprintf(tbl->i_msgq.string, 
				"%c%c", BIN_TEST_MOD, tbl->i_local_pid);
			bin_send(SYNCHRONIZE);
		}
	}
}

void
bin_test_mod_callback(PROC_TABLE *tbl)
{
	struct bin_test_mod *mp, *mpn;
	struct bin_commands *bp;
	ulong flag;

	bp = tbl->test_mod.bp;
	flag = tbl->test_mod.cmdflag;

	if ((bp->cmdflags & flag) == flag) 
		return;

	if ((mp = malloc(sizeof(struct bin_test_mod))) == NULL) {
		USER_MESSAGE("malloc failure (struct bin_test_mod)");
		return;
	}

	mp->bp = bp;
	mp->cmdflag = flag;
	mp->next = NULL;

	if ((mpn = tbl->test_mod_list)) {
		while (mpn->next)
			mpn = mpn->next;
		mpn->next = mp;
	} else
		tbl->test_mod_list = mp;
}

static void
size_command_window(PROC_TABLE *tbl)
{
	char buf[MESSAGE_SIZE];
        int location, maxlen, dirsize;
        struct bin_commands *bp;

	maxlen = 0;
        for (bp = &bin_commands[0]; bp->cmd != 0; bp++) {
                switch (location = command_location(bp))
                {
                case BIN:
			dirsize = 5;    /* strlen("/bin/") */
			break;
                case USR_BIN:
			dirsize = 9;
                        break;
                case USR_UCB:
			dirsize = 9;
                        break;
                case USR_SBIN:
			dirsize = 10;
                        break;
		default:
			dirsize = 0;
			continue;
		}

		maxlen = MAX(maxlen, 
			dirsize + strlen(get_command_name(bp, buf)));
	}

	tbl->i_limit = maxlen;
}

static void 
do_cmd_specific(void)
{
	struct bin_commands *bp;

    	for (bp = &bin_commands[0]; bp->cmd != 0; bp++) {
		if (!(bp->cmdflags & CMD_SPECIFIC))
			continue;
		if (streq(bp->cmd, "ar")) {
			if (file_exists("/usr/lib64/libc.a"))
				bp->cmd = "ar -tv /usr/lib64/libc.a";		
			else if (file_exists("/usr/lib/libc.a"))
				bp->cmd = "ar -tv /usr/lib/libc.a";		
			else
				bp->cmd = "ar --help";		
		}
		console("bp->cmd: [%s]\n", bp->cmd);
	}

}
