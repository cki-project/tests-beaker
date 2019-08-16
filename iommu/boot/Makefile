# Include Common Makefile
include /usr/share/rhts/lib/rhts-make.include

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=/kernel

RELATIVE_PATH=iommu/boot

# The version of the test rpm that gets created / submitted.
export TESTVERSION=1.0

# The relative path name to the test.
export TEST=$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

.PHONY: build clean run

# All files you want bundled into your rpm.
FILES=	$(METADATA) runtest.sh \
	Makefile \
        PURPOSE \
	default-boot-options-intel.txt \
	default-boot-options-amd.txt \
	iommu-dmesg-errors.txt

build:	$(METADATA)
	chmod a+x ./runtest.sh

clean:
	rm -f $(METADATA)

run:	build
	./runtest.sh

$(METADATA):
	touch $(METADATA)
	@echo "Name:		$(TEST)" >$(METADATA)
	@echo "Description:	boot kernel with different iommu options" \
				>>$(METADATA)
	@echo "Path:		$(TEST_DIR)" >>$(METADATA)
	@echo "TestTime:	1h" >>$(METADATA)
	@echo "TestVersion:	$(TESTVERSION)"	>>$(METADATA)
	@echo "Destructive:	no" >>$(METADATA)
	@echo "Confidential:	no" >>$(METADATA)
	@echo "RunFor:		kernel"	>>$(METADATA)
	@echo "License:		GPLv2" >>$(METADATA)
	@echo "Owner:		William Gomeringer <wgomerin@redhat.com>" >>$(METADATA)
