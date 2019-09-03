#!/bin/bash
# Common helper functions to be used by all CKI tests

function abort_recipe()
{
  # When a serious problem occurs and we cannot proceed any further, we abort
  # this recipe with an error message.
  #
  # Arguments:
  #   $1 - the message to print in the log
  #   $2 - 'WARN' or 'FAIL'
  FAILURE_MESSAGE=$1
  FAILURE_TYPE=${2:-"FAIL"}

  echo "❌ ${FAILURE_MESSAGE}"
  if [[ $FAILURE_TYPE == 'WARN' ]]; then
    report_result ${TEST} WARN 99
  else
    report_result ${TEST} FAIL 1
  fi
  rhts-abort -t recipe
  exit 1
}

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

function print_info()
{
  # Print an informational message with a friendly emoji.
  echo "ℹ️ ${1}"
}

function print_success()
{
  # Print a success message with a friendly emoji.
  echo "✅ ${1}"
}

function print_warning()
{
  # Print an warning message with a friendly emoji.
  echo "⚠️ ${1}"
}
