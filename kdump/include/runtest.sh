#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


# Source rhts environment 
. /usr/bin/rhts-environment.sh


K_TESTAREA="/mnt/testarea"
K_NFS="${K_TESTAREA}/KDUMP-NFS"
K_PATH="${K_TESTAREA}/KDUMP-PATH"
K_RAW="${K_TESTAREA}/KDUMP-RAW"
K_RAID="${K_TESTAREA}/KDUMP-RAID"
K_REBOOT="./KDUMP-REBOOT"
KDUMP_CONFIG="/etc/kdump.conf"
KDUMP_SYS_CONFIG="/etc/sysconfig/kdump"

[[ "$FAMILY" =~ [a-zA-Z]+5 ]] && IS_RHEL5=true || IS_RHEL5=false
[[ "$FAMILY" =~ [a-zA-Z]+6 ]] && IS_RHEL6=true || IS_RHEL6=false
[[ "$FAMILY" =~ [a-zA-Z]+7 ]] && IS_RHEL7=true || IS_RHEL7=false
[[ "$FAMILY" =~ [a-zA-Z]+8 ]] && IS_RHEL8=true || IS_RHEL8=false

if $IS_RHEL5 || $IS_RHEL6; then
    INITRD_PREFIX=initrd
else
    INITRD_PREFIX=initramfs
fi
INITRD_IMG_PATH="/boot/$INITRD_PREFIX-`uname -r`.img"

# e.g. x86_64
K_ARCH=`uname -m`

# e.g 4.18.0-74.el8
K_KVER=`uname -r | sed "s/\.$K_ARCH//"`

# debug|PAE|xen|trace|vanilla if any
K_KVARI=`echo $K_KVER | grep -Eo '(debug|PAE|xen|trace|vanilla)$'`

# .e.g kernel-2.6.32-220.el6.src.rpm
K_KSRC=`rpm -q --queryformat '%{sourcerpm}\n' -qf /boot/config-$(uname -r)`

# In RHEL-8, `uname -r` on a debug kernel returns '4.18.0-40.el8.x86_64+debug'
# Instead of '3.10.0-957.1.2.el7.x86_64.debug' as it usually is in RHEL-7
K_KVERS=`echo $K_KVER | sed "s/[.+]*$K_KVARI$//"`

# This is a little cryptic, in practice it takes the full src rpm file
# name and strips everytihng after (including) the version, leaving just
# the src rpm package name.
# Needed when the kernel rpm comes from of e.g. kernel-pegas src rpm.
K_SPEC_NAME=${K_KSRC%%-${K_KVER}*}


K_SSH_CONFIG="${HOME}/.ssh/config"
K_ID_RSA="${SSH_KEY:-/root/.ssh/kdump_id_rsa}"
K_DEFAULT_PATH="/var/crash"
IS_RT_KEN=false

K_DEBUG=${K_DEBUG:-false}
K_NFSSERVER=${K_NFSSERVER:-""}
K_VMCOREPATH=${K_VMCOREPATH:-"/var/crash"}

ALLOW_SKIP=${ALLOW_SKIP:-true}

[ "${K_ARCH}" = "ia64" ] && K_BOOT="/boot/efi/efi/redhat" || K_BOOT="/boot"

# back up kdump config files
[ -f "${KDUMP_CONFIG}.bk" ] || cp "${KDUMP_CONFIG}" "${KDUMP_CONFIG}.bk"
[ -f "${KDUMP_SYS_CONFIG}.bk" ] || cp "${KDUMP_SYS_CONFIG}" "${KDUMP_SYS_CONFIG}.bk"

DisableAVCCheck()
{
  echo "Disable AVC check"
  export AVC_ERROR=+no_avc_check
}

# Disable AVC Check for all kdump tests
DisableAVCCheck

# Erase possible preceding/trailing white spaces.
Chomp()
{
    echo "$1" | sed '/^[[:space:]]*$/d;
        s/^[[:space:]]*\|[[:space:]]*$//g'
}

TurnDebugOn()
{
    if $IS_RHEL7 || $IS_RHEL8 ; then
        sed -i 's;\(/bin/sh\)$;\1 -x;' /usr/bin/kdumpctl
        sed -i 's;2>/dev/null;;g' /usr/bin/kdumpctl
    else
        sed -i 's;\(/bin/sh\);\1 -x;' /etc/init.d/kdump
    fi
}

