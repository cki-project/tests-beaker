# Copyright (c) 2011 Red Hat, Inc. All rights reserved. This copyrighted material 
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
# Author: Hushan Jia <hjia@redhat.com>

TOPLEVEL_NAMESPACE=kernel

PACKAGE_NAME=kernel

RELATIVE_PATH=networking/common

# Version of the Test. Used with make tag.
export TESTVERSION=1.1

# The combined namespace of the test.
export TEST=/$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

.PHONY: all install download clean

# executables to be built should be added here, they will be generated on the system under test.
BUILT_FILES=

# data files, .c files, scripts anything needed to either compile the test and/or run it.
FILES=$(METADATA) *.sh Makefile PURPOSE src/ tools/ patch/ keys/ vm/ lib/

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	chmod a+x ./runtest.sh

clean:
	rm -f *~ *.rpm $(BUILT_FILES)

# You may need to add other targets e.g. to build executables from source code
# Add them here:


# Include Common Makefile
include /usr/share/rhts/lib/rhts-make.include

# Generate the testinfo.desc here:
$(METADATA): Makefile
	@touch $(METADATA)
	@echo "Owner:        Hushan Jia <hjia@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)" >> $(METADATA)
	@echo "Path:         $(TEST_DIR)"	>> $(METADATA)
	@echo "License:      GPL" >> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"	>> $(METADATA)
	@echo "Description:  common routines for networking tests">> $(METADATA)
	@echo "RunFor:       $(PACKAGE_NAME)" >> $(METADATA)
# add any other packages for which your test ought to run here
	@echo "RhtsRequires: beakerlib-redhat" >> $(METADATA)
	@echo "Requires:     net-tools" >> $(METADATA)
	@echo "Requires:     iproute" >> $(METADATA)
	@echo "Requires:     tcpdump" >> $(METADATA)
	@echo "Requires:     nmap" >> $(METADATA)
	@echo "Requires:     ethtool" >> $(METADATA)
	@echo "Requires:     iproute" >> $(METADATA)
	@echo "Requires:     nc nmap-ncat socat" >> $(METADATA) # for nc
	@echo "Requires:     libtool" >> $(METADATA)	# for lksctp-tools
	@echo "Requires:     bind-utils" >> $(METADATA)	# for dig
	@echo "Requires:     bridge-utils" >> $(METADATA)	# for brctl
	@echo "Requires:     libteam" >> $(METADATA)
	@echo "Requires:     teamd" >> $(METADATA)
	@echo "Requires:     traceroute" >> $(METADATA)
	@echo "Requires:     expect pexpect python3-pexpect" >> $(METADATA)
	@echo "Requires:     bc wget bzip2 gcc" >> $(METADATA)
	@echo "Requires:     git patch rsync" >> $(METADATA)
# add any other requirements for the script to run here

# You may need other fields here; see the documentation
	rhts-lint $(METADATA)
