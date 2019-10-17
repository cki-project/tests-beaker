#!/bin/bash
#
# Copyright (c) 2019 Red Hat, Inc. All rights reserved.
#
# This copyrighted material is made available to anyone wishing
# to use, modify, copy, or redistribute it subject to the terms
# and conditions of the GNU General Public License version 2.
#
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
#

FILE=$(readlink -f ${BASH_SOURCE})
NAME=$(basename $FILE)
CDIR=$(dirname $FILE)

BUSY=${1:-"$CDIR/busy.sh"}
STRESSPIDS=

start_load_test()
{
    cores=$(nproc)
    count=0

    [ ! -e "$BUSY" ] && echo "missing $BUSY" && exit 1

    for ((i=0; i < $cores; ++i)); do
        # if hyperthreading is enabled - only start on the even cores
        [ "$even_only" = true ] && [ $((i % 2)) -eq 1 ] && continue
        bash $BUSY $i &>/dev/null &
        STRESSPIDS="$STRESSPIDS ""$!"
        count=$((count + 1))
    done

    if [ "$count" -ne "$cores" ]; then
        echo "count: $count is not equal to target: $1"
        exit 1
    fi

    # make sure the processes really starts
    sleep 5

    for pid in $STRESSPIDS; do
        result=$(ps -p $pid -o comm=)
        size=${#result}

        if [ $size -eq 0 ]; then
            echo "start_load_test: $BUSY is not running!"
            exit 1
        fi
    done

    echo "load processes started"
}

end_load_test()
{
    if [ ! -z "$STRESSPIDS" ]; then
        for pid in $STRESSPIDS; do
            kill $pid
            wait $pid 2>/dev/null
        done
        STRESSPIDS=
        echo "load processes killed"
    fi
}

finish()
{
    end_load_test
}

powerunit=0
get_power_unit()
{
    powerunit=$(rdmsr 0x606)
}

esu=0
get_energy_status_units()
{
    get_power_unit
    esu=$((16#$powerunit))
    esu=$((esu >> 8))
    mask=$((16#1f))
    esu=$((esu & mask))
    esu=$((2 ** esu))
    esu=$(echo "scale=6; 1/$esu" | bc -l | awk '{printf "%f", $0}')
    echo "energy status units = $esu joules"
}

INTMAX=4294967296
last_reg=-1
handle_overflow()
{
    updated_reg=$1
    if [ $last_reg -eq -1 ]; then
	last_reg=$updated_reg
    else
	[ $updated_reg -lt $last_reg ] && updated_reg=$((updated_reg+INTMAX))
	last_reg=-1
    fi
}

get_pkg_energy()
{
    reg=$(rdmsr 0x611)
    reg=$((16#$reg))
    handle_overflow $reg
    reg=$updated_reg
    energy=$(echo "$reg*$esu" | bc -l)
}

average=
monitor_power()
{
    duration=60 # seconds

    get_pkg_energy
    last=$energy
    last_time=$(date +%s%N | cut -b1-13)
    sleep $duration
    get_pkg_energy
    curr=$energy
    curr_time=$(date +%s%N | cut -b1-13)
    milliseconds=$((curr_time - last_time))
    joules=$(echo $curr-$last | bc -l)
    watts=$(echo "$joules*1000/$milliseconds" | bc -l)
    printf "average power use = %5.2f watts over last %d seconds\n" \
           $watts $duration
    average=$(echo $watts+0.5 | bc -l)
    average=${average%.*}
}

trap 'finish' EXIT
get_energy_status_units
monitor_power
idle_ave=$average
start_load_test
monitor_power
busy_ave=$average
end_load_test
max_expected=$((busy_ave/2))
if [ $idle_ave -ge $max_expected ]; then
    if [[ $idle_ave -lt $busy_ave ]] && [[ $busy_ave -lt 20 ]]; then
	echo "SKIP - system power draw is too low"
	exit 2
    fi
    echo "FAIL"
    exit 1
else
    echo "PASS"
    exit 0
fi
