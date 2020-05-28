# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2020 Red Hat, Inc.

TOPLEVEL_NAMESPACE=/kernel
PACKAGE_NAME=distribution/ltp
RELATIVE_PATH=lite

export TESTVERSION=1.3
export TEST=$(TOPLEVEL_NAMESPACE)/$(PACKAGE_NAME)/$(RELATIVE_PATH)

# A phony target is one that is not really the name of a file.
# It is just a name for some commands to be executed when you
# make an explicit request. There are two reasons to use a
# phony target: to avoid a conflict with a file of the same
# name, and to improve performance.
.PHONY: all install download clean

# data files, .c files, scripts anything needed to either compile the test and/or run it.
FILES=$(METADATA) runtest.sh Makefile PURPOSE hugetlb.inc

run: build
	./runtest.sh

build: $(BUILT_FILES)
	chmod a+x ./runtest.sh

clean:
	rm -rf *~ *.rpm ltp/ $(BUILT_FILES)

# Include Common Makefile
# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

# Generate the testinfo.desc here:
$(METADATA): Makefile
	@touch $(METADATA)
	@echo "Owner:        Red Hat MM-QE <mm-qe@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)" >> $(METADATA)
	@echo "Path:         $(TEST_DIR)"	>> $(METADATA)
	@echo "License:      GPLv2" >> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"	>> $(METADATA)
	@echo "Description:  test ltp patches using git version ">> $(METADATA)
	@echo "RunFor:       kernel glibc" >> $(METADATA)  
	@echo "Requires:     $(PACKAGE_NAME)" >> $(METADATA)  
	@echo "Requires:     git autoconf automake"      >> $(METADATA)
	@echo "Requires:     procmail rsyslog sysklogd ntpdate util-linux util-linux-ng redhat-lsb bc" >> $(METADATA)
	@echo "Requires:     kernel-headers" >> $(METADATA)
	@echo "Requires:     kernel-devel libaio-devel libcap-devel numactl-devel libattr-devel" >> $(METADATA)
	@echo "Requires:     e2fsprogs e4fsprogs xfsprogs btrfs-progs" >> $(METADATA)
	@echo "Requires:     mkisofs genisoimage bzip2" >> $(METADATA)
	@echo "Requires:     @development" >> $(METADATA)
	@echo "Requires:     numactl numactl-devel" >> $(METADATA)
	@echo "Requires:     ethtool" >> $(METADATA)
	@echo "repoRequires: distribution/ltp-upstream/include" >> $(METADATA)
	@echo "repoRequires: cki_lib" >> $(METADATA)
	@echo "Environment:  AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Releases:     RHELServer5 RHEL6 RHEL7 RHEL8" >> $(METADATA)
	@echo "Destructive:  no" >> $(METADATA)
	@echo "Confidential: no" >> $(METADATA)
	@echo "Priority:     Normal" >>$(METADATA)
