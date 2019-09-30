include /usr/share/rhts/lib/rhts-make.include
include ../include/ltp-make.include

# The toplevel namespace within which the test lives.
TOPLEVEL_NAMESPACE=/kernel

# The name of the package under test.
PACKAGE_NAME=distribution/ltp

# The name of test case.
TEST_CASE=openposix_testsuite

# The version of the test rpm that gets created / submitted.
# export TESTVERSION=1.0
# The TESTVERSION is declared in the include file
# /mnt/tests/kernel/distribution/ltp/include/ltp-make.include

export TEST=$(TOPLEVEL_NAMESPACE)/$(PACKAGE_NAME)/$(TEST_CASE)

.PHONY: build clean run patch-inc-tolerant

# All files you want in your rpm.
FILES=	$(METADATA) runtest.sh Makefile PURPOSE \
	disabled.* \
	grab_corefiles.sh grab_corefiles_excluded_bins known_issues.txt \
	patches 

patch-inc-tolerant:
	-make --ignore-errors patch-inc > patchinc.log 2>&1
	-cat patchinc.log

patch: patch-inc-tolerant patch-opt

patch-opt:
	@echo "============ Patch open posix test suite. ============"
	# upstream

	cp -fv patches/pthread_cancel/3-1.c $(TARGET)/testcases/open_posix_testsuite/conformance/interfaces/pthread_cancel/3-1.c
	cp -fv patches/pthread_rwlock_rdlock/4-1.c $(TARGET)/testcases/open_posix_testsuite/conformance/interfaces/pthread_rwlock_rdlock/4-1.c

ifeq ($(TESTVERSION),20120822)
	cp -fv patches/20120822/pthread_cond_broadcast-1-2.c $(TARGET)/testcases/open_posix_testsuite/conformance/interfaces/pthread_cond_broadcast/1-2.c
	cp -fv patches/20120822/sigset-6-1.c $(TARGET)/testcases/open_posix_testsuite/conformance/interfaces/sigset/6-1.c
	cp -fv patches/20120822/sigset-7-1.c $(TARGET)/testcases/open_posix_testsuite/conformance/interfaces/sigset/7-1.c
	cp -fv patches/20120822/pthread_cond_signal-1-1.c $(TARGET)/testcases/open_posix_testsuite/conformance/interfaces/pthread_cond_signal/1-1.c
endif
ifeq ($(TESTVERSION),20130109)
	cp -fv patches/20130109/aio_fsync-2-1.c $(TARGET)/testcases/open_posix_testsuite/conformance/interfaces/aio_fsync/2-1.c
	cp -fv patches/20130109/aio_fsync-3-1.c $(TARGET)/testcases/open_posix_testsuite/conformance/interfaces/aio_fsync/3-1.c
endif
ifeq ($(TESTVERSION),20130904)
	cp -fv patches/20130904/2-1.c $(TARGET)/testcases/open_posix_testsuite/conformance/interfaces/pthread_attr_setschedpolicy
endif
ifeq ($(TESTVERSION),20140115)
	cp -fv patches/20140115/run-tests.sh $(TARGET)/testcases/open_posix_testsuite/bin
endif
ifeq ($(TESTVERSION),20140422)
	cp -fv patches/20140422/run-tests.sh $(TARGET)/testcases/open_posix_testsuite/bin
endif

build: $(TARGET) build-all
	chmod +x ./runtest.sh
	chmod +x ./grab_corefiles.sh

patchonly-generic: $(TARGET) patch-inc-tolerant

patchonly: $(TARGET) patch

patch-and-build: $(TARGET) patch build

run: $(TARGET) patchonly
	chmod +x ./runtest.sh
	chmod +x ./grab_corefiles.sh
	@echo "============ Run Tests ============"
	LANG=C ./runtest.sh

$(METADATA):
	touch $(METADATA)
	@echo "Name:            $(TEST)" >$(METADATA)
	@echo "Description:     Open posix testsuite (from LTP)" >>$(METADATA)
	@echo "Path:            $(TEST_DIR)" >>$(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >>$(METADATA)
	@echo "License:         GPLv3" >>$(METADATA)
	@echo "Requires:        automake autoconf procmail flex bison rsyslog sysklogd util-linux-ng rpm-build" >> $(METADATA)
	@echo "Requires:        ntpdate kernel-headers redhat-lsb bc numactl time gcc" >> $(METADATA)
	@echo "Requires:        kernel-devel libaio-devel libcap-devel numactl-devel strace" >> $(METADATA)
	@echo "Owner:           Jan Stancek <jstancek@redhat.com>" >>$(METADATA)
	@echo "Releases:        RHEL7 RedHatEnterpriseLinux7 RedHatEnterpriseLinuxPegas7 RedHatEnterpriseLinuxAlternateArchitectures7" >>$(METADATA)
	@echo "Type:            KernelTier1" >>$(METADATA)
