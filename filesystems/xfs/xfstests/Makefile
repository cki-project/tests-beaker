# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /kernel/filesystems/xfs/xfstests
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Author, maintainer and description of the test
AUTHOR=Eric Sandeen <sandeen@redhat.com>
MAINTAINER=Boris Ranto <branto@redhat.com>
DESCRIPTION=The internal wrapper of upstream xfstests test suite.

# The name of the test.
export TEST=/kernel/filesystems/xfs/xfstests

# Version of the test. Used with make tag.
export TESTVERSION=2.4

# data files, .c files, scripts anything needed to either compile the test and/or run it.
FILES=$(METADATA) *.sh PURPOSE LICENCE known_issues Makefile RUNTESTS

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES) $(FILES)
	chmod a+x ./runtest.sh

clean:
	rm -f *~ *.rpm
	rm -f $(METADATA)

# Include Common Makefile
include /usr/share/rhts/lib/rhts-make.include

# Generate the testinfo.desc here:
$(METADATA): Makefile
	@touch $(METADATA)
	@echo "Owner:        $(MAINTAINER)"     > $(METADATA)
	@echo "Name:         $(TEST)"           >> $(METADATA)
	@echo "Path:         $(TEST_DIR)"       >> $(METADATA)
	@echo "License:      GPLv2"             >> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"    >> $(METADATA)
	@echo "Description:  $(DESCRIPTION)"    >> $(METADATA)
	@echo "RunFor:       kernel"            >> $(METADATA)
	@echo "RunFor:       xfsprogs"          >> $(METADATA)
	@echo "RunFor:       xfsdump"           >> $(METADATA)
	@echo "RunFor:       acl"               >> $(METADATA)
	@echo "RunFor:       attr"              >> $(METADATA)
	@echo "Type:         Regression"        >> $(METADATA)
	@echo "Type:         KernelTier2"       >> $(METADATA)
	@echo "Requires:     vdo kmod-kvdo"     >> $(METADATA)
	@echo "Requires:     acl"               >> $(METADATA)
	@echo "Requires:     attr"              >> $(METADATA)
	@echo "Requires:     autoconf"          >> $(METADATA)
	@echo "Requires:     bc"                >> $(METADATA)
	@echo "Requires:     bind-utils"        >> $(METADATA)
	@echo "Requires:     btrfs-progs"       >> $(METADATA)
	@echo "Requires:     e2fsprogs-devel"   >> $(METADATA)
	@echo "Requires:     e4fsprogs"	        >> $(METADATA)
	@echo "Requires:     fio"               >> $(METADATA)
	@echo "Requires:     gcc"               >> $(METADATA)
	@echo "Requires:     gdbm-devel"        >> $(METADATA)
	@echo "Requires:     gettext"           >> $(METADATA)
	@echo "Requires:     gfs2-utils"        >> $(METADATA)
	@echo "Requires:     git"               >> $(METADATA)
	@echo "Requires:     indent"            >> $(METADATA)
	@echo "Requires:     kernel-devel"      >> $(METADATA)
	@echo "Requires:     kernel"            >> $(METADATA)
	@echo "Requires:     libacl-devel"      >> $(METADATA)
	@echo "Requires:     libaio-devel"      >> $(METADATA)
	@echo "Requires:     libattr-devel"     >> $(METADATA)
	@echo "Requires:     libblkid-devel"    >> $(METADATA)
	@echo "Requires:     libcap"            >> $(METADATA)
	@echo "Requires:     libtool"           >> $(METADATA)
	@echo "Requires:     libuuid-devel"     >> $(METADATA)
	@echo "Requires:     librbd1-devel"     >> $(METADATA)
	@echo "Requires:     librdmacm-devel"   >> $(METADATA)
	@echo "Requires:     ncurses-devel"     >> $(METADATA)
	@echo "Requires:     openssl-devel"     >> $(METADATA)
	@echo "Requires:     perl"              >> $(METADATA)
	@echo "Requires:     policycoreutils-python" >> $(METADATA)
	@echo "Requires:     popt-devel"        >> $(METADATA)
	@echo "Requires:     psmisc"            >> $(METADATA)
	@echo "Requires:     pyOpenSSL"         >> $(METADATA)
	@echo "Requires:     python"            >> $(METADATA)
	@echo "Requires:     python2"            >> $(METADATA)
	@echo "Requires:     quota"             >> $(METADATA)
	@echo "Requires:     readline-devel"    >> $(METADATA)
	@echo "Requires:     rpm-build"         >> $(METADATA)
	@echo "Requires:     shadow-utils"      >> $(METADATA)
	@echo "Requires:     wget"              >> $(METADATA)
	@echo "Requires:     xfsdump"           >> $(METADATA)
	@echo "Requires:     xfs-kmod"          >> $(METADATA)
	@echo "Requires:     xfsprogs"          >> $(METADATA)
	@echo "Requires:     xfsprogs-devel"    >> $(METADATA)
	@echo "Requires:     xfsprogs-qa-devel" >> $(METADATA)
	@echo "Requires:     samba samba-client cifs-utils" >> $(METADATA)
	@echo "Requires:     rpcbind nfs-utils" >> $(METADATA)
	@echo "Requires:     lvm2 beakerlib" >> $(METADATA)
	@echo "environment:  FAILUREFILENM=/usr/share/rhts/falsestrings" >> $(METADATA)
	@echo "RhtsRequires: test(/kernel/filesystems/xfs/include)" >> $(METADATA)
	rhts-lint $(METADATA)
#	The include package takes care of all the dependencies
#	Add any other dependencies there (/kernel/filesystems/xfs/include)
