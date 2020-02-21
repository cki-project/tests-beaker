# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc.
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

export TEST        := rt-tests/rt_migrate_test
export TESTVERSION := 1.0

.PHONY: build run clean

FILES := $(METADATA) runtest.sh Makefile

build:
	chmod +x ./runtest.sh

run: $(FILES) build
	./runtest.sh

clean:
	rm -f $(METADATA)

# Include a global make rules file
# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

$(METADATA): Makefile
	touch $(METADATA)
	@echo "Owner:		Steven Rostedt <srostedt@redhat.com>" > $(METADATA)
	@echo "Name:		$(TEST)"	>> $(METADATA)
	@echo "Path:		$(TEST_DIR)"	>> $(METADATA)
	@echo "TestVersion:	$(TESTVERSION)"	>> $(METADATA)
	@echo "License:		GPLv2"		>> $(METADATA)
	@echo "Description:	Test to verify CPUs should be running the highest\
			        possible priority task that it can run." >> $(METADATA)
	@echo "Architectures:   x86_64" >>$(METADATA)
	@echo "repoRequires:	rt-tests/include" >> $(METADATA)

	rhts-lint $(METADATA)
