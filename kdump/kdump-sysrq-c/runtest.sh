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

ANALYZE_VMCORE="${ANALYZE_VMCORE:-true}"

Crash()
{
    if [ ! -f "${C_REBOOT}" ]; then
        # Clear previous vmcores if any and restore kdump configurations
        Cleanup
        PrepareKdump

        # Test with
        #    default kdump config
        #    default kdump sysconfig but with KDUMP_FILE_LOAD = off
        ResetKdumpConfig
        # if KDUMP_FILE_LOAD presents, turn it off 
        # Otherwise kdump service would fail to start if the kernel 
        # is not signed with a ceritified key.
        if grep -i KDUMP_FILE_LOAD "${KDUMP_SYS_CONFIG}" ; then
            AppendSysconfig KDUMP_FILE_LOAD override "off"
        fi
        RestartKdump
        ReportSystemInfo
        TriggerSysrqPanic
        rm -f "${C_REBOOT}"
    else
        rm -f "${C_REBOOT}"
        GetCorePath || return

        if [ "${ANALYZE_VMCORE,,}" != "true" ]; then
          return
        fi

        # Analyse the vmcore by crash utilities
        PrepareCrash
        [ $? -eq 1 ] && return

        # Only check the return code of this session.
        cat <<EOF > "${K_TESTAREA}/crash-simple.cmd"
bt -a
ps
log
exit
EOF
        local vmcores
        CheckVmlinux

        Log "- Analyze the vmcore by crash utilities."
        if [ "${K_KVARI}" = 'rt' ]; then
            CrashCommand "--reloc=12m" "${vmlinux}" "${vmcore}"
        else
            CrashCommand "" "${vmlinux}" "${vmcore}"
        fi
    fi
}

RunTest Crash
