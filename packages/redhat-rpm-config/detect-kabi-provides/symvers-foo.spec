Summary: symvers-foo Package
Name: symvers-foo
Version: 1.0
Release: 1
Group: System Environment/Base
License: GPL
BuildArch: noarch
Provides: symvers-foo

%description

This is a test package

%build
mkdir -p %{buildroot}/boot
# choose some kernel
VER=`rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel | head -n 1 2> /dev/null`
# find the symver file

# was working while /boot/symvers existed
#SYMFILE=`ls /boot/symvers-$VER.gz`
#zcat $SYMFILE | head 2> /dev/null | gzip -c > %{buildroot}/boot/symvers-foo.gz

# due to rhel-8/bz1582110 we need to do this
# Ensure currently running kernel is used. There might be multiple kernels
# installed in /usr/src/kernels; pick currently running one (the tested
# one) to allow for patch impact testing (i.e., ensure that the patched
# kernel's Module.symvers is compatible w/ rpm utils)
SYMFILE=`find /usr/src/kernels -name Module.symvers -path "*$(uname -r)*" | egrep -v '(debug|zfcpdump)' | head -1`
head $SYMFILE | gzip -c > %{buildroot}/boot/symvers-foo.gz

%files
/boot/symvers-foo.gz