GetBiosInfo()
{
    # Get BIOS information.
    dmidecode >"${K_TESTAREA}/bios.log"
    rhts-submit-log -l "${K_TESTAREA}/bios.log"
}

GetHWInfo()
{
    Log "- Getting system hw or firmware config."
    lshw > "${K_TESTAREA}/lshw.output"
    RhtsSubmit "${K_TESTAREA}/lshw.output"

    which lscfg && {
        lscfg > "${K_TESTAREA}/lscfg.output"
        RhtsSubmit "${K_TESTAREA}/lscfg.output"
    }
}


LsCore()
{
    Log "\n# ls -l ${vmcore}"
    ls -l "${vmcore}" >>"${OUTPUTFILE}" 2>&1
    [ $? -ne 0 ] && FatalError "ls returns errors."
    Log "\n"
}

GetCorePath()
{
    local path

    [ -f "${K_PATH}" ] && path=`cat "${K_PATH}"` || path="${K_DEFAULT_PATH}"

    if [ -f "${K_NFS}" ]; then
        corepath="$(cat "${K_NFS}")${path}"
    else
        corepath="${path}"
    fi

    # debug use
    Log "# find ${corepath}"
    find "${corepath}" 2>&1 | tee -a "${OUTPUTFILE}"
    Log "\n# ls -tl ${corepath}/*/"
    ls -tl "${corepath}"/*/ 2>&1 | tee -a "${OUTPUTFILE}"

    # Always analyse the latest vmcore.
    if ls -t "${corepath}"/*/vmcore; then
        vmcore=$(ls -t "${corepath}"/*/vmcore 2>/dev/null | head -1)
    else
        Error "no vmcore found in ${corepath}"
        Report
    fi
}

CheckConfig()
{
    local multi=$1

    if [ ! -f "${KDUMP_CONFIG}" ]; then
        [ -n "${multi}" ] && rhts_sync_set -s "DONE"
        FatalError "Unable to find /etc/kdump.conf"
    fi
}

AppendConfig()
{
    Log "- Modifying /etc/kdump.conf"

    if [ $# -eq 0 ]; then
        Warn "Nothing to append."
        return 0
    fi

    while [ $# -gt 0 ]; do
        Log "- Removing existed old ${1%%[[:space:]]*} settings."
        sed -i "/^${1%%[[:space:]]*}/d" ${KDUMP_CONFIG}
        Log "- Adding new '$1'."
        echo "$1" >>"${KDUMP_CONFIG}"
        shift
    done

    rhts-submit-log -l "${KDUMP_CONFIG}"
}

ReportKdumprd()
{
    Log "- Reporting kdump rd image"
    if $IS_RHEL5 || $IS_RHEL6; then
        tmp=initrd
    else
        tmp=initramfs
    fi

    # Submit Kdump initramfs.
    if grep -q "fadump=on" < /proc/cmdline; then
        kdumprd=${K_BOOT}/$tmp-$(uname -r).img
    else
        kdumprd=${K_BOOT}/$tmp-$(uname -r)kdump.img
    fi

    if [ -f "${kdumprd}" ]; then
        RhtsSubmit "${kdumprd}"
    else
        Error '- No ĸdumprd generated!'
    fi

    sync
}

# print out kdump status
# no error handling
CheckKdumpStatus()
{
    kdumpctl status || service kdump status || systemctl status kdump
}

RestartKdump()
{
    local tmp=""
    local kdumprd=""
    local rc=

    Log "- Restarting Kdump service."

    # TODO: some ppc64 has wrong timestamp, this is a workaround for rhel6
    # BZ: 816831
    rm -f /boot/initrd-*kdump.img
    rm -f /boot/initramfs-*kdump.img    # For RHEL7
    touch "${KDUMP_CONFIG}"

    if $IS_RHEL5 || $IS_RHEL6; then
        tmp=initrd
        /sbin/service kdump restart 2>&1 | tee /tmp/kdump_restart.log
        /sbin/service kdump status  2>&1
    else
        tmp=initramfs
        /usr/bin/kdumpctl showmem 2>&1
        /usr/bin/kdumpctl restart 2>&1 | tee /tmp/kdump_restart.log
        /usr/bin/kdumpctl status  2>&1
    fi
    rc=$?
    Log "`cat /tmp/kdump_restart.log`"
    [ $rc -ne 0 ] && FatalError 'Restarting kdump failed.'

    sync; sync; sleep 10

    # It may report "No kdump initial ramdisk found.[WARNING]" in rhel6
    local skip_pat="No kdump initial ramdisk found|Warning: There might not be enough space to save a vmcore|Warning no default label"
    if grep -v -E "$skip_pat" /tmp/kdump_restart.log |  grep -i -E "can't|error|warn";  then
        Warn 'Restarting kdump reported warn/error message'
    fi

    sync;

    ReportKdumprd

}




GetRaw()
{
    if [ -f ${K_RAW} ]; then
        rawdump=`cat ${K_RAW}`
    else
        rawdump=`df | grep dump | awk -F " " '{print $1}'`
        echo $rawdump > ${K_RAW}
    fi

    [ -z "${rawdump}" ] && FatalError "No dump partition found."
    # Avoid fsck in next boot since it's a raw device
    sed -i "/dump/d" /etc/fstab
}

GetDumpfs()
{
    local path

    # If we have already supplied a path value, we'll use it here.
    # Otherwise, we will not know which partition to use during Kdump.
    if [ -n "$1" ]; then
        path=$1
    elif [ -f "${K_PATH}" ]; then
        path=$(cat "${K_PATH}")
    else
        path="${K_DEFAULT_PATH}"
    fi

    # Handle target directory is on a separated partition.
    fsline=$(mount | grep " ${path} ")

    # FIXME: parent directories on a separated partion.

    # Check rootfs.
    if [ -z "${fsline}" ]; then
        fsline=$(mount | grep ' / ')
    else
        # If /var/crash is on a separate partition, then VMCore will be
        # found at /var/crash/var/crash.
        echo "${path}${path}" >"${K_PATH}"
    fi

    if ! ( $IS_RHEL7 || $IS_RHEL8 ); then
        if [[ $(echo "${fsline}" | awk '{print $5}') != ext[34] ]]; then
            FatalError "target directory is not on an EXT3/EXT4 partition."
        fi
    fi

    target=$(echo "${fsline}" | awk '{print $1}')
}

FindModule()
{
    local name=$1

    #see if module was compiled in
    modname="$(modprobe -nv $name 2>/dev/null | grep $name.ko)"
    if test -n "$modname"; then
        echo "$modname" | sed 's/insmod //'
        return
    fi

    #see if it was precompiled
    if test -f "$name/$name.ko"; then
        echo "$name/$name.ko"
        return
    fi

    #we have to create it
    echo ""
    return
}

MakeModule()
{
    local name=$1

    mkdir "${name}"
    mv "${name}.c" "${name}"
    mv "Makefile.${name}" "${name}/Makefile"

    if [ "${K_ARCH}" = "ppc64" ]; then
        Log "- unset ARCH for ${K_ARCH}."
        unset ARCH
    fi

    make -C "${name}"
    [ $? -ne 0 ] && MajorError "Unable to compile ${name} Kernel module."
}

# Install kernel related packages
InstallKernel()
{
    local pkgs="$*"
    local tmp=""

    [ ! -n "${pkgs}" ] && return 0

    Log "# yum install ${pkgs}"
    yum -y install ${pkgs}
    for i in ${pkgs}; do
        rpm -q $i >/dev/null || tmp="${tmp} $i"
    done

    [ ! -n "${tmp}" ] && return 0
}

# Install kernel debuginfo packages
InstallDebuginfo()
{
    local kvari="$1"
    local kern=$(rpm -qf /boot/vmlinuz-$(uname -r) --qf "%{name}-debuginfo-%{version}-%{release}.%{arch}" | sed -e "s/-core//g")
    local comm=""

    #workaround the kernel name in rhel8
    if [[ "$kern" == kernel-core-debuginfo-* ]]; then
        kern=${kern//kernel-core/kernel}
    fi

    # even vanilla is not PREEMPT RT kernel, it is packages as kernel-rt
    if $(uname -v | grep -q PREEMPT\ RT) || [[ $K_KVARI == "vanilla" ]] ; then
        comm="kernel-rt-debuginfo-common-${K_ARCH}-${K_KVERS}.${K_ARCH}"
        IS_RT_KEN=true
    elif $IS_RHEL5; then
        comm="kernel-debuginfo-common-${K_KVERS}.${K_ARCH}"
    else
        comm="kernel-debuginfo-common-${K_ARCH}-${K_KVERS}.${K_ARCH}"
    fi

    rpm -q ${comm} ${kern} ||
    InstallKernel ${comm} ${kern} ||
    Error "Failed to install kernel debuginfo packages"
}

CheckEnv()
{
    # Check test environment.
    if [ -z "${JOBID}" ]; then
        Log "Variable JOBID does not set! Assume developer mode."
        SERVERFILE="Server-$(date +%H_%j)"
        DEVMODE=true
    else
        SERVERFILE="Server-${JOBID}"
    fi
}

PrepareCrash()
{
    # install crash package and kernel-debuginfo required for testing crash untilities.
    rpm -q crash || yum install -y crash
    InstallDebuginfo
}

PrepareReboot()
{
    # IA-64 needs nextboot set.
    if [ -e "/usr/sbin/efibootmgr" ]; then
        EFI=$(efibootmgr -v | grep BootCurrent | awk '{ print $2}')
        if [ -n "$EFI" ]; then
            Log "- Updating efibootmgr next boot option to $EFI according to BootCurrent"
            efibootmgr -n $(efibootmgr -v | grep BootCurrent | awk '{ print $2}')
        elif [[ -z "$EFI" && -f /root/EFI_BOOT_ENTRY.TXT ]] ; then
            os_boot_entry=$(</root/EFI_BOOT_ENTRY.TXT)
            Log "- Updating efibootmgr next boot option to $os_boot_entry according to EFI_BOOT_ENTRY.TXT"
            efibootmgr -n $os_boot_entry
        else
            Log "- Could not determine value for BootNext!"
        fi
    fi
}

SaveVmcoreForDebug()
{
    local core=$1
    [ -z "$core" ] && return 1

    if [[ "${K_NFSSERVER}" =~ ^[[:space:]]*$ ]]; then
        Log "No vmcore is saved as no K_NFSSERVER is provided."
        return
    fi

    local mp=/tmp/vmcore_debug
    mkdir -p ${mp}
    mount $K_NFSSERVER:$K_VMCOREPATH ${mp}
    [ $? -eq 0 ] || return 1

    SUBMITTER=${SUBMITTER%@*}
    SUB_DIR=${SUBMITTER:-noowner}/${JOBID:-nojobid}/${HOSTNAME:-nohostname}
    UPLOAD_PATH=${mp}/$SUB_DIR
    mkdir -p "$UPLOAD_PATH"

    core_dir=$(dirname "$core")
    cp -r $core_dir $UPLOAD_PATH
    [ $? -eq 0 ] || {
        umount ${mp}
        return 1
    }
    umount ${mp}
}

# Run crash cmd defined in $cmd_file. Only return code is checked.
# Output:
#   ${cmd_file%.*}.log if on a live system
#   ${cmd_file%.*}.vmcore.log if on a vmcore
CrashCommand_CheckReturnCode()
{
    local args=$1; shift
    local aux=$1; shift
    local core=$1; shift
    local cmd_file=${1:-"crash-simple.cmd"}; shift
    local log_suffix
    [ -z "$core" ] && log_suffix=log || log_suffix="${core##*/}.log"

    Log "- Only check the return code of this session."
    Log "# crash ${args} -i ${K_TESTAREA}/${cmd_file} ${aux} ${core}"

    if [ -f "${K_TESTAREA}/${cmd_file}" ]; then
        # The EOF part is the workaround of the the crash utility bug
        # 458422 -- [RFE] Scripting Friendly, which has only been fixed
        # in RHEL5.3. Otherwise, the crash utility session would fail
        # during the initialization when invoked from a script without a
        # control terminal.
        crash ${args} -i "${K_TESTAREA}/${cmd_file}" ${aux} ${core} \
                > "${K_TESTAREA}/${cmd_file%.*}.$log_suffix" 2>&1 <<EOF
EOF
        code=$?

        echo | tee -a "${OUTPUTFILE}"
        RhtsSubmit "${K_TESTAREA}/${cmd_file%.*}.$log_suffix"
        RhtsSubmit "${K_TESTAREA}/${cmd_file}"

        if [ ${code} -eq 0 ]; then
            return 0
        else
            Error "crash returns error code ${code}."
            return 1
        fi

    fi
}

