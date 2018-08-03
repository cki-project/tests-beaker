/*
 * Copyright (C) 2012 Linux Test Project, Inc.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of version 2 of the GNU General Public
 * License as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it would be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * Further, this software is distributed without any warranty that it
 * is free of the rightful claim of any third person regarding
 * infringement or the like.  Any license provided herein, whether
 * implied or otherwise, applies only to this software file.  Patent
 * licenses, if any, provided herein do not apply to combinations of
 * this program with other software, or any other product whatsoever.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
 * 02110-1301, USA.
 */

/*
 * functional test for readahead() syscall
 *
 * This test is measuring effects of readahead syscall.
 * It mmaps/reads a test file with and without prior call to readahead.
 *
 */
#define _GNU_SOURCE
#include <sys/types.h>
#include <sys/syscall.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/time.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include "config.h"
#include "test.h"
#include "usctest.h"
#include "safe_macros.h"
#include "linux_syscall_numbers.h"

char *TCID = "readahead02";
int  TST_TOTAL = 1;

#if defined(__NR_readahead)
static char testfile[] = "testfile";
static long testfile_size = 64*1024*1024;
static int opt_fsize;
static char *opt_fsizestr;
static int pagesize;

option_t options[] = {
	{ "s:", &opt_fsize, &opt_fsizestr},
	{ NULL, NULL, NULL }
};

static void setup(char *argv[]);
static void cleanup(void);

void help()
{
	printf("  -s x    testfile size (default 64MB)\n");
}

static int check_ret(long expected_ret)
{
	if (expected_ret == TEST_RETURN) {
		tst_resm(TPASS, "expected ret success - "
			"returned value = %ld", TEST_RETURN);
		return 0;
	}
	else
		tst_resm(TFAIL, "unexpected failure - "
			"returned value = %ld, expected: %ld",
			TEST_RETURN, expected_ret);
	return 1;
}

static int has_proc_io()
{
	char fname[128];
	struct stat buf;
	int ret;

	sprintf(fname, "/proc/%u/io", getpid());
	ret = stat(fname, &buf);
	if (ret == -1) {
		if (errno == ENOENT)
			return 0;
		else
			tst_brkm(TBROK|TERRNO, cleanup, "stat failed");
	}
	return 1;
}

static void drop_caches()
{
	int ret;
	char *drop_caches = "/proc/sys/vm/drop_caches";
	FILE *f;

	f = fopen(drop_caches, "w");
	if (f) {
		ret = fprintf(f, "1");
		fclose(f);
		if (ret < 1)
			tst_brkm(TBROK, cleanup, "Failed to drop caches");
	} else
		tst_brkm(TBROK, cleanup, "Failed to open: %s", drop_caches);
}

static long get_bytes_read()
{
	FILE *f;
	long bytes_read = -1;
	int ret;
	char fname[128];
	char *line = NULL;
	size_t linelen;

	sprintf(fname, "/proc/%u/io", getpid());
	f = fopen(fname, "r");
	if (f) {
		do {
			ret = getline(&line, &linelen, f);
			if (sscanf(line, "read_bytes: %ld", &bytes_read) == 1)
				break;
		} while (ret != -1);
		fclose(f);
	}
	return bytes_read;
}

static void create_testfile()
{
	FILE *f;
	char *tmp;
	int i;

	tst_resm(TINFO, "creating test file of size: %ld", testfile_size);
	tmp = SAFE_MALLOC(cleanup, pagesize);

	/* round to page size */
	testfile_size = testfile_size & ~((long)pagesize - 1);

	f = fopen(testfile, "w");
	if (!f)
		tst_brkm(TBROK|TERRNO, cleanup, "Failed to create %s",
			testfile);

	for (i = 0; i < testfile_size; i += pagesize)
		if (fwrite(tmp, pagesize, 1, f) < 1)
			tst_brkm(TBROK, cleanup, "Failed to create %s",
				testfile);
	fflush(f);
	fsync(fileno(f));
	fclose(f);
	free(tmp);
}

/* read_testfile - mmap testfile and read every page.
 * This functions measures how many I/O and time it takes to fully
 * read contents of test file.
 *
 * @do_readahead: call readahead prior to reading file content?
 * @fname: name of file to test
 * @fsize: how many bytes to read/mmap
 * @read_bytes: returns difference of bytes read, parsed from /proc/<pid>/io
 * @usec: returns how many microsecond it took to go over fsize bytes
 */
