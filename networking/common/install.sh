#!/bin/bash
# This is for common install scripts

# default URL
EPEL_BASEURL=${EPEL_BASEURL:-"https://dl.fedoraproject.org/pub/epel/"}

# select tool to manage package, which could be "yum" or "dnf"
function select_yum_tool() {
    if [ -x /usr/bin/dnf ]; then
        echo "/usr/bin/dnf"
    elif [ -x /usr/bin/yum ]; then
        echo "/usr/bin/yum"
    else
        return 1
    fi

    return 0
}

yum=$(select_yum_tool)

include_dir()
{
	# change path/kernel/networking/... to path/kernel/networking/common
	local path=$(pwd | sed 's#kernel/networking/.*#kernel/networking/common/#')
	echo $path | grep "/mnt/tests" || echo "/mnt/tests/kernel/networking/common/"
}

check_arch()
{
	if [ $(uname -m) == "aarch64" ] ; then
		sed -i 's/arm.*:Linux/aarch64*:Linux/' config.guess
	fi
	if [ $(uname -m) == "ppc64le" ] ; then
		sed -i 's/ppc64:Linux/ppc64*:Linux/' config.guess
	fi
}

# Ncat tcp transport will fail when we put it background vai & on RHEL7
# Install traditional nc for RHEL7.
# this function will only cp nc to /usr/bin/
nc_install()
{
	if [ "$(GetDistroRelease)" -ne 7 ];then
		echo "Only install on RHEL7"
		return 0
	fi

	if [ -a /usr/bin/nc ];then
		mv /usr/bin/nc /usr/bin/nc_bak
	fi

	${yum} install -y libbsd-devel
	wget $MY_URL/nc.tar.gz
	tar zxf nc.tar.gz

	pushd nc/
	make && make install
	if [ $? -ne 0 ];then
		test_fail "Install_NC_Fail"
	fi
	popd
}

lksctp_install()
{
	if [ -a /usr/include/netinet/sctp.h ]; then
		echo "lksctp have been installed"
		return 0
	fi

	# try yum first
	${yum} install -y lksctp-tools-devel

	if [ -a /usr/include/netinet/sctp.h ]; then
		echo "lksctp installed success"
		return 0
	fi

	distro="`uname -i`"
	if [ "`uname -r | grep 2.6.18`" ];then
		wget $MY_URL/lksctp-tools-1.0.6-3.el5.${distro}.rpm
		wget $MY_URL/lksctp-tools-devel-1.0.6-3.el5.${distro}.rpm
		rpm -ivh lksctp-tools* --force
	elif [ "`uname -r | grep 2.6.32`" ]; then
		if [ $distro = "x86_64" ];then
			wget $MY_URL/lksctp-tools-1.0.10-5.el6.${distro}.rpm
			wget $MY_URL/lksctp-tools-devel-1.0.10-5.el6.${distro}.rpm
		else
			wget $MY_URL/lksctp-tools-1.0.10-5.el6.i686.rpm
			wget $MY_URL/lksctp-tools-devel-1.0.10-5.el6.i686.rpm
		fi
		rpm -ivh lksctp-tools* --force
	else
		lksctp-tools_install
	fi

	return $?
}

lksctp-tools_install()
{
	[ -a /usr/local/bin/bindx_test ] && return 0

	local commit="57b003559078db2321e79b0c6dd85013fe7aa6e0"

	pushd ${NETWORK_COMMONLIB_DIR}
	git clone https://github.com/sctp/lksctp-tools
	pushd lksctp-tools
	patch -p1 < ../patch/lksctp.patch
	[ "$(GetDistroRelease)" -eq 5 ] && mkdir m4
	# An interim workaround, will remove this after upstream fix 
	# https://github.com/sctp/lksctp-tools/issues/24
	[ -f src/include/linux/sctp.h ] && git checkout 3c8bd0d26b64611c690f33f5802c734b0642c1d8
	./bootstrap && ./configure && make && make install
	if [ $? -ne 0 ]; then
		# upstream lksctp-tools begin to make use kernel UAPI header,
		# which may cause compilation error on previous kernels.
		# So checkout the commit just before below commit.
		#
		# commit 3c8bd0d26b64611c690f33f5802c734b0642c1d8
		# Author: Marcelo Ricardo Leitner <marcelo.leitner@gmail.com>
		# Date:   Tue Apr 17 20:17:14 2018 -0300

		# sctp.h: make use kernel UAPI header
		git checkout $commit
		make && make install
	fi
	popd
	popd

	if ! [ -a /usr/local/bin/bindx_test ];then
		echo "WARN : lksctp-tools install fail"
		test_warn "lksctp-tools_install_fail"
	fi

	test_pass "lksctp-tools_install_pass"
	return 0
}

