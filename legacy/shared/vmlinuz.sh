#!/usr/bin/env sh

# -----------------------------------------------------------------------------
# --- Kernel CKI -- Kernel Tier 1 Tests ---------------------------------------
# -----------------------------------------------------------------------------
#
# Cestmir Kalina, Red Hat, 2019, ckalina@redhat.com
#
# Distributed under BSD 3-Clause.
#
# -----------------------------------------------------------------------------
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

MAP_SIGNATURE_UTIL=(
        1F8B08              "gunzip"
        FD377A585A00        "unxz"
        425A68              "bunzip2"
        5D000000            "unlzma"
        894C5A              "lzop -d"
        02214C18            "lz4 -d"
        28B52FFD            "unzstd"
)

function vmlinuz_find_signature()
{
        local file="$1"
        local signature="$2"

        local offset=$(
                hexdump -v -e '/1 "%02X"' "$file" \
                | grep -m 1 -b -o "$signature" \
                | head -n 1 \
                | awk -F':' '{print $1/2;}'
        )

        if test $? -gt 0
        then
                return 1
        fi

        case $offset in
        ''|*[!0-9]*|[[:space:]]*)
                return 1
                ;;
        *)
                ;;
        esac

        echo $offset
        return 0
}

function vmlinuz_extract_deps()
{
        local fn="vmlinuz_extract_deps"
        if test -z $(which echo 2> /dev/null) -o \
                -z $(which mktemp 2> /dev/null) -o \
                -z $(which gawk 2> /dev/null) -o \
                -z $(which test 2> /dev/null) -o \
                -z $(which dd 2> /dev/null) -o \
                -z $(which zcat 2> /dev/null)
        then
                echo "[$fn] ERROR: Dependecies were not met."
                return 1
        fi
        return 0
}

function vmlinuz_extract()
{
        local fn="vmlinuz_extract"

        local vmlinuz="$1"
        local extracted=0

        vmlinuz_extract_deps || return 1

        if test   -z  "$vmlinuz" -o \
                ! -f "$vmlinuz" -o \
                ! -s "$vmlinuz" -o \
                ! -r "$vmlinuz"
        then
                echo "[$fn] ERROR: Unable to process file: $vmlinuz" >&2
                return 1
        fi

        local tmpfile="$(mktemp vmlinux-XXXXX --tmpdir=/tmp)"
        if test $? -gt 0 -o \
                  -z "$tmpfile" -o \
                ! -f "$tmpfile" -o \
                ! -w "$tmpfile"
        then
                echo "[$fn] ERROR: Unable to create a temporary file."
                return 1
        fi

        local signature_idx=0
        while test $signature_idx -lt ${#MAP_SIGNATURE_UTIL[@]}
        do
                echo -n > "$tmpfile"

                local signature="${MAP_SIGNATURE_UTIL[$signature_idx]}"
                local callback="${MAP_SIGNATURE_UTIL[$[$signature_idx+1]]}"
                signature_idx=$[$signature_idx+2]

                local offset=$(vmlinuz_find_signature "$vmlinuz" "$signature")
                if test $? -gt 0
                then
                        continue
                fi

                dd if="$vmlinuz" skip=$offset bs=1 \
                | $callback > "$tmpfile" 2>/dev/null

                if readelf -h $tmpfile &> /dev/null
                then
                        extracted=1
                        break
                fi
        done

        if test $extracted -eq 0
        then
                echo "[$fn] ERROR: Unable to parse vmlinuz."
                return 1
        fi

        echo "$tmpfile"
        return 0
}
