
# variables to control some default action
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


# Usage: run command [return_value]
run()
{
        cmd=$1
        # only support zero or none zero,
        exp=${2:-0}
        echo -e "\n[$(date '+%T')][$(whoami)@$(uname -r | cut -f 2 -d-)]# '"$cmd"'" | tee -a $OUTPUTFILE
        # we only care the return value
        eval "$cmd" &> >(tee -a $OUTPUTFILE)
        ret=$?
        if [ "$exp" -eq "$ret" ];then
                let PASS++
                echo -e ":: [  ${GRN}PASS${RES}  ] :: Command '"$cmd"' (Expected $exp, got $ret, score $PASS)" | tee -a $OUTPUTFILE
                echo 0
        else
                let FAIL++
                echo -e ":: [  ${RED}FAIL${RES}  ] :: Command '"$cmd"' (Expected $exp, got $ret, score $FAIL)" | tee -a $OUTPUTFILE
                echo 1
        fi
}
