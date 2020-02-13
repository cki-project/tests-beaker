#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of  power management suspend-resume
#   Description: try to suspend and resume the system.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
# Source the common test script helpers
. /usr/bin/rhts-environment.sh

SLEEP_TIME=10
FAIL=0
BOOTTIME_FAIL=0
NOT_SUPPORT=0

# Helper functions
function result_fail()
{
    echo "***** End of runtest.sh *****" | tee -a $OUTPUTFILE
    rstrnt-report-result $TEST FAIL 1
    exit 0
}

function result_pass ()
{
    echo "***** End of runtest.sh *****" | tee -a $OUTPUTFILE
    rstrnt-report-result $TEST PASS 0
    exit 0
}

#return 0 when running on baremetal
function is_baremetal 
{
   local virtwhat=$(virt-what)
   local virtret=$?
   # virt-what returns empty string  and exit code 0, when is baremetal
   if [[  -z "$virtwhat" ]] && [[ $virtret -eq 0 ]]; then
      return 0
   else
      return 1
   fi
}


function getdetails ()
{
	echo "grep /var/log/messages for which time source kernel is using" >> $OUTPUTFILE
	echo "------------------------------------------------------------" >> $OUTPUTFILE
        journalctl > /tmp/messages
#REMOVE	grep kernel: /var/log/messages | grep time >> $OUTPUTFILE
	grep kernel: /tmp/messages | grep time >> $OUTPUTFILE
	echo "------------------------------------------------------------" >> $OUTPUTFILE
	echo "lspci output to show what chipset" >> $OUTPUTFILE
	echo "------------------------------------------------------------" >> $OUTPUTFILE
	lspci >> $OUTPUTFILE
	echo "------------------------------------------------------------" | tee -a $OUTPUTFILE
	echo "* List of Available Clock Sources " | tee -a $OUTPUTFILE
	echo "        $(cat /sys/devices/system/clocksource/clocksource0/available_clocksource)" | tee -a  $OUTPUTFILE
	echo "* Current Clock Source " | tee -a $OUTPUTFILE
	echo "        $(cat /sys/devices/system/clocksource/clocksource0/current_clocksource)" | tee -a  $OUTPUTFILE
	echo "------------------------------------------------------------" | tee -a $OUTPUTFILE
}

function setup ()
{
	echo '=============== Setup ==================================' | tee -a ${OUTPUTFILE}

        is_baremetal
        if (( $? != 0 )); then
            echo "Not running on baremetal machine" | tee -a ${OUTPUTFILE}
            rstrnt-report-result $TEST SKIP 0
            exit 0
        fi

	systemctl disable ntpd  > /dev/null 2>&1

	echo "Supported sleep states: `cat /sys/power/state`" | tee -a ${OUTPUTFILE}

	# Set the system to UTC to avoid problems with RTC alarm
        timedatectl set-timezone UTC

	default=`grubby --default-kernel`
	grubby --args="no_console_suspend" --update-kernel=$default

	echo "Rebooting now..." | tee -a ${OUTPUTFILE}

	rstrnt-reboot

	echo "Finish Rebooting !" | tee -a ${OUTPUTFILE}

	# sync system and rtc clocks
	hwclock -w

}

function print_rtc () {
        echo '-- RTC Status: ----' | tee -a ${OUTPUTFILE}
        echo "*** System time: `date`" | tee -a ${OUTPUTFILE}

        echo "*** /proc/driver/rtc:" | tee -a ${OUTPUTFILE}
        cat /proc/driver/rtc | tee -a ${OUTPUTFILE}
        echo '-------------------' | tee -a ${OUTPUTFILE}
}

function set_rtc_alarm () {
        echo "Setting RTC alarm to now + $SLEEP_TIME minutes..." | tee -a ${OUTPUTFILE}
        rtcwake -m no -s $(($SLEEP_TIME * 60))
}

function suspend_resume ()
{
	state=$1

	print_rtc
	set_rtc_alarm
	print_rtc

        echo "/sys/power/disk: "$(cat  /sys/power/disk 2>/dev/null)  | tee -a ${OUTPUTFILE}
        echo "/sys/power/mem_sleep: "$(cat  /sys/power/mem_sleep 2>/dev/null) | tee -a ${OUTPUTFILE}
	echo "Suspend to $state" | tee -a ${OUTPUTFILE}

	if [[ "$state" = "disk" ]]; then
		hibernation_mode=`cat /sys/power/disk | sed 's/\(.*\)\[\(.*\)\]\(.*\)/\2/g'`

		# reboot mode
		if [[ $hibernation_mode = reboot ]]; then
			if grep -q platform /sys/power/disk; then
				echo "Setting to platform hibernation mode" | tee -a ${OUTPUTFILE}
				echo "platform" > /sys/power/disk
			elif grep -q shutdown /sys/power/disk; then
				echo "Setting to shutdown hibernation mode" | tee -a ${OUTPUTFILE}
				echo "shutdown" > /sys/power/disk
			else
				echo "working in reboot hibernation mode" | tee -a ${OUTPUTFILE}
			fi
		else
			echo "working in $hibernation_mode hibernation mode" | tee -a ${OUTPUTFILE}
		fi
	elif [[ "$state" = "mem" ]]; then
		if grep -q s2idle  /sys/power/mem_sleep; then
			echo "Setting to s2idle suspend  mode" | tee -a ${OUTPUTFILE}
			echo "s2idle" > /sys/power/mem_sleep
                fi
	fi

	RES=1
	if [[ "$state" = "disk" ]]; then
                # setting boot order
		if efibootmgr &>/dev/null ; then
			os_boot_entry=$(efibootmgr | awk '/BootCurrent/ { print $2 }')
			# fall back to /root/EFI_BOOT_ENTRY.TXT if it exists and BootCurrent is not available
			if [[ -z "$os_boot_entry" && -f /root/EFI_BOOT_ENTRY.TXT ]] ; then
				os_boot_entry=$(</root/EFI_BOOT_ENTRY.TXT)
			fi
			if [[ -n "$os_boot_entry" ]] ; then
				logger -s "efibootmgr -n $os_boot_entry"
				efibootmgr -n $os_boot_entry
			else
				logger -s "Could not determine value for BootNext!"
			fi
		fi

		echo "Suspending to disk" | tee -a ${OUTPUTFILE}
		systemctl hibernate
		RES=$?
	elif [[ "$state" = "mem" ]]; then
		echo "Suspending to mem" | tee -a ${OUTPUTFILE}
		systemctl suspend
		RES=$?
	fi

	if [[ $RES != 0 ]]; then
		echo "Function not implemented Bug(891967)" | tee -a ${OUTPUTFILE}
		NOT_SUPPORT=1
		return
	fi

	sleep 30

	echo "Successfully resumed from $state" | tee -a ${OUTPUTFILE}
	echo '--------------------------------------------------------' | tee -a ${OUTPUTFILE}
}

