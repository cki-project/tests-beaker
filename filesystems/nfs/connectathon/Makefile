# Copyright (c) 2006 Red Hat, Inc. All rights reserved. This copyrighted material
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
# Author: Bill Peck <bpeck@redhat.com>

# The name of the package under test
PACKAGE_NAME=kernel

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=/$(PACKAGE_NAME)

# The path of the test below the package
RELATIVE_PATH=filesystems/nfs/connectathon

# The relative path name to the test
export TEST=$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

# The redhat rpm test package version
export TESTVERSION=3.0

# Include a global make rules file
# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

CONNECTATHON_SRCDIR=cthon04
LOOKASIDE_DEFAULT=git://git.linux-nfs.org/projects/steved/cthon04.git
LOOKASIDE=$(shell echo $$LOOKASIDE)
ifeq (,$(LOOKASIDE))
    LOOKASIDE=${LOOKASIDE_DEFAULT}
endif

FILES=	$(METADATA)       \
	runtest.sh        \
	kvercmp.sh        \
	patch             \
	434966lock.patch  \
	Makefile          \
	hostnamefix.patch \
	umount.patch      \
	filter_nroff_warnings.patch

dopatch: $(CONNECTATHON_SRCDIR)
	patch -d $< -p1 < patches/patch
	patch -d $< -p1 < patches/434966lock.patch
	patch -d $< -p1 < patches/hostnamefix.patch
	patch -d $< -p1 < patches/umount.patch
	patch -d $< -p1 < patches/filter_nroff_warnings.patch

clone: $(CONNECTATHON_SRCDIR)
$(CONNECTATHON_SRCDIR):
	git clone $(LOOKASIDE_DEFAULT)

build: dopatch
	(cd $(CONNECTATHON_SRCDIR); make)

clean:
	rm -f *~ $(METADATA)

clobber: clean
	rm -rf $(CONNECTATHON_SRCDIR)

run: build
	chmod a+x ./runtest.sh
	./runtest.sh

$(METADATA):
	@touch $(METADATA)
	@echo "Owner:        Bill Peck <bpeck@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)"		>> $(METADATA)
	@echo "Path:         $(TEST_DIR)"	>> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"	>> $(METADATA)
	@echo "Description:  Connectathon Testsuite\
		 to test NFS versions 2,3 and 4." >> $(METADATA)
	@echo "RunFor:       kernel"		>> $(METADATA)
	@echo "RunFor:       nfs-utils"		>> $(METADATA)
	@echo "Requires:     nfs-utils"		>> $(METADATA)
	@echo "Requires:     net-tools"		>> $(METADATA)
	@echo "Requires:     net-snmp"		>> $(METADATA)
	@echo "Requires:     ethereal"		>> $(METADATA)
	@echo "Requires:     wireshark"		>> $(METADATA)
	@echo "Requires:     tcpdump"		>> $(METADATA)
	@echo "Requires:     rusers"		>> $(METADATA)
	@echo "Requires:     bzip2"		>> $(METADATA)
	@echo "Requires:     gcc"		>> $(METADATA)
	@echo "Requires:     git"		>> $(METADATA)
	@echo "Requires:     patch"		>> $(METADATA)
	@echo "Requires:     time"		>> $(METADATA)
	@echo "Requires:     libnsl2 libtirpc-devel"		>> $(METADATA)
	@echo "RhtsRequires: test(/kernel/include)"                      >> $(METADATA)
	@echo "Provides:     test(/kernel/filesystems/nfs/connectathon)" >> $(METADATA)
	@echo "Priority:     Medium"		>> $(METADATA)
	@echo "Type:         Regression"	>> $(METADATA)
	@echo "Type:         Tier1"		>> $(METADATA)
	@echo "Type:         KernelTier0 KernelTier1"	>> $(METADATA)
	@echo "License:      GPL v2"		>> $(METADATA)
	@echo "repoRequires: cki_lib" >> $(METADATA)
