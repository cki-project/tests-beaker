# The name of the package under test
PACKAGE_NAME=kernel

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=/$(PACKAGE_NAME)

# The version of the test rpm that gets
#  created / submitted
export TESTVERSION=1.4

# The path of the test below the package
RELATIVE_PATH=misc/module-load

# The relative path name to the test
export TEST=$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

# Generated information file that describes your test
#  and test requiremnets
METADATA=testinfo.desc

FILES=	$(METADATA) \
	Makefile    \
	runtest.sh  \
	modules.*

run: build
	./runtest.sh

build: $(METADATA)
	chmod a+x ./runtest.sh

clean:
	rm -f *~ 
	rm -rf test/
	rm -f rh*.rpm
 
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
	@echo "Name:         $(TEST)"		> $(METADATA)
	@echo "Path:         $(TEST_DIR)"	>> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)"	>> $(METADATA)
	@echo "Description:  Simple kernel sanity\
		check that loads and unloads various\
		kernel modules"			>> $(METADATA)
	@echo "Releases:     -RHEL2.1"		>> $(METADATA)
	@echo "#Architectures: All"		>> $(METADATA)
	@echo "Destructive:  no"		>> $(METADATA)
	@echo "RunFor:       $(PACKAGE_NAME)"	>> $(METADATA)
	@echo "Type:         Regression"	>> $(METADATA)
	@echo "Type:         KernelTier1"	>> $(METADATA)
	@echo "Requires:     kernel-utils"	>> $(METADATA)
	@echo "Requires:     coreutils"		>> $(METADATA)
	@echo "Requires:     @development-tools" >> $(METADATA)
	@echo "RepoRequires: cki_lib"		>> $(METADATA)
	@echo "License:      GPL" >> $(METADATA)
	@echo "Owner:        Mike Gahagan <mgahagan@redhat.com>" >> $(METADATA)