scapy_install()
{
	python_2_6="Python-2.6.7.tgz"
	scapy_git="https://github.com/secdev/scapy.git"

	if [ "`python -V 2>&1 | grep -F 2.4`" ];then
		wget ${MY_URL}/${python_2_6}
		tar xvf ${python_2_6}
		pushd ${python_2_6%.tgz}
		./configure && make && make install
		if [ $? -ne 0 ];then
			log "Can't install Python 2.6"
			test_warn "Cant_insall_Python_2.6"
		fi
		popd
	fi

	scapy -h
	if [ $? -eq 0 ];then
		return 0
	fi

	rm -rf scapy
	git clone ${scapy_git}
	pushd scapy
	if [ "$(GetDistroRelease)" -le 6 ]; then
		git checkout v2.2.0
		# fix ICMPv6MLQuery().hashret()
		# https://github.com/secdev/scapy/pull/335/commits/a1880b5ccfa0720d07aa77636b50af5e66f65ce9
		# This patch was applied to v2.3.3-13-ga1880b5, so the versions >= v2.4.0 have fixed the problem.
		# We can receive ICMPv6MLQuery packet via public NIC(which has ip like 10.*.*.*)which will break off scapy
		git cherry-pick a1880b5ccfa0720d07aa77636b50af5e66f65ce9
	else
		# Install version >= 2.4.0 on rhel7/8
		# git checkout v2.4.0
		# This commit resolves the problem we met when running sctp/fuzz_init/
		git checkout 900e8da87b4c5fe78d4253ded6f6132b2c268ddc
	fi
	if /usr/libexec/platform-python -V &> /dev/null; then
		/usr/libexec/platform-python ./setup.py install
	elif python3 -V &> /dev/null ; then
		python3 ./setup.py install
	elif python2 -V &> /dev/null; then
		python2 ./setup.py install
	fi
	which scapy
	if [ $? -ne 0 ];then
		log "Scapy install failed"
		test_warn "Scapy_install_failed"
	fi
	popd
}

