# Copyright (c) 2015 Red Hat, Inc. All rights reserved. This copyrighted material 
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Jianlin Shi<jishi@redhat.com>

TOPLEVEL_NAMESPACE=kernel

PACKAGE_NAME=kernel

RELATIVE_PATH=networking/route/pmtu

# Version of the Test. Used with make tag.
export TESTVERSION=1.0

# The combined namespace of the test.
export TEST=/$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

.PHONY: all install download clean

# executables to be built should be added here, they will be generated on the system under test.
BUILT_FILES= 

# data files, .c files, scripts anything needed to either compile the test and/or run it.
FILES=$(METADATA) runtest.sh Makefile PURPOSE  *.sh func common patch

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	chmod a+x ./runtest.sh

clean:
	rm -f *~ *.rpm $(BUILT_FILES)

# You may need to add other targets e.g. to build executables from source code
# Add them here:


# Include Common Makefile
# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

# Generate the testinfo.desc here:
$(METADATA): Makefile
	@touch $(METADATA)
	@echo "Owner:        Jianlin Shi<jishi@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)" >> $(METADATA)
	@echo "Path:         $(TEST_DIR)"	>> $(METADATA)
	@echo "License:      GPL" >> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"	>> $(METADATA)
	@echo "Description:  pmtu tests">> $(METADATA)
	@echo "RunFor:       $(PACKAGE_NAME)" >> $(METADATA) 
# add any other packages for which your test ought to run here
	@echo "Requires:     $(PACKAGE_NAME)" >> $(METADATA)
	@echo "Requires:     net-tools" >> $(METADATA)
	@echo "Requires:     net-tools" >> $(METADATA)
	@echo "Requires:     tcpdump" >> $(METADATA)
	@echo "Requires:     nmap" >> $(METADATA)
	@echo "Requires:     ethtool" >> $(METADATA)
	@echo "Requires:     iproute" >> $(METADATA)
	@echo "Requires:     nc nmap-ncat socat" >> $(METADATA) # for nc
	@echo "Requires:     libtool" >> $(METADATA)    # for lksctp-tools
	@echo "Requires:     bind-utils" >> $(METADATA) # for dig
	@echo "Requires:     bridge-utils" >> $(METADATA)       # for brctl
	@echo "Requires:     libteam" >> $(METADATA)
	@echo "Requires:     teamd" >> $(METADATA)
	@echo "Requires:     traceroute" >> $(METADATA)
	@echo "Requires:     expect pexpect python3-pexpect" >> $(METADATA)
	@echo "Requires:     bc wget bzip2 gcc" >> $(METADATA)
	@echo "Requires:     git patch rsync" >> $(METADATA)
	@echo "Requires:     texinfo" >> $(METADATA)
	@echo "Requires:     python3-lxml" >> $(METADATA)
	@echo "RhtsRequires: beakerlib-redhat" >> $(METADATA)
	@echo "RhtsRequires: kernel-kernel-networking-common" >> $(METADATA)
	@echo "RhtsRequires: library(kernel/network)" >> $(METADATA)
	@echo "repoRequires: cki_lib" >> $(METADATA)
