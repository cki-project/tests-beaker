# The name of the package under test
PACKAGE_NAME=kernel

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=/$(PACKAGE_NAME)

# The version of the test rpm that gets
#  created / submitted
export TESTVERSION=1.1

# The path of the test below the package
RELATIVE_PATH=misc/header-test

# The relative path name to the test
export TEST=$(TOPLEVEL_NAMESPACE)/$(RELATIVE_PATH)

# All files you want bundled into your rpm
FILES=	$(METADATA) \
    runtest.sh \
    Makefile \
    PURPOSE \
    *.py \
    ./el6 \
    ./el7 \
    ./el8

clean:
	rm -f *~ $(METADATA)
	rm -rf rh-tests-kernel*.rpm
	find . -type f -name '*.pyc' -exec rm '{}' \;

run:
	chmod +x ./runtest.sh
	./runtest.sh

# Include a global make rules file
include /usr/share/rhts/lib/rhts-make.include

$(METADATA):
	touch $(METADATA)
	@echo "Owner:		Jeff Bastian <jbastian@redhat.com>" 	> $(METADATA)
	@echo "Name:		$(TEST)"				>> $(METADATA)
	@echo "Description:	Sanity test for kernel-headers" 	>> $(METADATA)
	@echo "Path:		$(TEST_DIR)"				>> $(METADATA)
	@echo "TestTime:	10m"					>> $(METADATA)
	@echo "TestVersion:	$(TESTVERSION)"				>> $(METADATA)
	@echo "Releases:	RHEL6 RHEL7 RHEL8 RedHatEnterpriseLinux6 RedHatEnterpriseLinux7 RedHatEnterpriseLinux8" >> $(METADATA)
	@echo "Architectures:	i386 x86_64 ppc64 ppc64le s390x aarch64"	>> $(METADATA)
	@echo "Destructive:	no"					>> $(METADATA)
	@echo "Confidential:	no"					>> $(METADATA)
	@echo "Priority:	Normal"					>> $(METADATA)
	@echo "RunFor:		kernel"					>> $(METADATA)
	@echo "License:		GPL"					>> $(METADATA)
	@echo "Requires:	kernel-headers"				>> $(METADATA)
	@echo "Requires:	gcc"					>> $(METADATA)
	@echo "Requires:	bash"					>> $(METADATA)
	@echo "Requires:	python python2 python3"			>> $(METADATA)
	@echo "Requires:	gcc"					>> $(METADATA)
