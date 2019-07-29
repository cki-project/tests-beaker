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

cpupower_out="$(cpupower -c 0 frequency-info)"
cpupower_out_n="$(cpupower -c 0 frequency-info -n)"

low_hw_limit_str="$(echo "$cpupower_out" | grep 'hardware limits' | sed 's/.*: \([0-9.]* *[kMG]Hz \).*/\1/')"
hi_hw_limit_str="$(echo "$cpupower_out" | grep 'hardware limits' | sed 's/.*: .*Hz.*- \([0-9.]* *[kMG]Hz\).*/\1/')"
cur_freq_str="$(echo "$cpupower_out" | grep 'current CPU frequency:'| grep Hz | sed 's/.*: \([0-9.]* *[kMG]Hz \).*/\1/')"
low_hw_limit_n_str="$(echo "$cpupower_out_n" | grep 'hardware limits' | sed 's/.*: \([0-9.]* *[kMG]Hz \).*/\1/')"
hi_hw_limit_n_str="$(echo "$cpupower_out_n" | grep 'hardware limits' | sed 's/.*: .*Hz.*- \([0-9.]* *[kMG]Hz\).*/\1/')"
cur_freq_n_str="$(echo "$cpupower_out_n" | grep 'current CPU frequency:'| grep Hz | sed 's/.*: \([0-9.]* *[kMG]Hz \).*/\1/')"

echo "DATA low HW frequency limit: $low_hw_limit_str $low_hw_limit_n_str"
echo "DATA high HW frequency limit: $hi_hw_limit_str $hi_hw_limit_n_str"
echo "DATA current frequency: $cur_freq_str $cur_freq_n_str"

#Obtain value for rounding.
#String-add '5' after the last number in frequency. Convert it to number
#and numeric-substract the original value. The result is value of that '5'
#in right numeric scale:
# '1.605 GHz' - '1.60 GHz' = 5000000 Hz
#
#Assuming the same precision for the lowest and the highest frequency.
low_hw_limit_str_plus5="$(echo "$low_hw_limit_str" | sed 's/\([0-9.]*\) *\([kMG]Hz\)/\15\2/')"
rounding_value="$(echo "$low_hw_limit_str_plus5 - $low_hw_limit_str" | sed 's/GHz/* 10^9/g;s/MHz/* 10^6/g;s/kHz/* 10^3/g'|bc|sed 's/\.0*//')"

#The last sed can be omitted by using scale=0 command for bc. But it isn't working
#for real numbers on input, which appears in the current CPU frequency field.
low_hw_limit="$(echo "$low_hw_limit_str" | sed 's/GHz/* 10^9/;s/MHz/* 10^6/;s/kHz/* 10^3/'|bc|sed 's/\.0*//')"
hi_hw_limit="$(echo "$hi_hw_limit_str" | sed 's/GHz/* 10^9/;s/MHz/* 10^6/;s/kHz/* 10^3/'|bc|sed 's/\.0*//')"
cur_freq="$(echo "$cur_freq_str" | sed 's/GHz/* 10^9/;s/MHz/* 10^6/;s/kHz/* 10^3/'|bc|sed 's/\.0*//')"
low_hw_limit_n="$(echo "$low_hw_limit_n_str" | sed 's/GHz/* 10^9/;s/MHz/* 10^6/;s/kHz/* 10^3/'|bc|sed 's/\.0*//')"
hi_hw_limit_n="$(echo "$hi_hw_limit_n_str" | sed 's/GHz/* 10^9/;s/MHz/* 10^6/;s/kHz/* 10^3/'|bc|sed 's/\.0*//')"
cur_freq_n="$(echo "$cur_freq_n_str" | sed 's/GHz/* 10^9/;s/MHz/* 10^6/;s/kHz/* 10^3/'|bc|sed 's/\.0*//')"

echo "DATA low HW frequency limit: $low_hw_limit $low_hw_limit_n"
echo "DATA high HW frequency limit: $hi_hw_limit $hi_hw_limit_n"
echo "DATA current frequency: $cur_freq $cur_freq_n"

###################### FAILS ########################
retval=0
#The values should be the same, but one of them is affected by
#rounding much more, than the other, so the less affected number
#should fit to +-rounding_value window.
if [ "$low_hw_limit" -le "$(( low_hw_limit_n + rounding_value ))" ] && [ "$low_hw_limit" -gt "$(( low_hw_limit_n - rounding_value ))" ]; then
    echo "PASS low HW limit is the same with and without -n"
else
    echo "FAIL low HW limit differs with and without -n"
    (( retval += 1 ))
fi

if [ "$hi_hw_limit" -le "$(( hi_hw_limit_n + rounding_value ))" ] && [ "$hi_hw_limit" -gt "$(( hi_hw_limit_n - rounding_value ))" ]; then
    echo "PASS high HW limit is the same with and without -n"
else
    echo "FAIL high HW limit differs with and without -n"
    (( retval += 1 ))
fi

# don't check current frequency this way - it hasn't been snapped at the same time
# so it may differ

if [ "$low_hw_limit" -le "$hi_hw_limit" ]; then
    echo "PASS low HW limit is not bigger than high HW limit is"
else
    echo "FAIL low HW limit is bigger than high HW limit is"
    (( retval += 1 ))
fi

if [ "$low_hw_limit" -le "$cur_freq" ]; then
    echo "PASS low HW limit is not bigger than current frequency is"
else
    echo "FAIL low HW limit is bigger than current frequency is"
    (( retval += 1 ))
fi

if [ "$cur_freq" -le "$hi_hw_limit" ]; then
    echo "PASS current frequency is not bigger than high HW limit is"
else
    echo "FAIL current frequency is bigger than high HW limit is"
    (( retval += 1 ))
fi

echo "INFO: Next tests are trying to catch nonsense values."
echo "INFO: Low frequencies are 400-1600 MHz and I haven't seen CPU faster than 6GHz"
echo "INFO: even in extreme liquid nitrogen overclocking forums."
echo "INFO: Boundaries are set to 2017 year values. Low should be lower than 2 GHz."
echo "INFO: High should be lower than 10 GHz."
echo "INFO: Adjust these values according to state of the art if you want to use this test"
echo "INFO: in far future."

lo_thresh="2200000000" #2.2GHz
hi_thresh="10000000000" #10GHz

if [ "$low_hw_limit" -le "$lo_thresh" ]; then
    echo "PASS low HW limit is reasonably low"
else
    echo "FAIL low HW limit is not reasonably low"
    (( retval += 1 ))
fi

if [ "$hi_hw_limit" -le "$hi_thresh" ]; then
    echo "PASS high HW limit is reasonably low"
else
    echo "FAIL high HW limit is not reasonably low"
    (( retval += 1 ))
fi


###################### WARNS ########################
if [ "$low_hw_limit" -eq "$hi_hw_limit_n" ]; then
    echo "WARN low HW limit is the same as high HW limit"
fi

hi_thresh_warn="6000000000" #6GHz
if [ "$hi_hw_limit" -gt "$hi_thresh_warn" ]; then
    echo "WARN high HW limit may be too high (check state of the art)"
fi

exit "$retval"
