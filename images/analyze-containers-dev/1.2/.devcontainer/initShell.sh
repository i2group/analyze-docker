#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

# Ensure NOT to add the following line in this script since it will be sourced to current terminal
# set -e

function printUsage() {
  echo "Usage:"
  echo "  initShell.sh [-y]"
  echo "  initShell.sh -h" 1>&2
}

function usage() {
  printUsage
  exit 1
}

function help() {
  printUsage
  echo "Options:" 1>&2
  echo "  -y                                     Answer 'yes' to all prompts." 1>&2
  echo "  -h                                     Display the help." 1>&2
  exit 1
}

while getopts ":yh" flag; do
  case "${flag}" in
  y)
    YES_FLAG="true"
    ;;
  h)
    help
    ;;
  \?)
    usage
    ;;
  :)
    echo "Invalid option: ${OPTARG} requires an argument"
    ;;
  esac
done

function waitForUserReply() {
  local question="$1"
  echo "" # print an empty line

  if [[ "${YES_FLAG}" == "true" ]]; then
    echo "${question} (y/n) "
    echo "You selected -y flag, continuing"
    return 0
  fi

  while true; do
    read -r -p "${question} (y/n) " yn
    case $yn in
    [Yy]*) echo "" && break ;;
    [Nn]*) exit 1 ;;
    *) ;;
    esac
  done
}

function determineRootDir() {
  # Determine project root directory
  ANALYZE_CONTAINERS_ROOT_DIR=$(
    pushd . 1>/dev/null
    while [ "$(pwd)" != "/" ]; do
      test -e .root && grep -q 'Analyze-Containers-Root-Dir' <'.root' && {
        pwd
        break
      }
      cd ..
    done
    popd 1>/dev/null || exit
  )

  export ANALYZE_CONTAINERS_ROOT_DIR

  echo "New ANALYZE_CONTAINERS_ROOT_DIR root directory"
  echo "ANALYZE_CONTAINERS_ROOT_DIR=${ANALYZE_CONTAINERS_ROOT_DIR}"
}

function addExecutablesToPath() {
  export PATH="${PATH}:${ANALYZE_CONTAINERS_ROOT_DIR}/example/pre-prod:${ANALYZE_CONTAINERS_ROOT_DIR}/scripts"
}

if [[ -n "${ANALYZE_CONTAINERS_ROOT_DIR}" ]]; then
  waitForUserReply "ANALYZE_CONTAINERS_ROOT_DIR is already set to ${ANALYZE_CONTAINERS_ROOT_DIR}. Are you sure you want to override it?"
fi

determineRootDir
addExecutablesToPath
