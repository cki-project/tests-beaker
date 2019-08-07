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

export TEST=/kernel/cpu/driver
export TESTVERSION=1.0

BUILT_FILES= runtest

FILES=$(METADATA) runtest.sh Makefile README.md

.PHONY: all install download clean

run: $(FILES) build
	./runtest

runtest: runtest.sh
	cp $< $@ && chmod +x $@

build: $(BUILT_FILES)

clean:

clobber: clean
	rm -f *~ $(BUILT_FILES)
cl: clobber

include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:        David Arcari <darcari@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)" >> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)" >> $(METADATA)
	@echo "Path:         $(TEST_DIR)" >> $(METADATA)
	@echo "Description:  cpu frequency driver testing" >> $(METADATA)
	@echo "Type:         Functional" >> $(METADATA)
	@echo "TestTime:     30m" >> $(METADATA)
	@echo "RunFor:       kernel" >> $(METADATA)
	@echo "Requires:     msr-tools" >> $(METADATA)
	@echo "Requires:     virt-what" >> $(METADATA)
	@echo "Requires:     git" >> $(METADATA)
	@echo "Requires:     autoconf" >> $(METADATA)
	@echo "Requires:     automake" >> $(METADATA)
	@echo "Requires:     make" >> $(METADATA)
	@echo "Requires:     gcc" >> $(METADATA)
	@echo "Requires:     bc" >> $(METADATA)
	@echo "Requires:     python2-lxml" >> $(METADATA)
	@echo "Requires:     python3-lxml" >> $(METADATA)
	@echo "RepoRequires: cpu/common" >> $(METADATA)
	@echo "Priority:     Normal" >> $(METADATA)
	@echo "License:      GPLv2 or above" >> $(METADATA)
	@echo "Confidential: no" >> $(METADATA)
	@echo "Destructive:  no" >> $(METADATA)

	rhts-lint $(METADATA)
