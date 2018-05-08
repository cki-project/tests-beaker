#!/bin/bash

. /usr/bin/rhts_environment.sh

ARCH=$(uname -m)
REBOOTCOUNT=${REBOOTCOUNT:-0}

if [ ${REBOOTCOUNT} -eq 0 ]; then
  if [ -z ${KPKG_URL} ]; then
    echo "No KPKG_URL specified" | tee -a ${OUTPUTFILE}
    report_result ${TEST} FAIL 1
    exit 1
  fi

  if [ -z ${KVER} ]; then
    echo "No KVER specified" | tee -a ${OUTPUTFILE}
    report_result ${TEST} FAIL 2
    exit 1
  fi

  echo "Fetching kpkg from ${KPKG_URL}" | tee -a ${OUTPUTFILE}
  curl -OL "${KPKG_URL}" >>${OUTPUTFILE} 2>&1

  if [ $? -ne 0 ]; then
    echo "Failed to fetch package from ${KPKG_URL}" | tee -a ${OUTPUTFILE}
    report_result ${TEST} FAIL 3
    exit 1
  fi

  KPKG=${KPKG_URL##*/}

  tar xfh ${KPKG} -C / >>${OUTPUTFILE} 2>&1

  if [ $? -ne 0 ]; then
    echo "Failed to extract package ${KPKG}" | tee -a ${OUTPUTFILE}
    report_result ${TEST} FAIL 4
    exit 1
  fi

  case ${ARCH} in
    ppc64|ppc64le|s390x)
      for xname in $(ls /boot/vmlinux-*${KVER}); do
        zname=$(echo "${xname}" | sed "s/x-/z-/")
        ln -sv $(basename ${xname}) ${zname}
      done
      ;;
  esac

  new-kernel-pkg -v --mkinitrd --dracut --depmod --make-default --host-only --install ${KVER} >>${OUTPUTFILE} 2>&1

  if [ $? -ne 0 ]; then
    echo "Failed installing kernel ${KVER}" | tee -a ${OUTPUTFILE}
    report_result ${TEST} FAIL 5
    exit 1
  fi

  echo "Installed kernel ${KVER}, rebooting" | tee -a ${OUTPUTFILE}
  report_result ${TEST}/install PASS 0
  rhts-reboot
else
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
    report_result ${TEST} FAIL 6
  fi
fi