# Run crash cmd defined in $cmd_file. Check if output contains potential errors.
# Output:
#   ${cmd_file%.*}.log if on a live system
#   ${cmd_file%.*}.vmcore.log if on a vmcore
CrashCommand_CheckOutput()
{
    local args=$1; shift
    local aux=$1; shift
    local core=$1; shift
    local cmd_file=${1:-"crash.cmd"}; shift
    local log_suffix
    [ -z "$core" ] && log_suffix=log || log_suffix="${core##*/}.log"

    local result=0

    Log "- Check command output of this session."
    Log "# crash ${args} -i ${K_TESTAREA}/${cmd_file} ${aux} ${core}"

    if [ -f "${K_TESTAREA}/${cmd_file}" ]; then
        crash ${args} -i "${K_TESTAREA}/${cmd_file}" ${aux} ${core} \
                >"${K_TESTAREA}/${cmd_file%.*}.$log_suffix" 2>&1 <<EOF
EOF
        code=$?

        if [ ${code} -ne 0 ]; then
            Error "crash returns error code ${code}."
            result=1
        fi

        RhtsSubmit "${K_TESTAREA}/${cmd_file%.*}.$log_suffix"
        RhtsSubmit "${K_TESTAREA}/${cmd_file}"

        ValidateCrashOutput "${K_TESTAREA}/${cmd_file%.*}.$log_suffix"

        if [ $? -eq 0 ]; then
            Log "- crash successfully analysed vmcore."
            Log "  See ${cmd_file%.*}.$log_suffix for more details."
        else
            result=1
        fi

        return $result
    fi
}

