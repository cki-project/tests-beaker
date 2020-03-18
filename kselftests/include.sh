#!/bin/bash
[ ! "$JOBID" ] && rm -rf logs && mkdir logs && export LOG_DIR="$PWD/logs"

if [ ! "$JOBID" ]; then
	RED='\E[1;31m'
	GRN='\E[1;32m'
	YEL='\E[1;33m'
	RES='\E[0m'
fi

new_outputfile()
{
	[ "$JOBID" ] && mktemp /mnt/testarea/tmp.XXXXXX || mktemp $LOG_DIR/tmp.XXXXXX
}

setup_env()
{
	# install dependence
	# save testing environment
	# export our new variable
	export PASS=0
	export FAIL=0
	export OUTPUTFILE=$(new_outputfile)
}

clean_env()
{
	# clean environment
	# restore environment
	unset PASS
	unset FAIL
}

log()
{
	echo -e "\n[$(date '+%T')][$(whoami)@$(uname -r | cut -f 2 -d-)]# " | tee -a $OUTPUTFILE
	echo -e "\n[  LOG: $1  ]" | tee -a $OUTPUTFILE
}

submit_log()
{
	for file in $@; do
		[ "$JOBID" ] && rstrnt-report-log -l $file || cp $file $LOG_DIR/
	done
}

test_pass()
{
	echo -e "\n:: [  PASS  ] :: Test '"$1"'" >> $OUTPUTFILE
	if [ $JOBID ]; then
		rstrnt-report-result "${TEST}/$1" "PASS"
	else
		echo -e "::::::::::::::::"
		echo -e ":: [  ${GRN}PASS${RES}  ] :: Test '"${TEST}/$1"'"
		echo -e "::::::::::::::::\n"
	fi
}

test_fail()
{
	SCORE=${2:-$FAIL}
	echo -e ":: [  FAIL  ] :: Test '"$1"'" >> $OUTPUTFILE
	if [ $JOBID ]; then
		rstrnt-report-result "${TEST}/$1" "FAIL" "$SCORE"
	else
		echo -e ":::::::::::::::::"
		echo -e ":: [  ${RED}FAIL${RES}  ] :: Test '"${TEST}/$1"' FAIL $SCORE"
		echo -e ":::::::::::::::::\n"
	fi
}

test_warn()
{
	echo -e "\n:: [  WARN  ] :: Test '"$1"'" | tee -a $OUTPUTFILE
	if [ $JOBID ]; then
		rstrnt-report-result "${TEST}/$1" "WARN"
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

# Usage: run command [return_value]
run()
{
	cmd=$1
	# FIXME: only support zero or none zero, doesn't support 2-10, or 2,3,4
	exp=${2:-0}
	echo -e "\n[$(date '+%T')][$(whoami)@$(uname -r | cut -f 2 -d-)]# '"$cmd"'" | tee -a $OUTPUTFILE
	# FIXME: how should we handle if there are lots of output for the cmd,
	# and we only care the return value
	eval "$cmd" > >(tee -a $OUTPUTFILE)
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
