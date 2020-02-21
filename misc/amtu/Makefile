# The name of the package under test
PACKAGE_NAME=kernel

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=/$(PACKAGE_NAME)

# The version of the test rpm that gets
#  created / submitted
export TESTVERSION=1.1

# The path of the test below the package
RELATIVE_PATH=misc/amtu

# Name of the tgz file that will be bundled in the rpm
TARGET=amtu-$(TESTVERSION)

# The relative path name to the test 
export TEST=$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

# All files you want bundled into your rpm
FILES=	$(METADATA)   \
	runtest.sh    \
	memsep-use-_exit-to-exit-child.patch \
	memtest-limit-memtest-to-512MB-of-memory.patch \
	Makefile

clean:
	rm -f *~ $(METADATA)
	rm -rf  rhts-rh-tests-kernel*.rpm  rh-tests-kernel*.rpm
	rm -rf ./amtu
	rm -rf ./mnt

run:
	@echo "No Build required using version packaged in distro"
	chmod +x ./runtest.sh
	./runtest.sh

# Include a global make rules file
# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

$(METADATA):
	touch $(METADATA)
	@echo "Name:		$(TEST)"	> $(METADATA)
	@echo "Description:	Abstract Machine Test Utility" >> $(METADATA)
	@echo "Path:		$(TEST_DIR)"	>> $(METADATA)
	@echo "TestVersion:	$(TESTVERSION)"	>> $(METADATA)
	@echo "Releases:	-RHEL2.1 -RHEL3" >> $(METADATA)
	@echo "Destructive:	no"		>> $(METADATA)
	@echo "Confidential:	no"		>> $(METADATA)
	@echo "Priority:	Normal"		>> $(METADATA)
	@echo "Type:		Standardscompliance" >> $(METADATA)
	@echo "Type:		KernelTier1"	>> $(METADATA)
	@echo "Requires:	kernel-devel"	>> $(METADATA)
	@echo "Requires:	@developer-tools" >> $(METADATA)
	@echo "Requires:	amtu"		>> $(METADATA)
	@echo "Requires:	gcc"		>> $(METADATA)
	@echo "Requires:	git"		>> $(METADATA)
	@echo "Requires:	make"		>> $(METADATA)
	@echo "Requires:	autoconf"       >> $(METADATA)
	@echo "Requires:	automake"       >> $(METADATA)
	@echo "Requires:	gettext"        >> $(METADATA)
	@echo "Requires:	wget"		>> $(METADATA)
	@echo "Requires:	auditd"		>> $(METADATA)
	@echo "Requires:	audit-tools"	>> $(METADATA)
	@echo "Requires:	audit-libs"	>> $(METADATA)
	@echo "Requires:	libao-devel"	>> $(METADATA)
	@echo "Requires:	libgcrypt-devel" >> $(METADATA)
	@echo "Requires:	audit-libs-devel" >> $(METADATA)
	@echo "RunFor:		kernel"		>> $(METADATA)
	@echo "RunFor:		amtu"		>> $(METADATA)
	@echo "License:		GPL"		>> $(METADATA)
	@echo "Owner:		Kernel General Test Team <kernel-general-test-team@redhat.com>"	>> $(METADATA)
	@echo "RepoRequires:	cki_lib"	>> $(METADATA)
