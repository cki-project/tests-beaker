# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Ensure that debuginfo vmlinux comes with .debug* sections
#   Author: Čestmír Kalina <ckalina@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat All rights reserved.
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

export TEST=distribution/kernel-debuginfo
export TESTVERSION=1.0

FILES=$(METADATA) runtest.sh Makefile

run: $(FILES) build
	$(foreach v, $(.VARIABLES), $(info $(v) = $($(v))))
	./runtest.sh

build:
	test -x runtest.sh || chmod a+x runtest.sh

# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

$(METADATA): Makefile
	@echo "Owner:           Čestmír Kalina <ckalina@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            /tmp/" >> $(METADATA)
	@echo "Description:     Ensure that debuginfo vmlinux comes with .debug* sections." >> $(METADATA)
	@echo "Type:            Misc" >> $(METADATA)
	@echo "RunFor:          kernel" >> $(METADATA)
	@echo "Requires:        kernel" >> $(METADATA)
	@echo "Requires:        kmod" >> $(METADATA)
	@echo "Requires:        grep" >> $(METADATA)
	@echo "Requires:        coreutils" >> $(METADATA)
	@echo "Requires:        rpm" >> $(METADATA)
	@echo "Requires:        sed" >> $(METADATA)
	@echo "Requires:        findutils" >> $(METADATA)
	@echo "Requires:        bash" >> $(METADATA)
	@echo "Requires:        cpio" >> $(METADATA)
	@echo "Requires:        file" >> $(METADATA)
	@echo "Requires:        gawk" >> $(METADATA)
	@echo "Requires:        binutils" >> $(METADATA)
	@echo "Requires:        yum-utils" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "repoRequires:    legacy/shared" >> $(METADATA)
	@echo "repoRequires:    cki_lib" >> $(METADATA)
