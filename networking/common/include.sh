#!/bin/bash

# dynamically get the lib dir
NETWORK_COMMONLIB_DIR=$(dirname $(readlink -f $BASH_SOURCE))
networkLib=$NETWORK_COMMONLIB_DIR

# include beaker default environmnet
. /usr/bin/rhts_environment.sh
. /usr/share/beakerlib/beakerlib.sh || . /usr/lib/beakerlib/beakerlib.sh

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

# variables to control some default action
NM_CTL=${NM_CTL:-"no"}
FIREWALL=${FIREWALL:-"no"}
AVC_CHECK=${AVC_CHECK:-"yes"}
if [ ! "$JOBID" ]; then
	RED='\E[1;31m'
	GRN='\E[1;32m'
	YEL='\E[1;33m'
	RES='\E[0m'
fi

new_outputfile()
{
	mktemp /mnt/testarea/tmp.XXXXXX
}

setup_env()
{
	# install dependence
	# save testing environment
	# export our new variable
	export PASS=0
	export FAIL=0
	export OUTPUTFILE=$(new_outputfile)
	reset_network_env
}

clean_env()
{
	# clean environment
	# restore environment
	unset PASS
	unset FAIL
	reset_network_env
}

log()
{
	#echo ":: [  LOG   ] :: : $1" | tee -a $OUTPUTFILE
	echo -e "\n[$(date '+%T')][$(whoami)@$(uname -r | cut -f 2 -d-)]# " | tee -a $OUTPUTFILE
	echo -e "\n[  LOG: $1  ]" | tee -a $OUTPUTFILE
}

submit_log()
{
	[ ! $JOBID ] && return 0
	for file in $@; do
		rstrnt-report-log -l $file
	done
}

test_pass()
{
	#SCORE=${2:-$PASS}
	echo -e "\n:: [  PASS  ] :: Test '"$1"'" | tee -a $OUTPUTFILE
	# we don't care how many test passed
	if [ $JOBID ]; then
		rstrnt-report-result "${TEST}/$1" "PASS"
	else
		echo -e "\n::::::::::::::::"
		echo -e ":: [  ${GRN}PASS${RES}  ] :: Test '"${TEST}/$1"'"
		echo -e "::::::::::::::::\n"
	fi
}

test_fail()
{
	SCORE=${2:-$FAIL}
	#echo ":: [  FAIL  ] :: RESULT: $1" | tee -a $OUTPUTFILE
	echo -e ":: [  FAIL  ] :: Test '"$1"'" | tee -a $OUTPUTFILE
	# we only care how many test failed
	if [ $JOBID ]; then
		rstrnt-report-result "${TEST}/$1" "FAIL" "$SCORE"
	else
		echo -e "\n:::::::::::::::::"
		echo -e ":: [  ${RED}FAIL${RES}  ] :: Test '"${TEST}/$1"' FAIL $SCORE"
		echo -e ":::::::::::::::::\n"
	fi
}

test_warn()
{
	#echo ":: [  WARN  ] :: RESULT: $1" | tee -a $OUTPUTFILE
	echo -e "\n:: [  WARN  ] :: Test '"$1"'" | tee -a $OUTPUTFILE
	if [ $JOBID ]; then
		rstrnt-report-result "${TEST}/$1" "WARN"
		rstrnt-abort -t recipe
	else
		echo -e "\n:::::::::::::::::"
		echo -e ":: [  ${YEL}WARN${RES}  ] :: Test '"${TEST}/$1"'"
		echo -e ":::::::::::::::::\n"
	fi
}

test_pass_exit()
{
	test_pass $1
	exit 0
}

test_fail_exit()
{
	test_fail $1
	exit 1
}

test_warn_exit()
{
	test_fail $1
	exit 1
}

i_am_server() {
	echo $SERVERS | grep -q $HOSTNAME
}

i_am_client() {
	echo $CLIENTS | grep -q $HOSTNAME
}

i_am_standalone() {
	echo $STANDALONE | grep -q $HOSTNAME
}

# Usage: run command [return_value]
run()
{
	cmd=$1
	# FIXME: only support zero or none zero, doesn't support 2-10, or 2,3,4
	exp=${2:-0}
	echo -e "\n[$(date '+%T')][$(whoami)@$(uname -r | cut -f 2 -d-)]# '"$cmd"'" | tee -a $OUTPUTFILE
	# FIXME: how should we handle if there are lots of output for the cmd,
	# and we only care the return value
	eval "$cmd" &> >(tee -a $OUTPUTFILE)
	ret=$?
	if [ "$exp" -eq "$ret" ];then
		let PASS++
		echo -e ":: [  ${GRN}PASS${RES}  ] :: Command '"$cmd"' (Expected $exp, got $ret, score $PASS)" | tee -a $OUTPUTFILE
		return 0
	else
		let FAIL++
		echo -e ":: [  ${RED}FAIL${RES}  ] :: Command '"$cmd"' (Expected $exp, got $ret, score $FAIL)" | tee -a $OUTPUTFILE
		return 1
	fi
}

# Usage: watch command timeout [signal]
watch()
{
	command=$1
	timeout=$2
	single=${3:-9}
	now=`date '+%s'`
	after=`date -d "$timeout seconds" '+%s'`

        eval "$command" &
        pid=$!
        while true; do
                now=`date '+%s'`

                if ps -p $pid; then
                        if [ "$after" -gt "$now" ]; then
                                sleep 10
                        else
                                log "command (# $command) still alive, kill it"
                                kill -$single $pid
                                break
                        fi
                else
                        log "command (# $command) exit itself"
                        break
                fi
        done
}