function startSuspendResume ()
{
	COUNT=1000
	BOOTTIME_1=`cat /proc/stat | grep "btime" | awk '{print $2}'`
	START_TIME=`./time | sed -n 2p | awk '{ print $1 }'`

	suspend_resume $1

	if [[ $NOT_SUPPORT = 1 ]]; then
		echo "> Suspend do not occur actually"
		return
	fi

	END_TIME=`./time | sed -n 2p | awk '{ print $1 }'`

	while [ $COUNT -ge 0 ]
	do
		BOOTTIME_2=`cat /proc/stat | grep "btime" | awk '{print $2}'`
		if [[ $BOOTTIME_1 != $BOOTTIME_2 ]]; then
			printf "FAIL: boottime not stable count = $COUNT\n\t * Before suspend to $i boottime = $BOOTTIME_1\n\t * After  suspend to $i boottime = $BOOTTIME_2\n"

			BOOTTIME_FAIL=1

			break;
		fi

		((COUNT--))
	done

	# Sleeping time and add with extra time to reload the full system
	SLEEP_TIME_SEC=`expr $SLEEP_TIME \* 60 \* 2`
	DELTA_TIME=`expr $END_TIME - $START_TIME`

	if [[ $DELTA_TIME -gt $SLEEP_TIME_SEC ]]; then
		FAIL=1
		printf "FAIL: sleep about $DELTA_TIME seconds it is too long !!\n"
	else
		printf "Success : sleep about $DELTA_TIME seconds\n"
	fi

	printf "Suspend to $2 time elapsed :\n \
		start time(sec) $START_TIME\n \
		end   time(sec) $END_TIME\n"
}

function runTest ()
{
	if [ -z "${REBOOTCOUNT}" ] || [ "${REBOOTCOUNT}" -eq 0 ]; then
		setup
	fi

	for i in `cat /sys/power/state`
	do
		case $i in
			standby)
				echo "Did nothing in standby S1 state" | tee -a ${OUTPUTFILE}
				
				;;
			mem)
				echo '--------------------------------------------------------' | tee -a ${OUTPUTFILE}
				echo "Suspend-to-RAM (s3)" | tee -a ${OUTPUTFILE}
				startSuspendResume $i mem
				;;
			disk)
				echo '--------------------------------------------------------' | tee -a ${OUTPUTFILE}
				echo "Suspend-to-Disk/Hibernate (s4)" | tee -a ${OUTPUTFILE}
				startSuspendResume $i disk
				;;
			*)
				echo "Did nothing in other S state: $i" | tee -a ${OUTPUTFILE}
				;;
		esac
	done

	if [[ $NOT_SUPPORT = 1 ]]; then
		echo "Please Refers to BZ: https://bugzilla.redhat.com/show_bug.cgi?id=891967" | tee -a ${OUTPUTFILE}
		echo "This is not Supported"| tee -a {OUTPUTFILE}
		rstrnt-report-result $TEST SKIP 0
		exit 0
	fi

	if [[ $BOOTTIME_FAIL = 0 ]]; then
		echo ">> Boottime Checking Pass" | tee -a ${OUTPUTFILE}
	else
		echo "!! Boottime Checking Fail" | tee -a ${OUTPUTFILE}
	fi

	if [[ $FAIL = 0 ]]; then
		echo ">> Suspend-Resume Time Consuming checking Pass" | tee -a ${OUTPUTFILE}
	else
		echo "!! Suspend-Resume Time Consuming checking Fail" | tee -a ${OUTPUTFILE}
	fi

	if [ $FAIL = 1 ] || [ $BOOTTIME_FAIL = 1 ]; then
		result_fail
	else
		result_pass
	fi
}

# ---------- Start Test -------------
# Setup some variables
if [ -e /etc/redhat-release ] ; then
    installeddistro=$(cat /etc/redhat-release)
else
    installeddistro=unknown
fi

kernbase=$(rpm -q --queryformat '%{name}-%{version}-%{release}.%{arch}\n' -qf /boot/config-$(uname -r))

echo "***** Starting the runtest.sh script *****" | tee -a $OUTPUTFILE
echo "***** Current Running Kernel Package = "$kernbase" *****" | tee -a $OUTPUTFILE
echo "***** Current Running Distro = "$installeddistro" *****" | tee -a $OUTPUTFILE

getdetails

systemctl stop ntpd  > /dev/null 2>&1
runTest 
systemctl start ntpd > /dev/null 2>&1
