#!/usr/bin/env bash

#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of the <organization> nor the
#    names of its contributors may be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(realpath "$(dirname "$BASH_SOURCE")")"

source "$SCRIPT_DIR/../shared/file-utils.sh"
source "$SCRIPT_DIR/../shared/vmlinuz.sh"
source "$SCRIPT_DIR/../shared/ksymbols.sh"

# -- Try and find as many of the symbol definitions in the *PATCHED* kernel ---
# Currently, for the patched (new) kernel these include:
#  - kernel modules in /lib/{,modules/}.*$(uname -r).* compressed or otherwise
#  - System.map.*$(uname -r) files in /boot
#  - Module.symvers file in /usr/src/.*$(uname -r).*
#  - archived symvers-.*$(uname -r).* in /boot
#  - VMLinu{x,z} files in /boot
# Duplicit sources are here on purpose as it is not guaranteed that all will
# be present on the system.

NEW_KERNEL_KMOD_FOLDERS=()
NEW_KERNEL_SYSTEM_MAP=()
NEW_KERNEL_MODULE_SYMVERS=()
NEW_KERNEL_VMLINUX=()
NEW_KERNEL_VMLINUZ=()
NEW_KERNEL_KABI_WHITELITS=()

OLD_KERNEL_SYMVERS=()
OLD_KERNEL_WHITELIST=()