ValidateCrashOutput()
{
    local cmd_output_file=$1
    local result=0

    [ -z "$cmd_output_file" ] && return 1

    # Crash does not return sensitive error codes.
    echo | tee -a "${OUTPUTFILE}"
    Log "- Skip the following patterns when searching for potential errors."

    Log "- '_FAIL_'"
    Log "- 'Instruction bus error [***] exception frame:'"

    # In aarch64 vmcore analyse testing, the "err" string that is passed to __die() is
    # preceded by "Internal error: ", shown here in "arch/arm64/kernel/traps.c".
    # PANIC: "Internal error: Oops: 96000047 [#1] SMP" (check log for details)'
    Log "- 'PANIC'"

    # Dave Anderson <anderson@redhat.com> updated the pageflags_data in
    # crash-7.0.2-2.el7 to include the use of '00000002: error' which
    # causes /kernel/kdump/analyse-crash to FAIL.
    Log "- '00000002: error'"

    # We have seen those false negative results before
    # e00000010a3b2980 e000000110198fb0 e000000118f09a10 REG
    # /var/log/cups/error_log
    Log "- 'error_'"

    # flags: 6 (KDUMP_CMPRS_LOCAL|ERROR_EXCLUDED)
    Log "- 'ERROR_'"

    # e00000010fe82c60 e000000118f0a328 REG
    # usr/lib/libgpg-error.so.0.3.0
    Log "- '-error'"

    # [0] divide_error
    # [16] coprocessor_error
    # [19] simd_coprocessor_error
    Log "- '_error'"

    # Data Access error  [301] exception frame:
    Log "- 'Data Access error'"

    # fph = {{
    #     u = {
    #       bits = {3417217742307420975, 65598},
    #       __dummy = <invalid float value>
    #     }
    #   }, {
    Log "- 'invalid float value'"


    # crash> foreach crash task
    # ...
    # fail_nth = 0
    Log "- 'fail_nth'"

    # [ffff81007e565e48] __down_failed_interruptible at ffffffff8006468b
    Log "- '_fail'"

    #       failsafe_callback_cs = 97,
    #       failsafe_callback_eip = 3225441872,
    Log "- 'failsafe'"

    # crash> mod
    #      MODULE       NAME                      SIZE  OBJECT FILE
    # ...
    # ffffffffc0310080  failover                 16384  (not loaded)  [CONFIG_KALLSYMS]
    Log "- 'failover'"

    # [ffff81003ee83d60] do_invalid_op at ffffffff8006c1d7
    # [6] invalid_op
    # [10] invalid_TSS
    Log "- 'invalid_'"

    # [253] invalidate_interrupt
    Log "- 'invalidate'"

    # name: a00000010072b4e8  "PCIBR error"
    Log "- 'PCIBR error'"

    # name: a000000100752ce0  "TIOCE error"
    Log "- 'TIOCE error'"

    # beaker testing harness has a process 'beah-beaker-bac' which
    # will open a file named  /var/beah/journals/xxxxx/debug/task_beah_unexpected
    # which will be showed by 'foreach files'
    Log "- 'task_beah_unexpected'"

    # arm-smmu-v3-gerror is an IRQ line implemented in some aarch64 machines
    # like Qualcomm Amberwing (CPU: Centriq 2400)
    # crash> irq 124
    # IRQ   IRQ_DESC/_DATA      IRQACTION      NAME
    # 124  ffff8017d8d2f000  ffff8017d8d0e280  "arm-smmu-v3-gerror"
    Log "- 'arm-smmu-v3-gerror'"


    Log "\n- Search for the following patterns for potential errors."

    Log "- 'fail'"
    Log "- 'error'"
    Log "- 'invalid'"
    Log "- 'absurdly large unwind_info'"
    Log "- 'unexpected'"
    Log "- 'crash: page excluded: kernel virtual address'"
    Log "- 'zero-size memory allocation'"
    Log "- 'dev: -d option not supported or applicable on this architecture or kernel'"
    Log "- 'dev: -D option not supported or applicable on this architecture or kernel'"
    # dev -p is supported on RHEL5 and RHEL8.
    Log "- 'dev: -p option not supported or applicable on this architecture or kernel'"


    # Skip false warnings.
    #   mod: cannot find or load object file for crasher/altsysrq module
    #   (cannot determine file and line number)
    #
    # Search for the following words for warnings.
    #   warning
    #   warnings
    #   cannot
    Log "\n- WARNING MESSAGES BEGIN"
    grep -v \
         -e "mod: cannot find or load object file for crasher module" \
         -e "mod: cannot find or load object file for altsysrq module" \
         -e "mod: cannot find or load object file for crash_warn module" \
         -e "mod: cannot find or load object file for hung_task module" \
         -e "mod: cannot find or load object file for lkdtm module" \
         -e "bt: cannot determine NT_PRSTATUS ELF note for active task" \
         -e "bt: WARNING: cannot determine starting stack frame for task" \
         -e "cannot determine file and line number" \
         -e "cannot be determined: try -t or -T options" \
         -e "WARNING: kernel relocated" \
         -e "WARNING: page fault at" \
         -e "WARNING: FPU may be inaccurate" \
         -e "WARNING: cannot find NT_PRSTATUS note for cp" \
         "${cmd_output_file}" |
    if [ -n "${SKIP_WARNING_PAT}" ]; then grep -v -e "${SKIP_WARNING_PAT}"; else cat; fi |
        grep -iw -e 'warning' \
             -e 'warnings' \
             -e 'cannot' \
             2>&1 | tee -a "${OUTPUTFILE}"
    local warnFound=${PIPESTATUS[2]}
    Log "- WARNING MESSAGES END"

    if [ "${warnFound}" -eq 0 ]; then
        Warn "crash commands have some warnings."
        result=1
    fi

    Log "- ERROR MESSAGES BEGIN"
    grep -v -e '_FAIL_' \
         -e 'PANIC:' \
         -e 'Instruction bus error  \[[0-9]*\] exception frame:' \
         -e '00000002: error' \
         -e 'error_' \
         -e 'ERROR_' \
         -e '-error' \
         -e '_error' \
         -e 'Data Access error' \
         -e 'invalid float value' \
         -e 'fail_nth' \
         -e '_fail' \
         -e 'failsafe' \
         -e 'failover' \
         -e 'invalid_' \
         -e 'invalidate' \
         -e 'PCIBR error' \
         -e 'TIOCE error' \
         -e 'task_beah_unexpected' \
         -e 'arm-smmu-v3-gerror' \
         "${cmd_output_file}" |
    if [ -n "${SKIP_ERROR_PAT}" ]; then grep -v -e "${SKIP_ERROR_PAT}"; else cat; fi |
        grep -i -e 'fail' \
             -e 'error' \
             -e 'invalid' \
             -e 'absurdly large unwind_info' \
             -e 'unexpected' \
             -e 'crash: page excluded: kernel virtual address' \
             -e 'zero-size memory allocation' \
             -e 'dev: -d option not supported or applicable on this architecture or kernel' \
             -e 'dev: -D option not supported or applicable on this architecture or kernel' \
             -e 'dev: -p option not supported or applicable on this architecture or kernel' \
             2>&1 | tee -a "${OUTPUTFILE}"
    local errorFound=${PIPESTATUS[2]}
    Log "- ERROR MESSAGES END"

    if [ "${errorFound}" -eq 0 ]; then
        Error "crash commands have some errors."
        result=1
    fi

    return $result
}

