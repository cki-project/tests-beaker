/*  Author: David Anderson <anderson@redhat.com> */

/*
 *  usex.c
 *
 *  main:  The invocation module for USEX as a whole.  It gathers the user 
 *         test parameters, and then forks off all of the test processes.
 *         The mother process remains as the window manager, running the
 *         output display's window_manager function.  Currently there are
 *         two output displays, curses and GTK.
 *
 *  BitKeeper ID: @(#)usex.c 1.7
 *
 *  CVS: $Revision: 1.17 $ $Date: 2016/02/10 19:25:53 $
 */

#include "defs.h"
#include <unistd.h>
#include <getopt.h>
#include <sys/prctl.h>

struct shm_buf *Shm;            /* The locus of control */
int ID;                         /* The index into the process table. */

static void resolve_term(void);
static void get_environment(void);
static void resolve_rc_cmd(char *);
static void wait_for_release(void);
static void prompt(void);
static void getstring(char *);
static void make_IO_record(void);
static void ctrl_c(void);
static int make_usex_input(int, int);
static void start_shell(int, char **);
static void usage(void);
static void usex_kill(void);
static long long getmode(void);
static void do_binargs(char *);
static void do_rhts(char *);
static void do_exclude(char *);
static void do_nolog(char *);
static void do_vmem(char *);
static void do_io(char *);
static void make_reportfile(void);
static void nodisplay_setup(int, char **);
static void argv_preview(int, char **);
static void print_die_code(int, FILE *, int);
static void make_spec_file(void);

static struct option long_options[] = {
        {"binargs", 1, 0, 0},
        {"exclude", 1, 0, 0},
        {"vmem", 1, 0, 0},
        {"io", 1, 0, 0},
        {"nolog", 1, 0, 0},
        {"help", 0, 0, 0},
        {"nodisplay", 0, 0, 0},
        {"core", 0, 0, 0},
	{"sys", 0, 0, 0},
	{"system", 0, 0, 0},
        {"nostats", 0, 0, 0},
        {"win", 1, 0, 0},
        {"spec", 0, 0, 0},
        {"version", 0, 0, 0},
        {"rhts", 1, 0, 0},
        {0, 0, 0, 0}
};

#define USEX_OPTIONS "kl:whDICLqn:vebMSPR:rdcp:o:i:?x:H:t:T:V:s:X"

static struct option_override {      /* over-rides input file settings */
	int time_to_kill;
	char *transfer_rate_device;
	int nolog;
} option_override = { 0 };

static struct shm_buf shm_tmp_buffer = { 0 };

int
main(int argc, char **argv)
{
    register int i, j;               /* General registers. */
    int dummy[NUMSG];  
    int buffer_location;	     /* shared memory or mmap'd memory      */
    char id = FIRST_ID;              /* Local_pid's kept in ASCII value.    */
    struct shm_buf *shm_tmp;
    char dash_e = 0;                 /* needed for -t or -T override        */
    char dash_b = 0;                 /* needed for -T override              */
    int tcnt;                        /* test count for -E or -B             */
    int catch_sigsegv = TRUE;        /* for debugging usex itself           */
    int option_index = 0;

   /*
    *  A temporary "shared memory" buffer is actually not shared at all,
    *  but need during pre- and post-setup of whatever shared scheme is
    *  eventually put into place. 
    */
    shm_tmp = &shm_tmp_buffer;
    Shm = shm_tmp;
    Shm->mode = INITIALIZED;        

    window_manager_init(&argc, &argv);  /* Initialize the window manager */

    resolve_term();     /* Make sure it's worth going ahead at all... */
    
    Shm->procno = -1;

    nodisplay_setup(argc, argv);     /* Look for --nodisplay */

    start_shell(argc, argv);	     /* Make /bin/sh parent of usex.        */

    Shm->shm_tmp = shm_tmp;
    Shm->mompid = getpid();
    Shm->shm_size = sizeof(struct shm_buf);

#ifdef MAP_SHARED
    Shm->mode |= MMAP_MODE;
    buffer_location = MMAP_MODE;
#else
    Shm->mode |= SHMEM_MODE;
    buffer_location = SHMEM_MODE;
#endif

    get_environment();  /* Get environment variables and .usexrc contents. */

    process_list(PS_LIST_INIT, NULL);  /* Stash the current list of procs */

    if (!Shm->logfile)
        Shm->logfile = "/dev/null";

    if (!Shm->reportfile)
        Shm->reportfile = "/dev/null";

    sprintf(Shm->default_file, "/tmp/ux%06d", Shm->mompid);
    sprintf(Shm->tmpdir, "/tmp/ux%06d_tmp", Shm->mompid);
    Shm->ux_IO[0] = 0;

    Shm->stallvalue = UNSET_STALLVALUE;
    if (!Shm->hangtime)
        Shm->hangtime = DEFAULT_HANGTIME;

    argv_preview(argc, argv);

    opterr = 0;
    while((i = getopt_long(argc, argv, USEX_OPTIONS,
	                    long_options, &option_index)) != -1) {
        switch (i)
        {
        case 0:
		if (streq(long_options[option_index].name, "binargs")) {
			do_binargs(optarg);
			break;
		}

		if (streq(long_options[option_index].name, "rhts")) {
			do_rhts(optarg);
			break;
		}

                if (streq(long_options[option_index].name, "exclude")) {
                        do_exclude(optarg);
                        break;
                }

                if (streq(long_options[option_index].name, "nolog")) {
                        do_nolog(optarg);
                        break;
                }

                if (streq(long_options[option_index].name, "vmem")) {
                        do_vmem(optarg);
                	if (dash_e) {
                        	i = dash_e;
                        	goto redo_dash_e;
                	}
                        break;
                }

                if (streq(long_options[option_index].name, "io")) {
                        do_io(optarg);
                        break;
                }

                if (streq(long_options[option_index].name, "help")) {
                        usage();
			quick_die(QDIE(1));
                }

                if (streq(long_options[option_index].name, "nodisplay")) {
			Shm->mode |= NODISPLAY;  /* already done */
			break;
                }

                if (streq(long_options[option_index].name, "core")) {
                        Shm->mode |= DROPCORE; 
                        break;
                }

                if (streq(long_options[option_index].name, "nostats")) {
                        Shm->mode |= NO_STATS;
                        break;
                }

                if (streq(long_options[option_index].name, "sys") ||
		    streq(long_options[option_index].name, "system")) {    
                        Shm->mode |= SYS_STATS;
                        break;
                }

                if (streq(long_options[option_index].name, "win")) {
                        Shm->win_specific(optarg);
                        break;
                }

                if (streq(long_options[option_index].name, "spec")) {
			make_spec_file();
			_exit(NORMAL_EXIT);
                }

                if (streq(long_options[option_index].name, "version")) 
			goto show_version;

                break;

        case 'v':
show_version:
                Shm->printf("UNIX System EXerciser (USEX)  Version ");
                Shm->printf(USEX_VERSION);
                Shm->printf("\n");
                quick_die(QDIE(8));

        case 'k':
                usex_kill();
		_exit(NORMAL_EXIT);

	case 'T':
		option_override.time_to_kill = atoi(optarg);
		break;

	case 's':
		if (strneq(optarg, "ys")) {
                        Shm->mode |= SYS_STATS;
			break;
		} else if (decimal(optarg, 0)) {
			Shm->stallvalue = atol(optarg);
		} else {
                	Shm->printf ("usex: invalid -s argument\n");
                	Shm->printf("enter \"usex -h\" for help\n");
                	quick_die(QDIE(9));
		}
		break;

	case 'I':
		Shm->mode |= IGNORE_BIN_EXIT;
		break;

	case 'D':
                catch_sigsegv = FALSE;
                break;

	case 'l':
	case 'L':
		Shm->logfile = optarg;
	        break;

	case 'R':
		Shm->reportfile = optarg;
		break;

	case 'q':
		Shm->mode |= QUIET_MODE;
		break;

	case 'r':
		Shm->mode |= NO_REFRESH_MODE;
		break;

	case 'n':
		Shm->niceval = atoi(optarg);
		if (Shm->niceval < -10)
		    Shm->niceval = -10;
		else if (Shm->niceval > 19)
		    Shm->niceval = 19;
		break;

	case 'C':
                if (chk_leftovers(!QUERY) == 0) {
                    Shm->printf("No leftovers detected.  ");
		    j = 2;
		} else
		    j = 4;
                if (Shm->directories_found) {
                    Shm->printf("%d director%s not removed.", 
		        Shm->directories_found,
                        Shm->directories_found == 1 ? "y was" : "ies were");
                }
		Shm->printf("\n");
		sleep(Shm->mode & NOTTY ? 0 : j);
                break;

        case 'c':
		if (chk_leftovers(QUERY) == 0) 
		    Shm->printf("No leftovers detected.  ");
                if (Shm->directories_found) {
                    Shm->printf("%d director%s not removed.", 
			Shm->directories_found,
		        Shm->directories_found == 1 ? "y was" : "ies were");
                }
                Shm->printf("\n");
		quick_die(QDIE(2));

	case 'h':
		usage();
		quick_die(QDIE(3));
	
	case 'H':
		if ((Shm->hangtime = atoi(optarg)) == 0)
			Shm->hangtime = DEFAULT_HANGTIME;
		else
	             Shm->hangtime *= 60;
		break;

        case 'd':
                Shm->mode |= DEBUG_MODE;
                break;

        case 'i':
		if (dash_b || dash_e) {
		       	Shm->printf("usex: -i and -%c are mutually exclusive\n",
			    dash_b ? dash_b : dash_e);
			quick_die(QDIE(29));
		}
                Shm->infile = optarg;
                break;

        case 'o':
                Shm->outfile = optarg;
		break;

	case 'e':
		if (!dash_b && Shm->infile) {
                        Shm->printf("usex: -i and -e are mutually exclusive\n");
                        quick_die(QDIE(29));
		}
redo_dash_e:
		if (dash_b) {
		       Shm->printf("usex: -b and -e are mutually exclusive\n");
			quick_die(QDIE(4));
		}
		dash_e = (char)i;
                Shm->infile = Shm->outfile ?
                        Shm->outfile : Shm->default_file;
                if (!make_usex_input(i, Shm->hanging_tcnt)) 
                        quick_die(QDIE(5));
                Shm->mode |= AUTO_INFILE;
		break;

	case 'b':
		if (dash_e) {
                       Shm->printf("usex: -e and -b are mutually exclusive\n");
                        quick_die(QDIE(6));
                }

                if (Shm->infile) {
                        Shm->printf("usex: -i and -b are mutually exclusive\n");
                        quick_die(QDIE(29));
                }

		dash_b = (char)i;
		Shm->infile = Shm->outfile ? 
			Shm->outfile : Shm->default_file;
		if (!make_usex_input(i, Shm->hanging_tcnt)) 
		        quick_die(QDIE(7));    
	        Shm->mode |= AUTO_INFILE;
		break;

  	case 'p':
		Shm->pattern = optarg;
		break;

	case 'P':
                Shm->mode &= ~(SHMEM_MODE|MESGQ_MODE|MMAP_MODE);
                Shm->mode |= PIPE_MODE;
		break;

	case 'S':
                Shm->mode &= ~(PIPE_MODE|MESGQ_MODE|MMAP_MODE);
                Shm->mode |= SHMEM_MODE;
		break;

        case 'M':
                Shm->mode &= ~(PIPE_MODE|SHMEM_MODE|MMAP_MODE);
	        Shm->mode |= MESGQ_MODE;

		/*
                 * Fork off 16 quick-dying processes so that another "usex" 
		 * can run on another terminal without the msg queue id numbers
		 * conflicting with one another.                    
		 *
		 * NOTE: I've long since forgotten what this is all about... 
		 *       (Was it a GENICS problem?)
	 	 */
                for (i = 0; i < NUMSG; i++)
                    if ((dummy[i] = fork()) == 0)
                        pause();                
                for (i = 0; i < NUMSG; i++) {
                    Kill(dummy[i], SIGKILL, "U1", K_OTHER);
                    wait(NULL);
                }
                break;

	case 't':
		option_override.transfer_rate_device = optarg;
		if (dash_e) {
			i = dash_e;
			goto redo_dash_e;
		}
		break;

	case 'V':
		Shm->vmem_size = atoi(optarg);
		if (dash_e) {
			i = dash_e;
			goto redo_dash_e;
		}
		break;

	case 'x':
		do_exclude(optarg);
		break;

	case 'w':
		if (mlockall(MCL_CURRENT|MCL_FUTURE) == 0) 
			Shm->mode |= MLOCK_MODE;
		else {
			Shm->perror("window manager not wired: mlockall");
			sleep(2);
		}
		break;

	case 'X':
		break;

        case '?':
        default:
        	Shm->printf ("usex: invalid command line option\n");
		Shm->printf("enter \"usex -h\" for help\n");
		quick_die(QDIE(9));
        }
    }

    if (optind < argc) {
	if (((optind+1) == argc) && !Shm->hanging_tcnt &&
	    (decimal(argv[optind], 0) && (tcnt = atoi(argv[optind]))) &&
	    (dash_b || dash_e)) {
                if (!make_usex_input(dash_b ? dash_b : dash_e, tcnt)) 
                        quick_die(dash_e ? QDIE(5) : QDIE(7));
	} else {
            Shm->printf ("usex: invalid arguments: ");
            while (optind < argc)
                Shm->printf ("%s ", argv[optind++]);
            Shm->printf("\n");
	    Shm->printf("enter \"usex -h\" for help\n");
	    quick_die(QDIE(10));
	}
    }

    console_init(0);    /* Initialize the console (debug) device */

    LOG(NOARG, LOG_START, NOARG, NULL);

    if ((Shm->mode & SHMEM_MODE) || (buffer_location == SHMEM_MODE)) {
        if ((Shm->shmid = shmget(IPC_PRIVATE, sizeof(struct shm_buf),
            0666 | IPC_CREAT)) == -1) {
            Shm->perror("usex: shmget");
            _exit(SHMGET_ERROR);
        }

        if ((Shm->shm_addr = (char *)shmat(Shm->shmid, 0, 0)) == (char *)(-1)) {
            Shm->perror("usex: shmat");
            if (shmdt(Shm->shm_addr) == -1)
                Shm->perror("usex: shmdt");
            if (shmctl(Shm->shmid, IPC_RMID, (struct shmid_ds *)NULL) == -1)
                Shm->perror("usex: shmctl");
            _exit(SHMAT_ERROR);
        }
        bcopy(shm_tmp, Shm->shm_addr, sizeof(struct shm_buf));
        Shm = (struct shm_buf *)Shm->shm_addr;
    }
    else if (buffer_location == MMAP_MODE) {
#ifdef MAP_SHARED
	Shm = (struct shm_buf *)-1;
#ifdef MAP_ANONYMOUS
        if ((Shm = (struct shm_buf *)mmap((void *) 0,
            sizeof(struct shm_buf), (PROT_READ | PROT_WRITE),
            MAP_ANONYMOUS|MAP_SHARED, -1, 0)) != (struct shm_buf *)-1) {
            bcopy(shm_tmp, Shm, sizeof(struct shm_buf));
	    Shm->mode |= MMAP_ANON;
        }
#endif /* MAP_ANONYMOUS */
        if (Shm == (struct shm_buf *)-1 && file_exists("/dev/zero")) {
	    Shm = shm_tmp;
	    if ((Shm->mmfd = open("/dev/zero", O_RDWR, 0777)) < 0) {
                Shm->perror("/dev/zero");
                quick_die(QDIE(11));
            }
            if ((Shm = (struct shm_buf *)mmap((void *) 0,
                sizeof(struct shm_buf), (PROT_READ | PROT_WRITE),
                MAP_SHARED, Shm->mmfd, 0)) != (struct shm_buf *)-1) {
	        bcopy(shm_tmp, Shm, sizeof(struct shm_buf));
		Shm->mode |= MMAP_DZERO;
            } else {
		close(shm_tmp->mmfd);
	    }
	}
	if (Shm == (struct shm_buf *)-1) {
	    Shm = shm_tmp;
	    if ((Shm->mmfd = open(Shm->id_file, O_CREAT|O_RDWR, 0777)) < 0) {
                Shm->perror(Shm->id_file);
                quick_die(QDIE(12));
            }
            delete_file(Shm->id_file, NOT_USED);  
            if (write(Shm->mmfd, shm_tmp, sizeof(struct shm_buf)) !=
                sizeof(struct shm_buf)) {
                Shm->perror(Shm->id_file);
                quick_die(QDIE(13));
            }
            if ((Shm = (struct shm_buf *)mmap((void *) 0,
                sizeof(struct shm_buf), (PROT_READ | PROT_WRITE),
                MAP_SHARED, Shm->mmfd, 0)) < (struct shm_buf *)0) {
                Shm->perror("mmap");
                quick_die(QDIE(14));
            }
	    Shm->mode |= MMAP_FILE;
	}
#else
        Shm->stderr( 
            "This machine does not support mmap operations on a file.\n");
	quick_die(QDIE(15));
#endif
    }

    /*
     *  Find out the real geometry -- make sure it's at least 80x24.
     */
    get_geometry();

    /*
     *  Give the user information regarding potential leftovers.
     */
    if (!(Shm->mode & (QUIET_MODE|NODISPLAY)) && chk_leftovers(QUERY))
	sleep(Shm->mode & NOTTY ? 0 : 2);

    if ((strcmp(getenv("TERM"), "AT386") == 0) || /* Get ready for AT kludge. */
        (strcmp(getenv("TERM"), "at386") == 0) ||
        (strcmp(getenv("TERM"), "a386") == 0))
        Shm->mode |= AT_KLUDGE;

    sigset(SIGINT, die);      /* Set up to die with dignity.       */
    sigset(SIGBUS, die);

    if (catch_sigsegv)
    	 sigset(SIGSEGV, die); 

    sigset(SIGILL, die);

    prompt();                     /* Get the parameters from the user. */

    if (option_override.time_to_kill)
	Shm->time_to_kill = option_override.time_to_kill*60;

    if (NO_DISPLAY() && !Shm->time_to_kill)
	quick_die(QDIE(16));

    switch (Shm->mode & IPC_MODE)
    {
    case PIPE_MODE:                 
        for (i = 0; i < NUMSG*2; i++) 
	    Shm->win_pipe[i] = -1;

        for (i = 0; i < Shm->procno; i++) 
            pipe(&Shm->win_pipe[i*2]); 
	break;
    
    case MESGQ_MODE:
        for (i = 0; i < NUMSG; i++) 
            Shm->msgid[i] = -1;

        for (i = 0; i < Shm->procno; i++) {
            if ((Shm->msgid[i] = msgget(Shm->mompid+i, 0666 | IPC_CREAT)) == -1)
            {
                Shm->perror("usex: msgget");
                die(0, DIE(2), FALSE);
            }
            else {
                Shm->ptbl[i].i_msgq.type = 1;
                Shm->ptbl[i].i_msg_id = Shm->msgid[i];
            }
        }
        break;
 
    case MMAP_MODE:
    case SHMEM_MODE: 
	ring_init();
        break;

    default:
        Shm->stderr("usex: invalid IPC mode: %x\n", Shm->mode);
        die(0, DIE(3), FALSE);
	
    }

    uname(&Shm->utsname);   /* Gather this for future reference. */

    if (mkdir(Shm->tmpdir, 0777) == -1) {
        Shm->perror("mkdir");
        sprintf(Shm->tmpdir, "/tmp");
    }

    /*
     *  Stash a copy of a designated outfile in the global tmp directory
     *  for use by bin tests.
     */
    if (Shm->outfile) {
    	if (!file_copy(Shm->outfile, Shm->tmpdir)) {
            Shm->stderr("\n\nusex: cannot copy %s to %s\n", 
		Shm->outfile, Shm->tmpdir);
            die(0, DIE(4), FALSE);
        }
    }

    /* The loop below initializes the individual process tables and */
    /* then forks off a process for each test file exercise.        */

    sigset(SIGINT, ctrl_c); /* Force user to die the right way from now on... */

    Shm->mode |= CHILD_HOLD;  /* Make the children wait til mother's ready. */

    sigset(SIGCHLD, sigchld);  /* Keep children from defunctizing.  */

    for (i = 0; i < Shm->procno; ++i)
    {
        /* Initialize each process table. */

        Shm->ptbl[i].i_local_pid = id++;          /* Insert unique local id. */
	if (Shm->mode & BKGD_MODE)
	    Shm->ptbl[i].i_stat |= IO_BKGD; 

        if (Shm->ptbl[i].i_type == USER_TEST) {
            if ((Shm->ptbl[i].i_pid = fork ()) == 0) {    /* fork it now... */
                Shm->ptbl[i].i_pid = getpid();
		wait_for_release();
                sigset(SIGALRM, block);
                shell_mgr(i);
                _exit(SHELL_MGR_FAILED);       /* not reached */
            }
            else if (Shm->ptbl[i].i_pid == -1) { /* The fork() call died! */
		Shm->ptbl[i].i_saved_errno = errno;
		sprintf(Shm->ptbl[i].i_fatal_errmsg,
		    "fork: %s", strerror(Shm->ptbl[i].i_saved_errno));
		Shm->ptbl[i].i_stat |= IO_FORK;
            }
            continue;
        }

        if (Shm->ptbl[i].i_type == BIN_TEST) {
            if ((Shm->ptbl[i].i_pid = fork ()) == 0) {    /* fork it now... */
                Shm->ptbl[i].i_pid = getpid();
		wait_for_release();
                sigset(SIGALRM, block);
                bin_mgr(i);
                _exit(BIN_MGR_FAILED);       /* not reached */
            }
            else if (Shm->ptbl[i].i_pid == -1) { /* The fork() call died! */
		Shm->ptbl[i].i_saved_errno = errno;
                sprintf(Shm->ptbl[i].i_fatal_errmsg,
                    "fork: %s", strerror(Shm->ptbl[i].i_saved_errno));
		Shm->ptbl[i].i_stat |= IO_FORK;
            }
            continue;
        }

        if ((Shm->ptbl[i].i_pid = fork ()) == 0)      /* Now fork it... */
        {
            Shm->ptbl[i].i_pid = getpid();

           /*
            * If a directory was entered, create the "regular" file name,
            * delete it if it already exists, and copy it into the ptbl
            * structure.  If a raw device was entered, just make the copy.
            */

            if ((Shm->ptbl[i].i_sbuf.st_mode & S_IFMT) == S_IFDIR)
            {
                sprintf(Shm->ptbl[i].i_file, "%s%sux%06d_%02d", 
                    Shm->ptbl[i].i_path,
                    strlen(filename(Shm->ptbl[i].i_path)) == 0 ? "" : "/", 
                    Shm->mompid, i+1);
                Shm->ptbl[i].i_message = file_exists(Shm->ptbl[i].i_file) ?
                    FILE_EXISTS : (int)NULLCHAR;
            }
            else
                sprintf(Shm->ptbl[i].i_file, "%s", Shm->ptbl[i].i_path);

            /* 
             * Create the associated ".err" filename; if it already exists
             * and shouldn't be there, unlink it.
             */
            sprintf(Shm->ptbl[i].i_errfile, "ux%06d_%02d.err", 
                Shm->mompid, i+1);
            if (Shm->ptbl[i].i_message != FILE_EXISTS && 
                file_exists(Shm->ptbl[i].i_errfile))
                delete_file(Shm->ptbl[i].i_errfile, NOT_USED);

	    wait_for_release();
            sigset(SIGALRM, block);
            io_test(i);
            _exit(IO_TEST_FAILED);      /* not reached */
        }
        else if (Shm->ptbl[i].i_pid == -1)  /* Whoa... the fork() call died! */
        {
 	    Shm->ptbl[i].i_saved_errno = errno;
            sprintf(Shm->ptbl[i].i_fatal_errmsg,
                "fork: %s", strerror(Shm->ptbl[i].i_saved_errno));
	    Shm->ptbl[i].i_stat |= IO_FORK;
        }

    }  /* End of for loop. */


    make_IO_record();   /* Make I/O file record for usex -c, if needed. */

    sigset(SIGUSR1, dump_status_signal);
    sigset(SIGUSR2, dump_status_signal);

    if (Shm->mode & MMAP_MODE && file_exists(Shm->id_file))
	delete_file(Shm->id_file, NOT_USED);  

   /*
    *  Let the output-specific window manager function take it from here. 
    */
    Shm->window_manager(argc, argv);   

    _exit(0);
}

