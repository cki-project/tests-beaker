#!/bin/bash


rtr=0

for i in $(ls *.sh | grep -v runtest.sh) ; do
    echo $i
    ./$i
    rtr1=$?
    rtr=$(expr $rtr + $rtr1)
done
if [ -f $(dirname $0)/../../include/testframeworks ]; then
  . $(dirname $0)/../../include/testframeworks
  uploadlogs
fi

if [ $rtr -ne 0 ]; then
    exit 1
else
    exit 0
fi
