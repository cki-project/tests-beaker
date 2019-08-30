#!/bin/bash
set -x


. /usr/bin/rhts_environment.sh

ARCH=$(uname -m)
REBOOTCOUNT=${REBOOTCOUNT:-0}
YUM=""
PACKAGE_NAME=""

function set_package_name()
{
  # We can't do a simple "grep for anything kernel-like" because of packages like
  # kernel-devel, kernel-tools etc. State all possible kernel packages that aren't
  # a simple "kernel" and check for them. If none of them is present, set the
  # package name to kernel. Do NOT do a check for "kernel" because all of those
  # packages we don't want to match will match!
  # Please someone come up with a better solution how to determine the package name...

  # Recover the saved package name from /tmp/KPKG_PACKAGE_NAME if it exists.
  if [ -f "/tmp/kpkginstall/KPKG_PACKAGE_NAME" ]; then
    PACKAGE_NAME=$(cat /tmp/kpkginstall/KPKG_PACKAGE_NAME)
    return
  fi

  if [[ "${KPKG_URL}" =~ ^[^/]+/[^/]+$ ]] ; then
    # COPR
    REPO_NAME=${KPKG_URL/\//-}
  else
    # Normal RPM repo we create
    REPO_NAME='kernel-cki'
  fi

  ALL_PACKAGES=$(${YUM} -q --disablerepo="*" --enablerepo="${REPO_NAME}" list "${ALL}" --showduplicates | tr "\n" "#" | sed -e 's/# / /g' | tr "#" "\n" | grep "^kernel.*\.$ARCH.*${REPO_NAME}")

  # An empty result for ALL_PACKAGES likely means that the repo has been
  # deleted from GitLab's artifact storage.
  if [ -z $ALL_PACKAGES ]; then
    cat << EOF
*******************************************************************************
*******************************************************************************
** 🔥 No packages were found on the RPM repository provided for this test.   **
** This usually happens when the artifacts for a test job are no             **
** longer available.                                                         **
**                                                                           **
** For more details, email cki-project@redhat.com.                           **
*******************************************************************************
*******************************************************************************
EOF
    rhts-abort -t recipe
    exit 1
  fi

  for possible_name in "kernel-rt" ; do
    if echo "$ALL_PACKAGES" | grep $possible_name ; then
      PACKAGE_NAME=$possible_name
      break
    fi
  done
  if [[ -z $PACKAGE_NAME ]] ; then
      PACKAGE_NAME=kernel
  fi

  # Append "-debug" if we were asked to install the debug kernel.
  if [[ "${KPKG_INSTALL_DEBUG:-}" == "yes" ]]; then
    echo "Debug kernel was requested -- appending -debug to package name"
    PACKAGE_NAME=${PACKAGE_NAME}-debug
  fi

  # Write the PACKAGE_NAME to a file in /tmp so we have it after reboot.
  echo -n "${PACKAGE_NAME}" | tee -a /tmp/kpkginstall/KPKG_PACKAGE_NAME

  echo "Package name is ${PACKAGE_NAME}"
}

function get_kpkg_ver()
{
  # Recover the saved package name from /tmp/KPKG_KVER if it exists.
  if [ -f "/tmp/kpkginstall/KPKG_KVER" ]; then
    KVER=$(cat /tmp/kpkginstall/KPKG_KVER)
    return
  fi

  if [[ "${KPKG_URL}" =~ .*\.tar\.gz ]] ; then
    declare -r kpkg=${KPKG_URL##*/}
    KVER=$(tar tf "$kpkg" | sed -ne '/^boot\/vmlinu[xz]-[1-9]/ {s/^[^-]*-//p;q}; $Q1')
  else
    if [[ "${KPKG_URL}" =~ ^[^/]+/[^/]+$ ]] ; then
      # Repo names in configs are formatted as "USER-REPO", so take the kpkgurl
      # and change / to -
      REPO_NAME=${KPKG_URL/\//-}
    else
      REPO_NAME='kernel-cki'
    fi

    # Grab the kernel version from the provided repo directly
    KVER=$(
      ${YUM} -q --disablerepo="*" --enablerepo="${REPO_NAME}" list "${ALL}" "${PACKAGE_NAME}" --showduplicates \
        | tr "\n" "#" | sed -e 's/# / /g' | tr "#" "\n" \
        | grep -m 1 "$ARCH.*${REPO_NAME}" \
        | awk -v arch="$ARCH" '{print $2"."arch}'
    )
  fi

  # Write the KVER to a file in /tmp so we have it after reboot.
  echo -n "${KVER}" | tee -a /tmp/kpkginstall/KPKG_KVER
}

function targz_install()
{
  declare -r kpkg=${KPKG_URL##*/}
  echo "Fetching kpkg from ${KPKG_URL}"
  curl -OL "${KPKG_URL}" 2>&1

  if [ $? -ne 0 ]; then
    echo "Failed to fetch package from ${KPKG_URL}"
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  fi

  echo "Extracting kernel version from ${KPKG_URL}"
  get_kpkg_ver
  if [ -z "${KVER}" ]; then
    echo "Failed to extract kernel version from the package"
    rhts-abort -t recipe
    exit 1
  else
    echo "Kernel version is ${KVER}"
  fi

  tar xfh ${kpkg} -C / 2>&1

  if [ $? -ne 0 ]; then
    echo "Failed to extract package ${kpkg}"
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  fi

  case ${ARCH} in
    ppc64|ppc64le)
      for xname in $(ls /boot/vmlinux-*${KVER}); do
        zname=$(echo "${xname}" | sed "s/x-/z-/")
        mv ${xname} ${zname}
      done
      ;;
    aarch64)
      # These steps are required until the following patch is backported into
      # the kernel trees: https://patchwork.kernel.org/patch/10532993/

      # Check if the vmlinuz is present (a sign that the upstream patch has
      # merged)
      if [ -f "/boot/vmlinuz-${KVER}" ]; then
        # Remove the vmlinux file so that only the vmlinuz is used
        rm -f /boot/vmlinux-${KVER}
      else
        # Strip the vmlinux binary as required for aarch64
        objcopy  -O binary -R .note -R .note.gnu.build-id -R .comment -S /boot/vmlinux-${KVER} /tmp/vmlinux-${KVER}

        # Compress the stripped vmlinux
        cat /tmp/vmlinux-${KVER} | gzip -n -f -9 > /boot/vmlinuz-${KVER}

        # Clean up temporary stripped vmlinux and the generic vmlinux in /boot
        rm -f /tmp/vmlinux-${KVER} /boot/vmlinux-${KVER}
      fi
      ;;
    s390x)
      # These steps are required until the following patch is backported into
      # the kernel trees: https://patchwork.kernel.org/patch/10534813/

      # Check to see if vmlinuz is present (it's a sign that upstream patch)
      # has merged)
      if [ -f "/boot/vmlinuz-${KVER}" ]; then
        # Remove the vmlinux from /boot and use only the vmlinuz
        rm -f /boot/vmlinux-${KVER}
      else
        # Copy over the vmlinux-kbuild binary as a temporary workaround. With
        # newer kernels, this is identical to the missing bzImage. With older
        # (3.10) kernels, the vmlinux-kbuild marks built "image" instead of
        # "bzImage", which is still bootable by s390x.
        mv /boot/vmlinux-kbuild-${KVER} /boot/vmlinuz-${KVER}
      fi
      ;;
  esac

  if [ ! -x /sbin/new-kernel-pkg ]; then
    kernel-install add ${KVER} /boot/vmlinuz-${KVER} 2>&1
    grubby --set-default /boot/vmlinuz-${KVER} 2>&1
  else
    new-kernel-pkg -v --mkinitrd --dracut --depmod --make-default --host-only --install ${KVER} 2>&1
  fi

  # Workaround for kernel-install problem when it's not sourcing os-release
  # file, no official bug number yet.
  if [[ "${ARCH}" == s390x ]] ; then
      # Yay matching with wildcard, as we only want to execute this part of the
      # code on BLS systems and when this file exists, to prevent weird failures.
      for f in /boot/loader/entries/*"${KVER}".conf ; do
        title=$(grep title "${f}" | sed "s/[[:space:]]*$//")
        echo "Removing trailing whitespace in title record of $f"
        sed -i "s/title.*/$title/" "${f}"
      done
  fi
}

function select_yum_tool()
{
  if [ -x /usr/bin/dnf ]; then
    YUM=/usr/bin/dnf
    ALL="--all"
    ${YUM} install -y dnf-plugins-core
  elif [ -x /usr/bin/yum ]; then
    YUM=/usr/bin/yum
    ALL="all"
    ${YUM} install -y yum-plugin-copr
  else
    echo "No tool to download kernel from a repo"
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  fi
}

function rpm_prepare()
{
  # Detect if we have yum or dnf and install packages for managing COPR repos.
  select_yum_tool

  # setup yum repo based on url
  cat > /etc/yum.repos.d/kernel-cki.repo << EOF
[kernel-cki]
name=kernel-cki
baseurl=${KPKG_URL}
enabled=1
gpgcheck=0
EOF
  echo "Setup kernel repo file"
  cat /etc/yum.repos.d/kernel-cki.repo 2>&1

  return 0
}

function copr_prepare()
{
  # set YUM var.
  select_yum_tool

  ${YUM} copr enable -y "${KPKG_URL}"
  if [ $? -ne 0 ]; then
    echo "Can't enable COPR repo!"
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
  fi
  return 0
}

function download_install_package()
{
  $YUM install --downloadonly -y $1 2>&1

  # If download of a package fails, report warn/abort -> infrastructure issue
  if [ $? -ne 0 ]; then
    echo "Failed to download $2!" 2>&1
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  fi

  # If installation of a downloaded package fails, report fail/abort
  # -> distro issue

  $YUM install -y $1 2>&1
  if [ $? -ne 0 ]; then
    echo "Failed to install $2!"
    report_result ${TEST} FAIL 1
    rhts-abort -t recipe
    exit 1
  fi
}

function rpm_install()
{
  echo "Extracting kernel version from ${KPKG_URL}"
  get_kpkg_ver
  if [ -z "${KVER}" ]; then
    echo "Failed to extract kernel version from the package"
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  else
    echo "Kernel version is ${KVER}"
  fi

  # Ensure that the debug kernel is selected as the default kernel in
  # /boot/grub2/grubenv.
  if [[ "${KPKG_INSTALL_DEBUG:-}" == "yes" ]]; then
    echo "Adjusting settings in /etc/sysconfig/kernel to set debug as default"
    echo "UPDATEDEFAULT=yes" | tee /etc/sysconfig/kernel
    echo "DEFAULTKERNEL=kernel-debug" | tee -a /etc/sysconfig/kernel
    echo "DEFAULTDEBUG=yes" | tee -a /etc/sysconfig/kernel
  fi

  # download & install kernel, or report result
  download_install_package "${PACKAGE_NAME}-$KVER" "kernel"

  $YUM install -y "${PACKAGE_NAME}-devel-${KVER}" 2>&1
  if [ $? -ne 0 ]; then
    echo "No package kernel-devel-${KVER} found, skipping!"
    echo "Note that some tests might require the package and can fail!"
  fi
  $YUM install -y "${PACKAGE_NAME}-headers-${KVER}" 2>&1
  if [ $? -ne 0 ]; then
    echo "No package kernel-headers-${KVER} found, skipping!"
  fi

  # The package was renamed (and temporarily aliased) in Fedora/RHEL
  if $YUM search kernel-firmware | grep "^kernel-firmware\.noarch" ; then
      $YUM install -y kernel-firmware 2>&1
  else
      $YUM install -y linux-firmware 2>&1
  fi

  # Workaround for BZ 1698363
  if [[ "${ARCH}" == s390x ]] ; then
    grubby --set-default /boot/"${KVER}" && zipl
  fi

  return 0
}

if [ ${REBOOTCOUNT} -eq 0 ]; then

  # If we haven't rebooted yet, then we shouldn't have the temporary directory
  # present on the system.
  rm -rfv /tmp/kpkginstall

  # Make a directory to hold small bits of information for the test.
  mkdir -p /tmp/kpkginstall

  # If we are installing a debug kernel, make a reminder for us to check for
  # a debug kernel after the reboot
  if [[ "${KPKG_INSTALL_DEBUG:-}" == "yes" ]]; then
    touch /tmp/kpkginstall/KPKG_INSTALL_DEBUG
  fi

  if [ -z "${KPKG_URL}" ]; then
    echo "No KPKG_URL specified"
    rhts-abort -t recipe
    exit 1
  fi

  if [[ "${KPKG_URL}" =~ .*\.tar\.gz ]] ; then
      targz_install
  elif [[ "${KPKG_URL}" =~ ^[^/]+/[^/]+$ ]] ; then
      copr_prepare
      set_package_name
      rpm_install
  else
      rpm_prepare
      set_package_name
      rpm_install
  fi

  if [ $? -ne 0 ]; then
    echo "Failed installing kernel ${KVER}"
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  fi

  echo "Installed kernel ${KVER}, rebooting"
  report_result ${TEST}/kernel-in-place PASS 0
  rhts-reboot
else
  # set YUM var.
  select_yum_tool

  if [[ ! "${KPKG_URL}" =~ .*\.tar\.gz ]] ; then
    set_package_name
  fi
  echo "Extracting kernel version from ${KPKG_URL}"
  get_kpkg_ver
  if [ -z "${KVER}" ]; then
    echo "Failed to extract kernel version from the package"
    rhts-abort -t recipe
    exit 1
  fi

  ckver=$(uname -r)
  uname -a

  # Make a list of kernel versions we expect to see after reboot.
  if [ -f /tmp/kpkginstall/KPKG_INSTALL_DEBUG ]; then
    valid_kernel_versions=(
      "${KVER}.debug"           # RHEL 7 style debug kernels
      "${KVER}.${ARCH}.debug"   # RHEL 7 style debug kernels
      "${KVER}+debug"           # RHEL 8 style debug kernels
      "${KVER}.${ARCH}+debug"   # RHEL 8 style debug kernels
    )
  else
    valid_kernel_versions=(
      "${KVER}"
      "${KVER}.${ARCH}"
    )
  fi
  echo "Acceptable kernel version strings: ${valid_kernel_versions[@]} "
  echo "Running kernel version string:     ${ckver}"

  # Did we get the right kernel running after reboot?
  if [[ ! " ${valid_kernel_versions[@]} " =~ " ${ckver} " ]]; then
    echo "❌ Kernel version after reboot (${ckver}) does not match expected version strings!"
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  fi

  echo "✅ Found the correct kernel version running!"

  # We have the right kernel. Do we have any call traces?
  dmesg | grep -qi 'Call Trace:'
  dmesgret=$?
  if [[ -n "${CHECK_DMESG}" && ${dmesgret} -eq 0 ]]; then
    DMESGLOG=/tmp/dmesg.log
    dmesg > ${DMESGLOG}
    rhts_submit_log -l ${DMESGLOG}
    echo "⚠️  Call trace found in dmesg, see dmesg.log"
    report_result ${TEST} WARN 7
  else
    report_result ${TEST}/reboot PASS 0
  fi
fi
