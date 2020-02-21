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

TOPLEVEL_NAMESPACE	= kernel
PACKAGE_NAME		= kernel
RELATIVE_PATH		= networking/vnic/ipvlan/basic

export TEST=/$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)
export TESTVERSION=1.0

BUILT_FILES		= runtest

FILES			= $(METADATA) \
			  Makefile \
			  README.md \
			  PURPOSE \
			  runtest.sh

.PHONY: all install download clean

run: $(FILES) build
	./runtest

runtest: runtest.sh
	cp $< $@ && chmod +x $@

build: $(BUILT_FILES)

clean:
	rm -f *~ $(BUILT_FILES)

# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

$(METADATA): Makefile
	@echo "Owner:        Jianlin Shi<jishi@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)" >> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)" >> $(METADATA)
	@echo "Path:         $(TEST_DIR)" >> $(METADATA)
	@echo "Description:  ipvlan basic">> $(METADATA)
	@echo "License:      GPLv2 or above" >> $(METADATA)
	@echo "Type:         Functional" >> $(METADATA)
	@echo "RunFor:       $(PACKAGE_NAME)" >> $(METADATA)
	@echo "Requires:     $(PACKAGE_NAME)" >> $(METADATA)
	@echo "Requires:     net-tools" >> $(METADATA)
	@echo "repoRequires: networking/common" >> $(METADATA)
	@echo "Priority:     Normal" >> $(METADATA)
	@echo "License:      GPLv2 or above" >> $(METADATA)
	@echo "Confidential: no" >> $(METADATA)
	@echo "Destructive:  no" >> $(METADATA)

	rhts-lint $(METADATA)