/*
 *  Try to at least warn of impending doom if the TERM doesn't exist in
 *  /usr/lib/terminfo.  If TERM is not set at all, bail out now.
 */
void
resolve_term(void)
{
    char *tp, *ti;
    char term[STRINGSIZE];
    int tty_fd;

    if ((tty_fd = open("/dev/tty", O_RDONLY)) < 0) {
	Shm->mode |= NOTTY;
    } else
	close(tty_fd);

    if ((tp = getenv("TERM")) != 0 && *tp) {
	Shm->TERM = tp;
        if ((ti = getenv("TERMINFO")) != NULL)
            sprintf(term, "%s/%c/%s", ti, *tp, tp);
        else
            sprintf(term, "/usr/share/terminfo/%c/%s", *tp, tp);
        if (CURSES_DISPLAY() && !file_exists(term)) {
            Shm->stderr("usex: FATAL ERROR: %s not found in %s.\n", tp,
		ti ? ti : "/usr/share/terminfo");
            quick_die(QDIE(17));
        }
    }
    else if (CURSES_DISPLAY()) {
        Shm->stderr("usex: FATAL ERROR: TERM variable not set!\n");
        quick_die(QDIE(18));
    }
}

/*
 *  Wait until mother cuts the apron strings.
 */
static void
wait_for_release(void)
{
    sigset(SIGINT, SIG_DFL);   /* Restore handlers from mother's setup */
    sigset(SIGBUS, SIG_DFL);
    sigset(SIGSEGV, SIG_DFL);
    sigset(SIGILL, SIG_DFL);

    while (getmode() & CHILD_HOLD) 
	sleep(1);
}

static long long
getmode(void)
{
    unsigned volatile long long mode = Shm->mode;

    return(mode);
}

/*
 *  prompt: Called upon initialization by usex() in order to establish 
 *          parameters for the I/O and TRANSFER RATE tests.
 *          It asks for paths, command names, buffer sizes and
 *          limits as required for each I/O TEST requested by the user.  
 *          If none are requested, or after all applicable I/O TEST 
 *          parameters are entered, it asks for TRANSFER RATE test parameters.
 *          Finally it asks for clock granularity and display mode.
 */

