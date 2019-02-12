#!/usr/bin/env bash

# -- Handle Test Cleanup ------------------------------------------------------
# Add any temporary files into TMP_FILES to have them cleaned up automatically,
# as follows: TMP_FILES+=("$file").

TMP_FILES=()

function __cleanup()
{
        for arg in "${TMP_FILES[@]}"
        do
                rm -rf "$arg"
        done
}

trap "__cleanup" 0 1 9 15

# -- RPM Dependencies ---------------------------------------------------------
# Specify which packages ought to be:
#   a) installed prior to running the test*,
#   b) downloaded and contents extracted prior to running the test**.
#
# *  Use rpm_install_add [PACKAGE_NAME] # to mark for installation
# ** Use rpm_extract_add [PACKAGE_NAME] # to mark for extraction
#
# - Invoke rpm_install to install all dependencies.
# - Invoke rpm_extract to extract all RPMs marked for extraction.
# - Invoke rpm_extract_path [PACKAGE_NAME] to obtain the path to the extracted
#   files.

SCRIPT_DIR__RUNTEST="$(realpath "$(dirname "$0")")"

source "$SCRIPT_DIR__RUNTEST/../shared/rpm-utils.sh"

# -- Load kpet/skt dependencies -----------------------------------------------

source "$SCRIPT_DIR__RUNTEST/../shared/kernel-ci.sh"

# -- Run requested test -------------------------------------------------------

source "$SCRIPT_DIR__RUNTEST/01-whitelist.sh"

rpm_install
main
