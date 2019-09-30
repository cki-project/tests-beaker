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
ifeq ($(TESTVERSION),20120822)
	cp -vf $(PATCHDIR)/$(TESTVERSION)/proc01.c $(TARGET)/testcases/kernel/fs/proc/
	cp -vf $(PATCHDIR)/$(TESTVERSION)/clone_platform.h $(TARGET)/testcases/kernel/syscalls/clone/
	cp -vrf $(PATCHDIR)/$(TESTVERSION)/readahead $(TARGET)/testcases/kernel/syscalls/
	cp -vf $(PATCHDIR)/$(TESTVERSION)/send01.c $(TARGET)/testcases/kernel/syscalls/send/
	cp -vf $(PATCHDIR)/$(TESTVERSION)/sendto01.c $(TARGET)/testcases/kernel/syscalls/sendto/
	cp -vf $(PATCHDIR)/$(TESTVERSION)/sendmsg01.c $(TARGET)/testcases/kernel/syscalls/sendmsg/
else ifeq ($(TESTVERSION),20130109)
	cp -vf $(PATCHDIR)/$(TESTVERSION)/waitid02.c $(TARGET)/testcases/kernel/syscalls/waitid
	cp -vf $(PATCHDIR)/$(TESTVERSION)/clone02.c $(TARGET)/testcases/kernel/syscalls/clone
	cp -vf $(PATCHDIR)/$(TESTVERSION)/clone07.c $(TARGET)/testcases/kernel/syscalls/clone
	cp -vf $(PATCHDIR)/$(TESTVERSION)/proc01.c $(TARGET)/testcases/kernel/fs/proc
else ifeq ($(TESTVERSION),20130904)
	cp -vf $(PATCHDIR)/$(TESTVERSION)/proc01.c $(TARGET)/testcases/kernel/fs/proc
	cp -vf $(PATCHDIR)/$(TESTVERSION)/kernel_Makefile $(TARGET)/testcases/kernel/Makefile
	cp -vf $(PATCHDIR)/$(TESTVERSION)/sendmsg01.c $(TARGET)/testcases/kernel/syscalls/sendmsg/
else ifeq ($(TESTVERSION),20140115)
	cp -vf $(PATCHDIR)/$(TESTVERSION)/readahead02.c $(TARGET)/testcases/kernel/syscalls/readahead/
else ifeq ($(TESTVERSION),20150119)
	cp -vf configs/RHELKT1LITE.20150119 RHELKT1LITE
	cp -vf $(PATCHDIR)/$(TESTVERSION)/proc01.c $(TARGET)/testcases/kernel/fs/proc/
else ifeq ($(TESTVERSION),20150420)
	cp -vf $(PATCHDIR)/20150420/proc01.c $(TARGET)/testcases/kernel/fs/proc/
	cp -vf configs/RHELKT1LITE.20150420 RHELKT1LITE
else ifeq ($(TESTVERSION),20160126)
	patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/20150903/proc01_ignore_bus_usb.patch
	patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/oom_hang_workaround.patch
	cp -vf configs/RHELKT1LITE.20150903 RHELKT1LITE
else ifeq ($(TESTVERSION),20160510)
	patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/20150903/proc01_ignore_bus_usb.patch
	patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/oom_hang_workaround.patch
	cp -vf configs/RHELKT1LITE.20160510 RHELKT1LITE
else ifeq ($(TESTVERSION),20160920)
	patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/20150903/proc01_ignore_bus_usb.patch
	patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/oom_hang_workaround.patch
	cp -vf configs/RHELKT1LITE.20160920 RHELKT1LITE
else ifeq ($(TESTVERSION),20170116)
	patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/20150903/proc01_ignore_bus_usb.patch
	patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/oom_hang_workaround.patch
	cp -vf configs/RHELKT1LITE.20170116 RHELKT1LITE
else ifeq ($(TESTVERSION),20170516)
	patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/20150903/proc01_ignore_bus_usb.patch
	patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/oom_hang_workaround.patch
	cp -vf configs/RHELKT1LITE.20170516 RHELKT1LITE
else ifeq ($(TESTVERSION),20170929)
	patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/20150903/proc01_ignore_bus_usb.patch
	patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/oom_hang_workaround2.patch
	if ! ./is_baremetal.sh; then patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/dont_fail_timing.patch; fi
	cp -vf configs/RHELKT1LITE.20170929 RHELKT1LITE
else ifeq ($(TESTVERSION),2018018)
	patch -d $(TARGET) -p1 < $(PATCHDIR)/20150903/proc01_ignore_bus_usb.patch
	patch -d $(TARGET) -p1 < $(PATCHDIR)/oom_hang_workaround2.patch
	if ! ./is_baremetal.sh; then patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/dont_fail_timing.patch; fi
	# RHEL5 gcc has trouble with this test
	if grep -q "release 5" /etc/redhat-release; then rm -f $(TARGET)/testcases/cve/cve-2016-7117.c; fi
	# RHEL5 doesn't have timeout
	if grep -q "release 5" /etc/redhat-release; then cp -f timeout.my /usr/bin/timeout; fi
	cp -vf configs/RHELKT1LITE.20180118 RHELKT1LITE
else ifeq ($(TESTVERSION),20180515)
	patch -d $(TARGET) -p1 < $(PATCHDIR)/20150903/proc01_ignore_bus_usb.patch
	if ! ./is_baremetal.sh; then patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/dont_fail_timing.patch; fi
	# RHEL5 gcc has trouble with this test
	if grep -q "release 5" /etc/redhat-release; then rm -f $(TARGET)/testcases/cve/cve-2016-7117.c; fi
	# RHEL5 doesn't have timeout
	if grep -q "release 5" /etc/redhat-release; then cp -f timeout.my /usr/bin/timeout; fi
	cp -vf configs/RHELKT1LITE.20180515 RHELKT1LITE
else
	patch -d $(TARGET) -p1 < $(PATCHDIR)/20150903/proc01_ignore_bus_usb.patch
	if ! ./is_baremetal.sh; then patch -d $(TARGET) -p1 --merge < $(PATCHDIR)/dont_fail_timing.patch; fi
	# RHEL5 gcc has trouble with this test
	if grep -q "release 5" /etc/redhat-release; then rm -f $(TARGET)/testcases/cve/cve-2016-7117.c; fi
	# RHEL5 doesn't have timeout
	if grep -q "release 5" /etc/redhat-release; then cp -f timeout.my /usr/bin/timeout; fi
	# work around Bug 1672242 - clash between linux/in.h and netinet/in.h
	if grep -q "release 7" /etc/redhat-release; then rm -f $(TARGET)/testcases/kernel/syscalls/setsockopt/setsockopt03.c || true; fi
	cp -vf configs/RHELKT1LITE.20190115 RHELKT1LITE
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
