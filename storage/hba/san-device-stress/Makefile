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
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=tests-beaker

# The name of the package under test:
PACKAGE_NAME=storage
#
# The path of the test below the package:
RELATIVE_PATH=hba
#
# Version of the Test. Used with make tag.
export TESTVERSION=0.1
#
# The combined namespace of the test.
export TEST=/$(TOPLEVEL_NAMESPACE)/$(PACKAGE_NAME)/$(RELATIVE_PATH)

BUILT_FILES=

FILES=$(METADATA) runtest.sh main.sh Makefile PURPOSE

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	chmod a+x ./runtest.sh
	chmod a+x ./main.sh
clean:
	rm -f *~ *.rpm $(BUILT_FILES)
include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Marco Patalano <mpatalan@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     This test will generate I/O using FIO at the device level." >> $(METADATA)
	@echo "License:		GPL v3" >> $(METADATA)
	@echo "TestTime:	1h" >> $(METADATA)
	@echo "RunFor:		$(PACKAGE_NAME)" >> $(METADATA)
	@echo "Requires:        python2-lxml" >> $(METADATA)
	@echo "Requires:        python3-lxml" >> $(METADATA)
	@echo "Requires:        fio" >> $(METADATA)
	@echo "Requires:        libaio-devel" >> $(METADATA)
	@echo "Requires:        zlib-devel" >> $(METADATA)
	@echo "Requires:        gcc" >> $(METADATA)
	@echo "Requires:        git" >> $(METADATA)
	@echo "RhtsRequires:	hba" >> $(METADATA)

	rhts-lint $(METADATA)

