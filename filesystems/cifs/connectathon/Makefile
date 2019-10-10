# Copyright (c) 2019 Red Hat, Inc. All rights reserved. This copyrighted material
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

#Generate and export TEST= PACKAGE=
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
export TESTVERSION=1.1

.PHONY: all install download clean

BUILT_FILES= # executables to be built should be added here, they will be generated on the system under test.
FILES=$(TENV) $(METADATA) runtest.sh Makefile smb.conf smb.conf.unix local.te

CONNECTATHON_SRCDIR=cthon04
LOOKASIDE_DEFAULT=git://git.linux-nfs.org/projects/steved/cthon04.git
LOOKASIDE=$(shell echo $$LOOKASIDE)
ifeq (,$(LOOKASIDE))
    LOOKASIDE=${LOOKASIDE_DEFAULT}
endif

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	git clone $(LOOKASIDE_DEFAULT)
	chmod a+x ./runtest.sh

clobber: clean
	rm -rf $(CONNECTATHON_SRCDIR)

clean:
	rm -f *~ $(BUILT_FILES)

# You may need to add other taregts e.g. to build executables from source code
# Add them here:


# Include Common Makefile
include /usr/share/rhts/lib/rhts-make.include

# Generate the testinfo.desc here:
$(METADATA): Makefile
	@touch $(METADATA)
	@echo "Owner:        Jianhong Yin <jiyin@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)" >> $(METADATA)
	@echo "Path:         $(TEST_DIR)"	>> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"	>> $(METADATA)
	@echo "Description:  Connectathon for CIFS ">> $(METADATA)
	@echo "Releases:     -RHEL2.1 -RHEL3" >> $(METADATA)
	@echo "RunFor:       $(PACKAGE_NAME)" >> $(METADATA)
	@echo "Requires:     wget git samba time patch" >> $(METADATA)
	@echo "Requires:     cups samba-client cifs-utils" >> $(METADATA)
	@echo "Requires:     gcc bzip2 nfs-utils net-tools rusers" >> $(METADATA)
	@echo "Requires:     libnsl2 libtirpc-devel" >> $(METADATA)
	@echo "Requires:     beakerlib python3-lxml " >> $(METADATA)
	@echo "License:      GPL v2"            >> $(METADATA)
	@echo "Type:         Regression"        >> $(METADATA)
	@echo "Type:         KernelTier1" >>$(METADATA)
