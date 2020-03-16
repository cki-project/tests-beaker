# The name of the package under test
PACKAGE_NAME=kernel

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=/$(PACKAGE_NAME)

# The version of the test rpm that gets
#  created / submitte
export TESTVERSION=1.0

# The path of the test below the package
RELATIVE_PATH=storage/lvm/thinp/sanity

# The relative path name to the test
export TEST=$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

# Name of the tar file that will be bundled in the rpm
TARGET=iozone3_414

FILES=	$(METADATA)      \
	runtest.sh       \
	Makefile

clean:
	$(RM) *~ rm $(METADATA)
	rm -rf $(TARGET) rh-tests-kernel-*.rpm
	rm -rf $(TARGET).tar.gz
	rm -f iozone *.txt

run: build
	chmod +x ./runtest.sh
	./runtest.sh

build: $(METADATA) $(TARGET)
	make -C iozone3_414/src/current/ linux
	cp -f iozone3_414/src/current/iozone ./

$(TARGET):
	# Use lookaside location for iozone3 dependency
	wget --tries=10 http://cki-artifacts.s3.us-east-2.amazonaws.com/lookaside/$(TARGET).tar.gz
	tar -xzvf $(TARGET).tar.gz

# Include a global make rules file
# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

showmeta: $(METADATA)
	@cat $(METADATA)

$(METADATA):
	touch $(METADATA)
	@echo "Name:		$(TEST)"	> $(METADATA)
	@echo "Description:	Sanity test for lvm thinp" >> $(METADATA)
	@echo "Path:		$(TEST_DIR)"	>> $(METADATA)
	@echo "TestVersion:	$(TESTVERSION)"	>> $(METADATA)
	@echo "Releases:	RedHatEnterpriseLinux7 RedHatEnterpriseLinuxPegas7 RedHatEnterpriseLinuxAlternateArchitectures7 Fedora25 Fedora26 Fedorarawhide" >> $(METADATA)
	@echo "#Architectures:	All"		>> $(METADATA)
	@echo "Destructive:	no"		>> $(METADATA)
	@echo "Type:            KernelTier0 KernelTier1"    >> $(METADATA)
	@echo "Priority:	Normal"		>> $(METADATA)
	@echo "RunFor:		kernel"		>> $(METADATA)
	@echo "Requires:	kernel-devel"	>> $(METADATA)
	@echo "Requires:	lvm2"           >> $(METADATA)
	@echo "Requires:	wget"           >> $(METADATA)
	@echo "Requires:	gcc"            >> $(METADATA)
	@echo "Requires:	make"           >> $(METADATA)
	@echo "Requires:	glibc-static"   >> $(METADATA)
	@echo "Requires:	gnuplot"	>> $(METADATA)
	@echo "repoRequires:	cki_lib"	>> $(METADATA)
	@echo "Owner:		Jakub Krysl <jkrysl@redhat.com>" >> $(METADATA)
	@echo "License:		GPLv2"		>> $(METADATA)
