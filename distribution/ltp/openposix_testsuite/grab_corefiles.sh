#!/bin/bash

my_dir=$1
excluded_list="$2"
bin_core_list=""

for core_abs in $(find $my_dir -iname 'core.*' -print); do
    echo "Found corefile: $core_abs"
    bin_name_=`file $core_abs | awk -F \' '{print $2}'`
    bin_name=`basename $bin_name_`
    echo "from binary: $bin_name"

    core_dir_abs=$(dirname $core_abs)
    core_dir_basename=$(basename $core_dir_abs)
    bin_abs=$(find $core_dir_abs -name "$bin_name" -print)
    echo "Binary absolute path: $bin_abs"
    if [ -e "$bin_abs" ]; then
        grep "$core_dir_basename/$bin_name" $excluded_list > /dev/null
        if [ $? -ne 0 ]; then
            bin_core_list="$bin_core_list $core_abs $bin_abs"
        else
            echo "$bin_name is excluded"
        fi
    else
        bin_core_list="$bin_core_list $core_abs"
    fi
done

echo "List of files to pack: $bin_core_list"
if [ -n "$bin_core_list" ]; then
    tar cfvz binaries_and_corefiles.tar.gz $bin_core_list
    rhts_submit_log -l binaries_and_corefiles.tar.gz
else
    echo "No cores to submit"
fi