CrashCommand()
{
    local args=$1; shift
    local aux=$1; shift
    local core=$1; shift
    # allow passing cmd file other than default crash.cmd or crash-simple.cmd
    local cmd_file=$1; shift

    local result=0
    # if cmd_file is specified, only run CheckOutput check
    if [ -z "$cmd_file" ]; then
        CrashCommand_CheckReturnCode "${args}" "${aux}" "${core}" "${cmd_file}"
        [ $? -ne 0 ] && result=1
    fi

    CrashCommand_CheckOutput "${args}" "${aux}" "${core}" "${cmd_file}"
    [ $? -ne 0 ] && result=1

    if [ "$result" -ne 0 ] && [ -n "$core" ] && [ "$K_DEBUG" = "true" ]; then
        Log "- Uploading vmcore to NFS server for debugging"
        SaveVmcoreForDebug "$core" || Log "- Failed to save vmcore to nfs server."
    fi
}

Multihost()
{
    func=$1
    local stage=$2

    warn=0
    error=0

    CheckEnv

    # Check test type.
    if [ -z "${SERVERS}" ] && [ -z "${CLIENTS}" ]; then
        # single host test
        ${func}

    elif echo "${CLIENTS}" | grep -qi "${HOSTNAME}"; then
        TEST="${TEST}/client"

        ${func}

        Log "- client finishes."

    elif echo "${SERVERS}" | grep -qi "${HOSTNAME}"; then
        TEST="${TEST}/server"

        # Do nothing.

        Log "- server finishes."

    else
        Error "Neither server nor client"
    fi

    Report $stage
}