static void
prompt(void)
{
    register int i, j;              /* General registers.                */
    unsigned int temp;              /* Temporary storage location.       */
    char input[256];                /* Storage for user input.           */
    char last_input[256];           /* Storage for previous user input.  */
    FILE *fi, *fo;                  /* Optional input or output files.   */
    char *ptr;
    BOOL raw_disk = FALSE;          /* Signals whether any raw devices.   */
    int limit_required = 0;         /* Signals whether any disk devices.  */
    int buffer_required = 0;        /* Signals whether buffer is needed.  */
    long last_disk_size = -1;       /* For last buffer size used.         */
    long last_rate_size = -1;
    int disk_size = 0;
    int vmem_size = 0;
    int rate_test;
    int fline = 0;		   
    int nolog;
    int io_fsync;

    if (NO_DISPLAY() && !Shm->infile)
	die(0, DIE(5), FALSE);

    clear_display_screen();

    if (!Shm->outfile) 
        Shm->outfile = Shm->default_file;

    if (Shm->infile && (strcmp(Shm->infile, Shm->outfile) == 0)) { 
        if ((fo = fopen("/dev/null", "w")) == NULL) {      /* usex -e or -b */
            Shm->perror(Shm->outfile);
            Shm->outfile = (char *)NULL;
        }
    } 
    else if ((fo = fopen(Shm->outfile, "w")) == NULL) {
            Shm->perror(Shm->outfile);
            Shm->outfile = (char *)NULL;
    }

    if (Shm->infile) {
        if ((fi = fopen(Shm->infile, "r")) == NULL) {
            Shm->perror(Shm->infile);
            Shm->procno = -1;
            die(0, DIE(6), FALSE);
        }
    }

    for (i = 0; i < MAX_IO_TESTS; i++)
        Shm->ptbl[i].i_pid = NOT_RUNNING;

    setbuf(stdout, NULL);   /* Flush stdout immediately. */

    if (!(Shm->mode & SYS_STATS)) {
        PROMPT("UNIX System EXerciser (USEX)  Version ");
        PROMPT(USEX_VERSION);
        PROMPT("  %s", COMPANY_NAME);

    PROMPT("\n\nThe maximum number of built-in or user-supplied tests is %d.\n",
         Shm->max_tests);
        PROMPT("A <RETURN> implies that NO built-in or user-supplied tests\n");
        PROMPT("will be run.\n");
    }

    for (NEW_LINE;;)
    {
        Shm->procno = -1;

        if (!(Shm->mode & SYS_STATS)) 
            PROMPT("How many tests would you like to run? ==> ");

        if (Shm->mode & SYS_STATS) 
	    input[0] = NULLCHAR;
        else if (Shm->infile)
            {FGETSTRING(input)}
        else 
            getstring(input);

        if (!decimal(input, 0) || (atoi(input) > Shm->max_tests)) {
            sprintf(Shm->saved_error_msg, 
        "\"%s\" is an invalid test count. (%d is maximum on this %s)\n", 
		    input, Shm->max_tests, 
		    CURSES_DISPLAY() ? Shm->TERM : "display");
	    if (Shm->infile) 
		goto prompt_bailout;
            Shm->printf(Shm->saved_error_msg);
	}
        else {
            Shm->procno = atoi(input);
            if (Shm->outfile) 
                fprintf(fo, "%d\n", Shm->procno);
            if (Shm->procno <= MIN_IO_LINES)
		Shm->lines_used = MIN_TEST_LINES;
            else 
		Shm->lines_used = Shm->procno + NON_IO_LINES;
            break;       /* Entry is OK, so break out here. */
	}
    }

    /* Only do the following if the user wants to run at least one I/O test. */

    if (Shm->procno > 0)
    {
        /* Get directories for the I/O tests. */

	int testno = 1;

        PROMPT("\nEnter one of the following:\n");
	PROMPT("     %d)  a directory in which to create an I/O test file.\n",
	    testno++);
	PROMPT("     %d)  a block or character device file name to use as an I/O test file.\n",
	    testno++);
	PROMPT("     %d)  \"rate\" followed by either a device file name, or a mount point\n          on which to run a transfer rate test.\n",
	    testno++);
	PROMPT("     %d)  \"whet\" for the built-in whetstone benchmark.\n",
	    testno++);
	PROMPT("     %d)  \"dhry\" for the built-in dhrystone benchmark.\n",
	    testno++);
	PROMPT("     %d)  \"vmem\" for the built-in virtual memory test.\n",
	    testno++);
	PROMPT("     %d)  \"bin\" for the built-in UNIX command suite.\n",
	    testno++);
        PROMPT("     %d)  a UNIX command or shell script preceded by a \"!\".\n",
	    testno++);
        PROMPT("     %d)  a <RETURN> implies a repeat of the LAST directory or test type\n",
	    testno++);
	PROMPT("         that was entered, or if no prior selection has been made, the\n");
	PROMPT("         current directory will be used for an I/O test.\n");
  
        /* Make the "last_input" the current directory for starters. */

        strcpy(last_input, "./");
        for (i = 0; i < Shm->procno; i++)
	    bzero(Shm->ptbl[i].i_path, PATHSIZE);

        for (NEW_LINE, i = 0; i < Shm->procno;)
        {
            Shm->ptbl[i].i_type = (int)NULLCHAR;  /* Clear for good measure. */
            Shm->ptbl[i].i_stat = INITIALIZED;  

            PROMPT("Enter directory, device or command for test %d ==> ", 
                (i + 1));
            if (Shm->infile)
                {FGETSTRING(input)}
            else
                getstring(input);

            /* Use the input if something other than a <RETURN> was */
            /* entered.  Otherwise use the last known input.        */

            strncpy(Shm->ptbl[i].i_path,
		strlen(input) != 0 ? input : last_input, STRINGSIZE-1);

            if (strlen(input) > MAX_PATHNAME) {
		/*
	         *  If it's a bin or shell command, 80 is allowable.
		 */
                if ((input[0] == '!' || input[0] == '^' ||
                    (strncmp(input, "bin", 3) == 0))) {
		    if (strlen(input) >= STRINGSIZE) {
                        sprintf(Shm->saved_error_msg,
   "\"%s\"\nis too long.  Please use less than 80 characters per input line\n",
                                input);
                        if (Shm->infile) 
                            goto prompt_bailout;
                        Shm->printf(Shm->saved_error_msg);
                        continue;
		    }
                }
		else {
		    sprintf(Shm->saved_error_msg,
    "\"%s\"\nis too long.  Please use less than 60 characters per filename.\n",
                        input);
                    if (Shm->infile) 
                        goto prompt_bailout;
		    Shm->printf(Shm->saved_error_msg);
		    continue;
		}
            }

            if (strneq(Shm->ptbl[i].i_path, "float") ||
		    strneq(Shm->ptbl[i].i_path, "whet") ||
		    strneq(Shm->ptbl[i].i_path, "wet")) {
                    Shm->ptbl[i].i_type = WHET_TEST;
                    Shm->ptbl[i].i_size = 0;
                    Shm->ptbl[i].i_sbuf.st_mode = EXEMPT;
                    goto io_bypass;                      
            }
            if (strneq(Shm->ptbl[i].i_path,"debug")) {
                    Shm->ptbl[i].i_type = DEBUG_TEST;
                    Shm->ptbl[i].i_sbuf.st_mode = EXEMPT;
                    goto io_bypass;
            }
            if (strneq(Shm->ptbl[i].i_path,"vmem")) {
                    Shm->ptbl[i].i_type = VMEM_TEST;
                    Shm->ptbl[i].i_sbuf.st_mode = EXEMPT;
                    buffer_required++;
                    goto io_bypass;
            }
            if (strneq(Shm->ptbl[i].i_path, "cpu") ||
                    strneq(Shm->ptbl[i].i_path, "dhry") ||
                    strneq(Shm->ptbl[i].i_path, "dry")) {
                    Shm->ptbl[i].i_type = DHRY_TEST;
                    Shm->ptbl[i].i_size = 40;
                    Shm->ptbl[i].i_sbuf.st_mode = EXEMPT;
                    goto io_bypass;                
            }
            if (Shm->ptbl[i].i_path[0] == '!' || 
		    Shm->ptbl[i].i_path[0] == '^') {
                    Shm->ptbl[i].i_type = USER_TEST;
		    if (Shm->ptbl[i].i_path[0] == '^')
                    	Shm->ptbl[i].i_message = IGNORE_NONZERO_EXIT;
		    ptr = &Shm->ptbl[i].i_path[1];
		    while (*ptr && ((*ptr == ' ') || (*ptr == '\t')))
			ptr++;
		    if (strncmp(ptr, "-nolog", strlen("-nolog")) == 0) {
			Shm->ptbl[i].i_stat |= IO_NOLOG;
		    	ptr += strlen("-nolog");
		    }
		    while (*ptr && ((*ptr == ' ') || (*ptr == '\t')))
                        ptr++;
                    strcpy(Shm->ptbl[i].i_file, ptr);
                    Shm->ptbl[i].i_sbuf.st_mode = EXEMPT;    
                    goto io_bypass;              
            }
            if (strneq(Shm->ptbl[i].i_path, "bin")) {
                    Shm->ptbl[i].i_type = BIN_TEST;
		    bin_mgr_init();
                    strcpy(Shm->ptbl[i].i_file, &Shm->ptbl[i].i_path[1]);
                    Shm->ptbl[i].i_sbuf.st_mode = EXEMPT;
                    goto io_bypass;
            }

            if (strneq(Shm->ptbl[i].i_path, "rate")) {
                    Shm->ptbl[i].i_type = RATE_TEST;
		    shift_string_left(Shm->ptbl[i].i_path, strlen("rate"), 
			NULL);
		    strip_beginning_whitespace(Shm->ptbl[i].i_path);
		    rate_test = TRUE;
	    } else
		    rate_test = FALSE;

	    if (strstr(Shm->ptbl[i].i_path, "-nolog"))
		    nolog = TRUE;
	    else
		    nolog = FALSE;

            if (strstr(Shm->ptbl[i].i_path, "-fsync") ||
		    (Shm->ioflags & IO_FSYNC))
                    io_fsync = TRUE;
            else
                    io_fsync = FALSE;

	    if (strstr(Shm->ptbl[i].i_path, "-notrunc") ||
		    (Shm->ioflags & IO_NOTRUNC))
		    Shm->ptbl[i].i_stat |= IO_NOTRUNC;

	    strip_ending_spaces(Shm->ptbl[i].i_path);

            switch (what_is(Shm->ptbl[i].i_path, &Shm->ptbl[i].i_sbuf))
            {
            case S_IFCHR:
                    Shm->ptbl[i].i_type = rate_test ? RATE_TEST : DISK_TEST;
		    if (nolog)
                    	Shm->ptbl[i].i_stat |= IO_NOLOG;
		    if (io_fsync)
			Shm->ptbl[i].i_stat |= IO_FSYNC;
                    raw_disk = TRUE;
                    limit_required++;
		    buffer_required++;

                    for (j = 0; j < i; j++) {
                        if (((Shm->ptbl[j].i_sbuf.st_mode & S_IFMT) == S_IFCHR) 
			    && (Shm->ptbl[j].i_sbuf.st_rdev == 
                            Shm->ptbl[i].i_sbuf.st_rdev)) {
                            sprintf(Shm->saved_error_msg,
              "Character device \"%s\" has already been selected by test %d.\n",
                                    Shm->ptbl[i].i_path, j+1);
	                    if (Shm->infile) 
                                goto prompt_bailout;
                            Shm->printf(Shm->saved_error_msg);
                            --i;
                    	    --limit_required;
                    	    --buffer_required;
                            break;
                        }
                    }
                    break;

            case S_IFBLK:
#ifdef RESTRICT_BLOCK_DEVICES
                    sprintf(Shm->saved_error_msg, 
			"\"%s\" is a block device file name.\n",
                        Shm->ptbl[i--].i_path);
                    if (Shm->infile) 
                        goto prompt_bailout;
                    Shm->printf(Shm->saved_error_msg);
#else
                    Shm->ptbl[i].i_type = rate_test ? RATE_TEST : DISK_TEST;
                    if (nolog)
                        Shm->ptbl[i].i_stat |= IO_NOLOG;
	            if (io_fsync)
			Shm->ptbl[i].i_stat |= IO_FSYNC;

                    limit_required++;
                    buffer_required++;

		    if (Shm->ptbl[i].i_type == RATE_TEST)
  			break;

                    for (j = 0; j < i; j++) {
                        if (((Shm->ptbl[j].i_sbuf.st_mode & S_IFMT) == S_IFBLK)
			    && (Shm->ptbl[j].i_sbuf.st_rdev ==
                            Shm->ptbl[i].i_sbuf.st_rdev)) {
                            sprintf(Shm->saved_error_msg,
                  "Block device \"%s\" has already been selected by test %d.\n",
                                Shm->ptbl[i].i_path, j+1);
                            if (Shm->infile) 
                                goto prompt_bailout;
                            Shm->printf(Shm->saved_error_msg);
                            --i;
                            --limit_required;
                            --buffer_required;
                            break;
                        }
                    }
#endif
                    break;

            case S_IFREG:
		    if (rate_test) {
                        Shm->ptbl[i].i_type = RATE_TEST;
                    	if (nolog)
                            Shm->ptbl[i].i_stat |= IO_NOLOG;
                        limit_required++;
                        buffer_required++;
		    } else {
                        sprintf(Shm->saved_error_msg, 
		 	    "\"%s\" is a regular file name.\n",
                            Shm->ptbl[i--].i_path);
                        if (Shm->infile) 
                            goto prompt_bailout;
                        Shm->printf(Shm->saved_error_msg);
		    }
                    break;

            case S_IFDIR:
                    Shm->ptbl[i].i_type = rate_test ? RATE_TEST : DISK_TEST;
		    if (Shm->ptbl[i].i_type == RATE_TEST && 
			!is_mount_point(i, NULL, TRUE, NULL))
			    Shm->ptbl[i].i_stat |= RATE_CREATE;
                    if (nolog)
                        Shm->ptbl[i].i_stat |= IO_NOLOG;
		    if (io_fsync)
                        Shm->ptbl[i].i_stat |= IO_FSYNC;
                    limit_required++;
                    buffer_required++;
                    break;

            default:
                    sprintf(Shm->saved_error_msg,
                        "\"%s\" is non-existent.\n", Shm->ptbl[i--].i_path);
                    if (Shm->infile) 
                        goto prompt_bailout;
                    Shm->printf(Shm->saved_error_msg);
                    break;
            }
io_bypass:
            if (strlen(input) != 0)
                    strcpy(last_input, input);
            i++;
        }

        if (Shm->outfile) {
            for (i = 0; i < Shm->procno; i++) {
		if (Shm->ptbl[i].i_type == RATE_TEST)
                    fprintf(fo, "rate ");
                fprintf(fo, "%s", Shm->ptbl[i].i_path);
		if (Shm->ptbl[i].i_stat & IO_NOLOG)
		    fprintf(fo, " -nolog");
		if (Shm->ptbl[i].i_stat & IO_FSYNC)
		    fprintf(fo, " -fsync");
		fprintf(fo, "\n");
	    }
        }

        if (!buffer_required)
            goto buffer_bypass;

       
        /* Explain how the buffer size can be entered, and get at least one. */

	PROMPT("\nTest%s ", buffer_required > 1 ? "s" : "");
        for (i = 0, j = buffer_required; i < Shm->procno; i++) {
	    switch (Shm->ptbl[i].i_type)
	    {
	    case RATE_TEST:
            case DISK_TEST:
            case VMEM_TEST:
	        j--;
		if (j == 0) {
		    PROMPT("%d", i+1);
		}
		else {
		    if (j == 1) {
		        PROMPT("%d and ", i+1);
		    }
		    else {
		        PROMPT("%d, ", i+1);
                    }
		}
		break;
            }
        }
	PROMPT(" require%s %sbuffer size%s.", 
	    buffer_required == 1 ? "s" : "",
	    buffer_required == 1 ? "a " : "",
	    buffer_required == 1 ? "" : "s");

        PROMPT(
          "\nThe buffer size must be entered in one of the following ways: \n");
        PROMPT("     1) a literal integer value.\n");
        PROMPT("     2) a number followed by a \"k\" or \"K\",");
        PROMPT(" for multiples of one kilobyte.\n");
        j = 3;
        for (i = 0; i < Shm->procno; i++) {
            if (Shm->ptbl[i].i_type == VMEM_TEST) {
PROMPT("     %d) the vmem test requires the number of megabytes to allocate.\n",
	        j++);
		break;
	    }
	}
        PROMPT(
        "     %d) a <RETURN> implies a repeat of the LAST buffer size\n",
	    j++);
        PROMPT("        that was entered.\n");
        PROMPT("At least ONE buffer size MUST be entered.");

        if (raw_disk)
        {
        PROMPT("\nWARNING: The buffer size for a character disk device MUST\n");
        PROMPT("         be a multiple of the unit's sector size.");
        }
        PROMPT("\n");

        for (NEW_LINE, i = j = 0; i < Shm->procno;)
        {
            switch (Shm->ptbl[i].i_type) 
            {
            case VMEM_TEST:
                PROMPT("Enter number of megabytes for virtual memory ");
                PROMPT("test %d ==> ", (i + 1)); 
                break;
            case DHRY_TEST:
            case WHET_TEST:
            case DEBUG_TEST:
            case USER_TEST:
            case BIN_TEST:
                i++;
                continue;
            case DISK_TEST:
                PROMPT("Enter a buffer size for I/O test %d (%s) ==> ", (i + 1), 
                    Shm->ptbl[i].i_path); 
	        break;
            case RATE_TEST:
                PROMPT("Enter a buffer size for transfer rate test %d (%s) ==> ", (i + 1), 
                    Shm->ptbl[i].i_path); 
                break;
            }

            if (Shm->infile)
                {FGETSTRING(input)}
            else
                getstring(input);

            if (strlen(input) != 0)
            {
                 /* Hey, something was entered... */

                for (j = 0;;j++)
                {
                    /* Look for a NULL or "k" at the end of the input string. */

                    if (input[j] == '\0')
                    {
                        /* Must be a literal entry. */

                        temp = atoi(input);

                        if ((Shm->ptbl[i].i_size = (int)temp) == 0) 
                            j = INVALID;      /* Literal, but foolish... */
			else if (Shm->ptbl[i].i_type & (DISK_TEST|RATE_TEST))
			    disk_size = (int)temp;
			else if (Shm->ptbl[i].i_type == VMEM_TEST)
			    vmem_size = (int)temp;
                        break;
                    }

                    if ((input[j] == 'k' || input[j] == 'K') &&
                        (Shm->ptbl[i].i_type & (DISK_TEST|RATE_TEST)))
                    {
                        /* Multiply the entry by 1024. */ 

                        temp = atoi(input) * 1024; 

                        if ((Shm->ptbl[i].i_size = (int)temp) == 0)
                            j = INVALID;     /* Short version, but foolish... */
			else
			    disk_size = (int)temp;

                        break;
                    }
                }
            }
            else if (strlen(input) == 0)
            {
                /* User hit <RETURN>, so use the previous entry */
                /* as long as this isn't the FIRST attempt, OR  */
                /* the previous test has a meaningless "size".  */
                if ((Shm->ptbl[i].i_type & (DISK_TEST|RATE_TEST)) && disk_size)
                    Shm->ptbl[i].i_size = disk_size;
                if ((Shm->ptbl[i].i_type == VMEM_TEST) && vmem_size)
                    Shm->ptbl[i].i_size = vmem_size;
            }   
            if (j == INVALID)
            {
                sprintf(Shm->saved_error_msg,
                    "%s is an invalid size for test %d.\n", input, i+1);
                if (Shm->infile) 
                    goto prompt_bailout;
                Shm->printf(Shm->saved_error_msg);
                j = 0;
            }
            else if (Shm->ptbl[i].i_size > 0) {     /* That's good enough. */
                if (Shm->outfile)
                    fprintf(fo, "%ld\n", (ulong)Shm->ptbl[i].i_size);
                last_disk_size = (long)Shm->ptbl[i].i_size;
                i++;                            
            }
            else 
            {
                if (Shm->ptbl[i].i_type == VMEM_TEST) 
                    sprintf(Shm->saved_error_msg,
			"Number of megabytes MUST be entered.\n");
                else 
                    sprintf(Shm->saved_error_msg,
			"At least ONE buffer size MUST be entered.\n");
                if (Shm->infile)  
                    goto prompt_bailout;
		Shm->printf(Shm->saved_error_msg);
            }

        } /* for */

buffer_bypass:

        /* Get the size limit on the files. */

        if (limit_required) {

    	    PROMPT("\nTest%s ", limit_required > 1 ? "s" : "");
            for (i = 0, j = limit_required; i < Shm->procno; i++) {
    	    switch (Shm->ptbl[i].i_type)
    	    {
		case RATE_TEST:
                case DISK_TEST:
    	        j--;
    		if (j == 0) {
    		    PROMPT("%d", i+1);
    		}
    		else {
    		    if (j == 1) {
    		        PROMPT("%d and ", i+1);
    		    }
    		    else {
    		        PROMPT("%d, ", i+1);
                        }
    		}
    		break;
                }
            }
    	    PROMPT(" require%s %sfile size limit%s.\n", 
    	        limit_required == 1 ? "s" : "",
    	        limit_required == 1 ? "a " : "",
    	        limit_required == 1 ? "" : "s");
    
            last_disk_size = last_rate_size = -1;

	    PROMPT("The file size limits must be entered in one of the following ways:\n");
	    PROMPT("     1) a number followed by a \"k\" or \"K\", for multiples of one kilobyte.\n");
	    PROMPT("     2) a number followed by a \"m\" or \"M\", for multiples of one megabyte.\n");
	    PROMPT("     3) an \"f\" implies:\n");
	    PROMPT("        for I/O tests: \"until the file system is full\"\n");
	    PROMPT("        for transfer rate tests: \"read the whole file\"\n");
	    PROMPT("     4) a <RETURN> implies a repeat of the LAST file size that was entered.\n");
	    PROMPT("At least ONE file size limit MUST be entered.\n\n");

            for (i = 0; i < Shm->procno; i++)
            {
                switch (Shm->ptbl[i].i_type)
                {
                case RATE_TEST:
                    PROMPT("Enter the file size limit for transfer rate test %d (%s) ==> ",
                        (i + 1), Shm->ptbl[i].i_path);
                    break;

		case DISK_TEST:
                    PROMPT("Enter the file size limit for I/O test %d (%s) ==> ",
                        (i + 1), Shm->ptbl[i].i_path);
		    break;

                default:
                    continue;
                }

                if (Shm->infile) 
                    {FGETSTRING(input)}
                else
                    getstring(input);

                if (input[0] == 'f') {
		    if (Shm->ptbl[i].i_type == DISK_TEST) {
                        Shm->ptbl[i].i_limit = 0;
                        last_disk_size = 0;
                        if (Shm->outfile) 
                            fprintf(fo, "0\n");
		    }
                    if (Shm->ptbl[i].i_type == RATE_TEST) {
			if (Shm->ptbl[i].i_stat & RATE_CREATE) {
			    if (last_rate_size <= 0) {
                        	sprintf(Shm->saved_error_msg,
                    "Transfer rate test %d requires a file size limit.\n", i+1);
                        	if (Shm->infile)
                            	    goto prompt_bailout;
                        	Shm->printf(Shm->saved_error_msg);
                        	--i;
			    } else {
				Shm->ptbl[i].i_limit = (ulong)last_rate_size;
                                if (Shm->outfile)
                                    fprintf(fo, "%ld\n", Shm->ptbl[i].i_limit);
			    }
			} else {
                            Shm->ptbl[i].i_limit = 0;
                            last_rate_size = 0;
                            if (Shm->outfile)
                                fprintf(fo, "0\n");
			}
                    }
                }
                else if (strlen(input) == 0) {
		    if (Shm->ptbl[i].i_type == DISK_TEST) {
                        if (last_disk_size != -1) {
                            Shm->ptbl[i].i_limit = (ulong)last_disk_size;
                            if (Shm->outfile) {
                                if (Shm->ptbl[i].i_limit != 0)
                                    fprintf(fo, "%ld\n", Shm->ptbl[i].i_limit);
                                else
                                    fprintf(fo, "0\n");
                            }
                        }
                        else {
    			    sprintf(Shm->saved_error_msg,
    			     "At least ONE file size limit must be entered.\n");
    	                    if (Shm->infile) 
                                goto prompt_bailout;
    			    Shm->printf(Shm->saved_error_msg);
                            --i;
                        }
		    }
                    if (Shm->ptbl[i].i_type == RATE_TEST) {
                        if (last_rate_size >= 0) {
                            Shm->ptbl[i].i_limit = (ulong)last_rate_size;
                            if (Shm->outfile) {
                                if (Shm->ptbl[i].i_limit != 0)
                                    fprintf(fo, "%ld\n", Shm->ptbl[i].i_limit);
                                else
                                    fprintf(fo, "0\n");
                            }
                        }
                        else {
                            sprintf(Shm->saved_error_msg,
                    "Transfer rate test %d requires a file size limit.\n", i+1);
                            if (Shm->infile)
                                goto prompt_bailout;
                            Shm->printf(Shm->saved_error_msg);
                            --i;
                        }
                    }
                }
                else if (!(Shm->infile) && abs(atoi(input)) == 0 && 
                    strlen(input) > 0) {
                    sprintf(Shm->saved_error_msg,
			"\"%s\" is an invalid file size limit for test %d.\n", 
			input, i+1);  /* Excuse me? */
	            if (Shm->infile)
                        goto prompt_bailout;
		    Shm->printf(Shm->saved_error_msg);
                    --i;
                }
                else {
                    Shm->ptbl[i].i_limit = abs(atol(input));
		    if (strstr(input, "m") || strstr(input, "M"))
			Shm->ptbl[i].i_limit *= 1024;
		    if (Shm->ptbl[i].i_type == DISK_TEST)
                    	last_disk_size = (long)Shm->ptbl[i].i_limit;
		    if (Shm->ptbl[i].i_type == RATE_TEST)
                    	last_rate_size = (long)Shm->ptbl[i].i_limit;
                    if (Shm->outfile) {
                        if (Shm->ptbl[i].i_limit != 0)
                            fprintf(fo, "%ld\n", Shm->ptbl[i].i_limit);
                        else
                            fprintf(fo, "0\n");
                    }
                }
            }
        }  /* if limit_required */
    }  /* if Shm->procno > 0 */


    /* Determine whether a kill time was entered. */

    if (!(Shm->mode & SYS_STATS)) {
        PROMPT("\nIf desired, enter automatic USEX kill time in minutes.\n");
        PROMPT("A <RETURN> implies that USEX should run indefinitely ==> ");
    }

    if (Shm->mode & SYS_STATS)
	input[0] = NULLCHAR;
    else if (Shm->infile)
        {FGETSTRING(input)}
    else
        getstring(input);

    Shm->time_to_kill = abs(atoi(input));
    if (Shm->outfile)
        fprintf(fo, "%d\n", Shm->time_to_kill);
    Shm->time_to_kill *= 60;

    if (!(Shm->mode & SYS_STATS)) {
      PROMPT("\nEnter a \"b\" if initial display mode is to be in background.");
        PROMPT("\nA <RETURN> implies foreground display mode ==> ");
    }

    if (Shm->mode & SYS_STATS) 
	input[0] = 'f'; 
    else if (Shm->infile) {
        {FGETSTRING(input)}
	switch (input[0])
        {
        case 'f':
	case 'b':
	    break;
  	default:
	    sprintf(Shm->saved_error_msg, 
		"Display mode must be either \"f\" or \"b\".\n");
            if (Shm->infile) 
                goto prompt_bailout;
	    Shm->printf(Shm->saved_error_msg);
        }
    }
    else
        getstring(input);

    if (input[0] == 'b')
        Shm->mode |= BKGD_MODE;
    if (Shm->outfile)
        fprintf(fo, "%s", Shm->mode & BKGD_MODE ? "b\n\n" : "f\n\n");

    for (i = 0; i < Shm->procno; i++) {
	switch (Shm->ptbl[i].i_type)
	{
	case DISK_TEST:
	    if (option_override.nolog & DISK_TEST)
		Shm->ptbl[i].i_stat |= IO_NOLOG;
	    break;
	case WHET_TEST:
            if (option_override.nolog & WHET_TEST)
                Shm->ptbl[i].i_stat |= IO_NOLOG;
	    break;
	case DHRY_TEST:
            if (option_override.nolog & DHRY_TEST)
                Shm->ptbl[i].i_stat |= IO_NOLOG;
	    break;
	case NULL_TEST:
            if (option_override.nolog & NULL_TEST)
                Shm->ptbl[i].i_stat |= IO_NOLOG;
	    break;
	case USER_TEST:
            if (option_override.nolog & USER_TEST)
                Shm->ptbl[i].i_stat |= IO_NOLOG;
	    break;
	case VMEM_TEST:
            if (option_override.nolog & VMEM_TEST)
                Shm->ptbl[i].i_stat |= IO_NOLOG;
	    break;
	case BIN_TEST:
            if (option_override.nolog & BIN_TEST)
                Shm->ptbl[i].i_stat |= IO_NOLOG;
	    break;
	case DEBUG_TEST:
            if (option_override.nolog & DISK_TEST)
                Shm->ptbl[i].i_stat |= IO_NOLOG;
	    break;
	case RATE_TEST:
            if (option_override.nolog & DISK_TEST)
                Shm->ptbl[i].i_stat |= IO_NOLOG;
	    break;
	}
    }

    if (Shm->infile)
        fclose(fi);     /* Close any input or output files used. */
    if (Shm->outfile)
        fclose(fo);

    CLEAR_STRING(Shm->saved_error_msg);  /* Clear this -- used later by die() */

   /* 
    *  If in (curses) debug mode, clear the display screen. 
    */
    if (Shm->mode & DEBUG_MODE) 
        clear_display_screen();

    return;

prompt_bailout:

    fflush(stdout);
    Shm->mode |= SAVE_DEFAULT|BAD_INPUT_FILE;
    Shm->bad_fline = fline;

    die(0, DIE(7), FALSE);
}

