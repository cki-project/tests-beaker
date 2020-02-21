TOPLEVEL_NAMESPACE	= kernel
PACKAGE_NAME		= kernel
RELATIVE_PATH		= storage/dm/common

export TEST=/$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)
export TESTVERSION=1.0

.PHONY: all install download clean

BUILT_FILES	= runtest

FILES		= $(METADATA) \
		  Makefile \
		  README.md \
		  PURPOSE \
		  runtest.sh

run: $(FILES) build
	./runtest

runtest: runtest.sh
	cp $< $@ && chmod +x $@

build: $(BUILT_FILES)

clean:
	rm -f *~ *.rpm $(BUILT_FILES)


# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

$(METADATA): Makefile
	@echo "Owner:        Jakub Krysl <jkrysl@redhat.com>" > $(METADATA)
	@echo "Name:         $(TEST)" >> $(METADATA)
	@echo "TestVersion:  $(TESTVERSION)" >> $(METADATA)
	@echo "Path:         $(TEST_DIR)" >> $(METADATA)
	@echo "Description:  Tests device-mapper, mainly Core">> $(METADATA)
	@echo "RunFor:       $(PACKAGE_NAME)" >> $(METADATA)
	@echo "Requires:     $(PACKAGE_NAME)" >> $(METADATA)
	@echo "Requires:     git" >> $(METADATA)
	@echo "Requires:     wget" >> $(METADATA)
	@echo "Requires:     augeas" >> $(METADATA)
	@echo "Requires:     python3" >> $(METADATA)
	@echo "Requires:     python2-lxml" >> $(METADATA)
	@echo "Requires:     python3-lxml" >> $(METADATA)
	@echo "Requires:     platform-python-devel python-devel python3-devel" >> $(METADATA)
	@echo "repoRequires: cki_lib" >> $(METADATA)
	@echo "repoRequires: storage/include" >> $(METADATA)
	@echo "Priority:     Normal" >> $(METADATA)
	@echo "License:      GPLv2 or above" >> $(METADATA)
	@echo "Confidential: no" >> $(METADATA)
	@echo "Destructive:  no" >> $(METADATA)

	rhts-lint $(METADATA)
