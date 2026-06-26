#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2026)
#
# SPDX short identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

USAGE="""
Usage:
  test.sh [-i <image_name>] [-v <version>] [-r <revision>] [<full_image_name>]
  test.sh -h

Options:
  -h                      Display the help.
  -i <image_name>         Specifies the image name.
                          An image name must be provided, either via this option or via <full_image_name>.
  -v <version>            Specifies the image version.
                          An image version must be provided, either via this option or via <full_image_name>.
  -r <revision>           Specifies the value of the 'revision' LABEL expected.
                          If a parseable <full_image_name> is not provided then this defaults to 'dev'.
  <full_image_name>       The full image name, including tag, to test.
                          Defaults to 'i2group/i2eng-<image_name>:<version>-<revision>'.
                          If provided AND is of format 'i2group/i2eng-<image_name>:<version>-<revision>' then
                          it will provide defaults for the corresponding -i, -v, and -r options so that they
                          do not have to be specified separately.

  Either -i and -v must be provided or a parseable <full_image_name> must be provided.
  If a non-standard <full_image_name> is provided then -i and -v must be provided as well.

  Examples:
    test.sh -i solr -v 99 -r 12345
    test.sh i2group/i2eng-solr:99-12345
    test.sh -i solr -v 99 -r 12345 my-custom-solr
"""

function print() {
  echo ""
  echo "#----------------------------------------------------------------------"
  echo "# $*"
  echo "#----------------------------------------------------------------------"
}

function print_error_and_usage() {
  printf "\n\e[31mERROR: %s\n" "$*" >&2
  printf "\e[0m" >&2
  echo "${USAGE}" >&2
  exit 1
}

function help() {
  echo "${USAGE}"
  exit 0
}

