#!/bin/bash

. /usr/bin/rhts_environment.sh

ARCH=$(uname -m)
REBOOTCOUNT=${REBOOTCOUNT:-0}
YUM=""
PACKAGE_NAME=""

# Bring in library functions.
FILE=$(readlink -f ${BASH_SOURCE})
CDIR=$(dirname $FILE)
source ${CDIR}/../../cki_lib/libcki.sh

function parse_kpkg_url_variables()
{
  # The KPKG_URL can contain variables after a pound sign that are important
  # for this script. For example:
  #    https://example.com/job/12345/repo#package_name=kernel-rt&amp;foo=bar
  # In those situations we need to:
  #   1) Remove the pound sign and variables from KPKG_URL
  #   2) Parse those URL variables into shell variables

  # Get the params from the end of KPKG_URL
  KPKG_PARAMS=$(grep -oP "\#\K(.*)$" <<< $KPKG_URL)

  # Clean up KPKG_URL so that it contains only the URL without variables.
  KPKG_URL=${KPKG_URL%\#*}

  # Kudos to Dennis for the inspiration here:
  #   https://stackoverflow.com/questions/3919755/how-to-parse-query-string-from-a-bash-cgi-script
  saveIFS=$IFS                   # Store the current field separator
  IFS='=&'                       # Set a new field separate for parameter delimiters
  parm=(${KPKG_PARAMS/&amp;/&})  # Split the variables into their pieces
  IFS=$saveIFS                   # Restore the original field separator

  # Loop over the variables we found and set KPKG_VAR_"KEY" = VALUE. We make
  # all keys uppercase for consistency.
  for ((i=0; i<${#parm[@]}; i+=2))
  do
    cki_print_success "Found URL parameter: ${parm[i]^^}=${parm[i+1]}"
    readonly KPKG_VAR_${parm[i]^^}=${parm[i+1]}
  done
}

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
    cki_print_success "Found cached package name on disk: ${PACKAGE_NAME}"
    return
  fi

  # If the pipeline provides the package name after the # sign in the URL, we
  # can use that here and be done really fast.
  if [ ! -z "${KPKG_VAR_PACKAGE_NAME:-}" ]; then
    PACKAGE_NAME=$KPKG_VAR_PACKAGE_NAME
    cki_print_success "Found package name in URL variables: ${PACKAGE_NAME}"
  fi

  # If we don't know the package name at this point, then we need to determine
  # it from the repository itself.
  # NOTE(mhayden): This is a little less reliable and should be removed in the
  # future when all instance of KPKG_URL have package names specified.
  if [ -z "${PACKAGE_NAME:-}" ]; then
    get_package_name_from_repo
  fi

  # Append "-debug" if we were asked to install the debug kernel.
  if [[ "${KPKG_VAR_DEBUG:no}" == "yes" ]]; then
    cki_print_info "Debug kernel was requested -- appending -debug to package name"
    PACKAGE_NAME=${PACKAGE_NAME}-debug
  fi

  # Write the PACKAGE_NAME to a file in /tmp so we have it after reboot.
  echo -n "${PACKAGE_NAME}" > /tmp/kpkginstall/KPKG_PACKAGE_NAME
  cki_print_success "Package name is set: ${PACKAGE_NAME} (cached to disk)"
}

function get_package_name_from_repo()
{
  # Detemine the package name based on the packages found in the RPM
  # repository.
  # NOTE(mhayden): This is a little less reliable and should be removed in the
  # future when all instance of KPKG_URL have package names specified.

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
  if [ -z "${ALL_PACKAGES}" ]; then
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
    cki_abort_recipe "RPM repository is unavailable" FAIL
  fi

  for possible_name in "kernel-rt" ; do
    if echo "$ALL_PACKAGES" | grep $possible_name ; then
      PACKAGE_NAME=$possible_name
      cki_print_success "Found package name in repository: ${PACKAGE_NAME}"
      break
    fi
  done
  if [[ -z $PACKAGE_NAME ]] ; then
      PACKAGE_NAME=kernel
  fi
}

function get_kpkg_ver()
{
  # Recover the saved package name from /tmp/KPKG_KVER if it exists.
  if [ -f "/tmp/kpkginstall/KPKG_KVER" ]; then
    KVER=$(cat /tmp/kpkginstall/KPKG_KVER)
    cki_print_success "Found kernel version string in cache on disk: ${KVER}"
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
  echo -n "${KVER}" > /tmp/kpkginstall/KPKG_KVER
}

function targz_install()
{
  declare -r kpkg=${KPKG_URL##*/}
  cki_print_info "Fetching kpkg from ${KPKG_URL}"

  if curl -sOL "${KPKG_URL}" 2>&1; then
    cki_print_success "Downloaded kernel package successfully from ${KPKG_URL}"
  else
    cki_abort_recipe "Failed to download package from ${KPKG_URL}" WARN
  fi

  cki_print_info "Extracting kernel version from ${KPKG_URL}"
  get_kpkg_ver
  if [ -z "${KVER}" ]; then
    cki_abort_recipe "Failed to extract kernel version from the package" FAIL
  else
    cki_print_success "Kernel version is ${KVER}"
  fi

  if tar xfh ${kpkg} -C / 2>&1; then
    cki_print_success "Extracted kernel package successfully: ${kpkg}"
  else
    cki_abort_recipe "Failed to extract kernel package: ${kpkg}" WARN
  fi

  cki_print_info "Applying architecture-specific workarounds (if needed)"
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
  cki_print_success "Architecture-specific workarounds applied successfully"

  cki_print_info "Finishing boot loader configuration for the new kernel"
  if [ ! -x /sbin/new-kernel-pkg ]; then
    kernel-install add ${KVER} /boot/vmlinuz-${KVER} 2>&1
    grubby --set-default /boot/vmlinuz-${KVER} 2>&1
  else
    new-kernel-pkg -v --mkinitrd --dracut --depmod --make-default --host-only --install ${KVER} 2>&1
  fi
  cki_print_success "Boot loader configuration complete"

  # Workaround for kernel-install problem when it's not sourcing os-release
  # file, no official bug number yet.
  if [[ "${ARCH}" == s390x ]] ; then
      # Yay matching with wildcard, as we only want to execute this part of the
      # code on BLS systems and when this file exists, to prevent weird failures.
      for f in /boot/loader/entries/*"${KVER}".conf ; do
        title=$(grep title "${f}" | sed "s/[[:space:]]*$//")
        sed -i "s/title.*/$title/" "${f}"
        cki_print_success "Removed trailing whitespace in title record of $f"
      done
  fi
}

function select_yum_tool()
{
  if [ -x /usr/bin/dnf ]; then
    YUM=/usr/bin/dnf
    ALL="--all"
    COPR_PLUGIN_PACKAGE=dnf-plugins-core
  elif [ -x /usr/bin/yum ]; then
    YUM=/usr/bin/yum
    ALL="all"
    COPR_PLUGIN_PACKAGE=yum-plugin-copr
  else
    cki_abort_recipe "No tool to download kernel from a repo" WARN
  fi

  cki_print_info "Installing package manager prerequisites"
  ${YUM} install -y ${COPR_PLUGIN_PACKAGE} > /dev/null
  cki_print_success "Package manager prerequisites installed successfully"
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
  cki_print_success "Kernel repository file deployed"

  return 0
}

function copr_prepare()
{
  # set YUM var.
  select_yum_tool

  if ${YUM} copr enable -y "${KPKG_URL}"; then
    cki_print_success "Successfully enabled COPR repository: ${KPKG_URL}"
  else
    cki_abort_recipe "Could not enable COPR repository: ${KPKG_URL}" WARN
  fi
  return 0
}

function download_install_package()
{
  # If download of a package fails, report warn/abort -> infrastructure issue
  if $YUM install --downloadonly -y $1 > /dev/null; then
    cki_print_success "Downloaded $1 successfully"
  else
    cki_abort_recipe "Failed to download ${1}!" WARN
  fi

  # If installation of a downloaded package fails, report fail/abort
  # -> distro issue
  if $YUM install -y $1 > /dev/null; then
    cki_print_success "Installed $1 successfully"
  else
    cki_abort_recipe "Failed to install $1!" FAIL
  fi
}

function rpm_install()
{
  cki_print_info "Extracting kernel version from ${KPKG_URL}"
  get_kpkg_ver
  if [ -z "${KVER}" ]; then
    cki_abort_recipe "Failed to extract kernel version from the package" FAIL
  else
    cki_print_success "Kernel version is ${KVER}"
  fi

  # Ensure that the debug kernel is selected as the default kernel in
  # /boot/grub2/grubenv.
  if [[ "${KPKG_VAR_DEBUG:no}" == "yes" ]]; then
    echo "Adjusting settings in /etc/sysconfig/kernel to set debug as default"
    echo "UPDATEDEFAULT=yes" > /etc/sysconfig/kernel
    echo "DEFAULTKERNEL=kernel-debug" >> /etc/sysconfig/kernel
    echo "DEFAULTDEBUG=yes" >> /etc/sysconfig/kernel
    cki_print_success "Updated /etc/sysconfig/kernel to set debug kernels as default"
  fi

  # download & install kernel, or report result
  download_install_package "${PACKAGE_NAME}-$KVER" "kernel"


  if $YUM install -y "${PACKAGE_NAME}-devel-${KVER}" > /dev/null; then
    cki_print_success "Installed ${PACKAGE_NAME}-devel-${KVER} successfully"
  else
    cki_print_warning "No package kernel-devel-${KVER} found, skipping!"
    cki_print_warning "Note that some tests might require the package and can fail!"
  fi
  if $YUM install -y "${PACKAGE_NAME}-headers-${KVER}" > /dev/null; then
    cki_print_success "Installed ${PACKAGE_NAME}-headers-${KVER} successfully"
  else
    cki_print_warning "No package kernel-headers-${KVER} found, skipping!"
    cki_print_warning "Note that some tests might require the package and can fail!"
  fi

  # The package was renamed (and temporarily aliased) in Fedora/RHEL"
  if $YUM search kernel-firmware | grep "^kernel-firmware\.noarch" ; then
    FIRMWARE_PKG=kernel-firmware
  else
    FIRMWARE_PKG=linux-firmware
  fi
  cki_print_info "Installing kernel firmware package"
  $YUM install -y $FIRMWARE_PKG > /dev/null
  cki_print_success "Kernel firmware package installed"

  # Workaround for BZ 1698363
  if [[ "${ARCH}" == s390x ]] ; then
    grubby --set-default /boot/"${KVER}" > /dev/null && zipl > /dev/null
    cki_print_success "Grubby workaround for s390x completed"
  fi

  return 0
}

if [ ${REBOOTCOUNT} -eq 0 ]; then

  # If we haven't rebooted yet, then we shouldn't have the temporary directory
  # present on the system.
  rm -rfv /tmp/kpkginstall

  # Make a directory to hold small bits of information for the test.
  mkdir -p /tmp/kpkginstall

  # If the KPKG_URL contains a pound sign, then we have variables on the end
  # which need to be removed and parsed.
  if [[ $KPKG_URL =~ \# ]]; then
      parse_kpkg_url_variables
  fi

  # If we are installing a debug kernel, make a reminder for us to check for
  # a debug kernel after the reboot
  if [[ "${KPKG_VAR_DEBUG:no}" == "yes" ]]; then
    echo "yes" > /tmp/kpkginstall/KPKG_VAR_DEBUG
  fi

  if [ -z "${KPKG_URL}" ]; then
    cki_abort_recipe "No KPKG_URL specified" FAIL
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
    cki_abort_recipe "Failed installing kernel ${KVER}" WARN
  fi

  cki_print_success "Installed kernel ${KVER}, rebooting (this may take a while)"
  cat << EOF
*******************************************************************************
*******************************************************************************
** A reboot is required to boot the new kernel that was just installed.      **
** This can take a while on some systems, especially those with slow BIOS    **
** POST routines, like HP servers.                                           **
**                                                                           **
** Please be patient...                                                      **
*******************************************************************************
*******************************************************************************
EOF
  report_result ${TEST}/kernel-in-place PASS 0
  rhts-reboot
else
  # set YUM var.
  select_yum_tool

  if [[ ! "${KPKG_URL}" =~ .*\.tar\.gz ]] ; then
    set_package_name
  fi
  cki_print_info "Extracting kernel version from ${KPKG_URL}"
  get_kpkg_ver
  if [ -z "${KVER}" ]; then
    cki_abort_recipe  "Failed to extract kernel version from the package" FAIL
  fi

  # Make a list of kernel versions we expect to see after reboot.
  if [ -f /tmp/kpkginstall/KPKG_VAR_DEBUG ]; then
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
  ckver=$(uname -r)
  cki_print_info "Acceptable kernel version strings: ${valid_kernel_versions[@]} "
  cki_print_info "Running kernel version string:     ${ckver}"

  # Did we get the right kernel running after reboot?
  if [[ ! " ${valid_kernel_versions[@]} " =~ " ${ckver} " ]]; then
    cki_abort_recipe "Kernel version after reboot (${ckver}) does not match expected version strings!" WARN
  fi

  cki_print_success "Found the correct kernel version running!"

  # We have the right kernel. Do we have any call traces?
  dmesg | grep -qi 'Call Trace:'
  dmesgret=$?
  if [[ -n "${CHECK_DMESG}" && ${dmesgret} -eq 0 ]]; then
    DMESGLOG=/tmp/dmesg.log
    dmesg > ${DMESGLOG}
    rhts_submit_log -l ${DMESGLOG}
    cki_print_warning "Call trace found in dmesg, see dmesg.log"
    report_result ${TEST} WARN 7
  else
    report_result ${TEST}/reboot PASS 0
  fi
fi
