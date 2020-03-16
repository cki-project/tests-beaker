#!/bin/sh

. ../../../cki_lib/libcki.sh || exit 1

COUNT=0

#
# Count number of devices under /sys/class/net with type == 1 (ethernet)
#
echo -e "\n****Running : Counting the number of ethernet devices"
for netdev in /sys/class/net/*
do
	if [ "$(cat ${netdev}/type)" == "1" ]
	then
		COUNT=$(($COUNT + 1))
	fi
done
        echo "$COUNT ethernet devices were found"

# 
# If none found, assume failure to load any ethernet driver and fail test
#
if [ $COUNT -eq 0 ]
then
        echo "FAIL: No ethernet devices found"
        rstrnt-report-result $TEST FAIL 1
        exit
fi

#
# For each device under /sys/class/net...
#
echo -e "\n****Running : 'ethtool -i' against each ethernet device"
for netdev in /sys/class/net/*
do
        #
        # Check if type == 1 (ethernet)
        #
        if [ "$(cat ${netdev}/type)" == "1" ]
        then
                #
                # If so, try to run "ethtool -i" on the device.
                #
                dev=$(basename $netdev);
                echo -e "\nRunning ethtool -i on $dev"
                ethtool -i $dev

                #
                # If ethtool returns failure, then fail the test...
                #
                if [ $? -ne 0 ];
                then
		        echo "FAIL: ethtool -i returned a failure"
		        rstrnt-report-result $TEST FAIL 1
                fi
        fi
done

#
# Otherwise, success!
#
rstrnt-report-result $TEST PASS 0
exit
