# Include global Makefile targets
# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=/kernel

# The path of the test below the package:
RELATIVE_PATH=firmware/fwts/user-specified

export TESTVERSION=1.0

export TEST=$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

METADATA=testinfo.desc

# built executables should be added here
BUILT_FILES=$(METADATA)

FILES=$(BUILT_FILES) \
	runtest.sh   \
	Makefile     \
	PURPOSE

build: $(BUILT_FILES)
	chmod a+x ./runtest.sh

run: build
	./runtest.sh

# Generate the testinfo.desc here:
$(METADATA): Makefile
	@touch $(METADATA)
	@echo "Owner:		Erico  Nunes <ernunes@redhat.com>"	> $(METADATA)
	@echo "Name:		$(TEST)"		>> $(METADATA)
	@echo "Path:		$(TEST_DIR)"		>> $(METADATA)
	@echo "Architectures:	aarch64 x86_64" >> $(METADATA)
	@echo "TestVersion:	$(TESTVERSION)"		>> $(METADATA)
	@echo "Description:	run user specified tests in Firmware Test Suite (fwts)" >> $(METADATA)
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
	@echo "Requires:	make"			>> $(METADATA)
	@echo "Requires:	wget"			>> $(METADATA)
	@echo "Requires:	patch"			>> $(METADATA)
	@echo "Requires:	autoconf"		>> $(METADATA)
	@echo "Requires:	automake"		>> $(METADATA)
	@echo "Requires:	gcc"			>> $(METADATA)
	@echo "Requires:	libtool"		>> $(METADATA)
	@echo "Requires:	bison"			>> $(METADATA)
	@echo "Requires:	flex"			>> $(METADATA)
	@echo "repoRequires:    cki_lib"                >> $(METADATA)
	@echo "repoRequires:    firmware/include"       >> $(METADATA)
	@echo "License:		GPLv2"			>> $(METADATA)
