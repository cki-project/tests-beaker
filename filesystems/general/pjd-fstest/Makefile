# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /kernel/filesystems/general/pjd-fstest
#   Description: Tests POSIX features of file system
#   Author: Zorro Lang <zlang@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019, Inc. All rights reserved.
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

export TEST=/kernel/filesystems/general/pjd-fstest
export TESTVERSION=1.1

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE README.md

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	chmod a+x runtest.sh

clean:
	rm -f *~ $(BUILT_FILES)


include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Zorro Lang <zlang@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     Tests POSIX features of file system" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        1h" >> $(METADATA)
	@echo "RunFor:          filesystems" >> $(METADATA)
	@echo "Requires:        filesystems" >> $(METADATA)
	@echo "Requires:        library(kernel/fs)" >> $(METADATA)
	@echo "Requires:        perl-Test-Harness" >> $(METADATA)
	@echo "Requires:        libacl-devel" >> $(METADATA)
	@echo "Requires:        perl" >> $(METADATA)
	@echo "Requires:        xfsprogs" >> $(METADATA)
	@echo "Requires:        e2fsprogs" >> $(METADATA)
	@echo "Requires:        e4fsprogs" >> $(METADATA)
	@echo "Requires:        acl" >> $(METADATA)
	@echo "Requires:        libacl" >> $(METADATA)
	@echo "Requires:        libacl-devel" >> $(METADATA)
	@echo "Requires:        redhat-lsb-core gcc make wget git" >> $(METADATA)
	@echo "Requires:        beakerlib python3-lxml " >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)

	rhts-lint $(METADATA)
