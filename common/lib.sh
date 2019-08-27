#!/bin/bash
# Common helper functions to be used by all CKI tests

function cki_yum_tool()
{
  if [ -x /usr/bin/dnf ]; then
    YUM=/usr/bin/dnf
  elif [ -x /usr/bin/yum ]; then
    YUM=/usr/bin/yum
  else
    echo "No tool to download kernel from a repo"
    rhts-abort -t recipe
    exit 0
  fi
}
