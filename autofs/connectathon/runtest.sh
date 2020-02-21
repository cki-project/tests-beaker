#!/bin/bash
# Copyright (c) 2019 Red Hat, Inc. All rights reserved. This copyrighted material
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#

# Include rhts environment
. ../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1
. ./vercmp || exit 1

# Include cki library
. ../../cki_lib/libcki.sh

echo -e "\n"s{$SERVERS} c{$CLIENTS}
MultiHost=yes
ServerNeed=2 ClientNeed=1

read Client nil <<<$CLIENTS
read Server1 Server2 nil <<<$SERVERS
role=server; echo "$CLIENTS" | grep -q "$HOSTNAME" && role=client
#===============================================================================
OPWD=`pwd`
export SERVER1=$Server1 SERVER2=$Server2
pkgPath=$OPWD/cthon_automount

echo  "{INFO} cthon_automount install ..." | tee -a ${OUTPUTFILE} 
(cd $pkgPath/src; make clean && make && make install && make clean)
#===============================================================================
source $pkgPath/src/tests.init

[[ -f /usr/bin/python ]] || {
	if [[ -f /usr/bin/python2 ]]; then
		alternatives --set python /usr/bin/python2
	elif [[ -f /usr/bin/python3 ]]; then
		alternatives --set python /usr/bin/python3
	fi
}

SUCCESS=0
FAIL=1
NISDOMAIN="autofs.test"

# output the test env info:(Test name, distro, hostname, kernel, pkg versions)
envinfo() {
    rlLog "{INFO} Test env info:"
    rlLog "------------------------------------------------"
    rlLog "Time & CURDIR : [`date '+%F %T'` @$PWD]"
    rlLog "Case Name     : $TEST"
    rlLog '$HOSTNAME     : '$HOSTNAME
    rlLog "Distro Info   : `lsb_release -sir` : $DISTRO_BUILD"
    rlLog "NVR & host    : `uname -a`"
    rlLog "LANG          : $LANG"
    rlLog "cmdline       :"; cat /proc/cmdline | sed 's/^/\t/'
    rlLog "Package Info  :"
        rpm -q `for p in $PKG_LIST "$@"; do echo $p; done|sort -u` 2>&1 |
                sed 's/^/\t/'
    rlLog "------------------------------------------------"
}


yp_server_setup() {
	local ypinit="/usr/lib64/yp/ypinit"
	#we choose server1 as yp server
	echo "$Server1" | grep -q "$HOSTNAME" || return $SUCCESS
	rlFileBackup "/var/yp/Makefile" "/etc/ypserv.conf"

	domainname "$NISDOMAIN"
	>/etc/ypserv.conf

	cp "$pkgPath/config/yp_makefile" /var/yp/Makefile

	touch /etc/auto.master
	touch /etc/auto.nis

	if [ ! -f "$ypinit" ]; then
		ypinit="/usr/lib/yp/ypinit"
	fi

	systemctl restart ypserv || (echo "restart ypserv failed"; return $FAIL)
	$ypinit -m < /dev/null || (echo "ypinit -m failed"; return $FAIL)

	return $SUCCESS
}

yp_client_setup() {
	rlFileBackup "/etc/yp.conf"

	domainname "$NISDOMAIN"
	echo "domain $NISDOMAIN server $Server1" > /etc/yp.conf
	systemctl restart ypbind  || (echo "restart ypbind filed"; return $FAIL)
	ypcat -k auto.nis

	return $SUCCESS
}

cthon_setup() {
	rlLog "{INFO} cthon_automount setup ..."
	cd $pkgPath/bin
	rlRun "./setup -a" "0-255"
	if [ $? -ne 0 ]; then
		cki_abort_task "Failed to configure cthon test environment "
        fi
	mkdir -p $AUTO_CLIENT_MNTPNT
	test -n "$DEBUG" && chmod 777 $AUTO_CLIENT_MNTPNT

	# because the linux automounter does not support included maps,
	# we have to copy the auto.master file to /etc/
	[ "${AUTOMAP_DIR}" != /etc ] && cat $AUTOMAP_DIR/auto.master >/etc/auto.master
	restorecon /etc/auto.master
	restorecon -F -R -v $AUTOMAP_DIR
}

