#!/bin/sh

repo_epel_6_set()
{
	if ! test -e /etc/yum.repos.d/epel.repo; then
		cat > /etc/yum.repos.d/epel.repo << REPO
[epel]
name=epel
baseurl=https://download.fedoraproject.org/pub/epel/6/\$basearch/
enabled=1
gpgcheck=0
skip_if_unavailable=1
REPO
	fi
}
repo_epel_7_set()
{
	if ! test -e /etc/yum.repos.d/epel.repo; then
		cat > /etc/yum.repos.d/epel.repo << REPO
[epel]
name=epel
baseurl=https://download.fedoraproject.org/pub/epel/7/\$basearch/
enabled=1
gpgcheck=0
skip_if_unavailable=1
REPO
	fi
}
repo_centos_set()
{
	if ! test -e /etc/yum.repos.d/CentOS-Base.repo; then
		cat /etc/yum.repos.d/CentOS-Base.repo << REPO
# CentOS-Base.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the 
# remarked out baseurl= line instead.
#
#

[base]
name=CentOS-\$releasever - Base
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=os&infra=\$infra
#baseurl=http://mirror.centos.org/centos/\$releasever/os/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#released updates 
[updates]
name=CentOS-\$releasever - Updates
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=updates&infra=\$infra
#baseurl=http://mirror.centos.org/centos/\$releasever/updates/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-\$releasever - Extras
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=extras&infra=\$infra
#baseurl=http://mirror.centos.org/centos/\$releasever/extras/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-\$releasever - Plus
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=centosplus&infra=\$infra
#baseurl=http://mirror.centos.org/centos/\$releasever/centosplus/\$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

REPO
	fi
	if ! test -e /etc/yum.repos.d/CentOS-CR.repo; then
		cat /etc/yum.repos.d/CentOS-CR.repo << REPO
# CentOS-CR.repo
#
# The Continuous Release ( CR )  repository contains rpms that are due in the next
# release for a specific CentOS Version ( eg. next release in CentOS-7 ); these rpms
# are far less tested, with no integration checking or update path testing having
# taken place. They are still built from the upstream sources, but might not map 
# to an exact upstream distro release.
#
# These packages are made available soon after they are built, for people willing 
# to test their environments, provide feedback on content for the next release, and
# for people looking for early-access to next release content.
#
# The CR repo is shipped in a disabled state by default; its important that users 
# understand the implications of turning this on. 
#
# NOTE: We do not use a mirrorlist for the CR repos, to ensure content is available
#       to everyone as soon as possible, and not need to wait for the external
#       mirror network to seed first. However, many local mirrors will carry CR repos
#       and if desired you can use one of these local mirrors by editing the baseurl
#       line in the repo config below.
#

[cr]
name=CentOS-\$releasever - cr
baseurl=http://mirror.centos.org/centos/\$releasever/cr/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

REPO
	fi
	if ! test -e /etc/yum.repos.d/CentOS-Debuginfo.repo; then
		cat /etc/yum.repos.d/CentOS-Debuginfo.repo << REPO
# CentOS-Debug.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#

# All debug packages from all the various CentOS-7 releases
# are merged into a single repo, split by BaseArch
#
# Note: packages in the debuginfo repo are currently not signed
#

[base-debuginfo]
name=CentOS-7 - Debuginfo
baseurl=http://debuginfo.centos.org/7/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-Debug-7
enabled=0

REPO
	fi
	if ! test -e /etc/yum.repos.d/CentOS-fasttrack.repo; then
		cat /etc/yum.repos.d/CentOS-fasttrack.repo << REPO
#CentOS-fasttrack.repo

[fasttrack]
name=CentOS-7 - fasttrack
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=fasttrack&infra=\$infra
#baseurl=http://mirror.centos.org/centos/\$releasever/fasttrack/\$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

REPO
	fi
	if ! test -e /etc/yum.repos.d/CentOS-Media.repo; then
		cat /etc/yum.repos.d/CentOS-Media.repo << REPO
# CentOS-Media.repo
#
#  This repo can be used with mounted DVD media, verify the mount point for
#  CentOS-7.  You can use this repo and yum to install items directly off the
#  DVD ISO that we release.
#
# To use this repo, put in your DVD and use it with the other repos too:
#  yum --enablerepo=c7-media [command]
#  
# or for ONLY the media repo, do this:
#
#  yum --disablerepo=\* --enablerepo=c7-media [command]

[c7-media]
name=CentOS-\$releasever - Media
baseurl=file:///media/CentOS/
        file:///media/cdrom/
        file:///media/cdrecorder/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

REPO
	fi
	if ! test -e /etc/yum.repos.d/CentOS-Sources.repo; then
		cat /etc/yum.repos.d/CentOS-Sources.repo << REPO
# CentOS-Sources.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the 
# remarked out baseurl= line instead.
#
#

[base-source]
name=CentOS-\$releasever - Base Sources
baseurl=http://vault.centos.org/centos/\$releasever/os/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#released updates 
[updates-source]
name=CentOS-\$releasever - Updates Sources
baseurl=http://vault.centos.org/centos/\$releasever/updates/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras-source]
name=CentOS-\$releasever - Extras Sources
baseurl=http://vault.centos.org/centos/\$releasever/extras/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus-source]
name=CentOS-\$releasever - Plus Sources
baseurl=http://vault.centos.org/centos/\$releasever/centosplus/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

REPO
	fi
	if ! test -e /etc/yum.repos.d/CentOS-Vault.repo; then
		cat /etc/yum.repos.d/CentOS-Vault.repo << REPO
# CentOS Vault contains rpms from older releases in the CentOS-7 
# tree.

#c7.0.1406
[C7.0.1406-base]
name=CentOS-7.0.1406 - Base
baseurl=http://vault.centos.org/7.0.1406/os/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.0.1406-updates]
name=CentOS-7.0.1406 - Updates
baseurl=http://vault.centos.org/7.0.1406/updates/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.0.1406-extras]
name=CentOS-7.0.1406 - Extras
baseurl=http://vault.centos.org/7.0.1406/extras/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.0.1406-centosplus]
name=CentOS-7.0.1406 - CentOSPlus
baseurl=http://vault.centos.org/7.0.1406/centosplus/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.0.1406-fasttrack]
name=CentOS-7.0.1406 - CentOSPlus
baseurl=http://vault.centos.org/7.0.1406/fasttrack/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

# C7.1.1503
[C7.1.1503-base]
name=CentOS-7.1.1503 - Base
baseurl=http://vault.centos.org/7.1.1503/os/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.1.1503-updates]
name=CentOS-7.1.1503 - Updates
baseurl=http://vault.centos.org/7.1.1503/updates/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.1.1503-extras]
name=CentOS-7.1.1503 - Extras
baseurl=http://vault.centos.org/7.1.1503/extras/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.1.1503-centosplus]
name=CentOS-7.1.1503 - CentOSPlus
baseurl=http://vault.centos.org/7.1.1503/centosplus/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.1.1503-fasttrack]
name=CentOS-7.1.1503 - CentOSPlus
baseurl=http://vault.centos.org/7.1.1503/fasttrack/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

# C7.2.1511
[C7.2.1511-base]
name=CentOS-7.2.1511 - Base
baseurl=http://vault.centos.org/7.2.1511/os/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.2.1511-updates]
name=CentOS-7.2.1511 - Updates
baseurl=http://vault.centos.org/7.2.1511/updates/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.2.1511-extras]
name=CentOS-7.2.1511 - Extras
baseurl=http://vault.centos.org/7.2.1511/extras/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.2.1511-centosplus]
name=CentOS-7.2.1511 - CentOSPlus
baseurl=http://vault.centos.org/7.2.1511/centosplus/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.2.1511-fasttrack]
name=CentOS-7.2.1511 - CentOSPlus
baseurl=http://vault.centos.org/7.2.1511/fasttrack/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

# C7.3.1611
[C7.3.1611-base]
name=CentOS-7.3.1611 - Base
baseurl=http://vault.centos.org/7.3.1611/os/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.3.1611-updates]
name=CentOS-7.3.1611 - Updates
baseurl=http://vault.centos.org/7.3.1611/updates/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.3.1611-extras]
name=CentOS-7.3.1611 - Extras
baseurl=http://vault.centos.org/7.3.1611/extras/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.3.1611-centosplus]
name=CentOS-7.3.1611 - CentOSPlus
baseurl=http://vault.centos.org/7.3.1611/centosplus/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.3.1611-fasttrack]
name=CentOS-7.3.1611 - CentOSPlus
baseurl=http://vault.centos.org/7.3.1611/fasttrack/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

REPO
	fi
}
repo_fedora_set()
{
	if ! test -e /etc/yum.repos.d/fedora-cisco-openh264.repo; then
		cat /etc/yum.repos.d/fedora-cisco-openh264.repo << REPO
[fedora-cisco-openh264]
name=Fedora \$releasever openh264 (From Cisco) - \$basearch
baseurl=https://codecs.fedoraproject.org/openh264/\$releasever/\$basearch/
type=rpm
enabled=0
enabled_metadata=1
metadata_expire=14d
repo_gpgcheck=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

[fedora-cisco-openh264-debuginfo]
name=Fedora \$releasever openh264 (From Cisco) - \$basearch - Debug
failovermethod=priority
baseurl=https://codecs.fedoraproject.org/openh264/\$releasever/\$basearch/debug/
type=rpm
enabled=0
metadata_expire=28d
repo_gpgcheck=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

REPO
	fi
	if ! test -e /etc/yum.repos.d/fedora.repo; then
		cat /etc/yum.repos.d/fedora.repo << REPO
[fedora]
name=Fedora \$releasever - \$basearch
failovermethod=priority
#baseurl=http://download.fedoraproject.org/pub/fedora/linux/releases/\$releasever/Everything/\$basearch/os/
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-\$releasever&arch=\$basearch
enabled=0
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

[fedora-debuginfo]
name=Fedora \$releasever - \$basearch - Debug
failovermethod=priority
#baseurl=http://download.fedoraproject.org/pub/fedora/linux/releases/\$releasever/Everything/\$basearch/debug/tree/
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-debug-\$releasever&arch=\$basearch
enabled=0
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

[fedora-source]
name=Fedora \$releasever - Source
failovermethod=priority
#baseurl=http://download.fedoraproject.org/pub/fedora/linux/releases/\$releasever/Everything/source/tree/
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-source-\$releasever&arch=\$basearch
enabled=0
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

REPO
	fi
	if ! test -e /etc/yum.repos.d/fedora-updates.repo; then
		cat /etc/yum.repos.d/fedora-updates.repo << REPO
[updates]
name=Fedora \$releasever - \$basearch - Updates
failovermethod=priority
#baseurl=http://download.fedoraproject.org/pub/fedora/linux/updates/\$releasever/Everything/\$basearch/os/
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f\$releasever&arch=\$basearch
enabled=1
repo_gpgcheck=0
type=rpm
gpgcheck=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

[updates-debuginfo]
name=Fedora \$releasever - \$basearch - Updates - Debug
failovermethod=priority
#baseurl=http://download.fedoraproject.org/pub/fedora/linux/updates/\$releasever/Everything/\$basearch/debug/tree/
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-released-debug-f\$releasever&arch=\$basearch
enabled=0
repo_gpgcheck=0
type=rpm
gpgcheck=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

[updates-source]
name=Fedora \$releasever - Updates Source
failovermethod=priority
#baseurl=http://download.fedoraproject.org/pub/fedora/linux/updates/\$releasever/Everything/source/tree/
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-released-source-f\$releasever&arch=\$basearch
enabled=0
repo_gpgcheck=0
type=rpm
gpgcheck=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

REPO
	fi
	if ! test -e /etc/yum.repos.d/fedora-updates-testing.repo; then
		cat /etc/yum.repos.d/fedora-updates-testing.repo << REPO
[updates-testing]
name=Fedora \$releasever - \$basearch - Test Updates
failovermethod=priority
#baseurl=http://download.fedoraproject.org/pub/fedora/linux/updates/testing/\$releasever/Everything/\$basearch/os/
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-testing-f\$releasever&arch=\$basearch
enabled=0
repo_gpgcheck=0
type=rpm
gpgcheck=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

[updates-testing-debuginfo]
name=Fedora \$releasever - \$basearch - Test Updates Debug
failovermethod=priority
#baseurl=http://download.fedoraproject.org/pub/fedora/linux/updates/testing/\$releasever/Everything/\$basearch/debug/tree/
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-testing-debug-f\$releasever&arch=\$basearch
enabled=0
repo_gpgcheck=0
type=rpm
gpgcheck=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

[updates-testing-source]
name=Fedora \$releasever - Test Updates Source
failovermethod=priority
#baseurl=http://download.fedoraproject.org/pub/fedora/linux/updates/testing/\$releasever/Everything/source/tree/
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-testing-source-f\$releasever&arch=\$basearch
enabled=0
repo_gpgcheck=0
type=rpm
gpgcheck=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False

REPO
	fi
}

