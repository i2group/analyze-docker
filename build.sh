#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=utils/pull_image.sh
. "${SCRIPT_DIR}/utils/pull_image.sh"

USAGE="""
Usage:
  build.sh -i <image_name> -v <version> [-r <revision>] [-t <tag>]... [-p] [-m] [-n] [-e]
  build.sh -h

Options:
  -i <image_name>         The image name.
  -v <version>            The image version.
  -r <revision>           The value of the 'revision' ARG to pass in.
                          Defaults to 'dev'.
  -t <tag>                (Optional) tag to push.
                          Can be passed in multiple times to set multiple tags.
                          Defaults to '<version>-<revision>'.
  -p                      Will push the images to the registry.
  -m                      Builds multi-arch images.
  -n                      Build without cache
  -e                      Use existing base images where possible; turns off --pull.
                          Defaults to '--pull'ing the base image(s), except for dev containers.
  -h                      Display the help.

Summary:
  This script builds a (possibly multi-architecture) docker image.
  It can push the image to the registry if requested.
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
  NO_CACHE='false'
  MULTI_ARCH_FLAG='false'
  PUSH_FLAG='false'
  TAGS=()
  REVISION='dev'
  NO_PULL_USE_EXISTING='false'
  # cspell:ignore epmnh
  while getopts ':i:v:r:t:epmnh' flag; do
    case "${flag}" in
    i)
      IMAGE_NAME="${OPTARG}"
      ;;
    v)
      VERSION="${OPTARG}"
      ;;
    r)
      REVISION="${OPTARG}"
      ;;
    t)
      TAGS+=("${OPTARG}")
      ;;
    e)
      NO_PULL_USE_EXISTING='true'
      ;;
    p)
      PUSH_FLAG='true'
      ;;
    m)
      MULTI_ARCH_FLAG='true'
      ;;
    n)
      NO_CACHE='true'
      ;;
    h)
      help
      ;;
    \?)
      print_error_and_usage "Unknown option: ${OPTARG}"
      ;;
    :)
      print_error_and_usage "Invalid option: ${OPTARG} requires an argument"
      ;;
    esac
  done

  if [[ -z "${IMAGE_NAME:-}" ]]; then
    print_error_and_usage "Image name needs to be passed to be able to build"
  fi
  if [[ ! "${IMAGE_NAME}" =~ ^[-_.a-zA-Z0-9]+$ ]]; then
    print_error_and_usage "Invalid image name: '${IMAGE_NAME}'. It must be a string containing only a-z, A-Z, 0-9, period, underscores and minus."
  fi

  if [[ -z "${VERSION:-}" ]]; then
    print_error_and_usage "Version needs to be passed to be able to build"
  fi
  if [[ ! "${VERSION}" =~ ^[-_.a-zA-Z0-9]+$ ]]; then
    print_error_and_usage "Invalid version: '${VERSION}'. It must be a string containing only a-z, A-Z, 0-9, period, underscores and minus."
  fi

  if [[ ! "${REVISION}" =~ ^[-_.a-zA-Z0-9]+$ ]]; then
    print_error_and_usage "Invalid revision: '${REVISION}'. It must be a string containing only a-z, A-Z, 0-9, period, underscores and minus."
  fi

  if [[ "${#TAGS[@]}" -eq 0 ]]; then
    TAGS=("${VERSION}-${REVISION}")
  fi
  local tag
  for tag in "${TAGS[@]}"; do
    if [[ -z "${tag}" || ! "${tag}" =~ ^[-_.a-zA-Z0-9]+$ ]]; then
      print_error_and_usage "Invalid tag: '${tag}'. It must be a string containing only a-z, A-Z, 0-9, period, underscores and minus."
    fi
  done

  IMAGE_REPO="i2group"
  IMAGE_PREFIX="i2eng"
}

function validate() {
  if [[ ! -d "${SCRIPT_DIR}/images/${IMAGE_NAME}" ]]; then
    echo "Unknown image: ${IMAGE_NAME}" >&2
    exit 1
  fi

  if [[ ! -d "${SCRIPT_DIR}/images/${IMAGE_NAME}/${VERSION}" ]]; then
    echo "Unknown version: ${VERSION}" >&2
    exit 1
  fi
}

# Downloads the specified maven artifact into the current directory.
# $* = one or more maven artifacts to download
# Example: "com.my.company:MyPackageName:1.2.3:jar"
function download_maven_artifact() {
  local output_directory
  output_directory="$(pwd)"
  local artifact
  while [[ "$#" -gt 0 ]]; do
    artifact="$1"
    shift
    mvn dependency:copy \
      -Dartifact="${artifact}" \
      -DoutputDirectory="${output_directory}" \
      -Dmdep.stripVersion=true
  done
}

function copy_cert_tools_and_environment_scripts() {
  # Most images use these scripts
  local build_folder="$1"
  cp "${SCRIPT_DIR}/utils/environment.sh" "${build_folder}/environment.sh"
  cp "${SCRIPT_DIR}/utils/cert_tools.sh" "${build_folder}/cert_tools.sh"
}

function prepare_build_context() {
  local build_folder="${SCRIPT_DIR}/images/${IMAGE_NAME}/${VERSION}"

  # Images can have their own custom preparation steps
  # If they do, run those.
  if [[ -f "${build_folder}/build.sh" ]]; then
    local working_directory_before
    working_directory_before="$(pwd)"
    cd "${build_folder}"
    # shellcheck disable=SC1091
    . "./build.sh"
    cd "${working_directory_before}"
  else
    # If not, we copy environment.sh and cert_tools.sh
    copy_cert_tools_and_environment_scripts "${build_folder}"
  fi
}

# Shows what files are in the directory and their checksums
# $1 = directory to list. Defaults to current directory.
function log_directory_contents() {
  (
    # Cope with incompatibility between Linux and BSD
    if stat --version >/dev/null 2>&1; then
      # We have GNU stat, e.g. we are on WSL2 Ubuntu Linux
      function ldc_get_attributes() { stat -c '%A' "$@"; }
      function ldc_get_size() { stat -c '%s' "$@"; }
      function ldc_get_timestamp() { stat -c '%y' "$@" | sed -E 's/ /T/' | cut -d'.' -f1 | sed -E 's/ +0000$/Z/'; }
    else
      # We have BSD stat, e.g. we are on MacOS
      function ldc_get_attributes() { stat -f '%Sp' "$@"; }
      function ldc_get_size() { stat -f '%z' "$@"; }
      function ldc_get_timestamp() { stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%SZ' "$@"; }
    fi
    if command -v sha256sum >/dev/null 2>&1; then
      # We have sha256sum available, e.g. we are on Linux
      function ldc_get_sha() { sha256sum "$@" | cut -d' ' -f1; }
    else
      # We will try shasum instead, e.g. we are on MacOS
      function ldc_get_sha() { shasum -a 256 "$@" | cut -d' ' -f1; }
    fi
    cd "${1:-.}"
    find . -mindepth 1 -print0 | sort -z | while IFS= read -r -d '' f; do
      file_attributes=$(ldc_get_attributes "${f}")
      file_size=$(ldc_get_size "${f}")
      file_timestamp=$(ldc_get_timestamp "${f}")
      if [[ -f "${f}" ]]; then
        file_checksum=$(ldc_get_sha "${f}")
      else
        file_checksum="--------------------------------"
      fi
      if [[ -d "${f}" ]]; then
        f="${f}/"
      fi
      echo "${file_checksum} ${file_attributes} ${file_size} ${file_timestamp} ${f}" | awk '{printf "# %s %-10s %11s %19s %s\n", substr($1,1,16), $2, $3, $4, substr($5, 3)}'
    done
  )
}

function ensure_using_right_builder_and_driver() {
  local builder_name="$1"
  local builder_driver="$2"
  local existing_driver=""
  if docker buildx ls --format '{{.Name}}' | grep -Fqx "${builder_name}"; then
    existing_driver=$(docker buildx inspect "${builder_name}" 2>/dev/null | awk -F': ' '/^Driver:/ {print $2}' | sed -e 's,^[[:space:]]*,,g' -e 's,[[:space:]]*$,,g' | head -n1)
  fi
  if [[ -n "${existing_driver}" ]]; then
    if [[ "${existing_driver}" == "${builder_driver}" ]]; then
      echo "Using existing builder instance ${builder_name} with driver ${existing_driver}"
      docker buildx use "${builder_name}"
      return
    fi
    echo "Existing builder ${builder_name} has driver ${existing_driver}; we want ${builder_driver}. Recreating."
    docker buildx rm "${builder_name}"
  fi
  echo "Creating builder ${builder_name} with driver ${builder_driver}"
  docker buildx create --driver "${builder_driver}" --use --name "${builder_name}"
}

function build_image() {
  local is_dev_container="false"
  local build_folder="${SCRIPT_DIR}/images/${IMAGE_NAME}/${VERSION}"
  local full_image_name_without_colon_tag="${IMAGE_REPO}/${IMAGE_PREFIX}-${IMAGE_NAME}"
  local extra_args=()

  if [[ -d "${SCRIPT_DIR}/images/${IMAGE_NAME}/${VERSION}/.devcontainer" ]]; then
    is_dev_container="true"
  fi

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
  if [[ "${NO_CACHE}" == "true" ]]; then
    extra_args+=("--no-cache")
  fi

  print "Building ${IMAGE_NAME} from:"
  log_directory_contents "${build_folder}"

  # Decide builder name and driver.
  # CI environments (GitHub Actions, Jenkins, GitLab CI, etc.) set CI=true and
  # need the docker-container driver for full feature support (multi-arch, sbom, attestation).
  # Local builds use the plain docker driver, which shares the host daemon's image
  # store so locally tagged base images are visible to the build.
  # The -e flag (NO_PULL_USE_EXISTING) also forces local docker driver so that
  # existing local base images are reused rather than pulled.
  local builder_driver
  local builder_name
  if [[ "${CI:-false}" == "true" && "${NO_PULL_USE_EXISTING}" != "true" ]]; then
    builder_driver="docker-container"
    builder_name="analyze-docker-${REVISION}"
  else
    builder_driver="docker"
    builder_name="default"
  fi
  ensure_using_right_builder_and_driver "${builder_name}" "${builder_driver}"

  # Lastly, we do the docker build. VSC devcontainers are a special-case though.
  if [[ "${is_dev_container}" == "true" ]]; then
    # Use devcontainer CLI instead to build image.
    # This uses buildx internally but supports fewer, and different, arguments.
    local tag
    for tag in "${TAGS[@]}"; do
      extra_args+=( "--image-name" "${full_image_name_without_colon_tag}:${tag}" )
    done
    # devcontainer build doesn't support --pull or --no-cache
    export DEV_CONTAINER_VERSION="${VERSION}"
    export REVISION
    local cmd=( \
      devcontainer build \
      "${extra_args[@]}" \
      "${build_folder}" \
    )
    print "Building ${IMAGE_NAME} using command ${cmd[*]}"
    "${cmd[@]}"
  else
    local tag
    for tag in "${TAGS[@]}"; do
      extra_args+=( "--tag" "${full_image_name_without_colon_tag}:${tag}" )
    done
    if [[ "${CI:-false}" == "true" && "${NO_PULL_USE_EXISTING}" == "false" ]]; then
      extra_args+=("--pull=true")
    fi
    if [[ "${NO_CACHE}" == "false" ]]; then
      local cache_folder="${SCRIPT_DIR}/.cache/docker/${IMAGE_NAME}/${VERSION}"
      rm -rf "${cache_folder}-new"
      extra_args+=(
        --cache-from "type=local,src=${cache_folder}"
        --cache-to "type=local,dest=${cache_folder}-new,mode=max"
      )
    else
      local cache_folder=""
    fi
    # --sbom and --attest require an image registry destination (push or multi-arch manifest)
    # and are incompatible with --load (local builds). Only apply them when pushing or
    # building multi-arch images.
    if [[ "${PUSH_FLAG}" == "true" || "${MULTI_ARCH_FLAG}" == "true" ]]; then
      extra_args+=("--sbom=true")
      extra_args+=("--attest" "type=provenance,mode=max")
    fi
    local cmd=( \
      docker buildx build \
      "${extra_args[@]}" \
      --build-arg revision="${REVISION}" \
      --build-arg version="${VERSION}" \
      "${build_folder}" \
    )
    print "Building ${IMAGE_NAME} using command ${cmd[*]}"
    "${cmd[@]}"
    if [[ -n "${cache_folder}" && -e "${cache_folder}-new" ]]; then
      rm -rf "${cache_folder}"
      mv -f "${cache_folder}-new" "${cache_folder}"
    fi
  fi
  echo "Success"
}

# For local dev builds the base image tag won't exist in the registry (e.g. :ubi-jdk21-main-dev).
# This function finds the latest published revision for each such base image, pulls it, and
# re-tags it locally with the -dev suffix so the build can proceed without touching the Dockerfile.
function ensure_base_images_available() {
  local build_folder="${SCRIPT_DIR}/images/${IMAGE_NAME}/${VERSION}"
  local dockerfile="${build_folder}/Dockerfile"

  if [[ ! -f "${dockerfile}" ]]; then
    # Devcontainer images keep their Dockerfile inside .devcontainer/
    dockerfile="${build_folder}/.devcontainer/Dockerfile"
  fi

  if [[ ! -f "${dockerfile}" ]]; then
    echo "ERROR: No Dockerfile found for ${IMAGE_NAME}/${VERSION} (checked ${build_folder}/Dockerfile and ${build_folder}/.devcontainer/Dockerfile)" >&2
    return 1
  fi

  # Collect FROM lines that reference ${revision}.
  # grep exits 1 when there are no matches, which is not an error here.
  local dockerfile_from_lines
  dockerfile_from_lines="$(grep -E '^FROM [^ ].*\$\{revision\}' "${dockerfile}")" || true

  if [[ -z "${dockerfile_from_lines}" ]]; then
    return
  fi

  # Pass 1: parse FROM lines into an array of image references
  local -a images_we_need=()
  local _from image_ref _remainder
  while read -r _from image_ref _remainder; do
    images_we_need+=( "${image_ref}" )
  done <<< "${dockerfile_from_lines}"

  # Pass 2: pull and tag each image
  for image_ref in "${images_we_need[@]}"; do
    # Build the local tag we need by substituting ${revision} -> dev
    local local_tag="${image_ref/\$\{revision\}/dev}"

    # If already present locally, nothing to do
    if docker image inspect "${local_tag}" >/dev/null 2>&1; then
      echo "Base image ${local_tag} already available locally, skipping pull."
      continue
    fi

    # The published (non-dev) tag is the image reference with -${revision} stripped.
    # For example: i2group/i2eng-foo:bar-${revision} -> i2group/i2eng-foo:bar
    local base_tag="${image_ref/-\$\{revision\}/}"

    echo "Pulling ${base_tag} ..."
    pull_image_for_all_architectures "${base_tag}" "${MULTI_ARCH_FLAG}"
    echo "Tagging ${base_tag} => ${local_tag} ..."
    docker tag "${base_tag}" "${local_tag}"
  done
}

function main() {
  parse_arguments "$@"
  validate
  prepare_build_context
  if [[ "${REVISION}" == "dev" ]]; then
    ensure_base_images_available
  fi
  build_image
}

main "$@"
