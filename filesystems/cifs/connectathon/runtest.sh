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

# Include  environment
. ../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

LOOKASIDE_DEFAULT=git://git.linux-nfs.org/projects/steved/cthon04.git

TEST=${TEST:-TEST}
TESTNAME=${TEST/*\//}

TESTEXPORTPATH="/tmp/${TESTNAME}"
TESTMOUNTPATH="/mnt/${TESTNAME}"
TESTEXPORTNAME="$TESTNAME"

TESTCONFIGFILE="/etc/samba/smb.conf"
TESTSERVICE="smb"

TESTLOCAL=0

# Commands in this section are provided by test developer.
# ---------------------------------------------
function outputecho() {
	echo $@ | tee -a ${OUTPUTFILE}
}

exitcleanup() {

	#successful, and restore the original environment
	mountpoint $TESTMOUNTPATH && umount $TESTMOUNTPATH
	rm -fr ${TESTEXPORTPATH} ${TESTMOUNTPATH}

	# I think we need it
   	make clean

	rlJournalStart
	   rlServiceStop $TESTSERVICE

	   if [ ${TESTLOCAL} -eq 1 ] ; then
		   if [ -e /etc/samba/smb.conf-${TESTNAME} ]; then
			   cp -fr /etc/samba/smb.conf-${TESTNAME} /etc/samba/smb.conf
		   fi
	   else
			   rstrnt-restore
	   fi
	   rlServiceRestore $TESTSERVICE
	rlJournalEnd
}

function passexit() {

	outputecho "$@"

	rstrnt-report-result $TEST PASS

	exitcleanup

	exit 0
}

function failexit() {

	outputecho "$@"
	rstrnt-report-result $TEST FAIL

	exitcleanup

	exit
}

# ---------------------------------------------

# functions
function Make()
{
   # First we need to make the test

   outputecho "dir"
   pwd
   git clone $LOOKASIDE_DEFAULT
   pushd cthon04
   if [ $? -ne 0 ]; then
      outputecho "Failed to clone cthon04"
      rstrnt-report-result $TEST WARN
      # Abort the task
      rstrnt-abort --server $RSTRNT_RECIPE_URL/tasks/$TASKID/status
      exit 0
   fi
   make clean || ( status=$? && return $status )

   make FSTYPE=cifs || ( status=$? && return $status )

   popd
# Yes, works here, change to PASS temporary
   result="PASS"

} #end Make()

function Client()
{
   local servpath=testuser
   if [ "$1" == "nounix" ]; then
		CTHON_FLAGS='-C'
   fi

   pushd cthon04
   smbclient -L //`hostname`/$servpath -N

   echo "y\n" | ./server -o user=root,password=redhat,domain=EXAMPLE,file_mode=0777,rw,noauto $CTHON_FLAGS -a -f -p ${servpath} -m ${TESTMOUNTPATH} `hostname`

   status=$?
   popd

   return $status

} # end Client()


Server()
{
   # samba and samba-client should already be installed

	outputecho "Save the original configure files"
	# We use this, to avoid the re-backup config file,
	# and the definite original config file is overrided
	if [ ! -e ${TESTCONFIGFLE}-${TESTNAME} ] ; then
		if [ ${TESTLOCAL} -eq 1 ] ; then
			cp -fr ${TESTCONFIGFILE} ${TESTCONFIGFILE}-${TESTNAME}
		else
			rstrnt-backup ${TESTCONFIGFILE}
		fi
	fi

	outputecho "Prepare directory, file and link"
	rm -fr  ${TESTEXPORTPATH} && mkdir -p ${TESTEXPORTPATH} && chmod 1777 ${TESTEXPORTPATH} || failexit "prepare directory failed.."
	#add the access permission, this don't support rhel4
	if ! grep "Nahant" /etc/redhat-release ; then
		chcon -t samba_share_t ${TESTEXPORTPATH} || failexit "Chcon the ${TESTEXPORTPATH} failed.."
	fi

###
## The directory wild at last,so we use this absolute dir
    if [ "$1" == "nounix" ]; then
		cp -f ${CURRENT_DIR}/smb.conf ${TESTCONFIGFILE}
    else
		cp -f ${CURRENT_DIR}/smb.conf.unix ${TESTCONFIGFILE}
    fi

	echo -e "redhat\nredhat" | smbpasswd -s -a root || failexit "Fail to add test samba account"

	rlServiceStop $TESTSERVICE && rlServiceStart $TESTSERVICE

	sleep 20
}

# ------------------Start test -----------------
outputecho "**** Start CIFS ${TESTNAME} test *******"

touch /mnt/testarea/printcap
sed -i -e '/^Browsing/d' /etc/cups/cupsd.conf | tee -a ${OUTPUTFILE}
sed -i -e '/^DefaultShared/d' /etc/cups/cupsd.conf | tee -a ${OUTPUTFILE}
echo "Browsing No" >> /etc/cups/cupsd.conf | tee -a ${OUTPUTFILE}
echo "DefaultShared No" >> /etc/cups/cupsd.conf | tee -a ${OUTPUTFILE}
restorecon /etc/cups/cupsd.conf

(rlServiceStop cups && rlServiceStart cups) | tee -a ${OUTPUTFILE}
echo "cupsctl: " | tee -a ${OUTPUTFILE}
cupsctl | tee -a ${OUTPUTFILE}

score=0
result="FAIL"
CURRENT_DIR=`pwd`

#call Make, building stuffs
outputecho "Building connectathon test suite"
Make
if [ $result = "FAIL" ] ; then
   outputecho "Failed to compile cthon04"
   rstrnt-report-result $TEST WARN
   # Abort the task
   rstrnt-abort --server $RSTRNT_RECIPE_URL/tasks/$TASKID/status
   exit 0
fi

# Randomly, we are getting the following AVC denial with RHEL 6.9:
#
# type=SYSCALL msg=audit(1504145288.730:53): arch=c000003e syscall=2 success=no exit=-13
# a0=7f82716a4b95 a1=80002 a2=1b6 a3=2 items=0 ppid=12376 pid=12398 auid=4294967295 uid=0
# gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="smbd"
# exe="/usr/sbin/smbd" subj=unconfined_u:system_r:smbd_t:s0 key=(null)
# type=AVC msg=audit(1504145288.730:53): avc:  denied  { write } for  pid=12398 comm="smbd"
# name="mtab" dev=dm-0 ino=652679 scontext=unconfined_u:system_r:smbd_t:s0
# tcontext=unconfined_u:object_r:etc_runtime_t:s0 tclass=file
if grep -q "6.9" /etc/redhat-release ; then
	make -f /usr/share/selinux/devel/Makefile local.pp
	semodule -i local.pp
fi

outputecho "======================================="
outputecho "Setting up server with unix extensions enabled"
Server unix

outputecho "Running connectathon test -- ROUND01"
Client unix

outputecho "Now, Test result=>${result}, status=>${status}, score=>${score}"

if [ "$result" != "PASS" ]; then
    outputecho "Status = $status\n"
    dmesg
	failexit "${TEST} ==> FAIL, score:$score"
fi

outputecho "======================================="
outputecho  "Setting up server with unix extensions disabled"
Server nounix

outputecho "Running connectathon test (nounix) -- ROUND02"
Client nounix

outputecho "Now, Test result=>${result}, status=>${status}, score=>${score}"

if [ "$result" != "PASS" ]; then
    outputecho "Status = $status\n"
    dmesg
	failexit "${TEST} ==> FAIL, score:$score"
fi

passexit "${TEST} ==> PASS, score:$score"
outputecho "----cthon-cifs Complete ----- Result = $result"
