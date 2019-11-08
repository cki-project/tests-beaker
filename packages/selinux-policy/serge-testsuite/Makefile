# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Sanity/serge-testsuite
#   Description: functional test suite for the LSM-based SELinux security module
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
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

export TEST=/CoreOS/selinux-policy/Sanity/serge-testsuite
export TESTVERSION=1.1

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	test -x runtest.sh || chmod a+x runtest.sh
	test -x runtest.sh || chcon -t bin_t runtest.sh

clean:
	rm -f *~ $(BUILT_FILES)

include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Milos Malik <mmalik@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     functional test suite for the LSM-based SELinux security module" >> $(METADATA)
	@echo "Type:            Sanity" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "Requires:        attr" >> $(METADATA)
	@echo "Requires:        audit" >> $(METADATA)
	@echo "Requires:        checkpolicy" >> $(METADATA)
	@echo "Requires:        expect" >> $(METADATA)
	@echo "Requires:        gcc" >> $(METADATA)
	@echo "Requires:        git" >> $(METADATA)
	@echo "Requires:        grep" >> $(METADATA)
	@echo "Requires:        ipsec-tools" >> $(METADATA)
	@echo "Requires:        keyutils-libs-devel" >> $(METADATA)
	@echo "Requires:        libbpf-devel" >> $(METADATA)
	@echo "Requires:        libibverbs-devel" >> $(METADATA)
	@echo "Requires:        libselinux" >> $(METADATA)
	@echo "Requires:        libselinux-devel" >> $(METADATA)
	@echo "Requires:        libselinux-utils" >> $(METADATA)
	@echo "Requires:        libsemanage" >> $(METADATA)
	@echo "Requires:        libsepol-devel" >> $(METADATA)
	@echo "Requires:        lksctp-tools-devel" >> $(METADATA)
	@echo "Requires:        mktemp" >> $(METADATA)
	@echo "Requires:        nc" >> $(METADATA)
	@echo "Requires:        netlabel_tools" >> $(METADATA)
	@echo "Requires:        net-tools" >> $(METADATA)
	@echo "Requires:        nmap-ncat" >> $(METADATA)
	@echo "Requires:        perl-Test" >> $(METADATA)
	@echo "Requires:        perl-Test-Harness" >> $(METADATA)
	@echo "Requires:        perl-Test-Simple" >> $(METADATA)
	@echo "Requires:        platform-python" >> $(METADATA)
	@echo "Requires:        policycoreutils" >> $(METADATA)
	@echo "Requires:        policycoreutils-devel" >> $(METADATA)
	@echo "Requires:        policycoreutils-python" >> $(METADATA)
	@echo "Requires:        python3" >> $(METADATA)
	@echo "Requires:        python2-lxml" >> $(METADATA)
	@echo "Requires:        python3-lxml" >> $(METADATA)
	@echo "Requires:        rdma-core-devel" >> $(METADATA)
	@echo "Requires:        selinux-policy" >> $(METADATA)
	@echo "Requires:        selinux-policy-devel" >> $(METADATA)
	@echo "Requires:        setools-console" >> $(METADATA)
	@echo "Requires:        which" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Releases:        -RHEL4" >> $(METADATA)
	@echo "Bug:             1251546" >> $(METADATA) # RHEL-7
	@echo "Bug:             1373368" >> $(METADATA) # RHEL-7
	@echo "Bug:             1480521" >> $(METADATA) # RHEL-7

	rhts-lint $(METADATA)

