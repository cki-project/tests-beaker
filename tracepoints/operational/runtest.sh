#!/bin/bash

# Source the common test script helpers
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1



STAP_VERBOSE_FLAG="-v"
if [ x"${STP_VERBOSE}" = x"y" ]; then
    STAP_VERBOSE_FLAG="-vvvv"
fi

# Helper functions
function resultFail()
{
    echo "***** End of runtest.sh *****" | tee -a $OUTPUTFILE
    report_result $1 FAIL $2
    echo "" | tee -a $OUTPUTFILE
}

function resultPass ()
{
    echo "***** End of runtest.sh *****" | tee -a $OUTPUTFILE
    report_result $1 PASS $2
    echo "" | tee -a $OUTPUTFILE
}

function submitLog ()
{
    LOG=$1
    if [ -z "$TESTPATH" ]; then
        echo "Running in developer mode"
    else
        rhts_submit_log -S $RESULT_SERVER -T $TESTID -l $LOG
    fi
}

function testHeader ()
{
    echo "***** Starting the runtest.sh script *****" | tee $OUTPUTFILE
    echo "***** Current Running Kernel Package = "$kernbase" *****" | tee -a $OUTPUTFILE
    echo "***** Installed systemtap version = "$stapbase" *****" | tee -a $OUTPUTFILE
    echo "***** Current Running Distro = "$installeddistro" *****" | tee -a $OUTPUTFILE
}

function timeCalc ()
{
    # end & test time
    ETIME=`date +%s`
    TTIME=`expr $ETIME - $STIME`
}

function isCpuFamilyModel ()
{
    local CPU=$1
    local FAMILY=$2
    local MODEL=$3
    
    cat /proc/cpuinfo  | awk  "BEGIN {CPU=\"NO\"; FAMILY=\"NO\"; MODEL=\"NO\"; MATCH=1} /^vendor_id/ { CPU = \$3 }; /^cpu family/ { FAMILY=\$4}; /^model\t/ { MODEL=\$3}; (CPU == \"$CPU\") && (FAMILY == \"$FAMILY\") && (MODEL == \"$MODEL\") { MATCH=0}; END {exit MATCH}"
    return $?
}

function testList ()
{
    local TESTLIST="$1"
    local GROUP_SIZE="$2"
    local COUNT=0
    local PROBE_COUNT=`echo $TESTLIST | wc -w`
    local PROBES_FILE=`mktemp -p /tmp -t group.XXXXXX`
    local PROBES_NAME_FILE=`mktemp -p /tmp -t group_probe_names.XXXXXX`
    for i in $TESTLIST; do

        # Create unique log for verbose tracepoint logging
        COUNT=`expr $COUNT + 1`
        STIME=`date +%s`

        echo "$i" | grep -q "hcall_"
        if [ $? -eq 0 ]; then
                echo "Skipping probe $i due to Bug 1143870" | tee -a $OUTPUTFILE
                echo "Bug 1143870 - ppc64le kernel hangs while running systemtap with hcall_entry/hcall_exit probes" | tee -a $OUTPUTFILE
                continue
        fi

        echo "$i" | tr -d '\"' >> $PROBES_NAME_FILE
        echo 'probe kernel.trace('$i') { if (pid() == 0) printf("probe hit\n"); }' >> $PROBES_FILE

        if [ $((COUNT % GROUP_SIZE)) == 0 -o $COUNT == $PROBE_COUNT ]; then

            testHeader
            echo "------------------------------------------------------------" | tee -a $OUTPUTFILE
            echo "         Start of SystemTap Kernel Tracepoint Test          " | tee -a $OUTPUTFILE
            echo "         $STIME                                             " | tee -a $OUTPUTFILE
            echo "         Testing:                                           " | tee -a $OUTPUTFILE
            cat $PROBES_FILE | tee -a $OUTPUTFILE
            echo "------------------------------------------------------------" | tee -a $OUTPUTFILE

            cat $PROBES_FILE > group.stap

            local firstp=`head -1 $PROBES_NAME_FILE`
            local lastp=`tail -1 $PROBES_NAME_FILE`
            local VAR="$firstp"
            if [ ! "$firstp" == "$lastp" ]; then
                local VAR="${firstp}__to__${lastp}"
            fi
            local VERBOSETRACELOG=`mktemp -p /mnt/testarea -t $VAR-TraceLog.XXXXXX`

            stap -DSTP_NO_OVERLOAD $XTRA -t -c "sleep 0.25" ${STAP_VERBOSE_FLAG} group.stap > $VERBOSETRACELOG 2>&1
            local rc=$?
            timeCalc
            if [ $rc -eq 0 ] ; then
                echo "       Result testing : Test Passed " | tee -a $OUTPUTFILE
                echo "       Test run time  : $TTIME seconds " | tee -a $OUTPUTFILE
                echo "------------------------------------------------------------" | tee -a $OUTPUTFILE
                resultPass $VAR $COUNT
            else
                echo "       Result testing : Test Failed " | tee -a $OUTPUTFILE
                echo "       Test run time  : $TTIME seconds " | tee -a $OUTPUTFILE
                echo "------------------------------------------------------------" | tee -a $OUTPUTFILE
                submitLog $VERBOSETRACELOG
                resultFail $VAR $COUNT
            fi
            rm -f $PROBES_FILE
            rm -f $PROBES_NAME_FILE
        fi
    done
}

