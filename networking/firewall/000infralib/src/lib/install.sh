#!/bin/sh

###########################################################
# netfilter userspace tools installing
###########################################################
netfilter_install()
{
	local rpmname=$1
	local tarname=${rpmname%%-devel}
	[ -z $2 ] || { local rpmname=$1-$2; }

	rpm -q ${rpmname} && { return 0; }
	${YUM} install ${rpmname} -y && { return 0; }

	# netfilter common dependencies
	rpm -q git || ${YUM} install git -y
	rpm -q bzip2 || ${YUM} install bzip2 -y
	rpm -q gcc || ${YUM} install gcc -y
	rpm -q automake || ${YUM} install automake -y
	rpm -q bison || ${YUM} install bison -y
	rpm -q flex || ${YUM} install flex -y

	# latest versions from www.netfilter.org [updated on Sep.4th 2018]
	declare -A map_latest
	map_latest["iptables"]="1.8.0"
	map_latest["nftables"]="0.9.0"
	map_latest["libnftnl"]="1.1.1"
	map_latest["libnfnetlink"]="1.0.1"
	map_latest["libnetfilter_acct"]="1.0.3"
	map_latest["libnetfilter_log"]="1.0.1"
	map_latest["libnetfilter_queue"]="1.0.3"
	map_latest["libnetfilter_conntrack"]="1.0.7"
	map_latest["libnetfilter_cttimeout"]="1.0.0"
	map_latest["libnetfilter_cthelper"]="1.0.0"
	map_latest["conntrack-tools"]="1.4.5"
	map_latest["libmnl"]="1.0.4"
	map_latest["nfacct"]="1.0.2"
	map_latest["ulogd"]="2.0.7"
	if uname -r | grep el6 > /dev/null 2>&1; then
		# current versions from RHEL-6.10 [updated on Sep.4th 2018]
		declare -A map
		map["iptables"]="1.4.7"
		map["nftables"]=""
		map["libnftnl"]=""
		map["libnfnetlink"]="1.0.0"
		map["libnetfilter_acct"]=${map_latest["libnetfilter_acct"]}
		map["libnetfilter_log"]="1.0.1" # not from RHEL-6.10, from EPEL
		map["libnetfilter_queue"]="1.0.2" # not from RHEL-6.10, from RHEL-7.1
		map["libnetfilter_conntrack"]="1.0.4" # not from RHEL-6.10, from RHEL-7.0
		map["libnetfilter_cttimeout"]="1.0.0" # not from RHEL-6.10, from RHEL-7.2
		map["libnetfilter_cthelper"]="1.0.0" # not from RHEL-6.10, from RHEL-7.2
		map["conntrack-tools"]="1.4.2" # not from RHEL-6.10, from RHEL-7.2
		map["libmnl"]="1.0.2"
		map["nfacct"]=${map_latest["nfacct"]}
		map["ulogd"]=${map_latest["ulogd"]}
	elif uname -r | grep el7 > /dev/null 2>&1; then
		# current versions from RHEL-7.6-20180830.1 [updated on Sep.4th 2018]
		declare -A map
		map["iptables"]="1.4.21"
		map["nftables"]="0.8"
		map["libnftnl"]="1.0.8"
		map["libnfnetlink"]="1.0.1"
		map["libnetfilter_acct"]=${map_latest["libnetfilter_acct"]}
		map["libnetfilter_log"]="1.0.1"
		map["libnetfilter_queue"]="1.0.2"
		map["libnetfilter_conntrack"]="1.0.6"
		map["libnetfilter_cttimeout"]="1.0.0"
		map["libnetfilter_cthelper"]="1.0.0"
		map["conntrack-tools"]="1.4.4"
		map["libmnl"]="1.0.3"
		map["nfacct"]=${map_latest["nfacct"]}
		map["ulogd"]=${map_latest["ulogd"]}
	else
		declare -A map
		map["iptables"]=${map_latest["iptables"]}
		map["nftables"]=${map_latest["nftables"]}
		map["libnftnl"]=${map_latest["libnftnl"]}
		map["libnfnetlink"]=${map_latest["libnfnetlink"]}
		map["libnetfilter_acct"]=${map_latest["libnetfilter_acct"]}
		map["libnetfilter_log"]=${map_latest["libnetfilter_log"]}
		map["libnetfilter_queue"]=${map_latest["libnetfilter_queue"]}
		map["libnetfilter_conntrack"]=${map_latest["libnetfilter_conntrack"]}
		map["libnetfilter_cttimeout"]=${map_latest["libnetfilter_cttimeout"]}
		map["libnetfilter_cthelper"]=${map_latest["libnetfilter_cthelper"]}
		map["conntrack-tools"]=${map_latest["conntrack-tools"]}
		map["libmnl"]=${map_latest["libmnl"]}
		map["nfacct"]=${map_latest["nfacct"]}
		map["ulogd"]=${map_latest["ulogd"]}
	fi
	# if version is specified, use it first
	[ -n "$2" ] && { local version=$2; } || { local version=${map[${tarname}]}; }

	export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

	local finishedflag=false
	pushd /tmp
	test -e ${tarname}-${version} && { finishedflag=true; }
	test -e ${tarname} && { finishedflag=true; }
	$finishedflag || {
		wget http://www.netfilter.org/projects/${tarname}/files/${tarname}-${version}.tar.bz2 
		tar jxf ${tarname}-${version}.tar.bz2
		cd ${tarname}-${version}
		[ ${tarname} == "libnfnetlink" ] && { sed -i "s/-nostartfiles/-nostartfiles -lmnl/g" src/Makefile.in; }
		./configure --build=$(rpm --eval %{_host}) && make && make install && finishedflag=true
		cd ../
	}
	$finishedflag || { rm -f ${tarname}-${version}.tar.bz2; rm -rf ${tarname}-${version}; }
	$finishedflag || {
		git clone git://git.netfilter.org/${tarname}
		cd ${tarname}
		git checkout $(git tag | grep ${version})
		./autogen.sh && ./configure && make && make install && finishedflag=true
		cd ../
	}
	$finishedflag || { rm -rf ${tarname}; }
	popd
	$finishedflag || { return 1; }

	echo ${rpmname} | grep devel && {
		echo "/usr/local/lib" > /etc/ld.so.conf.d/${tarname}-x86_64.conf
		ldconfig
	}
	return 0
}
iptables_install()
{
	libmnl_install
	libnftnl_install
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install iptables $version
}
nftables_install()
{
	modinfo nf_tables > /dev/null 2>&1 || return
	rpm -q gmp-devel || { ${YUM} install gmp-devel -y; }
	rpm -q readline-devel || { ${YUM} install readline-devel -y; }
	libnftnl_install
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install nftables $version
}
libnftnl_install()
{
	modinfo nf_tables > /dev/null 2>&1 || return
	libmnl_install
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install libnftnl-devel $version
}
libnfnetlink_install()
{
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install libnfnetlink-devel $version
}
libnetfilter_acct_install()
{
	libmnl_install
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install libnetfilter_acct-devel $version
}
libnetfilter_log_install()
{
	libmnl_install
	libnfnetlink_install
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install libnetfilter_log-devel $version
}
libnetfilter_queue_install()
{
	libmnl_install
	libnfnetlink_install
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install libnetfilter_queue-devel $version
}
libnetfilter_conntrack_install()
{
	libmnl_install
	libnfnetlink_install
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install libnetfilter_conntrack-devel $version
}
libnetfilter_cttimeout_install()
{
	libmnl_install
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install libnetfilter_cttimeout-devel $version
}
libnetfilter_cthelper_install()
{
	libmnl_install
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install libnetfilter_cthelper-devel $version
}
conntrack_tools_install()
{
	libnetfilter_cttimeout_install
	libnetfilter_cthelper_install
	libnetfilter_queue_install
	libnetfilter_conntrack_install
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install conntrack-tools $version
}
libmnl_install()
{
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install libmnl-devel $version
}
nfacct_install()
{
	libnetfilter_acct_install
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install nfacct $version
}
ulogd_install()
{
	libnetfilter_conntrack_install
	libnetfilter_acct_install
	libnetfilter_log_install
	[ -n "$1" ] && { local version=$1; } || { local version=''; }
	netfilter_install ulogd $version
}

