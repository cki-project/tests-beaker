/*  Author: David Anderson <anderson@redhat.com> */

/*
 *  This file is an #ifdef'd output display switch containing:
 *
 *   (1) an #include of the actual display-dependent window manager file.
 *   (2) the window_manager_init() function, called very early on to set up
 *       set up a few key fields in the shm_buf.
 *
 *  CVS: $Revision: 1.6 $ $Date: 2016/02/10 19:25:53 $
 */   

#ifdef _CURSES_

#include "curses_mgr.c"

void window_manager_init(int *unused1, char ***unused2)
{
	Shm->mode |= CURSES_MODE;
	Shm->window_manager = curses_mgr;
	Shm->printf = curses_printf;
	Shm->perror = curses_perror;
	Shm->stderr = curses_stderr;
	Shm->dump_win_mgr_data = NULL;
	Shm->win_specific = NULL;
	Shm->wmd = NULL;
}
#endif  /* _CURSES_ */

#ifdef _GTK_

#include "gtk_mgr.c"

void window_manager_init(int *argcp, char ***argvp)
{
	int i, argc; 
	char **argv;

	Shm->mode |= GTK_MODE;
	Shm->window_manager = gtk_mgr_main;
	Shm->perror = gtk_mgr_perror;
	Shm->stderr = gtk_mgr_stderr;
	Shm->printf = gtk_mgr_printf;
	Shm->dump_win_mgr_data = dump_gtk_mgr_data;
	Shm->wmd = &gtk_mgr_data;
	Shm->win_specific = gtk_mgr_specific;

       /*
 	*  gtk_init() first tries to open whatever's set in the DISPLAY 
        *  environment variable.  If it fails that (or if DISPLAY is not set), 
	*  gtk_init() bails out -- even if the user specifies a "--display" 
	*  command line argument.  So just jam any user's --display argument
	*  into DISPLAY before calling gtk_init().
        *
	*  If the argument is a short-cut that won't even bring up gtk,
        *  just return without even calling gtk_init().
 	*/
	argc = *argcp;
	argv = *argvp;
        for (i = 0; i < argc; i++) {
                if (streq(argv[i], "-v") ||
	            streq(argv[i], "--version") ||
	            streq(argv[i], "--help") ||
	            streq(argv[i], "--nodisplay") ||
	            streq(argv[i], "-h") ||
	            streq(argv[i], "-c"))
			return;

                if (streq(argv[i], "--display")) {
                        i++;
                        if (i < argc)
                                setenv("DISPLAY", argv[i], 1);
                        break;
                }
        }

	gtk_init(argcp, argvp);
}

#endif  /* _GTK_ */
