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

# symbols_whitelist [FILE] ----------------------------------------------------

function symbols_whitelist_usage()
{
        echo
        echo "symbols_whitelist [FILE]"
        echo
        echo "Dump a list of symbols in a whitelist file."
        echo "Path to whitelist file is provided as first argument, if given."
        echo "If the first argument is zero length or not given, stdin will"
        echo "be used instead."
        echo
        echo "This function has no sife-effects."
}

function symbols_whitelist()
{
        file_contents "$1" \
        | grep -h '^[[:space:]]' \
        | tr -d '\t'
        return $?
}

# symbols_system_map [FILE] ---------------------------------------------------

function symbols_system_map_usage()
{
        echo
        echo "symbols_system_map [FILE]"
        echo
        echo "Dump a list of exported symbols according to System.map."
        echo "Path to System.map is provided as first argument, if given."
        echo "If the first argument is zero length or not given, stdin will"
        echo "be used instead."
        echo
        echo "This function has no sife-effects."
}

function symbols_system_map()
{
        file_contents "$1" \
        | grep -Po '(?<=( __kcrctab_)).*(?=$)'
        return $?
}

# symbols_module_symvers [FILE]
#
# Dump a list of exported symbols according to Module.symvers.
# Path to System.map is provided as first argument, if given.
# If the first argument is zero length or not given, stdin will
# be used instead.
#
# This function has no sife-effects.
#
function symbols_module_symvers()
{
        file_contents "$1" \
        | awk '{print $2;}'
        return $?
}

# symbols_vmlinux [FILE]
#
# Dump a list of exported symbols from vmlinux.
# First argument can be:
#   - empty/undefined: use stdin as source
#   - points to a (possibly compressed) file: extract if needed and use that
#     file
#
# This function has no sife-effects.
#
function symbols_vmlinux() {
        if test -z "$1" -o -r "$1"
        then
                symbols_kmod "${1=-}"
                return $?
        else
                echo "symbols_vmlinux: Unsupported argument given." >&2
                return 1
        fi
}

# symbols_kmod [FILE|DIRECTORY]
#
# Dump a list of exported symbols from kernel modules.
# First argument can be:
#   - empty/undefined: use stdin as source
#   - points to a (possibly compressed) file: extract if needed and use that
#     file
#   - points to a directory: attempt to locate kernel modules recursively
#
# This function has no sife-effects.
#
function symbols_kmod()
{
        local ret=0
        local path="$1"

        # Input: a directory
        if test -d "$path"
        then
                local IFS=$'\n'
                for ko in $(
                        find "$path" -type f -name "*.ko" -or -name "*.ko.*"
                )
                do
                        symbols_kmod "$ko"
                        if test $? -gt 0
                        then
                                ret=$?
                        fi
                done
                return $ret
        fi

        if ! test -z "$path" -o -r "$path"
        then
                echo "symbols_kmod: Unsupported argument given." >&2
                return 1
        fi

        # Input: stdin or readable file
        local filetype=""
        local tmpfile=""
        local extract_attempts=10

        while test $extract_attempts -gt 0
        do
                # Determine the type of the file we're processing
                filetype=$(
                        cat "$path" \
                        | file "${path=-}" \
                        | awk -F'[[:space:]]*[:,-][[:space:]]' '{print $2;}'
                )

                # We've got an ELF file, exit the loop.
                # This check is here only to avoid calling file_contents
                # when we don't need to. Note that when passing data
                # via stdin, we still require file_contents pass as
                # it will dump the data into the file.
                if test "${filetype%% *}" = "ELF" -a ! -z "$path"
                then
                        break
                fi

                # We haven't created a tmp file yet, create one
                if test -z "$tmpfile"
                then
                        tmpfile="$(mktemp)"
                fi

                # Attempt to extract
                file_contents "${path=-}" "$tmpfile"

                # Couldn't extract further
                if test $? -eq $FILE_CONTENTS_RESULT_IDEMPOTENT
                then
                        break
                fi

                path="$tmpfile"

                let extract_attempts--
        done

        nm --defined-only "$path" \
        | awk '$3 ~ /__crc_.*/ { gsub("^__crc_", "", $3); print $3; }'
        ret=$?

        rm -f "$tmpfile"

        return $ret
}