###########################################################
# python tools/libs installing
###########################################################
python_argparse_install()
{
	rpm -q python-libs-2.6.* && { ${YUM} install python-argparse -y; }
#	wget https://www.python.org/ftp/python/2.7/Python-2.7.tar.bz2
#	tar -xjvf Python-2.7.tar.bz2 
#	cd Python-2.7 && ./configure && make && make install
#	cd -
}
python_scapy_install()
{
	rpm -q python-devel || { ${YUM} install python-devel -y; }
	pushd /tmp
	test -e scapy-2.2.0.tar.gz || {
		local finishedflag=false
		git clone https://github.com/secdev/scapy.git
		cd scapy/
		git checkout v2.2.0
		# added by Long Xin <lxin@redhat.com>
		sed -i 's/sha,/hashlib,/' ./scapy/crypto/cert.py
		sed -i 's/popen2,/subprocess,/' ./scapy/crypto/cert.py
		sed -i '/No route found for/d' ./scapy/route6.py
		# added by Shuang Li <shuali@redhat.com>
		sed -i '430s/12/14/' ./scapy/layers/sctp.py
		python3 setup.py install && finishedflag=true
		cd ../
		$finishedflag || { rm -f scapy-2.2.0.tar.gz; rm -rf scapy-2.2.0; }
	}
	popd
}
python_NetfilterQueue_install()
{
	rpm -q kernel-devel-$(uname -r) || { ${YUM} install kernel-devel-$(uname -r) -y; }
	rpm -q python-devel || { ${YUM} install python-devel -y; } || ${YUM} install python3-devel -y
	rpm -q redhat-rpm-config || { ${YUM} install redhat-rpm-config -y; }
	libnetfilter_queue_install

	pushd /tmp
	test -e NetfilterQueue-0.3.tar.gz || {
		local finishedflag=false
		# https://pypi.org/project/NetfilterQueue
		wget http://pypi.python.org/packages/source/N/NetfilterQueue/NetfilterQueue-0.3.tar.gz --no-check-certificate
		tar zxf NetfilterQueue-0.3.tar.gz
		cd NetfilterQueue-0.3
		sed '2867i break;' -i ./netfilterqueue.c
		python3 setup.py install && finishedflag=true
		cd ../
		$finishedflag || { rm -f NetfilterQueue-0.3.tar.gz; rm -rf NetfilterQueue-0.3; }
	}
	popd
}

