#!/bin/bash

# A script to help generate the list of stressors to run and
# eliminate duplicate stressors from the classes.
# The list may need further editing to blacklist known issues.
# Build stress-ng and run this script in the same directory (./stress-ng)

CLASSES="cpu cpu-cache interrupt memory os"
for c in $CLASSES ; do
    cat /dev/null > ${c}.stressors
done

for c in $CLASSES ; do
    for s in $(./stress-ng --class ${c}? | sed 's/^.*stressors: //') ; do
        if ! grep -q -w ${s} *.stressors ; then
            echo "Adding ${s} to ${c}.stressors"
            echo "--${s} 0 --timeout 5 --log-file ${s}.log" >> ${c}.stressors
        else
            echo "${s} is dup"
        fi
    done
done
