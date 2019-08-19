#!/bin/bash
# Include rhts environment
. /usr/bin/rhts-environment.sh
. /usr/share/beakerlib/beakerlib.sh
. ../../include/install.sh

# Logic:
# 1. Download the SRPM and install the SRPM
# 2. Find the source tarball and decompress
# 3. Extract the lib/test_bpf.c
# 4. obj-m+= test_bpf.o in Makefile
# 5. make -C /lib/modules/`uname -r`/build M=`pwd` modules
# 6. insmod test_bpf.ko
# 7. journalctl -k --full | sed "s/$(hostname)//g"
# Expected result
# Apr 25 04:30:10  kernel: test_bpf: Summary: 349 PASSED, 0 FAILED, [0/341 JIT'ed]


DistName=`rpm -E %{?dist} | sed 's/[.0-9]//g'`
DistVer=`rpm -E %{?dist} | sed 's/[^0-9]//g'`
DUPARCH=`arch`
KVer=`uname -r | awk -F '-' '{print $1}'`
KDIST=`uname -r | sed "s/.$(arch)//g" | awk -F '.' '{print "."$NF}'`
KBUILD=`uname -r | awk -F '-' '{print $2}' | sed "s/.$(arch)//g" | sed "s/${KDIST}//g"`
KBuild=${KBuild:-${KBUILD}}
KBuildPrefix=`echo ${KBuild} | awk -F '.' '{print $1}'`

kernel_nvr=`uname -r | sed "s/.$(arch)//g"`
KVARIANT=`rpm -q --queryformat '%{sourcerpm}\n' -qf /boot/config-$(uname -r) | sed "s/.srpm//g;s/.src.rpm//g;s/-${kernel_nvr}//g"`

yum=$(select_yum_tool)

rlJournalStart
    rlPhaseStartSetup
        for i in libgcc glibc-static gcc gcc-c++ kernel-devel elfutils-libelf-devel binutils-devel libcap-devel ; do
            $yum install -y $i
        done
        # nfs-utils git util-linux createrepo genisoimage gcc gcc-c++ rpm-build kernel-abi-whitelists wget python-setuptools
        # yum install -y elfutils-libelf-devel binutils-devel newt-devel python-devel perl xmlto asciidoc perl-ExtUtils-Embed
        $yum download kernel-devel-$(uname -r)
        $yum download kernel-${kernel_nvr} --source
        rpm -ivh --force kernel-devel-$(uname -r).rpm
        rpm -ivh --force $(rpm -q --queryformat '%{sourcerpm}\n' -qf /boot/config-$(uname -r))
        $yum install -y kmod

        tar Jxf ~/rpmbuild/SOURCES/linux-${KVer}-${KBuild}*.tar.xz
        ksrcdir=`ls | grep linux-${KVer}-${KBuild} | grep -v tar`
        rm -rf test_bpf
        mkdir test_bpf
        find . -name test_bpf.c -exec cp {} test_bpf \;
        echo 'obj-m+= test_bpf.o' > test_bpf/Makefile
        pushd test_bpf
        BEAHARCH=${ARCH}
        unset ARCH
        make -C /lib/modules/`uname -r`/build M=`pwd` modules
        popd
        rmmod test_bpf
        ARCH=${BEAHARCH}
    rlPhaseEnd
    rlPhaseStartTest "Loading test_bpf"
        rlRun "insmod test_bpf/test_bpf.ko"
        sleep 5
        journalctl -k --full | sed "s/$(hostname)//g" &> insmod_test_bpf.log
        rlFileSubmit insmod_test_bpf.log
        rlRun "cat insmod_test_bpf.log | egrep -v 'Summary|signature' | grep -i test_bpf | grep -i failed" 1 "Should not find any failure"
        rmmod test_bpf
    rlPhaseEnd
rlJournalEnd
