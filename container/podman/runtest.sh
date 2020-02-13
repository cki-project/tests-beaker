#!/bin/bash
#--------------------------------------------------------------------------------
# Copyright (c) 2019 Red Hat, Inc. All rights reserved. This copyrighted material
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Source the common test script helpers
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

# Global variables
ret=0
BATS_RPM="http://mirrors.kernel.org/fedora/releases/31/Everything/x86_64/os/Packages/b/bats-1.1.0-3.fc31.noarch.rpm"
TEST_REGISTRY="docker.io"
TEST_IMAGE_NAME="alpine"
TEST_IMAGE_TAG="latest"

# x86_64 alpine images are all in docker.io/library/alpine:latest
# non-x86_64 alpine image are in docker.io/$(uname -m)/alpine:latest
function multi_arch_wrap {
    if [[ $(uname -m) == "x86_64" ]]; then
        env \
            PODMAN_TEST_IMAGE_REGISTRY=$TEST_REGISTRY \
            PODMAN_TEST_IMAGE_USER="library" \
            PODMAN_TEST_IMAGE_NAME=$TEST_IMAGE_NAME \
            PODMAN_TEST_IMAGE_TAG=$TEST_IMAGE_TAG \
            "$@"
    else
        env \
            PODMAN_TEST_IMAGE_REGISTRY=$TEST_REGISTRY \
            PODMAN_TEST_IMAGE_USER=$(uname -m) \
            PODMAN_TEST_IMAGE_NAME=$TEST_IMAGE_NAME \
            PODMAN_TEST_IMAGE_TAG=$TEST_IMAGE_TAG \
            "$@"
    fi
}

# Verify that podman-tests is installed
pkg=$(rpm -qa | grep podman-tests)
if [ -z "$pkg" ] ; then
    rstrnt-report-result "${TEST}" WARN
    rstrnt-abort -t recipe
fi

# Bug reports require this information.
echo "Podman version:"
podman --version
echo "Podman debug info:"
podman info --debug


# RHEL 8 will install podman-tests, but it will not install bats. We can use
# the Fedora 31 package instead. Attempt the installation five times.
if [ ! -x /usr/bin/bats ]; then
    for i in {1..5}; do
        dnf -y --nogpgcheck install $BATS_RPM && break
    done
fi

# NOTE(mhayden): The 'metacopy=on' mount option may be causing issues with
# podman on RHEL 8. It needs to be disabled per BZ 1734799.
PODMAN_RPM_NAME=$(rpm -q podman)
if [[ $PODMAN_RPM_NAME =~ el8 ]]; then
    sed -i 's/,metacopy=on//' /etc/containers/storage.conf || true
    grep ^mountopt /etc/containers/storage.conf || true
fi

# Run the podman system tests.
TEST_DIR=/usr/share/podman/test/system
for TEST_FILE in ${TEST_DIR}/*.bats; do
    echo -e "\n📊  $(basename $TEST_FILE):"

    # NOTE(mhayden): On non-x86 architectures, all tests must use an
    # architecture-specific container image. However, the history test
    # throws an error due to a bug in the bats script and it must use the
    # generic x86_64 image.
    if [[ $TEST_FILE =~ "history" ]]; then
        bats $TEST_FILE  | tee -a "${OUTPUTFILE}"
    else
        multi_arch_wrap bats $TEST_FILE  | tee -a "${OUTPUTFILE}"
    fi

    # Save a marker if this test failed.
    if [[ $? != 0 ]]; then
        TEST_FAILED=1
    fi
done

echo "Test finished" | tee -a "${OUTPUTFILE}"

if [[ ${TEST_FAILED:-} == 1 ]] ; then
    echo "😭 One or more tests failed."
    rstrnt-report-result "${TEST}" FAIL 1
else
    echo "😎 All tests passed."
    rstrnt-report-result "${TEST}" PASS 0
fi