static void
getstring(char *line)
{
	if (fgets((char *)line, (int)STRINGSIZE, stdin) == (char *)NULL) { 
		die(0, DIE(8), FALSE);   /* catches CTRL-D or EOF */
	}
	strip_lf(line);
}

/*
 *  make_IO_record()
 *
 *        Make a /tmp/ux######_IO file to keep track of any I/O tests that
 *        may be hanging around if the system crashes.  Later on in time,
 *        chk_leftovers() can search around for the disk I/O files and wipe
 *        them out.
 */

static void
make_IO_record(void)
{
    FILE *fp;
    register int i, cnt;
    char cwd_buf[1026];
    char *cwd;

    if ((cwd = getcwd(cwd_buf, sizeof(cwd_buf)-2) ) == NULL)
        Shm->perror("getcwd");

    /*
     *  Create an I/O test record file for any future usex -c operation.
     */
    for (i = cnt = 0; i < Shm->procno; i++) {
        if (Shm->ptbl[i].i_type & (DISK_TEST|RATE_TEST)) 
	    cnt++;
    }

    if (cnt == 0)
        return;

    sprintf(Shm->ux_IO, "/tmp/ux%06d_IO", Shm->mompid);
    if ((fp = fopen(Shm->ux_IO, "w")) == NULL) {
        Shm->perror(Shm->ux_IO);
        return;
    }

    fprintf(fp, "%d\n", getppid());

    for (i = 0; i < Shm->procno; i++) {
        if (Shm->ptbl[i].i_type & (DISK_TEST|RATE_TEST)) {
	    if (strlen(Shm->ptbl[i].i_errfile) == 0) {
		sprintf(Shm->ptbl[i].i_errfile, "ux%06d_%02d.err",
                    Shm->mompid, i+1);
	    }
            if (cwd) {
	        fprintf(fp, "%s/%s\n", cwd, Shm->ptbl[i].i_errfile);
	 	fflush(fp);
	    }
            else {
	        fprintf(fp, "%s\n", Shm->ptbl[i].i_errfile);
	 	fflush(fp);
	    }
            if (SPECIAL_FILE(Shm->ptbl[i].i_sbuf.st_mode))
                continue;
            else {
		if (Shm->ptbl[i].i_type == DISK_TEST) {
	        	fprintf(fp, "%s\n", Shm->ptbl[i].i_file);
	 		fflush(fp);
		}
		if (Shm->ptbl[i].i_type == RATE_TEST &&
		    Shm->ptbl[i].i_stat & RATE_CREATE) {
	        	fprintf(fp, "%s\n", Shm->ptbl[i].i_file);
	 		fflush(fp);
		}
	    }
        }
    }

    fclose(fp);
}


/*
 *  die:  Resets the terminal back to the orginal values before exiting from 
 *        USEX.  All I/O test files are deleted UNLESS an associated 
 *        "ux######_##.err" file exists.  All leftover files that are still
 *        around are deleted.  All of the IPC stuff is cleaned up and the 
 *        terminal is restored to normal.
 */

