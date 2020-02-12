include /usr/share/rhts/lib/rhts-make.include
ifeq (,$(wildcard ../include/ltp-make.include))
include /mnt/tests/kernel/distribution/ltp/include/ltp-make.include
else
include ../include/ltp-make.include
endif

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=/kernel

# The name of the package under test.
PACKAGE_NAME=distribution

# The name of test case.
TEST_CASE=ltp/lite

# The version of the test rpm that gets created / submitted.
# export TESTVERSION=1.0
# The TESTVERSION is declared in the include file
# /mnt/tests/kernel/distribution/ltp/include/ltp-make.include

export TEST=$(TOPLEVEL_NAMESPACE)/$(PACKAGE_NAME)/$(TEST_CASE)

.PHONY: build clean run patch-inc-tolerant

PATCHDIR = .
ifeq ($(wildcard patches),patches)
    PATCHDIR = patches
endif
PATCHES=$(PATCHDIR)

# All files you want in your rpm.
FILES=$(METADATA) runtest.sh Makefile PURPOSE configs/ \
	grab_corefiles.sh grab_corefiles_excluded_bins \
	is_baremetal.sh timeout.my \
	$(PATCHES)

patch-inc-tolerant:
	-make --ignore-errors patch-inc > patchinc.log 2>&1
	-cat patchinc.log

patch: patch-inc-tolerant patch-lite

patch-lite:
	@echo "============ Patch ltp-lite test suite. ============"
ifeq ($(TESTVERSION),20190930)
	cp -vf configs/RHELKT1LITE.20190930 RHELKT1LITE
else
	cp -vf configs/RHELKT1LITE.20200120 RHELKT1LITE
endif

build: $(TARGET) build-all
	chmod +x ./runtest.sh
	chmod +x ./grab_corefiles.sh

patchonly-generic: $(TARGET) patch-inc-tolerant

patchonly: $(TARGET) patch

patch-and-build: $(TARGET) patch build

run: $(TARGET) patch build
	@echo "============ Run Tests ============"
	LANG=C ./runtest.sh

$(METADATA):
	touch $(METADATA)
	@echo "Name:            $(TEST)" >$(METADATA)
	@echo "Description:     Latest LTP test KernelTier1" >>$(METADATA)
	@echo "Path:            $(TEST_DIR)" >>$(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >>$(METADATA)
	@echo "License:         GPLv3" >>$(METADATA)
	@echo "RhtsRequires:    kernel-kernel-distribution-ltp-include" >> $(METADATA)
	@echo "Requires:        automake autoconf procmail flex bison rsyslog sysklogd util-linux-ng rpm-build" >> $(METADATA)
	@echo "Requires:        gcc wget ntpdate kernel-headers redhat-lsb bc numactl" >> $(METADATA)
	@echo "Requires:        kernel-devel libaio-devel libcap-devel numactl-devel libcgroup strace hexdump virt-what" >> $(METADATA)
	@echo "Owner:           Kernel General Test Team <kernel-general-test-team@redhat.com>" >>$(METADATA)
	@echo "Releases:        RHEL6 RHEL7 RedHatEnterpriseLinux7 RedHatEnterpriseLinuxPegas7 RedHatEnterpriseLinuxAlternateArchitectures7 RedHatEnterpriseLinux8 Fedora25 Fedora26 Fedorarawhide" >>$(METADATA)
	@echo "Type:            KernelTier0 KernelTier1" >>$(METADATA)
