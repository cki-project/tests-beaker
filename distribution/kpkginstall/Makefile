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
# Author: Artem Savkov <asavkov@redhat.com>

TOPLEVEL_NAMESPACE=distribution
PACKAGE_NAME=kpkginstall

export TESTVERSION=1.0
export TEST=/$(TOPLEVEL_NAMESPACE)/$(PACKAGE_NAME)

BUILT_FILES=
FILES=$(METADATA) runtest.sh Makefile

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	chmod a+x runtest.sh

clean:
	rm -f *~ $(BUILT_FILES)

# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

$(METADATA): Makefile
	@echo "Owner:           Artem Savkov <asavkov@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Description:     Install kernel from a tarball" >> $(METADATA)
	@echo "RunFor:          $(TOPLEVEL_NAMESPACE)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPL" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Requires:        make curl grubby tar binutils yum-utils" >> $(METADATA)
	@echo "repoRequires:    cki_lib" >> $(METADATA)
