# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2015 Red Hat, Inc. All rights reserved.
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

export TEST=/kernel/networking/sctp/auth/sockopts
export TESTVERSION=1.0

BUILT_FILES=

FILES=$(METADATA) *.sh Makefile PURPOSE *.c *.h common lib
TARGET_FILES=api_tests test_cases.c

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	test -x runtest.sh || chmod a+x runtest.sh
	test -x make_register_tests.sh || chmod a+x make_register_tests.sh

clean:
	rm -f *~ $(BUILT_FILES) $(TARGET_FILES)


include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Jianwen Ji <jiji@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     sctp auth socket ops test" >> $(METADATA)
	@echo "Type:            functional" >> $(METADATA)
	@echo "Type:            Singlehost" >> $(METADATA)
	@echo "TestTime:        60m" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Requires:        $(PACKAGE_NAME) lksctp-tools lksctp-tools-devel" >> $(METADATA)
	@echo "Requires:        bc wget bzip2 gcc" >> $(METADATA)
	@echo "Requires:        git patch rsync" >> $(METADATA)
	@echo "Requires:        texinfo" >> $(METADATA)
	@echo "Requires:        python3-lxml" >> $(METADATA)
	@echo "Requires:        kernel-modules-extra" >> $(METADATA)
	@echo "Requires:        kernel-rt-modules-extra" >> $(METADATA)
	rhts-lint $(METADATA)
