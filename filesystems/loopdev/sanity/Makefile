# The name of the package under test
PACKAGE_NAME=kernel

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=/$(PACKAGE_NAME)

# The version of the test rpm that gets
#  created / submitte
export TESTVERSION=1.0

# The path of the test below the package
RELATIVE_PATH=filesystems/loopdev/sanity

# The relative path name to the test
export TEST=$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

LOOKASIDE=http://www.iozone.org/src/current

# Name of the tar file that will be bundled
TARGET=iozone3_487

FILES=	$(METADATA)      \
	runtest.sh       \
	Makefile

clean:
	$(RM) *~ rm $(METADATA)
	rm -rf $(TARGET) rh-tests-kernel-*.rpm
	rm -rf fs_mark $(TARGET).tar
	rm -f iozone *.txt
	rm -f runtest

runtest: runtest.sh
	cp $< $@ && chmod +x $@

run: build
	./runtest

build: $(METADATA) $(TARGET) runtest
	make -C $(TARGET)/src/current/ linux
	cp -f $(TARGET)/src/current/iozone ./

$(TARGET).tar:
	wget $(LOOKASIDE)/$(TARGET).tar

$(TARGET): $(TARGET).tar
	tar -xvf $(TARGET).tar

# Include a global make rules file
include /usr/share/rhts/lib/rhts-make.include

showmeta: $(METADATA)
	@cat $(METADATA)
	@rhts-lint $(METADATA)

$(METADATA):
	touch $(METADATA)
	@echo "Name:		$(TEST)"	> $(METADATA)
	@echo "Description:	Sanity test for loop device" >> $(METADATA)
	@echo "Path:		$(TEST_DIR)"	>> $(METADATA)
	@echo "TestTime:	15m"		>> $(METADATA)
	@echo "TestVersion:	$(TESTVERSION)"	>> $(METADATA)
	@echo "Releases:	RHEL7 Fedorarawhide" >> $(METADATA)
	@echo "#Architectures:	All"		>> $(METADATA)
	@echo "Destructive:	no"		>> $(METADATA)
	@echo "Type:            KernelTier0 KernelTier1"    >> $(METADATA)
	@echo "Priority:	Normal"		>> $(METADATA)
	@echo "RunFor:		kernel"		>> $(METADATA)
	@echo "Requires:	kernel-devel"	>> $(METADATA)
	@echo "Requires:	gcc"            >> $(METADATA)
	@echo "Requires:	make"           >> $(METADATA)
	@echo "Requires:	glibc-static"   >> $(METADATA)
	@echo "Requires:	wget"           >> $(METADATA)
	@echo "Owner:		Jan Stancek <jstancek@redhat.com>" >> $(METADATA)
	@echo "License:		GPLv2"		>> $(METADATA)
