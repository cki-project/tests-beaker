# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /kernel/storage/Sanity/dt_stress_panic
#   Description: This test verifies that kdump is active, installs dt if necessary, then generates I/O with dt. While generating I/O, it triggers a panic. It will then verify that the server reboots properly and that a crash dump was generated.
#   Author: Marco Patalano <mpatalan@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=tests-beaker

# # The name of the package under test:
PACKAGE_NAME=storage
#
# # The path of the test below the package:
RELATIVE_PATH=hw_raid
#
# # Version of the Test. Used with make tag.
export TESTVERSION=0.1
#
# # The combined namespace of the test.
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
	@echo "Description:     This test will generate I/O using FIO at the device level and trigger a panic as well as kexec boot." >> $(METADATA)
	@echo "License:		GPL v3" >> $(METADATA)
	@echo "RunFor:		$(PACKAGE_NAME)" >> $(METADATA)
	@echo "Requires:	$(PACKAGE_NAME)" >> $(METADATA)
	@echo "RepoRequires:    cki_lib" >> $(METADATA)
	@echo "RhtsRequires:	hw_raid" >> $(METADATA)

	rhts-lint $(METADATA)
