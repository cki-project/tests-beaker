/*  Author: David Anderson <anderson@redhat.com> */

/*
 *  gtk_mgr.c
 *
 *  This is the window manager for the GTK-based output display.  
 *
 *  gtk_mgr_main() is called from main() to set up the GUI bells and whistles.  
 *
 *  gtk_mgr_idle() is registered as an idle function.  It calls the
 *  workhorse function gtk_mgr(), which makes a pass through the timer 
 *  queue, each test process data buffer, and the error daemon.  
 *  Upon return from gtk_mgr(), pending GUI events are checked.
 *
 *  Whenever USEX data or GUI events have occurred, gtk_mgr_idle() returns
 *  back to gtk_main().  Whenever neither USEX nor GUI events are pending,
 *  gtk_mgr_idle() blocks gnusex by calling stall().  
 *
 *  This scheme satisfies both USEX and GUI demands as efficiently as 
 *  possible, without burdening the kernel with frivolous system activity.  
 *
 *  CVS: $Revision: 1.12 $ $Date: 2016/02/10 19:25:52 $
 */

#include <gtk/gtk.h>
#include "defs.h" 
#include "gtk_mgr.h"

/*
 *  gnusex widget-related data
 */
struct window_manager_data gtk_mgr_data = { 0 };

/*
 *  static function/data declarations
 */
static gchar *GDK_event_type(GdkEvent *);
static gchar *gnusex_widget_name(GtkWidget *);
static gboolean event_handler(GtkWidget *, GdkEvent *, gpointer);
static GtkWidget *track_widget(GtkWidget *);
static gint delete_event_handler(GtkWidget *, GdkEvent *, gpointer);
static void destroy_handler(GtkWidget *, gpointer);
static gboolean test_control_mouse_pressed(GtkWidget *, GdkEvent *, gpointer);
static GtkWidget *build_menu_item(gchar *, gchar,
        GtkSignalFunc, GtkWidget *, GtkAccelGroup *, gpointer);
static void gtk_mgr_debug(void);
static void gtk_mgr_adjust_window_size(GtkWidget *);
static gint dialog_response(GtkWidget *, gpointer);
static gint dialog_key_press(GtkWidget *, GdkEvent *, gpointer);
static void kill_usex_dialog_window(gchar *);
static gint kill_usex_button_release(GtkWidget *, GdkEvent *, gpointer);
static void kill_tests_dialog_window(gchar *);
static gint usex_control_button_release(GtkWidget *, GdkEvent *, gpointer);
static gint help_button_release(GtkWidget *, GdkEvent *, gpointer);
static gint test_control_button_release(GtkWidget *, GdkEvent *, gpointer);
static gint hidden_button_press(GtkWidget *, gpointer);
static gint gtk_mgr(void);
static gint gtk_mgr_idle(gpointer);
static void gtk_mgr_set_font(GtkWidget *, GdkFont *);
static GtkWidget *build_frame(gchar *, GtkWidget *, gint, gint, gint, gint);
static GtkWidget *build_scrolled_frame(gchar *, GtkWidget *, 
	gint, gint, gint, gint);
static GtkWidget *build_test_data_entry(GtkWidget *, gboolean, gboolean,
        gint, gint, gint, gint, gchar *, GtkWidget **);
static void individual_test_menu(GtkWidget *, gpointer);
static void test_control_menu(GtkWidget *, gpointer);
static void usex_control_menu(GtkWidget *, gpointer);
static gint hide_window_on_delete(GtkWidget *, gpointer);
static void build_help_table_entry(GtkWidget *, gint, 
        GtkJustification, gint, gint, gint, gint);
static void gtk_mgr_help_table(void);
static GtkWidget *build_test_data(GtkWidget *);
static void build_user_sys_idle_bars(GtkWidget *, gint, gint, gint, gint);
static GtkWidget *build_system_data_entry(GtkWidget *, gchar *, 
	gint, gint, gint, gint);
static GtkWidget *build_system_data(GtkWidget *);
static gboolean status_bar_expose(GtkWidget *, GdkEvent *, gpointer);
static GtkWidget *build_status_bar(GtkWidget *);
static GtkWidget *build_toolbar(GtkWidget *);
static void gtk_mgr_load_fonts(void);
static gint gtk_mgr_timer_callback(gpointer);
static void toplevel_map(GtkWidget *, GdkEvent *, gpointer);
static gboolean toplevel_key_press(GtkWidget *, GdkEvent *, gpointer);
static void gtk_mgr_output_message(char *);
static void gtk_mgr_error_message(char *);
static void external_window_destroy(GtkWidget *, gpointer);
static GtkWidget *build_picwidget(gchar **name, gboolean);
static char *stop_xpm[];
static char *help_xpm[];
static char *testctl_xpm[];
static char *caution_xpm[];
static char *button_horiz_xpm[];
static char *cog1_xpm[];
static char *cog2_xpm[];
static char *cog3_xpm[];
static char *cog4_xpm[];
static char *cog5_xpm[];
static char *cog6_xpm[];
static char *cog7_xpm[];
static char *cog8_xpm[];
static char *cog9_xpm[];
static char **cog_array[];
static char *HOLD_xpm[];
static char *KILL_xpm[];
static char *FGND_xpm[];
static char *BKGD_xpm[];

void 
dump_gtk_mgr_data(FILE *fp)
{
	gint i, others;
	struct window_manager_data *gdp;

	gdp = Shm->wmd;

	fprintf(fp, "flags: %lx ", gdp->flags);
	if (gdp->flags) {
		others = 0;
		fprintf(fp, "(");
		if (gdp->flags & GTK_MGR_RESIZE)
			fprintf(fp, "%sGTK_MGR_RESIZE", others++ ? "|" : "");
		if (gdp->flags & SCROLL_TEST_DATA)
			fprintf(fp, "%sSCROLL_TEST_DATA", others++ ? "|" : "");
		if (gdp->flags & TRACK_WIDGETS)
			fprintf(fp, "%sTRACK_WIDGETS", others++ ? "|" : "");
		if (gdp->flags & TOPLEVEL_MAP)
			fprintf(fp, "%sTOPLEVEL_MAP", others++ ? "|" : "");
		fprintf(fp, ")\n");
	}
	fprintf(fp, "toplevel: %lx mainbox: %lx toolbar: %lx\n",
		(ulong)gdp->toplevel, (ulong)gdp->mainbox, (ulong)gdp->toolbar);
	fprintf(fp, "test_frame: %lx system_frame: %lx\n", 
		(ulong)gdp->test_frame, (ulong)gdp->system_frame);
	fprintf(fp, "status_frame: %lx status_bar: %lx\n",
                (ulong)gdp->status_frame, (ulong)gdp->status_bar);
	fprintf(fp, "kill_usex_button: %lx kill_usex_dialog: %lx\n",
		(ulong)gdp->kill_usex_button, (ulong)gdp->kill_usex_dialog);
	fprintf(fp, "kill_usex_dialog_yes: %lx kill_usex_dialog_no: %lx\n",
		(ulong)gdp->kill_usex_dialog_yes, (ulong)gdp->kill_usex_dialog_no);
        fprintf(fp, "kill_tests_dialog: %lx\n",
                (ulong)gdp->kill_tests_dialog);
        fprintf(fp, "kill_tests_dialog_yes: %lx kill_tests_dialog_no: %lx\n",
                (ulong)gdp->kill_tests_dialog_yes, (ulong)gdp->kill_tests_dialog_no);
        fprintf(fp, "usex_control_button: %lx usex_control: %lx\n",
                (ulong)gdp->usex_control_button, (ulong)gdp->usex_control);
        fprintf(fp, "usex_help_button: %lx\n",
                (ulong)gdp->usex_help_button);
	fprintf(fp, "user_pct: %lx system_pct: %lx idle_pct: %lx\n",
		(ulong)gdp->user_pct, (ulong)gdp->system_pct, (ulong)gdp->idle_pct);
	fprintf(fp, "loadavg: %lx tasks_run: %lx forks: %lx\n",
		(ulong)gdp->loadavg, (ulong)gdp->tasks_run, (ulong)gdp->forks);
	fprintf(fp, "system_table: %lx interrupts: %lx csw: %lx\n",
		(ulong)gdp->system_table, (ulong)gdp->interrupts, (ulong)gdp->csw);
	fprintf(fp, "cached: %lx buffers: %lx\n",
		(ulong)gdp->cached, (ulong)gdp->buffers);
	fprintf(fp, "free_mem: %lx free_swap: %lx\n",
		(ulong)gdp->free_mem, (ulong)gdp->free_swap);
	fprintf(fp, "swap_in: %lx swap_out: %lx\n",
		(ulong)gdp->swap_in, (ulong)gdp->swap_out);
	fprintf(fp, "page_in: %lx page_out: %lx\n",
		(ulong)gdp->page_in, (ulong)gdp->page_out);
	fprintf(fp, "test_time: %lx timebox: %lx datebox: %lx\n",
		(ulong)gdp->test_time, (ulong)gdp->timebox, (ulong)gdp->datebox);
	fprintf(fp, "bitbucket: %lx  hidden_button: %lx\n",
		(ulong)gdp->bitbucket, (ulong)gdp->hidden_button);
	fprintf(fp, "test_control_one: %lx test_control_id: %d\n", 
		(ulong)gdp->test_control_one, gdp->test_control_id);
	fprintf(fp, "test_control_fgnd: %lx test_control_bkgd: %lx\n", 
		(ulong)gdp->test_control_fgnd, (ulong)gdp->test_control_bkgd);
        fprintf(fp, "test_control_hold: %lx test_control_kill: %lx\n",
                (ulong)gdp->test_control_hold, (ulong)gdp->test_control_kill);
	fprintf(fp, "help_window: %lx help_table: %lx\n", 
		(ulong)gdp->help_window, (ulong)gdp->help_table);
	fprintf(fp, "scrollwindow: %lx fixed: %lx\n",
		(ulong)gdp->scrollwindow, (ulong)gdp->fixed);
	fprintf(fp, "user_input: %lx status_bar_exposed: %lx\n", 
		(ulong)gdp->user_input, (ulong)gdp->status_bar_exposed);
	fprintf(fp, "toplevel_string: [%s]\n", gdp->toplevel_string);

	for (i = 0; i < Shm->procno; i++) {
		fprintf(fp, "test[%d]:\n", i);
		fprintf(fp, "  mode: %lx bsize: %lx\n",
			(ulong)gdp->test_data[i].mode,
			(ulong)gdp->test_data[i].bsize);
		fprintf(fp, "  fpointer: %lx pass: %lx\n",
			(ulong)gdp->test_data[i].fpointer,
			(ulong)gdp->test_data[i].pass);
		fprintf(fp, "  operation: %lx stat: %lx\n",
			(ulong)gdp->test_data[i].operation,
			(ulong)gdp->test_data[i].stat);
		fprintf(fp, "  field2: %lx fieldspec: %lx\n",
			(ulong)gdp->test_data[i].field2,
			(ulong)gdp->test_data[i].fieldspec);
		fprintf(fp, "  field3: %lx field4: %lx field5: %lx\n",
			(ulong)gdp->test_data[i].field3,
			(ulong)gdp->test_data[i].field4,
			(ulong)gdp->test_data[i].field5);
		fprintf(fp, "  bsize_frame: %lx mode_frame: %lx\n",
			(ulong)gdp->test_data[i].bsize_frame,
			(ulong)gdp->test_data[i].mode_frame);
                fprintf(fp, "  fpointer_frame: %lx operation_frame: %lx\n",
                        (ulong)gdp->test_data[i].fpointer_frame,
                        (ulong)gdp->test_data[i].operation_frame);
                fprintf(fp, "  filename: %lx file_frame: %lx\n",
                        (ulong)gdp->test_data[i].filename,
                        (ulong)gdp->test_data[i].file_frame);
		fprintf(fp, "  field2_frame: %lx field3_frame: %lx\n",
			(ulong)gdp->test_data[i].field2_frame,
			(ulong)gdp->test_data[i].field3_frame);
		fprintf(fp, "  fieldspec_frame: %lx pass_frame: %lx\n",
			(ulong)gdp->test_data[i].fieldspec_frame, 
			(ulong)gdp->test_data[i].pass_frame);
                fprintf(fp, "  field4_frame: %lx field5_frame: %lx\n",
                        (ulong)gdp->test_data[i].field4_frame,
                        (ulong)gdp->test_data[i].field5_frame);
                fprintf(fp, "  control: %lx control_frame: %lx\n",
                        (ulong)gdp->test_data[i].control,
                        (ulong)gdp->test_data[i].control_frame);

	}
}

static gchar *
GDK_event_type(GdkEvent *event)
{
	GdkEventType type;
	static gchar unknown[20];

	type = event->type;

	switch (type)
	{
	case GDK_NOTHING:
		return ("GDK_NOTHING");
	case GDK_DELETE:   
		return ("GDK_DELETE");
	case GDK_DESTROY: 
		return ("GDK_DESTROY");
	case GDK_EXPOSE:  
		return ("GDK_EXPOSE");
	case GDK_MOTION_NOTIFY:
		return ("GDK_MOTION_NOTIFY");
	case GDK_BUTTON_PRESS:
		return ("GDK_BUTTON_PRESS");
	case GDK_2BUTTON_PRESS:
		return ("GDK_2BUTTON_PRESS");
	case GDK_3BUTTON_PRESS:
		return ("GDK_3BUTTON_PRESS");
	case GDK_BUTTON_RELEASE:
		return ("GDK_BUTTON_RELEASE");
	case GDK_KEY_PRESS:    
		return ("GDK_KEY_PRESS");
	case GDK_KEY_RELEASE: 
		return ("GDK_KEY_RELEASE");
	case GDK_ENTER_NOTIFY:
		return ("GDK_ENTER_NOTIFY");
	case GDK_LEAVE_NOTIFY:
		return ("GDK_LEAVE_NOTIFY");
	case GDK_FOCUS_CHANGE:
		return ("GDK_FOCUS_CHANGE");
	case GDK_CONFIGURE: 
		return ("GDK_CONFIGURE");
	case GDK_MAP:      
		return ("GDK_MAP");
	case GDK_UNMAP:   
		return ("GDK_UNMAP");
	case GDK_PROPERTY_NOTIFY:
		return ("GDK_PROPERTY_NOTIFY");
	case GDK_SELECTION_CLEAR:
		return ("GDK_SELECTION_CLEAR");
	case GDK_SELECTION_REQUEST:
		return ("GDK_SELECTION_REQUEST");
	case GDK_SELECTION_NOTIFY:
		return ("GDK_SELECTION_NOTIFY");
	case GDK_PROXIMITY_IN:  
		return ("GDK_PROXIMITY_IN");
	case GDK_PROXIMITY_OUT:
		return ("GDK_PROXIMITY_OUT");
	case GDK_DRAG_ENTER:  
		return ("GDK_DRAG_ENTER");
	case GDK_DRAG_LEAVE: 
		return ("GDK_DRAG_LEAVE");
	case GDK_DRAG_MOTION:     
		return ("GDK_DRAG_MOTION");
	case GDK_DRAG_STATUS:    
		return ("GDK_DRAG_STATUS");
	case GDK_DROP_START:    
		return ("GDK_DROP_START");
	case GDK_DROP_FINISHED:
		return ("GDK_DROP_FINISHED");
	case GDK_CLIENT_EVENT:    
		return ("GDK_CLIENT_EVENT");
	case GDK_VISIBILITY_NOTIFY:
		return ("GDK_VISIBILITY_NOTIFY");
	case GDK_NO_EXPOSE:       
		return ("GDK_NO_EXPOSE");
	default:
		sprintf(unknown, "%d", type);
		return unknown;
	}
}

/*
 *  DEBUG FUNCTION:
 *
 *  Given a GtkWidget pointer, return the registered gnusex window name.
 */
static gchar *
gnusex_widget_name(GtkWidget *window)
{
        struct window_manager_data *gdp;
	static char namebuf[40];
	gint i;

        gdp = Shm->wmd;

	if (window == gdp->toplevel)
		return "toplevel";
	if (window == gdp->mainbox)
		return "mainbox";
	if (window == gdp->toolbar)
		return "toolbar";
	if (window == gdp->status_frame)
		return "status_frame";
	if (window == gdp->user_input)
		return "user_input";
	if (window == gdp->status_bar)
		return "status_bar";
	if (window == gdp->test_frame)
		return "test_frame";
	if (window == gdp->system_frame)
		return "system_frame";
	if (window == gdp->kill_usex_button)
		return "kill_usex_button";
        if (window == gdp->usex_control_button)
                return "usex_control_button";
        if (window == gdp->usex_control)
                return "usex_control";
        if (window == gdp->usex_help_button)
                return "usex_help_button";
	if (window == gdp->kill_usex_dialog)
		return "kill_usex_dialog";
	if (window == gdp->kill_usex_dialog_yes)
		return "kill_usex_dialog_yes";
	if (window == gdp->kill_usex_dialog_no)
		return "kill_usex_dialog_no";
       if (window == gdp->kill_tests_dialog_yes)
                return "kill_tests_dialog_yes";
        if (window == gdp->kill_usex_dialog_no)
                return "kill_usex_dialog_no";
	if (window == gdp->user_pct)
		return "user_pct";
	if (window == gdp->idle_pct)
		return "idle_pct";
	if (window == gdp->loadavg)
		return "loadavg";
	if (window == gdp->tasks_run)
		return "tasks_run";
	if (window == gdp->forks)
		return "forks";
	if (window == gdp->interrupts)
		return "interrupts";
	if (window == gdp->csw)
		return "csw";
	if (window == gdp->cached)
		return "cached";
	if (window == gdp->buffers)
		return "buffers";
	if (window == gdp->free_mem)
		return "free_mem";
	if (window == gdp->free_swap)
		return "free_swap";
	if (window == gdp->swap_in)
		return "swap_in";
	if (window == gdp->swap_out)
		return "swap_out";
	if (window == gdp->page_in)
		return "page_in";
	if (window == gdp->page_out)
		return "page_out";
	if (window == gdp->test_time)
		return "test_time";
	if (window == gdp->timebox)
		return "timebox";
	if (window == gdp->datebox)
		return "datebox";
	if (window == gdp->system_table)
		return "system_table";
	if (window == gdp->bitbucket)
		return "bitbucket";
	if (window == gdp->test_control_one)
		return "test_control_one";
	if (window == gdp->test_control_fgnd)
		return "test_control_fgnd";
	if (window == gdp->test_control_bkgd)
		return "test_control_bkgd";
	if (window == gdp->test_control_hold)
		return "test_control_hold";
	if (window == gdp->test_control_kill)
		return "test_control_kill";
	if (window == gdp->hidden_button)
		return "hidden_button";
	if (window == gdp->scrollwindow)
		return "scrollwindow";
	if (window == gdp->help_window)
		return "help_window";
	if (window == gdp->help_table)
		return "help_table";
	if (window == (GtkWidget *)gdp->fixed)
		return "fixed";

	sprintf(namebuf, "(unknown)");

	for (i = 0; i < Shm->procno; i++) {
		if (window == gdp->test_data[i].bsize)
			sprintf(namebuf, "bsize-%d", i);	
		if (window == gdp->test_data[i].mode)
			sprintf(namebuf, "mode-%d", i);	
		if (window == gdp->test_data[i].fpointer)
			sprintf(namebuf, "fpointer-%d", i);	
		if (window == gdp->test_data[i].operation)
			sprintf(namebuf, "operation-%d", i);	
		if (window == gdp->test_data[i].filename)
			sprintf(namebuf, "filename-%d", i);	
		if (window == gdp->test_data[i].pass)
			sprintf(namebuf, "pass-%d", i);	
		if (window == gdp->test_data[i].stat)
			sprintf(namebuf, "stat-%d", i);	
		if (window == gdp->test_data[i].field2)
			sprintf(namebuf, "field2-%d", i);	
		if (window == gdp->test_data[i].fieldspec)
			sprintf(namebuf, "fieldspec-%d", i);	
		if (window == gdp->test_data[i].field3)
			sprintf(namebuf, "field3-%d", i);	
		if (window == gdp->test_data[i].field4)
			sprintf(namebuf, "field4-%d", i);	
		if (window == gdp->test_data[i].field5)
			sprintf(namebuf, "field5-%d", i);	
                if (window == gdp->test_data[i].bsize_frame)
			sprintf(namebuf, "bsize_frame-%d", i);
                if (window == gdp->test_data[i].mode_frame)
			sprintf(namebuf, "mode_frame-%d", i);
                if (window == gdp->test_data[i].fpointer_frame)
			sprintf(namebuf, "fpointer_frame-%d", i);
                if (window == gdp->test_data[i].operation_frame)
			sprintf(namebuf, "operation_frame-%d", i);
                if (window == gdp->test_data[i].file_frame)
			sprintf(namebuf, "file_frame-%d", i);
                if (window == gdp->test_data[i].pass_frame)
                        sprintf(namebuf, "pass_frame-%d", i);
                if (window == gdp->test_data[i].field2_frame)
			sprintf(namebuf, "field2_frame-%d", i);
                if (window == gdp->test_data[i].fieldspec_frame)
			sprintf(namebuf, "fieldspec_frame-%d", i);
                if (window == gdp->test_data[i].field3_frame)
			sprintf(namebuf, "field3_frame-%d", i);
                if (window == gdp->test_data[i].field4_frame)
			sprintf(namebuf, "field4_frame-%d", i);
                if (window == gdp->test_data[i].field5_frame)
			sprintf(namebuf, "field5_frame-%d", i);
                if (window == gdp->test_data[i].control)
			sprintf(namebuf, "control-%d", i);
                if (window == gdp->test_data[i].control_frame)
			sprintf(namebuf, "control_frame-%d", i);
	}

	return(namebuf);
}

/*
 *  This generic "event" handler can be used to catch all events associated
 *  with a registered widget.  It's most useful purpose will most likely
 *  be debugging.
 */

static gboolean 
event_handler(GtkWidget *widget, GdkEvent *event, gpointer data)
{
        switch (event->type)
        {
        default:
		if ((Shm->wmd->flags & TRACK_WIDGETS) ||
		    (Shm->mode & DEBUG_MODE)) {
                	console("event: %-8s %s\n",
                        	gnusex_widget_name(widget),
                        	GDK_event_type(event));
		}
                break;
        }
        return(FALSE);
}

/*
 *  Register all gnusex widgets locally.  Widget names/addresses must be 
 *  unique, or the original one with the same name/address will be
 *  overwritten with the new data.
 */

static GtkWidget *
track_widget(GtkWidget *widget)
{
	gtk_signal_connect(GTK_OBJECT(widget), "event",
        	GTK_SIGNAL_FUNC(event_handler), NULL);

	return widget;
}


/* 
 *  When the user attempts to shut down the window with the window manager's 
 *  upper left-hand "Close" menu option, or by the upper right-hand "X", a 
 *  "delete_event" is issued before the window's closing.  If the delete_event
 *  handler, returns FALSE, the "destroy" signal will be sent to its handler.
 *  NOTE: events come before, signals come after.
 */
static gint 
delete_event_handler(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	console("delete_event_handler: %-8s %s\n", 
		gnusex_widget_name(widget), GDK_event_type(event));

	kill_usex_button_release(NULL, NULL, NULL);

    	return(TRUE);   /* FALSE lets "destroy" signal shut things down. */
}

static 
void destroy_handler(GtkWidget *widget, gpointer data)
{
	if (!(Shm->mode & SHUTDOWN_MODE)) {
        	common_kill(KILL_ALL, SHUTDOWN);
        	die(0, DIE(28), TRUE);
	}
	gtk_main_quit();
}


/*
 *  Handle a test control mouse-pressed event.
 */

static gboolean 
test_control_mouse_pressed(GtkWidget *widget, GdkEvent *event, gpointer data)
{
       /* 
    	* Check to see if the event was a mouse button press 
    	*/
   	if (event->type == GDK_BUTTON_PRESS) {
      	       /* 
       		* Cast the event into a GdkEventButton structure 
       		*/
      		GdkEventButton *buttonevent = (GdkEventButton *) event;

      	       /* 
       		* Check the button member to see which button was pressed. 
       		*/
      		switch (buttonevent->button)
      		{
		case 1:
		case 2:
		case 3: Shm->wmd->test_control_id = (uint)((ulong)data);
			gtk_menu_popup(GTK_MENU(Shm->wmd->test_control_one), 
				NULL, NULL, NULL, NULL, 
				buttonevent->button, 0); 
                       /* 
	  		*  return TRUE because we dealt with the event 
          		*/
         		return TRUE;
      		}
   	}

       /* 
        *  Return FALSE here because we didn't do anything with the event 
        */
   	return FALSE;
}

/*
 *  Build a menuitem into a menu.
 */

static GtkWidget *
build_menu_item(gchar *menutext, gchar acceleratorkey, 
	GtkSignalFunc signalhandler, GtkWidget *menu, 
	GtkAccelGroup *accelgroup, gpointer data)
{
   	GtkWidget *menuitem;

      	menuitem = menutext ? 
		gtk_menu_item_new_with_label(menutext) : gtk_menu_item_new();
   	/* 
	 *  Attach the signal handler 
	 */
   	if (signalhandler != NULL)
      		gtk_signal_connect(GTK_OBJECT(menuitem),
                	"activate", signalhandler, data);

   	/* 
	 *  Add the item to the passed-in menu 
	 */
      	gtk_menu_append(GTK_MENU(menu), menuitem);

	/* 
	 *  Finally, build the accelerator if necessary 
	 */
   	if (accelgroup != NULL && (guint) acceleratorkey != 0)
      		gtk_accel_group_add(accelgroup, (guint) acceleratorkey,
       			GDK_CONTROL_MASK, GTK_ACCEL_VISIBLE,
       			GTK_OBJECT(menuitem), "activate");

   	return menuitem;
}


static void
gtk_mgr_debug(void)
{
        gint      x;
        gint      y;
        gint      width;
        gint      height;
        gint      depth;

	gdk_window_get_geometry(NULL,
		&x, &y, &width, &height, &depth);
	console("    root: x: %d y: %d width: %d height: %d depth: %d\n",
		x, y, width, height, depth);

	gdk_window_get_geometry(Shm->wmd->toplevel->window, 
		&x, &y, &width, &height, &depth);
	console("toplevel: x: %d y: %d width: %d height: %d depth: %d\n",
		x, y, width, height, depth);

		
}

void
gtk_mgr_shutdown(void)
{
	;
}