function parse_arguments() {
  IMAGE=''
  IMAGE_NAME=''
  VERSION=''
  REVISION=''
  while getopts ":i:v:r:h" flag; do
    case "${flag}" in
    h)
      help
      ;;
    i)
      IMAGE_NAME="${OPTARG}"
      ;;
    v)
      VERSION="${OPTARG}"
      ;;
    r)
      REVISION="${OPTARG}"
      ;;
    \?)
      print_error_and_usage "Invalid option: -${OPTARG}"
      ;;
    :)
      print_error_and_usage "Invalid option: ${OPTARG} requires an argument"
      ;;
    esac
  done
  # Remove processed options from $@
  shift $((OPTIND - 1))
  # Process remaining arguments as image names
  if [[ $# -eq 0 ]]; then
    if [[ -z "${REVISION}" ]]; then
      REVISION="dev"
    fi
    IMAGE="i2group/i2eng-${IMAGE_NAME}:${VERSION}-${REVISION}"
  elif [[ $# -eq 1 ]]; then
    IMAGE="$1"
    if [[ -z "${IMAGE}" ]]; then
      print_error_and_usage "Full image name given is empty"
    fi
    if [[ "${IMAGE}" =~ ^i2group/i2eng-([^:]+):([^@]+)-(.+)?$ ]]; then
      if [[ -z "${IMAGE_NAME}" ]]; then
        IMAGE_NAME="${BASH_REMATCH[1]}"
      fi
      if [[ -z "${VERSION}" ]]; then
        VERSION="${BASH_REMATCH[2]}"
      fi
      if [[ -z "${REVISION}" ]]; then
        REVISION="${BASH_REMATCH[3]}"
      fi
    else
      if [[ -z "${REVISION}" ]]; then
        REVISION="dev"
      fi
    fi
  else
    print_error_and_usage "Need ONLY ONE full image name to be passed after any options"
  fi
  if [[ -z "${IMAGE_NAME}" ]]; then
    print_error_and_usage "Image name is empty"
  fi
  if [[ ! "${IMAGE_NAME}" =~ ^[-_.a-zA-Z0-9]+$ ]]; then
    print_error_and_usage "Invalid image name: '${IMAGE_NAME}'. It must be a string containing only a-z, A-Z, 0-9, period, underscores and minus."
  fi
  if [[ ! -d "images/${IMAGE_NAME}" ]]; then
    print_error_and_usage "Unknown image name '${IMAGE_NAME}'; no directory found at images/${IMAGE_NAME}"
  fi
  if [[ -z "${VERSION}" ]]; then
    print_error_and_usage "Version is empty"
  fi
  if [[ ! "${VERSION}" =~ ^[-_.a-zA-Z0-9]+$ ]]; then
    print_error_and_usage "Invalid version: '${VERSION}'. It must be a string containing only a-z, A-Z, 0-9, period, underscores and minus."
  fi
  if [[ ! -d "images/${IMAGE_NAME}/${VERSION}" ]]; then
    print_error_and_usage "Unknown version '${VERSION}' for image '${IMAGE_NAME}'; no directory found at images/${IMAGE_NAME}/${VERSION}"
  fi
  if [[ ! "${REVISION}" =~ ^[-_.a-zA-Z0-9]+$ ]]; then
    print_error_and_usage "Invalid revision: '${REVISION}'. It must be a string containing only a-z, A-Z, 0-9, period, underscores and minus."
  fi
}

function test_image_labels() {
  local required_labels=(
    "description"
    "license"
    "maintainer"
    "name"
    "revision"
    "summary"
    # "version"
  )
  # Inspect the image and extract the labels
  local labelsJson
  labelsJson=$(docker inspect --format '{{ json .Config.Labels }}' "${IMAGE}")
  local exit_code=0
  # Check that required labels are set and non-empty
  local label_name
  for label_name in "${required_labels[@]}"; do
    if ! jq -e --arg key "${label_name}" '.[$key] and .[$key] != ""' <<< "${labelsJson}" > /dev/null; then
      echo "ERROR: Label '${label_name}' is missing or empty in image '${IMAGE}'" >&2
      exit_code=1
    fi
  done
  # if REVISION is set, check that it matches the label
  if [[ -n "${REVISION}" ]]; then
    if ! jq -e --arg key "revision" --arg value "${REVISION}" '.[$key] == $value' <<< "${labelsJson}" > /dev/null; then
      echo "ERROR: Label 'revision' is not set to '${REVISION}' in image '${IMAGE}'" >&2
      exit_code=1
    fi
  fi
  if [[ "${exit_code}" == 0 ]]; then
    echo "INFO: All required labels are correctly set in image '${IMAGE}'"
  fi
  return "${exit_code}"
}

# Runs a bash command ($1) in a container made from the image under test,
# with optional extra docker run arguments ($2 onwards),
# and checks that it exits with code 0.
#
# The test_command should include any assertions
# and will be run with 'set -euxo pipefail' with the debug sent to
# stdout to ensure that we can see what is going on.
#
# $1 = test command
# $2 onwards = extra docker run arguments (optional)
function test_docker_image_using_bash_command() {
  local test_command="$1"
  shift
  local extra_args=("$@")
  # set -x logging goes to a temp fd 3 that's going to stdout, so that we can see the debug output
  # without it interfering with the actual output of the commands.
  local container_command=(
    bash -c "\
exec 3>/proc/self/fd/1; \
BASH_XTRACEFD=3; \
set -euxo pipefail; \
${test_command}"
  )
  if (
      BASH_XTRACEFD=1
      set -x
      docker run \
        --rm \
        "${extra_args[@]}" \
        "${IMAGE}" \
        "${container_command[@]}"
    ); then
    return 0
  else
    local exit_code="$?"
    echo "ERROR: Bash command '${test_command}' failed with exit code ${exit_code}" >&2
    return "${exit_code}"
  fi
}

function run_image_test_code() {
  if [[ -r "images/${IMAGE_NAME}/${VERSION}/test.sh" ]]; then
    # shellcheck disable=SC1090
    ( source "images/${IMAGE_NAME}/${VERSION}/test.sh" )
  elif [[ -r "images/${IMAGE_NAME}/test.sh" ]]; then
    # shellcheck disable=SC1090
    ( source "images/${IMAGE_NAME}/test.sh" )
  else
    echo "ERROR: No test.sh found for image ${IMAGE} at images/${IMAGE_NAME}/${VERSION}/test.sh or images/${IMAGE_NAME}/test.sh" >&2
    return 1
  fi
}

function run_tests_for_image() {
  local return_code=0
  # There's a race condition where the image may not be available
  # immediately after a build, so we retry a few times.
  # Worse, we might get a not-our-native-archicture image when we first pull,
  # so we need to pull at least twice to be sure we have the right one.
  local attempt
  for attempt in {1..3}; do
    ( set -x; docker pull "${IMAGE}" > /dev/null ) || true
    sleep 1
  done
  if ! ( set -x; docker pull "${IMAGE}" ); then
    echo "ERROR: Failed to pull image ${IMAGE} after ${attempt} attempts" >&2
    return 1
  fi
  run_image_test_code || return_code="$?"
  test_image_labels || return_code="$?"
  return "${return_code}"
}

function main() {
  parse_arguments "$@"
  print "Testing ${IMAGE} from images/${IMAGE_NAME}/${VERSION}"
  if run_tests_for_image; then
    echo "  PASSED"
  else
    local exit_code="$?"
    echo "ERROR: Tests failed, exit code ${exit_code}" >&2
    return "${exit_code}"
  fi
}

main "$@"