void 
die(int reason, int caller, int do_return)
{
    register int i; 
    char message[STRINGSIZE];
    int quiet_death = Shm->mode & QUIET_MODE;

    Shm->die_caller = caller;

    if (reason) {
	char sigrec[MESSAGE_SIZE];

	switch (reason)
	{
	case SIGINT:
		sprintf(sigrec, "window manager received: SIGINT");
		break;
	case SIGBUS:
		sprintf(sigrec, "window manager received: SIGBUS");
		break;
	case SIGSEGV:
		sprintf(sigrec, "window manager received: SIGSEGV");
		break;
	case SIGILL:
		sprintf(sigrec, "window_manager received: SIGILL");
		break;
	default:
		sprintf(sigrec, "window manager received signal: %d", reason);
		break;
	}

	USER_MESSAGE_WAIT(sigrec);
	sigset(SIGSEGV, SIG_DFL); 

	save_screen(SCREEN_SAVED);
    }
    else
    	USER_MESSAGE_WAIT("dying...");

    for (i = 0; i < Shm->procno; i++) {
       /*
        *  If by some change an I/O test is still kicking, kill it good...
	*/
        if (Shm->ptbl[i].i_pid == NOT_RUNNING)
            continue;

        if (Kill(Shm->ptbl[i].i_pid, 0, "U2", K_IO(i)) == 0)  {
            Kill(Shm->ptbl[i].i_pid, SIGKILL, "U3", K_IO(i));
            post_test_status(i, "KILLED");
        }
        else 
            post_test_status(i, "<DEAD>");

       /*
        *  Get rid of any BIN_TEST files that might be left around.
        */
        if (Shm->ptbl[i].i_type == BIN_TEST)
            bin_cleanup(i, EXTERNAL);

        if (SPECIAL_FILE(Shm->ptbl[i].i_sbuf.st_mode))  /* Don't touch devs. */
            continue;            

       /*
        * Delete each I/O TEST file UNLESS there 
        * is an error file associated with it.  
        */

        if ((Shm->ptbl[i].i_type == DISK_TEST) && 
            !(file_exists(Shm->ptbl[i].i_errfile))) {
		sprintf(message, "deleting %s", Shm->ptbl[i].i_file);
		if (!reason)
        	    USER_MESSAGE_WAIT(message); 
            	delete_file(Shm->ptbl[i].i_file, NOT_USED);  
	}

        if ((Shm->ptbl[i].i_type == RATE_TEST) &&
            (Shm->ptbl[i].i_stat & RATE_CREATE) &&
            !(file_exists(Shm->ptbl[i].i_errfile))) {
		sprintf(message, "deleting %s", Shm->ptbl[i].i_file);
        	if (!reason) {
		    USER_MESSAGE_WAIT(message); 
		}
            	delete_file(Shm->ptbl[i].i_file, NOT_USED);
	}
    }

    if (!reason)
        USER_MESSAGE_WAIT("cleaning up files...");

    file_cleanup();  /* Once more for paranoia's sake... */

    if (Shm->mode & SAVE_DEFAULT) {
        if (strcmp(Shm->outfile, Shm->default_file) != 0) 
            delete_file(Shm->default_file, NOT_USED);  
    }
    else 
         delete_file(Shm->default_file, NOT_USED);  

    if (!streq(Shm->tmpdir, "/tmp"))
	delete_file(Shm->tmpdir, NOT_USED);

    for (i = 0; i < NUMSG && (Shm->mode & MESGQ_MODE); i++) {
        if (Shm->msgid[i] < 0)
            continue;
        if (msgctl(Shm->msgid[i], IPC_RMID, (struct msqid_ds *)NULL) == -1) 
            Shm->perror("die: msgctl");
    }

    LOG(NOARG, LOG_END, NOARG, NULL);

    window_manager_shutdown_notify();

    if (!quiet_death)
    	Shm->stderr("");                  /* The final toll... */

    if (Shm->mode & BAD_INPUT_FILE)
        Shm->stderr(
        "\rusex: FATAL ERROR: \"%s\": incorrect input file format: line %d\n",
            Shm->infile, Shm->bad_fline);

    Shm->stderr("%s\r\n",                       
	Shm->saved_error_msg ? Shm->saved_error_msg : "");  

    dump_screen(stderr);

    process_list(PS_LIST_VERIFY, stderr);

    make_reportfile();

    print_die_code(Shm->die_caller, stderr, FALSE);

    if (Shm->mode & SHMEM_MODE) {
        bcopy(Shm, Shm->shm_tmp, sizeof(struct shm_buf));
        Shm = Shm->shm_tmp;

        if (shmdt(Shm->shm_addr) == -1)
            Shm->perror("die: shmdt");

        if (shmctl(Shm->shmid, IPC_RMID, (struct shmid_ds *)NULL) == -1)
            Shm->perror("die: shmctl");
    }

    if (Shm->mode & DROPCORE)
	drop_core("die()\n");

    window_manager_shutdown();

    if (do_return)
	return;

    _exit(NORMAL_EXIT);
}

void
quick_die(int caller)
{
    Shm->die_caller = caller;

    if (Shm->mode & SHMEM_MODE && Shm->shm_addr) {
        bcopy(Shm, Shm->shm_tmp, sizeof(struct shm_buf));
        Shm = Shm->shm_tmp;

        if (shmdt(Shm->shm_addr) == -1) 
            Shm->perror("usex: shmdt");
        if (shmctl(Shm->shmid, IPC_RMID, (struct shmid_ds *)NULL) == -1) 
            Shm->perror("usex: shmctl");
    }

    if (file_exists(Shm->id_file))
	delete_file(Shm->id_file, NOT_USED);

    if (file_exists(Shm->infile) && streq(Shm->infile, Shm->default_file)) 
	delete_file(Shm->infile, NOT_USED);
    if (file_exists(Shm->outfile))
        delete_file(Shm->outfile, NOT_USED);

    LOG(NOARG, LOG_END, NOARG, NULL);

    make_reportfile();

    print_die_code(caller, stderr, FALSE);

    if (Shm->mode & DROPCORE)
	drop_core("quick_die()\n");

    _exit(QUICK_DIE);
}

static void
make_reportfile(void)
{
	FILE *fp;
	register int i;
	char buf[MESSAGE_SIZE];
	int tests_run, test_failures, win_mgr_failures;

    	if (!Shm->reportfile)
        	Shm->reportfile = "/dev/null";

        if ((fp = fopen(Shm->reportfile, "w")) == NULL) {
                Shm->perror(Shm->reportfile);
                Shm->printf("cannot create report file: %s\n", Shm->reportfile);
                return;
        }

	fprintf(fp, "USEX VERSION: %s\n\n", USEX_VERSION);

        tests_run = test_failures = win_mgr_failures = 0;
        for (i = 0; i < Shm->procno; i++) {
                if (Shm->ptbl[i].i_pid == NOT_RUNNING)
			continue;

		switch (Shm->ptbl[i].i_stat & (EXPLICIT_KILL|HANG))
		{
		case EXPLICIT_KILL:
			break;

		case (EXPLICIT_KILL|HANG):
		case 0:
			test_failures++;
			break;
		}

		tests_run++;
	}

	if (!(Shm->mode & (CINIT|GINIT)))
		win_mgr_failures++;

	fprintf(fp, "USEX TEST RESULT: %s\n\n", 
		(test_failures|win_mgr_failures) ? "FAIL" : "PASS");

	if (Shm->mode & CINIT) 
		dump_screen(fp);

	if (tests_run)
		fprintf(fp, "\n");
        for (i = 0; i < Shm->procno; i++) {
		if (Shm->ptbl[i].i_pid == NOT_RUNNING)
			continue;

		sprintf(buf, "%s TEST %d: ", test_type(i), i+1);

                switch (Shm->ptbl[i].i_stat & (EXPLICIT_KILL|HANG))
                {
                case EXPLICIT_KILL:
			strcat(buf, "PASS");
                        break;

                case (EXPLICIT_KILL|HANG):
                case 0:
			strcat(buf, "FAIL");
                        break;
                }

		fprintf(fp, "%22s\n", buf);
        }

	if (tests_run)
		fprintf(fp, "\n");

	if (!streq(Shm->reportfile, "/dev/null"))
		print_die_code(Shm->die_caller, fp, TRUE);

	dump_status(REPORTFILE_STATUS, fp);

	fclose(fp);
}

/*
 *  Window manager will pick this up...
 */
static void
ctrl_c(void)
{
    Shm->mode |= CTRL_C;
}

/*
 *  The user has relied upon the "-[eb]" option to do all his dirty work.
 *  Make an input file called "ux<pid>", and have usex do it up.
 */

static int
make_usex_input(int arg, int tcount)
{
    register int i;
    FILE *fp, *pp;
    int max_tests;
    int disk_tests;
    int vmem_tests;
    int rate_tests;
    int random_vmems;
    int sequential_vmems;
    int dry_tests;
    int float_tests;
    int bin_tests;
    ulong mbs, memsize, ratesize, disksize;
    char *argv[MAX_ARGV];
    char buf[MESSAGE_SIZE*2];
    char *directory;
    int force_transfer = FALSE;

    get_geometry();

    max_tests = tcount ? tcount : Shm->max_tests;

    if (file_exists(Shm->infile)) {
        if (unlink(Shm->infile)) {
            Shm->perror(Shm->infile);
            return(FALSE);
        }
    }

    /*
     *  Make the input file.
     */
    if ((fp = fopen(Shm->infile, "w")) == NULL) {
        Shm->perror(Shm->infile);
	return(FALSE);
    }

    switch(arg)
    {
    case 'B':
    case 'b':
	fprintf(fp, "%d\n", max_tests);
	for (i = 0; i < max_tests; i++) {
	        fprintf(fp, "bin\n");
	}
#ifdef NOTDEF
	fprintf(fp, "0\n");
#endif
	if (Shm->time_to_kill) 
		fprintf(fp, "%d\n", Shm->time_to_kill);
	else
		fprintf(fp, "0\n");
	fprintf(fp, "f\n");
	fprintf(fp, "\n");
	break;

    case 'E': 
    case 'e': 
	max_tests = MAX(max_tests, 6);  /* at least one of each built-in */

        if (option_override.transfer_rate_device)
	    force_transfer = TRUE;

	disk_tests = max_tests/4;
	if (!disk_tests)
	    disk_tests = 1;
	rate_tests = 1;
	vmem_tests = max_tests/4;
	if (!vmem_tests)
	    vmem_tests = 1;
        sequential_vmems = vmem_tests/2;
	random_vmems = vmem_tests - sequential_vmems;
	float_tests = MAX(max_tests/12, 1);
	dry_tests = MAX(max_tests/12, 1);
        bin_tests = max_tests - 
	    (disk_tests + rate_tests + vmem_tests + float_tests + dry_tests);
	if (!bin_tests)
	    bin_tests = 1;

	if (is_directory("/usr/tmp"))
	    directory = "/usr/tmp";
	else if (is_directory("/tmp"))
	    directory = "/tmp";
	else 
	    directory = ".";

	fprintf(fp, "%d\n", max_tests);
	for (i = 0; i < disk_tests; i++) 
	    fprintf(fp, "%s\n", directory);
	for (i = 0; i < rate_tests; i++) {
	    if (force_transfer)
		fprintf(fp, "rate %s\n", option_override.transfer_rate_device);
	    else if (is_mount_point(NOT_USED, "/usr", TRUE, buf)) {
		fprintf(fp, "rate %s\n", buf); 
	    } else {
	        fprintf(fp, "rate %s\n", directory);
	    }
	}
	for (i = 0; i < dry_tests; i++)
	    fprintf(fp, "dhry\n");
	for (i = 0; i < float_tests; i++)
	    fprintf(fp, "whet\n");
	for (i = 0; i < vmem_tests; i++) {
	    if (Shm->vmem_access) {
		if (streq(Shm->vmem_access, "ran"))
	    		fprintf(fp, "vmem -r\n");
		if (streq(Shm->vmem_access, "seq"))
	    		fprintf(fp, "vmem -s\n");
		continue;
	    }
            if (i < random_vmems)
	    	fprintf(fp, "vmem -r\n");
	    else
	        fprintf(fp, "vmem -s\n");
        }
	for (i = 0; i < bin_tests; i++) 
	    fprintf(fp, "bin\n");

	for (i = 0; i < disk_tests; i++)
	    fprintf(fp, "8192\n");
	for (i = 0; i < rate_tests; i++)
	    fprintf(fp, "8192\n");

	memsize = get_free_memory();
	for (i = 0; i < vmem_tests; i++) {
	    if (Shm->vmem_size)
		fprintf(fp, "%d\n", Shm->vmem_size);
	    else {
		if (memsize) { 
			mbs = (memsize) / vmem_tests;
			fprintf(fp, "%ld\n", mbs ? mbs : 1);
		} else
	    		fprintf(fp, "10\n");
	    }
	}
	
	disksize = 1024;
        if ((pp = popen("/bin/df /usr", "r"))) {
            while (fgets(buf, MESSAGE_SIZE*2, pp)) {
                if (strstr(buf, "Available") || (buf[0] != '/'))
                    continue;
		if (parse(buf, argv) == 6) {
		    disksize = atol(argv[3]) / disk_tests+rate_tests;
		    break;
		}
            }
	    pclose(pp);
        } 

	for (i = 0; i < disk_tests; i++) 
	    fprintf(fp, "%ld\n", disksize);

	for (i = 0; i < rate_tests; i++) { 
	    ratesize = ((memsize*2)*1048576)/1024;
	    fprintf(fp, "%ld\n", ratesize);
	}

	if (Shm->time_to_kill)
        	fprintf(fp, "%d\n", Shm->time_to_kill);
	else
        	fprintf(fp, "0\n");
        fprintf(fp, "b\n");
        fprintf(fp, "\n");
	break;
    }

    fclose(fp);

    if (chmod(Shm->infile, 0777)) {
        Shm->perror(Shm->infile);
        return(FALSE);
    }

    return(TRUE);
}

static void
start_shell(int argc, char **argv)
{
    register int i;
    char command[STRINGSIZE*2];
    char errmsg[STRINGSIZE*2];
    char id_file_current[STRINGSIZE];
    FILE *fp;

    /*
     *  This routine is essentially called twice:
     *
     *  (1) When usex is invoked from the command line.  When this happens
     *      an ID file /tmp/ux[PID].sh is created, and execl("/bin/sh -c usex")
     *      is performed below.
     *  (2) When usex is invoked from the execl("/bin/sh -c usex") below, it
     *      sees the newly-created ID file (thereby recognizing itself as the 
     *      exec'd usex), sets the parent_shell variable, and returns.
     *
     *  However, depending upon the UNIX used, the exec'd usex may:
     *
     *  (1) be a child of the original usex.
     *  (2) have the same PID as the original usex.
     *
     *  That being the case, we have to look for ID files that contain 
     *  either the parent's PID or the current PID.  It really doesn't make
     *  a difference, as long as parent_shell is set correctly.  If the
     *  parent_shell dies and orphans the exec'd usex, then the exec'd
     *  usex will recognize that fact and kill itself.
     *
     *  NOTE: This kludge was put in place to deal with remote executions
     *  of "xterm -e usex" where the originator was running /bin/csh under
     *  SVR4.  I don't remember what the exact problem was, other than there
     *  would be "stranded" usex c-shells running remotely after the xterms 
     *  were killed; running from /bin/sh worked fine.  Hence this kludge...
     */

    sprintf(Shm->id_file, "/tmp/ux%06d.sh", getppid());
    sprintf(id_file_current, "/tmp/ux%06d.sh", getpid());

    if (file_exists(Shm->id_file) || file_exists(id_file_current)) {
	if (file_exists(Shm->id_file))
	    delete_file(Shm->id_file, NOT_USED);
	if (file_exists(id_file_current))
	    delete_file(id_file_current, NOT_USED);
        Shm->parent_shell = getppid();
        return;
    }
    else
        sprintf(Shm->id_file, "/tmp/ux%06d.sh", getpid());

    if ((fp = fopen(Shm->id_file, "w")) == NULL) {
        Shm->perror("fopen");
        return;
    }
    else 
        fclose(fp);

    sprintf(command, "%s",  argv[0]);
    for (i = 1; i < argc; i++) 
        sprintf(&command[strlen(command)], " %s", argv[i]);

    sprintf(errmsg, "execl: FATAL ERROR: [%s]: ", command);

    sigset(SIGINT, SIG_IGN);
    execl("/bin/sh", "/bin/sh", "-c", command, (char *)0);

    Shm->perror(errmsg);   /* NOT REACHED */
    _exit(START_SHELL_EXIT);
}

void
log_death (int id)
{
	char buffer[FATAL_STRINGSIZE];

	if (id < MAX_IO_TESTS) {
		if (!strlen(Shm->ptbl[id].i_time_of_death))
			set_time_of_death(id);
		sprintf(buffer, " %s TEST %d: %s: %s\n",
                                test_type(id), id+1, 
				Shm->ptbl[id].i_stat & EXPLICIT_KILL ?
				"EXPLICITLY KILLED AT" : "ABNORMAL DEATH AT",
				Shm->ptbl[id].i_time_of_death);
	}

	LOG(id, LOG_MESSAGE, NOARG, buffer);
}