/*
 *  When the test data window is scrolled, adjust the toplevel window size
 *  to the full root window height minus a rough guess-timate of the
 *  window manager's overhead.
 */

#define WINDOW_MANAGER_OVERHEAD (30)

static void
gtk_mgr_adjust_window_size(GtkWidget *toplevel)
{
        gint      x;
        gint      y;
        gint      width; 
        gint      height;
        gint      depth;

	gdk_window_get_geometry(NULL, &x, &y, &width, &height, &depth);

        gtk_widget_set_usize(toplevel, -1, -1);
        gtk_widget_set_usize(toplevel, -1, height-WINDOW_MANAGER_OVERHEAD);
}


/*
 *  USEX shutdown and tests kill dialog window mechanisms.
 */

static gint 
dialog_response(GtkWidget *widget, gpointer data)
{
	if (Shm->mode & SHUTDOWN_MODE)
		return(0);

	if (strstr(data, "usex")) {
		gtk_widget_hide(Shm->wmd->kill_usex_dialog);

        	if (streq(data, "usex_TRUE")) {
                	common_kill(KILL_ALL, SHUTDOWN);
                	die(0, DIE(28), TRUE);
        	} else {
                	USER_MESSAGE("kill request ignored");
                	gtk_mgr_debug();
        	}
	}

	if (strstr(data, "tests")) {
		gtk_widget_hide(Shm->wmd->kill_tests_dialog);

                if (streq(data, "tests_TRUE")) 
			test_control_menu(widget, TEST_KILL_ALL);
                else 
                        USER_MESSAGE("kill request ignored");
	}
	return(0);
}

/*
 *  Generic dialog window key press handler.
 */
static gint
dialog_key_press(GtkWidget *widget, GdkEvent *event, gpointer data)
{                       
        GdkEventKey *key_event;
	char buf[MESSAGE_SIZE];

        key_event = (GdkEventKey *)event;
         
	sprintf(buf, " %s%s", 
		Shm->wmd->toplevel_string, key_event->string); 
	gtk_label_set_text(GTK_LABEL(Shm->wmd->user_input), buf); 
                
	if (streq(data, "usex")) {
		if (streq(key_event->string, "y") ||
		    streq(key_event->string, "Y") ||
		    streq(key_event->string, "k") ||
		    streq(key_event->string, "q"))
			return(dialog_response(widget, (gpointer)"usex_TRUE"));
		else 
			return(dialog_response(widget, (gpointer)"usex_FALSE"));
	}

	if (streq(data, "tests")) {
                if (streq(key_event->string, "y") ||
		    streq(key_event->string, "k") ||
		    streq(key_event->string, "Y")) 
                        return(dialog_response(widget,(gpointer)"tests_TRUE"));
                else
                        return(dialog_response(widget,(gpointer)"tests_FALSE"));
	}

	return 0;  /* can't get here */
}

/*
 *  Bring up the kill usex dialog window, building it the first time, and just
 *  showing it during any subsequent attempts.
 */
static void
kill_usex_dialog_window(gchar *message)
{
   	GtkWidget *dialogwindow;
   	GtkWidget *packingbox;
   	GtkWidget *yn_box;
   	GtkWidget *dialogwidget;
   	GtkWidget *widget;

	if (Shm->wmd->kill_usex_dialog) {
   		gtk_widget_show(Shm->wmd->kill_usex_dialog);
		beep();
		return;
	}

       /* 
    	*  First, set up a centered dialog window.
        */
   	Shm->wmd->kill_usex_dialog = dialogwindow = 
//		gtk_window_new(GTK_WINDOW_DIALOG);
		gtk_window_new(GTK_WINDOW_TOPLEVEL);
   	gtk_window_set_title(GTK_WINDOW(dialogwindow), "USEX Message" );
   	gtk_container_set_border_width(GTK_CONTAINER(dialogwindow), 5);
   	gtk_window_set_position(GTK_WINDOW(dialogwindow), GTK_WIN_POS_CENTER);
        gtk_signal_connect (GTK_OBJECT(dialogwindow), "key_press_event",
                GTK_SIGNAL_FUNC(dialog_key_press), "usex");
        gtk_signal_connect(GTK_OBJECT(dialogwindow), "delete_event",
                GTK_SIGNAL_FUNC(hide_window_on_delete), NULL);
	gtk_widget_show(dialogwindow);

       /* 
    	*  Add a vbox to the window to hold the dialog widgets.
    	*/
   	packingbox = gtk_vbox_new(FALSE, 5);
   	gtk_container_add(GTK_CONTAINER(dialogwindow), packingbox);
	gtk_widget_show(packingbox);

       /* 
       	*  Add the caution widget and message label to the vbox,
	*  followed by a separator.
	*/
	gtk_box_pack_start(GTK_BOX(packingbox),
		build_picwidget(caution_xpm, FALSE), TRUE, TRUE, 2);
        gtk_box_pack_start(GTK_BOX(packingbox), 
		widget = gtk_label_new(message), TRUE, TRUE, 2);
	gtk_widget_show(widget);
	beep();

   	yn_box = gtk_hbox_new(TRUE, 5);

       /* 
	*  Add the buttons and connect them to their signal handlers.
	*/
	gtk_box_pack_start(GTK_BOX(yn_box), 
		dialogwidget = gtk_button_new_with_label("yes"), TRUE, TRUE, 2);
        gtk_signal_connect (GTK_OBJECT(dialogwidget), "clicked", 
		GTK_SIGNAL_FUNC(dialog_response), (gpointer)"usex_TRUE");
	gtk_widget_show(dialogwidget);
	gtk_widget_show(yn_box);

	Shm->wmd->kill_usex_dialog_yes = track_widget(dialogwidget);

	gtk_box_pack_start(GTK_BOX(yn_box), 
		dialogwidget = gtk_button_new_with_label("no"), TRUE, TRUE, 2);
        gtk_signal_connect (GTK_OBJECT(dialogwidget), "clicked",
                GTK_SIGNAL_FUNC(dialog_response), (gpointer)"usex_FALSE");
	gtk_widget_show(dialogwidget);

	Shm->wmd->kill_usex_dialog_no = track_widget(dialogwidget);

   	gtk_box_pack_start(GTK_BOX(packingbox), yn_box, TRUE, TRUE, 2 );

       /* 
	*  Set the modality of the window and show it.
        */
   	gtk_window_set_modal(GTK_WINDOW(dialogwindow), TRUE); 
   	gtk_widget_show(dialogwindow);
}


/*
 *  Bring up the kill tests dialog window, building it the first time, and just
 *  showing it during any subsequent attempts.
 */
static void
kill_tests_dialog_window(gchar *message)
{
   	GtkWidget *dialogwindow;
   	GtkWidget *packingbox;
   	GtkWidget *yn_box;
   	GtkWidget *dialogwidget;
   	GtkWidget *widget;

	if (Shm->wmd->kill_tests_dialog) {
   		gtk_widget_show(Shm->wmd->kill_tests_dialog);
		beep();
		return;
	}

       /* 
    	*  First, set up a centered dialog window.
        */
   	Shm->wmd->kill_tests_dialog = dialogwindow = 
//		gtk_window_new(GTK_WINDOW_DIALOG);
		gtk_window_new(GTK_WINDOW_TOPLEVEL);
   	gtk_window_set_title(GTK_WINDOW(dialogwindow), "USEX Message" );
   	gtk_container_set_border_width(GTK_CONTAINER(dialogwindow), 5);
   	gtk_window_set_position(GTK_WINDOW(dialogwindow), GTK_WIN_POS_CENTER);
        gtk_signal_connect(GTK_OBJECT(dialogwindow), "delete_event",
                GTK_SIGNAL_FUNC(hide_window_on_delete), NULL);
        gtk_signal_connect (GTK_OBJECT(dialogwindow), "key_press_event",
                GTK_SIGNAL_FUNC(dialog_key_press), "tests");
	gtk_widget_show(dialogwindow);

       /* 
    	*  Add a vbox to the window to hold the dialog widgets.
    	*/
   	packingbox = gtk_vbox_new(FALSE, 5);
   	gtk_container_add(GTK_CONTAINER(dialogwindow), packingbox);
	gtk_widget_show(packingbox);

       /* 
       	*  Add the caution widget and message label to the vbox,
	*  followed by a separator.
	*/
	gtk_box_pack_start(GTK_BOX(packingbox),
		build_picwidget(caution_xpm, FALSE), TRUE, TRUE, 2);
        gtk_box_pack_start(GTK_BOX(packingbox), 
		widget = gtk_label_new(message), TRUE, TRUE, 2);
	gtk_widget_show(widget);
	beep();

   	yn_box = gtk_hbox_new(TRUE, 5);

       /* 
	*  Add the buttons and connect them to their signal handlers.
	*/
	gtk_box_pack_start(GTK_BOX(yn_box), 
		dialogwidget = gtk_button_new_with_label("yes"), TRUE, TRUE, 2);
        gtk_signal_connect (GTK_OBJECT(dialogwidget), "clicked", 
		GTK_SIGNAL_FUNC(dialog_response), (gpointer)"tests_TRUE");
	gtk_widget_show(dialogwidget);
	gtk_widget_show(yn_box);

	Shm->wmd->kill_tests_dialog_yes = track_widget(dialogwidget);

	gtk_box_pack_start(GTK_BOX(yn_box), 
		dialogwidget = gtk_button_new_with_label("no"), TRUE, TRUE, 2);
        gtk_signal_connect (GTK_OBJECT(dialogwidget), "clicked",
                GTK_SIGNAL_FUNC(dialog_response), (gpointer)"tests_FALSE"); 
	gtk_widget_show(dialogwidget);

	Shm->wmd->kill_tests_dialog_no = track_widget(dialogwidget);

   	gtk_box_pack_start(GTK_BOX(packingbox), yn_box, TRUE, TRUE, 2 );

       /* 
	*  Set the modality of the window and show it.
        */
   	gtk_window_set_modal(GTK_WINDOW(dialogwindow), TRUE); 
   	gtk_widget_show(dialogwindow);
}

static gchar *kill_usex_message = \
    "Clicking \"yes\" will shut down\nthis USEX session.\nAre you sure?";

static gint 
kill_usex_button_release(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	kill_usex_dialog_window(kill_usex_message);
        return(0);
}

static gint
usex_control_button_release(GtkWidget *widget, GdkEvent *event, gpointer data)
{
        gtk_menu_popup(GTK_MENU(Shm->wmd->usex_control),
                NULL, NULL, NULL, NULL, 0, 0); 
        return(0);
}

static gint
help_button_release(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_mgr_help_table();
        return(0);
}

static gint     
hidden_button_press(GtkWidget *widget, gpointer data)
{
        g_print("hidden button pressed!!!\n");
        return(0);
}

static gchar *kill_tests_message = \
    "Clicking \"yes\" will kill all running tests.\nAre you sure?";

static gint
test_control_button_release(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	if (streq(data, "FGND"))
		test_control_menu(widget, TEST_FOREGROUND_ALL);
	if (streq(data, "BKGD"))
		test_control_menu(widget, TEST_BACKGROUND_ALL);
	if (streq(data, "HOLD"))
		test_control_menu(widget, TEST_HOLD_ALL);
/**
	if (streq(data, "KILL"))
		test_control_menu(widget, TEST_KILL_ALL);
**/
	if (streq(data, "KILL"))
		kill_tests_dialog_window(kill_tests_message);

	return(0);
}

/*
 *  This function is called by gtk_main() whenever it has no other GUI events
 *  to handle.  This function calls gtk_mgr() to handle USEX matters:
 *
 *  (1) If no test process had any data in its queue, and no GUI event occurred
 *      while checking for it, we stall for at least a millisecond in order to
 *      keep gnusex as idle as possible.  
 *
 *  (2) If either test data was available, or if a GUI event occured while 
 *      checking for it, we immediately return to gtk_main().
 *
 *  This scheme should keep both the GUI and USEX test handling satisfied
 *  without burdening the system with useless system activity. 
 */

static gint 
gtk_mgr_idle(gpointer data)
{
	if (Shm->wmd->flags & GTK_MGR_RESIZE) {
        	gtk_window_set_policy(GTK_WINDOW(Shm->wmd->toplevel),
                	FALSE, TRUE, FALSE);
		Shm->wmd->flags &= ~GTK_MGR_RESIZE;
	}

        if (Shm->mode & SHUTDOWN_MODE) {
                gtk_main_quit();
		return TRUE;
        }

	while (!gtk_mgr() && !gtk_events_pending()) 
		stall(1000); 

	return TRUE;
}

/*
 *  Change a widget's default font.
 */
static void
gtk_mgr_set_font(GtkWidget *widget, GdkFont *font)
{
	GtkStyle *style;

	if (!font)
		return;

	style = gtk_style_copy(gtk_widget_get_style(widget));
	style->font = font;
	gtk_widget_set_style(widget, style);
}

/*
 *  Create a generic frame and stuff it in the vbox.
 */
static GtkWidget *
build_frame(gchar *name, GtkWidget *box, gint expand, gint fill, 
	    gint shadow, gint show_name)
{
	GtkWidget *frame;

	frame = gtk_frame_new(show_name ? name : NULL);
	
        gtk_frame_set_shadow_type(GTK_FRAME(frame), shadow);
	gtk_box_pack_start(GTK_BOX(box), frame, expand, fill, 5);
	gtk_widget_show(frame);

	return frame;
}

/*
 *  Create a scrolled generic frame and stuff it in the vbox.
 */
static GtkWidget *
build_scrolled_frame(gchar *name, GtkWidget *box, gint expand, gint fill,
                     gint shadow, gint show_name)
{
        GtkWidget *frame;
	GtkWidget *scrollwindow;

        frame = gtk_frame_new(show_name ? name : NULL);
        gtk_frame_set_shadow_type(GTK_FRAME(frame), shadow);

	Shm->wmd->scrollwindow = scrollwindow = 
		gtk_scrolled_window_new(GTK_ADJUSTMENT 
		(gtk_adjustment_new(0,0,1000,0,0,0)),
		GTK_ADJUSTMENT(gtk_adjustment_new(0,0,1000,0,0,0)));

	gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrollwindow),
		GTK_POLICY_NEVER,
		GTK_POLICY_AUTOMATIC);

	gtk_scrolled_window_add_with_viewport(GTK_SCROLLED_WINDOW(scrollwindow),
		frame);

        gtk_box_pack_start(GTK_BOX(box), scrollwindow, expand, fill, 5);

        gtk_widget_show(frame);
        gtk_widget_show(scrollwindow);

        return frame;
}

/*
 *  Build an individual entry in the test table.
 */
static GtkWidget *
build_test_data_entry(GtkWidget *table, gboolean mod, gboolean show, 
	gint left, gint right, gint top, gint bottom, gchar *init,
	GtkWidget **widget_frame)
{
        GtkWidget *entry = NULL;
        GtkWidget *frame = NULL;

        entry = gtk_label_new(init ? init : "");
	gtk_label_set_text(GTK_LABEL(entry), init ? init : "");
	gtk_widget_show(entry);

	if (mod) {
        	frame = gtk_frame_new(NULL);
        	gtk_frame_set_shadow_type(GTK_FRAME(frame), GTK_SHADOW_IN);
        	gtk_container_add(GTK_CONTAINER(frame), entry);
		if (show)
			gtk_widget_show(frame);
		if (widget_frame)
			*widget_frame = frame;
	}

        gtk_table_attach_defaults(GTK_TABLE(table), mod ? frame : entry,
                left, right, top, bottom);

        return entry;
}

/*
 *  GTK Replacement for curses function.
 */
int
beep(void)
{
	g_print("");
	return TRUE;
}

/*
 *  Individual test control menu executioner.
 */
static void
individual_test_menu(GtkWidget *widget, gpointer data)
{
	ulong item;
        uint id;
	FILE *fp;
        char buf[MESSAGE_SIZE];

	item = (ulong)data;
	id = Shm->wmd->test_control_id;

	if (id >= Shm->procno) {
                sprintf(buf, "invalid request: test %d does not exist", id+1);
                USER_MESSAGE(buf);
                beep();
                return;
	}

	switch (item)
	{
	case (ulong)TEST_BACKGROUND:
	        if (Shm->ptbl[id].i_stat & IO_DEAD) {
	                sprintf(buf, "invalid request: test %d is dead", id+1);
	                USER_MESSAGE(buf);
	                beep();
	                break;
	        }
	
	        Shm->ptbl[id].i_stat &= ~(IO_HOLD|IO_HOLD_PENDING|HANG);
	        Shm->ptbl[id].i_stat |= IO_BKGD;
	        gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].stat), 
			"BKGD");
	
	        sprintf(buf, "put test %d in background (BKGD) display mode", 
			id+1);
	        USER_MESSAGE_WAIT(buf);

	        gtk_mgr_test_background(id);
		break;

	case (ulong)TEST_FOREGROUND: 
	        id = Shm->wmd->test_control_id;
	
	        if (Shm->ptbl[id].i_stat & IO_DEAD) {
	                sprintf(buf, "invalid request: test %d is dead", id+1);
	                USER_MESSAGE(buf);
	                beep();
	                return;
	        }       
	                
	        Shm->ptbl[id].i_stat &= ~(IO_BKGD|IO_HOLD|IO_HOLD_PENDING|HANG);
	        gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].stat), 
			"OK");
	
	        sprintf(buf, "put test %d in foreground (OK) display mode", 
			id+1);
	        USER_MESSAGE_WAIT(buf);
	
	        gtk_mgr_test_foreground(id);
		break;

	case (ulong)TEST_HOLD:       
	        if (Shm->ptbl[id].i_stat & IO_DEAD) {
	                sprintf(buf, "invalid request: test %d is dead", id+1);
	                USER_MESSAGE(buf);
	                beep();
	                break;
	        }
	
	        Shm->ptbl[id].i_stat |= IO_HOLD_PENDING;
                gtk_label_set_text(GTK_LABEL(Shm->wmd->test_data[id].stat), 
			"WAIT");
	
	        sprintf(buf, "put test %d on HOLD", id+1);
	        USER_MESSAGE_WAIT(buf);
		break;

	case (ulong)TEST_KILL:       
	        if (Shm->ptbl[id].i_stat & IO_DEAD) {
	                sprintf(buf, 
			    "invalid request: test %d is already dead", id+1);
	                USER_MESSAGE(buf);
	                beep();
	                return;
	        }
	
	        common_kill(id, NOARG);
	
	        if (Shm->ptbl[id].i_stat & IO_DEAD)
	                gtk_label_set_text(GTK_LABEL
				(Shm->wmd->test_data[id].stat), "DEAD");
	        else
	                gtk_label_set_text(GTK_LABEL
				(Shm->wmd->test_data[id].stat), "KILL");
	
	        sprintf(buf, "kill test %d", id+1);
	        USER_MESSAGE_WAIT(buf);
		break;

	case (ulong)TEST_MESSAGES:   
	        sprintf(buf, "display test %d messages", id+1);
	        USER_MESSAGE(buf); 
	
	        if ((fp = tmpfile()) == NULL) {
	                strcat(buf, ": tmpfile() failed");
	                USER_MESSAGE(buf);
	                beep();
	                break;
	        }
	
	        last_message_query(id + FIRST_ID, fp, TRUE);
	        rewind(fp);
	        gtk_mgr_display_external(fp, buf);
	        fclose(fp);
		break;

	case (ulong)TEST_INQUIRY:    
	        sprintf(buf, "test %d inquiry", id+1);
	        if (widget)
	                USER_MESSAGE(buf);
	
	        if ((fp = tmpfile()) == NULL) {
	                strcat(buf, ": tmpfile() failed");
	                USER_MESSAGE(buf);
	                beep();
	                break;
	        }
	
	        test_inquiry(id, fp, TRUE);
	        rewind(fp);
	        gtk_mgr_display_external(fp, buf);
	        fclose(fp);
		break;

	default:
		console("individual_test_menu: invalid item: %d\n", item);
		break;
	}

}

/*
 *  Global test control menu executioner.
 */
static void
test_control_menu(GtkWidget *widget, gpointer data)
{
	ulong item;
        int id, cnt;
	FILE *fp;
	char buf[MESSAGE_SIZE];

	item = (ulong)data;

	if (Shm->procno == 0) {
		USER_MESSAGE("no tests are running");
		beep();
		return;
	}

	switch (item)
	{
	case (ulong)TEST_BACKGROUND_ALL: 
	        for (id = cnt = 0; id < Shm->procno; id++) {
	                if (!(Shm->ptbl[id].i_stat & IO_DEAD)) {
	                        Shm->wmd->test_control_id = id;
	                        individual_test_menu(NULL, TEST_BACKGROUND);
	                        cnt++;
	                }
	        }
	
	        if (cnt == 0) {
	                USER_MESSAGE("all tests are dead");
	                beep();
	        } else if (cnt == Shm->procno)
	            	USER_MESSAGE(
			    "all tests in background (BKGD) display mode");
	        else
	            	USER_MESSAGE(
	                   "remaining tests in background (BKGD) display mode");
		break;

	case (ulong)TEST_FOREGROUND_ALL:
	        for (id = cnt = 0; id < Shm->procno; id++) {
	                if (!(Shm->ptbl[id].i_stat & IO_DEAD)) {
	                        Shm->wmd->test_control_id = id;
	                        individual_test_menu(NULL, TEST_FOREGROUND);
	                        cnt++;
	                }
	        }
	
	        if (cnt == 0) {
	                USER_MESSAGE("all tests are dead");
	                beep();
	        } else if (cnt == Shm->procno)
	                USER_MESSAGE(
			    "all tests in foreground (OK) display mode");
	        else
	                USER_MESSAGE(
			    "remaining tests in foreground (OK) display mode");
		break;

	case (ulong)TEST_HOLD_ALL:       
	        for (id = cnt = 0; id < Shm->procno; id++) {
	                if (!(Shm->ptbl[id].i_stat & IO_DEAD)) {
	                        Shm->wmd->test_control_id = id;
	                        individual_test_menu(NULL, TEST_HOLD);
	                        cnt++;
	                }
	        }
	                
	        if (cnt == 0) {
	                USER_MESSAGE("all tests are dead");
	                beep();
	        } else if (cnt == Shm->procno)
	                USER_MESSAGE("all tests on hold");
	        else
	                USER_MESSAGE("all remaining tests on hold");
		break;

	case (ulong)TEST_KILL_ALL:       
		common_kill(KILL_ALL, MAX_IO_TESTS);
                file_cleanup();
		break;

	case (ulong)TEST_MESSAGES_ALL:   
	        sprintf(buf, "display all test messages");
	        USER_MESSAGE(buf);
	
	        if ((fp = tmpfile()) == NULL) {
	                strcat(buf, ": tmpfile() failed");
	                USER_MESSAGE(buf);
	                beep();
	                break;
	        }       
	                
	        last_message_query(ALL_MESSAGES, fp, TRUE);
	        rewind(fp);
	        gtk_mgr_display_external(fp, buf);
	        fclose(fp);
		break;

	case (ulong)TEST_FATAL_MESSAGES: 
	        sprintf(buf, "display all test fatal error messages");
	        USER_MESSAGE(buf);
	
	        if ((fp = tmpfile()) == NULL) {
	                strcat(buf, ": tmpfile() failed");
	                USER_MESSAGE(buf);
	                beep();
	                break;
	        }
	
	        last_message_query(FATAL_MESSAGES, fp, TRUE);
	        rewind(fp);
	        gtk_mgr_display_external(fp, buf);
	        fclose(fp);
		break;

	default:
		console("test_control_menu: invalid item: %d\n", item);
		break;
	}


}

/*
 *  USEX control menu executioner.
 */
static void
usex_control_menu(GtkWidget *widget, gpointer data)
{
	ulong item;
        FILE *fp;
        gchar *usefile = NULL;
        char buffer[MESSAGE_SIZE];

	item = (ulong)data;

	switch (item)
	{
	case (ulong)USEX_INQUIRY:
	        sprintf(buffer, "USEX inquiry");
	        USER_MESSAGE(buffer);
	
	        if ((fp = tmpfile()) == NULL) {
	                strcat(buffer, ": tmpfile() failed");
	                USER_MESSAGE(buffer);
	                beep();
	                break;
	        }
	
	        usex_inquiry(fp);
	        rewind(fp);
	        gtk_mgr_display_external(fp, buffer);
	        fclose(fp);
		break;

	case (ulong)USEX_SNAPSHOT:   
		dump_status(INTERACTIVE_STATUS, NULL);
		break;

	case (ulong)SAVE_INPUT_FILE: 
		Shm->mode |= SAVE_DEFAULT;
		/* FALLTHROUGH */

	case (ulong)SHOW_INPUT_FILE:  
	        if (Shm->infile && 
		    (strcmp(Shm->outfile, Shm->default_file) != 0))
	            	usefile = Shm->outfile;
	        else if (Shm->infile && 
		    (strcmp(Shm->infile, Shm->outfile) != 0))
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
	                sprintf(buffer, "input file: %s", usefile);
	
	        USER_MESSAGE(buffer);
	
	        if (usefile) {
	                if ((fp = fopen(usefile, "r")) == NULL) {
	                        sprintf(buffer, "cannot open input file: %s", 
					usefile);
	                        USER_MESSAGE(buffer);
	                        beep();
	                        break;
	                }
	                rewind(fp);
	                gtk_mgr_display_external(fp, usefile);
	                fclose(fp);
	        }
		break;

	case (ulong)EXTERNAL_SHELL:   
		if (strlen(Shm->ext_terminal)) {
			sprintf(buffer, "%s &", Shm->ext_terminal);
			system(buffer);
	
		} else if (file_exists("/usr/X11R6/bin/xterm"))
			system("/usr/X11R6/bin/xterm -font fixed &");
		else
			system("xterm -font fixed &");
		break;

        case (ulong)EXTERNAL_TOP:
		if (!file_exists("/usr/bin/top"))
			break;
		if (strlen(Shm->ext_terminal)) {
			sprintf(buffer, "%s -e /usr/bin/top &", Shm->ext_terminal);
			system(buffer);
		} else if (file_exists("/usr/X11R6/bin/xterm"))
                        system("/usr/X11R6/bin/xterm -font fixed"
		               " -e /usr/bin/top &");
                else
                        system("xterm -font fixed -e /usr/bin/top &");
                break;

	case (ulong)TOGGLE_DEBUG:     
	        if (Shm->mode & DEBUG_MODE) {
	                USER_MESSAGE("Debug OFF");
	                Shm->mode &= ~DEBUG_MODE;
	        } else {
	                USER_MESSAGE("Debug ON");
	                Shm->mode |= DEBUG_MODE;
	        }
		break;

        case (ulong)USEX_UNAME_INFO:
                sprintf(buffer, "System utsname data");
                USER_MESSAGE(buffer);

                if ((fp = tmpfile()) == NULL) {
                        strcat(buffer, ": tmpfile() failed");
                        USER_MESSAGE(buffer);
                        beep();
                        break;
                }

                fprintf(fp, " sysname: %s\n", Shm->utsname.sysname);
                fprintf(fp, "nodename: %s\n", Shm->utsname.nodename);
                fprintf(fp, " release: %s\n", Shm->utsname.release);
                fprintf(fp, " version: %s\n", Shm->utsname.version);
                fprintf(fp, " machine: %s\n\n", Shm->utsname.machine);

                rewind(fp);
                gtk_mgr_display_external(fp, buffer);
                fclose(fp);
		break;

        case (ulong)USEX_BUILD_INFO:
                sprintf(buffer, "USEX build information");
                USER_MESSAGE(buffer);

                if ((fp = tmpfile()) == NULL) {
                        strcat(buffer, ": tmpfile() failed");
                        USER_MESSAGE(buffer);
                        beep();
                        break;
                }

                fprintf(fp, "%s\n", build_date);
                fprintf(fp, "%s\n", build_machine);
                fprintf(fp, "%s\n", build_id);
                fprintf(fp, "%s\n\n\n", build_sum);

                rewind(fp);
                gtk_mgr_display_external(fp, buffer);
                fclose(fp);
                break;

	default:
		console("usex_control_menu: invalid item: %d\n", item);
		break;
	}
}

