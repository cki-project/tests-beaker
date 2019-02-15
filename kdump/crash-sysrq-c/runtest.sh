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

function Crash() {
    DisableAVCCheck

    if [ ! -f "${K_REBOOT}" ]; then
        PrepareReboot

        local sysrq_value
        sysrq_value=$(cat /proc/sys/kernel/sysrq)
        [ "$sysrq_value" -eq 0 ] && Warn "kernel.sysrq is set to 0 which is unexpected."

        # Crash the system.
        touch "${K_REBOOT}"
        Report 'boot-2nd-kernel'
        sync

        # Check kdump status before triggering panic
        CheckKdumpStatus

        # Trigger panic
        echo c >/proc/sysrq-trigger
        # Should stop here.
    else
        rm -f "${K_REBOOT}"
    fi
}

# --- start ---
Multihost "Crash"
