# Copyright (c) 2014 Red Hat, Inc. All rights reserved. This copyrighted material
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
# Author: Shuang Li <shuali@redhat.com>

# The toplevel namespace within which the test lives.
# FIXME: You will need to change this:
TOPLEVEL_NAMESPACE=kernel

# The name of the package under test:
# FIXME: you wil need to change this:
PACKAGE_NAME=kernel

# The path of the test below the package:
# FIXME: you wil need to change this:
RELATIVE_PATH=networking/firewall/000infralib

# Version of the Test. Used with make tag.
export TESTVERSION=0.1

# The combined namespace of the test.
export TEST=/$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)


# A phony target is one that is not really the name of a file.
# It is just a name for some commands to be executed when you
# make an explicit request. There are two reasons to use a
# phony target: to avoid a conflict with a file of the same
# name, and to improve performance.
.PHONY: all install download clean

# executables to be built should be added here, they will be generated on the system under test.
BUILT_FILES=runtest

# data files, .c files, scripts anything needed to either compile the test and/or run it.
FILES=$(METADATA) runtest.sh Makefile PURPOSE env.sh include.sh src/

run: $(FILES) build
	./runtest

build: $(BUILT_FILES)

runtest: runtest.sh
	cp $< $@ && chmod +x $@

clean:
	rm -f *~ *.rpm $(BUILT_FILES)

# You may need to add other targets e.g. to build executables from source code
# Add them here:


# Include Common Makefile
include /usr/share/rhts/lib/rhts-make.include

# Generate the testinfo.desc here:
$(METADATA): Makefile
	@touch $(METADATA)
# Change to the test owner's name
	@echo "Owner:        Shuang Li <shuali@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)" >> $(METADATA)
	@echo "Path:         $(TEST_DIR)" >> $(METADATA)
	@echo "License:      GPLv2" >> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)" >> $(METADATA)
	@echo "Description:  firewall/000infralib" >> $(METADATA)
	@echo "RunFor:       $(PACKAGE_NAME)" >> $(METADATA)
# add any other packages for which your test ought to run here
	@echo "Requires:     $(PACKAGE_NAME)" >> $(METADATA)
# add any other requirements for the script to run here
	@echo "RhtsRequires: beakerlib" >> $(METADATA)
	@echo "RhtsRequires: beakerlib-redhat" >> $(METADATA)
	@echo "RepoRequires: networking/common" >> $(METADATA)

# You may need other fields here; see the documentation
	rhts-lint $(METADATA)
