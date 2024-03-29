#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

set -euo pipefail

USAGE="""
Usage:
  build.sh -i <image_name> -v <version> [-t <tag>] [-p] [-m]
  build.sh -h

Options:
  -i <image_name>         The image name.
  -v <version>            The image version.
  -t <tag>                Optional tag to push. Defaults to '<version>'.
  -p                      Will push the images to the registry.
  -m                      Builds multi-arch images.
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
  while getopts ":i:v:t:pmh" flag; do
    case "${flag}" in
    i)
      IMAGE_NAME="${OPTARG}"
      ;;
    v)
      VERSION="${OPTARG}"
      ;;
    t)
      TAG="${OPTARG}"
      ;;
    p)
      PUSH_FLAG="true"
      ;;
    m)
      MULTI_ARCH_FLAG="true"
      ;;
    h)
      help
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

  if [[ -z "${PUSH_FLAG:-""}" ]]; then
    PUSH_FLAG="false"
  fi

  if [[ -z "${MULTI_ARCH_FLAG:-""}" ]]; then
    MULTI_ARCH_FLAG="false"
  fi

  IMAGE_REPO="i2group"
  IMAGE_PREFIX="i2eng"
}

function validate() {
  if [[ ! -d "images/${IMAGE_NAME}" ]]; then
    echo "Unknown image: ${IMAGE_NAME}" >&2
    exit 1
  fi

  if [[ ! -d "images/${IMAGE_NAME}/${VERSION}" ]]; then
    echo "Unknown version: ${VERSION}" >&2
    exit 1
  fi
}

function prepare_build_context() {
  local env_file_path="utils/environment.sh"
  local build_folder="images/${IMAGE_NAME}/${VERSION}"
  local env_context_path="${build_folder}/environment.sh"

  # analyze-containers-dev doesn't use the environment.sh util
  if [[ "${IMAGE_NAME}" == "analyze-containers-dev" ]]; then
    return
  fi

  # Solr 8.11 version had a special path
  if [[ "${IMAGE_NAME}" == "solr" && "${VERSION}" == "8.11"* ]]; then
    env_context_path="${build_folder}/scripts/environment.sh"
  fi

  cp "${env_file_path}" "${env_context_path}"
}

function build_image() {
  local is_dev_container="false"
  local build_folder="images/${IMAGE_NAME}/${VERSION}"
  local full_image_name="${IMAGE_REPO}/${IMAGE_PREFIX}-${IMAGE_NAME}:${TAG}"
  local extra_args=()

  [[ -d "images/${IMAGE_NAME}/${VERSION}/.devcontainer" ]] && is_dev_container="true"

  # SQL Server & Db2 only supports amd64
  if [[ "${IMAGE_NAME}" == "sqlserver" || "${IMAGE_NAME}" == "db2" ]]; then
    extra_args+=("--platform=linux/amd64")
  elif [[ "${MULTI_ARCH_FLAG}" == "true" ]]; then
    extra_args+=("--platform=linux/amd64,linux/arm64")
  fi
  if [[ "${MULTI_ARCH_FLAG}" != "true" && "${is_dev_container}" == "false" ]]; then
    extra_args+=("--load")
  fi
  if [[ "${PUSH_FLAG}" == "true" ]]; then
    extra_args+=("--push")
  fi

  print "Building ${IMAGE_NAME}"

  # Create new "analyze-docker" builder instance. But first ensure to remove previous one if any
  docker buildx ls | grep -q "analyze-docker" && docker buildx rm "analyze-docker"
  docker buildx create --driver docker-container --use --name "analyze-docker"

  if [[ "${is_dev_container}" == "true" ]]; then
    # Use devcontainer CLI instead to build image. This uses buildx internally already.
    export DEV_CONTAINER_VERSION="${VERSION}"
    devcontainer build \
      "${extra_args[@]}" \
      --image-name "${full_image_name}" "${build_folder}"
  else
    docker buildx build \
      "${extra_args[@]}" \
      --cache-from type=local,src="/tmp/analyze-docker-cache" --cache-to type=local,dest="/tmp/analyze-docker-cache" \
      --build-arg revision="${CIRCLE_BUILD_NUM:-dev}" \
      --tag "${full_image_name}" "${build_folder}"
  fi
  docker buildx rm "analyze-docker"
  echo "Success"
}

function main() {
  parse_arguments "$@"
  validate

  prepare_build_context
  build_image
}
main "$@"
