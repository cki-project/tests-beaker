# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /kernel/vm/hugepage/libhugetlbfs
#   Description: Test libhugetlbfs with upstream testsuite
#   Author: Caspar Zhang <czhang@redhat.com>
#   Update: Li Wang <liwan@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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

PACKAGE_NAME=libhugetlbfs
export TEST=/kernel/vm/hugepage/$(PACKAGE_NAME)

PACKAGE_VERSION=2.21
RHEL_VERSION=$(shell grep -q "release [5-7].*" /etc/redhat-release && echo rhel[5-7])
ifeq ($(RHEL_VERSION), rhel[5-7])
	PACKAGE_VERSION=2.18
endif

TARGET=$(PACKAGE_NAME)-$(PACKAGE_VERSION)
TESTVERSION=$(PACKAGE_VERSION)
PATCH_DIR=patches
OS_MAJOR_RELEASE=$(shell grep -Go 'release [0-9]\+' /etc/redhat-release | awk '{print $NF}')
ARCH=$(shell uname -i)

LOOKASIDE=https://github.com/libhugetlbfs/libhugetlbfs/releases/download/

FILES	= $(METADATA) \
	  runtest.sh \
	  Makefile \
	  PURPOSE \
	  KnownIssueList \
	  $(PATCH_DIR) \
	  kvercmp.sh \
	  patch.sh \
	  dependency.sh

.PHONY: all install clean patch build

$(TARGET).tar.gz:
	@echo "------ Download Package ------"
	wget -q $(LOOKASIDE)/$(PACKAGE_VERSION)/$(TARGET).tar.gz

$(TARGET): $(TARGET).tar.gz clean
	@echo "------ Extract Package ------"
	tar xzf $(TARGET).tar.gz

patch: $(TARGET)
	@echo "------ Patch the Testsuite ------"
	@bash patch.sh

runtest: runtest.sh
	cp $< $@
	chmod +x $@

build:
	@echo "------ Build the Testsuite ------"
	@bash dependency.sh
ifneq (,$(filter $(OS_MAJOR_RELEASE)_$(ARCH), 8_aarch64 8_ppc64le 8_s390x))
	#
	# XXX: For RHEL8, add BUILDTYPE=NATIVEONLY to skip 32-bit tests on
	#      64-bit systems
	#
	make -C $(TARGET) BUILDTYPE=NATIVEONLY
	make -C $(TARGET) PREFIX=/usr BUILDTYPE=NATIVEONLY install
else
	make -C $(TARGET)
	make -C $(TARGET) PREFIX=/usr install
endif
	cp -f $(TARGET)/huge_page_setup_helper.py /usr/bin/

testfullbuild: $(TARGET) patch build runtest

run: testfullbuild
	./runtest

clean:
	rm -rf *~ $(TARGET) runtest

# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

$(METADATA): Makefile
	@echo "Owner:           Caspar Zhang <czhang@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     Test libhugetlbfs with upstream testsuite" >> $(METADATA)
	@echo "RunFor:          $(PACKAGE_NAME) $(PACKAGE_NAME)-utils" >> $(METADATA)
	@echo "Requires:        @development" >> $(METADATA)
	@echo "Requires:        wget" >> $(METADATA)
	@echo "Requires:        patch" >> $(METADATA)
	@echo "repoRequires:    cki_lib" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPL-v2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Releases:        RHEL6 RHEL7 RHEL8 RedHatEnterpriseLinuxPegas7" >> $(METADATA)
