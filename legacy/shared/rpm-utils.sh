#!/usr/bin/env bash
#
# RPM helpers
#
# It is intended for this script to expose the following globals and functions:
#
# Globals:
#
# RPM_INSTALL   ARRAY[INT => STRING]    A list of packages to install.
# RPM_EXTRACT   ARRAY[INT => STRING]    A list of packages to download and
#                                       to extract.
#
# Functions:
#
# rpm_install_add
# rpm_extract_add
# rpm_install
# rpm_extract
# rpm_extract_path
#
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# PREP: Initialize globals provided they haven't been already -----------------
# -----------------------------------------------------------------------------

if test -z ${RPM_INSTALL+x}
then
        RPM_INSTALL=()
fi

if test -z ${RPM_EXTRACT+x}
then
        RPM_EXTRACT=()
fi

# -----------------------------------------------------------------------------
# PREP: Add RPM_INSTALL dependencies required by this scripts -----------------
# -----------------------------------------------------------------------------

if test -z $(command -v cpio)
then
        RPM_INSTALL+=(
                cpio    # required for rpm extract; namely: cpio
        )
fi

if test -z $(command -v rpm2cpio)
then
        RPM_INSTALL+=(
                rpm     # required for rpm extract; namely: rpm2cpio
        )
fi

# -----------------------------------------------------------------------------
# PREP: Determine whether we're using yum or dnf ------------------------------
# -----------------------------------------------------------------------------

PKG_MANAGER=dnf
if ! which dnf &> /dev/null
then
        PKG_MANAGER=yum
fi

# -----------------------------------------------------------------------------
# PREP: Create a temporary directory for RPM extract, and add to TMP_FILES ----
# -----------------------------------------------------------------------------

RPM_TMPDIR="$(mktemp -d rpm-XXXXX --tmpdir=/tmp)"
TMP_FILES+=("$RPM_TMPDIR")

# -----------------------------------------------------------------------------
# INTERNAL FUNCTIONS ----------------------------------------------------------
# -----------------------------------------------------------------------------

#
# __yum_call [YUM_ARGUMENTS...] [PACKAGES...]
#
# Calls [yum|dnf] [install|reinstall] [YUM_ARGUMENTS...] [PACKAGES...]
# where install|reinstall is chosen depending on whether the package is present
# in the system.
#
# Arguments:
#   YUM_ARGUMENTS         Arguments to yum/dnf, starting w/ `-'.
#   PACKAGES              Packages to pass to yum/dnf.
#
function __yum_call()
{
        if test $# -eq 0
        then
                # Nothing to do.
                return 0
        fi

        # Create a temporary file for dnf output logging
        local log="$(mktemp)"
        TMP_FILES+=("$log")

        # Filter out yum arguments
        YUM_ARGS=()
        while test "${1:0:1}" == "-"
        do
                YUM_ARGS+=("$1")
                shift 1
        done

        # Install/extract RPMs.
        for pkg in "$@"
        do
                PKG_TARGETS=()
                # Check whether the package has been installed, or not.
                # This influences whether we use (re)install command used.
                if $PKG_MANAGER list installed "$pkg" &> /dev/null
                then
                        if $PKG_MANAGER list --upgrades "$pkg" &> /dev/null
                        then
                                PKG_TARGET=update
                        else
                                PKG_TARGET=reinstall
                        fi
                else
                        PKG_TARGET=install
                fi

                if ! (set -x; $PKG_MANAGER ${YUM_ARGS[@]} $PKG_TARGET $pkg -y)
                then
                        exit 1
                fi
        done

        return 0
}

# -----------------------------------------------------------------------------
# EXTERNAL FUNCTIONS ----------------------------------------------------------
# -----------------------------------------------------------------------------

function rpm_install_add()
{
        for pkg in "$@"
        do
                if [ -z "$(rpm -qa $pkg | head -n 1)" ]
                then
                        continue
                fi
                RPM_INSTALL+=("$pkg")
        done
}

function rpm_extract_add()
{
        for pkg in "$@"
        do
                if [ -z "$(rpm -qa $pkg | head -n 1)" ]
                then
                        continue
                fi
                RPM_EXTRACT+=("$pkg")
        done
}

function rpm_install()
{
        __yum_call "${RPM_INSTALL[@]}"

        if test $? -gt 0
        then
                return $ret
        fi

        RPM_INSTALL=()

        return 0
}

function rpm_extract()
{
        __yum_call --downloadonly --downloaddir=$RPM_TMPDIR "${RPM_EXTRACT[@]}"

        if test $? -gt 0
        then
               return $?
        fi

        RPM_EXTRACT=()

        local oldcwd="$(pwd)"

        find $RPM_TMPDIR -maxdepth 1 -mindepth 1 -name "*.rpm" \
        | xargs -I RPM bash -c "
                cd \"$RPM_TMPDIR\";
                rpm2cpio \"RPM\" | cpio -idmv
                rm -f RPM;"

        return 0
}

function rpm_extract_path()
{
        find "$RPM_TMPDIR" -mindepth 1 -maxdepth 1 -type d -iname "$1*"
}
