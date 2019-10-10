#
# Copyright (c) 2019 Red Hat, Inc. All rights reserved.
#
# This copyrighted material is made available to anyone wishing
# to use, modify, copy, or redistribute it subject to the terms
# and conditions of the GNU General Public License version 2.
#
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
#

# The name of the package under test
PACKAGE_NAME=kernel

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=$(PACKAGE_NAME)

# The path of the test below the package
RELATIVE_PATH=storage/blk

# The relative path name to the test
export TEST=$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

# The redhat rpm test package version
export TESTVERSION=1.0

# The upsteam location of tests
LOOKASIDE=https://github.com/osandov/blktests.git

TARGETS	= blktests \
	  runtest

blktests:
	git clone $(LOOKASIDE)
	cd $@ && make

runtest: runtest.sh
	cp $< $@ && chmod +x $@

build: $(TARGETS)

run: build
	./runtest

clean:
	rm -f $(METADATA)
	rm -f runtest

clobber: clean
	rm -rf blktests

# Include a global make rules file
include /usr/share/rhts/lib/rhts-make.include

$(METADATA):
	@touch $(METADATA)
	@echo "Owner:        Yi Zhang <yi.zhang@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)"           >> $(METADATA)
	@echo "License:      GPLv2 or above"    >> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"    >> $(METADATA)
	@echo "Description:  blktests"          >> $(METADATA)
	@echo "Requires:     fio"		>> $(METADATA)
	@echo "Requires:     blktrace"		>> $(METADATA)
	@echo "Requires:     gcc"		>> $(METADATA)
	@echo "Requires:     gcc-c++"		>> $(METADATA)
	@echo "Requires:     git"		>> $(METADATA)
	@echo "Requires:     nvme-cli"		>> $(METADATA)
	@echo "RunFor:       $(PACKAGE_NAME)"   >> $(METADATA)
	rhts-lint $(METADATA)
