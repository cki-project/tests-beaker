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

  if [[ "${KPKG_URL}" =~ ^[^/]+/[^/]+$ ]] ; then
    # COPR
    REPO_NAME=${KPKG_URL/\//-}
  else
    # Normal RPM repo we create
    REPO_NAME='kernel-cki'
  fi

  ALL_PACKAGES=$(${YUM} -q --disablerepo="*" --enablerepo="${REPO_NAME}" list "${ALL}" --showduplicates | tr "\n" "#" | sed -e 's/# / /g' | tr "#" "\n" | grep "^kernel.*\.$ARCH.*${REPO_NAME}")

  for possible_name in "kernel-rt" ; do
    if echo "$ALL_PACKAGES" | grep $possible_name ; then
      PACKAGE_NAME=$possible_name
      break
    fi
  done
  if [[ -z $PACKAGE_NAME ]] ; then
      PACKAGE_NAME=kernel
  fi

  echo "Package name is ${PACKAGE_NAME}" | tee -a ${OUTPUTFILE}
}

function get_kpkg_ver()
{
  if [[ "${KPKG_URL}" =~ .*\.tar\.gz ]] ; then
    declare -r kpkg=${KPKG_URL##*/}
    tar tf "$kpkg" | sed -ne '/^boot\/vmlinu[xz]-[1-9]/ {s/^[^-]*-//p;q}; $Q1'
  else
    if [[ "${KPKG_URL}" =~ ^[^/]+/[^/]+$ ]] ; then
      # Repo names in configs are formatted as "USER-REPO", so take the kpkgurl
      # and change / to -
      REPO_NAME=${KPKG_URL/\//-}
    else
      REPO_NAME='kernel-cki'
    fi

    # Grab the kernel version from the provided repo directly
    ${YUM} -q --disablerepo="*" --enablerepo="${REPO_NAME}" list "${ALL}" "${PACKAGE_NAME}" --showduplicates | tr "\n" "#" | sed -e 's/# / /g' | tr "#" "\n" | grep -m 1 "$ARCH.*${REPO_NAME}" | awk -v arch="$ARCH" '{print $2"."arch}'
  fi
}

function targz_install()
{
  declare -r kpkg=${KPKG_URL##*/}
  echo "Fetching kpkg from ${KPKG_URL}" | tee -a ${OUTPUTFILE}
  curl -OL "${KPKG_URL}" 2>&1 | tee -a ${OUTPUTFILE}

  if [ $? -ne 0 ]; then
    echo "Failed to fetch package from ${KPKG_URL}" | tee -a ${OUTPUTFILE}
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  fi

  echo "Extracting kernel version from ${KPKG_URL}" | tee -a ${OUTPUTFILE}
  KVER=$(get_kpkg_ver)
  if [ -z "${KVER}" ]; then
    echo "Failed to extract kernel version from the package" | tee -a ${OUTPUTFILE}
    rhts-abort -t recipe
    exit 1
  else
    echo "Kernel version is ${KVER}" | tee -a ${OUTPUTFILE}
  fi

  tar xfh ${kpkg} -C / 2>&1 | tee -a ${OUTPUTFILE}

  if [ $? -ne 0 ]; then
    echo "Failed to extract package ${kpkg}" | tee -a ${OUTPUTFILE}
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
    kernel-install add ${KVER} /boot/vmlinuz-${KVER} 2>&1 | tee -a ${OUTPUTFILE}
    grubby --set-default /boot/vmlinuz-${KVER} 2>&1 | tee -a ${OUTPUTFILE}
  else
    new-kernel-pkg -v --mkinitrd --dracut --depmod --make-default --host-only --install ${KVER} 2>&1 | tee -a ${OUTPUTFILE}
  fi

  # Workaround for kernel-install problem when it's not sourcing os-release
  # file, no official bug number yet.
  if [[ "${ARCH}" == s390x ]] ; then
      # Yay matching with wildcard, as we only want to execute this part of the
      # code on BLS systems and when this file exists, to prevent weird failures.
      for f in /boot/loader/entries/*"${KVER}".conf ; do
        title=$(grep title "${f}" | sed "s/[[:space:]]*$//")
        echo "Removing trailing whitespace in title record of $f" | tee -a ${OUTPUTFILE}
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
    echo "No tool to download kernel from a repo" | tee -a ${OUTPUTFILE}
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  fi
}

function rpm_prepare()
{
  # setup yum repo based on url
  cat > /etc/yum.repos.d/kernel-cki.repo << EOF
[kernel-cki]
name=kernel-cki
baseurl=${KPKG_URL}
enabled=1
gpgcheck=0
EOF
  echo "Setup kernel repo file" | tee -a  ${OUTPUTFILE}
  cat /etc/yum.repos.d/kernel-cki.repo 2>&1 | tee -a ${OUTPUTFILE}

  # set YUM var.
  select_yum_tool

  return 0
}

function copr_prepare()
{
  # set YUM var.
  select_yum_tool

  ${YUM} copr enable -y "${KPKG_URL}"
  if [ $? -ne 0 ]; then
    echo "Can't enable COPR repo!" | tee -a ${OUTPUTFILE}
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
  fi
  return 0
}

function download_install_package()
{
  $YUM install --downloadonly -y $1 2>&1 | tee -a ${OUTPUTFILE}

  # If download of a package fails, report warn/abort -> infrastructure issue
  if [ $? -ne 0 ]; then
    echo "Failed to download $2!" 2>&1 | tee -a ${OUTPUTFILE}
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  fi

  # If installation of a downloaded package fails, report fail/abort
  # -> distro issue

  $YUM install -y $1 2>&1 | tee -a ${OUTPUTFILE}
  if [ $? -ne 0 ]; then
    echo "Failed to install $2!" | tee -a ${OUTPUTFILE}
    report_result ${TEST} FAIL 1
    rhts-abort -t recipe
    exit 1
  fi
}

function rpm_install()
{
  echo "Extracting kernel version from ${KPKG_URL}" | tee -a ${OUTPUTFILE}
  KVER="$(get_kpkg_ver)"
  if [ -z "${KVER}" ]; then
    echo "Failed to extract kernel version from the package" | tee -a ${OUTPUTFILE}
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  else
    echo "Kernel version is ${KVER}" | tee -a ${OUTPUTFILE}
  fi

  # download & install kernel, or report result
  download_install_package "${PACKAGE_NAME}-$KVER" "kernel"

  $YUM install -y "${PACKAGE_NAME}-devel-${KVER}" 2>&1 | tee -a ${OUTPUTFILE}
  if [ $? -ne 0 ]; then
    echo "No package kernel-devel-${KVER} found, skipping!" | tee -a ${OUTPUTFILE}
    echo "Note that some tests might require the package and can fail!" | tee -a ${OUTPUTFILE}
  fi
  $YUM install -y "${PACKAGE_NAME}-headers-${KVER}" 2>&1 | tee -a ${OUTPUTFILE}
  if [ $? -ne 0 ]; then
    echo "No package kernel-headers-${KVER} found, skipping!" | tee -a ${OUTPUTFILE}
  fi

  # The package was renamed (and temporarily aliased) in Fedora/RHEL
  if $YUM search kernel-firmware | grep "^kernel-firmware\.noarch" ; then
      $YUM install -y kernel-firmware 2>&1 | tee -a ${OUTPUTFILE}
  else
      $YUM install -y linux-firmware 2>&1 | tee -a ${OUTPUTFILE}
  fi

  # Workaround for BZ 1698363
  if [[ "${ARCH}" == s390x ]] ; then
    grubby --set-default /boot/"${KVER}" && zipl
  fi

  return 0
}

if [ ${REBOOTCOUNT} -eq 0 ]; then
  if [ -z "${KPKG_URL}" ]; then
    echo "No KPKG_URL specified" | tee -a ${OUTPUTFILE}
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
    echo "Failed installing kernel ${KVER}" | tee -a ${OUTPUTFILE}
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  fi

  echo "Installed kernel ${KVER}, rebooting" | tee -a ${OUTPUTFILE}
  report_result ${TEST}/kernel-in-place PASS 0
  rhts-reboot
else
  # set YUM var.
  select_yum_tool

  if [[ ! "${KPKG_URL}" =~ .*\.tar\.gz ]] ; then
    set_package_name
  fi
  echo "Extracting kernel version from ${KPKG_URL}" | tee -a ${OUTPUTFILE}
  KVER=$(get_kpkg_ver)
  if [ -z "${KVER}" ]; then
    echo "Failed to extract kernel version from the package" | tee -a ${OUTPUTFILE}
    rhts-abort -t recipe
    exit 1
  fi

  ckver=$(uname -r)
  uname -a | tee -a ${OUTPUTFILE}
  if [ "${KVER}" = "${ckver}" ]; then
    dmesg | grep -qi 'Call Trace:'
    dmesgret=$?
    if [[ -n "${CHECK_DMESG}" && ${dmesgret} -eq 0 ]]; then
      DMESGLOG=/tmp/dmesg.log
      dmesg > ${DMESGLOG}
      rhts_submit_log -l ${DMESGLOG}
      echo "Call trace found in dmesg, see dmesg.log" | tee -a ${OUTPUTFILE}
      report_result ${TEST} WARN 7
    else
      report_result ${TEST}/reboot PASS 0
    fi
  else
    echo "Kernel version after reboot is not '${KVER}': '${ckver}'" | tee -a ${OUTPUTFILE}
    report_result ${TEST} WARN 99
    rhts-abort -t recipe
    exit 0
  fi
fi