void
log_entry(unsigned long id, unsigned long cmd, unsigned long count, void *s)
{
        static FILE *logfp = (FILE *)NULL;
        char buffer1[MESSAGE_SIZE];    
        char buffer2[MESSAGE_SIZE];    
        char buffer3[MESSAGE_SIZE];    
	register int i;
	int fd;
	time_t now;

        if (!Shm->logfile)
                return;

	if (!logfp) {
        	if ((logfp = fopen(Shm->logfile, "w+")) == NULL) {
                	Shm->perror(Shm->logfile);
                	quick_die(QDIE(19));
        	}
	}

	fd = fileno(logfp);

	time(&now);

        switch (cmd)
        {
	case LOG_MESSAGE:
		fprintf(logfp, "%s", (char *)s);
		fsync(fd);
		break;

        case LOG_IO_PASS:
		if (count == 1) 
			return;

		elapsed_time(Shm->ptbl[id].i_timestamp, now, buffer1);
                Shm->ptbl[id].i_timestamp = now;

      		switch (Shm->ptbl[id].i_type)
		{
		case DHRY_TEST:
                        fprintf(logfp, 
                      " %s TEST %ld: PASS: %ld TIME: %s %ld dhrystones/second\n",
                                test_type(id),
                                id+1, count-1, buffer1, (ulong)s);
			break;

		default:
                	fprintf(logfp, 
			    " %s TEST %ld: PASS: %ld TIME: %s %s\n", 
				test_type((int)id),
				id+1, count-1, buffer1, s ? (char *)s : "");
			break;
		}

		fsync(fd);
                break;

        case LOG_START:
		fprintf(logfp, "%sUSEX VERSION: %s\n", SEPARATOR, USEX_VERSION);
		sys_date(buffer1);
		sys_time(buffer2);
		fprintf(logfp, SEPARATOR);
		fprintf(logfp, "USEX START: %s@%s\n", buffer1, buffer2);
		fprintf(logfp, SEPARATOR);
		fprintf(logfp, "RUNTIME MESSAGES:\n\n");
		fflush(logfp);
		fsync(fd);
		break;

        case LOG_END:
                sys_date(buffer1);
                sys_time(buffer2);
		run_time(buffer3, NULL);
		fprintf(logfp, SEPARATOR);
		fprintf(logfp, "USEX END: %s@%s  TIME: %s\n", 
			buffer1, buffer2, buffer3);

                fprintf(logfp, SEPARATOR);
		fprintf(logfp, "TEST STATISTICS:\n");
                for (i = 0; i < Shm->procno; i++) {
                        fprintf(logfp, "\n%s TEST %d:\n",
				test_type(i), i+1);
                        test_inquiry(i, logfp, TRUE);
                	fprintf(logfp, "\n%s", SEPARATOR);
                }

		fprintf(logfp, "TEST SUMMARIES:\n\n");
		test_summaries(logfp);

                fprintf(logfp, SEPARATOR);

		fprintf(logfp, "USEX SHARED MEMORY DATA:\n\n");
		usex_inquiry(logfp);


                fprintf(logfp, SEPARATOR);

		if (Shm->mode & CINIT)
			fprintf(logfp, "FINAL SCREEN:\n\n");

		if (!(Shm->mode & SCREEN_SAVED))
			save_screen(SCREEN_SAVED);

		dump_screen(logfp);

		if (!streq(Shm->logfile, "/dev/null"))
			print_die_code(Shm->die_caller, logfp, TRUE);

		fsync(fd);
        	fclose(logfp);
                break;
        }
}

char *usage_lines[] = {

"usex options: ",
"     -e [count]      Automatically execute an an example set of built-in tests,",
"                     adapting to the terminal window size.  If a test count is",
"                     specified, then only run that many tests.  The minimum ",
"                     test count is 6, so as to allow one of each type of",
"                     built-in test to run.  The maximum test count is 48.",
"     -b [count]      Automatically execute bin test suites, adapting to the",
"                     terminal window size.  If a test count is specified, then",
"                     only run that many tests.  The maximum test count is 48.",
"     -v              Display USEX version number.",
"     -h              Display this help message.",
"     -M              Use SYSV IPC message queues for message passing.",
"     -S              Use SYSV shared memory for message passing.",
"     -P              Use pipes for message passing.",
"     -r              Prevent automatic screen refresh.",
"     -d              Start USEX in debug mode.",
"     -C              Clean leftover USEX files without query.",
"     -c              Clean leftover USEX files and exit immediately after query.",
"     -i filename     Read USEX input from file.",
"     -o filename     Save test parameters in USEX input file.",
"     -p filename     Use I/O test pattern as indicated in the file, or the",
"                     keyword \"ID\", which fills the test pattern with the",
"                     test ID number.",
"     -t filename     Use as transfer rate file for -e option.",
"     -T minutes      Minutes to run test (overrides any input file setting).",
"     -l filename     Log usex events in a file, along with a screen dump,",
"                     test summaries, and usex internal status.",
"     -R filename     Create a report file with pass/fail status, screen dump,",
"                     test summaries, and usex internal status.",
"     -n niceval      Assign nice value to USEX window manager.",
"     -I              Ignore exit returns from any bin test.",
"     -w              Wire window manager pages in memory (root only).",
"     -q              Quiet -- no beeps on error conditions, and do not check",
"                     for leftover files.",
"     -H minutes      Number of minutes without any builtin test messages to",
"                     qualify for HANG status (default is 10 minutes).",
"--help               Display this help message.",
"--version            Display USEX version number.",
"--nodisplay          Do not display anything on the terminal screen; this option",
"                     requires the use of either the -i, -b, -B, -e or -E ",
"                     options, and either -T or a kill-time must be entered in",
"                     the input file.  (not applicable to gnusex)",
"                     Use -l and/or -R options to ascertain test results.",
"--binargs cmd,...    Comma-separated list of specified commands for all bin",
"                     tests to run.",
"--exclude cmd,...    Comma-separated list of specified commands to exclude in",
"                     all bin tests.",
"--io fsync,notrunc   Comma-separated list of I/O test arguments, consisting of",
"                     \"fsync\", which forces an explicit fsync() call after each",
"                     write() call in the Fill cycle, and/or \"notrunc\", which",
"                     negates the ftruncate() call after each read() call in the",
"                     Trun cycle.",
"--vmem mb,ran|seq    Comma-separated vmem test arguments in which \"mb\" is",
"                     the number of megabytes to malloc (overrides any",
"                     input file, interactive or -e setting); \"ran\" or \"seq\"",
"                     sets the access mode to random or sequential (overrides",
"                     any input file or -e setting).",
"--nostats            Do not display any system statistics.",
"--nolog io,bin,vmem, Comma-separated list of test types whose events should NOT",
"        dhry,whet,   be logged when using the -l option.",
"        rate,user    ",
" ",
"Alternatively, the following options from the list above may be placed in a",
".usexrc file located in the current directory or in the user's HOME directory:",
"  ",
"  -i, -o, -S, -M, -P, -p, -I, -H, -q, -r, -n, -l, -R, -C, -t, -T, -d,",
"  --binargs, --exclude, --io, --vmem, --nostats, --nolog",
" ",
NULL
};

static void
usage(void)
{
	register int i;
	FILE *fp;

	fp = open_output_pipe();
	for (i = 0; usage_lines[i]; i++)
		fprintf(fp, "%s\n", usage_lines[i]);
	close_output_pipe();
}

/*
 *  Kill any other usex tasks found.
 */
static void
usex_kill(void)
{
 	pid_t upid;
	FILE *fp;
	char buffer1[STRINGSIZE];
	char buffer2[STRINGSIZE];
        int argc ATTRIBUTE_UNUSED;
        char *argv[MAX_ARGV];

	if ((fp = popen("/bin/ps -e | /bin/grep -e usex -e PID", "r")) == NULL){
		Shm->perror("popen(/bin/ps | /bin/grep -e usex -e PID)");
		_exit(USEX_KILL_POPEN);
	}

        while (fgets(buffer1, STRINGSIZE-1, fp)) {
		if (strstr(buffer1, "PID TTY")) {
			Shm->stderr(buffer1);
			continue;
		}

                if (strstr(buffer1, " usex") || strstr(buffer1, " gnusex")) {
			strcpy(buffer2, buffer1);
			strip_beginning_whitespace(buffer2);
		     	argc = parse(buffer2, argv);
			upid = atoi(argv[0]);
			if (upid != getpid()) {
				strip_lf(buffer1);
				Shm->stderr(buffer1);
				errno = 0;
				kill(upid, SIGKILL);
				if (errno)
					Shm->perror("  --  kill failed");
				else
					Shm->stderr("  --  kill succeeded\n");
			}
		}
        }

	pclose(fp);
}