netperf_install()
{
	if netperf -V;then
		return 0
	fi

	# force install lksctp for netperf sctp support
	lksctp_install

	local OUTPUTFILE=`mktemp /mnt/testarea/tmp.XXXXXX`
        SRC_NETPERF=${SRC_NETPERF:-"https://github.com/HewlettPackard/netperf/archive/netperf-2.7.0.tar.gz"}
	pushd ${NETWORK_COMMONLIB_DIR} 1>/dev/null
	wget -nv -N $SRC_NETPERF
	tar xvzf $(basename $SRC_NETPERF)
	cd netperf-netperf-2.7.0
	check_arch
	lsmod | grep sctp
	if [ $? -ne 0 ];then
		modprobe sctp
	fi
	if checksctp; then
		./configure --enable-sctp && make && make install | tee -a $OUTPUTFILE
	else
		./configure && make && make install | tee -a $OUTPUTFILE
	fi
	popd 1>/dev/null

	if ! netperf -V;then
		echo "WARN : Netperf install fail" | tee -a $OUTPUTFILE
		test_warn "Netperf_install_fail"
	fi

	test_pass "Netperf_install_pass"
	return 0
}
iperf3_install()
{
	${yum} install -y iperf3
	iperf3 -v && return 0
	local iperf3_version="iperf-3.1.3"
	pushd ${NETWORK_COMMONLIB_DIR}
	wget https://iperf.fr/download/source/${iperf3_version}-source.tar.gz
	tar -zxvf ${iperf3_version}-source.tar.gz
	pushd ${iperf3_version}
	./configure && make && make install
	popd
	popd
	iperf3 -v  && return 0 || return 1
}
iperf_install()
{
	which iperf && return 0
	CUR_PWD=$(pwd)
	${yum} install -y gcc-c++ make gcc
	# grab sctp-enabled iperf and install it:
	IPERF_FILE="iperf-2.0.10.tar.gz"
        # download iperf-2 from sourceforge mirrors download page
        wget --trust-server-names https://sourceforge.net/projects/iperf2/files/${IPERF_FILE}/download
	if [[ $? != 0 ]]; then
		echo "${TEST} fail grabbing iperf source"
		test_warn "Grabbing iperf-2 source failed"
		rstrnt-abort -t recipe
		exit
	fi
	tar xf ${IPERF_FILE}
	if [[ $? != 0 ]]; then
		echo "${TEST} fail extracting ${IPERF_FILE}"
		rstrnt-report-result ${TEST}_extract_iperf FAIL 1
		exit 1
	fi
	BUILD_DIR="${IPERF_FILE%.tar.gz}"
	cd ${BUILD_DIR}
	check_arch
	./configure && make && make install
	if [[ $? != 0 ]]; then
		echo "${TEST} fail installing iperf"
		rstrnt-report-result ${TEST}_install_iperf FAIL 1
		exit 1
	fi
	IPERF_EXEC=$(which iperf)
	if [[ $? != 0 ]]; then
		echo "${TEST} fail finding sctp_iperf executable"
		rstrnt-report-result ${TEST}_find_iperf FAIL 1
		exit 1
	fi
	cd ${CUR_PWD}
}
sockperf_install(){
	which sockperf && return 0
	${yum} install -y gcc-c++ automake autoconf
	local sockperf_v=${1:-"3.6"}
	pushd ${NETWORK_COMMONLIB_DIR}
	wget https://github.com/Mellanox/sockperf/archive/${sockperf_v}.tar.gz
	tar -zxvf ${sockperf_v}.tar.gz
	pushd sockperf-${sockperf_v}
	./autogen.sh
	./configure --prefix=/usr/local/ --enable-test  --enable-tool --enable-debug
	make && make install
	popd
	popd
	sockperf -v  && return 0 || return 1
}
packetdrill_install()
{
        if [ -x /usr/local/bin/packetdrill ];then
                log "packetdrill has been installed"
                return 0
        fi
        pushd ${NETWORK_COMMONLIB_DIR}
        ${yum} install -y bison flex glibc-static
        git clone https://github.com/google/packetdrill.git
        pushd packetdrill
        patch -p1 < ../patch/packetdrill_rm_ufo_flag.patch
        patch -p1 < ../patch/packetdrill_cases.patch
        # pegas kernel has this patch "tcp: limit GSO packets to half cwnd", need do a workaround.
        # pegas kernel also need improve undo case since another commit.
	[ $(echo "`uname -r| awk -F. '{print $1"."$2}'` >= 4.11"|bc -l) = 1 ] && \
		patch -p1 < ../patch/packetdrill_cases.pegas.patch
        pushd gtests/net/packetdrill
        ./configure
        make
        popd
        popd
        popd
        ln -s ${NETWORK_COMMONLIB_DIR}/packetdrill/gtests/net/packetdrill/packetdrill /usr/local/bin/packetdrill
        [ -x /usr/local/bin/packetdrill ] && return 0 || return 1
}

libsctp_static_install()
{
	local commit="57b003559078db2321e79b0c6dd85013fe7aa6e0"

	[ -a /usr/lib64/libsctp.a ] && return 0

	pushd ${NETWORK_COMMONLIB_DIR}
	rm -rf lksctp-tools
	git clone https://github.com/sctp/lksctp-tools
	pushd lksctp-tools
	./bootstrap && ./configure && make
	if [ $? -ne 0 ]; then
		# Please see comment in lksctp-tools_install()
		git checkout $commit
		make
	fi
	popd
	popd
	[ -a /usr/include/netinet/sctp.h ] || \ 
	ln -s ${NETWORK_COMMONLIB_DIR}/lksctp-tools/src/include/netinet/sctp.h /usr/include/netinet/sctp.h
	ln -sf ${NETWORK_COMMONLIB_DIR}/lksctp-tools/src/lib/.libs/libsctp.a /usr/lib64/libsctp.a
	[ -a /usr/lib64/libsctp.a ] && return 0 || return 1
}

