# Copyright (c) 2019 Red Hat, Inc. All rights reserved. This copyrighted material
#  is made available to anyone wishing to use, modify, copy, or
#  redistribute it subject to the terms and conditions of the GNU General
#  Public License v.2.
#
#  This program is distributed in the hope that it will be useful, but WITHOUT ANY
#  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
#  PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
#
TENV=_env
ifeq ($(PKG_TOP_DIR),)
    export PKG_TOP_DIR := $(shell p=$$PWD; while :; do \
        [ -e $$p/env.mk -o -z "$$p" ] && { echo $$p; break; }; p=$${p%/*}; done)
    export _TOP_DIR := $(shell p=$$PWD; while :; do \
        [ -d $$p/.git -o -z "$$p" ] && { echo $$p; break; }; p=$${p%/*}; done)
    -include $(PKG_TOP_DIR)/env.mk
endif
include $(TENV)
ifeq ($(_TOP_DIR),)
    _TOP_DIR=/mnt/tests/$(TOPLEVEL_NAMESPACE)
endif
#===============================================================================

# Version of the Test. Used with make tag.
export TESTVERSION=1.0

.PHONY: all install download clean

BUILT_FILES= # executables to be built should be added here, they will be generated on the system under test.
FILES=$(TENV) $(METADATA) runtest.sh Makefile cthon_automount vercmp README.md

run: $(FILES) build
	( set +o posix; . /usr/share/beakerlib/beakerlib.sh; \
. runtest.sh )

build: $(BUILT_FILES)
	chmod a+x ./runtest.sh

clean:
	rm -f *~ $(BUILT_FILES)

# You may need to add other taregts e.g. to build executables from source code
# Add them here:


# Include Common Makefile
# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

# Generate the testinfo.desc here:
$(METADATA): Makefile
	@touch $(METADATA)
	@echo "Owner:        Kun Wang <kunwan@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)" >> $(METADATA)
	@echo "Path:         $(TEST_DIR)"	>> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"	>> $(METADATA)
	@echo "Description:  Connectathon for AutoFS ">> $(METADATA)
	@echo "RunFor:       kernel $(PACKAGE_NAME)" >> $(METADATA)
	@echo "Requires:     $(PACKAGE_NAME)" >> $(METADATA)
	@echo "Requires:     autofs" >> $(METADATA)
	@echo "Requires:     nfs-utils" >> $(METADATA)
	@echo "Requires:     ypserv yp-tools" >> $(METADATA)
	@echo "Requires:     gcc  git wget bc beakerlib redhat-lsb-core sg3_utils" >> $(METADATA)
	@echo "Requires:     utils-libs sg3_utils-devel rsyslog" >> $(METADATA)
	@echo "Requires:     libnsl2 libtirpc-devel python2 python2-lxml python3-lxml" >> $(METADATA)
	@echo "repoRequires: cki_lib" >> $(METADATA)
	@echo "License:      GPLv2" >> $(METADATA)

