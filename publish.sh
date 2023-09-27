#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -euo pipefail

USAGE="""
Usage:
  publish.sh -i <image_name> -v <version> [-t <tag>]
  publish.sh -h

Options:
  -i <image_name>         Name of the image without repository or prefix. e.g 'solr'.
  -v <version>            The image version.
  -t <tag>                Optional tag to push. Defaults to '<version>'.
  -h                      Display the help.
"""

function print() {
  echo ""
  echo "#----------------------------------------------------------------------"
  echo "# $1"
  echo "#----------------------------------------------------------------------"
}

function usage() {
  echo -e "${USAGE}" >&2
  exit 1
}

function print_error_and_exit() {
  print_error "$1"
  exit 1
}

function print_error() {
  printf "\n\e[31mERROR: %s\n" "$1" >&2
  printf "\e[0m" >&2
}

function print_error_and_usage() {
  print_error "$1"
  usage
}

function help() {
  echo -e "${USAGE}"
  exit 0
}

function parse_arguments() {
  while getopts ":i:v:t:h" flag; do
    case "${flag}" in
    h)
      help
      ;;
    i)
      IMAGE_NAME="${OPTARG}"
      ;;
    t)
      TAG="${OPTARG}"
      ;;
    v)
      VERSION="${OPTARG}"
      ;;
    \?)
      usage
      ;;
    :)
      print_error_and_usage "Invalid option: ${OPTARG} requires an argument"
      ;;
    esac
  done

  if [[ -z "${IMAGE_NAME:-""}" ]]; then
    print_error_and_usage "Image name needs to be passed to be able to build"
  fi

  if [[ -z "${VERSION:-""}" ]]; then
    print_error_and_usage "Version needs to be passed to be able to build"
  fi

  if [[ -z "${TAG:-""}" ]]; then
    TAG="${VERSION}"
  fi

  STABLE_MAJOR_TAG="${VERSION%%.*}"
}

function get_latest_major_version_from_version() {
  local image_name="$1"
  local major_version="$2"

  find "./images/${image_name}" -mindepth 1 -maxdepth 1 -name "${major_version}.*" -not -name "*-main" -type d -exec basename {} \; | sort | tail -1
}

function get_latest_version() {
  local image_name="$1"
  find "./images/${image_name}" -mindepth 1 -maxdepth 1 -not -name "*-main" -type d -exec basename {} \; | sort | tail -1
}

function main() {
  local latest_version latest_major_version
  parse_arguments "$@"

  # All these commands will reuse the cache from the previously run build
  # Push unique image name
  ./build.sh -i "${IMAGE_NAME}" -v "${VERSION}" -t "${TAG}" -m -p

  # Push stable minor tag
  ./build.sh -i "${IMAGE_NAME}" -v "${VERSION}" -t "${VERSION}" -m -p

  if [[ "${STABLE_MAJOR_TAG}" != "${VERSION}" ]]; then
    # Check if it is latest major and push
    latest_major_version=$(get_latest_major_version_from_version "${IMAGE_NAME}" "${STABLE_MAJOR_TAG}")
    if [[ "${latest_major_version}" == "${VERSION}" ]]; then
      ./build.sh -i "${IMAGE_NAME}" -v "${VERSION}" -t "${STABLE_MAJOR_TAG}" -m -p
    fi
  fi

  # Check if it is latest and push
  latest_version=$(get_latest_version "${IMAGE_NAME}")
  if [[ "${latest_version}" == "${VERSION}" ]]; then
      ./build.sh -i "${IMAGE_NAME}" -v "${VERSION}" -t "latest" -m -p
  fi
}
main "$@"