packetdrill_uninstall()
{
	rm -rf /usr/local/bin/packetdrill
	pushd ${NETWORK_COMMONLIB_DIR}
	rm -rf packetdrill
	popd
}

packetdrill_sctp_install()
{
	[ -x /usr/local/bin/packetdrill_sctp ] && return 0
	# depends on sctp static lib
	libsctp_static_install

	pushd ${NETWORK_COMMONLIB_DIR}
	rpm -q glibc-static || ${yum} install -y glibc-static
	rm -rf packetdrill_sctp
	git clone https://github.com/nplab/packetdrill.git packetdrill_sctp
	local packetdrill_subdir="packetdrill_sctp/gtests/net/packetdrill"
	pushd $packetdrill_subdir
	./configure && make
	popd
	popd
	ln -sf ${NETWORK_COMMONLIB_DIR}/${packetdrill_subdir}/packetdrill /usr/local/bin/packetdrill_sctp
	[ -x /usr/local/bin/packetdrill_sctp ] && return 0 || return 1
}
# mptcp hasn't been brought into rhts kernel by now. hope it will be useful for future.
# bz1191716: [RFE] mptcp support
#packetdrill_mptcp_install()
#{
#        if [ -x /usr/local/bin/packetdrill_mptcp ];then
#                log "packetdrill_mptcp has been installed"
#                return 0
#        fi
#        pushd ${NETWORK_COMMONLIB_DIR}
#        yum install -y bison flex glibc-static openssl-devel openssl-static zlib-static
#        rm -rf packetdrill_mptcp
#        git clone https://github.com/aschils/packetdrill_mptcp.git packetdrill_mptcp
#        local packetdrill_mptcp_subdir="packetdrill_mptcp/gtests/net/packetdrill"
#        pushd $packetdrill_mptcp_subdir
#        ./configure && make
#        popd
#        popd
#        ln -s ${NETWORK_COMMONLIB_DIR}/$packetdrill_mptcp_subdir/packetdrill /usr/local/bin/packetdrill_mptcp
#        [ -x /usr/local/bin/packetdrill_mptcp ] && return 0 || return 1
#        popd
#}

git_install()
{
	# only check whether git is installed at present
	# todo : add git install function
	if [ -a /usr/bin/git ];then
		log "Git have been installed"
		return 0
	else
		log "Git haven't been installed"
		test_warn "No_git"
	fi
}

tunctl_install()
{
	which tunctl && return
	pushd ${NETWORK_COMMONLIB_DIR}
	gcc patch/tunctl.c -o tunctl
	cp tunctl /usr/local/bin/
	popd
}

mtools_install()
{
	[ -f /usr/local/bin/msend ] && return 0
	pushd /usr/local/src/mtools
	sh build.sh
	popd
}

omping_install()
{
	which omping && return 0
	# try yum first
	${yum} install -y omping && return 0
	#git clone git://git.fedorahosted.org/git/omping.git
	# fedorahosted is retired
	git clone https://github.com/troglobit/omping.git
	pushd omping
	make && make install
	popd
	which omping && return 0 || return 1
}

hping3_install()
{
	which hping && return 0
	${yum} install -y libpcap-devel tcl-devel
	ln -s /usr/include/pcap/bpf.h /usr/include/net/bpf.h
	git clone https://github.com/antirez/hping.git
	pushd hping
	./configure && make && make install
	popd
	which hping && return 0 || return 1
}

httpd24_install()
{
	rpm -q httpd24-httpd && return 0
	rhscl_repo_install
	${yum} install -y httpd24 httpd24-mod_ssl && return 0
}

epel_release_install()
{
	local release=$(GetDistroRelease)
	local epel_fullurl=${EPEL_BASEURL}/epel-release-latest-${release}.noarch.rpm

	[ "`rpm -qa | grep epel-release`" ] && return 0
	# We rarely run test on RHEL5, no epel-release for RHEL8 currently
	if [ "$release" -le 5 -o "$release" -ge 8 ]; then
		return 0
	fi
	rpm -ivh --force --nodeps $epel_fullurl && return 0 || return 1
}

devtoolset_install()
{
	ver=${1:-"8"}
	rpm -q devtoolset-${ver}-toolchain && return 0
	rhscl_repo_install
	${yum} install -y devtoolset-${ver}-toolchain
}