CheckVmlinux()
{
    vmlinux="/usr/lib/debug/lib/modules/$(uname -r)/vmlinux"
    [ ! -f "${vmlinux}" ] && MajorError "vmlinux not found."
}

# testing case which forbidden by selinux can offer a selinux's module
# and this function will try to compile the module and load it into system

ByPassSelinux()
{
    local te_file=$1
    local mod_file=${te_file%.*}.mod
    local pp_file=${te_file%.*}.pp

    [[ ! -e $te_file ]] && { echo $te_file doesn\'t exist...;return 1; }

    checkmodule -M -m -o $mod_file $te_file || { echo checkmodule failed;return 1;}
    semodule_package -o $pp_file -m $mod_file || { echo semodule_package failed;return 1; }
    semodule -i $pp_file || { echo semodule failed;return 1; }

    return 0
}


RestartNetwork()
{
    # NetworkManager is buggy, use network service.
    service NetworkManager status &&
        service NetworkManager stop &&
        chkconfig NetworkManager off

    # bz#903087
    export SYSTEMCTL_SKIP_REDIRECT=1

    chkconfig network on &&
        service network restart
}


# Check if secure boot is being enforced.
#
# Per Peter Jones, we need check efivar SecureBoot-$(the UUID) and
# SetupMode-$(the UUID), they are both 5 bytes binary data. The first four
# bytes are the attributes associated with the variable and can safely be
# ignored, the last bytes are one-byte true-or-false variables. If SecureBoot
# is 1 and SetupMode is 0, then secure boot is being enforced.
#
# SecureBoot-UUID won't always be set when securelevel is 1. For legacy-mode
# and uefi-without-seucre-enabled system, we can manually enable secure mode
# by writing "1" to securelevel. So check both efi var and secure mode is a
# more sane way.
#
# Assume efivars is mounted at /sys/firmware/efi/efivars.
isSecureBootEnforced()
{
    local secure_boot_file setup_mode_file
    local secure_boot_byte setup_mode_byte

    secure_boot_file=$(find /sys/firmware/efi/efivars -name SecureBoot-* 2>/dev/null)
    setup_mode_file=$(find /sys/firmware/efi/efivars -name SetupMode-* 2>/dev/null)

    if [ -f "$secure_boot_file" ] && [ -f "$setup_mode_file" ]; then
        secure_boot_byte=$(hexdump -v -e '/1 "%d\ "' $secure_boot_file|cut -d' ' -f 5)
        setup_mode_byte=$(hexdump -v -e '/1 "%d\ "' $setup_mode_file|cut -d' ' -f 5)

        if [ "$secure_boot_byte" = "1" ] && [ "$setup_mode_byte" = "0" ]; then
            return 0
        fi
    fi

    return 1
}


# @usage: CheckUnexpectedReboot
# @description: Check whether system was rebooted unexpected. This is used for
# test cases that not testing system panic. e.g. system configuration or runing
# a crash analysis against a vmcore or live system.
# Test case which calls CheckUnexpectedReboot will be terminiated as FAIL if
# unexpected reboot is detected.
CheckUnexpectedReboot()
{
    if [ -f "$K_REBOOT" ]; then
        rm -f "$K_REBOOT"
        MajorError "- Unexpected reboot is detected. Please check if system has \
been rebooted from panic or other possible incidents."
    fi
    touch "$K_REBOOT"
    sync;sync;
}



#  Common Log Functions/Variables.

declare -i error warn skip

function Log() {
    local msg="$1"
    echo -e "$msg" | tee -a "${OUTPUTFILE}"
}

function LogRun() {
    local comm="$1"
    local ret

    echo -e "# ${comm}" | tee -a "${OUTPUTFILE}"
    eval ${comm} | tee -a "${OUTPUTFILE}"
    ret=${PIPESTATUS[0]}
    echo | tee -a "${OUTPUTFILE}"
    return ${ret}
}

function Skip() {
    local msg="$1"
    echo "- warn: $msg" | tee -a "${OUTPUTFILE}"
    skip=$((skip + 1))
}

function Warn() {
    local msg="$1"
    echo "- warn: $msg" | tee -a "${OUTPUTFILE}"
    warn=$((warn + 1))
}

# error occurs - but won't abort recipe set
function Error() {
    local msg="$1"
    echo "- error: $msg" | tee -a "${OUTPUTFILE}"
    error=$((error + 1))
}

# major error occurs - stop current test task and proceed to next test task.
# do not abort recipe set
function MajorError() {
    local msg="$1"
    echo "- major error: $msg" | tee -a "${OUTPUTFILE}"
    error=$((error + 1))

    Report
}


# fatal error occurs - must abort recipe set
function FatalError() {
    local msg="$1"

    [ -n "$msg" ] &&
    echo "- fatal error: $msg" | tee -a "${OUTPUTFILE}"
    echo "- fatal error: aborting the recipe set." | tee -a "${OUTPUTFILE}"

    error=$((error + 1))
    report_result "${TEST}" "FAIL" "${error}"
    rhts-abort -t recipeset
}

function Report() {
    local stage="$1"
    local code

    if (( skip != 0 )); then
        result="SKIP"
        code=0
    elif (( error != 0 )); then
        result="FAIL"
        code=${error}
    elif (( warn != 0 )); then
        result="WARN"
        code=${warn}
    else
        result="PASS"
        code=0
    fi

    #reset codes to avoid propogating them
    error=0
    warn=0
    skip=0

    if [ -n "${stage}" ]; then
        report_result "${TEST}/${stage}" "${result}" "${code}"
    else
        report_result "${TEST}" "${result}" "${code}"
        exit 0
    fi
}

function RhtsSubmit() {
    local size
    size=$(wc -c < "$1")
    # zip and upload the zipped file if the size of which is larger than 100M
    if [ "$size" -ge 100000000 ]; then
        Log "- Size of File $1 is larger than 100M. Uploading the zipped file."
        zip "${1}.zip" "${1}"
        rhts-submit-log -l "${1}.zip"
    else
        rhts-submit-log -l "${1}"
    fi
}
