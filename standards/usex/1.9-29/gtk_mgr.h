/*  Author: David Anderson <anderson@redhat.com> */

/*
 *  CVS: $Revision: 1.3 $ $Date: 2016/02/10 19:25:52 $
 */

#define GTK_MGR_RESIZE    (0x1)
#define SCROLL_TEST_DATA  (0x2)
#define TRACK_WIDGETS     (0x4)
#define TOPLEVEL_MAP      (0x8)

#define TOPLEVEL_MAP_EVENT      ((gpointer)(1))
#define TOPLEVEL_UNMAP_EVENT    ((gpointer)(2))
#define TOPLEVEL_KEYPRESS_EVENT ((gpointer)(3))

#define MAXIMUM_UNSCROLLED_TESTS (24)

#define GTK_MGR_BOLD_FONT  "6x13bold"
#define GTK_MGR_FIXED_FONT "fixed"

struct window_manager_data {
	ulong flags;
	GtkWidget *toplevel;
	GtkWidget *mainbox;
	GtkWidget *toolbar;
	GtkWidget *status_frame;
	GtkWidget *status_bar;
	GtkWidget *user_input;
	GtkWidget *test_frame;
	GtkWidget *system_frame;
	GtkWidget *kill_usex_button;
	GtkWidget *kill_usex_dialog;
	GtkWidget *kill_usex_dialog_yes;
	GtkWidget *kill_usex_dialog_no;
	GtkWidget *kill_tests_dialog;
	GtkWidget *kill_tests_dialog_yes;
	GtkWidget *kill_tests_dialog_no;
	GtkWidget *usex_control_button;
	GtkWidget *usex_control;
	GtkWidget *usex_help_button;
	GtkWidget *user_pct;
	GtkWidget *idle_pct;
	GtkWidget *system_pct;
	GtkWidget *loadavg;
	GtkWidget *tasks_run;
	GtkWidget *forks;
	GtkWidget *interrupts;
	GtkWidget *csw;
	GtkWidget *cached;
	GtkWidget *buffers;
	GtkWidget *free_mem;
	GtkWidget *free_swap;
	GtkWidget *swap_in;
	GtkWidget *swap_out;
	GtkWidget *page_in;
	GtkWidget *page_out;
	GtkWidget *test_time;
	GtkWidget *timebox;
	GtkWidget *datebox;
	GtkWidget *system_table;
	GtkWidget *bitbucket;
	GtkWidget *hidden_button;
	GtkWidget *test_control_one;
	GtkWidget *test_control_fgnd;
	GtkWidget *test_control_bkgd;
	GtkWidget *test_control_hold;
	GtkWidget *test_control_kill;
	GtkWidget *scrollwindow;
	GtkWidget *help_window;
	GtkWidget *help_table;

	uint test_control_id;
	GdkFont *fixed;
	gchar *status_bar_exposed;
	gchar toplevel_string[MESSAGE_SIZE];

#define TOPLEVEL_STRING_IS(X) streq(Shm->wmd->toplevel_string, X)
#define CLEAR_TOPLEVEL_STRING()  bzero(Shm->wmd->toplevel_string, MESSAGE_SIZE)

	struct test_data {
		GtkWidget *bsize;
		GtkWidget *mode;
		GtkWidget *fpointer;
		GtkWidget *operation;
		GtkWidget *pass;
		GtkWidget *stat;
		GtkWidget *field2;
		GtkWidget *fieldspec;
		GtkWidget *field3;
		GtkWidget *field4;
		GtkWidget *field5;
		GtkWidget *bsize_frame;
		GtkWidget *mode_frame;
		GtkWidget *fpointer_frame;
		GtkWidget *operation_frame;
		GtkWidget *filename;
		GtkWidget *file_frame;
		GtkWidget *pass_frame;
		GtkWidget *field2_frame;
		GtkWidget *fieldspec_frame;
		GtkWidget *field3_frame;
		GtkWidget *field4_frame;
		GtkWidget *field5_frame;
		GtkWidget *control_frame;
		GtkWidget *control;
	} test_data[MAX_IO_TESTS];
};

struct external_window {
	GtkWidget *top;
	GtkWidget *scroll;
	GtkWidget *frame;
	GtkWidget *text;
	gchar *data;
};

/*
 *  Individual test control menu items
 */
#define TEST_BACKGROUND ((gpointer)1)
#define TEST_FOREGROUND ((gpointer)2)
#define TEST_HOLD       ((gpointer)3)
#define TEST_KILL       ((gpointer)4)
#define TEST_MESSAGES   ((gpointer)5)
#define TEST_INQUIRY    ((gpointer)6)

/*
 *  Test control menu items
 */
#define TEST_BACKGROUND_ALL ((gpointer)7)
#define TEST_FOREGROUND_ALL ((gpointer)8)
#define TEST_HOLD_ALL       ((gpointer)9)
#define TEST_KILL_ALL       ((gpointer)10)
#define TEST_MESSAGES_ALL   ((gpointer)11)
#define TEST_FATAL_MESSAGES ((gpointer)12)

/*
 *  USEX control menu items
 */
#define USEX_INQUIRY      ((gpointer)(13))
#define USEX_SNAPSHOT     ((gpointer)(14))
#define SHOW_INPUT_FILE   ((gpointer)(15))
#define SAVE_INPUT_FILE   ((gpointer)(16))
#define EXTERNAL_SHELL    ((gpointer)(17))
#define TOGGLE_DEBUG      ((gpointer)(18))
#define USEX_BUILD_INFO   ((gpointer)(19))
#define USEX_UNAME_INFO   ((gpointer)(20))
#define USEX_GENERAL_HELP ((gpointer)(21))
#define EXTERNAL_TOP      ((gpointer)(22))
