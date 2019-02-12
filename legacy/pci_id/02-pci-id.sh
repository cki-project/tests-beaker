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

NEW_KERNEL_KO=()
OLD_KERNEL_KO=()

function dump_alias()
{
        local kernel_dir="$1"
        local alias_dir="$2"
        local alias_all="$3"

        if ! test -e "$alias_all" -a -d "$alias_dir" -a -d "$kernel_dir"
        then
                echo "ERROR: invalid arguments passed to dump_alias()."
                exit 1
        fi

        echo "  * Dumping kernel module aliases"
        echo "    Per-KO Files: $2"
        echo "    Summary File: $3"

        find $kernel_dir -name "*.ko" -or -name "*.ko.*" -type f \
        | xargs -I KO bash -c '
                rel_path=$(realpath --relative-to="'$kernel_dir'" "KO");
                alias_out=${rel_path%.ko[^\/]*}.alias

                source "'$SCRIPT_DIR'/../shared/file-utils.sh";

                echo "  * Dumping aliases for KO ...";

                basename_ko=$(basename "KO")
                basename_ko=${basename_ko/X/}
                tmpfile="$(mktemp XXXXXX-$basename_ko.ko)"
                file_contents "KO" > "$tmpfile"

                mkdir -p "$(dirname "'$alias_dir'/${rel_path}")";

                modinfo -F alias "$tmpfile" >> "'$alias_dir'/$alias_out";
                modinfo -F alias "$tmpfile" >> "'$alias_all'";

                rm $tmpfile;'
}

function main()
{
        echo
        echo " :: PCI ID Removal Test"
        echo

        # -- Download and extract the baseline kernel RPMS
        rpm_extract_add "kernel-modules"
        rpm_extract_add "kernel-modules-extra"
        rpm_extract

        local new_kernel_dir="$(find /lib/ -type d -name "$(uname -r)")"
        local old_kernel_dir="$RPM_TMPDIR"

        old_alias_all=$(mktemp old-alias-all-XXXXXX --tmpdir=/tmp)
        TMP_FILES+=("$old_alias_all")
        old_alias_dir=$(mktemp -d old-alias-XXXXXX --tmpdir=/tmp)
        TMP_FILES+=("$old_alias_dir")

        new_alias_all=$(mktemp new-alias-all-XXXXXX --tmpdir=/tmp)
        TMP_FILES+=("$new_alias_all")
        new_alias_dir=$(mktemp -d new-alias-XXXXXX --tmpdir=/tmp)
        TMP_FILES+=("$new_alias_dir")

        echo " :: Dumping aliased for new (patched kernel) ..."
        dump_alias "$new_kernel_dir" "$new_alias_dir" "$new_alias_all"

        sort "$new_alias_all" | uniq >> "$new_alias_all.tmp"
        mv "$new_alias_all.tmp" "$new_alias_all"

        echo " :: Dumping aliased for baseline kernel ..."
        dump_alias "$old_kernel_dir" "$old_alias_dir" "$old_alias_all"

        sort "$old_alias_all" | uniq >> "$old_alias_all.tmp"
        mv "$old_alias_all.tmp" "$old_alias_all"

        echo " :: Comparing aliases."

        if test -n "$(comm -13 "$new_alias_all" "$old_alias_all")"
        then
                echo "---------------------------------------------------------"
                echo "--- Missing PCI IDs -------------------------------------"
                echo "---------------------------------------------------------"
                echo
                echo "The following PCI IDs are missing from this patch."
                echo "Syntax: KO_FILE PCI_ID"
                comm -13 "$new_alias_all" "$old_alias_all" \
                | sed 's/*/\\\\*/g' \
                | xargs -I ALIAS_LINE grep -r 'ALIAS_LINE$' "$old_alias_dir" \
                | xargs -I MATCH_LINE bash -c '
                        line="MATCH_LINE";
                        file=${line%%:*};
                        file=$(realpath --relative-to='$old_alias_dir' $file);
                        line=${line#*:};
                        file=${file/.alias/.ko};
                        echo $file $line;'
                test_fail "Missing PCI ID detected!"
        else
                test_pass "All PCI IDs present on baseline were found."
        fi
}
