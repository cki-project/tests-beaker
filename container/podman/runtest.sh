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

# Verify that podman-tests is installed
pkg=$(rpm -qa | grep podman-tests)
if [ -z "$pkg" ] ; then
    report_result "${TEST}" WARN
    rhts-abort -t recipe
fi

# Bug reports require this information.
echo "Podman version:"
podman --version
echo "Podman debug info:"
podman info --debug

# RHEL 8 will install podman-tests, but it will not install bats. We can use
# the Fedora 30 package instead.
if [ ! -x /usr/bin/bats ]; then
    dnf -y --nogpgcheck install \
        http://mirrors.kernel.org/fedora/releases/30/Everything/x86_64/os/Packages/b/bats-1.1.0-2.fc30.noarch.rpm
fi

# NOTE(mhayden): The 'metacopy=on' mount option may be causing issues with
# podman on RHEL 8. It needs to be disabled per BZ 1734799.
PODMAN_RPM_NAME=$(rpm -q podman)
if [[ $PODMAN_RPM_NAME =~ el8 ]]; then
    sed -i 's/,metacopy=on//' /etc/containers/storage.conf || true
    grep ^mountopt /etc/containers/storage.conf || true
fi

# Use the multi-arch Fedora image to ensure podman's tests pass
# on non-x86 architectures.
export PODMAN_TEST_IMAGE_REGISTRY="docker.io"
export PODMAN_TEST_IMAGE_USER="library"
export PODMAN_TEST_IMAGE_NAME="fedora"
export PODMAN_TEST_IMAGE_TAG="latest"

# Run the podman system tests.
bats /usr/share/podman/test/system/ | tee -a "${OUTPUTFILE}"
ret=$?

echo "Test finished" | tee -a "${OUTPUTFILE}"

if [ $ret != 0 ] ; then
    report_result "${TEST}" FAIL $ret
else
    # all is well
    report_result "${TEST}" PASS 0
fi