static void read_testfile(int do_readahead, char *fname, int fsize,
	long *read_bytes, long *usec)
{
	int fd, i;
	long read_bytes_start;
	unsigned char *p, tmp;
	unsigned long time_start_usec, time_end_usec;
	off_t offset;
	struct timeval now;

	fd = open(fname, O_RDONLY);
	if (fd < 0)
		tst_brkm(TBROK|TERRNO, cleanup, "Failed to open %s",
			fname);

	if (do_readahead) {
		TEST(syscall(__NR_readahead, fd, (off64_t)0, (size_t)fsize));
		check_ret(0);

		/* offset of file shouldn't change after readahead */
		offset = lseek(fd, 0, SEEK_CUR);
		if (offset == (off_t) -1)
			tst_brkm(TBROK|TERRNO, cleanup, "lseek failed");
		if (offset == 0)
			tst_resm(TPASS, "offset is still at 0 as expected");
		else
			tst_resm(TFAIL, "offset has changed to: %lu", offset);
	}

	if (gettimeofday(&now, NULL) == -1)
		tst_brkm(TBROK|TERRNO, cleanup, "gettimeofday failed");
	time_start_usec = now.tv_sec * 1000000 + now.tv_usec;
	read_bytes_start = get_bytes_read();

	p = mmap(NULL, fsize, PROT_READ, MAP_SHARED|MAP_POPULATE, fd, 0);
	if (p == MAP_FAILED)
		tst_brkm(TBROK|TERRNO, cleanup, "mmap failed");
	/* 
         * for old kernels, where MAP_POPULATE does not work, touch each page
         */
        tmp = 0;
	for (i = 0; i < fsize; i += pagesize)
		tmp = tmp ^ p[i];
        /* prevent gcc from optimizing out loop above */
	if (tmp != 0)
		tst_brkm(TBROK, NULL, "This line should not be reached");

        if (munmap(p, fsize) == -1)
		tst_brkm(TBROK|TERRNO, cleanup, "munmap failed");

	*read_bytes = get_bytes_read() - read_bytes_start;
	if (gettimeofday(&now, NULL) == -1)
		tst_brkm(TBROK|TERRNO, cleanup, "gettimeofday failed");
	time_end_usec = now.tv_sec * 1000000 + now.tv_usec;
	*usec = time_end_usec - time_start_usec;

	if (close(fd) == -1)
		tst_brkm(TBROK|TERRNO, cleanup, "close failed");
}

static void test_readahead()
{
	long read_bytes, read_bytes_ra;
	long usec, usec_ra;

	tst_resm(TINFO, "read_testfile(0)");
	drop_caches();
	read_testfile(0, testfile, testfile_size, &read_bytes, &usec);

	tst_resm(TINFO, "read_testfile(1)");
	drop_caches();
	read_testfile(1, testfile, testfile_size, &read_bytes_ra, &usec_ra);

	tst_resm(TINFO, "read_testfile(0) took: %ld usec", usec);
	tst_resm(TINFO, "read_testfile(1) took: %ld usec", usec_ra);
	if (has_proc_io()) {
		tst_resm(TINFO, "read_testfile(0) read: %ld bytes",
				read_bytes);
		tst_resm(TINFO, "read_testfile(1) read: %ld bytes",
				read_bytes_ra);
		/* 
		 * read_bytes_ra should be very close to 0,
		 * but this can not be guaranteed as it depends
		 * on available RAM.
		 */
		if (read_bytes_ra < read_bytes)
			tst_resm(TPASS, "readahead saved us some I/O");
		else
			tst_resm(TFAIL, "readahead failed to save any I/O");
	} else
		tst_resm(TCONF, "Your system doesn't have /proc/pid/io,"
			" unable to determine read bytes during test");

}

int main(int argc, char *argv[])
{
	char *msg;
	int lc;

	if ((msg = parse_opts(argc, argv, options, help)) != NULL)
		tst_brkm(TBROK, NULL, "OPTION PARSING ERROR - %s", msg);

	if (opt_fsize)
		testfile_size = atoi(opt_fsizestr);

	setup(argv);
	for (lc = 0; TEST_LOOPING(lc); lc++) {
		Tst_count = 0;
		test_readahead();
	}
	cleanup();
	tst_exit();
}


static void setup(char *argv[])
{
	tst_require_root(NULL);
	tst_tmpdir();
	TEST_PAUSE;
	
	/* check if readahead is supported */
	syscall(__NR_readahead, 0, 0, 0);
	
	pagesize = getpagesize();
	create_testfile();
}

static void cleanup(void)
{
	TEST_CLEANUP;
	unlink(testfile);
	tst_rmdir();
}

#else /* __NR_readahead */
int main(void)
{
	tst_brkm(TCONF, NULL, "System doesn't support __NR_readahead");
}
#endif

