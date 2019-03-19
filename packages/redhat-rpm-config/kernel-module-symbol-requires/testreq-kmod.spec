%define buildforkernels current
%define _use_internal_dependency_generator  0
%define kver %(uname -r)

Summary: testreq kernel module
Name: testreq-kmod
Version: 1.0
Release: 1
Group: System Environment/Base
License: GPL
Provides: testreq-kmod
Requires: testprov-kmod
Requires(post):   /sbin/depmod
Requires(postun): /sbin/depmod
BuildRequires: xz
BuildRequires: rpm-build
BuildRequires: kernel-devel
BuildRequires: elfutils-libelf-devel
BuildRequires: testprov-kmod
Source0: testreq-kmod.tar.gz

%description

This is a test package created to test bug 1622016

%prep
tar -xzf %{_sourcedir}/testreq-kmod.tar.gz -C %{_builddir}

%build
make

%install
mkdir -p %{buildroot}/lib/modules/%{kver}/testreq
mkdir -p %{buildroot}/usr/share/kmod-redhat-testreq
cp testreq.ko %{buildroot}/lib/modules/%{kver}/testreq
cp Module.symvers %{buildroot}/usr/share/kmod-redhat-testreq

%post
/sbin/depmod -a

%postun
/sbin/depmod -a

%files
/lib/modules/%{kver}/testreq/testreq.ko
/usr/share/kmod-redhat-testreq/Module.symvers
