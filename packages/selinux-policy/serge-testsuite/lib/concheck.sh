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

# Concheck is script for selinux-policy tests consistency analysis.
# It checks for various aspects of the test and prints results into
# html page


OUTPUT=~/concheck.html
PHASES=`mktemp`

##if ! pwd | grep Regression\$ > /dev/null; then
##    echo "You have to be in selinux-policy/Regression directory!"
##    exit 1;
##fi

DATE=`date`

cat > $OUTPUT <<EOF
<html>
<head>
    <title>Selinux tests consistency check</title>
    <style>
.bgred { background-color: #ff9999; }
    </style>
    <link href="ts_style.css" rel="stylesheet" type="text/css" media="screen" />
    <script type="text/javascript" src="jquery-1.7.1.min.js"></script>
    <script type="text/javascript" src="jquery.tablesorter.min.js"></script>
    <script type="text/javascript">
        \$(document).ready(function() {
            \$("#concheck_table").tablesorter();
        });

    </script>
</head>
<body>

<h2>SELinux tests consistency check</h2>
<span style="font-size: small;">$DATE</span>
<table class="tablesorter" id="concheck_table">

<thead>
<tr>
    <th><b title="Name of the directory containing the test.">Test dir</b></th>
    <th><b title="Shows the number of Phases (except Setup and Cleanup)">Phases count</b></th>
    <th><b title="Shows if the test has Releases record in Makefile (should have at least -RHEL4).">Releases</b></th>
    <th><b title="Shows if the test uses new rlMatchpathcon fction or the old way of context check.">Matchpathcon</b></th>
    <th><b title="Shows whether the legacy workaround testpolicy.pp is conditioned by SPECIAL_POLICY_NEEDED variable.">testpolicy.pp</b></th>
    <th><b title="Shows whether the test uses the new Selinux Beaker Expansion library.">common-dev.sh</b></th>
    <th><b title="Shows if TAB is presented on the beginning of any line of test code.">Tabs/Spaces</b></th>

</tr>
</thead>

EOF


#COUNTER=10
for ITEM in `ls`; do

    #let COUNTER--
    #if [ $COUNTER -eq 0 ]; then break; fi

    if [ ! -d $ITEM ]; then
        echo "Excluding $ITEM - not a directory!"
        continue;
    fi

    if [ ! -f $ITEM/Makefile ] || [ ! -f $ITEM/runtest.sh ]; then
        echo "Excluding $ITEM -  not a test directory.";
        continue;
    fi

    echo "<tr>" >> $OUTPUT
    echo "<td> $ITEM </td>" >> $OUTPUT

    RUNTEST=$ITEM/runtest.sh
    MAKEFILE=$ITEM/Makefile

    ###############  Check for Releases section in Makefile ###################
    COUNT=`grep rlPhaseStartTest $RUNTEST | wc -l`
    echo "<td>${COUNT}</td>" >> $OUTPUT


    ###############  Check for Releases section in Makefile ###################
    if ! grep Releases $MAKEFILE >/dev/null; then
        echo "<td class=\"bgred\">MISSING!</td>" >> $OUTPUT
    else
        echo "<td class=\"bggreen\">OK</td>" >> $OUTPUT
    fi


    ###############  Check for old matchpathcon in runtest.sh ###################
    if grep matchpathcon $RUNTEST >/dev/null; then
        echo "<td class=\"bgred\">Use old matchpathcon!</td>" >> $OUTPUT
    else
        if grep rlMatchpathcon $RUNTEST >/dev/null; then
            echo "<td class=\"bgorange\">Deprecated rlMatchpathcon</td>" >> $OUTPUT
        elif grep rlSEMatchPathCon $RUNTEST >/dev/null; then
            echo "<td class=\"bggreen\">OK - New rlSEMatchPathCon</td>" >> $OUTPUT
        else
            echo "<td class=\"bggreen\">OK - Not used</td>" >> $OUTPUT
        fi
    fi


    ###############  Check for testpolicy in runtest.sh ###################
    if ! grep testpolicy.pp $RUNTEST >/dev/null; then
        echo "<td class=\"bggreen\">No testpolicy</td>" >> $OUTPUT
    else
        if grep SPECIAL_POLICY_NEEDED $RUNTEST >/dev/null; then
            echo "<td class=\"bggreen\">Testpolicy - SPECIAL_POLICY_NEEDED</td>" >> $OUTPUT
        else
            echo "<td class=\"bgred\">Testpolicy - no condition</td>" >> $OUTPUT
        fi
    fi

    ###############  Check for common-dev.sh usage ###################
    if ! grep '. ../../common/common-dev.sh' $RUNTEST >/dev/null; then
        echo "<td class=\"bgorange\">Not used</td>" >> $OUTPUT
    else
        if grep 'RhtsRequires:    test(/CoreOS/selinux-policy/common)' $MAKEFILE >/dev/null; then
            echo "<td class=\"bggreen\">Used</td>" >> $OUTPUT
        else
            echo "<td class=\"bgred\">Missing RhtsRequires</td>" >> $OUTPUT
        fi
    fi


    ###############  Check for tabs runtest.sh ###################
    if grep $'^\t' $RUNTEST >/dev/null; then
        echo "<td class=\"bgred\">Tab!</td>" >> $OUTPUT
    else
        echo "<td class=\"bggreen\">OK - No Tab</td>" >> $OUTPUT
    fi



    ###############  Extract all Phases names  ###################
    grep rlPhaseStartTest $RUNTEST >> $PHASES

    echo "</tr>" >> $OUTPUT

done

cat >> $OUTPUT <<EOF
</table>
EOF

#echo "<pre>" >> $OUTPUT
#cat $PHASES | sed 's/.*rlPhaseStartTest.*"\(.*\)"/\1/' | sort | uniq -c | sort -n >> $OUTPUT
#echo "</pre>" >> $OUTPUT

cat >> $OUTPUT <<EOF
</body>
</html>
EOF


[[ ! -d /mnt/qa/scratch/mtruneck ]] && mkdir -p /mnt/qa/scratch/mtruneck
cp $OUTPUT /mnt/qa/scratch/mtruneck/concheck.html

