# Copyright (c) 2017 Red Hat, Inc. All rights reserved. This copyrighted
# material is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General Public
# License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Jeff Bastian <jbastian@redhat.com>

TOPLEVEL_NAMESPACE=kernel
PACKAGE_NAME=stress
RELATIVE_PATH=stress-ng

export TESTVERSION=1.0
export TEST=/$(TOPLEVEL_NAMESPACE)/$(PACKAGE_NAME)/$(RELATIVE_PATH)

# All files you want bundled into your rpm
FILES=	$(METADATA) \
    runtest.sh \
    Makefile \
    PURPOSE \
    *.stressors

.PHONY: clean run

clean:
	rm -f *~ $(METADATA)

run:
	@echo "No Build required"
	chmod +x ./runtest.sh
	./runtest.sh

# Include a global make rules file
# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

$(METADATA):
	touch $(METADATA)
	@echo "Owner:		Jeff Bastian <jbastian@redhat.com>" 	> $(METADATA)
	@echo "Name:		$(TEST)"				>> $(METADATA)
	@echo "Description:	Run stress-ng tests"			>> $(METADATA)
	@echo "Path:		$(TEST_DIR)"				>> $(METADATA)
	@echo "TestVersion:	$(TESTVERSION)"				>> $(METADATA)
	@echo "Releases:	RHEL7"					>> $(METADATA)
	@echo "Architectures:	aarch64 ppc64le s390x x86_64"		>> $(METADATA)
	@echo "Destructive:	no"					>> $(METADATA)
	@echo "Confidential:	no"					>> $(METADATA)
	@echo "Priority:	Normal"					>> $(METADATA)
	@echo "RunFor:		kernel"					>> $(METADATA)
	@echo "License:		GPLv2"					>> $(METADATA)
	@echo "Requires:	beakerlib"				>> $(METADATA)
	@echo "Requires:	beakerlib-redhat"			>> $(METADATA)
	@echo "Requires:	kernel-devel"				>> $(METADATA)
	@echo "Requires:	kernel-headers"				>> $(METADATA)
	@echo "Requires:	gcc"					>> $(METADATA)
	@echo "Requires:	wget"					>> $(METADATA)
	@echo "Requires:	dmidecode"				>> $(METADATA)
	@echo "Requires:	libaio-devel"				>> $(METADATA)
	@echo "Requires:	libattr-devel"				>> $(METADATA)
	@echo "Requires:	libbsd-devel"				>> $(METADATA)
	@echo "Requires:	libcap-devel"				>> $(METADATA)
	@echo "Requires:	libgcrypt-devel"			>> $(METADATA)
	@echo "Requires:	libsctp-devel"				>> $(METADATA)
	@echo "Requires:	keyutils-libs"				>> $(METADATA)
	@echo "Requires:	zlib-devel"				>> $(METADATA)
	@echo "Requires:        git"					>> $(METADATA)
	@echo "Requires:        python3-lxml"                           >> $(METADATA)	