static gint   
hide_window_on_delete(GtkWidget *widget, gpointer data)
{
        gtk_widget_hide(widget);
	return TRUE;
}

#define HELP_TABLE_SPACER       (NULL)
#define HELP_TABLE_EMPTY_FIELD  ((GtkWidget *)(-1))

static void
build_help_table_entry(GtkWidget *entry, gint inframe, 
	GtkJustification just, gint left, gint right, gint top, gint bottom)
{
	GtkWidget *frame;
	GtkWidget *vbox;

	if (entry == HELP_TABLE_SPACER) {
		vbox = gtk_vbox_new(FALSE, 0);
		gtk_widget_show(vbox);
		gtk_table_attach(GTK_TABLE(Shm->wmd->help_table), vbox,
			left, right, top, bottom,
			GTK_EXPAND | GTK_FILL,
			GTK_EXPAND | GTK_FILL,
			0, inframe);
		return;
	}

	if (entry == HELP_TABLE_EMPTY_FIELD) {
                frame = gtk_frame_new(NULL);
                gtk_frame_set_shadow_type(GTK_FRAME(frame),
                        GTK_SHADOW_ETCHED_OUT);
                gtk_container_add(GTK_CONTAINER(frame), 
			entry = gtk_label_new(""));
                gtk_table_attach_defaults(GTK_TABLE
                        (Shm->wmd->help_table),
                        frame, left, right, top, bottom);
                gtk_widget_show(frame);
                gtk_widget_show(entry);
		return;
	}

	if (just == GTK_JUSTIFY_LEFT) { 
       		gtk_misc_set_alignment(GTK_MISC(entry), 0.0f, 0.5f);
		gtk_label_set_justify(GTK_LABEL(entry), GTK_JUSTIFY_LEFT);
	}

	if ((left == 2) && inframe) 
		gtk_mgr_set_font(entry, Shm->wmd->fixed);

	if (inframe) {
                frame = gtk_frame_new(NULL);
                gtk_frame_set_shadow_type(GTK_FRAME(frame), 
			left == 0 ?  GTK_SHADOW_ETCHED_OUT : GTK_SHADOW_IN);
                gtk_container_add(GTK_CONTAINER(frame), entry);
        	gtk_table_attach_defaults(GTK_TABLE
	       		(Shm->wmd->help_table), 
			frame, left, right, top, bottom);
                gtk_widget_show(frame);
		gtk_widget_show(entry);
	} else {
        	gtk_table_attach_defaults(GTK_TABLE(Shm->wmd->help_table), 
			entry, left, right, top, bottom);
		gtk_widget_show(entry);
	}
}

