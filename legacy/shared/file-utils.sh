#!/usr/bin/env sh

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
#
# File helpers
#
# It is intended for this script to expose the following globals and functions:
#
# Functions:
#
# file_contents [FILE] [OUTPUT_FILE]
#
# -----------------------------------------------------------------------------

#
# file_contents [FILE] [OUTPUT_FILE]
#
# Extracts contents of FILE to stdout or to OUTPUT_FILE.
#
# Arguments:
#   FILE                File to extract. If '-' is given, use stdin.
#   OUTPUT_FILE         File to extract contents to. If none given, use stdout.
#

FILE_CONTENTS_ERROR=-1
FILE_CONTENTS_RESULT_EXTRACTED=0
FILE_CONTENTS_RESULT_IDEMPOTENT=1

function file_contents()
{
        local fn="file_extract"

        local input=""
        local output="$2"

        local ret="$FILE_CONTENTS_RESULT_EXTRACTED"

        # If we use stdin as input, dump it to a temporary file, since two
        # reads are required; it can be further optimized (cf. vmlinuz.sh).
        case "$1" in
        '-'|'')
                input="$(mktemp)"
                cat > "$input"
                ;;
        *)
                input="$1"
                ;;
        esac

        if test ! -r "$input"
        then
                echo "[$fn] ERROR: Expected source file to exist and be" \
                     "readable." >&2
                return $FILE_CONTENTS_ERROR
        fi

        if test -n "$output" -a ! -e "$output"
        then
                touch "$output"
        fi

        if test -n "$output" -a ! -w "$output"
        then
                echo "[$fn] ERROR: Output file does not exist or cannot be" \
                     "written to." >&2
                return $FILE_CONTENTS_ERROR
        fi

        local cmd=()
        local type=$(
                file "$input" \
                | awk -F'[[:space:]]*[:,-][[:space:]]' '{print $2;}'
        )

        case $type in
        "gzip compressed data")
                cmd+=(zcat)
                ;;
        "XZ compressed data")
                cmd+=(xzcat)
                ;;
        "bzip2 compressed data")
                cmd+=(bzcat)
                ;;
        "LZMA compressed data")
                cmd+=(lzcat)
                ;;
        "lzop compressed data")
                cmd+=(lzop -d -c)
                ;;
        "LZ4 compressed data (v1.4+)")
                cmd+=(lz4 -d)
                ;;
        "Zstandard compressed data (v0.8+)")
                cmd+=(unzstd)
                ;;
        "POSIX tar archive (GNU)")
                cmd+=(tar -Oxf)
                ;;
        # It is not a known archive, so just pass it through.
        # There are cases where we know this is the end result, e.g.,
        # text file or ELF.
        *)
                cmd+=(cat)
                ret="$FILE_CONTENTS_RESULT_IDEMPOTENT"
                ;;
        esac

        # Decompress to stdout if no output file has been given
        if test -z "$output"
        then
                "${cmd[@]}" "$input"
                return 0
        fi

        # Decompress to file
        "${cmd[@]}" "$input" > "$output"

        # We were reading from stdin, so remove temporary file used.
        if test -z "$1" -o "$1" = "-"
        then
                rm -f "$input"
        fi

        return $ret
}