void
usex_inquiry(FILE *fp)
{
	register int i, j;
	struct timer_callback *tc, *tc1;
	char buffer[MESSAGE_SIZE];
	int others;

	fprintf(fp, "mode: %llx\n (", Shm->mode);
	others = 0;
	if (Shm->mode & DEBUG_MODE)
		fprintf(fp, "%sDEBUG", others++ ? "|" : "");
       if (Shm->mode & BKGD_MODE)
                fprintf(fp, "%sBKGD", others++ ? "|" : "");
       if (Shm->mode & AT_KLUDGE)
                fprintf(fp, "%sAT_KLUDGE", others++ ? "|" : "");
       if (Shm->mode & NO_REFRESH_MODE)
                fprintf(fp, "%sNO_REFRESH", others++ ? "|" : "");
       if (Shm->mode & CHILD_HOLD)
                fprintf(fp, "%sCHILD_HOLD", others++ ? "|" : "");
       if (Shm->mode & SAVE_DEFAULT)
                fprintf(fp, "%sSAVE_DEFAULT", others++ ? "|" : "");
       if (Shm->mode & AUTO_INFILE)
                fprintf(fp, "%sAUTO_INFILE", others++ ? "|" : "");
       if (Shm->mode & CURSES_MODE)
                fprintf(fp, "%sCURSES", others++ ? "|" : "");
       if (Shm->mode & CINIT)
                fprintf(fp, "%sCINIT", others++ ? "|" : "");
       if (Shm->mode & PIPE_MODE)
                fprintf(fp, "%sPIPE", others++ ? "|" : "");
       if (Shm->mode & MESGQ_MODE)
                fprintf(fp, "%sMESGQ", others++ ? "|" : "");
       if (Shm->mode & SHMEM_MODE)
                fprintf(fp, "%sSHMEM", others++ ? "|" : "");
       if (Shm->mode & MMAP_MODE)
                fprintf(fp, "%sMMAP", others++ ? "|" : "");
       if (Shm->mode & MMAP_DZERO)
                fprintf(fp, "%sMMAP_DZERO", others++ ? "|" : "");
       if (Shm->mode & MMAP_ANON)
                fprintf(fp, "%sMMAP_ANON", others++ ? "|" : "");
       if (Shm->mode & MMAP_FILE)
                fprintf(fp, "%sMMAP_FILE", others++ ? "|" : "");
       if (Shm->mode & WINUPDATE)
                fprintf(fp, "%sWINUPDATE", others++ ? "|" : "");
       if (Shm->mode & QUIET_MODE)
                fprintf(fp, "%sQUIET", others++ ? "|" : "");
       if (Shm->mode & IGNORE_BIN_EXIT)
                fprintf(fp, "%sIGNORE_BIN_EXIT", others++ ? "|" : "");
       if (Shm->mode & MLOCK_MODE)
                fprintf(fp, "%sMLOCK", others++ ? "|" : "");
       if (Shm->mode & NO_STATS)
                fprintf(fp, "%sNO_STATS", others++ ? "|" : "");
       if (Shm->mode & SCREEN_SAVED)
                fprintf(fp, "%sSCREEN_SAVED", others++ ? "|" : "");
       if (Shm->mode & SYNC_BIN_TESTS)
                fprintf(fp, "%sSYNC_BIN_TESTS", others++ ? "|" : "");
       if (Shm->mode & BAD_INPUT_FILE)
                fprintf(fp, "%sBAD_INPUT_FILE", others++ ? "|" : "");
       if (Shm->mode & SHUTDOWN_MODE)
                fprintf(fp, "%sSHUTDOWN", others++ ? "|" : "");
       if (Shm->mode & CTRL_C)
                fprintf(fp, "%sCTRL_C", others++ ? "|" : "");
       if (Shm->mode & BIN_INIT)
                fprintf(fp, "%sBIN_INIT", others++ ? "|" : "");
       if (Shm->mode & CONS_PENDING)
                fprintf(fp, "%sCONS_PENDING", others++ ? "|" : "");
       if (Shm->mode & CONS_INIT)
                fprintf(fp, "%sCONS_INIT", others++ ? "|" : "");
       if (Shm->mode & NODISPLAY)
                fprintf(fp, "%sNODISPLAY", others++ ? "|" : "");
       if (Shm->mode & DROPCORE)
                fprintf(fp, "%sDROPCORE", others++ ? "|" : "");
       if (Shm->mode & RCLOCAL)
                fprintf(fp, "%sRCLOCAL", others++ ? "|" : "");
       if (Shm->mode & RCHOME)
                fprintf(fp, "%sRCHOME", others++ ? "|" : "");
       if (Shm->mode & NOTTY)
                fprintf(fp, "%sNOTTY", others++ ? "|" : "");
       if (Shm->mode & GTK_MODE)
                fprintf(fp, "%sGTK", others++ ? "|" : "");
       if (Shm->mode & GINIT)
                fprintf(fp, "%sGINIT", others++ ? "|" : "");
       if (Shm->mode & SYS_STATS)
                fprintf(fp, "%sSYS_STATS", others++ ? "|" : "");
        if (Shm->mode & MORE)
                fprintf(fp, "%sMORE", others++ ? "|" : "");
        if (Shm->mode & LESS)
                fprintf(fp, "%sLESS", others++ ? "|" : "");
       if (Shm->mode & RHTS_HANG_TRACE)
                fprintf(fp, "%sRHTS_HANG_TRACE", others++ ? "|" : "");
	fprintf(fp, ")\n");

	fprintf(fp, "parent_shell: %d mompid: %d\n", 
		Shm->parent_shell, Shm->mompid);
	fprintf(fp, 
            "Shm: %lx shm_tmp: %lx shmid: %d shm_addr: %lx\n",
		(ulong)Shm, (ulong)Shm->shm_tmp, Shm->shmid, (ulong)Shm->shm_addr);

        fprintf(fp,
            "mmfd: %d max_tests: %d hanging_tcnt: %d die_caller: %d\n",  
		Shm->mmfd, Shm->max_tests, Shm->hanging_tcnt, Shm->die_caller);

	fprintf(fp, 
	    "TERM: \"%s\" term_LINES: %d term_COLS: %d lines_used: %d\n",
		Shm->TERM, Shm->term_LINES,
		Shm->term_COLS, Shm->lines_used);

	fprintf(fp, 
            "shm_size: %d ptbl[%d]: %lx (see individual test reports)\n", 
		Shm->shm_size, MAX_IO_TESTS, (ulong)&Shm->ptbl[0]);
	fprintf(fp, "mom: \"%s\" ", Shm->mom);
	fprintf(fp, "input: \"%s\" ", Shm->input);
        fprintf(fp, "u_msgq.type: %d umsgq_string: \"%s\"\n",
		Shm->u_msgq.type, Shm->u_msgq.string);

	fprintf(fp, "        msgid[%d]: ", NUMSG);
	for (i = j = 0; i < NUMSG; i++) {
		sprintf(buffer, "%d", Shm->msgid[i]);
		fprintf(fp, buffer);
		j += strlen(buffer) + 1;
		if (j > 50) {
                        fprintf(fp, "\n                   ");
			j = 0;
		} else
			fprintf(fp, " "); 
	}
	fprintf(fp, "\n");

	fprintf(fp, "   win_pipe[%d*2]: ", NUMSG);
	for (i = j = 0; i < (NUMSG*2); i += 2) {
		sprintf(buffer, "%d,%d", Shm->win_pipe[i], Shm->win_pipe[i+1]);
		fprintf(fp, buffer);
		j += strlen(buffer) + 1;
		
                if (j > 50) {
                        fprintf(fp, "\n                   ");
			j = 0;
                } else
                        fprintf(fp, " ");
	}
	fprintf(fp, "\n");
	
	fprintf(fp, "      wake_me[%d]: ", NUMSG);
	for (i = 0; i < NUMSG; i++) {
		fprintf(fp, "%d", Shm->wake_me[i]);
                if (i == (NUMSG/2-1))
                        fprintf(fp, "\n                   ");
                else
                        fprintf(fp, " ");
	}
	fprintf(fp, "\n");

        fprintf(fp, "   being_read[%d]: ", NUMSG);
        for (i = 0; i < NUMSG; i++) {
                fprintf(fp, "%d", Shm->being_read[i]);
                if (i == (NUMSG/2-1))
                        fprintf(fp, "\n                   ");
                else
                        fprintf(fp, " ");
	}
        fprintf(fp, "\n");

        fprintf(fp, "being_written[%d]: ", NUMSG);
        for (i = 0; i < NUMSG; i++) {
                fprintf(fp, "%d", Shm->being_written[i]);
                if (i == (NUMSG/2-1))
                        fprintf(fp, "\n                   ");
                else
                        fprintf(fp, " ");
	}
        fprintf(fp, "\n");

	fprintf(fp, "procno: %d hangtime: %u stallcnt: %lu stallvalue: %lu\n",
		Shm->procno, Shm->hangtime, Shm->stallcnt, 
		Shm->stallvalue);
	fprintf(fp, 
	    "bin_sync_delay: %d bin_cmds_found: %d confd: %d ",
		Shm->bin_sync_delay, Shm->bin_cmds_found, Shm->confd);

	fprintf(fp, "heartbeat: %llx\n", Shm->heartbeat);

	fprintf(fp, "infile: \"%s\" outfile: \"%s\"\ndefault_file: \"%s\"\n",
		Shm->infile, Shm->outfile, Shm->default_file);

	fprintf(fp, 
	    "pattern: \"%s\" bad_fline: %d niceval: %d\n",
		Shm->pattern, Shm->bad_fline, Shm->niceval);

	fprintf(fp, 
            "time_to_kill: %d statnum: %d directories_found: %d\n",
		Shm->time_to_kill, Shm->statnum, 
		Shm->directories_found);
	fprintf(fp, "vmem_size: %d vmem_access: %s ioflags: %x ", 
		Shm->vmem_size, 
		Shm->vmem_access ? Shm->vmem_access : "(not specified)",
		Shm->ioflags);
	if (Shm->ioflags) {
		fprintf(fp, "(");
		others = 0;
		if (Shm->ioflags & IO_FSYNC)
			fprintf(fp, "%sIO_FSYNC", others++ ? "|" : "");
		if (Shm->ioflags & IO_NOTRUNC)
			fprintf(fp, "%sIO_NOTRUNC", others++ ? "|" : "");
		fprintf(fp, ")");
	}
	fprintf(fp, "\n");

	fprintf(fp, 
	    "screen_buf: %lx (see screen dump below)\n",
		(ulong)&Shm->screen_buf[0][0]);
	fprintf(fp, "tmpdir: \"%s\" id_file: \"%s\"\n",
		Shm->tmpdir, Shm->id_file);
	fprintf(fp, "ux_IO: \"%s\" console_device: \"%s\"\n",
		Shm->ux_IO, Shm->console_device);

        fprintf(fp, "saved_error_message: \"%s\"%s",
                Shm->saved_error_msg,
                strlen(Shm->saved_error_msg) ? "\n" : " ");
        fprintf(fp, "logfile: \"%s\"\n", Shm->logfile);
	fprintf(fp, "reportfile: \"%s\" origdir: \"%s\"\n", 
		Shm->reportfile, Shm->origdir);
	fprintf(fp, "ext_terminal: %s\n", Shm->ext_terminal);
	fprintf(fp, "utsname: ");
        fprintf(fp, "sysname: %s ", Shm->utsname.sysname);
        fprintf(fp, "nodename: %s ", Shm->utsname.nodename);
        fprintf(fp, "release: %s\n", Shm->utsname.release);
        fprintf(fp, "         version: %s ", Shm->utsname.version);
        fprintf(fp, "machine: %s\n", Shm->utsname.machine);

	fprintf(fp, "prompt_x: %d debug_message_inuse: %d\n", 
		Shm->prompt_x, Shm->debug_message_inuse);
	fprintf(fp, "prompt: \"%s\"%s", Shm->prompt,
		strlen(Shm->prompt) ? "\n" : " ");
	fprintf(fp, "unresolved: \"%s\"\n", Shm->unresolved);

	fprintf(fp, "timer_request:\n");
	fprintf(fp, "  requests: %ld  sequence: %d\n",
		Shm->timer_request.requests,
		Shm->timer_request.sequence);
	fprintf(fp, "  sys_time: \"%s\" sys_date: \"%s\" run_time: \"%s\"\n",
		Shm->timer_request.sys_time,
		Shm->timer_request.sys_date,
		Shm->timer_request.run_time);

	for (i = 0; i < TIMER_CALLBACKS; i++) {
	   tc = &Shm->timer_request.callbacks[i];

           if (!tc->func) {
                for (j = i; j < TIMER_CALLBACKS; j++) {
	   	    tc1 = &Shm->timer_request.callbacks[j];
                    if (tc1->func)
                        break;
		}
                if (j > i) {
                    if (i == (TIMER_CALLBACKS-1))
                        fprintf(fp, "  callbacks[%d]: (unused)\n", i);
                    else
                        fprintf(fp, "  callbacks[%d-%d]: (unused)\n", i, 
				(j == TIMER_CALLBACKS) || tc1->func ? j-1 : j);
                    i = j-1;
                } else
                    fprintf(fp, "  callbacks[%d]: (unused)\n", i);
            }
            else {
		fprintf(fp, "  callbacks[%d]: ", i);
		fprintf(fp, "time: %d seq: %d active: %d ",
				tc->time, tc->seq, tc->active);
		fprintf(fp, "func: %lx arg1: %ld arg2: %ld\n",
				(ulong)tc->func, tc->arg1, tc->arg2);
	    }
	}

	fprintf(fp, "lockstats[%d]: %lx (not shown) opipe: %lx\n", NUMSG,
		(ulong)&Shm->lockstats[0], (ulong)Shm->opipe);
        fprintf(fp, "ps_list: %lx\n", (ulong)Shm->ps_list);
        process_list(PS_LIST_READ, fp);

	fprintf(fp, "window_manager: "); 
	if (CURSES_DISPLAY())
		fprintf(fp, "curses_mgr() ");
	else if (GTK_DISPLAY())
		fprintf(fp, "GTK_mgr() ");
        fprintf(fp, "printf: ");
        if (CURSES_DISPLAY())
                fprintf(fp, "curses_printf()\n");
        else if (GTK_DISPLAY())
                fprintf(fp, "GTK_printf()\n");
	fprintf(fp, "perror: ");
        if (CURSES_DISPLAY())
                fprintf(fp, "curses_perror() ");
        else if (GTK_DISPLAY())
                fprintf(fp, "GTK_perror() ");
	fprintf(fp, "stderr: ");
        if (CURSES_DISPLAY())
                fprintf(fp, "curses_stderr()\n");
        else if (GTK_DISPLAY())
                fprintf(fp, "GTK_stderr()\n");
        fprintf(fp, "dump_win_mgr_data: ");
        if (CURSES_DISPLAY())
                fprintf(fp, "NULL\n");
        else if (GTK_DISPLAY())
                fprintf(fp, "dump_gtk_mgr_data()\n");
        fprintf(fp, "win_specific: ");
        if (CURSES_DISPLAY())
                fprintf(fp, "curses_specific()\n");
        else if (GTK_DISPLAY())
                fprintf(fp, "gtk_mgr_specific()\n");
	fprintf(fp, "wmd: %lx\n", (ulong)Shm->wmd);
	if (Shm->dump_win_mgr_data)
		Shm->dump_win_mgr_data(fp);
}


/* 
struct ps_list {
	char message[MESSAGE_SIZE];
	struct ps_list *next;
};
*/

void 
process_list(int req, FILE *out)
{
	register int i;
	FILE *fp;
	char buf[MESSAGE_SIZE*2];
	char workbuf[MESSAGE_SIZE*2];
	char hdr[MESSAGE_SIZE];
	char *cmd;
	int pid;
	struct ps_list **ps;
	int tty_fd, argc, cnt, found;
	int bin_test_run;
        char *argv[MAX_ARGV];
	int pidlist[MAX_IO_TESTS*2];

	if (NO_DISPLAY() || GTK_DISPLAY())
		return;

	switch (req)
	{
	case PS_LIST_INIT:
		if ((fp = popen("/bin/ps 2>/dev/null", "r")) == NULL) {
			return;
		}

		ps = &Shm->ps_list;

		while (fgets(buf, MESSAGE_SIZE*2, fp)) {
			if (strstr(buf, " PID "))
				continue;	

			buf[MESSAGE_SIZE-1] = NULLCHAR;
			strip_lf(buf);

                        strcpy(workbuf, strip_lf(buf));
                        argc = parse(strip_beginning_whitespace(workbuf), argv);
                        cmd = argv[argc-1];

                        if (streq(cmd, "ps") || streq(cmd, "/bin/ps"))
                                continue;

			*ps = (struct ps_list *)malloc(sizeof(struct ps_list));
			strcpy((*ps)->ps_line, buf);
			(*ps)->next = NULL;
			ps = &(*ps)->next;
		}
		pclose(fp);
		break;

	case PS_LIST_VERIFY:
		if (!Shm->ps_list) {
			console("no processes saved?\n");
			return;
		}

		for (i = 0, bin_test_run = FALSE; i < Shm->procno; i++)
			if (Shm->ptbl[i].i_type == BIN_TEST)
				bin_test_run = TRUE;

		if ((fp = popen("/bin/ps", "r")) == NULL)
                        return;

		bzero(pidlist, sizeof(int) * (MAX_IO_TESTS*2));
		cnt = 0;

                while (fgets(buf, MESSAGE_SIZE*2, fp)) {

			buf[MESSAGE_SIZE-1] = NULLCHAR;

                        if (strstr(buf, " PID ") && strstr(buf, "TTY")) {
				strcpy(hdr, buf);
                                continue; 
			}

			strcpy(workbuf, strip_lf(buf));
                        argc = parse(strip_beginning_whitespace(workbuf), argv);
			cmd = argv[argc-1];
			pid = atoi(argv[0]);

			if (pid == getpid())
				continue;

                        if (streq(cmd, "ps") || streq(cmd, "/bin/ps"))
                                continue; 

			found = FALSE;
                	for (ps = &Shm->ps_list; *ps; ps = &(*ps)->next) {
				if (streq((*ps)->ps_line, buf)) {
					found = TRUE;
					break;
				}
			}

			if (!found) {
				if (!streq(cmd, "usex")) {
					if (!bin_test_run)
						continue;
					if (!bin_test_exists(cmd)) 
						continue;
				}

				if (cnt == 0) {
					fprintf(out, 
"\nusex: WARNING: The following appear to be leftover usex-related processe(s):\n\n");
					fprintf(out, hdr);
				}

				fprintf(out, "%s\n", buf);
				pidlist[cnt++] = atoi(argv[0]);
			}

			if (cnt == (MAX_IO_TESTS*2))
				break;
                } 

		if (!cnt)
			return;

        	if ((tty_fd = open("/dev/tty", O_RDONLY)) < 0) {
			pclose(fp);
			return;
		}

		fprintf(out, "\nDo you want to kill %s?: y\b",
			cnt == 1 ? "it" : "them");
		read(tty_fd, buf, MESSAGE_SIZE);
		if (buf[0] == '\n' || buf[0] == 'y') {
			for (i = 0; i < cnt; i++) {
				console("kill %d\n", pidlist[i]);
				if (pidlist[i] && pidlist[i] != getpid())
					kill(pidlist[i], SIGKILL);
			}
		}

		close(tty_fd);
		pclose(fp);
		break;

	case PS_LIST_READ:
                for (ps = &Shm->ps_list; *ps; ps = &(*ps)->next) { 
			fprintf(out, "  %s\n", (*ps)->ps_line);
		}
		break;
	}
}

static void
do_binargs(char *args)
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
	    	if (decimal(argv[i], 0)) {
	        	Shm->bin_sync_delay = atoi(argv[i]);
	        	Shm->mode |= SYNC_BIN_TESTS;
	    	} else if (streq(argv[i], "ret")) {
	        	Shm->bin_sync_delay = -1;
	        	Shm->mode |= SYNC_BIN_TESTS;
	    	} else
	        	bin_exclusive(argv[i]);
	}
}

static void
do_rhts(char *args)
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
		if (streq(argv[i], "hang-trace")) {
			if (access("/proc/sysrq-trigger", W_OK) == 0) {
			 	Shm->mode |= RHTS_HANG_TRACE;
				continue;
			}
			Shm->stderr("usex: --rhts %s: cannot write to /proc/sysrq-trigger\n", 
				argv[i]);
			_exit(RHTS_BAD_ARG);
		}

		Shm->stderr("usex: invalid argument: --rhts %s\n", argv[i]);
		_exit(RHTS_BAD_ARG);
	}
}

static void
do_exclude(char *args)
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

        for (i = 0; i < argc; i++) 
        	bin_exclude(argv[i]);
}

static void
do_nolog(char *args)
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
		if (streq(argv[i], "io"))
			option_override.nolog |= DISK_TEST;
		if (streq(argv[i], "bin"))
			option_override.nolog |= BIN_TEST;
		if (streq(argv[i], "whet"))
			option_override.nolog |= WHET_TEST;
		if (streq(argv[i], "dhry"))
			option_override.nolog |= DHRY_TEST;
		if (streq(argv[i], "debug"))
			option_override.nolog |= DEBUG_TEST;
		if (streq(argv[i], "user"))
			option_override.nolog |= USER_TEST;
		if (streq(argv[i], "vmem"))
			option_override.nolog |= VMEM_TEST;
		if (streq(argv[i], "rate"))
			option_override.nolog |= RATE_TEST;
	}
}


static void
do_vmem(char *args)
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
		if (decimal(argv[i], 0))
			Shm->vmem_size = atoi(argv[i]);
                else if (strneq(argv[i], "ran"))
			Shm->vmem_access = "ran";
                else if (strneq(argv[i], "seq"))
			Shm->vmem_access = "seq";
        }
}

static void
do_io(char *args)
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
                if (strneq(argv[i], "notrunc"))
			Shm->ioflags |= IO_NOTRUNC;
                if (strneq(argv[i], "fsync"))
			Shm->ioflags |= IO_FSYNC;
        }
}