get_round()
{
	# pushd to include dir to make sure our $round is specific
	PWD=$(pwd)
	cd ${NETWORK_COMMONLIB_DIR}
	if [ ! -e my.round ];then
		echo 1 > my.round
		round=1
	else
		round=`cat my.round`
		let round++
		echo $round > my.round
	fi
	cd $PWD
	echo $round
}
# sync is a linux file system cmd. use net_sync instead
net_sync()
{
	local FLAG=$1
	# only enalbe get_round when (no JOBID and no DONT_GET_ROUND)
	if [ ! "$JOBID" ] && [ ! "$DONT_GET_ROUND" ];then
		FLAG="$(get_round)_${FLAG}"
	fi
	log "Start sync ${FLAG}"
	if $(echo $SERVERS | grep -q -i $HOSTNAME);then
		rhts-sync-set -s ${FLAG}
		for client in $CLIENTS; do
			rhts-sync-block -s ${FLAG} $client
		done
	elif $(echo $CLIENTS | grep -q -i $HOSTNAME);then
		for server in $SERVERS; do
			rhts-sync-block -s ${FLAG} $server
		done
		rhts-sync-set -s ${FLAG}
	fi
	log "Finish sync ${FLAG}"
}
net-sync()
{
	net_sync $1
}

# We only care the main distro
GetDistroRelease()
{
	#version=`sed 's/[^0-9\.]//g' /etc/redhat-release`
	cut -f1 -d. /etc/redhat-release | sed 's/[^0-9]//g'
}

get_python()
{
	PYTHON=${PYTHON:-python}
	if /usr/libexec/platform-python -V &> /dev/null; then
		PYTHON="/usr/libexec/platform-python"
	elif python3 -V &> /dev/null; then
		PYTHON="python3"
	elif python2 -V &> /dev/null; then
		PYTHON="python2"
	fi
	echo ${PYTHON}
}

#Usage: rmmodule MODULENAME
#unload module and it's holders.
#Note: If this function stuck,you should handle it on your own.
#     Check if successful unload after call rmmodule.
rmmodule()
{
	local module=$1
	modprobe -q -r $module && return 0
	test -e /sys/module/$module || { echo "FATAL: Module $module not found.";return 1; }
	local holders=`ls /sys/module/$module/holders/`
	for item in $holders;do
		rmmodule $item
	done
	modprobe -q -r $module
}

# source our functions
pushd $NETWORK_COMMONLIB_DIR > /dev/null
for lib in *.sh; do
	# skip self and runtest.sh
	[ "$lib" = "include.sh" -o "$lib" = "runtest.sh" ] && continue
	source $lib
done

# handle the initial task just once
if [ -f /dev/shm/network_common_initalized ]
then
	# avc_check toggle every time common is called as avc setting may be
	# reset by beaker or others
	[ "$AVC_CHECK" = yes ] && enable_avc_check || disable_avc_check
else
	{
	# make sure all required packages are installed
	make testinfo.desc
	packages=`awk -F: '/Requires:/ {print $2}' testinfo.desc`
	${yum} install -y $packages --skip-broken
	# install kernel-module-extra version matching the current running kernel version
	${yum} install kernel-modules-extra -y --skip-broken

	# install customer tools
	mkdir -p /usr/local/src /usr/local/bin
	\cp -af src/*    /usr/local/src/.
	\cp -af tools/*  /usr/local/bin/.
        chmod a+x /usr/local/bin/netns_clean.sh

	# work around bz883695
	lsmod | grep mlx4_en || modprobe mlx4_en
	# work around bz1642795
	lsmod | grep sctp || modprobe sctp

	[ -d $networkLib/network-scripts.bak ] || \
		rsync -a --delete /etc/sysconfig/network-scripts/ $networkLib/network-scripts.bak/

	# NetworkManger toggle
	[ "$NM_CTL" = yes ] || stop_NetworkManager

	# firewall toggle
	[ "$FIREWALL" = yes ] && enable_firewall || disable_firewall

	# avc_check toggle
	[ "$AVC_CHECK" = yes ] && enable_avc_check || disable_avc_check

	touch /dev/shm/network_common_initalized
}
fi

popd > /dev/null

# use our own rhts-sync for manually testing
if [ ! "$JOBID" ];then
rhts-sync-set()
{
	local message=$2
	local timeout=3600
	local peer_host=""
	local resend=1

	if   i_am_client; then peer_host="$SERVERS"
	elif i_am_server; then peer_host="$CLIENTS"
	else peer_host=$HOSTNAME
	fi
	until [ $timeout -le 0 ] || [ $resend -eq 0 ]; do
		let resend=0
		for host in $peer_host; do
			ssh $host "echo $HOSTNAME $message >> /tmp/sync_message" 2>/dev/null || let resend++;
		done
		sleep 5
		let timeout=timeout-5
	done
	if [ $timeout -le 0 ]; then test_warn "rhts-sync-set $HOSTNAME $message failed"; fi
	echo "rhts-sync-set -s $message DONE"
}

rhts-sync-block()
{
	local message=$2
	local i
	shift; shift
	hosts=($@)
	for i in ${hosts[@]}; do
		local key="$i $message"
		while true; do
			grep "$key" /tmp/sync_message 2>/dev/null && {
				sed -i "/$key/d" /tmp/sync_message
				break
			}
			echo "$(date '+%b %d %T') Waiting $key"
			sleep 5
		done
	done
	echo "rhts-sync-block -s $message $@ DONE"
}
fi
