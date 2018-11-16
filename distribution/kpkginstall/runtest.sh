#!/bin/bash

. /usr/bin/rhts_environment.sh

ARCH=$(uname -m)
REBOOTCOUNT=${REBOOTCOUNT:-0}

# Output version of the kernel contained in the specified kernel package
# tarball.
#
# Args: tarball
# Output: kernel version, nothing if not found
# Status: zero if version is found, non-zero on failure
function get_kpkg_ver()
{
  tar tf "$1" | sed -ne '/^boot\/vmlinu[xz]-[1-9]/ {s/^[^-]*-//p;q}; $Q1'
}

if [ ${REBOOTCOUNT} -eq 0 ]; then
  if [ -z ${KPKG_URL} ]; then
    echo "No KPKG_URL specified" | tee -a ${OUTPUTFILE}
    rhts-abort -t recipe
    exit 1
  fi

  echo "Fetching kpkg from ${KPKG_URL}" | tee -a ${OUTPUTFILE}
  curl -OL "${KPKG_URL}" >>${OUTPUTFILE} 2>&1

  if [ $? -ne 0 ]; then
    echo "Failed to fetch package from ${KPKG_URL}" | tee -a ${OUTPUTFILE}
    rhts-abort -t recipe
    exit 1
  fi

  KPKG=${KPKG_URL##*/}

  echo "Extracting kernel version from package ${KPKG}" | tee -a ${OUTPUTFILE}
  KVER=$(get_kpkg_ver "$KPKG")
  if [ -z ${KVER} ]; then
    echo "Failed to extract kernel version from the package" | tee -a ${OUTPUTFILE}
    rhts-abort -t recipe
    exit 1
  fi

  tar xfh ${KPKG} -C / >>${OUTPUTFILE} 2>&1

  if [ $? -ne 0 ]; then
    echo "Failed to extract package ${KPKG}" | tee -a ${OUTPUTFILE}
    rhts-abort -t recipe
    exit 1
  fi

  case ${ARCH} in
    ppc64|ppc64le)
      for xname in $(ls /boot/vmlinux-*${KVER}); do
        zname=$(echo "${xname}" | sed "s/x-/z-/")
        ln -sv $(basename ${xname}) ${zname}
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
    kernel-install add ${KVER} /boot/vmlinuz-${KVER} >>${OUTPUTFILE} 2>&1
    grub2-set-default 0 >>${OUTPUTFILE} 2>&1
  else
    new-kernel-pkg -v --mkinitrd --dracut --depmod --make-default --host-only --install ${KVER} >>${OUTPUTFILE} 2>&1
  fi

  if [ $? -ne 0 ]; then
    echo "Failed installing kernel ${KVER}" | tee -a ${OUTPUTFILE}
    rhts-abort -t recipe
    exit 1
  fi

  echo "Installed kernel ${KVER}, rebooting" | tee -a ${OUTPUTFILE}
  report_result ${TEST}/kernel-in-place PASS 0
  rhts-reboot
else
  KPKG=${KPKG_URL##*/}

  echo "Extracting kernel version from package ${KPKG}" | tee -a ${OUTPUTFILE}
  KVER=$(get_kpkg_ver "$KPKG")
  if [ -z ${KVER} ]; then
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
    rhts-abort -t recipe
  fi
fi
