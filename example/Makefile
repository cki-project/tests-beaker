# ~~~~~~~~~~~~~~~~~~~~~
#
#   Example test Makefile
#
# ~~~~~~~~~~~~~~~~~~~~~

export TEST        := template/dummy-test
export TESTVERSION := 1.0

.PHONY: build run clean

FILES := $(METADATA) runtest.sh Makefile

run: $(FILES) build
	./runtest.sh

build:
	chmod a+x ./runtest.sh

clean:
	rm -f $(METADATA)

# Include Common Makefile
# Common Variables
TEST_DIR=/mnt/tests$(TEST)
INSTALL_DIR=$(DEST)$(TEST_DIR)
METADATA=testinfo.desc

$(METADATA):
	touch $(METADATA)
	@echo "Owner:		Ondrej Kinst <okinst@redhat.com>" >$(METADATA)
	@echo "Name:		$(TEST)" >>$(METADATA)
	@echo "Path:		$(TEST_DIR)" >>$(METADATA)
	@echo "TestVersion:	$(TESTVERSION)"	>>$(METADATA)
	@echo "License:		GPLv3" >>$(METADATA)
	@echo "Description: 	Dummy test." >>$(METADATA)
	@echo "Architectures:	x86_64" >>$(METADATA)
	@echo "repoRequires:	cki_lib" >> $(METADATA)