static void
gtk_mgr_help_table(void)
{
	GtkWidget *toplevel;
	GtkWidget *table;
	GtkWidget *vbox;
	GtkWidget *button;
	gint top, bot;
	char buffer[MESSAGE_SIZE];

        sprintf(buffer, "USEX help page");
        USER_MESSAGE(buffer);

	if (Shm->wmd->help_window) {
		gtk_widget_show(Shm->wmd->help_window);
		return;
	}

        Shm->wmd->help_window = toplevel = gtk_window_new(GTK_WINDOW_TOPLEVEL);
        gtk_window_set_title(GTK_WINDOW(toplevel), "USEX Help Window");
        gtk_window_set_position(GTK_WINDOW(toplevel), GTK_WIN_POS_MOUSE);
        gtk_signal_connect(GTK_OBJECT(toplevel), "delete_event",
                GTK_SIGNAL_FUNC(hide_window_on_delete), NULL);
        gtk_window_set_policy(GTK_WINDOW(toplevel),
                        FALSE, FALSE, FALSE);
	track_widget(toplevel);

	Shm->wmd->help_table = table = gtk_table_new(30, 4, FALSE);
	gtk_table_set_col_spacings(GTK_TABLE(table), 5);
	gtk_container_add(GTK_CONTAINER(toplevel), table);

	top = 0; bot = 1;

	build_help_table_entry(HELP_TABLE_SPACER, 3, GTK_JUSTIFY_CENTER, 
		0, 1, top++, bot++);

	build_help_table_entry(gtk_label_new("Button"), FALSE,
		GTK_JUSTIFY_CENTER, 0, 1, top, bot);
	build_help_table_entry(gtk_label_new("Menu Item"), FALSE, 
		GTK_JUSTIFY_CENTER, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new("Keystroke(s)"), FALSE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
	build_help_table_entry(gtk_label_new("Action"), FALSE,
		GTK_JUSTIFY_CENTER, 3, 4, top++, bot++);

	build_help_table_entry(HELP_TABLE_SPACER, 3, GTK_JUSTIFY_CENTER, 
		0, 1, top++, bot++);

	build_help_table_entry(build_picwidget((gchar **)FGND_xpm, FALSE),
		TRUE, GTK_JUSTIFY_CENTER, 0, 1, 3, 4);

	build_help_table_entry(build_picwidget((gchar **)BKGD_xpm, FALSE),
		TRUE, GTK_JUSTIFY_CENTER, 0, 1, 4, 5);

	build_help_table_entry(build_picwidget((gchar **)HOLD_xpm, FALSE),
		TRUE, GTK_JUSTIFY_CENTER, 0, 1, 5, 6);

	build_help_table_entry(build_picwidget((gchar **)KILL_xpm, FALSE),
		TRUE, GTK_JUSTIFY_CENTER, 0, 1, 6, 7);

	vbox = gtk_vbox_new(TRUE, 0);
	button = gtk_button_new();
	/* gtk_widget_set_usize(button, 40, 40); */
	gtk_container_add(GTK_CONTAINER(button), 	
		build_picwidget((gchar **)testctl_xpm, FALSE));
	gtk_widget_show(button);
	gtk_box_pack_start(GTK_BOX(vbox), button, FALSE, FALSE, 0);
	build_help_table_entry(vbox,
		TRUE, GTK_JUSTIFY_CENTER, 0, 1, 8, 17);

	build_help_table_entry(build_picwidget
		((gchar **)button_horiz_xpm, FALSE),
		TRUE, GTK_JUSTIFY_CENTER, 0, 1, 18, 24);

	build_help_table_entry(build_picwidget((gchar **)stop_xpm, FALSE),
		TRUE, GTK_JUSTIFY_CENTER, 0, 1, 25, 26);

	build_help_table_entry(build_picwidget((gchar **)help_xpm, FALSE),
		TRUE, GTK_JUSTIFY_CENTER, 0, 1, 27, 28);

        build_help_table_entry(HELP_TABLE_EMPTY_FIELD,
                TRUE, GTK_JUSTIFY_CENTER, 0, 1, 29, 30);

        build_help_table_entry(gtk_label_new("t<RETURN>"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(HELP_TABLE_EMPTY_FIELD,
                TRUE, GTK_JUSTIFY_CENTER, 1, 2, top, bot); 
        build_help_table_entry(gtk_label_new
                (" Put all tests in foreground display mode. " 
                 " Each test STAT will indicate: OK "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("tb"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(HELP_TABLE_EMPTY_FIELD,
                TRUE, GTK_JUSTIFY_CENTER, 1, 2, top, bot); 
        build_help_table_entry(gtk_label_new
                (" Put all tests in background display mode. "
                 " Each test STAT will indicate: BKGD "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("th"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(HELP_TABLE_EMPTY_FIELD,
                TRUE, GTK_JUSTIFY_CENTER, 1, 2, top, bot); 
        build_help_table_entry(gtk_label_new
                (" Put all tests on hold. "
                 " Each test STAT will indicate: WAIT, then HOLD "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("tk"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(HELP_TABLE_EMPTY_FIELD,
                TRUE, GTK_JUSTIFY_CENTER, 1, 2, top, bot); 
        build_help_table_entry(gtk_label_new
		(" Kill all tests.  Each test STAT will indicate: DEAD\n"
		 " A subsequent dialog box requires positive confirmation. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(HELP_TABLE_SPACER, 5, GTK_JUSTIFY_CENTER,
                0, 1, top++, bot++);

        build_help_table_entry(gtk_label_new("m"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new
		(" Show last test messages "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
           (" Display last 30 messages from all tests in an external window. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("M"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new
                (" Show fatal error messages "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Display fatal error messages from all dead tests "
                 "in an external window. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("f"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new
		(" Show input file "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Display the name and contents of the session's "
                 "input file in an external window. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("F"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new
		(" Save input file "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Display the name and contents of the session's input file "
                 " in an external window. \n"
	         " Save the input file when the session is killed. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("i or I"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new
                (" Inquiry of internal state "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Display USEX internal state in an external window. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("s"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new
                (" Snapshot internal state "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Save a snapshot of USEX internal state in a file. \n"
		 " The filename will be displayed in the status bar."),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("d"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new
                (" Toggle debug mode "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Enter/Leave USEX debug mode.  The current state will be \n"
		 " displayed in the status bar."),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("!"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new
                (" External shell "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Open a shell in an external window. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("T"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new
                (" External top session "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Start top session in an external window. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("b"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new(" Build information "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Display USEX build information in an external window. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(HELP_TABLE_SPACER, 5, GTK_JUSTIFY_CENTER,
                0, 1, top++, bot++);

        build_help_table_entry(gtk_label_new(" t<number><RETURN> "), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new(" Foreground "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Put the selected test in foreground display mode. "
                 " Test STAT will indicate: OK "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("t<number>b"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new(" Background "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Put the selected test in background display mode. "
                 " Test STAT will indicate: BKGD "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("t<number>h"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new(" Hold "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Put the selected test in HOLD mode. "
                 " Test STAT will indicate: WAIT, then HOLD "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("t<number>k"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new(" Kill "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Kill selected test.  Test STAT will indicate: DEAD "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("t<number>i"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new(" Inquiry "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Display the internal state of the selected test in "
                 "an external window. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

        build_help_table_entry(gtk_label_new("t<number>m"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new(" Messages "),
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new
                (" Display the last 30 messages from the selected test in an"
                 " external window. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

	build_help_table_entry(HELP_TABLE_SPACER, 5, GTK_JUSTIFY_CENTER, 
		0, 1, top++, bot++);

        build_help_table_entry(gtk_label_new("k or q"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(HELP_TABLE_EMPTY_FIELD,
                TRUE, GTK_JUSTIFY_CENTER, 1, 2, top, bot); 
        build_help_table_entry(gtk_label_new
                (" Kill all tests and then shutdown the USEX session. \n"
                 " A subsequent dialog box requires positive confirmation. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);
  
	build_help_table_entry(HELP_TABLE_SPACER, 5, GTK_JUSTIFY_CENTER, 
		0, 1, top++, bot++);

        build_help_table_entry(gtk_label_new("h"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(HELP_TABLE_EMPTY_FIELD,
                TRUE, GTK_JUSTIFY_LEFT, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new(" Display this HELP window. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

	build_help_table_entry(HELP_TABLE_SPACER, 5, GTK_JUSTIFY_CENTER, 
		0, 1, top++, bot++);

        build_help_table_entry(HELP_TABLE_EMPTY_FIELD,
		TRUE, GTK_JUSTIFY_CENTER, 1, 2, top, bot);
        build_help_table_entry(gtk_label_new("<RETURN>"), TRUE,
                GTK_JUSTIFY_CENTER, 2, 3, top, bot);
        build_help_table_entry(gtk_label_new
                (" Clear status bar. "),
                TRUE, GTK_JUSTIFY_LEFT, 3, 4, top++, bot++);

	build_help_table_entry(HELP_TABLE_SPACER, 3, GTK_JUSTIFY_CENTER, 
		0, 1, top++, bot++);

	gtk_widget_show(table);
	gtk_widget_show(toplevel);
}


#ifdef NOTDEF
/* XPM */
static char * exec_xpm[] = {
"16 16 11 1",
" 	c None",
".	c #000000",
"+	c #DCDCDC",
"@	c #A0A0A0",
"#	c #C3C3C3",
"$	c #808080",
"%	c #FFA858",
"&	c #FFDCA8",
"*	c #FFFFC0",
"=	c #FFFFFF",
"-	c #585858",
"       ..       ",
"   .. .++. ..   ",
"  .+@.@##@.@+.  ",
"  .@+$@%%@$+@.  ",
"   .$%%&%&%$.   ",
" ..+@%&$$%&@+.. ",
".+#@%&%@@&*%@#+.",
".$@+$&*&&=*$+@$.",
" .--+$&*=&$+--. ",
"  .$#++$$++#$.  ",
" .@=$-$++$-$=@. ",
" .+@-..@@..-@+. ",
"  ... .+=. ...  ",
"      .-$.      ",
"       ..       ",
"                "
};
#endif

/* XPM */
static char * button_horiz_xpm[] = {
"12 12 33 1",
" 	c None",
".	c #020204",
"+	c #7D7A89",
"@	c #B9B6BC",
"#	c #A3A1AC",
"$	c #D7D7DC",
"%	c #C6C6CC",
"&	c #8C8A94",
"*	c #5C5C6C",
"=	c #6F6C7C",
"-	c #ADABB4",
";	c #C0BFC5",
">	c #858492",
",	c #D1D0D4",
"'	c #95939F",
")	c #757382",
"!	c #B4B2BC",
"~	c #646274",
"{	c #EEEEEC",
"]	c #DEDEE4",
"^	c #A6A6AC",
"/	c #827E8C",
"(	c #BEBAC4",
"_	c #B2AEB8",
":	c #8A8694",
"<	c #D6D2DC",
"[	c #9A96A4",
"}	c #7A7684",
"|	c #6A666D",
"1	c #7E7E8C",
"2	c #BABAC0",
"3	c #CACACE",
"4	c #8E8E9C",
"{{{{{{{{{{{{",
"{**~~==)}+/|",
"{~|==}}1>:&|",
"{=)}11>:&4'|",
"{..........|",
"{.],;@-#'>.|",
"{.$32_#'&+.|",
"{..........|",
"{#^-_!@2;;3|",
"{-_!@;;%3,<|",
"{@;;;3,,$$]|",
"||||||||||||"
};


static char * testctl_xpm[] = {
"32 32 9 1",
" 	c None",
".	c #000000",
"+	c #999999",
"@	c #CCCCCC",
"#	c #FF0000",
"$	c #00FF00",
"%	c #FFFFCC",
"&	c #00FFFF",
"*	c #FFFFFF",
"              @@@@@@@@@@@@@@@@@+",
"              @****************+",
" +++          @*@@@@@@@@@@@@@@@+",
"+***.         @*@@..@@...@@@..@+",
"+**@*.        @*@@.@@.&&&.@@.@@+",
"+*@@@*+       @*@@..@@...@@@..@+",
" .+@@@.+++    @*@@.@@@@.@@@@.@@+",
"  .+@@*.**.   @*@...@@@..@@@..@+",
"   ..+@*.@*.  @*.&&&.@@.@@@@.@@+",
"    +.+@*.@.+ @*@...@@@..@@...@+",
"    +*.+@.@.+ @*@@.@@@@.@@.&&&.+",
"    +*@..@@.+ @*@@..@@@..@@...@+",
"     +@@@@.++ @*@@.@@@@.@@@@.@@+",
"      +...++  @*@@@@@@@@@@@@@@@+",
"       ++++   ++++++++++++++++++",
"                                ",
"                                ",
"      ++++      ++++     ++++   ",
"     +****.    +@@@@+   +@@@@.  ",
"    +*@..@*.  +@*++@+. +@*++@+. ",
"    +*+*@.@.+ +@+##@+.++@+$$@+.+",
"    .+*@+.@.+ +@+##@+.++@+$$@+.+",
"   +*@@+.@@.+ +@@@@@+.++@@@@@+.+",
"  +**@+.@@.++  +++++.++ .++++.++",
" +*@@@.+..++    ....++   ....++ ",
"+*@@@+.++++      ++++     ++++  ",
".*@@+.+     .                   ",
".+++.+     .*.                  ",
" ...+    + .&. +  +  +  +  +  . ",
"  ++     + .&. +  +  +  +  +  . ",
"         ...&.................. ",
"            .                   "
};

#ifdef NOTDEF
static char * bw0_xpm[] = {
"14 14 3 1",
"       c None",
".      c #FFFFFFFFFFFF",
"X      c #000000000000",
"    ...XXXX   ",
"  .....XXXXX  ",
" ......XXXXXX ",
" ......XXXXXX ",
".......XXXXXXX",
".......XXXXXXX",
".......XXXXXXX",
".......XXXXXXX",
".......XXXXXXX",
".......XXXXXXX",
" ......XXXXXX ",
" ......XXXXXX ",
"  .....XXXXX  ",
"   ....XXX    "
};

static char * bw1_xpm[] = {
"14 14 3 1",
" 	c None",
".	c #FFFFFFFFFFFF",
"X	c #000000000000",
"    .......   ",
"  ..........  ",
" ..........XX ",
" .........XXX ",
".........XXXXX",
"........XXXXXX",
".......XXXXXXX",
"......XXXXXXXX",
".....XXXXXXXXX",
"....XXXXXXXXXX",
" ..XXXXXXXXXX ",
" .XXXXXXXXXXX ",
"  XXXXXXXXXX  ",
"   XXXXXXX    "
};


static char * bw2_xpm[] = {
"14 14 3 1",
"       c None",
".      c #FFFFFFFFFFFF",
"X      c #000000000000",
"    .......   ",
"  ..........  ",
" ............ ",
" ............ ",
"..............",
"..............",
"..............",
"XXXXXXXXXXXXXX",
"XXXXXXXXXXXXXX",
"XXXXXXXXXXXXXX",
" XXXXXXXXXXXX ",
" XXXXXXXXXXXX ",
"  XXXXXXXXXX  ",
"   XXXXXXX    "
};


static char * bw3_xpm[] = {
"14 14 3 1",
" 	c None",
".      c #FFFFFFFFFFFF",
"X	c #000000000000",
"    ......    ",
"  ..........  ",
" XX.......... ",
"XXXX......... ",
"XXXXX.........",
"XXXXXX........",
"XXXXXXX.......",
"XXXXXXXX......",
"XXXXXXXXX.....",
"XXXXXXXXXX....",
" XXXXXXXXXX...",
" XXXXXXXXXXX. ",
"  XXXXXXXXXX  ",
"    XXXXXX    "
};

static char * bw4_xpm[] = {
"14 14 3 1",
"       c None",
".      c #FFFFFFFFFFFF",
"X      c #000000000000",
"    XXX....   ",
"  XXXXX.....  ",
" XXXXXX...... ",
" XXXXXX...... ",
"XXXXXXX.......",
"XXXXXXX.......",
"XXXXXXX.......",
"XXXXXXX.......",
"XXXXXXX.......",
"XXXXXXX.......",
" XXXXXX...... ",
" XXXXXX...... ",
"  XXXXX.....  ",
"   XXXX...    "
};

static char * bw5_xpm[] = {
"14 14 3 1",
" 	c None",
".	c #FFFFFFFFFFFF",
"X      c #000000000000",
"    XXXXXXX   ",
"  XXXXXXXXXX  ",
" XXXXXXXXXXX. ",
" XXXXXXXXXX.. ",
"XXXXXXXXXX....",
"XXXXXXXXX.....",
"XXXXXXXX......",
"XXXXXXX.......",
"XXXXXX........",
"XXXXX.........",
" XXX......... ",
" XX.......... ",
"  ..........  ",
"   .......    "
};

static char * bw6_xpm[] = {
"14 14 3 1",
"       c None",
".      c #FFFFFFFFFFFF",
"X      c #000000000000",
"    XXXXXXX   ",
"  XXXXXXXXXX  ",
" XXXXXXXXXXXX ",
" XXXXXXXXXXXX ",
"XXXXXXXXXXXXXX",
"XXXXXXXXXXXXXX",
"XXXXXXXXXXXXXX",
"..............",
"..............",
"..............",
" ............ ",
" ............ ",
"  ..........  ",
"   .......    "
};

static char * bw7_xpm[] = {
"14 14 3 1",
"       c None",
".      c #FFFFFFFFFFFF",
"X      c #000000000000",
"    XXXXXX    ",
"  XXXXXXXXXX  ",
" ..XXXXXXXXXX ",
"....XXXXXXXXX ",
".....XXXXXXXXX",
"......XXXXXXXX",
".......XXXXXXX",
"........XXXXXX",
".........XXXXX",
"..........XXXX",
" ..........XXX",
" ...........X ",
"  ..........  ",
"    ......    "
};

static char **bw_xpm_array[GTK_DANCE_STEPS] = {
	bw0_xpm,
	bw1_xpm,
	bw2_xpm,
	bw3_xpm,
	bw4_xpm,
	bw5_xpm,
	bw6_xpm,
	bw7_xpm
};
#endif


static char * cog1_xpm[] = {
"14 13 80 1",
" 	c None",
".	c #6E6E70",
"+	c #9B9B9D",
"@	c #DCDCDD",
"#	c #9E9EA0",
"$	c #89898B",
"%	c #F2F2F2",
"&	c #8D8D8F",
"*	c #CECECF",
"=	c #848485",
"-	c #EDEDED",
";	c #FEFEFE",
">	c #FFFFFF",
",	c #DCDCDC",
"'	c #858586",
")	c #9F9FA2",
"!	c #AAAAAC",
"~	c #CBCBCD",
"{	c #E0E0E0",
"]	c #919191",
"^	c #3F3F3F",
"/	c #A6A6A6",
"(	c #B0B0B0",
"_	c #919192",
":	c #A4A4A7",
"<	c #B1B1B4",
"[	c #F0F0F1",
"}	c #FAFAFA",
"|	c #ABABAB",
"1	c #5E5E5E",
"2	c #484848",
"3	c #FCFCFC",
"4	c #F3F3F3",
"5	c #ABABAC",
"6	c #444445",
"7	c #68686A",
"8	c #979799",
"9	c #F6F6F6",
"0	c #BFBFBF",
"a	c #D9D9D9",
"b	c #6A6A6A",
"c	c #585858",
"d	c #3E3E3E",
"e	c #262626",
"f	c #525253",
"g	c #D2D2D3",
"h	c #FDFDFD",
"i	c #EEEEEE",
"j	c #B5B5B5",
"k	c #505051",
"l	c #767678",
"m	c #DFDFDF",
"n	c #BDBDBD",
"o	c #BEBEBF",
"p	c #AAAAAD",
"q	c #E5E5E5",
"r	c #757577",
"s	c #282828",
"t	c #717171",
"u	c #3B3B3B",
"v	c #2F2F2F",
"w	c #AFAFB2",
"x	c #4E4E4F",
"y	c #59595B",
"z	c #626264",
"A	c #434343",
"B	c #303030",
"C	c #212121",
"D	c #1E1E1E",
"E	c #808082",
"F	c #CECED0",
"G	c #9F9FA1",
"H	c #363637",
"I	c #383838",
"J	c #5F5F5F",
"K	c #323232",
"L	c #49494A",
"M	c #404040",
"N	c #191919",
"O	c #252525",
"              ",
"      ..      ",
"  +@#$%%$&*$  ",
"  =-;;>;;;,'  ",
" )!~;{]^/;(_: ",
"<[}>;|112>3445",
"6789;-00a;0bcd",
"efgh;;>;;;ijke",
" l9mn[>}opq%r ",
" stuvw>@xvyzA ",
"  BCDEFGHeIJ  ",
"     KLM      ",
"     NBO      "
};

/* XPM */
static char * cog2_xpm[] = {
"14 13 81 1",
" 	c None",
".	c #838385",
"+	c #C6C6C8",
"@	c #EDEDEE",
"#	c #949496",
"$	c #F7F7F7",
"%	c #CCCCCC",
"&	c #D7D7D8",
"*	c #F2F2F2",
"=	c #FEFEFE",
"-	c #DBDBDC",
";	c #9E9EA0",
">	c #DCDCDD",
",	c #9B9B9D",
"'	c #4B4B4C",
")	c #626264",
"!	c #D0D0D0",
"~	c #FFFFFF",
"{	c #A2A2A4",
"]	c #E7E7E8",
"^	c #E0E0E0",
"/	c #919191",
"(	c #3F3F3F",
"_	c #A6A6A6",
":	c #B1B1B4",
"<	c #A4A4A7",
"[	c #A0A0A3",
"}	c #B6B6B8",
"|	c #E5E5E6",
"1	c #ABABAB",
"2	c #5E5E5E",
"3	c #484848",
"4	c #FAFAFA",
"5	c #F6F6F6",
"6	c #BFBFC2",
"7	c #303030",
"8	c #3A3A3A",
"9	c #CBCBCD",
"0	c #EDEDED",
"a	c #BFBFBF",
"b	c #D9D9D9",
"c	c #979799",
"d	c #68686A",
"e	c #5D5D5F",
"f	c #939394",
"g	c #FBFBFB",
"h	c #EAEAEA",
"i	c #FDFDFD",
"j	c #F3F3F3",
"k	c #848486",
"l	c #333333",
"m	c #262626",
"n	c #8D8D8E",
"o	c #DADADA",
"p	c #DADADB",
"q	c #AAAAAD",
"r	c #CBCBCC",
"s	c #FCFCFC",
"t	c #D5D5D6",
"u	c #5C5C5E",
"v	c #343434",
"w	c #6D6D6F",
"x	c #808081",
"y	c #2F2F2F",
"z	c #474747",
"A	c #B8B8BA",
"B	c #929294",
"C	c #434343",
"D	c #181818",
"E	c #1C1C1C",
"F	c #424243",
"G	c #BBBBBD",
"H	c #C4C4C6",
"I	c #4C4C4E",
"J	c #393939",
"K	c #595959",
"L	c #1A1A1A",
"M	c #49494A",
"N	c #1E1E1E",
"O	c #252525",
"P	c #2D2D2D",
"              ",
"   .  +@#     ",
"  #$%&*=-;>,  ",
" ')!==~===$,  ",
"{]*$=^/(_=*:< ",
"[}|~=1223~=456",
"789~=0aab=5cdd",
"ef4ghi~===jklm",
" no;.$~pqrstu ",
" v'7w5~xyzABC ",
" D7EFGHI mJK  ",
"    LzMN  O   ",
"     P7       "
};

/* XPM */
static char * cog3_xpm[] = {
"14 13 77 1",
" 	c None",
".	c #98989A",
"+	c #C5C5C6",
"@	c #BCBCBD",
"#	c #6F6F71",
"$	c #8F8F92",
"%	c #FFFFFF",
"&	c #AEAEB1",
"*	c #565658",
"=	c #68686A",
"-	c #707073",
";	c #FEFEFE",
">	c #FAFAFA",
",	c #CBCBCD",
"'	c #DFDFE0",
")	c #D4D4D5",
"!	c #555557",
"~	c #AFAFB2",
"{	c #F2F2F2",
"]	c #E1E1E1",
"^	c #D8D8D8",
"/	c #E0E0E0",
"(	c #919191",
"_	c #3F3F3F",
":	c #A6A6A6",
"<	c #F4F4F5",
"[	c #8D8D8F",
"}	c #3A3A3B",
"|	c #767678",
"1	c #B6B6B8",
"2	c #E5E5E6",
"3	c #ABABAB",
"4	c #5E5E5E",
"5	c #484848",
"6	c #EEEEEF",
"7	c #C3C3C5",
"8	c #303030",
"9	c #626263",
"0	c #EDEDED",
"a	c #BFBFBF",
"b	c #D9D9D9",
"c	c #F6F6F6",
"d	c #CFCFD1",
"e	c #C2C2C5",
"f	c #DCDCDE",
"g	c #BBBBBC",
"h	c #ECECEC",
"i	c #EDEDEE",
"j	c #7E7E80",
"k	c #555556",
"l	c #919193",
"m	c #AAAAAD",
"n	c #5F5F60",
"o	c #C1C1C3",
"p	c #DDDDDF",
"q	c #B5B5B7",
"r	c #F7F7F8",
"s	c #AEAEB0",
"t	c #373737",
"u	c #2B2B2B",
"v	c #2F2F2F",
"w	c #6D6D6F",
"x	c #89898C",
"y	c #424243",
"z	c #929294",
"A	c #1C1C1C",
"B	c #1E1E1E",
"C	c #A1A1A2",
"D	c #C4C4C6",
"E	c #2C2C2D",
"F	c #202020",
"G	c #323232",
"H	c #676768",
"I	c #696969",
"J	c #363636",
"K	c #49494A",
"L	c #181818",
"              ",
"       .      ",
"   +@#$%& *=  ",
"  -+;;%;>,')! ",
"~{]^;/(_:;<[} ",
"|12%;3445%;67 ",
"892%;0aab;cd>e",
" f%'gh%;;;i=jk",
" lmn*o%pqr>stu",
" 8v8wc%xyzhzA ",
"  B yCDEFGHI  ",
"     JKL  8   ",
"              "
};

/* XPM */
static char * cog4_xpm[] = {
"14 13 81 1",
" 	c None",
".	c #98989A",
"+	c #A9A9AC",
"@	c #E4E4E4",
"#	c #909092",
"$	c #FDFDFD",
"%	c #C0C0C1",
"&	c #6A6A6C",
"*	c #E9E9E9",
"=	c #F6F6F7",
"-	c #5C5C5F",
";	c #717172",
">	c #E7E7E8",
",	c #FEFEFE",
"'	c #FFFFFF",
")	c #D4D4D6",
"!	c #E5E5E6",
"~	c #BCBCBE",
"{	c #F2F2F2",
"]	c #F4F4F4",
"^	c #E0E0E0",
"/	c #919191",
"(	c #3F3F3F",
"_	c #A6A6A6",
":	c #FAFAFA",
"<	c #B5B5B7",
"[	c #78787A",
"}	c #535354",
"|	c #DBDBDD",
"1	c #ABABAB",
"2	c #5E5E5E",
"3	c #484848",
"4	c #F9F9F9",
"5	c #AEAEB0",
"6	c #858587",
"7	c #5B5B5D",
"8	c #EDEDED",
"9	c #BFBFBF",
"0	c #D9D9D9",
"a	c #C2C2C5",
"b	c #DBDBDC",
"c	c #F1F1F1",
"d	c #E0E0E2",
"e	c #FCFCFC",
"f	c #D5D5D6",
"g	c #555556",
"h	c #9D9DA0",
"i	c #5C5C5D",
"j	c #5B5B5C",
"k	c #88888B",
"l	c #F7F7F7",
"m	c #D8D8D9",
"n	c #DFDFE0",
"o	c #DADADB",
"p	c #636364",
"q	c #313131",
"r	c #2B2B2B",
"s	c #303030",
"t	c #2F2F2F",
"u	c #959597",
"v	c #EBEBEC",
"w	c #DEDEDF",
"x	c #505051",
"y	c #5E5E5F",
"z	c #E2E2E3",
"A	c #F5F5F5",
"B	c #929294",
"C	c #1C1C1C",
"D	c #1E1E1E",
"E	c #626264",
"F	c #7B7B7D",
"G	c #D3D3D5",
"H	c #292929",
"I	c #747476",
"J	c #696969",
"K	c #272727",
"L	c #474747",
"M	c #333334",
"N	c #3B3B3B",
"O	c #525252",
"P	c #282828",
"              ",
"    .  +@     ",
"   #$%&*=- &  ",
"   ;>,',,>),! ",
" ~{],^/(_,:<[ ",
" }|',1223'456 ",
" 7!',8990,,,'a",
" bcdde',,,f66g",
" hijkl'mn'opqr",
" stuv,wxyzABC ",
" D EFG;HrgIJ  ",
"   KtLM  rNO  ",
"    tP        "
};


/* XPM */
static char * cog5_xpm[] = {
"14 13 74 1",
" 	c None",
".	c #98989A",
"+	c #78787A",
"@	c #636365",
"#	c #959598",
"$	c #FEFEFE",
"%	c #F5F5F5",
"&	c #DCDCDD",
"*	c #E9E9E9",
"=	c #D5D5D7",
"-	c #6A6A6C",
";	c #E5E5E6",
">	c #E7E7E8",
",	c #D4D4D6",
"'	c #FFFFFF",
")	c #DEDEDF",
"!	c #7D7D7F",
"~	c #808082",
"{	c #F0F0F1",
"]	c #E0E0E0",
"^	c #919191",
"/	c #3F3F3F",
"(	c #A6A6A6",
"_	c #FAFAFA",
":	c #B5B5B7",
"<	c #353535",
"[	c #404040",
"}	c #CFCFD1",
"|	c #ABABAB",
"1	c #5E5E5E",
"2	c #484848",
"3	c #F9F9F9",
"4	c #AEAEB0",
"5	c #B1B1B2",
"6	c #EDEDED",
"7	c #BFBFBF",
"8	c #D9D9D9",
"9	c #D3D3D5",
"0	c #7E7E80",
"a	c #B6B6B8",
"b	c #E6E6E6",
"c	c #E6E6E7",
"d	c #E0E0E2",
"e	c #C7C7C9",
"f	c #656566",
"g	c #707071",
"h	c #A3A3A5",
"i	c #535353",
"j	c #6B6B6D",
"k	c #DFDFE0",
"l	c #A2A2A5",
"m	c #4E4E4F",
"n	c #4A4A4A",
"o	c #2F2F2F",
"p	c #303030",
"q	c #959597",
"r	c #EBEBEC",
"s	c #B8B8BB",
"t	c #C8C8CA",
"u	c #4B4B4C",
"v	c #282828",
"w	c #1B1B1B",
"x	c #626264",
"y	c #B0B0B2",
"z	c #C2C2C3",
"A	c #717172",
"B	c #858587",
"C	c #272727",
"D	c #3D3D3E",
"E	c #424243",
"F	c #2A2A2A",
"G	c #49494A",
"H	c #545454",
"I	c #232323",
"              ",
"    .+  .@    ",
"   #$%&*$= -  ",
" ;>,$$'$$$)$! ",
" ~{'$]^/($_:< ",
" [}'$|112'34< ",
" 5''$6778$$$90",
"a_bc$$'$$$cdef",
"ghijk''3$'lmin",
"opoqr$)s{$tuv ",
" w xyzm<A&B   ",
"   CDEF vGH   ",
"    Iv   o    "
};


/* XPM */
static char * cog6_xpm[] = {
"14 13 78 1",
" 	c None",
".	c #E4E4E4",
"+	c #A9A9AC",
"@	c #98989A",
"#	c #6A6A6C",
"$	c #A8A8AA",
"%	c #FBFBFB",
"&	c #E9E9E9",
"*	c #C0C0C1",
"=	c #FDFDFD",
"-	c #949497",
";	c #7C7C7F",
">	c #FEFEFE",
",	c #DEDEDF",
"'	c #FFFFFF",
")	c #E7E7E8",
"!	c #CBCBCD",
"~	c #E5E5E6",
"{	c #353535",
"]	c #B5B5B7",
"^	c #FAFAFA",
"/	c #E0E0E0",
"(	c #919191",
"_	c #3F3F3F",
":	c #A6A6A6",
"<	c #8A8A8D",
"[	c #808083",
"}	c #AEAEB0",
"|	c #F9F9F9",
"1	c #ABABAB",
"2	c #5E5E5E",
"3	c #484848",
"4	c #404041",
"5	c #C2C2C5",
"6	c #EDEDED",
"7	c #BFBFBF",
"8	c #D9D9D9",
"9	c #D3D3D5",
"0	c #7E7E80",
"a	c #7F7F82",
"b	c #858587",
"c	c #B1B1B4",
"d	c #D5D5D6",
"e	c #D8D8D9",
"f	c #A0A0A3",
"g	c #2B2B2B",
"h	c #2F2F2F",
"i	c #363637",
"j	c #A7A7AA",
"k	c #DFDFE0",
"l	c #F6F6F7",
"m	c #5C5C5D",
"n	c #4B4B4C",
"o	c #3B3B3B",
"p	c #545456",
"q	c #CCCCCE",
"r	c #8A8A8C",
"s	c #505051",
"t	c #88888A",
"u	c #F0F0F1",
"v	c #EBEBEC",
"w	c #6F6F71",
"x	c #2D2D2D",
"y	c #1F1F1F",
"z	c #414142",
"A	c #7B7B7D",
"B	c #292929",
"C	c #313131",
"D	c #8B8B8D",
"E	c #B0B0B2",
"F	c #626264",
"G	c #2E2E2E",
"H	c #1D1D1D",
"I	c #181818",
"J	c #434344",
"K	c #616162",
"L	c #595959",
"M	c #505050",
"              ",
"     .+  @    ",
"  # $%&#*=-   ",
" ;>,>>'>>)!)~ ",
" {]^>/(_:>^]< ",
" [}|>1223'|}4 ",
"5'''>6778>>>90",
"abbc>>'>>>dbef",
"ghij>kel>kmhno",
"  pq>rstuvw xy",
"   zA{BCDEF   ",
"   GhH IJKL   ",
"        gM    "};


/* XPM */
static char * cog7_xpm[] = {
"14 13 75 1",
" 	c None",
".	c #E4E4E4",
"+	c #B7B7B9",
"@	c #808082",
"#	c #EDEDEE",
"$	c #7E7E80",
"%	c #DCDCDD",
"&	c #7E7E81",
"*	c #949496",
"=	c #F8F8F8",
"-	c #FFFFFF",
";	c #F5F5F5",
">	c #E3E3E4",
",	c #5B5B5D",
"'	c #58585A",
")	c #E7E7E8",
"!	c #FEFEFE",
"~	c #717172",
"{	c #464647",
"]	c #8D8D8F",
"^	c #F4F4F5",
"/	c #E0E0E0",
"(	c #919191",
"_	c #3F3F3F",
":	c #A6A6A6",
"<	c #F4F4F4",
"[	c #F2F2F2",
"}	c #BCBCBE",
"|	c #979799",
"1	c #E0E0E2",
"2	c #EEEEEF",
"3	c #ABABAB",
"4	c #5E5E5E",
"5	c #484848",
"6	c #DBDBDD",
"7	c #535354",
"8	c #B1B1B4",
"9	c #CFCFD1",
"0	c #E5E5E6",
"a	c #EDEDED",
"b	c #BFBFBF",
"c	c #D9D9D9",
"d	c #3A3A3A",
"e	c #5C5C5D",
"f	c #D5D5D6",
"g	c #F1F1F1",
"h	c #DBDBDC",
"i	c #2B2B2B",
"j	c #636364",
"k	c #DADADB",
"l	c #DFDFE0",
"m	c #D8D8D9",
"n	c #F9F9FA",
"o	c #515152",
"p	c #929294",
"q	c #E2E2E3",
"r	c #5E5E5F",
"s	c #505051",
"t	c #DEDEDF",
"u	c #D3D3D5",
"v	c #444445",
"w	c #474747",
"x	c #595959",
"y	c #323232",
"z	c #6E6E70",
"A	c #555556",
"B	c #292929",
"C	c #5D5D5F",
"D	c #C4C4C6",
"E	c #79797C",
"F	c #2E2E2E",
"G	c #333334",
"H	c #4D4D4D",
"I	c #404040",
"J	c #343434",
"              ",
"     .+ @#$   ",
"  %&*=-%;>,   ",
" ')-!!-!!)~   ",
" {]^!/(_:!<[} ",
"|12-!3445-!67 ",
"890-!abbc!!0, ",
"ddef!!-!!g1gh ",
" ijk!lm!n|o@* ",
"  p;qrst!uvwx ",
"  yzAiBCDE    ",
"   Fi  GoH    ",
"        IJ    "
};


/* XPM */
static char * cog8_xpm[] = {
"14 13 83 1",
" 	c None",
".	c #E4E4E4",
"+	c #EDEDEE",
"@	c #606062",
"#	c #98989A",
"$	c #838385",
"%	c #DCDCDD",
"&	c #7E7E81",
"*	c #89898D",
"=	c #F6F6F7",
"-	c #FFFFFF",
";	c #DFDFE0",
">	c #FEFEFE",
",	c #EAEAEB",
"'	c #58585A",
")	c #E7E7E8",
"!	c #CCCCCE",
"~	c #B7B7BA",
"{	c #CBCBCD",
"]	c #78787A",
"^	c #464647",
"/	c #818184",
"(	c #F0F0F0",
"_	c #E0E0E0",
":	c #919191",
"<	c #3F3F3F",
"[	c #A6A6A6",
"}	c #FCFCFC",
"|	c #F9F9F9",
"1	c #A5A5A7",
"2	c #979799",
"3	c #E0E0E2",
"4	c #ABABAB",
"5	c #5E5E5E",
"6	c #484848",
"7	c #DBDBDD",
"8	c #5D5D5E",
"9	c #3C3C3D",
"0	c #8D8D8F",
"a	c #CFCFD1",
"b	c #E5E5E6",
"c	c #EDEDED",
"d	c #BFBFBF",
"e	c #D9D9D9",
"f	c #626263",
"g	c #202020",
"h	c #333333",
"i	c #3A3A3A",
"j	c #6C6C6E",
"k	c #EFEFEF",
"l	c #F1F1F1",
"m	c #DCDCDE",
"n	c #313131",
"o	c #AEAEB0",
"p	c #FAFAFA",
"q	c #F7F7F8",
"r	c #B1B1B3",
"s	c #D8D8D9",
"t	c #F8F8F8",
"u	c #89898B",
"v	c #4E4E4F",
"w	c #808082",
"x	c #949496",
"y	c #929294",
"z	c #ECECEC",
"A	c #343434",
"B	c #777779",
"C	c #F6F6F6",
"D	c #6D6D6F",
"E	c #2F2F2F",
"F	c #474747",
"G	c #595959",
"H	c #323232",
"I	c #616163",
"J	c #181818",
"K	c #4C4C4E",
"L	c #D3D3D4",
"M	c #424243",
"N	c #272727",
"O	c #1E1E1E",
"P	c #585859",
"Q	c #3B3B3B",
"R	c #4B4B4B",
"              ",
"     .+@ #$   ",
"  %&*=-%;>,   ",
" ')->>->>>!~{]",
" ^/(>_:<[>}|)1",
"233|>4556->789",
"0ab->cdde>>bfg",
"hijk>>->>l3lm ",
" nopqrs>tuvwx ",
"  yzyAB>CDEFG ",
"  HIHJK%LM    ",
"   N  OvPh    ",
"       QR     "};


/* XPM */
static char * cog9_xpm[] = {
"14 13 78 1",
" 	c None",
".	c #949496",
"+	c #EDEDEE",
"@	c #C9C9CA",
"#	c #838385",
"$	c #9B9B9D",
"%	c #DCDCDD",
"&	c #9E9EA0",
"*	c #DBDBDC",
"=	c #FFFFFF",
"-	c #F6F6F6",
";	c #DFDFE0",
">	c #ECECEC",
",	c #E9E9EA",
"'	c #F7F7F7",
")	c #FEFEFE",
"!	c #AAAAAC",
"~	c #A4A4A7",
"{	c #B1B1B4",
"]	c #F2F2F2",
"^	c #E0E0E0",
"/	c #919191",
"(	c #3F3F3F",
"_	c #A6A6A6",
":	c #AFAFB2",
"<	c #BFBFC2",
"[	c #FDFDFD",
"}	c #ABABAB",
"|	c #5E5E5E",
"1	c #484848",
"2	c #FAFAFA",
"3	c #BABABC",
"4	c #767678",
"5	c #68686A",
"6	c #818184",
"7	c #EDEDED",
"8	c #BFBFBF",
"9	c #D9D9D9",
"0	c #CBCBCD",
"a	c #5D5D5F",
"b	c #303030",
"c	c #262626",
"d	c #333333",
"e	c #848486",
"f	c #F3F3F3",
"g	c #F1F1F1",
"h	c #F9F9F9",
"i	c #5F5F61",
"j	c #FCFCFC",
"k	c #CBCBCC",
"l	c #AEAEB1",
"m	c #E5E5E6",
"n	c #EFEFEF",
"o	c #808082",
"p	c #99999C",
"q	c #D1D1D2",
"r	c #9A9A9C",
"s	c #272727",
"t	c #929294",
"u	c #B8B8BA",
"v	c #474747",
"w	c #4E4E4F",
"x	c #2F2F2F",
"y	c #4B4B4C",
"z	c #5A5A5A",
"A	c #323232",
"B	c #343434",
"C	c #363637",
"D	c #B7B7B9",
"E	c #8A8A8C",
"F	c #1C1C1C",
"G	c #1A1A1A",
"H	c #222222",
"I	c #404040",
"J	c #585858",
"K	c #545454",
"L	c #252525",
"M	c #505050",
"              ",
"     .+@  #   ",
"  $%&*=-;>,   ",
"  $'))=)))!   ",
" ~{])^/(_)']]:",
"<--[)}||1=)234",
"556+)7889))0ab",
"cdef))=))gh2% ",
" i,jklm)nopqr ",
" stuvw%):xxyz ",
"  ABcCD%E FxG ",
"   H  IJK     ",
"      LMH     "
};

static char **cog_array[GTK_DANCE_STEPS] = {
        cog1_xpm,
        cog2_xpm,
        cog3_xpm,
        cog4_xpm,
        cog5_xpm,
        cog6_xpm,
        cog7_xpm,
        cog8_xpm,
        cog9_xpm,
};

/*
 *  Create a picwidget.
 */
static GtkWidget *
build_picwidget(gchar **name, gboolean ref)
{
        GdkBitmap *mask;
        GdkPixmap *pixmap;
        GtkWidget *picwidget;

        pixmap = gdk_pixmap_colormap_create_from_xpm_d(NULL,
                gtk_widget_get_default_colormap(), 
                &mask,  NULL, name);

        picwidget = gtk_pixmap_new(pixmap, mask);
	gtk_widget_show(picwidget);

	if (ref)
		gtk_widget_ref(picwidget);
		
	return picwidget;
}

/*
 *  Based upon the test being run (if any), build up the test data displays.
 */
static GtkWidget *
build_test_data(GtkWidget *box)
{
	register gint i, t, b;
	char buf1[MESSAGE_SIZE];
	GtkWidget *frame = NULL;
	GtkWidget *table = NULL;
	GtkWidget *menu = NULL;
	GtkWidget *pass = NULL;
	GtkTooltips *tooltips;
	GdkBitmap *mask;
	GdkPixmap *pixmap;
	GtkWidget *picwidget;
	PROC_TABLE *tbl;

	if (!Shm->procno)
		return frame;

	Shm->wmd->test_control_one = menu = gtk_menu_new(); 
   	build_menu_item("Background", 0, individual_test_menu, menu, NULL, 
		TEST_BACKGROUND);
   	build_menu_item("Foreground", 0, individual_test_menu, menu, NULL, 
		TEST_FOREGROUND);
   	build_menu_item("Hold", 0, individual_test_menu, menu, NULL, TEST_HOLD);
   	build_menu_item("Kill", 0, individual_test_menu, menu, NULL, TEST_KILL);
   	build_menu_item(NULL, 0, NULL, menu, NULL, 0);
   	build_menu_item("Messages", 0, individual_test_menu, menu, NULL, 
		TEST_MESSAGES);
   	build_menu_item("Inquiry", 0, individual_test_menu, menu, NULL, 
		TEST_INQUIRY);
	gtk_widget_show_all(GTK_WIDGET(menu));

	if (Shm->procno > MAXIMUM_UNSCROLLED_TESTS) {
		frame = build_scrolled_frame("test data", 
			box, TRUE, TRUE, GTK_SHADOW_OUT,FALSE);
		Shm->wmd->flags |= SCROLL_TEST_DATA;
	} else
		frame = build_frame("test data", 
			box, TRUE, TRUE, GTK_SHADOW_OUT,FALSE);

	Shm->wmd->test_frame = frame;

        table = gtk_table_new(Shm->procno+1, 9, FALSE);
        gtk_table_set_col_spacings(GTK_TABLE(table), 5);
        gtk_container_add(GTK_CONTAINER(frame), table);

	build_test_data_entry(table, FALSE, TRUE, 0, 1, 0, 1, "ID", NULL);
	build_test_data_entry(table, FALSE, TRUE, 1, 2, 0, 1, "BSIZE", NULL);
	build_test_data_entry(table, FALSE, TRUE, 2, 3, 0, 1, "MODE", NULL);
	build_test_data_entry(table, FALSE, TRUE, 3, 4, 0, 1, "POINTER", NULL);
	build_test_data_entry(table, FALSE, TRUE, 4, 5, 0, 1, "OPERATION",NULL);
	build_test_data_entry(table, FALSE, TRUE, 5, 6, 0, 1, "FILENAME",NULL);
	build_test_data_entry(table, FALSE, TRUE, 6, 7, 0, 1, "PASS", NULL);
	build_test_data_entry(table, FALSE, TRUE, 7, 8, 0, 1, "STAT", NULL);
	build_test_data_entry(table, FALSE, TRUE, 8, 9, 0, 1, "CTL", NULL);

	tooltips = gtk_tooltips_new();
	gtk_tooltips_enable(tooltips);
	
	pixmap = gdk_pixmap_colormap_create_from_xpm_d(NULL,
		gtk_widget_get_default_colormap(),
		&mask,
		NULL,
		(gchar **)button_horiz_xpm);

	for (i = 0; i < Shm->procno; i++) {
		t = i+1, b = i+2;

		/* ID */
		sprintf(buf1, "%d", i+1);
		build_test_data_entry(table, FALSE, TRUE, 
			0, 1, t, b, buf1, NULL);

		/* PASS */
                pass = Shm->wmd->test_data[i].pass = 
		    	build_test_data_entry(table, 
			TRUE, TRUE, 6, 7, t, b, NULL, 
			&Shm->wmd->test_data[i].pass_frame);

		/* STAT */
                Shm->wmd->test_data[i].stat = build_test_data_entry(table, 
			TRUE, TRUE, 7, 8, t, b, NULL, NULL);

		/* multiple fields -- invisible unless test-specific */

                Shm->wmd->test_data[i].field2 = build_test_data_entry(table, 
			TRUE, FALSE, 1, 3, t, b, NULL,
			&Shm->wmd->test_data[i].field2_frame);
                Shm->wmd->test_data[i].field3 = build_test_data_entry(table, 
			TRUE, FALSE, 1, 4, t, b, NULL,
			&Shm->wmd->test_data[i].field3_frame);
                Shm->wmd->test_data[i].field4 = build_test_data_entry(table, 
			TRUE, FALSE, 1, 5, t, b, NULL,
			&Shm->wmd->test_data[i].field4_frame);
                Shm->wmd->test_data[i].field5 = build_test_data_entry(table, 
			TRUE, FALSE, 1, 6, t, b, NULL,
			&Shm->wmd->test_data[i].field5_frame);

		Shm->wmd->test_data[i].control_frame = gtk_frame_new(NULL);
		gtk_frame_set_shadow_type(GTK_FRAME
			(Shm->wmd->test_data[i].control_frame), 
			GTK_SHADOW_NONE);
		Shm->wmd->test_data[i].control = 
			gtk_menu_item_new();
		picwidget = gtk_pixmap_new(pixmap, mask);
		gtk_container_add(GTK_CONTAINER(Shm->wmd->test_data[i].control),
			picwidget);
		gtk_container_add(GTK_CONTAINER
			(Shm->wmd->test_data[i].control_frame), 
			Shm->wmd->test_data[i].control);
        	gtk_table_attach_defaults(GTK_TABLE(table), 
			Shm->wmd->test_data[i].control_frame,
                	8, 9, t, b);
		gtk_widget_show_all(Shm->wmd->test_data[i].control_frame);
		gtk_signal_connect(GTK_OBJECT
			(Shm->wmd->test_data[i].control_frame), 
			"event", GTK_SIGNAL_FUNC(test_control_mouse_pressed), 
			(gpointer)((ulong)i));

		sprintf(buf1, "Click to view test %d control options", i+1);
		gtk_tooltips_set_tip(tooltips, 
			Shm->wmd->test_data[i].control,
			buf1, NULL);

                tbl = &Shm->ptbl[i];

    		switch (tbl->i_type)
    		{
        	case DISK_TEST:
			Shm->wmd->test_data[i].bsize = 
				build_test_data_entry(table, TRUE, TRUE, 
					1, 2, t, b, 
					adjust_size(Shm->ptbl[i].i_size, 
					5, buf1, 0),
					&Shm->wmd->test_data[i].bsize_frame);

			Shm->wmd->test_data[i].mode = 
				build_test_data_entry(table, TRUE, TRUE,
                                	2, 3, t, b, NULL,
					&Shm->wmd->test_data[i].mode_frame);

			Shm->wmd->test_data[i].fpointer =
                                build_test_data_entry(table, TRUE, TRUE,
                                	3, 4, t, b, NULL,
				        &Shm->wmd->test_data[i].fpointer_frame);

			Shm->wmd->test_data[i].operation = 
                                build_test_data_entry(table, TRUE, TRUE,
                                	4, 5, t, b, NULL,
				       &Shm->wmd->test_data[i].operation_frame);

			Shm->wmd->test_data[i].filename = 
				build_test_data_entry(table, TRUE, TRUE, 
					5, 6, t, b, tbl->i_file,
					&Shm->wmd->test_data[i].file_frame);
            		break;

		case BIN_TEST:
			gtk_widget_show(Shm->wmd->test_data[i].field2_frame);
                        gtk_mgr_set_font(Shm->wmd->test_data[i].field2, 
				Shm->wmd->fixed); 

                	Shm->wmd->test_data[i].fieldspec = 
				build_test_data_entry(table,
                        	TRUE, TRUE, 3, 6, t, b, NULL,
                        	&Shm->wmd->test_data[i].fieldspec_frame);

                        gtk_mgr_set_font(Shm->wmd->test_data[i].fieldspec, 
				Shm->wmd->fixed); 
                        gtk_misc_set_alignment(GTK_MISC
                                (Shm->wmd->test_data[i].fieldspec), 0.0f, 0.5f);
	    		break;

        	case WHET_TEST:
                        Shm->wmd->test_data[i].operation =
                                build_test_data_entry(table, TRUE, TRUE,
                                        4, 5, t, b, NULL,
                                       &Shm->wmd->test_data[i].operation_frame);

			Shm->wmd->test_data[i].filename = 
                        	build_test_data_entry(table, TRUE, TRUE, 
					5, 6, t, b,
                                	"whetstone benchmark", NULL);

			gtk_widget_show(Shm->wmd->test_data[i].field3_frame);

            		break;

        	case DHRY_TEST:
                        Shm->wmd->test_data[i].operation =
                                build_test_data_entry(table, TRUE, TRUE,
                                        4, 5, t, b, NULL,
                                       &Shm->wmd->test_data[i].operation_frame);

			Shm->wmd->test_data[i].filename = 
                        	build_test_data_entry(table, TRUE, TRUE, 
					5, 6, t, b,
                                	"dhrystone benchmark", NULL);
            		break;

        	case VMEM_TEST:
                        Shm->wmd->test_data[i].operation =
                                build_test_data_entry(table, TRUE, TRUE,
                                        4, 5, t, b, NULL,
                                       &Shm->wmd->test_data[i].operation_frame);

			Shm->wmd->test_data[i].filename = 
                        	build_test_data_entry(table, TRUE, TRUE, 
					5, 6, t, b, 
					"virtual memory test", NULL);

			gtk_widget_show(Shm->wmd->test_data[i].field3_frame);
			gtk_container_remove(GTK_CONTAINER
				(Shm->wmd->test_data[i].pass_frame), pass);
			gtk_mgr_vmem_dance(i, -1);
            		break;

        	case DEBUG_TEST:
                        Shm->wmd->test_data[i].bsize =
                                build_test_data_entry(table, TRUE, TRUE,
                                        1, 2, t, b,
                                        adjust_size(Shm->ptbl[i].i_size,
                                        5, buf1, 0),
                                        &Shm->wmd->test_data[i].bsize_frame);

                        Shm->wmd->test_data[i].mode =
                                build_test_data_entry(table, TRUE, TRUE,
                                        2, 3, t, b, NULL,
                                        &Shm->wmd->test_data[i].mode_frame);

                        Shm->wmd->test_data[i].fpointer =
                                build_test_data_entry(table, TRUE, TRUE,
                                        3, 4, t, b, NULL,
                                        &Shm->wmd->test_data[i].fpointer_frame);

                        Shm->wmd->test_data[i].operation =
                                build_test_data_entry(table, TRUE, TRUE,
                                        4, 5, t, b, NULL,
                                       &Shm->wmd->test_data[i].operation_frame);

                        Shm->wmd->test_data[i].filename =
                                build_test_data_entry(table, TRUE, TRUE,
                                        5, 6, t, b, tbl->i_file,
                                        &Shm->wmd->test_data[i].file_frame);
            		break;

        	case RATE_TEST:
                        Shm->wmd->test_data[i].operation =
                                build_test_data_entry(table, TRUE, TRUE,
                                        4, 5, t, b, NULL,
                                       &Shm->wmd->test_data[i].operation_frame);

			Shm->wmd->test_data[i].bsize = 
                        	build_test_data_entry(table, TRUE, TRUE, 
					1, 2, t, b,
                                	adjust_size(Shm->ptbl[i].i_size, 
					5, buf1, 0),
					&Shm->wmd->test_data[i].bsize_frame);

                        Shm->wmd->test_data[i].mode =
                                build_test_data_entry(table, TRUE, TRUE,
                                        2, 3, t, b, "Rate",
                                        &Shm->wmd->test_data[i].mode_frame);

                        Shm->wmd->test_data[i].fpointer =
                                build_test_data_entry(table, TRUE, TRUE,
                                        3, 4, t, b, NULL,
                                        &Shm->wmd->test_data[i].fpointer_frame);

			Shm->wmd->test_data[i].filename = 
                        	build_test_data_entry(table, TRUE, TRUE, 
					5, 6, t, b, tbl->i_file, 
					&Shm->wmd->test_data[i].file_frame);

            		break;

        	case USER_TEST:
                        gtk_widget_show(Shm->wmd->test_data[i].field2_frame);
                        gtk_mgr_set_font(Shm->wmd->test_data[i].field2, 
				Shm->wmd->fixed); 
        
                        Shm->wmd->test_data[i].fieldspec =
                                build_test_data_entry(table,
                                TRUE, TRUE, 3, 6, t, b, NULL,
                                &Shm->wmd->test_data[i].fieldspec_frame);

			gtk_mgr_set_font(Shm->wmd->test_data[i].fieldspec, 
				Shm->wmd->fixed); 
			gtk_misc_set_alignment(GTK_MISC
				(Shm->wmd->test_data[i].fieldspec), 0.0f, 0.5f);
            		break;
		}
	}

        Shm->wmd->bitbucket = gtk_label_new("");

	gtk_widget_show(frame);
	gtk_widget_show(table);

	return frame;
}

/*
 *  Handle ambiguous test-specific post_usex_message() requests by
 *  returning the proper widget for a given command.
 */

void *
gtk_mgr_test_widget(int id, unsigned char cmd, char *buf)
{
	PROC_TABLE *tbl;
	int argc;
        char *argv[MAX_ARGV];
	char buf1[MESSAGE_SIZE];
	char *p1;
	GtkWidget *widget = NULL;
	struct test_data *td;

        tbl = &Shm->ptbl[id];
	td = &Shm->wmd->test_data[id];

    	switch (tbl->i_type)
    	{
        case DISK_TEST:
		switch (cmd)
		{
		case MANDATORY_FMODE:
			strcpy(buf1, buf);
        		argc = parse(buf1, argv);
			switch (argc)
			{
			case 1:
				gtk_label_set_text(GTK_LABEL
					(td->fpointer), " ");
				gtk_label_set_text(GTK_LABEL
					(td->operation), " ");
				if (tbl->i_stat & IO_BKGD) {
					gtk_widget_hide(td->fpointer_frame);
                	        	gtk_widget_hide(td->operation_frame);
				}
				break;
			case 5:
				p1 = strstr(buf, "read");
				gtk_label_set_text(GTK_LABEL
					(td->fpointer), "ENOMEM");
				gtk_widget_show(td->fpointer_frame);
				gtk_label_set_text(GTK_LABEL
					(td->operation), p1);
                	        gtk_widget_show(td->operation_frame);
				break;
			}
			widget = Shm->wmd->bitbucket;
			break;
		case FMODE:
	                argc = parse(buf, argv);
	                switch (argc)
	                {
	                case 1:
				widget = Shm->wmd->test_data[id].mode;
				break;
	
	                case 3:
				widget = Shm->wmd->test_data[id].mode;
	                        gtk_label_set_text(GTK_LABEL
	                                (Shm->wmd->test_data[id].fpointer),
	                                adjust_size(strtoul(argv[1], 0, 10),
	                                9, buf1, 1));
	                        gtk_label_set_text(GTK_LABEL
	                                (Shm->wmd->test_data[id].operation),
	                                strip_ending_chars(argv[2], '.'));
	                        break;
	                }
			break;
		case FCLEAR:
			widget = td->operation;
			break;
		case FERROR:
			gtk_widget_hide(td->bsize_frame);
			gtk_widget_hide(td->mode_frame);
                	gtk_widget_hide(td->fpointer_frame);
                	gtk_widget_hide(td->operation_frame);
			gtk_widget_show(td->field4_frame);
			widget = td->field4;
			break;
		case COMPARE_ERR:
                        gtk_widget_hide(td->bsize_frame);
                        gtk_widget_hide(td->mode_frame);
                        gtk_widget_hide(td->fpointer_frame);
                        gtk_widget_hide(td->operation_frame);
                        gtk_widget_show(td->field4_frame);
			shift_string_left(strip_ending_spaces(buf), 5, NULL);
                        widget = td->field4;
			break;
		}
            	break;

	case BIN_TEST:
                switch (cmd)
                {
                case FSIZE:
			widget = td->field2;
			break;
		case MANDATORY_FSHELL:
			gtk_widget_show(td->fieldspec_frame);
			widget = td->fieldspec;
			break;
		case FSHELL:
			widget = td->fieldspec;
			break;
		case FERROR:
			gtk_label_set_text(GTK_LABEL
                        	(Shm->wmd->test_data[id].field2), tbl->curcmd);
			gtk_widget_show(td->fieldspec_frame);
			widget = td->fieldspec;
                	gtk_window_set_policy(GTK_WINDOW(Shm->wmd->toplevel),
                        	FALSE, TRUE, TRUE);
                	Shm->wmd->flags |= GTK_MGR_RESIZE;
			break; 
                }
	    	break;

        case WHET_TEST:
                switch (cmd)
                {
                case FSIZE:
			gtk_widget_show(td->field3_frame);
                        widget = td->field3;
                        break;
		case FCLEAR:
			widget = td->operation;
			break;
		case FERROR:
			gtk_widget_hide(td->operation_frame);
                        gtk_widget_hide(td->field3_frame);
                        gtk_widget_show(td->field4_frame);
			widget = td->field4;
			break;
                }
            	break;

        case DHRY_TEST:
                switch (cmd)
                {
		case FCLEAR:
			gtk_widget_hide(td->operation_frame);
			gtk_widget_show(td->field4_frame);
			widget = td->field4;
			break;
                case FSIZE:
			if (buf)
				strip_ending_spaces(buf);
			widget = td->field4;
			break;
		case FERROR:
                        widget = td->field4;
			break;
                }
            	break;

        case VMEM_TEST:
                switch (cmd)
                {
                case FSIZE:
			widget = td->field3;
                        break;
		case FCLEAR:
			widget = td->operation;
			break;
		case FERROR:
                        gtk_widget_hide(td->operation_frame);
                        gtk_widget_hide(td->field3_frame);
                        gtk_widget_show(td->field4_frame);
                        widget = td->field4;
			break;  
                }
            	break;

        case DEBUG_TEST:
                switch (cmd)
                {
                case FSIZE:
			if (strlen(buf) > strlen("BSIZE")) {
				widget = td->field5;
                                gtk_widget_hide(td->bsize_frame);
                                gtk_widget_hide(td->mode_frame);
                                gtk_widget_hide(td->fpointer_frame);
                                gtk_widget_hide(td->operation_frame);
                                gtk_widget_hide(td->file_frame);
			        gtk_widget_show(td->field5_frame);
			} else {
				widget = td->bsize;
				gtk_widget_hide(td->field5_frame);
                                gtk_widget_show(td->bsize_frame);
                                gtk_widget_show(td->mode_frame);
				gtk_label_set_text(GTK_LABEL(td->mode), " ");
                                gtk_widget_show(td->fpointer_frame);
				gtk_label_set_text(GTK_LABEL(td->fpointer),
					" ");
                                gtk_widget_show(td->operation_frame);
				gtk_label_set_text(GTK_LABEL(td->operation),
					" ");
                                gtk_widget_show(td->file_frame);
				gtk_label_set_text(GTK_LABEL(td->filename), 
					" ");
			}
                        break;
		case FCLEAR:
			widget = td->operation;
			break;
		case FMODE:
			widget = Shm->wmd->test_data[id].mode;
			break;
		case FERROR:
                        widget = td->field5;
                        gtk_widget_hide(td->bsize_frame);
                        gtk_widget_hide(td->mode_frame);
                        gtk_widget_hide(td->fpointer_frame);
                        gtk_widget_hide(td->operation_frame);
                        gtk_widget_hide(td->file_frame);
                        gtk_widget_show(td->field5_frame);
			break; 
                }
            	break;

        case RATE_TEST:
                switch (cmd)
		{
		case MANDATORY_FMODE:
			strip_ending_spaces(shift_string_left(buf, 5, NULL));
			widget = td->fpointer;
			break;
                case FSIZE:
                        break;
		case FCLEAR:
			widget = td->operation;
			break;
		case FERROR:
                        gtk_widget_hide(td->bsize_frame);
                        gtk_widget_hide(td->mode_frame);
                        gtk_widget_hide(td->fpointer_frame);
                        gtk_widget_hide(td->operation_frame);
                        gtk_widget_show(td->field4_frame);
                        widget = td->field4;
			break;
                }
            	break;

        case USER_TEST:
                switch (cmd)
                {
                case FSIZE:
			widget = td->field2;
			break;
		case MANDATORY_FSHELL:
		case FSHELL:
                        widget = td->fieldspec;
                        break;
		case FERROR:
                        gtk_widget_show(td->fieldspec_frame);
                        widget = td->fieldspec;
                        gtk_window_set_policy(GTK_WINDOW(Shm->wmd->toplevel),
                                FALSE, TRUE, TRUE);
                        Shm->wmd->flags |= GTK_MGR_RESIZE;
			break; 
                }
            	break;
	}
	
	if (!widget) {
		g_print("gtk_mgr_test_widget: id: %d cmd: %c buf: \"%s\"\n", 
			id, cmd, buf);
		drop_core("post_usex_message request failure");
	}
	return widget;
}

/*
 *  Handle test-specific change to background mode.
 */

void
gtk_mgr_test_background(int id)
{
        PROC_TABLE *tbl;
        struct test_data *td;

        tbl = &Shm->ptbl[id];
        td = &Shm->wmd->test_data[id];

    	switch (tbl->i_type)
    	{
       	case DISK_TEST:
		gtk_widget_hide(td->operation_frame);
                gtk_frame_set_shadow_type(GTK_FRAME(td->operation_frame), 
			GTK_SHADOW_ETCHED_OUT);
		gtk_label_set_text(GTK_LABEL (td->operation), " ");
		gtk_widget_show(td->operation_frame);

		gtk_widget_hide(td->fpointer_frame);
                gtk_frame_set_shadow_type(GTK_FRAME(td->fpointer_frame),
                        GTK_SHADOW_ETCHED_OUT);
                gtk_label_set_text(GTK_LABEL (td->fpointer), " ");
		gtk_widget_show(td->fpointer_frame);
        	break;

	case BIN_TEST:
		gtk_widget_hide(td->fieldspec_frame);
		gtk_frame_set_shadow_type(GTK_FRAME(td->fieldspec_frame), 
			GTK_SHADOW_ETCHED_OUT);
		gtk_label_set_text(GTK_LABEL(td->fieldspec), " ");
		gtk_widget_show(td->fieldspec_frame);
        	gtk_window_set_policy(GTK_WINDOW(Shm->wmd->toplevel),
                	FALSE, TRUE, TRUE);
        	Shm->wmd->flags |= GTK_MGR_RESIZE;
	     	break;

        case WHET_TEST:
            	break;

       	case DHRY_TEST:
            	break;

       	case VMEM_TEST:
		gtk_widget_hide(td->pass_frame);
		gtk_mgr_vmem_dance(id, -2);
                gtk_frame_set_shadow_type(GTK_FRAME(td->pass_frame),
                        GTK_SHADOW_ETCHED_OUT);
		gtk_widget_show(td->pass_frame);
            	break;

       	case DEBUG_TEST:
            	break;

       	case RATE_TEST:
            	break;

       	case USER_TEST:
		gtk_widget_hide(td->fieldspec_frame);
                gtk_frame_set_shadow_type(GTK_FRAME(td->fieldspec_frame),
                        GTK_SHADOW_ETCHED_OUT);
                gtk_label_set_text(GTK_LABEL(td->fieldspec), " ");
                gtk_widget_show(td->fieldspec_frame);
        	gtk_window_set_policy(GTK_WINDOW(Shm->wmd->toplevel),
                	FALSE, TRUE, TRUE);
        	Shm->wmd->flags |= GTK_MGR_RESIZE;
            	break;
	}
}

/*
 *  Handle test-specific change to foreground mode.
 */

void
gtk_mgr_test_foreground(int id)
{
        PROC_TABLE *tbl;
        struct test_data *td;

        tbl = &Shm->ptbl[id];
        td = &Shm->wmd->test_data[id];

        switch (tbl->i_type)
        {
        case DISK_TEST:
                gtk_widget_hide(td->operation_frame);
                gtk_frame_set_shadow_type(GTK_FRAME(td->operation_frame),
                        GTK_SHADOW_IN);
                gtk_widget_show(td->operation_frame);

                gtk_widget_hide(td->fpointer_frame);
                gtk_frame_set_shadow_type(GTK_FRAME(td->fpointer_frame),
                        GTK_SHADOW_IN);
                gtk_widget_show(td->fpointer_frame);
                break;

        case BIN_TEST:
		gtk_widget_hide(td->fieldspec_frame);
		gtk_frame_set_shadow_type(GTK_FRAME(td->fieldspec_frame),
        		GTK_SHADOW_IN);
		gtk_label_set_text(GTK_LABEL(td->fieldspec), " ");
                gtk_widget_show(td->fieldspec_frame);
                break;

        case WHET_TEST:
                break;

        case DHRY_TEST:
                break;

        case VMEM_TEST:
		gtk_widget_hide(td->pass_frame);
                gtk_frame_set_shadow_type(GTK_FRAME(td->pass_frame),
                        GTK_SHADOW_IN);
		gtk_widget_show(td->pass_frame);
                break;

        case DEBUG_TEST:
                break;

        case RATE_TEST:
                break;

        case USER_TEST:
                gtk_widget_hide(td->fieldspec_frame);
                gtk_frame_set_shadow_type(GTK_FRAME(td->fieldspec_frame),
                        GTK_SHADOW_IN);
                gtk_label_set_text(GTK_LABEL(td->fieldspec), " ");
                gtk_widget_show(td->fieldspec_frame);
                break;
        }
}

/*
 *  Build the user-system-idle progress bars.
 */
static void
build_user_sys_idle_bars(GtkWidget *table, gint left, gint right, 
	gint top, gint bottom)
{
	GtkWidget *vbox = NULL;
	GtkWidget *hbox = NULL;
	GtkWidget *user = NULL;
	GtkWidget *sys = NULL;
	GtkWidget *idle = NULL;
	GtkWidget *label = NULL;
	
        vbox = gtk_vbox_new(FALSE, 0);

        hbox = gtk_hbox_new(FALSE, 0);
  	label = gtk_label_new(" User     "); 
	gtk_label_set_justify(GTK_LABEL(label), GTK_JUSTIFY_LEFT);
	gtk_label_set_text(GTK_LABEL(label), "  User     ");
	user = gtk_progress_bar_new();
	gtk_progress_configure(GTK_PROGRESS(user), 0.0, 0.0, 100.0);
	gtk_progress_set_show_text (GTK_PROGRESS(user), TRUE);
	gtk_progress_bar_update(GTK_PROGRESS_BAR(user), 0);
        gtk_box_pack_start(GTK_BOX(hbox), user, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(hbox), label, FALSE, FALSE, 0); 
	gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 0);
	Shm->wmd->user_pct = user;
	gtk_widget_show(label);
	gtk_widget_show(user);
	gtk_widget_show(hbox);

        hbox = gtk_hbox_new(FALSE, 0);
        label = gtk_label_new(" System     ");
	gtk_label_set_justify(GTK_LABEL(label), GTK_JUSTIFY_LEFT);
	gtk_label_set_text(GTK_LABEL(label), "  System     ");
        sys = gtk_progress_bar_new();
	gtk_progress_configure(GTK_PROGRESS(sys), 0.0, 0.0, 100.0);
	gtk_progress_set_show_text (GTK_PROGRESS(sys), TRUE);
	gtk_progress_bar_update(GTK_PROGRESS_BAR(sys), 0);
        gtk_box_pack_start(GTK_BOX(hbox), sys, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(hbox), label, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 0);
	Shm->wmd->system_pct = sys;
	gtk_widget_show(label);
	gtk_widget_show(sys);
	gtk_widget_show(hbox);

        hbox = gtk_hbox_new(FALSE, 0);
        label = gtk_label_new(" Idle");
	gtk_label_set_justify(GTK_LABEL(label), GTK_JUSTIFY_LEFT);
	gtk_label_set_text(GTK_LABEL(label), "  Idle");
        idle = gtk_progress_bar_new();
	gtk_progress_configure(GTK_PROGRESS(idle), 0.0, 0.0, 100.0);
	gtk_progress_set_show_text (GTK_PROGRESS(idle), TRUE);
	gtk_progress_bar_update(GTK_PROGRESS_BAR(idle), 0);
        gtk_box_pack_start(GTK_BOX(hbox), idle, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(hbox), label, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 0);
	Shm->wmd->idle_pct = idle;
        gtk_widget_show(label);
        gtk_widget_show(idle);
        gtk_widget_show(hbox);

        gtk_table_attach_defaults(GTK_TABLE(table), vbox, 
		left, right, top, bottom);

	gtk_widget_show(vbox);
}

/*
 *  Build an individual entry in the system table.
 */
static GtkWidget *
build_system_data_entry(GtkWidget *table, gchar *title, gint left, gint right, 
	gint top, gint bottom)
{
	GtkWidget *entry = NULL;
	GtkWidget *vbox = NULL;
	GtkWidget *label = NULL;
	GtkWidget *frame = NULL;

        vbox = gtk_vbox_new(TRUE, 0);
        label = gtk_label_new(title);
        entry = gtk_label_new("");
        frame = gtk_frame_new(NULL);
        gtk_frame_set_shadow_type(GTK_FRAME(frame), GTK_SHADOW_IN);
        gtk_container_add(GTK_CONTAINER(frame), entry);
        gtk_box_pack_start(GTK_BOX(vbox), label, FALSE, FALSE, 0);
        gtk_box_pack_end(GTK_BOX(vbox), frame, FALSE, FALSE, 0);
        gtk_table_attach_defaults(GTK_TABLE(table), vbox, 
		left, right, top, bottom);

	gtk_widget_show(label);
	gtk_widget_show(entry);
	gtk_widget_show(frame);
	gtk_widget_show(vbox);

	return entry;
}

/*
 *  Build the system statistics display box.
 */
static GtkWidget *
build_system_data(GtkWidget *box)
{
	GtkWidget *frame = NULL;
	GtkWidget *table = NULL;

        frame = build_frame("system data", box, FALSE, FALSE, 
		GTK_SHADOW_OUT, FALSE);  

	Shm->wmd->system_frame = frame;

	table = gtk_table_new(4, 7, FALSE);
	gtk_table_set_col_spacings(GTK_TABLE(table), 5);
    	gtk_container_add(GTK_CONTAINER(frame), table); 

	build_user_sys_idle_bars(table, 0, 4, 0, 2);

	Shm->wmd->system_table = table;

	Shm->wmd->test_time = build_system_data_entry(table, 
		"Test Time", 6, 7, 0, 1);

	Shm->wmd->timebox = build_system_data_entry(table, 
		"Time", 0, 1, 2, 3);

	Shm->wmd->datebox = build_system_data_entry(table, 
		"Date", 0, 1, 3, 4); 

	Shm->wmd->page_in = build_system_data_entry(table, 
		"Page In", 1, 2, 2, 3);

	Shm->wmd->page_out = build_system_data_entry(table, 
		"Page Out", 2, 3, 2, 3);

	Shm->wmd->swap_in = build_system_data_entry(table, 
		"Swap In", 1, 2, 3, 4);

	Shm->wmd->swap_out = build_system_data_entry(table, 
		"Swap Out", 2, 3, 3, 4);

	Shm->wmd->free_mem = build_system_data_entry(table, 
		"Free Mem", 3, 4, 2, 3);

	Shm->wmd->free_swap = build_system_data_entry(table, 
		"Free Swap", 4, 5, 2, 3);

	Shm->wmd->buffers = build_system_data_entry(table, 
		"Buffers", 3, 4, 3, 4);

	Shm->wmd->cached = build_system_data_entry(table, 
		"Cached", 4, 5, 3, 4);

	Shm->wmd->csw = build_system_data_entry(table, 
		"Cswitch", 5, 6, 2, 3);

	Shm->wmd->interrupts = build_system_data_entry(table, 
                "Interrupts", 6, 7, 2, 3);

	Shm->wmd->forks = build_system_data_entry(table, 
                "Forks", 5, 6, 3, 4);

	Shm->wmd->tasks_run = build_system_data_entry(table, 
                "Tasks/Run", 6, 7, 3, 4);

	Shm->wmd->loadavg = build_system_data_entry(table, 
                "Load Avg", 4, 5, 0, 1);

	gtk_widget_show(table);

	return frame; 
}

/*
 *  Confirm that a status bar message has been displayed.
 */
static gboolean
status_bar_expose(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	gtk_label_get(GTK_LABEL(Shm->wmd->status_bar), 
		&Shm->wmd->status_bar_exposed);

	if (Shm->mode & DEBUG_MODE)
		console("status bar expose: \"%s\"\n", 
			Shm->wmd->status_bar_exposed); 

	return(FALSE);
}

/*
 *  Create a status bar.
 */
static GtkWidget *
build_status_bar(GtkWidget *box)
{
	GtkWidget *frame = NULL;
	GtkWidget *label = NULL;

        frame = build_frame("status bar", box, FALSE, FALSE, 
		GTK_SHADOW_IN, FALSE);

	Shm->wmd->status_frame = frame;

	label = gtk_label_new(" ");
	gtk_container_add(GTK_CONTAINER(frame), label);

	Shm->wmd->status_bar = track_widget(label);

	gtk_widget_show(label);

        gtk_signal_connect(GTK_OBJECT(label), "expose_event",
                GTK_SIGNAL_FUNC(status_bar_expose), NULL);

	return frame;
}

/* XPM */
static char * stop_xpm[] = {
"32 32 8 1",
" 	c None",
".	c #808080",
"+	c #000000",
"@	c #C0C0C0",
"#	c #FFFFFF",
"$	c #FF0000",
"%	c #800000",
"&	c #800080",
".++++++++++++++++++++++++++++++.",
"+#############################.+",
"+#.......@@@@@@@@@@@@@........@+",
"+#......@@%%%%%%%%%%%%@.......@+",
"+#.....@@%%%%%%%%%%%%%%@......@+",
"+#....@@%%%$$$$$$$$$$$$%@.....@+",
"+#...@@%%%$$$$$$$$$$$$$$%@....@+",
"+#..@@%%%$$$$$$$$$$$$$$$$%@...@+",
"+#.@@%%%$$$$$$$$$$$$$$$$$$%@..@+",
"+#@@%%%$$$$$$$$$$$$$$$$$$$$%@.@+",
"+#@%%%$##&$#####&$##&$$###&$%.@+",
"+#@%%$#&&#&&&#&&&#&&#&$#&&#&$#@+",
"+#@%%$#&$#&$$#&$$#&$#&$#&$#&$#@+",
"+#@%%$#&$&&$$#&$$#&$#&$#&$#&$#@+",
"+#@%%$#&$$$$$#&$$#&$#&$#&$#&$#@+",
"+#@%%$&##&$$$#&$$#&$#&$###&&$#@+",
"+#@%%$$&&#&$$#&$$#&$#&$#&&&$$#@+",
"+#@%%$$$$#&$$#&$$#&$#&$#&$$$$#@+",
"+#@%%$#&$#&$$#&$$#&$#&$#&$$$$#@+",
"+#@%%$#&$#&$$#&$$#&$#&$#&$$$$#@+",
"+#@%%$#&$#&$$#&$$#&$#&$#&$$$$#@+",
"+#@%%$&##&&$$#&$$&##&&$#&$$$$#@+",
"+#.#%$$&&&$$$&&$$$&&&$$&&$$$##@+",
"+#..#$$$$$$$$$$$$$$$$$$$$$$##.@+",
"+#...#$$$$$$$$$$$$$$$$$$$$##..@+",
"+#....#$$$$$$$$$$$$$$$$$$##...@+",
"+#.....#$$$$$$$$$$$$$$$$##....@+",
"+#......#$$$$$$$$$$$$$$##.....@+",
"+#.......#$$$$$$$$$$$$##......@+",
"+#........#############.......@+",
"+.@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+",
".++++++++++++++++++++++++++++++."
};


static char * help_xpm[] = {
"32 32 254 2",
"  	c None",
". 	c #FFFFFF",
"+ 	c #FFFFCC",
"@ 	c #FFFF99",
"# 	c #FFFF66",
"$ 	c #FFFF33",
"% 	c #FFFF00",
"& 	c #FFCCFF",
"* 	c #FFCCCC",
"= 	c #FFCC99",
"- 	c #FFCC66",
"; 	c #FFCC33",
"> 	c #FFCC00",
", 	c #FF99FF",
"' 	c #FF99CC",
") 	c #FF9999",
"! 	c #FF9966",
"~ 	c #FF9933",
"{ 	c #FF9900",
"] 	c #FF66FF",
"^ 	c #FF66CC",
"/ 	c #FF6699",
"( 	c #FF6666",
"_ 	c #FF6633",
": 	c #FF6600",
"< 	c #FF33FF",
"[ 	c #FF33CC",
"} 	c #FF3399",
"| 	c #FF3366",
"1 	c #FF3333",
"2 	c #FF3300",
"3 	c #FF00FF",
"4 	c #FF00CC",
"5 	c #FF0099",
"6 	c #FF0066",
"7 	c #FF0033",
"8 	c #FF0000",
"9 	c #CCFFFF",
"0 	c #CCFFCC",
"a 	c #CCFF99",
"b 	c #CCFF66",
"c 	c #CCFF33",
"d 	c #CCFF00",
"e 	c #CCCCFF",
"f 	c #CCCCCC",
"g 	c #CCCC99",
"h 	c #CCCC66",
"i 	c #CCCC33",
"j 	c #CCCC00",
"k 	c #CC99FF",
"l 	c #CC99CC",
"m 	c #CC9999",
"n 	c #CC9966",
"o 	c #CC9933",
"p 	c #CC9900",
"q 	c #CC66FF",
"r 	c #CC66CC",
"s 	c #CC6699",
"t 	c #CC6666",
"u 	c #CC6633",
"v 	c #CC6600",
"w 	c #CC33FF",
"x 	c #CC33CC",
"y 	c #CC3399",
"z 	c #CC3366",
"A 	c #CC3333",
"B 	c #CC3300",
"C 	c #CC00FF",
"D 	c #CC00CC",
"E 	c #CC0099",
"F 	c #CC0066",
"G 	c #CC0033",
"H 	c #CC0000",
"I 	c #99FFFF",
"J 	c #99FFCC",
"K 	c #99FF99",
"L 	c #99FF66",
"M 	c #99FF33",
"N 	c #99FF00",
"O 	c #99CCFF",
"P 	c #99CCCC",
"Q 	c #99CC99",
"R 	c #99CC66",
"S 	c #99CC33",
"T 	c #99CC00",
"U 	c #9999FF",
"V 	c #9999CC",
"W 	c #999999",
"X 	c #999966",
"Y 	c #999933",
"Z 	c #999900",
"` 	c #9966FF",
" .	c #9966CC",
"..	c #996699",
"+.	c #996666",
"@.	c #996633",
"#.	c #996600",
"$.	c #9933FF",
"%.	c #9933CC",
"&.	c #993399",
"*.	c #993366",
"=.	c #993333",
"-.	c #993300",
";.	c #9900FF",
">.	c #9900CC",
",.	c #990099",
"'.	c #990066",
").	c #990033",
"!.	c #990000",
"~.	c #66FFFF",
"{.	c #66FFCC",
"].	c #66FF99",
"^.	c #66FF66",
"/.	c #66FF33",
"(.	c #66FF00",
"_.	c #66CCFF",
":.	c #66CCCC",
"<.	c #66CC99",
"[.	c #66CC66",
"}.	c #66CC33",
"|.	c #66CC00",
"1.	c #6699FF",
"2.	c #6699CC",
"3.	c #669999",
"4.	c #669966",
"5.	c #669933",
"6.	c #669900",
"7.	c #6666FF",
"8.	c #6666CC",
"9.	c #666699",
"0.	c #666666",
"a.	c #666633",
"b.	c #666600",
"c.	c #6633FF",
"d.	c #6633CC",
"e.	c #663399",
"f.	c #663366",
"g.	c #663333",
"h.	c #663300",
"i.	c #6600FF",
"j.	c #6600CC",
"k.	c #660099",
"l.	c #660066",
"m.	c #660033",
"n.	c #660000",
"o.	c #33FFFF",
"p.	c #33FFCC",
"q.	c #33FF99",
"r.	c #33FF66",
"s.	c #33FF33",
"t.	c #33FF00",
"u.	c #33CCFF",
"v.	c #33CCCC",
"w.	c #33CC99",
"x.	c #33CC66",
"y.	c #33CC33",
"z.	c #33CC00",
"A.	c #3399FF",
"B.	c #3399CC",
"C.	c #339999",
"D.	c #339966",
"E.	c #339933",
"F.	c #339900",
"G.	c #3366FF",
"H.	c #3366CC",
"I.	c #336699",
"J.	c #336666",
"K.	c #336633",
"L.	c #336600",
"M.	c #3333FF",
"N.	c #3333CC",
"O.	c #333399",
"P.	c #333366",
"Q.	c #333333",
"R.	c #333300",
"S.	c #3300FF",
"T.	c #3300CC",
"U.	c #330099",
"V.	c #330066",
"W.	c #330033",
"X.	c #330000",
"Y.	c #00FFFF",
"Z.	c #00FFCC",
"`.	c #00FF99",
" +	c #00FF66",
".+	c #00FF33",
"++	c #00FF00",
"@+	c #00CCFF",
"#+	c #00CCCC",
"$+	c #00CC99",
"%+	c #00CC66",
"&+	c #00CC33",
"*+	c #00CC00",
"=+	c #0099FF",
"-+	c #0099CC",
";+	c #009999",
">+	c #009966",
",+	c #009933",
"'+	c #009900",
")+	c #0066FF",
"!+	c #0066CC",
"~+	c #006699",
"{+	c #006666",
"]+	c #006633",
"^+	c #006600",
"/+	c #0033FF",
"(+	c #0033CC",
"_+	c #003399",
":+	c #003366",
"<+	c #003333",
"[+	c #003300",
"}+	c #0000FF",
"|+	c #0000CC",
"1+	c #000099",
"2+	c #000066",
"3+	c #000033",
"4+	c #EE0000",
"5+	c #DD0000",
"6+	c #BB0000",
"7+	c #AA0000",
"8+	c #880000",
"9+	c #770000",
"0+	c #550000",
"a+	c #440000",
"b+	c #220000",
"c+	c #110000",
"d+	c #00EE00",
"e+	c #00DD00",
"f+	c #00BB00",
"g+	c #00AA00",
"h+	c #008800",
"i+	c #007700",
"j+	c #005500",
"k+	c #004400",
"l+	c #002200",
"m+	c #001100",
"n+	c #0000EE",
"o+	c #0000DD",
"p+	c #0000BB",
"q+	c #0000AA",
"r+	c #000088",
"s+	c #000077",
"t+	c #000055",
"u+	c #000044",
"v+	c #000022",
"w+	c #000011",
"x+	c #EEEEEE",
"y+	c #DDDDDD",
"z+	c #BBBBBB",
"A+	c #AAAAAA",
"B+	c #888888",
"C+	c #777777",
"D+	c #555555",
"E+	c #444444",
"y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+E+",
"y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+y+E+E+",
"y+y+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+E+E+",
"y+y+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+E+E+",
"y+y+B+B+B+B+B+B+B+B+B+B+i+i+i+i+i+i+i+i+B+B+B+B+B+B+B+B+B+B+E+E+",
"y+y+B+B+B+B+B+B+B+B+i+i+i+i+i+i+i+i+i+i+i+i+B+B+B+B+B+B+B+B+E+E+",
"y+y+B+B+B+B+B+B+B+i+i+i+i+i+i+i+i+i+i+i+i+i+i+B+B+B+B+B+B+B+E+E+",
"y+y+B+B+B+B+B+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+B+B+B+B+B+E+E+",
"y+y+B+B+B+B+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+B+B+B+B+E+E+",
"y+y+B+B+B+B+i+i+i+i+i+i+i+. . . . . i+i+i+i+i+i+i+i+B+B+B+B+E+E+",
"y+y+B+B+B+i+i+i+i+i+i+i+. . . . . . . i+i+i+i+i+i+i+i+B+B+B+E+E+",
"y+y+B+B+B+i+i+i+i+i+i+. . . i+i+i+. . . i+i+i+i+i+i+i+B+B+B+E+E+",
"y+y+B+B+i+i+i+i+i+i+i+. . . i+i+i+. . . i+i+i+i+i+i+i+i+B+B+E+E+",
"y+y+B+B+i+i+i+i+i+i+i+. . . i+i+i+. . . i+i+i+i+i+i+i+i+B+B+E+E+",
"y+y+B+B+i+i+i+i+i+i+i+i+i+i+i+i+. . . i+i+i+i+i+i+i+i+i+B+B+E+E+",
"y+y+B+B+i+i+i+i+i+i+i+i+i+i+i+. . . i+i+i+i+i+i+i+i+i+i+B+B+E+E+",
"y+y+B+B+i+i+i+i+i+i+i+i+i+i+. . . i+i+i+i+i+i+i+i+i+i+i+B+B+E+E+",
"y+y+B+B+i+i+i+i+i+i+i+i+i+i+. . . i+i+i+i+i+i+i+i+i+i+i+B+B+E+E+",
"y+y+B+B+i+i+i+i+i+i+i+i+i+i+. . . i+i+i+i+i+i+i+i+i+i+i+B+B+E+E+",
"y+y+B+B+B+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+B+B+B+E+E+",
"y+y+B+B+B+i+i+i+i+i+i+i+i+i+. . . i+i+i+i+i+i+i+i+i+i+B+B+B+E+E+",
"y+y+B+B+B+B+i+i+i+i+i+i+i+i+. . . i+i+i+i+i+i+i+i+i+B+B+B+B+E+E+",
"y+y+B+B+B+B+i+i+i+i+i+i+i+i+. . . i+i+i+i+i+i+i+i+i+B+B+B+B+E+E+",
"y+y+B+B+B+B+B+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+B+B+B+B+B+E+E+",
"y+y+B+B+B+B+B+B+B+i+i+i+i+i+i+i+i+i+i+i+i+i+i+B+B+B+B+B+B+B+E+E+",
"y+y+B+B+B+B+B+B+B+B+i+i+i+i+i+i+i+i+i+i+i+i+B+B+B+B+B+B+B+B+E+E+",
"y+y+B+B+B+B+B+B+B+B+B+B+i+i+i+i+i+i+i+i+B+B+B+B+B+B+B+B+B+B+E+E+",
"y+y+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+E+E+",
"y+y+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+E+E+",
"y+y+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+B+E+E+",
"y+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+",
"E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+E+"
};

static char * caution_xpm[] = {
"32 32 3 1",
" 	c None",
".	c #000000",
"+	c #FFFF00",
"                                ",
"                                ",
"              ...               ",
"             .+++.              ",
"            .++++...            ",
"            .+++++...           ",
"           .++++++...           ",
"           .+++++++...          ",
"          .++++++++...          ",
"          .+++...+++...         ",
"         .+++.....++...         ",
"         .+++.....+++...        ",
"        .++++.....+++...        ",
"        .++++.....++++...       ",
"       .+++++.....++++...       ",
"       .+++++.....+++++...      ",
"      .++++++.....+++++...      ",
"      .++++++.....++++++...     ",
"     .++++++++...+++++++...     ",
"     .++++++++...++++++++...    ",
"    .+++++++++...++++++++...    ",
"    .+++++++++...+++++++++...   ",
"   .++++++++++++++++++++++...   ",
"   .++++++++++...++++++++++...  ",
"  .++++++++++.....+++++++++...  ",
"  .++++++++++.....++++++++++... ",
" .++++++++++++...+++++++++++... ",
" .+++++++++++++++++++++++++++...",
" .+++++++++++++++++++++++++++...",
" ...............................",
"    ........................... ",
"                                "
};

/* XPM */
static char * HOLD_xpm[] = {
"44 20 217 2",
"  	c None",
". 	c #000000",
"+ 	c #000033",
"@ 	c #000066",
"# 	c #000099",
"$ 	c #0000CC",
"% 	c #0000FF",
"& 	c #003300",
"* 	c #003333",
"= 	c #003366",
"- 	c #003399",
"; 	c #0033CC",
"> 	c #0033FF",
", 	c #006600",
"' 	c #006633",
") 	c #006666",
"! 	c #006699",
"~ 	c #0066CC",
"{ 	c #0066FF",
"] 	c #009900",
"^ 	c #009933",
"/ 	c #009966",
"( 	c #009999",
"_ 	c #0099CC",
": 	c #0099FF",
"< 	c #00CC00",
"[ 	c #00CC33",
"} 	c #00CC66",
"| 	c #00CC99",
"1 	c #00CCCC",
"2 	c #00CCFF",
"3 	c #00FF00",
"4 	c #00FF33",
"5 	c #00FF66",
"6 	c #00FF99",
"7 	c #00FFCC",
"8 	c #00FFFF",
"9 	c #330000",
"0 	c #330033",
"a 	c #330066",
"b 	c #330099",
"c 	c #3300CC",
"d 	c #3300FF",
"e 	c #333300",
"f 	c #333333",
"g 	c #333366",
"h 	c #333399",
"i 	c #3333CC",
"j 	c #3333FF",
"k 	c #336600",
"l 	c #336633",
"m 	c #336666",
"n 	c #336699",
"o 	c #3366CC",
"p 	c #3366FF",
"q 	c #339900",
"r 	c #339933",
"s 	c #339966",
"t 	c #339999",
"u 	c #3399CC",
"v 	c #3399FF",
"w 	c #33CC00",
"x 	c #33CC33",
"y 	c #33CC66",
"z 	c #33CC99",
"A 	c #33CCCC",
"B 	c #33CCFF",
"C 	c #33FF00",
"D 	c #33FF33",
"E 	c #33FF66",
"F 	c #33FF99",
"G 	c #33FFCC",
"H 	c #33FFFF",
"I 	c #660000",
"J 	c #660033",
"K 	c #660066",
"L 	c #660099",
"M 	c #6600CC",
"N 	c #6600FF",
"O 	c #663300",
"P 	c #663333",
"Q 	c #663366",
"R 	c #663399",
"S 	c #6633CC",
"T 	c #6633FF",
"U 	c #666600",
"V 	c #666633",
"W 	c #666666",
"X 	c #666699",
"Y 	c #6666CC",
"Z 	c #6666FF",
"` 	c #669900",
" .	c #669933",
"..	c #669966",
"+.	c #669999",
"@.	c #6699CC",
"#.	c #6699FF",
"$.	c #66CC00",
"%.	c #66CC33",
"&.	c #66CC66",
"*.	c #66CC99",
"=.	c #66CCCC",
"-.	c #66CCFF",
";.	c #66FF00",
">.	c #66FF33",
",.	c #66FF66",
"'.	c #66FF99",
").	c #66FFCC",
"!.	c #66FFFF",
"~.	c #990000",
"{.	c #990033",
"].	c #990066",
"^.	c #990099",
"/.	c #9900CC",
"(.	c #9900FF",
"_.	c #993300",
":.	c #993333",
"<.	c #993366",
"[.	c #993399",
"}.	c #9933CC",
"|.	c #9933FF",
"1.	c #996600",
"2.	c #996633",
"3.	c #996666",
"4.	c #996699",
"5.	c #9966CC",
"6.	c #9966FF",
"7.	c #999900",
"8.	c #999933",
"9.	c #999966",
"0.	c #999999",
"a.	c #9999CC",
"b.	c #9999FF",
"c.	c #99CC00",
"d.	c #99CC33",
"e.	c #99CC66",
"f.	c #99CC99",
"g.	c #99CCCC",
"h.	c #99CCFF",
"i.	c #99FF00",
"j.	c #99FF33",
"k.	c #99FF66",
"l.	c #99FF99",
"m.	c #99FFCC",
"n.	c #99FFFF",
"o.	c #CC0000",
"p.	c #CC0033",
"q.	c #CC0066",
"r.	c #CC0099",
"s.	c #CC00CC",
"t.	c #CC00FF",
"u.	c #CC3300",
"v.	c #CC3333",
"w.	c #CC3366",
"x.	c #CC3399",
"y.	c #CC33CC",
"z.	c #CC33FF",
"A.	c #CC6600",
"B.	c #CC6633",
"C.	c #CC6666",
"D.	c #CC6699",
"E.	c #CC66CC",
"F.	c #CC66FF",
"G.	c #CC9900",
"H.	c #CC9933",
"I.	c #CC9966",
"J.	c #CC9999",
"K.	c #CC99CC",
"L.	c #CC99FF",
"M.	c #CCCC00",
"N.	c #CCCC33",
"O.	c #CCCC66",
"P.	c #CCCC99",
"Q.	c #CCCCCC",
"R.	c #CCCCFF",
"S.	c #CCFF00",
"T.	c #CCFF33",
"U.	c #CCFF66",
"V.	c #CCFF99",
"W.	c #CCFFCC",
"X.	c #CCFFFF",
"Y.	c #FF0000",
"Z.	c #FF0033",
"`.	c #FF0066",
" +	c #FF0099",
".+	c #FF00CC",
"++	c #FF00FF",
"@+	c #FF3300",
"#+	c #FF3333",
"$+	c #FF3366",
"%+	c #FF3399",
"&+	c #FF33CC",
"*+	c #FF33FF",
"=+	c #FF6600",
"-+	c #FF6633",
";+	c #FF6666",
">+	c #FF6699",
",+	c #FF66CC",
"'+	c #FF66FF",
")+	c #FF9900",
"!+	c #FF9933",
"~+	c #FF9966",
"{+	c #FF9999",
"]+	c #FF99CC",
"^+	c #FF99FF",
"/+	c #FFCC00",
"(+	c #FFCC33",
"_+	c #FFCC66",
":+	c #FFCC99",
"<+	c #FFCCCC",
"[+	c #FFCCFF",
"}+	c #FFFF00",
"|+	c #FFFF33",
"1+	c #FFFF66",
"2+	c #FFFF99",
"3+	c #FFFFCC",
"4+	c #FFFFFF",
". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . ",
". Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.f . ",
". Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.W W 4+4+W W W 4+4+W W W 4+4+4+4+4+W W W 4+4+W W W W W 4+4+4+4+4+W W W W W W f f . ",
". Q.Q.W W 4+4+W W W 4+4+W W 4+4+W W W 4+4+W W 4+4+W W W W W 4+4+W W 4+4+W W W W W f f . ",
". Q.Q.W W 4+4+W W W 4+4+W W 4+4+W W W 4+4+W W 4+4+W W W W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+W W W 4+4+W W 4+4+W W W 4+4+W W 4+4+W W W W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+4+4+4+4+4+W W 4+4+W W W 4+4+W W 4+4+W W W W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+W W W 4+4+W W 4+4+W W W 4+4+W W 4+4+W W W W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+W W W 4+4+W W 4+4+W W W 4+4+W W 4+4+W W W W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+W W W 4+4+W W 4+4+W W W 4+4+W W 4+4+W W W W W 4+4+W W 4+4+W W W W W f f . ",
". Q.Q.W W 4+4+W W W 4+4+W W W 4+4+4+4+4+W W W 4+4+4+4+4+4+W 4+4+4+4+4+W W W W W W f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f . ",
". Q.f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f . ",
". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . "
};


/* XPM */
static char * KILL_xpm[] = {
"44 20 217 2",
"  	c None",
". 	c #000000",
"+ 	c #000033",
"@ 	c #000066",
"# 	c #000099",
"$ 	c #0000CC",
"% 	c #0000FF",
"& 	c #003300",
"* 	c #003333",
"= 	c #003366",
"- 	c #003399",
"; 	c #0033CC",
"> 	c #0033FF",
", 	c #006600",
"' 	c #006633",
") 	c #006666",
"! 	c #006699",
"~ 	c #0066CC",
"{ 	c #0066FF",
"] 	c #009900",
"^ 	c #009933",
"/ 	c #009966",
"( 	c #009999",
"_ 	c #0099CC",
": 	c #0099FF",
"< 	c #00CC00",
"[ 	c #00CC33",
"} 	c #00CC66",
"| 	c #00CC99",
"1 	c #00CCCC",
"2 	c #00CCFF",
"3 	c #00FF00",
"4 	c #00FF33",
"5 	c #00FF66",
"6 	c #00FF99",
"7 	c #00FFCC",
"8 	c #00FFFF",
"9 	c #330000",
"0 	c #330033",
"a 	c #330066",
"b 	c #330099",
"c 	c #3300CC",
"d 	c #3300FF",
"e 	c #333300",
"f 	c #333333",
"g 	c #333366",
"h 	c #333399",
"i 	c #3333CC",
"j 	c #3333FF",
"k 	c #336600",
"l 	c #336633",
"m 	c #336666",
"n 	c #336699",
"o 	c #3366CC",
"p 	c #3366FF",
"q 	c #339900",
"r 	c #339933",
"s 	c #339966",
"t 	c #339999",
"u 	c #3399CC",
"v 	c #3399FF",
"w 	c #33CC00",
"x 	c #33CC33",
"y 	c #33CC66",
"z 	c #33CC99",
"A 	c #33CCCC",
"B 	c #33CCFF",
"C 	c #33FF00",
"D 	c #33FF33",
"E 	c #33FF66",
"F 	c #33FF99",
"G 	c #33FFCC",
"H 	c #33FFFF",
"I 	c #660000",
"J 	c #660033",
"K 	c #660066",
"L 	c #660099",
"M 	c #6600CC",
"N 	c #6600FF",
"O 	c #663300",
"P 	c #663333",
"Q 	c #663366",
"R 	c #663399",
"S 	c #6633CC",
"T 	c #6633FF",
"U 	c #666600",
"V 	c #666633",
"W 	c #666666",
"X 	c #666699",
"Y 	c #6666CC",
"Z 	c #6666FF",
"` 	c #669900",
" .	c #669933",
"..	c #669966",
"+.	c #669999",
"@.	c #6699CC",
"#.	c #6699FF",
"$.	c #66CC00",
"%.	c #66CC33",
"&.	c #66CC66",
"*.	c #66CC99",
"=.	c #66CCCC",
"-.	c #66CCFF",
";.	c #66FF00",
">.	c #66FF33",
",.	c #66FF66",
"'.	c #66FF99",
").	c #66FFCC",
"!.	c #66FFFF",
"~.	c #990000",
"{.	c #990033",
"].	c #990066",
"^.	c #990099",
"/.	c #9900CC",
"(.	c #9900FF",
"_.	c #993300",
":.	c #993333",
"<.	c #993366",
"[.	c #993399",
"}.	c #9933CC",
"|.	c #9933FF",
"1.	c #996600",
"2.	c #996633",
"3.	c #996666",
"4.	c #996699",
"5.	c #9966CC",
"6.	c #9966FF",
"7.	c #999900",
"8.	c #999933",
"9.	c #999966",
"0.	c #999999",
"a.	c #9999CC",
"b.	c #9999FF",
"c.	c #99CC00",
"d.	c #99CC33",
"e.	c #99CC66",
"f.	c #99CC99",
"g.	c #99CCCC",
"h.	c #99CCFF",
"i.	c #99FF00",
"j.	c #99FF33",
"k.	c #99FF66",
"l.	c #99FF99",
"m.	c #99FFCC",
"n.	c #99FFFF",
"o.	c #CC0000",
"p.	c #CC0033",
"q.	c #CC0066",
"r.	c #CC0099",
"s.	c #CC00CC",
"t.	c #CC00FF",
"u.	c #CC3300",
"v.	c #CC3333",
"w.	c #CC3366",
"x.	c #CC3399",
"y.	c #CC33CC",
"z.	c #CC33FF",
"A.	c #CC6600",
"B.	c #CC6633",
"C.	c #CC6666",
"D.	c #CC6699",
"E.	c #CC66CC",
"F.	c #CC66FF",
"G.	c #CC9900",
"H.	c #CC9933",
"I.	c #CC9966",
"J.	c #CC9999",
"K.	c #CC99CC",
"L.	c #CC99FF",
"M.	c #CCCC00",
"N.	c #CCCC33",
"O.	c #CCCC66",
"P.	c #CCCC99",
"Q.	c #CCCCCC",
"R.	c #CCCCFF",
"S.	c #CCFF00",
"T.	c #CCFF33",
"U.	c #CCFF66",
"V.	c #CCFF99",
"W.	c #CCFFCC",
"X.	c #CCFFFF",
"Y.	c #FF0000",
"Z.	c #FF0033",
"`.	c #FF0066",
" +	c #FF0099",
".+	c #FF00CC",
"++	c #FF00FF",
"@+	c #FF3300",
"#+	c #FF3333",
"$+	c #FF3366",
"%+	c #FF3399",
"&+	c #FF33CC",
"*+	c #FF33FF",
"=+	c #FF6600",
"-+	c #FF6633",
";+	c #FF6666",
">+	c #FF6699",
",+	c #FF66CC",
"'+	c #FF66FF",
")+	c #FF9900",
"!+	c #FF9933",
"~+	c #FF9966",
"{+	c #FF9999",
"]+	c #FF99CC",
"^+	c #FF99FF",
"/+	c #FFCC00",
"(+	c #FFCC33",
"_+	c #FFCC66",
":+	c #FFCC99",
"<+	c #FFCCCC",
"[+	c #FFCCFF",
"}+	c #FFFF00",
"|+	c #FFFF33",
"1+	c #FFFF66",
"2+	c #FFFF99",
"3+	c #FFFFCC",
"4+	c #FFFFFF",
". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . ",
". ]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+, . ",
". ]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+]+, , . ",
". ]+]+o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.4+4+o.o.4+4+o.o.4+4+o.o.4+4+o.o.o.o.o.4+4+o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.4+4+o.4+4+o.o.o.4+4+o.o.4+4+o.o.o.o.o.4+4+o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.4+4+4+4+o.o.o.o.4+4+o.o.4+4+o.o.o.o.o.4+4+o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.4+4+4+o.o.o.o.o.4+4+o.o.4+4+o.o.o.o.o.4+4+o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.4+4+4+o.o.o.o.o.4+4+o.o.4+4+o.o.o.o.o.4+4+o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.4+4+4+4+o.o.o.o.4+4+o.o.4+4+o.o.o.o.o.4+4+o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.4+4+o.4+4+o.o.o.4+4+o.o.4+4+o.o.o.o.o.4+4+o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.4+4+o.o.4+4+o.o.4+4+o.o.4+4+o.o.o.o.o.4+4+o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.4+4+o.o.o.4+4+o.4+4+o.o.4+4+4+4+4+4+o.4+4+4+4+4+4+o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o.o., , . ",
". ]+]+, , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , . ",
". ]+, , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , . ",
". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . "
};


/* XPM */
static char * FGND_xpm[] = {
"44 20 217 2",
"  	c None",
". 	c #000000",
"+ 	c #000033",
"@ 	c #000066",
"# 	c #000099",
"$ 	c #0000CC",
"% 	c #0000FF",
"& 	c #003300",
"* 	c #003333",
"= 	c #003366",
"- 	c #003399",
"; 	c #0033CC",
"> 	c #0033FF",
", 	c #006600",
"' 	c #006633",
") 	c #006666",
"! 	c #006699",
"~ 	c #0066CC",
"{ 	c #0066FF",
"] 	c #009900",
"^ 	c #009933",
"/ 	c #009966",
"( 	c #009999",
"_ 	c #0099CC",
": 	c #0099FF",
"< 	c #00CC00",
"[ 	c #00CC33",
"} 	c #00CC66",
"| 	c #00CC99",
"1 	c #00CCCC",
"2 	c #00CCFF",
"3 	c #00FF00",
"4 	c #00FF33",
"5 	c #00FF66",
"6 	c #00FF99",
"7 	c #00FFCC",
"8 	c #00FFFF",
"9 	c #330000",
"0 	c #330033",
"a 	c #330066",
"b 	c #330099",
"c 	c #3300CC",
"d 	c #3300FF",
"e 	c #333300",
"f 	c #333333",
"g 	c #333366",
"h 	c #333399",
"i 	c #3333CC",
"j 	c #3333FF",
"k 	c #336600",
"l 	c #336633",
"m 	c #336666",
"n 	c #336699",
"o 	c #3366CC",
"p 	c #3366FF",
"q 	c #339900",
"r 	c #339933",
"s 	c #339966",
"t 	c #339999",
"u 	c #3399CC",
"v 	c #3399FF",
"w 	c #33CC00",
"x 	c #33CC33",
"y 	c #33CC66",
"z 	c #33CC99",
"A 	c #33CCCC",
"B 	c #33CCFF",
"C 	c #33FF00",
"D 	c #33FF33",
"E 	c #33FF66",
"F 	c #33FF99",
"G 	c #33FFCC",
"H 	c #33FFFF",
"I 	c #660000",
"J 	c #660033",
"K 	c #660066",
"L 	c #660099",
"M 	c #6600CC",
"N 	c #6600FF",
"O 	c #663300",
"P 	c #663333",
"Q 	c #663366",
"R 	c #663399",
"S 	c #6633CC",
"T 	c #6633FF",
"U 	c #666600",
"V 	c #666633",
"W 	c #666666",
"X 	c #666699",
"Y 	c #6666CC",
"Z 	c #6666FF",
"` 	c #669900",
" .	c #669933",
"..	c #669966",
"+.	c #669999",
"@.	c #6699CC",
"#.	c #6699FF",
"$.	c #66CC00",
"%.	c #66CC33",
"&.	c #66CC66",
"*.	c #66CC99",
"=.	c #66CCCC",
"-.	c #66CCFF",
";.	c #66FF00",
">.	c #66FF33",
",.	c #66FF66",
"'.	c #66FF99",
").	c #66FFCC",
"!.	c #66FFFF",
"~.	c #990000",
"{.	c #990033",
"].	c #990066",
"^.	c #990099",
"/.	c #9900CC",
"(.	c #9900FF",
"_.	c #993300",
":.	c #993333",
"<.	c #993366",
"[.	c #993399",
"}.	c #9933CC",
"|.	c #9933FF",
"1.	c #996600",
"2.	c #996633",
"3.	c #996666",
"4.	c #996699",
"5.	c #9966CC",
"6.	c #9966FF",
"7.	c #999900",
"8.	c #999933",
"9.	c #999966",
"0.	c #999999",
"a.	c #9999CC",
"b.	c #9999FF",
"c.	c #99CC00",
"d.	c #99CC33",
"e.	c #99CC66",
"f.	c #99CC99",
"g.	c #99CCCC",
"h.	c #99CCFF",
"i.	c #99FF00",
"j.	c #99FF33",
"k.	c #99FF66",
"l.	c #99FF99",
"m.	c #99FFCC",
"n.	c #99FFFF",
"o.	c #CC0000",
"p.	c #CC0033",
"q.	c #CC0066",
"r.	c #CC0099",
"s.	c #CC00CC",
"t.	c #CC00FF",
"u.	c #CC3300",
"v.	c #CC3333",
"w.	c #CC3366",
"x.	c #CC3399",
"y.	c #CC33CC",
"z.	c #CC33FF",
"A.	c #CC6600",
"B.	c #CC6633",
"C.	c #CC6666",
"D.	c #CC6699",
"E.	c #CC66CC",
"F.	c #CC66FF",
"G.	c #CC9900",
"H.	c #CC9933",
"I.	c #CC9966",
"J.	c #CC9999",
"K.	c #CC99CC",
"L.	c #CC99FF",
"M.	c #CCCC00",
"N.	c #CCCC33",
"O.	c #CCCC66",
"P.	c #CCCC99",
"Q.	c #CCCCCC",
"R.	c #CCCCFF",
"S.	c #CCFF00",
"T.	c #CCFF33",
"U.	c #CCFF66",
"V.	c #CCFF99",
"W.	c #CCFFCC",
"X.	c #CCFFFF",
"Y.	c #FF0000",
"Z.	c #FF0033",
"`.	c #FF0066",
" +	c #FF0099",
".+	c #FF00CC",
"++	c #FF00FF",
"@+	c #FF3300",
"#+	c #FF3333",
"$+	c #FF3366",
"%+	c #FF3399",
"&+	c #FF33CC",
"*+	c #FF33FF",
"=+	c #FF6600",
"-+	c #FF6633",
";+	c #FF6666",
">+	c #FF6699",
",+	c #FF66CC",
"'+	c #FF66FF",
")+	c #FF9900",
"!+	c #FF9933",
"~+	c #FF9966",
"{+	c #FF9999",
"]+	c #FF99CC",
"^+	c #FF99FF",
"/+	c #FFCC00",
"(+	c #FFCC33",
"_+	c #FFCC66",
":+	c #FFCC99",
"<+	c #FFCCCC",
"[+	c #FFCCFF",
"}+	c #FFFF00",
"|+	c #FFFF33",
"1+	c #FFFF66",
"2+	c #FFFF99",
"3+	c #FFFFCC",
"4+	c #FFFFFF",
". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . ",
". Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.f . ",
". Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.W W 4+4+4+4+4+4+W W 4+4+4+4+4+W W W 4+4+W W W 4+4+W W 4+4+4+4+4+W W W W W W f f . ",
". Q.Q.W W 4+4+W W W W W 4+4+W W W 4+4+W W 4+4+4+W W 4+4+W W 4+4+W W 4+4+W W W W W f f . ",
". Q.Q.W W 4+4+W W W W W 4+4+W W W W W W W 4+4+4+W W 4+4+W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+W W W W W 4+4+W W W W W W W 4+4+4+4+W 4+4+W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+4+4+4+W W 4+4+W 4+4+4+4+W W 4+4+4+4+W 4+4+W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+W W W W W 4+4+W W W 4+4+W W 4+4+W 4+4+4+4+W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+W W W W W 4+4+W W W 4+4+W W 4+4+W W 4+4+4+W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+W W W W W 4+4+W W 4+4+4+W W 4+4+W W 4+4+4+W W 4+4+W W 4+4+W W W W W f f . ",
". Q.Q.W W 4+4+W W W W W W 4+4+4+4+4+4+W W 4+4+W W W 4+4+W W 4+4+4+4+4+W W W W W W f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f . ",
". Q.f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f . ",
". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . "
};


/* XPM */
static char * BKGD_xpm[] = {
"44 20 217 2",
"  	c None",
". 	c #000000",
"+ 	c #000033",
"@ 	c #000066",
"# 	c #000099",
"$ 	c #0000CC",
"% 	c #0000FF",
"& 	c #003300",
"* 	c #003333",
"= 	c #003366",
"- 	c #003399",
"; 	c #0033CC",
"> 	c #0033FF",
", 	c #006600",
"' 	c #006633",
") 	c #006666",
"! 	c #006699",
"~ 	c #0066CC",
"{ 	c #0066FF",
"] 	c #009900",
"^ 	c #009933",
"/ 	c #009966",
"( 	c #009999",
"_ 	c #0099CC",
": 	c #0099FF",
"< 	c #00CC00",
"[ 	c #00CC33",
"} 	c #00CC66",
"| 	c #00CC99",
"1 	c #00CCCC",
"2 	c #00CCFF",
"3 	c #00FF00",
"4 	c #00FF33",
"5 	c #00FF66",
"6 	c #00FF99",
"7 	c #00FFCC",
"8 	c #00FFFF",
"9 	c #330000",
"0 	c #330033",
"a 	c #330066",
"b 	c #330099",
"c 	c #3300CC",
"d 	c #3300FF",
"e 	c #333300",
"f 	c #333333",
"g 	c #333366",
"h 	c #333399",
"i 	c #3333CC",
"j 	c #3333FF",
"k 	c #336600",
"l 	c #336633",
"m 	c #336666",
"n 	c #336699",
"o 	c #3366CC",
"p 	c #3366FF",
"q 	c #339900",
"r 	c #339933",
"s 	c #339966",
"t 	c #339999",
"u 	c #3399CC",
"v 	c #3399FF",
"w 	c #33CC00",
"x 	c #33CC33",
"y 	c #33CC66",
"z 	c #33CC99",
"A 	c #33CCCC",
"B 	c #33CCFF",
"C 	c #33FF00",
"D 	c #33FF33",
"E 	c #33FF66",
"F 	c #33FF99",
"G 	c #33FFCC",
"H 	c #33FFFF",
"I 	c #660000",
"J 	c #660033",
"K 	c #660066",
"L 	c #660099",
"M 	c #6600CC",
"N 	c #6600FF",
"O 	c #663300",
"P 	c #663333",
"Q 	c #663366",
"R 	c #663399",
"S 	c #6633CC",
"T 	c #6633FF",
"U 	c #666600",
"V 	c #666633",
"W 	c #666666",
"X 	c #666699",
"Y 	c #6666CC",
"Z 	c #6666FF",
"` 	c #669900",
" .	c #669933",
"..	c #669966",
"+.	c #669999",
"@.	c #6699CC",
"#.	c #6699FF",
"$.	c #66CC00",
"%.	c #66CC33",
"&.	c #66CC66",
"*.	c #66CC99",
"=.	c #66CCCC",
"-.	c #66CCFF",
";.	c #66FF00",
">.	c #66FF33",
",.	c #66FF66",
"'.	c #66FF99",
").	c #66FFCC",
"!.	c #66FFFF",
"~.	c #990000",
"{.	c #990033",
"].	c #990066",
"^.	c #990099",
"/.	c #9900CC",
"(.	c #9900FF",
"_.	c #993300",
":.	c #993333",
"<.	c #993366",
"[.	c #993399",
"}.	c #9933CC",
"|.	c #9933FF",
"1.	c #996600",
"2.	c #996633",
"3.	c #996666",
"4.	c #996699",
"5.	c #9966CC",
"6.	c #9966FF",
"7.	c #999900",
"8.	c #999933",
"9.	c #999966",
"0.	c #999999",
"a.	c #9999CC",
"b.	c #9999FF",
"c.	c #99CC00",
"d.	c #99CC33",
"e.	c #99CC66",
"f.	c #99CC99",
"g.	c #99CCCC",
"h.	c #99CCFF",
"i.	c #99FF00",
"j.	c #99FF33",
"k.	c #99FF66",
"l.	c #99FF99",
"m.	c #99FFCC",
"n.	c #99FFFF",
"o.	c #CC0000",
"p.	c #CC0033",
"q.	c #CC0066",
"r.	c #CC0099",
"s.	c #CC00CC",
"t.	c #CC00FF",
"u.	c #CC3300",
"v.	c #CC3333",
"w.	c #CC3366",
"x.	c #CC3399",
"y.	c #CC33CC",
"z.	c #CC33FF",
"A.	c #CC6600",
"B.	c #CC6633",
"C.	c #CC6666",
"D.	c #CC6699",
"E.	c #CC66CC",
"F.	c #CC66FF",
"G.	c #CC9900",
"H.	c #CC9933",
"I.	c #CC9966",
"J.	c #CC9999",
"K.	c #CC99CC",
"L.	c #CC99FF",
"M.	c #CCCC00",
"N.	c #CCCC33",
"O.	c #CCCC66",
"P.	c #CCCC99",
"Q.	c #CCCCCC",
"R.	c #CCCCFF",
"S.	c #CCFF00",
"T.	c #CCFF33",
"U.	c #CCFF66",
"V.	c #CCFF99",
"W.	c #CCFFCC",
"X.	c #CCFFFF",
"Y.	c #FF0000",
"Z.	c #FF0033",
"`.	c #FF0066",
" +	c #FF0099",
".+	c #FF00CC",
"++	c #FF00FF",
"@+	c #FF3300",
"#+	c #FF3333",
"$+	c #FF3366",
"%+	c #FF3399",
"&+	c #FF33CC",
"*+	c #FF33FF",
"=+	c #FF6600",
"-+	c #FF6633",
";+	c #FF6666",
">+	c #FF6699",
",+	c #FF66CC",
"'+	c #FF66FF",
")+	c #FF9900",
"!+	c #FF9933",
"~+	c #FF9966",
"{+	c #FF9999",
"]+	c #FF99CC",
"^+	c #FF99FF",
"/+	c #FFCC00",
"(+	c #FFCC33",
"_+	c #FFCC66",
":+	c #FFCC99",
"<+	c #FFCCCC",
"[+	c #FFCCFF",
"}+	c #FFFF00",
"|+	c #FFFF33",
"1+	c #FFFF66",
"2+	c #FFFF99",
"3+	c #FFFFCC",
"4+	c #FFFFFF",
". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . ",
". Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.f . ",
". Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.Q.f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.W W 4+4+4+4+4+W W W 4+4+W W 4+4+W W W 4+4+4+4+4+W W W 4+4+4+4+4+W W W W W W f f . ",
". Q.Q.W W 4+4+W W 4+4+W W 4+4+W 4+4+W W W 4+4+W W W 4+4+W W 4+4+W W 4+4+W W W W W f f . ",
". Q.Q.W W 4+4+W W 4+4+W W 4+4+4+4+W W W W 4+4+W W W W W W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+W W 4+4+W W 4+4+4+W W W W W 4+4+W W W W W W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+4+4+4+W W W 4+4+4+W W W W W 4+4+W 4+4+4+4+W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+W W 4+4+W W 4+4+4+4+W W W W 4+4+W W W 4+4+W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+W W 4+4+W W 4+4+W 4+4+W W W 4+4+W W W 4+4+W W 4+4+W W W 4+4+W W W W f f . ",
". Q.Q.W W 4+4+W W 4+4+W W 4+4+W W 4+4+W W 4+4+W W 4+4+4+W W 4+4+W W 4+4+W W W W W f f . ",
". Q.Q.W W 4+4+4+4+4+W W W 4+4+W W W 4+4+W W 4+4+4+4+4+4+W W 4+4+4+4+4+W W W W W W f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W W f f . ",
". Q.Q.f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f . ",
". Q.f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f f . ",
". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . "
};

/*
 *  Build the application tool bar.
 */

static GtkWidget *
build_toolbar(GtkWidget *box)
{
    	GtkWidget *toolbar = NULL;
    	GtkWidget *button = NULL;
    	GtkWidget *label = NULL;
	GtkWidget *menu = NULL;
	GtkWidget *frame = NULL;
	char buf1[MESSAGE_SIZE];
	char buf2[MESSAGE_SIZE];
	int smp;

        toolbar = gtk_toolbar_new(GTK_ORIENTATION_HORIZONTAL, GTK_TOOLBAR_TEXT);
        gtk_box_pack_start(GTK_BOX(box), toolbar, FALSE, FALSE, 0); 

	Shm->wmd->toolbar = track_widget(toolbar);

       /*
    	*  The host system data
	*/
	smp = show_cpu_stats(GET_SMP_COUNT);
	if (smp)
            	sprintf(buf1, "  %s - %s (%d)  \n", 
			dec_node(Shm->utsname.nodename, buf2),
                	Shm->utsname.machine, smp);
	else
       	    	sprintf(buf1, "  %s - %s  \n", 
			dec_node(Shm->utsname.nodename, buf2),
                	Shm->utsname.machine);
        sprintf(&buf1[strlen(buf1)], "  %s %s  ",
                Shm->utsname.sysname, Shm->utsname.release);
        label = gtk_label_new(buf1);
	frame = gtk_frame_new(NULL);
	gtk_frame_set_shadow_type(GTK_FRAME(frame), GTK_SHADOW_IN);
	gtk_container_add(GTK_CONTAINER(frame), label);
        gtk_toolbar_append_widget(GTK_TOOLBAR(toolbar), frame,
                "system data", "system data");
	gtk_widget_show(label);
	gtk_widget_show(frame);

	gtk_toolbar_append_space(GTK_TOOLBAR(toolbar));
	gtk_toolbar_append_space(GTK_TOOLBAR(toolbar));

       /*
	*  The overall kill button.
	*/
        button = gtk_button_new();
        gtk_container_add(GTK_CONTAINER(button), 
		build_picwidget((gchar **)stop_xpm, FALSE));
        gtk_signal_connect (GTK_OBJECT(button), "button_release_event",
        	GTK_SIGNAL_FUNC(kill_usex_button_release), NULL);
        gtk_toolbar_append_widget(GTK_TOOLBAR(toolbar), button,
                "Click to shut down this USEX session", "kill button");
	Shm->wmd->kill_usex_button = track_widget(button);
	gtk_widget_show_all(button);

	gtk_toolbar_append_space(GTK_TOOLBAR(toolbar));

       /*
	*  The USEX control button and menu.
	*/
        button = gtk_button_new();
        gtk_container_add(GTK_CONTAINER(button),
                build_picwidget((gchar **)testctl_xpm, FALSE));
        gtk_signal_connect (GTK_OBJECT(button), "button_release_event",
                GTK_SIGNAL_FUNC(usex_control_button_release), NULL);
        gtk_toolbar_append_widget(GTK_TOOLBAR(toolbar), button,
                "Click to view USEX session control options", 
		"USEX control button");
        Shm->wmd->usex_control_button = track_widget(button);
        gtk_widget_show_all(button);

        Shm->wmd->usex_control = menu = gtk_menu_new();
#ifdef NOTDEF
	if (Shm->procno) {
        	build_menu_item("Put all tests in background", 
			0, test_control_menu, menu, NULL, TEST_BACKGROUND_ALL);
        	build_menu_item("Put all tests in foreground", 
			0, test_control_menu, menu, NULL, TEST_FOREGROUND_ALL);
        	build_menu_item("Put all tests on hold", 
			0, test_control_menu, menu, NULL, TEST_HOLD_ALL);
        	build_menu_item("Kill all tests", 0, 
			test_control_menu, menu, NULL, TEST_KILL_ALL);
        	build_menu_item("Show last test messages", 
			0, test_control_menu, menu, NULL, TEST_MESSAGES_ALL);
        	build_menu_item("Show fatal error messages", 
			0, test_control_menu, menu, NULL, TEST_FATAL_MESSAGES);
        	build_menu_item(NULL, 0, NULL, menu, NULL, 0);
	}
#endif
        build_menu_item("Inquiry of internal state", 
		0, usex_control_menu, menu, NULL, USEX_INQUIRY);
        build_menu_item("Snapshot internal state", 0, usex_control_menu,
                menu, NULL, USEX_SNAPSHOT);
        build_menu_item("Show input file", 0, usex_control_menu, menu, NULL,
                SHOW_INPUT_FILE);
        build_menu_item("Save input file", 0, usex_control_menu, menu, NULL,
                SAVE_INPUT_FILE);
        build_menu_item("External shell", 0, usex_control_menu, menu, NULL,
                EXTERNAL_SHELL);
        build_menu_item("External top session", 0, usex_control_menu, menu, 
		NULL, EXTERNAL_TOP);
        build_menu_item("Toggle debug mode", 0, usex_control_menu, menu, NULL,
                TOGGLE_DEBUG);
        build_menu_item("Show build information", 0, usex_control_menu, 
		menu, NULL, USEX_BUILD_INFO);
        gtk_widget_show_all(GTK_WIDGET(menu));

	gtk_toolbar_append_space(GTK_TOOLBAR(toolbar));

       /*
        *  The USEX help button and menu.
        */
        button = gtk_button_new();
        gtk_container_add(GTK_CONTAINER(button), 
		build_picwidget((gchar **)help_xpm, FALSE));
        gtk_signal_connect (GTK_OBJECT(button), "button_release_event",
                GTK_SIGNAL_FUNC(help_button_release), NULL);
        gtk_toolbar_append_widget(GTK_TOOLBAR(toolbar), button,
                "Click to view USEX help options",
                "USEX help button");
        Shm->wmd->usex_help_button = track_widget(button);
        gtk_widget_show_all(button);

	gtk_toolbar_append_space(GTK_TOOLBAR(toolbar));
	gtk_toolbar_append_space(GTK_TOOLBAR(toolbar));

	if (Shm->procno) {
	       /*
	        *  The test control FGND button.
	        */
	        button = gtk_button_new();
	        gtk_container_add(GTK_CONTAINER(button),
	                build_picwidget((gchar **)FGND_xpm, FALSE));
	        gtk_signal_connect (GTK_OBJECT(button), "button_release_event",
	                GTK_SIGNAL_FUNC(test_control_button_release), "FGND");
	        gtk_toolbar_append_widget(GTK_TOOLBAR(toolbar), button,
	                "Click to put all tests in foreground display mode.  "
			"Each test STAT will indicate: OK", 
			"FGND button");
	        Shm->wmd->test_control_fgnd = track_widget(button); 
	        gtk_widget_show_all(button);
	
	
	       /*
	        *  The test control BKGD button.
	        */
	        button = gtk_button_new();
	        gtk_container_add(GTK_CONTAINER(button),
	                build_picwidget((gchar **)BKGD_xpm, FALSE));
	        gtk_signal_connect (GTK_OBJECT(button), "button_release_event",
	                GTK_SIGNAL_FUNC(test_control_button_release), "BKGD");
	        gtk_toolbar_append_widget(GTK_TOOLBAR(toolbar), button,
	                "Click to put all tests in background display mode.  " 
			"Each test STAT will indicate: BKGD", 
	                "BKGD button");
	        Shm->wmd->test_control_bkgd = track_widget(button); 
	        gtk_widget_show_all(button);
	
	
	       /*
	        *  The test control HOLD button.
	        */
	        button = gtk_button_new();
	        gtk_container_add(GTK_CONTAINER(button),
	                build_picwidget((gchar **)HOLD_xpm, FALSE));
	        gtk_signal_connect (GTK_OBJECT(button), "button_release_event",
	                GTK_SIGNAL_FUNC(test_control_button_release), "HOLD");
	        gtk_toolbar_append_widget(GTK_TOOLBAR(toolbar), button,
	                "Click to put all tests on hold.  "
			"Each test STAT will indicate: WAIT, then HOLD", 
	                "HOLD button");
	        Shm->wmd->test_control_hold = track_widget(button); 
	        gtk_widget_show_all(button);
	
	
	       /*
	        *  The test control KILL button.
	        */
	        button = gtk_button_new();
	        gtk_container_add(GTK_CONTAINER(button),
	                build_picwidget((gchar **)KILL_xpm, FALSE));
	        gtk_signal_connect (GTK_OBJECT(button), "button_release_event",
	                GTK_SIGNAL_FUNC(test_control_button_release), "KILL");
	        gtk_toolbar_append_widget(GTK_TOOLBAR(toolbar), button,
	                "Click to kill all tests.  "
			"Each test STAT will indicate: DEAD", 
	                "KILL button");
	        Shm->wmd->test_control_kill = track_widget(button); 
	        gtk_widget_show_all(button);
	}


       /*
	*  The user input window.
        */
        sprintf(buf1, "          ");
        Shm->wmd->user_input = label = gtk_label_new(buf1);
	gtk_mgr_set_font(label, Shm->wmd->fixed);
	gtk_label_set_justify(GTK_LABEL(label), GTK_JUSTIFY_LEFT);
	gtk_misc_set_alignment(GTK_MISC(label), 0.0f, 0.0f);
        frame = gtk_frame_new(NULL);
        gtk_frame_set_shadow_type(GTK_FRAME(frame), GTK_SHADOW_IN);
        gtk_container_add(GTK_CONTAINER(frame), label);
        gtk_toolbar_append_widget(GTK_TOOLBAR(toolbar), frame,
                "user input", "user input");
#ifdef SHOW_USER_INPUT
        gtk_widget_show(label);
        gtk_widget_show(frame);
#endif


       /*
	*  Hidden button -- activate it for whatever purpose by:
        * 
      	*    gtk_signal_emit_by_name(GTK_OBJECT(Shm->wmd->hidden_button), 
        *            "clicked");
	*/
        Shm->wmd->hidden_button = gtk_button_new();
        gtk_signal_connect (GTK_OBJECT(Shm->wmd->hidden_button), "clicked",
                GTK_SIGNAL_FUNC(hidden_button_press), NULL);

	gtk_widget_show(toolbar);

	return toolbar;
}

/*
 *  Load globally-used fonts.
 */
static void
gtk_mgr_load_fonts(void) 
{
        Shm->wmd->fixed = gdk_font_load(GTK_MGR_FIXED_FONT);
}

/*
 *  Display a message in the status bar.
 */
void
gtk_mgr_status_bar_message(gchar *msg)
{
	if (!(Shm->mode & GINIT))
		return;

	gtk_label_set_text(GTK_LABEL(Shm->wmd->status_bar), msg);
}

/*
 *  Display a message and wait until it's exposed (called during event-handling)
 */
void
gtk_mgr_status_bar_message_wait(gchar *buf)
{
	int cnt;

	if (!(Shm->mode & GINIT))
		return;

        Shm->wmd->status_bar_exposed = NULL;

        USER_MESSAGE(buf);

	if (!(Shm->wmd->flags & TOPLEVEL_MAP))
		return;

        for (cnt = 0; gtk_events_pending() && (cnt < 100); cnt++) {
                gtk_main_iteration();
                if (streq(buf, Shm->wmd->status_bar_exposed)) {
			/* console("status message cnt: %d\n", cnt); */
                        return;
		}
        }
}

/*
 *  Timer callback function.
 */
static gint
gtk_mgr_timer_callback(gpointer data)
{
	return TRUE;
}

/*
 *  Keep track whether the toplevel is mapped or not.
 */
static void
toplevel_map(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	if (data == TOPLEVEL_MAP_EVENT)
		Shm->wmd->flags |= TOPLEVEL_MAP;	
        else if (data == TOPLEVEL_UNMAP_EVENT)
		Shm->wmd->flags &= ~TOPLEVEL_MAP;	
}

/*
 *  Toplevel key press handler.
 */ 

static gboolean
toplevel_key_press(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	register gint i;
	GdkEventKey *key_event;
	gint eol;
	char buf[MESSAGE_SIZE];

	key_event = (GdkEventKey *)event;
	eol = FALSE;

 console("toplevel_key_press: ENTERED: val: %x (%u) length: %d string: [%s]\n",
                key_event->keyval,
                key_event->keyval,
                key_event->length,
                key_event->string);

	switch (key_event->keyval)
	{
	case 0xff0d:            /* Return */
		eol = TRUE;
		break;

	case 0xffff:            /* Delete */
	case 0xff08:            /* Backspace */
		if ((i = strlen(Shm->wmd->toplevel_string)))
			Shm->wmd->toplevel_string[i-1] = NULLCHAR;
		break;

	case 0xffe2:            /* Shift */
		return FALSE;

	default:
		if (isascii(key_event->keyval))
			strcat(Shm->wmd->toplevel_string, key_event->string);
		else {
			return FALSE;
			console("IGNORING last keystroke!\n");
		}
		break;
	}

 console("toplevel CURRENT: [%s]\n", Shm->wmd->toplevel_string);

	gtk_label_set_text(GTK_LABEL(Shm->wmd->user_input), 
		mkstring(shift_string_right(Shm->wmd->toplevel_string, 1, buf),
			10, LJUST));

	if (TOPLEVEL_STRING_IS("k") || TOPLEVEL_STRING_IS("q")) {
		CLEAR_TOPLEVEL_STRING();
		kill_usex_button_release(NULL, NULL, NULL);
		return TRUE;
	}

        if (TOPLEVEL_STRING_IS("tk")) {
                CLEAR_TOPLEVEL_STRING();
/*
                test_control_menu(widget, TEST_KILL_ALL);
*/
		kill_tests_dialog_window(kill_tests_message);
                return TRUE;
        }

        if (TOPLEVEL_STRING_IS("tb")) {
                CLEAR_TOPLEVEL_STRING();
                test_control_menu(widget, TEST_BACKGROUND_ALL);
                return TRUE;
        }

        if (TOPLEVEL_STRING_IS("th")) {
                CLEAR_TOPLEVEL_STRING();
                test_control_menu(widget, TEST_HOLD_ALL);
                return TRUE;
        }

	if (TOPLEVEL_STRING_IS("d")) {
		CLEAR_TOPLEVEL_STRING();
		usex_control_menu(widget, TOGGLE_DEBUG);
                return TRUE;
        }

        if (TOPLEVEL_STRING_IS("b")) {
                CLEAR_TOPLEVEL_STRING();
                usex_control_menu(widget, USEX_BUILD_INFO);
                return TRUE;
        }

        if (TOPLEVEL_STRING_IS("u")) {
                CLEAR_TOPLEVEL_STRING();
                usex_control_menu(widget, USEX_UNAME_INFO);
                return TRUE;
        }

        if (TOPLEVEL_STRING_IS("h")) {
                CLEAR_TOPLEVEL_STRING();
		gtk_mgr_help_table();
                return TRUE;
        }

	if (TOPLEVEL_STRING_IS("f")) {
                CLEAR_TOPLEVEL_STRING();
                usex_control_menu(widget, SHOW_INPUT_FILE);
                return TRUE;
        }

	if (TOPLEVEL_STRING_IS("F")) {
                CLEAR_TOPLEVEL_STRING();
                usex_control_menu(widget, SAVE_INPUT_FILE);
                return TRUE;
        }

	if (TOPLEVEL_STRING_IS("s")) {
                CLEAR_TOPLEVEL_STRING();
                usex_control_menu(widget, USEX_SNAPSHOT);
                return TRUE;
        }

	if (TOPLEVEL_STRING_IS("i") || TOPLEVEL_STRING_IS("I")) {
                CLEAR_TOPLEVEL_STRING();
                usex_control_menu(widget, USEX_INQUIRY);
                return TRUE;
        }

        if (TOPLEVEL_STRING_IS("m")) {
                CLEAR_TOPLEVEL_STRING();
                test_control_menu(widget, TEST_MESSAGES_ALL);
                return TRUE;
        }

        if (TOPLEVEL_STRING_IS("M")) {
                CLEAR_TOPLEVEL_STRING();
                test_control_menu(widget, TEST_FATAL_MESSAGES);
                return TRUE;
        }

        if (TOPLEVEL_STRING_IS("!")) {
                CLEAR_TOPLEVEL_STRING();
                usex_control_menu(widget, EXTERNAL_SHELL);
                return TRUE;
        }

        if (TOPLEVEL_STRING_IS("T")) {
                CLEAR_TOPLEVEL_STRING();
                usex_control_menu(widget, EXTERNAL_TOP);
                return TRUE;
        }

        if ((FIRSTCHAR(Shm->wmd->toplevel_string) == 't') &&
            (LASTCHAR(Shm->wmd->toplevel_string) == 'k')) {
                LASTCHAR(Shm->wmd->toplevel_string) = NULLCHAR;
		if (strlen(&Shm->wmd->toplevel_string[1]) &&
		    decimal(&Shm->wmd->toplevel_string[1], 0)) {
			if ((i = atoi(&Shm->wmd->toplevel_string[1]))) {
				Shm->wmd->test_control_id = i-1;
				individual_test_menu(widget, TEST_KILL);
			}
		}
                CLEAR_TOPLEVEL_STRING();
                return TRUE;
        }

        if ((FIRSTCHAR(Shm->wmd->toplevel_string) == 't') &&
            (LASTCHAR(Shm->wmd->toplevel_string) == 'b')) {
                LASTCHAR(Shm->wmd->toplevel_string) = NULLCHAR;
                if (strlen(&Shm->wmd->toplevel_string[1]) &&
                    decimal(&Shm->wmd->toplevel_string[1], 0)) {
                        if ((i = atoi(&Shm->wmd->toplevel_string[1]))) {
                                Shm->wmd->test_control_id = i-1;
                                individual_test_menu(widget, TEST_BACKGROUND);
                        }
                }
                CLEAR_TOPLEVEL_STRING();
                return TRUE;
        }

        if ((FIRSTCHAR(Shm->wmd->toplevel_string) == 't') &&
            (LASTCHAR(Shm->wmd->toplevel_string) == 'h')) {
                LASTCHAR(Shm->wmd->toplevel_string) = NULLCHAR;
                if (strlen(&Shm->wmd->toplevel_string[1]) &&
                    decimal(&Shm->wmd->toplevel_string[1], 0)) {
                        if ((i = atoi(&Shm->wmd->toplevel_string[1]))) {
                                Shm->wmd->test_control_id = i-1;
                                individual_test_menu(widget, TEST_HOLD);
                        }
                }
                CLEAR_TOPLEVEL_STRING();
                return TRUE;
        }

        if ((FIRSTCHAR(Shm->wmd->toplevel_string) == 't') &&
            (LASTCHAR(Shm->wmd->toplevel_string) == 'm')) {
                LASTCHAR(Shm->wmd->toplevel_string) = NULLCHAR;
                if (strlen(&Shm->wmd->toplevel_string[1]) &&
                    decimal(&Shm->wmd->toplevel_string[1], 0)) {
                        if ((i = atoi(&Shm->wmd->toplevel_string[1]))) {
                                Shm->wmd->test_control_id = i-1;
                                individual_test_menu(widget, TEST_MESSAGES);
                        }
                }
                CLEAR_TOPLEVEL_STRING();
                return TRUE;
        }

        if ((FIRSTCHAR(Shm->wmd->toplevel_string) == 't') &&
            (LASTCHAR(Shm->wmd->toplevel_string) == 'i')) {
                LASTCHAR(Shm->wmd->toplevel_string) = NULLCHAR;
                if (strlen(&Shm->wmd->toplevel_string[1]) &&
                    decimal(&Shm->wmd->toplevel_string[1], 0)) {
                        if ((i = atoi(&Shm->wmd->toplevel_string[1]))) {
                                Shm->wmd->test_control_id = i-1;
                                individual_test_menu(widget, TEST_INQUIRY);
                        }
                }
                CLEAR_TOPLEVEL_STRING();
                return TRUE;
        }

	if (!eol)
		return FALSE;

console("EOL: [%s]\n", Shm->wmd->toplevel_string);

	if (TOPLEVEL_STRING_IS("")) {
		USER_MESSAGE("");
                return TRUE;
	}

        if (TOPLEVEL_STRING_IS("t")) {
                CLEAR_TOPLEVEL_STRING();
                test_control_menu(widget, TEST_FOREGROUND_ALL);
                return TRUE;
        }

        if ((FIRSTCHAR(Shm->wmd->toplevel_string) == 't') &&
	    decimal(&Shm->wmd->toplevel_string[1], 0)) {
		if ((i = atoi(&Shm->wmd->toplevel_string[1]))) {
                        Shm->wmd->test_control_id = i-1;
                        individual_test_menu(widget, TEST_FOREGROUND);
                	CLEAR_TOPLEVEL_STRING();
                	return TRUE;
               	}
	}

        gtk_window_set_policy(GTK_WINDOW(Shm->wmd->toplevel), 
		FALSE, TRUE, TRUE);
        Shm->wmd->flags |= GTK_MGR_RESIZE;

        CLEAR_TOPLEVEL_STRING();
	return FALSE;
}

/*
 *  The entry point into the GTK world.
 */

gint gtk_mgr_main(gint argc, gchar **argv)
{
    	GtkWidget *toplevel = NULL;
    	GtkWidget *mainbox = NULL;
	char buf[MESSAGE_SIZE];

       /*
	*  Set up the toplevel window.
        */
    	Shm->wmd->toplevel = toplevel = 
		track_widget(gtk_window_new(GTK_WINDOW_TOPLEVEL));
    	gtk_signal_connect(GTK_OBJECT(toplevel), "delete_event",
    		GTK_SIGNAL_FUNC(delete_event_handler), NULL);
    	gtk_signal_connect(GTK_OBJECT(toplevel), "destroy",
    		GTK_SIGNAL_FUNC(destroy_handler), NULL);
        gtk_signal_connect(GTK_OBJECT(toplevel), "map_event",
                GTK_SIGNAL_FUNC(toplevel_map), TOPLEVEL_MAP_EVENT);
        gtk_signal_connect(GTK_OBJECT(toplevel), "unmap_event",
                GTK_SIGNAL_FUNC(toplevel_map), TOPLEVEL_UNMAP_EVENT);
        gtk_signal_connect(GTK_OBJECT(toplevel), "key_press_event",
                GTK_SIGNAL_FUNC(toplevel_key_press), TOPLEVEL_KEYPRESS_EVENT);
	sprintf(buf, "Unix System Exerciser  -  USEX Version %s", USEX_VERSION);
    	gtk_window_set_title(GTK_WINDOW(toplevel), buf);
    	gtk_container_set_border_width(GTK_CONTAINER (toplevel), 5);

       /*
        *  Set up the main vbox and add it to the toplevel window.
        */
	Shm->wmd->mainbox = mainbox = gtk_vbox_new(FALSE, 0);
	gtk_container_add(GTK_CONTAINER(toplevel), mainbox);
	gtk_widget_show(mainbox);

       /*
	*  Load up prospective fonts.
	*/
	gtk_mgr_load_fonts();

       /*
        *  Create and populate the tool bar, and add it to the vbox.
        */
	build_toolbar(mainbox);

       /*
        *  Create the frames and add them to the vbox.
        */
	build_test_data(mainbox); 
	build_system_data(mainbox); 
	build_status_bar(mainbox);

	if (Shm->wmd->flags & SCROLL_TEST_DATA) 
		gtk_mgr_adjust_window_size(toplevel);

    	gtk_widget_show(toplevel);

       /*
	*  Currently unused.
	*/
	gtk_timeout_add(500, (GtkFunction)gtk_mgr_timer_callback, NULL);

       /*
	*  While gtk_main() gathers all the GTK signals and events, 
        *  gtk_mgr() runs the rest of time via gtk_mgr_idle(). 
        *  gtk_mgr() checks for USEX-related events, passing them
        *  on to post_usex_message() for processing.
        */

	gtk_idle_add(gtk_mgr_idle, NULL); 

	init_common();
    	Shm->mode |= GINIT;

    	gtk_main();

	if (Shm->mode & DEBUG_MODE)
		console("back from gtk_main...\n");

    	return(0); 
}


static void
gtk_mgr_output_message(char *msg)
{
        if (Shm->mode & GINIT) {
		USER_MESSAGE(msg);
	} else {
		if (Shm->mode & NOTTY)
			console(msg);   /* where else can this go? */
		else
			fprintf(stdout, msg);
	}
}

static void 
gtk_mgr_error_message(char *msg)
{
        if (Shm->mode & GINIT) {
		USER_MESSAGE(msg);
        } else {
		if (Shm->mode & NOTTY)
			console(msg);   /* where else can this go? */
                else
                        fprintf(stderr, msg);
        }
}

void 
gtk_mgr_perror(char *msg)
{
        char buf[MAX_PIPELINE_READ];

	sprintf(buf, "%s: %s", msg, strerror(errno));

	gtk_mgr_error_message(buf);
}

void 
gtk_mgr_stderr(char *fmt, ...)
{
        char buf[MAX_PIPELINE_READ];
        va_list ap;

        va_start(ap, fmt);
        (void)vsnprintf(buf, MAX_PIPELINE_READ, fmt, ap);
        va_end(ap);

	gtk_mgr_error_message(buf);
}

void
gtk_mgr_printf(char *fmt, ...)
{
        char buf[MAX_PIPELINE_READ];
        va_list ap;

        va_start(ap, fmt);
        (void)vsnprintf(buf, MAX_PIPELINE_READ, fmt, ap);
        va_end(ap);

        gtk_mgr_output_message(buf);
}


/*
 *  gtk_mgr() handles all USEX-related functionality.  Each time it is called,
 *  it checks the per-second USEX timer queue for anything scheduled to run,
 *  walks though each of the test processes output data buffers for display
 *  data and status, and calls the errdaemon() to look for test failures.
 *  It returns the number of test processes for which data was available.
 */

gint
gtk_mgr(void)
{
	gint id, queue, cycle_reads;
	gchar buffer[MESSAGE_SIZE];
	gboolean try_again;
	guchar cmd;
    	struct timer_request *treq = &Shm->timer_request;

	if (Shm->mode & SHUTDOWN_MODE)
		return 1;

        if (check_timer(treq)) {
                do_timer_functions();
		if (Shm->mode & SHUTDOWN_MODE) 
			return 1;
	}

        if (mother_is_dead(Shm->parent_shell, "G1")) {  /* sh -c is dead. */
            	common_kill(KILL_ALL, SHUTDOWN);
            	die(0, DIE(22), TRUE);
		return 1;
        }

        if (CTRL_C_ENTERED()) {
		console("gtk_mgr: CTRL-C entered\n");
		USER_MESSAGE("CTRL-C ignored -- use kill button");
                Shm->mode &= ~CTRL_C;
		beep();
        }

        bzero(buffer, MESSAGE_SIZE); 
	try_again = FALSE;

	for (queue = cycle_reads = 0; queue < NUMSG; queue++) {

        	if (try_again) {
            		queue--;
            		try_again = FALSE;
        	}

        	if (!get_usex_message(queue, buffer))
            		continue;

        	cycle_reads++;

        	cmd = (unsigned char)buffer[0];     /* Pull out the command. */
        	id = (gint)(buffer[1] - FIRST_ID);  /* "id" only present in  */
                                            	    /* I/O test messages.    */

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

		if (!post_usex_message(id, cmd, buffer, (BOOL *)&try_again))
                	unresolved(buffer, queue);
	}

	return (errdaemon(cycle_reads));
}

static void
external_window_destroy(GtkWidget *widget, gpointer data)
{
	struct external_window *ex;

	ex = (struct external_window *)data;
	gtk_widget_destroy(ex->text);
	gtk_widget_destroy(ex->frame);
	gtk_widget_destroy(ex->scroll);
	gtk_widget_destroy(ex->top);

	free(ex->data);
	free(ex);
	
}

/*
 *  Display the contents of a file in an external window.
 */
void
gtk_mgr_display_external(FILE *fp, gchar *header)
{
	int lc, ht, wid, cols;
	struct external_window *ex;
	char buf[MESSAGE_SIZE*2];
	struct stat statbuf;

	if (fstat(fileno(fp), &statbuf) < 0) {
		USER_MESSAGE("fstat failed!");
		beep();
		return;
	}

	if (!(ex = (struct external_window *)
	    calloc(sizeof(struct external_window), 1))) {
		USER_MESSAGE("malloc failed!");
		beep();
		return;
	}

	if (!(ex->data = (gchar *)
	    calloc(sizeof(gchar), statbuf.st_size + MESSAGE_SIZE))) {
		free(ex);
		USER_MESSAGE("malloc failed!");
		beep();
		return;
	}

	ex->top = gtk_window_new(GTK_WINDOW_TOPLEVEL);
	gtk_window_set_title(GTK_WINDOW(ex->top), header ? 
		header : "USEX");
	gtk_window_set_position(GTK_WINDOW(ex->top), GTK_WIN_POS_MOUSE);
	gtk_signal_connect(GTK_OBJECT(ex->top), "destroy",
		GTK_SIGNAL_FUNC(external_window_destroy), (gpointer)(ex));

	ex->frame = gtk_frame_new(NULL);
	gtk_frame_set_shadow_type(GTK_FRAME(ex->frame), GTK_SHADOW_NONE);
	gtk_container_set_border_width(GTK_CONTAINER (ex->frame), 2);

	ex->text = gtk_label_new("");
	gtk_label_set_justify(GTK_LABEL(ex->text), GTK_JUSTIFY_LEFT);
	gtk_mgr_set_font(ex->text, Shm->wmd->fixed);
        gtk_misc_set_alignment(GTK_MISC(ex->text), 0.0f, 0.0f);
	
	for (lc = cols = 0; fgets(buf, MESSAGE_SIZE, fp); lc++) {
		if (strlen(buf) > cols)
			cols = strlen(buf);
		strcat(ex->data, buf); 
	}

	ht = gdk_text_height(Shm->wmd->fixed, "X", 1);
	wid = gdk_text_width(Shm->wmd->fixed, "X", 1);
	cols = MAX(COLS+3, cols);
	gtk_window_set_default_size(GTK_WINDOW(ex->top), cols*wid, 
		MIN(lc * (ht+6), 480)); 

	gtk_label_set_text(GTK_LABEL(ex->text), ex->data);
	gtk_container_add(GTK_CONTAINER(ex->frame), ex->text);

        ex->scroll = gtk_scrolled_window_new(GTK_ADJUSTMENT 
                (gtk_adjustment_new(0,0,0,0,0,0)),
                GTK_ADJUSTMENT(gtk_adjustment_new(0,0,0,0,0,0)));
 
        gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(ex->scroll),
                GTK_POLICY_AUTOMATIC,
                GTK_POLICY_AUTOMATIC);

        gtk_scrolled_window_add_with_viewport(GTK_SCROLLED_WINDOW(ex->scroll),
                ex->frame);

	gtk_container_add(GTK_CONTAINER(ex->top), ex->scroll);
 
        gtk_widget_show(ex->scroll);
	gtk_widget_show(ex->text);
	gtk_widget_show(ex->frame);
	gtk_widget_show(ex->top);
}

/*
 *  Window specific function.
 */
void
gtk_mgr_specific(gchar *args)
{
        gint i, argc;
        gchar *p1, *argv[MAX_ARGV];
        gchar argbuf[STRINGSIZE];

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
                if (streq(argv[i], "track")) 
			Shm->wmd->flags |= TRACK_WIDGETS;
        }

}

/*
 *  Initialize, and then choreograph, the vmem dance routine.
 */
struct vmem_dance_widget {
	GtkWidget *current;
	GtkWidget *vwid[GTK_DANCE_STEPS];
};
	
void
gtk_mgr_vmem_dance(int id, int index)
{
	register gint i;
	PROC_TABLE *tbl;
	struct vmem_dance_widget *vp;

	tbl = &Shm->ptbl[id];

	switch (index) 
	{
	case -1:
		if ((tbl->dance_widget = (void *)malloc
		    (sizeof(struct vmem_dance_widget))) == NULL)
			return;

		vp = (struct vmem_dance_widget *)tbl->dance_widget;
		for (i = 0; i < GTK_DANCE_STEPS; i++) {
			vp->vwid[i] = build_picwidget(cog_array[i], TRUE);
		}
		vp->current = NULL;
		break;

	case -2:
		vp = (struct vmem_dance_widget *)tbl->dance_widget;
		if (vp->current) {
			gtk_container_remove(GTK_CONTAINER
                                (Shm->wmd->test_data[id].pass_frame),
                                vp->current);
		}

		vp->current = NULL;
		break;

	default:
		vp = (struct vmem_dance_widget *)tbl->dance_widget;
		if (vp->current) {
			gtk_container_remove(GTK_CONTAINER
				(Shm->wmd->test_data[id].pass_frame),
				vp->current);
		}

		vp->current = vp->vwid[index];
		gtk_container_add(GTK_CONTAINER
			(Shm->wmd->test_data[id].pass_frame), 
			vp->current);
		break;
	}
}
