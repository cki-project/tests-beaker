%define buildforkernels current
%define _use_internal_dependency_generator  0
%define kver %(uname -r)

Summary: testprov kernel module
Name: testprov-kmod
Version: 1.0
Release: 1
Group: System Environment/Base
License: GPL
Provides: testprov-kmod
Requires(post):   /sbin/depmod
Requires(postun): /sbin/depmod
BuildRequires: xz
BuildRequires: rpm-build
BuildRequires: kernel-devel
BuildRequires: elfutils-libelf-devel
Source0: testprov-kmod.tar.gz

%description

This is a test package created to test bug 1622016

%prep
tar -xzf %{_sourcedir}/testprov-kmod.tar.gz -C %{_builddir}

%build
make

%install
mkdir -p %{buildroot}/lib/modules/%{kver}/testprov
mkdir -p %{buildroot}/usr/share/kmod-redhat-testprov
cp testprov.ko %{buildroot}/lib/modules/%{kver}/testprov
cp Module.symvers %{buildroot}/usr/share/kmod-redhat-testprov

%post
/sbin/depmod -a

%postun
/sbin/depmod -a

%files
/lib/modules/%{kver}/testprov/testprov.ko
/usr/share/kmod-redhat-testprov/Module.symvers
