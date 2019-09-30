# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
RHEL_VERSION=$(shell grep -q "release [5-7].*" /etc/redhat-release && echo rhel[5-7])
ifeq ($(RHEL_VERSION), rhel[5-7])
	export TESTVERSION=2.18
else
	export TESTVERSION=2.21
endif
TARGET=$(PACKAGE_NAME)-$(TESTVERSION)
PATCH_DIR=patches

# System Environment, i.e., architecture
ifndef SYSENV
	SYSENV := $(shell uname -i)
endif
PYTHON_VERSION	:=$(shell which python3 &>/dev/null && echo python3)

LOOKASIDE=https://github.com/libhugetlbfs/libhugetlbfs/releases/download/

FILES=$(METADATA) runtest.sh Makefile PURPOSE KnownIssueList $(PATCH_DIR) kvercmp.sh

.PHONY: all install download clean extract patch build

$(TARGET).tar.gz:
	@echo "------ Download Package ------"
	wget -q $(LOOKASIDE)/$(TESTVERSION)/$(TARGET).tar.gz

$(TARGET): $(TARGET).tar.gz clean
	@echo "------ Extract Package ------"
	tar xzf $(TARGET).tar.gz
patch:
	@echo "------ Patch the Testsuite ------"
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/assume-support-rhel6.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/remove-duplicate-cases.patch
ifeq ($(TESTVERSION), 2.18)
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/fix-plt_extrasz-always-returning-0-on-ppc64le.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/map_high_truncate.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/huge_page_setup_helper-do-not-assume-default-huge-pa.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/tests-linkhuge_rw-function-ptr-may-not-refer-to-.tex.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/misalign-make-some-adjustments-for-misalign.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0001-aarch64-fix-page-size-not-properly-computed.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0001-ld.hugetlbfs-arm-arches-fix-page-size-and-text-offse.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0001-Force-text-segment-alignment-to-0x08000000-for-i386-.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0001-ld.hugetlbfs-pick-an-emulation-if-m-is-not-present.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0002-runtests.py-Change-R-to-R-in-elflink_rw_test-functio.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0003-ld.hugetlbfs-pick-an-emulation-if-m-is-not-present.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0004-tests-heapshrink-allocate-enough-to-expand-heap.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0005-ld.hugetlbfs-support-512M-hugepages-on-aarch64.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0001-restrict-is-a-reserved-keyword-in-C99.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0001-testutils-fix-range_is_mapped.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0002-stack_grow_into_huge-don-t-clobber-existing-mappings.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0001-tests-Makefile-HUGELINK_RW_TESTS-not-being-reference.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0001-Defined-task-size-value-to-be-512T-if-it-is-more-tha.patch
endif
ifeq ($(TESTVERSION), 2.21)
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0001-testutils-fix-range_is_mapped.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/0002-stack_grow_into_huge-don-t-clobber-existing-mappings.patch
ifeq ($(PYTHON_VERSION), python3)
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/huge_page_setup_helper-python3-convert.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/run_tests-python3-convert.patch
endif
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/build_flags.patch
	@patch -p1 -d $(TARGET) < $(PATCH_DIR)/hack-task-size-overrun.patch
endif

build:
	@echo "------ Build the Testsuite ------"
	make -C $(TARGET)
	make -C $(TARGET) PREFIX=/usr install
	cp -f $(TARGET)/huge_page_setup_helper.py /usr/bin/
	chmod a+x runtest.sh

testpatch: $(TARGET) patch

testfullbuild: $(TARGET) patch build

run: testfullbuild
	./runtest.sh

clean:
	rm -rf *~ $(TARGET)

include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Caspar Zhang <czhang@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     Test libhugetlbfs with upstream testsuite" >> $(METADATA)
	@echo "RunFor:          $(PACKAGE_NAME) $(PACKAGE_NAME)-utils" >> $(METADATA)
	@echo "Requires:        @development \
		libgcc.i686    glibc-devel.i686    glibc-static.i686 \
		libgcc.x86_64  glibc-devel.x86_64  glibc-static.x86_64 \
		libgcc.ppc     glibc-devel.ppc     glibc-static.ppc \
		libgcc.ppc64   glibc-devel.ppc64   glibc-static.ppc64 \
		libgcc.ppc64le glibc-devel.ppc64le glibc-static.ppc64le \
		libgcc.s390    glibc-devel.s390    glibc-static.s390 \
		libgcc.s390x   glibc-devel.s390x   glibc-static.s390x \
		libgcc.aarch64 glibc-devel.aarch64 glibc-static.aarch64" >> $(METADATA)
	@echo "Requires:        wget" >> $(METADATA)
	@echo "Requires:        patch" >> $(METADATA)
	@echo "Requires:        gcc" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPL-v2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Releases:        RHEL6 RHEL7 RedHatEnterpriseLinuxPegas7" >> $(METADATA)

	rhts-lint $(METADATA)