function runTest ()
{
    local TESTLIST=`/usr/bin/stap -L 'kernel.trace("*")' | grep -o "\".*\""`
    if [ -z "$TESTLIST" ] ; then
        resultFail TESTLIST_EMPTY 99
        exit 0
    fi

    # Bug 1541287 - WARNING: CPU: 3 PID: 10291 at kernel/jump_label.c:188 __jump_label_update+0x95/0xa0
    if grep -q "release 7.5" /etc/redhat-release; then
        TESTLIST=$(echo "$TESTLIST" | sed '/xen:xen_cpu_write_gdt_entry/d')
        TESTLIST=$(echo "$TESTLIST" | sed '/xen:xen_cpu_write_idt_entry/d')
    fi

    # Additional argumewnt to stap if Family is RHEL5 and CPU/Family/Model match
    [ "$FAMILY" == "RedHatEnterpriseLinuxServer5" ] && isCpuFamilyModel AuthenticAMD 21 2
    if [ "$?" == 0 ]; then
        XTRA="-DTRYLOCKDELAY=300"
    fi
    stap --clean-cache
    testList "$TESTLIST" 32
}

# Setup some variables
if [ -e /etc/redhat-release ] ; then
    installeddistro=`cat /etc/redhat-release`
else
    installeddistro=unknown
fi

# select tool to manage package, which could be "yum" or "dnf"
function select_yum_tool() {
    if [ -x /usr/bin/dnf ]; then
        echo "/usr/bin/dnf"
    elif [ -x /usr/bin/yum ]; then
        echo "/usr/bin/yum"
    else
        return 1
    fi

    return 0
}

yum=$(select_yum_tool)

kernbase=$(rpm -q --queryformat '%{name}-%{version}-%{release}.%{arch}\n' -qf /boot/config-$(uname -r))
stapbase=$(rpm -q --queryformat '%{name}-%{version}-%{release}.%{arch}\n' -qf /usr/bin/stap)

# Skip test if we are in FIPS mode, unsigned modules will cause kernel panic
grep "1" /proc/sys/crypto/fips_enabled  > /dev/null
if [ $? -eq 0 ]; then
    echo "***** Running in FIPS mode, stap modules would cause kernel panic ****" | tee -a $OUTPUTFILE
    rhts-report-result $TEST SKIP $OUTPUTFILE
    exit 0
fi

# Warn if gcc does not have retpoline (x86_64) or expoline (s390x) support.
# SystemTap cannot find any tracepoints in newer kernels with Spectre v2
# mitigations without retpoline/expoline support in gcc.
# aarch64 and ppc64le mitigated Spectre v2 through other means so we do
# not need to check those platforms for gcc support.
if [ -e /sys/devices/system/cpu/vulnerabilities/spectre_v2 ]; then
  CFLAGS=""
  if [ "`uname -i`" = "x86_64" ]; then
    CFLAGS="-mindirect-branch=thunk-extern"
    CFLAGS+=" -mindirect-branch-register"
    MITIGATION="retpoline"
  elif [ "`uname -i`" = "s390x" ]; then
    CFLAGS="-mindirect-branch=thunk-extern"
    CFLAGS+=" -mindirect-branch-table"
    CFLAGS+=" -mfunction-return=thunk-extern"
    MITIGATION="expoline"
  fi

  if [ -n "$CFLAGS" ]; then
    if ! gcc -Werror $CFLAGS -E -x c /dev/null -o /dev/null >/dev/null 2>&1
    then
      report_result "gcc does not have $MITIGATION support" WARN 1
    fi
  fi
fi

# Skip test if we are running an earlier distro (Supported in RHEL5.4)
OSREL=`grep -o 'release [[:digit:]]\+' /etc/redhat-release | awk '{print $2}'`
KERNVER=`/bin/uname -r | /bin/awk -F- {'print $2'} | /bin/awk -F. {'print $1'}`

# ensure KERNVER contains only digits
[[ "$KERNVER" =~ ^[[:digit:]]+$ ]] || KERVER=0

grep -q "Fedora" /etc/redhat-release
if [ $? -eq 0 ] ; then  # Check if upstream-Fedora
    runTest
elif [[ "$OSREL" = "5" ]] && [[ "$KERNVER" -ge "156" ]] ; then
    runTest
elif [[ "$OSREL" =~ [678] ]] ; then
    runTest
else
    echo "***** tracepoint not enabled in this kernel *****" | tee -a $OUTPUTFILE
    echo "***** End of runtest.sh *****" | tee -a $OUTPUTFILE
    echo"" | tee -a $OUTPUTFILE
    rhts-report-result $TEST SKIP $OUTPUTFILE
    exit 0

fi