###########################################################
# iproute installing
###########################################################
iproute_install()
{
	tc -V > /dev/null 2>&1 || ${YUM} install iproute -y
	tc -V > /dev/null 2>&1 || ${YUM} install iproute-tc -y

	rpm -q git || ${YUM} install git -y
	rpm -q gcc || ${YUM} install gcc -y
	rpm -q bison || ${YUM} install bison -y
	rpm -q flex || ${YUM} install flex -y

	local result=0
	pushd /tmp
	test -e iproute2 || {
		git clone https://git.kernel.org/pub/scm/network/iproute2/iproute2.git
		cd iproute2/
		local version; result=1;
		for version in $(git tag --contains "v$(rpm -q iproute --info | grep Version | awk '{print $3}')" | sort -r); do
			git checkout $version
			make &&	make install && { result=0; break; }
			make clean
		done
		cd -
		[ $result -eq 0 ] || { rm -rf iproute2; }
	}
	popd
	return $result
}

###########################################################
# other userspace tools installing
###########################################################
netperf_install()
{
	rpm -q git || ${YUM} install git -y
	rpm -q gcc || ${YUM} install gcc -y
	rpm -q lksctp-tools-devel || { ${YUM} install lksctp-tools-devel -y; }
	netperf -V || {
		pushd /tmp
		rm -rf netperf/
		git clone https://github.com/HewlettPackard/netperf.git
		cd netperf/
		git checkout netperf-2.7.0
		./configure --enable-sctp && make && make install
		cd ../
		popd
	}
}
super_netperf_install()
{
	netperf_install
	rpm -q wget || ${YUM} install wget -y
	test -x /usr/local/bin/super_netperf || {
		wget https://raw.githubusercontent.com/borkmann/stuff/master/super_netperf -O /usr/local/bin/super_netperf
		chmod +x /usr/local/bin/super_netperf
	}
}
sipp_install()
{
	rpm -q autoconf || { ${YUM} install autoconf -y; }
	rpm -q automake || { ${YUM} install automake -y; }
	rpm -q ncurses-devel || { ${YUM} install ncurses-devel -y; }
	rpm -q gcc-c++ || { ${YUM} install gcc-c++ -y; }

	pushd /tmp
	test -x /usr/local/bin/sipp || {
		local finishedflag=false
		git clone https://github.com/SIPp/sipp.git
		cd sipp/
		git checkout v3.5.2
		sh build.sh && make install && { finishedflag=true; }
		cd -
		$finishedflag || { rm -rf sipp; }
	}
	popd
}
nfbpf_install()
{
	rpm -q libpcap-devel || { ${YUM} install libpcap-devel -y; }
	test -e /usr/local/bin/nfbpf_compile || {
		local finishedflag=false
		cd $(dirname $(readlink -f $BASH_SOURCE))
		gcc -o nfbpf_compile nfbpf_compile.c -lpcap && mv -f nfbpf_compile /usr/local/bin
		cd -
	}
}
hping3_install()
{
	which hping && return 0
	${YUM} install -y libpcap libpcap-devel tcl-devel
	ln -s /usr/include/pcap-bpf.h /usr/include/net/bpf.h
	git clone https://github.com/antirez/hping.git
	pushd hping
	./configure && make && make install
	popd
	which hping && return 0 || return 1
}
