#!/bin/bash
# This is for the obsolete functions

my_echo()
{
	echo "# $1" | tee -a "$OUTPUTFILE"
	$1 | tee -a "$OUTPUTFILE"
}

# Usage : myecho "cmd" run check
# 0 is ok, 1 is error
myecho()
{
	echo -e "\n# $1" | tee -a "$OUTPUTFILE"
	if [ $2 ];then
		if [ "$2" == "run" ];then
			eval $1
			LASTSTATE=$?
		else
			echo -e "wrong option , should be 'run'\n"
			test_warn "wrong option , should be 'run'"
		fi
	fi
	if [ $3 ]; then
		if [ "$3" == "check" ];then
			if [ $LASTSTATE -ne 0 ];then
				echo -e "Command # $1 failed\n" | tee -a "$OUTPUTFILE"
				test_warn "Command_failed"
			else
				echo -e "[Command # $1 done]\n" | tee -a "$OUTPUTFILE"
			fi
		else
			echo -e "wrong option , should be 'check'\n"
			test_warn "wrong option , should be 'check'"
		fi
	fi
	return $LASTSTATE
}

# Usage : mywatch command timeout [signal]
mywatch()
{
        command=$1
        timeout=$2
        single=${3:-9}
        now=`date '+%s'`
        after=`date -d "$timeout seconds" '+%s'`

        $command &
        pid=$!
        while true; do
                now=`date '+%s'`

                if ps -p $pid; then
                        if [ "$after" -gt "$now" ]; then
                                sleep 10
                        else
                                echo "command (# $command) still alive, kill it"
                                kill -$single $pid
                                break
                        fi
                else
                        echo "command (# $command) exit itself"
                        break
                fi
        done
}

# check_cmd_fail "cmd" "test_should_fail"
check_cmd_fail()
{
	$1
	if [ $? == 0 ]; then
		log "Test Fail: $2 should fail , but passed."
		test_fail "$2"
		return 1
	fi
	return 0
}
