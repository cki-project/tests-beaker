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


# Source kdump common functions
. ../include/runtest.sh


# @usage: DefKdumpMem
# @description:
#     It returns crash memory range (crashkernel=XXXM) based on
#     system release and arch. This is usually used when crashkernel=auto is
#     is not supported (e.g. Fedora) or when system memory is lower than the
#     memory threshold required by crashkernel=auto function.
# @return:
#     Crash kernel memory range. e.g. crashkernel=XXXM
DefKdumpMem()
{
    local args=""

    if $IS_RHEL6; then
        if   [[ "${K_ARCH}" == i?86     ]]; then args="crashkernel=128M"
        elif [[ "${K_ARCH}"  = "x86_64" ]]; then args="crashkernel=128M"
        elif [[ "${K_ARCH}"  = "ppc64"  ]]; then args="crashkernel=256M"
        elif [[ "${K_ARCH}"  = "s390x"  ]]; then args="crashkernel=128M"
        fi

    elif $IS_RHEL7; then
        if   [[ "${K_ARCH}"  = "x86_64" ]]; then args="crashkernel=160M"
        elif [[ "${K_ARCH}"  = "s390x"  ]]; then args="crashkernel=160M"
        elif [[ "${K_ARCH}"  = ppc64*  ]]; then
            args="crashkernel=0M-4G:384M,4G-16G:512M,16G-64G:1G,64G-128G:2G,128G-:4G"
        elif [[ "${K_ARCH}"  = "aarch64"  ]]; then args="crashkernel=512M"
        fi

    elif $IS_RHEL8; then
        if   [[ "${K_ARCH}"  = "x86_64" ]]; then args="crashkernel=160M"
        elif [[ "${K_ARCH}"  = "s390x"  ]]; then args="crashkernel=160M"
        elif [[ "${K_ARCH}"  = ppc64*  ]]; then
            args="crashkernel=0M-4G:384M,4G-16G:512M,16G-64G:1G,64G-128G:2G,128G-:4G"
        elif [[ "${K_ARCH}"  = "aarch64"  ]]; then args="crashkernel=512M"
        fi

    elif $IS_RHEL5; then
        if   [[ "${K_ARCH}" == i?86     ]]; then args="crashkernel=128M@16M"
        elif [[ "${K_ARCH}"  = "x86_64" ]]; then args="crashkernel=128M@16M"
        elif [[ "${K_ARCH}"  = "ppc64"  ]]; then args="crashkernel=256M@32M xmon=off"
        elif [[ "${K_ARCH}"  = "ia64"   ]]; then args="crashkernel=512M@256M";
            # the larger IA-64 box, the more kdump memory needed
            grep -qE '^ACPI:.*(rx8640|SGI)' /var/log/dmesg &&
            args="crashkernel=768M@256M"
        fi
    fi

    echo "$args"
}


SetupKdump()
{
    if [ ! -f "${K_REBOOT}" ]; then
        rpm -q lshw || yum install -y lshw

        local default=/boot/vmlinuz-`uname -r`
        [ ! -s "$default" ] && default=/boot/vmlinux-`uname -r`

        # Temporarily comment out this line. Because it seems
        # if it's executed before rebuilding kdump img,
        # it may break the grub file and system would hange
        # after rebooting.
        #/sbin/grubby --set-default="${default}"

        # In ia64 arch, the path of vmlinuz is /boot/efi/efi/redhat, it different with other arch.
        if [[ "${K_ARCH}"  = "ia64" ]]; then
            default=/boot/efi/efi/redhat/vmlinuz-`uname -r`
            /sbin/grubby --set-default="${default}"
        fi

        # For uncompressed kernel, i.e. vmlinux
        [[ ${default} == *vmlinux* ]] && {
            Log "- Modifying /etc/sysconfig/kdump properly for 'vmlinux'."
            sed -i 's/\(KDUMP_IMG\)=.*/\1="vmlinux"/' /etc/sysconfig/kdump
        }

        # For kernel-rt
        $IS_RT_KEN && [ -f /usr/bin/rt-setup-kdump ] && {
            Log "- Modifying /etc/sysconfig/kdump properly for RT."
            set -x; /usr/bin/rt-setup-kdump -g; set +x
        }

        # Ensure Kdump Kernel memory reservation
        grep -q 'crashkernel' <<< "${KER1ARGS}" || {
            local kdumpMem=$(DefKdumpMem)
            [ -z "${KER1ARGS}" ] || kdumpMem=" ${kdumpMem}"

            $IS_RHEL5 && KER1ARGS+="${kdumpMem}" || {
                # memory >= auto-threshold and kdump already default on
                [ `cat /sys/kernel/kexec_crash_size` -eq 0 ] && {
                    Log "`grep MemTotal /proc/meminfo`"
                    KER1ARGS+="${kdumpMem}"
                }
            }
        }
        [ "${KER1ARGS}" ] && {
            touch "${K_REBOOT}"

            # Kdump service will not be enabled if crashkernel=auto && system
            # memory is less the threshold required by kdump service.
            /bin/systemctl enable kdump.service || /sbin/chkconfig kdump on

            Log "- Changing boot loader."
            {
                /sbin/grubby                     \
                    --args="${KER1ARGS}"         \
                    --update-kernel="${default}" &&
                if [ "${K_ARCH}" = "s390x" ]; then zipl; fi
            } || FatalError "Error changing boot loader."

            Report 'pre-reboot'
            Log "- Rebooting\n"; sync; rhts-reboot
        }
    fi

    # show kexec-tools & crash version after pkginstall
    rpm -q kexec-tools
    rpm -q crash

    # show kernel version, boot cmdline and crash memory reserved.
    rpm -q kernel
    echo "total system memory: $(lshw -short | grep -i "System Memory" | awk '{print $3}')"
    cat /proc/cmdline
    kdumpctl showmem || cat /sys/kernel/kexec_crash_size
    grep "fadump=on" /proc/cmdline && dmesg | grep "firmware-assisted dump" | grep "Reserved"

    [ -f "${K_REBOOT}" ] && rm -f "${K_REBOOT}"

    [[ "${K_ARCH}" =~ i.86|x86_64 ]] && GetBiosInfo

    # Make sure kdumpctl is operational
    # If kdump service is not started yet, wait for max 5 mins.
    # It may take time to start kdump service.
    local kdump_status=off
    for i in {1..5}
    do
        kdumpctl status 2>&1 || service kdump status 2>&1
        [ $? -eq 0 ] && {
            kdump_status=on
            break
        }
        sleep 60
    done

    # Submit kdump rd img for later debugging if fails.
    ReportKdumprd
    # last try to make sure kdump is ready.
    sleep 10

    # submit service messages for debugging in case of failing
    if [ "$kdump_status" = "off" ]; then
        if which journalctl ; then
            journalctl -u kdump > "${K_TESTAREA}/kdump.messages.log"
            if grep -i "No entries" "${K_TESTAREA}/kdump.messages.log" ; then
                journalctl -b >> "${K_TESTAREA}/kdump.messages.log"
            fi
            sync
            rhts-submit-log -l "${K_TESTAREA}/kdump.messages.log"
            sync
        else
            rhts-submit-log -l /var/log/messages
            sync
        fi
        MajorError "Kdump is not operational!"
    fi
}

#--- Start ---

GetHWInfo
Multihost 'SetupKdump'
