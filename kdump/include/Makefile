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

export TEST        := kdump/include
export TESTVERSION := 1.0

# Include Common Makefile
# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

.PHONY: build clean run

# All files you want bundled into your rpm.
FILES := $(METADATA) Makefile PURPOSE kdump.sh lib.sh

build:
	chmod a+x ./runtest.sh

clean:
	rm -f $(METADATA)

run: $(FILES) build
	./runtest.sh

$(METADATA):
	touch $(METADATA)
	@echo "Name:         $(TEST)"                            > $(METADATA)
	@echo "Path:         $(TEST_DIR)"                        >>$(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"                     >>$(METADATA)
	@echo "License:      GPLv3"                              >>$(METADATA)
	@echo "repoRequires: cki_lib"                            >> $(METADATA)
	@echo "Owner:        Kdump QE <kdump-qe-list@redhat.com>"      >>$(METADATA)
	@echo "Description:  kdump test library" >>$(METADATA)
