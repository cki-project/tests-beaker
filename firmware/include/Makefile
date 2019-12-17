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
# Include global Makefile targets
include /usr/share/rhts/lib/rhts-make.include

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=/kernel

# The path of the test below the package:
RELATIVE_PATH=firmware/fwts/include

export TESTVERSION=1.0

export TEST=$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

METADATA=testinfo.desc

# built executables should be added here
BUILT_FILES=$(METADATA)

FILES=$(BUILT_FILES) \
	patches/ \
	runtest.sh   \
	Makefile \
	PURPOSE

build: $(BUILT_FILES)
	chmod a+x ./runtest.sh

run: build
	./runtest.sh

# Generate the testinfo.desc here:
$(METADATA): Makefile
	@touch $(METADATA)
	@echo "Owner:		Erico Nunes <ernunes@redhat.com>"	> $(METADATA)
	@echo "Name:		$(TEST)"		>> $(METADATA)
	@echo "Path:		$(TEST_DIR)"		>> $(METADATA)
	@echo "TestVersion:	$(TESTVERSION)"		>> $(METADATA)
	@echo "Architectures:	aarch64 x86_64" >> $(METADATA)
	@echo "Description:	beaker library for Firmware Test Suite (fwts)" >> $(METADATA)
	@echo "Priority:	Manual"			>> $(METADATA)
	@echo "Requires:	iasl wget"		>> $(METADATA)
	@echo "Requires:	acpidump"		>> $(METADATA)
	@echo "Requires:	pciutils"		>> $(METADATA)
	@echo "Requires:	dmidecode"		>> $(METADATA)
	@echo "Requires:	sendmail"		>> $(METADATA)
	@echo "Requires:	pcre-devel"		>> $(METADATA)
	@echo "Requires:	json-c-devel"		>> $(METADATA)
	@echo "Requires:	git"			>> $(METADATA)
	@echo "Requires:	elfutils-libelf-devel"	>> $(METADATA)
	@echo "Requires:	kernel-devel"		>> $(METADATA)
	@echo "Requires:	glib2-devel"		>> $(METADATA)
	@echo "Requires:	beakerlib-redhat"	>> $(METADATA)
	@echo "Requires:	rhts-test-env.noarch"	>> $(METADATA)
	@echo "Requires:        make"                   >> $(METADATA)
	@echo "Requires:        gettext"                >> $(METADATA)
	@echo "Requires:	wget"			>> $(METADATA)
	@echo "Requires:	patch"			>> $(METADATA)
	@echo "Requires:	autoconf"		>> $(METADATA)
	@echo "Requires:	automake"		>> $(METADATA)
	@echo "Requires:	gcc"			>> $(METADATA)
	@echo "Requires:	libtool"		>> $(METADATA)
	@echo "Requires:	bison"			>> $(METADATA)
	@echo "Requires:	flex"			>> $(METADATA)
	@echo "RepoRequires:    cki_lib"                >> $(METADATA)
	@echo "License:		GPLv2"			>> $(METADATA)
	@echo "RhtsOptions:	-Compatible -CompatService"	>> $(METADATA)
