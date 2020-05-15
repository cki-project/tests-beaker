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
. ../../cki_lib/libcki.sh || exit 1
. ../include/runtest.sh

TEST="/kdump/kexec-boot"

KEXEC_VER=${KEXEC_VER:-"$(uname -r)"}
EXTRA_KEXEC_OPTIONS=${EXTRA_KEXEC_OPTIONS:-""}

KexecBoot()
{
    local test_boot_option=newkerneloption

    if [ ! -f "${C_REBOOT}_1" ] && [ ! -f "${C_REBOOT}_2" ]; then

        # Kexec load is only supported on aarch64 supporting PSCI
        if [ "$K_ARCH" = "aarch64" ]; then
            local supported=1
            if which journalctl ; then
                journalctl -k | grep -i psci | grep -i "is not implemented" && supported=0
            else
                grep -i  psci /var/log/messages | grep -i "is not implemented" && supported=0
            fi
            if [ "$supported" -eq 0 ]; then
                Warn "- This aarch64 system doesn't support PSCI. Terminate the test."
                return
            fi
        fi 

        # Make sure kdump service is done running 'kexec -p' load
        # So kexec -l won't compete resources with kexec -p
        # Otherwise it may fail: kexec_load failed: Device or resource busy
        if which kdumpctl &> /dev/null; then
            kdumpctl status &> /dev/null
        else
            service kdump status &> /dev/null
        fi

        # Prepare kexec cmd and run kexec load
        touch "${C_REBOOT}_1"
        cmd="kexec ${EXTRA_KEXEC_OPTIONS} \
            -l /boot/vmlinuz-${KEXEC_VER} \
            --initrd=/boot/initramfs-${KEXEC_VER}.img \
            --command-line=\"$(cat /proc/cmdline) ${test_boot_option}\""

        Log "- Running cmd: ${cmd}"
        eval ${cmd} || {
            rm -f "${C_REBOOT}_1"
            Error "kexec cmd returned a non-zero value."
            return
        }

        Log "- Loaded new kernel $KEXEC_VER."
        Log "- Switch to new kernel"
        # A system reboot after kexec -l call will kexec-switch to the loaded kernel.
        # Note, do not use rstrnt-reboot here as it will set next boot option affecting
        # next normal reboot instead this kexec reboot.
        reboot

    elif [ -f "${C_REBOOT}_1" ]; then
        rm -f "${C_REBOOT}_1"
        Log "- Current kernel and options are: "
        Log "$(uname -r)"
        Log "$(cat /proc/cmdline)"

        if cat /proc/cmdline | grep -q "${test_boot_option}"; then
            Log "- Kexec boot to new kernel $KEXEC_VER successfully."
            Log "- Reboot to normal kernel"
            touch "${C_REBOOT}_2"
            SafeReboot
        else
            Error "Kexec boot failed. Expect to see ${test_boot_option} in kernel boot options"
            return
        fi 

    elif [ -f "${C_REBOOT}_2" ]; then
        rm -f "${C_REBOOT}_2"
        Log "- Current kernel and options are: "
        Log "$(uname -r)"
        Log "$(cat /proc/cmdline)"  
        Log "- Reboot back to normal kernel successfully."
    fi
}

RunTest KexecBoot
