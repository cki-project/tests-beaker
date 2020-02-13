#!/bin/bash
# This is for common install scripts

check_arch()
{
    if [ $(uname -m) == "aarch64" ] ; then
        sed -i 's/arm.*:Linux/aarch64*:Linux/' config.guess
    fi
    if [ $(uname -m) == "ppc64le" ] ; then
            sed -i 's/ppc64:Linux/ppc64*:Linux/' config.guess
    fi
}



lksctp_install()
{
    if [ -a /usr/include/netinet/sctp.h ]; then
        echo "lksctp have been installed"
        return 0
    fi

    # try yum first
    yum install -y lksctp-tools-devel

    if [ -a /usr/include/netinet/sctp.h ]; then
        echo "lksctp installed success"
        return 0
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
       rstrnt-abort -t recipe
    fi

    test_pass "lksctp-tools_install_pass"
    return 0
}


netperf_install()
{
        if netperf -V;then
                return 0
        fi

        # force install lksctp for netperf sctp support
        lksctp_install

        local OUTPUTFILE=`mktemp /mnt/testarea/tmp.XXXXXX`
        pushd ${NETWORK_COMMONLIB_DIR} 1>/dev/null
        git clone https://github.com/HewlettPackard/netperf
        pushd netperf
        ./autogen.sh
        check_arch
        if checksctp; then
                ./configure --enable-sctp && make && make install | tee -a $OUTPUTFILE
        else
                ./configure && make && make install | tee -a $OUTPUTFILE
        fi
        popd 1>/dev/null
        popd 1>/dev/null

        if ! netperf -V;then
                echo "WARN : Netperf install fail" | tee -a $OUTPUTFILE
                test_warn "Netperf_install_fail"
                rstrnt-abort -t recipe
        fi

        test_pass "Netperf_install_pass"
        return 0
}

