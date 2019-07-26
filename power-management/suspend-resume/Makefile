# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 
# Include a global make rules file
include /usr/share/rhts/lib/rhts-make.include

# The name of the package under test
PACKAGE_NAME=kernel

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=/$(PACKAGE_NAME)

# The version of the test rpm that gets
#  created / submitted
export TESTVERSION=1.0

# The path of the test below the package
RELATIVE_PATH=power-management/suspend-resume

# The relative path name to the test 
export TEST=$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

# All files you want bundled into your rpm
FILES=$(METADATA) Makefile runtest.sh time.c PURPOSE README.md

BUILT_FILES= runtest.sh

clean:
	rm -f *~ $(METADATA) $(TESTS)
	rm -rf  rh-tests-kernel*.rpm

build: $(BUILT_FILES)
	chmod a+x ./runtest.sh
	gcc -o time time.c

run:	$(FILES) build
	./runtest.sh

$(METADATA): Makefile
	touch $(METADATA)
	@echo "Name:		$(TEST)"	> $(METADATA)
	@echo "Description:	"Checking the boottime after the system suspend >> $(METADATA)
	@echo "Path:		$(TEST_DIR)"	>> $(METADATA)
	@echo "TestTime:	240m"		>> $(METADATA)
	@echo "TestVersion:	$(TESTVERSION)"	>> $(METADATA)
	@echo "Destructive:	no"		>> $(METADATA)
	@echo "Confidential:	no"		>> $(METADATA)
	@echo "Priority:	Normal"		>> $(METADATA)
	@echo "Requires:	kernel-devel"	>> $(METADATA)
	@echo "Requires:	gcc"		>> $(METADATA)
	@echo "Requires:	git"		>> $(METADATA)
	@echo "Requires:	make"		>> $(METADATA)
	@echo "Requires:	autoconf"       >> $(METADATA)
	@echo "Requires:	automake" 	 >> $(METADATA)
	@echo "Requires:	gettext"	>> $(METADATA)
	@echo "Requires:	wget"		>> $(METADATA)
	@echo "Requires:	pciutils"	>> $(METADATA)
	@echo "Requires:	virt-what"	>> $(METADATA)
	@echo "RunFor:		kernel" >> $(METADATA)
	@echo "License:		GPLv2" 	>> $(METADATA)
	@echo "Owner:		Victor Ruiz <rvr@redhat.com>"	>> $(METADATA)