client() {
    rlPhaseStartSetup do-$role-Setup-Client
	rlFileBackup /etc/sysconfig/{autofs,nfs} /etc/exports /etc/auto.master
	rlRun 'rhts-sync-block -s SERVER_READY $Server1 $Server2'
	rlRun 'mkdir -p /export/'
	rlRun 'echo "/export/   *(rw,no_root_squash)" >> /etc/exports'
	rlRun "systemctl restart nfs-server" "0-255"
	if [ $? -ne 0 ]; then
		cki_abort_task "Failed to restart client nfs server"
	fi
	cthon_setup
	rlRun 'cat /etc/auto.master'
	rlRun 'echo "LOGGING=\"debug\"" >>/etc/sysconfig/autofs'
	yp_client_setup
	if [ $? -ne 0 ]; then
		cki_abort_task "Errors on NIS/YP client configuration"
	fi
	rlRun "systemctl restart autofs" "0-255"
	if [ $? -ne 0 ]; then
		cki_abort_task "Failed to restart client nfs server, aborting the task"
        fi
	rlRun 'mount -t autofs'
	rlRun 'automount -m'

        for h in $SERVERS $CLIENTS; do
		rlRun "showmount -e $h"
	done
	rlRun 'pushd $pkgPath/bin'
    	rlPhaseEnd

	for test in test.*; do
    		rlPhaseStartTest do-$role-Test-$test
			case "$test" in
				"test.net" | "test.net1")
				rlRun "./$test $Server1 $Server2" "0,2" "Running $test with $Server1, and $Server2"
				if [ $? -eq 2 ]; then
					rlRun 'rhts-sync-set -s DONE${TEST}'
					rlFileRestore
					cki_abort_task "Failed to configure $test environment with <$Server1>, and '<$Server2>"
				fi
			;;
			*)#default
				rlRun "./$test" "0,2" "Running $test"
				if [ $? -eq 2 ]; then
					rlRun 'rhts-sync-set -s DONE${TEST}'
					rlFileRestore
					cki_abort_task "Failed to configure $test environment"
				fi

			;;
		esac
	rlPhaseEnd
	done

	rlPhaseStartCleanup do-$role-Cleanup-
		rlRun 'popd'
		rlRun 'rhts-sync-set -s DONE${TEST}'
		rlFileRestore
	rlPhaseEnd
}

server() {
    rlPhaseStartSetup do-$role-Setup-Server
	rlFileBackup /etc/sysconfig/nfs /etc/exports
	rlRun "mkdir -p $AUTO_SERVER_DIR/export{1..6}; chmod 777 $AUTO_SERVER_DIR"
	rlRun "echo \"$AUTO_SERVER_DIR  *(rw,insecure,sync,no_root_squash,no_subtree_check)\" >/etc/exports"

	[ -n "ExportSubdir" ] && {
		for d in $AUTO_SERVER_DIR/export{1..6}; do
			rlRun "echo \"$d  *(rw,insecure,sync,no_root_squash,no_subtree_check)\" >>/etc/exports"
		done
	}
	yp_server_setup
	if [ $? -ne 0 ]; then
		cki_abort_task "Errors on NIS/YP configuration"
	fi
	#if distro version >= 8, enable NFS over UDP
	vercmp "$(lsb_release -sr)" '>=' 8 && cp "$pkgPath/config/nfs" /etc/sysconfig/nfs && nfsconvert
    rlPhaseEnd

    rlPhaseStartTest do-$role-Test-
	rlLog "{INFO} restart nfs server ..."
	rlRun "exportfs -ua"
	rlRun "systemctl restart nfs-server" "0-255"
	if [ $? -ne 0 ]; then
		cki_abort_task "Failed to restart server nfs server"
	fi
	rlRun "rhts-sync-set -s SERVER_READY"
    rlPhaseEnd

    rlPhaseStartCleanup do-$role-Cleanup-
	rlLog "{INFO} server ready. wait the client ..."
	rlRun 'rhts-sync-block -s DONE${TEST} $Client'
	rlFileRestore
    rlPhaseEnd
}


# ---------- Start Test -------------
#

rlJournalStart
    envinfo
    case $HOSTNAME in
        $Client)  client;;
        $Server1) server;;
        $Server2) server;;
        *)         :;;
    esac
rlJournalEnd