function new_find_symbol_sources()
{
        NEW_KERNEL_KMOD_FOLDERS+=($(
                find /usr/lib /lib/ -type d -name "$(uname -r)" \
                | sort \
                | uniq
        ))

        NEW_KERNEL_SYSTEM_MAP+=($(
                find /boot -type f -iname "system.map*$(uname -r)*"
        ))

        NEW_KERNEL_MODULE_SYMVERS+=($(
                find /usr/src -type f -name "Module.symvers" \
                              -path "*$(uname -r)*"
        ))

        NEW_KERNEL_MODULE_SYMVERS+=($(
                find /boot -type f -iname "symvers-*$(uname -r)*"
        ))

        NEW_KERNEL_VMLINUX+=($(
                find /boot/ -type f -iname "vmlinux*$(uname -r)*"
        ))

        NEW_KERNEL_VMLINUZ+=($(
                find /boot/ -type f -iname "vmlinuz*$(uname -r)*"
        ))

        # Obtain current whitelists
        #

        # Attempt to locate current whitelists in /lib/modules
        # **WARNING:** It is paramount that this test's Requires does not
        #              state kernel-abi-whitelists. RPM absolutely needs to
        #              be installed from the source provided by the CKI team.
        NEW_KERNEL_KABI_WHITELITS=($(
                find -L /lib/modules/kabi-current -type f
        ))

        if test ${#NEW_KERNEL_KMOD_FOLDERS[@]} -gt 0
        then
                echo -e "  * Kernel module folders: " \
                        "${NEW_KERNEL_KMOD_FOLDERS[@]/#/\\n    - }"
        else
                echo -e "  * No kernel module folders found."
        fi

        if test ${#NEW_KERNEL_SYSTEM_MAP[@]} -gt 0
        then
                echo -e "  * System.map files: " \
                        "${NEW_KERNEL_SYSTEM_MAP[@]/#/\\n    - }"
        else
                echo -e "  * No System.map files found."
        fi

        if test ${#NEW_KERNEL_MODULE_SYMVERS[@]} -gt 0
        then
                echo -e "  * Module.symvers files: " \
                        "${NEW_KERNEL_MODULE_SYMVERS[@]/#/\\n    - }"
        else
                echo -e "  * No Module.symvers files found."
        fi

        if test ${#NEW_KERNEL_VMLINUX[@]} -gt 0
        then
                echo -e "  * vmlinux files: " \
                        "${NEW_KERNEL_VMLINUX[@]/#/\\n    - }"
        else
                echo -e "  * No vmlinux files found."
        fi

        if test ${#NEW_KERNEL_VMLINUZ[@]} -gt 0
        then
                echo -e "  * vmlinuz files: " \
                        "${NEW_KERNEL_VMLINUZ[@]/#/\\n    - }"
        else
                echo -e "  * No vmlinuz files found."
        fi

        if test ${#NEW_KERNEL_KABI_WHITELITS[@]} -gt 0
        then
                echo -e "  * kABI whitelist files: " \
                        "${NEW_KERNEL_KABI_WHITELITS[@]/#/\\n    - }"
        else
                echo -e "    No kABI whitelist files found."
        fi

        return 0
}

# Download and extract kernel-devel (for Module.symvers) and
# kernel-abi-whitelists (for kABI whitelists).

function old_find_symbol_sources()
{
        # -- Download and extract the baseline kernel RPMS
        rpm_extract_add "kernel-devel"
        rpm_extract_add "kernel-abi-whitelists"
        rpm_extract

        OLD_KERNEL_SYMVERS+=($(
                find $RPM_TMPDIR \
                        -type f \
                        -name "Module.symvers" \
                        -print \
                        -quit
        ))

        OLD_KERNEL_WHITELIST+=($(
                find -L $RPM_TMPDIR \
                        -type f \
                        -path "*kabi-current*"
        ))

        if test ${#OLD_KERNEL_SYMVERS[@]} -gt 0
        then
                echo -e "  * Module.symvers files: " \
                        "${OLD_KERNEL_SYMVERS[@]/#/\\n    - }"
        else
                echo -e "  * No Module.symvers files found."
        fi

        if test ${#OLD_KERNEL_WHITELIST[@]} -gt 0
        then
                echo -e "  * kABI whitelist files: " \
                        "${OLD_KERNEL_WHITELIST[@]/#/\\n    - }"
        else
                echo -e "    No kABI whitelist files found."
        fi
}

function new_symbols()
{
        local IFS=$'\n'
        local new_list="$1"
        local new_whitelist="$2"

        {
                for system_map in ${NEW_KERNEL_SYSTEM_MAP[@]}
                do
                        symbols_system_map "$system_map"
                done

                for module_symvers in ${NEW_KERNEL_MODULE_SYMVERS[@]}
                do
                        symbols_module_symvers "$module_symvers"
                done

                for kmod_folder in ${NEW_KERNEL_KMOD_FOLDERS[@]}
                do
                        symbols_kmod "$kmod_folder"
                done

                for vmlinux in ${NEW_KERNEL_VMLINUX[@]}
                do
                        symbols_vmlinux "$vmlinux"
                done

                for vmlinuz in ${NEW_KERNEL_VMLINUZ[@]}
                do
                        vmlinuz_extracted="$(vmlinuz_extract "$vmlinuz")"
                        TMP_FILES+=("$vmlinuz_extracted")
                        if test $? -gt 0
                        then
                                continue
                        fi
                        symbols_vmlinux "$vmlinuz_extracted" 2> /dev/null
                done
        } >> "$new_list"

        for whitelist in ${NEW_KERNEL_KABI_WHITELITS[@]}
        do
                symbols_whitelist "$whitelist" >> "$new_whitelist"
        done

        sort "$new_list" | uniq >> "$new_list.tmp"
        mv "$new_list.tmp" "$new_list"

        sort "$new_whitelist" | uniq >> "$new_whitelist.tmp"
        mv "$new_whitelist.tmp" "$new_whitelist"
}

function old_symbols()
{
        local IFS=$'\n'
        local old_list="$1"
        local old_whitelist="$2"

        for module_symvers in ${OLD_KERNEL_SYMVERS[@]}
        do
                symbols_module_symvers "$module_symvers" >> "$old_list"
        done

        for whitelist in ${OLD_KERNEL_WHITELIST[@]}
        do
                symbols_whitelist "$whitelist" >> "$old_whitelist"
        done

        sort "$old_list" | uniq >> "$old_list.tmp"
        mv "$old_list.tmp" "$old_list"

        sort "$old_whitelist" | uniq >> "$old_whitelist.tmp"
        mv "$old_whitelist.tmp" "$old_whitelist"
}

function main()
{
        echo
        echo " :: kABI Whitelists Tests"
        echo

        echo " :: Looking for symbol sources for the patched kernel ..."
        new_find_symbol_sources

        echo " :: Looking for baseline symbol sources ..."
        old_find_symbol_sources

        new_symbol_list=$(mktemp ksym-new-XXXXXX --tmpdir=/tmp)
        TMP_FILES+=("$new_symbol_list")

        old_symbol_list=$(mktemp ksym-old-XXXXXX --tmpdir=/tmp)
        TMP_FILES+=("$old_symbol_list")

        new_whitelist=$(mktemp whitelist-new-XXXXXX --tmpdir=/tmp)
        TMP_FILES+=("$new_whitelist")

        old_whitelist=$(mktemp whitelist-old-XXXXXX --tmpdir=/tmp)
        TMP_FILES+=("$old_whitelist")

        echo " :: Reading available symbols ..."
        new_symbols "$new_symbol_list" "$new_whitelist"
        old_symbols "$old_symbol_list" "$old_whitelist"

        echo " :: Baseline whitelist symbols ..."
        cat "$old_whitelist"

        echo " :: New whitelist symbols ..."
        cat "$new_whitelist"

        echo " :: Comparing baseline kABI whitelist w/ new kABI whitelist"
        if test -n "$(comm -13 "$new_whitelist" "$old_whitelist")"
        then
                test_fail "New kABI whitelist is missing symbols with respect" \
                          "to baseline."
                comm -13 "$new_whitelist" "$old_whitelist"
        else
                test_pass "kABI whitelist registered no removal."
        fi

        echo " :: Comparing new kABI whitelist to found modules."

        if test -n "$(comm -13 \
                <(comm -23 "$new_whitelist" "$new_symbol_list" | sort | uniq) \
                <(comm -23 "$old_whitelist" "$old_symbol_list" | sort | uniq))"
        then
                test_fail "The following symbols are present on kABI " \
                          "whitelist, however, they weren't found on" \
                          "the system. They are present on the baseline though."

                comm -13 \
                     <(comm -23 "$new_whitelist" "$new_symbol_list"
                       | sort  \
                       | uniq) \
                     <(comm -23 "$old_whitelist" "$old_symbol_list" \
                       | sort  \
                       | uniq)
        else
                test_pass "kABI whitelisted symbols have all been exported"
        fi
}