static void
get_environment(void)
{
    	char *p1;
	char buf[STRINGSIZE*2];
	FILE *fp;
	size_t size;

    	if ((p1 = getenv("USEX_CONSOLE")) != 0 && *p1) 
        	strcpy(Shm->console_device, p1);

#ifdef PR_FPEMU_NOPRINT
#ifndef __ia64__
	if ((p1 = getenv("USEX_FPEMU_NOPRINT")))
#endif
		prctl(PR_SET_FPEMU, PR_FPEMU_NOPRINT, 0, 0, 0);
#endif

        if ((p1 = getenv("HOME"))) {
                sprintf(buf, "%s/.usexrc", p1);
                if (file_exists(buf)) {
                        if ((fp = fopen(buf, "r")) == NULL) {
                                Shm->stderr("cannot open %s: %s\n",
                                        buf, strerror(errno));
				sleep(Shm->mode & NOTTY ? 0 : 2);
			} else {
				Shm->mode |= RCHOME;
                                while (fgets(buf, STRINGSIZE, fp))
                                        resolve_rc_cmd(buf);
                                fclose(fp);
                	}
        	}
	}

        sprintf(buf, ".usexrc");
        if (file_exists(buf)) {
                if ((fp = fopen(buf, "r")) == NULL) {
                        Shm->stderr("cannot open %s: %s\n",
                                buf, strerror(errno));
			sleep(Shm->mode & NOTTY ? 0 : 2);
                } else {
			Shm->mode |= RCLOCAL;
                        while (fgets(buf, STRINGSIZE, fp))
                                resolve_rc_cmd(buf);
                        fclose(fp);
                }
        }

	size = 0;
cwd_retry:
	size += STRINGSIZE;

	if ((p1 = (char *)malloc(size)) == NULL) {
		Shm->stderr( 
            "usex: cannot malloc space for current working directory string\n");
		quick_die(QDIE(22));
	}

	bzero(p1, size);

	if ((Shm->origdir = getcwd(p1, size-1)) == NULL) {
		free(p1);
		size += STRINGSIZE;
		goto cwd_retry;
	} 
}

static void
resolve_rc_cmd(char *line)
{
	register int i;
	int argc;
	char *argv[MAX_ARGV];
	char *p1;

	if (*line == '#')
		return;

	/*
	 *  Shell environment variables override those in .usexrc files.
	 */
	if (strstr(line, "USEX_CONSOLE=") && !strlen(Shm->console_device)) {
		p1 = strstr(line, "=") + 1;
		argc = parse(p1, argv);
		if (argc == 1) 
			strcpy(Shm->console_device, argv[0]);
		return;
	}

	if ((p1 = strstr(line, "TERMINAL="))) {
		strip_lf(line);
		bzero(Shm->ext_terminal, STRINGSIZE);
		p1 += strlen("TERMINAL=");
		strncpy(Shm->ext_terminal, p1, min(strlen(p1), STRINGSIZE-1));
		return;
	} 
#ifdef PR_FPEMU_NOPRINT
	if (strstr(line, "USEX_FPEMU_NOPRINT")) {
		prctl(PR_SET_FPEMU, PR_FPEMU_NOPRINT, 0, 0, 0);
		return;
	}
#endif

	argc = parse(line, argv);

	if (streq(argv[0], "--binargs") && (argc > 1)) {
		do_binargs(argv[1]);
		return;
	}

	if (streq(argv[0], "--rhts") && (argc > 1)) {
		do_rhts(argv[1]);
		return;
	}

        if (streq(argv[0], "--win") && (argc > 1)) {
                Shm->win_specific(argv[1]);
                return;
        }

        if (streq(argv[0], "--exclude") && (argc > 1)) {
                do_exclude(argv[1]);
                return;
        }

        if (streq(argv[0], "--nolog") && (argc > 1)) {
                do_nolog(argv[1]);
                return;
        }

        if (streq(argv[0], "--io") && (argc > 1)) {
                do_io(argv[1]);
                return;
        }

        if (streq(argv[0], "--vmem") && (argc > 1)) {
                do_vmem(argv[1]);
                return;
        }

	if (streq(argv[0], "-l") && (argc > 1)) {
		if ((p1 = (char *)malloc(strlen(argv[1])+1))) {
			strcpy(p1, argv[1]);
			Shm->logfile = p1;
		}
	}

        if (streq(argv[0], "-R") && (argc > 1)) {
                if ((p1 = (char *)malloc(strlen(argv[1])+1))) {
                        strcpy(p1, argv[1]);
                        Shm->reportfile = p1;
                }
        }

	if (streq(argv[0], "--core")) {
		Shm->mode |= DROPCORE;
		return;
	}

        if (streq(argv[0], "--nostats")) {
                Shm->mode |= NO_STATS;
                return;
        }

        if (streq(argv[0], "-H") && (argc > 1)) {
                if ((Shm->hangtime = atoi(argv[1])) == 0)
                        Shm->hangtime = DEFAULT_HANGTIME;
                else
                     Shm->hangtime *= 60;
		return;
	}

	if (streq(argv[0], "-d")) {
		Shm->mode |= DEBUG_MODE;
		return;
	}

        if (streq(argv[0], "-I")) {
                Shm->mode |= IGNORE_BIN_EXIT;
                return;
        }

        if (streq(argv[0], "-q")) {
                Shm->mode |= QUIET_MODE;
                return;
        }

        if (streq(argv[0], "-r")) {
                Shm->mode |= NO_REFRESH_MODE;
                return;
        }

	if (streq(argv[0], "-n") && (argc > 1)) {
                Shm->niceval = atoi(argv[1]);
                if (Shm->niceval < -10)
                    Shm->niceval = -10;
                else if (Shm->niceval > 19)
                    Shm->niceval = 19;
	}

        if (streq(argv[0], "-C")) {
                if (chk_leftovers(!QUERY) == 0) {
                    Shm->printf("No leftovers detected.  ");
                    i = 2;
                } else
                    i = 4;
                if (Shm->directories_found) {
                    Shm->printf("%d director%s not removed.", 
			Shm->directories_found,
                        Shm->directories_found == 1 ? "y was" : "ies were");
                }
                Shm->printf("\n");
                sleep(Shm->mode & NOTTY ? 0 : i);
		return;
	}

        if (streq(argv[0], "-i") && (argc > 1)) {
                if ((p1 = (char *)malloc(strlen(argv[1])+1))) {
                        strcpy(p1, argv[1]);
                        Shm->infile = p1;
                }
		return;
        }

        if (streq(argv[0], "-o") && (argc > 1)) {
                if ((p1 = (char *)malloc(strlen(argv[1])+1))) {
                        strcpy(p1, argv[1]);
                        Shm->outfile = p1;
                }
                return;
        }

        if (streq(argv[0], "-p") && (argc > 1)) {
                if ((p1 = (char *)malloc(strlen(argv[1])+1))) {
                        strcpy(p1, argv[1]);
                        Shm->pattern = p1;
                }
                return;
        }

        if (streq(argv[0], "-P")) {
                Shm->mode &= ~(SHMEM_MODE|MESGQ_MODE|MMAP_MODE);
                Shm->mode |= PIPE_MODE;
		return;
	}

        if (streq(argv[0], "-S")) {
                Shm->mode &= ~(PIPE_MODE|MESGQ_MODE|MMAP_MODE);
                Shm->mode |= SHMEM_MODE;
		return;
	}

        if (streq(argv[0], "-M")) {
                Shm->mode &= ~(PIPE_MODE|SHMEM_MODE|MMAP_MODE);
                Shm->mode |= MESGQ_MODE;
		return;
	}

        if (streq(argv[0], "-w")) {
                if (mlockall(MCL_CURRENT|MCL_FUTURE) == 0)  
                        Shm->mode |= MLOCK_MODE;
                else {
                        Shm->perror("window manager not wired: mlockall");      
                        sleep(Shm->mode & NOTTY ? 0 : 2);
                }
		return;
	}

        if (streq(argv[0], "-T") && (argc > 1)) {
                option_override.time_to_kill = atoi(argv[1]);
		return;
	}

        if (streq(argv[0], "-t") && (argc > 1)) {
                if ((p1 = (char *)malloc(strlen(argv[1])+1))) {
                        strcpy(p1, argv[1]);
                        option_override.transfer_rate_device = p1;
                }
                return;
        }
}


static void
nodisplay_setup(int argc, char **argv)
{
	int i, j, nullfd;

	for (i = 0; i < argc; i++) {
		if (streq(argv[i], "--nodisplay")) {
			if (GTK_DISPLAY()) 
			    	quick_die(QDIE(27));
    			if ((nullfd = open("/dev/null", O_RDWR)) < 0) {
				Shm->perror("/dev/null");
				quick_die(QDIE(23));
			}
			Shm->mode |= NODISPLAY;
			for (j = 0; j < 3; j++)
				close(j);
			if (dup(nullfd) != 0)
				quick_die(QDIE(24));
			if (dup(nullfd) != 1)
				quick_die(QDIE(25));
			if (dup(nullfd) != 2)
				quick_die(QDIE(26));
		}
		if (streq(argv[i], "--core"))   /* for early-on debug */
			Shm->mode |= DROPCORE;
	}
}

static void
argv_preview(int argc, char **argv)
{
	int i;

	for (i = 0; i < argc; i++) {
		if (streq(argv[i], "--core"))      /* for getopt-time debug */
			Shm->mode |= DROPCORE;

                if (strneq(argv[i], "-b") || strneq(argv[i], "-e") ||
                     strneq(argv[i], "-B") || strneq(argv[i], "-E")) {
			if ((strlen(argv[i]) > 2) && 
			    decimal(&argv[i][2], 0) && 
			    (atoi(&argv[i][2]) > 0)) {
				Shm->hanging_tcnt = atoi(&argv[i][2]);
				argv[i][2] = (char)NULLCHAR;
			}
	
	                if (argv[i][1] == 'E')
	                        argv[i][1] = 'e';
	                if (argv[i][1] == 'B')
	                        argv[i][1] = 'b';
		}
	}
}

static char *die_codes[] = {
    /*  0 */ "window manager received CTRL-C",
    /*  1 */ "(invalid die code)",
    /*  2 */ "msgget failure",
    /*  3 */ "invalid IPC mode",
    /*  4 */ "cannot copy outfile to designed tmpdir directory",
    /*  5 */ "attempted --nodisplay without an input file",
    /*  6 */ "cannot open input file",
    /*  7 */ "input file contains invalid prompt data",
    /*  8 */ "EOF received during interactive prompt",
    /*  9 */ "(invalid die code)",
    /* 10 */ "(invalid die code)",
    /* 11 */ "(invalid die code)",
    /* 12 */ "(invalid die code)",
    /* 13 */ "(invalid die code)",
    /* 14 */ "(invalid die code)",
    /* 15 */ "(invalid die code)",
    /* 16 */ "(invalid die code)",
    /* 17 */ "(invalid die code)",
    /* 18 */ "(invalid die code)",
    /* 19 */ "(invalid die code)",
    /* 20 */ "cannot open /dev/tty",
    /* 21 */ "timer kill",
    /* 22 */ "window manager's parent shell is dead",
    /* 23 */ "test-issued STOP_USEX",
    /* 24 */ "interactive kill (curses-based)",
    /* 25 */ "curses initscr() failed",
    /* 26 */ "incompatible terminal geometry",
    /* 27 */ "interactive kill from synchronized bin test",
    /* 28 */ "interactive kill (GTK-based)",
    /* 29 */ "(invalid die code)",
    /* 30 */ "(invalid die code)",
};

static char *quick_die_codes[] = {
    /*  0 */ "(invalid die code)",
    /*  1 */ "--help option",
    /*  2 */ "-c option",
    /*  3 */ "-h option",
    /*  4 */ "attempted -e and after -b",
    /*  5 */ "could not create -e input file",
    /*  6 */ "attempted -b and after -e",
    /*  7 */ "could not create -b input file",
    /*  8 */ "-v option",
    /*  9 */ "invalid command line option",
    /* 10 */ "invalid command line argument",
    /* 11 */ "cannot open /dev/zero",
    /* 12 */ "cannot open id file",
    /* 13 */ "cannot write shared memory buffer to id file",
    /* 14 */ "cannot mmap id file",
    /* 15 */ "system does not support mmap'd files",
    /* 16 */ "attempted --nodisplay without a kill time",
    /* 17 */ "TERM does not exist in /usr/share/terminfo",
    /* 18 */ "TERM variable not set",
    /* 19 */ "cannot open log file",
    /* 20 */ "curses initscr() failed",
    /* 21 */ "incompatible terminal geometry",
    /* 22 */ "malloc failure for current directory string",
    /* 23 */ "cannot open /dev/null",
    /* 24 */ "cannot dup fd 0",
    /* 25 */ "cannot dup fd 1",
    /* 26 */ "cannot dup fd 2",
    /* 27 */ "cannot use --nodisplay with gnusex",
    /* 28 */ "invalid -s argument",
    /* 29 */ "attempted -i with -b or -e",
    /* 30 */ "(invalid die code)",
};
 
static void
print_die_code(int code, FILE *fp, int force)
{
	fflush(stdout);

	if (code < 0)
		goto quick_die;

        switch (code)
        {
        case DIE(21):      /* timer kill */
        case DIE(24):      /* interactive kill (curses) */
	case DIE(27):      /* interactive kill from synchronized bin test */
        case DIE(28):      /* interactive kill (GTK) */
                break;
        default:
		fprintf(fp, "UNEXPECTED DIE CODE [%d]: %s\n", code,
			die_codes[code] ?  die_codes[code] : 
			"(invalid die code)");
                break;
        }

	return;

quick_die:
	switch (code)
	{
	case QDIE(1):
	case QDIE(2):
	case QDIE(3):
	case QDIE(4):
	case QDIE(6):
	case QDIE(8):
	case QDIE(9):
	case QDIE(10):
	case QDIE(11):
	case QDIE(12):
	case QDIE(13):
	case QDIE(14):
	case QDIE(15):
	case QDIE(17):
	case QDIE(18):
	case QDIE(20):
	case QDIE(21):
	case QDIE(22):
	case QDIE(23):
	case QDIE(29):
		if (!force)
			break;
	
        default:
		code = abs(code);
		fprintf(fp, "UNEXPECTED QUICK DIE CODE [%d]: %s\n", code,
			quick_die_codes[code] ?  quick_die_codes[code] : 
			"(invalid die code)");
                break;
	}
}


char *spec_file_contents[] = {
"#",
"# Unix System EXerciser",
"#",
"Summary: System test harness containing a set of builtin stress tests ",
"Name: usex",
"Version: ",
"Release: ",
"License: CC0",
"Group: Test",
"Source: %{name}-%{version}-%{release}.tar.gz",
"Distribution: Linux 2.2 or greater",
"Vendor: Red Hat, Inc.",
"Packager: Dave Anderson <anderson@redhat.com>",
"ExclusiveOS: Linux",
"Buildroot: /var/tmp/usex",
"#ExclusiveArch: i386 alpha ia64 ppc",
"",
"%description",
"The usex UNIX System Exerciser gives its user the capability of thoroughly",
"exercising and testing several different kernel subsystems. usex is a single",
"executable that acts as as test harness controlling one or more test programs.",
"The test programs can be selected from a suite of built-in tests, or external",
"user-supplied test programs. In addition to showing the current state of each",
"test program, the usex display screen continuously displays several key kernel",
"subsystem performance statistics.  The basic usex executable is a curses-based",
"text mode program; also included is a GUI version called gnusex.",
"",
"%prep",
"%setup -n %{name}-%{version}-%{release}",
"",
"%build",
"make",
"",
"%install",
"rm -rf %{buildroot}",
"mkdir -p %{buildroot}/usr/bin",
"make DESTDIR=%{buildroot} install",
"",
"%files",
"/usr/bin/*usex",
"#%doc README",
NULL
};

static void
make_spec_file(void)
{
        int i;
	char buf[100], *p1, *p2;

	sprintf(buf, USEX_VERSION);
	p1 = p2 = buf;
	while (*p2 != '-')
		p2++;
	*p2 = '\0';
	p2++;

        for (i = 0; spec_file_contents[i]; i++) {
		if (streq(spec_file_contents[i], "Version: "))
                	fprintf(stderr, "%s%s\n", spec_file_contents[i], p1);
		else if (streq(spec_file_contents[i], "Release: "))
                	fprintf(stderr, "%s%s\n", spec_file_contents[i], p2);
		else
                	fprintf(stderr, "%s\n", spec_file_contents[i]);
	}
}
