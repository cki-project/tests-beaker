#
#ident	"$Id: Makefile,v 1.1 2005/10/25 22:38:34 jmoyer Exp $"
#
# Connectathon Tests for automounting
#
# to make tests, use 'make'
#

include tests.init

#
# CC, CFLAGS and LILBS to be modified through 'tests.init'
#
EXECS	= autoparse mopendir opendir  domount doautomount
INSTALLDIR = ../bin

INCLUDES=test.h

CFLAGS += -D_FILE_OFFSET_BITS=64

CFLAGS += $(USE_MNTTAB)
CFLAGS += $(USE_STATVFS)
CFLAGS += -DMOUNT_TABLE=\"$(MOUNT_TABLE)\"
CFLAGS += -DUSE_TMPFS_SCAFFOLDING=$(USE_TMPFS_SCAFFOLDING)
CFLAGS += -Wno-unknown-pragmas

all: $(EXECS)

subr.o: subr.c $(INCLUDES)

result_filter.o: result_filter.c $(INCLUDES)

opendir: opendir.c $(INCLUDES) subr.o result_filter.o mounttable.o
	$(CC) $(CFLAGS) -o $@ $@.c subr.o result_filter.o mounttable.o $(LIBS)

mopendir: mopendir.c $(INCLUDES) subr.o result_filter.o mounttable.o
	$(CC) $(CFLAGS) -o $@ $@.c subr.o result_filter.o mounttable.o $(LIBS)

autoparse: autoparse.c result_filter.o
	$(CC) $(CFLAGS) -o $@ $@.c result_filter.o

domount: domount.c
	$(CC) $(CFLAGS) -o $@ $@.c
	chown root domount
	chmod u+s domount

doautomount: doautomount.c
	$(CC) $(CFLAGS) -o $@ $@.c
	chown root doautomount
	chmod u+s doautomount

install: $(EXECS)
	cp -p $(EXECS) $(INSTALLDIR)
	chmod +x $(INSTALLDIR)/*

clean:
	rm -f *.o $(EXECS) domount doautomount

