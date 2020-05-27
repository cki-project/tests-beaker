#!/bin/bash

function get_pkg_version
{
   grep -q "release [5-7].*" /etc/redhat-release && echo "2.18" || echo "2.21"
}

function get_python_version
{
    typeset pv=$(python -V | awk '{print $NF}')
    [[ $pv == "3."* ]] && echo "python3" || echo "python2"
}

function is_rhel8
{
    typeset release=$(grep -Go 'release [0-9]\+' /etc/redhat-release | \
        awk '{print $NF}')
    [[ $release == "8" ]] && return 0 || return 1
}

function set_default_python
{
    rpm --quiet -q --whatprovides python3 || dnf -y install python3
    alternatives --set python /usr/bin/python3
}

function run_cmd
{
    echo ">>> $*"
    eval "$*"
    return $?
}

PACKAGE_NAME=libhugetlbfs
PATCH_DIR=$(dirname $(readlink -f $BASH_SOURCE))/../patches
PACKAGE_VERSION=$(get_pkg_version)
TARGET=${PACKAGE_NAME}-${PACKAGE_VERSION}
is_rhel8 && set_default_python
PYTHON_VERSION=$(get_python_version)

patch_files="
        assume-support-rhel6.patch \
        remove-duplicate-cases.patch \
        "
if [[ $PACKAGE_VERSION == "2.18" ]]; then
    patch_files+=" \
        fix-plt_extrasz-always-returning-0-on-ppc64le.patch \
        map_high_truncate.patch \
        huge_page_setup_helper-do-not-assume-default-huge-pa.patch \
        tests-linkhuge_rw-function-ptr-may-not-refer-to-.tex.patch \
        misalign-make-some-adjustments-for-misalign.patch \
        0001-aarch64-fix-page-size-not-properly-computed.patch \
        0001-ld.hugetlbfs-arm-arches-fix-page-size-and-text-offse.patch \
        0001-Force-text-segment-alignment-to-0x08000000-for-i386-.patch \
        0001-ld.hugetlbfs-pick-an-emulation-if-m-is-not-present.patch \
        0002-runtests.py-Change-R-to-R-in-elflink_rw_test-functio.patch \
        0003-ld.hugetlbfs-pick-an-emulation-if-m-is-not-present.patch \
        0004-tests-heapshrink-allocate-enough-to-expand-heap.patch \
        0005-ld.hugetlbfs-support-512M-hugepages-on-aarch64.patch \
        0001-restrict-is-a-reserved-keyword-in-C99.patch \
        0001-testutils-fix-range_is_mapped.patch \
        0002-stack_grow_into_huge-don-t-clobber-existing-mappings.patch \
        0001-tests-Makefile-HUGELINK_RW_TESTS-not-being-reference.patch \
        0001-Defined-task-size-value-to-be-512T-if-it-is-more-tha.patch \
        "
else # 2.21
    patch_files+=" \
        0001-testutils-fix-range_is_mapped.patch \
        0002-stack_grow_into_huge-don-t-clobber-existing-mappings.patch \
        "
    if [[ $PYTHON_VERSION == "python3" ]]; then
        patch_files+=" \
            huge_page_setup_helper-python3-convert.patch \
            run_tests-python3-convert.patch \
            "
    fi
    patch_files+=" \
        build_flags.patch \
        hack-task-size-overrun.patch \
        "
fi

for patch_file in $(echo $patch_files); do
    run_cmd "patch -p1 -d $TARGET < $PATCH_DIR/$patch_file"
done
