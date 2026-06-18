# shellcheck shell=bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

# Pulls a Docker image for one or more architectures.
# $1 = image name (required)
# $2 = 'true' to pull for all supported architectures (linux/amd64 + linux/arm64).
#      If omitted, falls back to checking the CI environment variable.
function pull_image_for_all_architectures() {
  local -r image="${1:?ERROR: Internal error - arg#1 (image name) is missing.}"
  # Explicit multi_arch arg takes precedence; otherwise use CI env var as signal.
  local multi_arch="${2:-}"
  if [[ -z "${multi_arch}" ]]; then
    multi_arch="${CI:+true}"
  fi

  local platforms=( '' )
  if [[ "${image}" == */mssql/* || "${image}" == */db2* ]]; then
    # SQL Server & Db2 only supports amd64
    platforms=( linux/amd64 )
  elif [[ "${multi_arch}" == "true" ]]; then
    platforms=( linux/amd64 linux/arm64 )
  fi
  local success=true
  local platform_or_empty
  for platform_or_empty in "${platforms[@]}"; do
    local -a docker_cmd=( docker pull )
    if [[ -n "${platform_or_empty}" ]]; then
      docker_cmd+=( "--platform=${platform_or_empty}" )
    fi
    docker_cmd+=( "${image}" )
    if ! (
      set -x
      "${docker_cmd[@]}"
    ); then
      success=false # but keep trying other architectures
    fi
  done
  [[ "${success}" == true ]] # return 0 if success=true
}

# Function to pull a single image with retries
# $1 = image name
# $2 = max tries
# $3 = seconds between retries
function pull_image_with_retries() {
  local -r image="${1:?ERROR: Internal error - arg#1 (image name) is missing.}"
  local -r max_tries="${2:?ERROR: Internal error - arg#2 (max tries) is missing.}"
  local -r seconds_between_tries="${3:?ERROR: Internal error - arg#3 (seconds between tries) is missing.}"
  local attempt=0
  local exit_code=''
  while ((attempt < max_tries)); do
    echo "Attempting to pull image: ${image} (Attempt $((attempt + 1)) of ${max_tries})"
    if pull_image_for_all_architectures "${image}"; then
      echo "Pulled docker image: ${image}"
      return 0
    else
      exit_code=$?
    fi
    attempt=$((attempt+1))
    if ((attempt < max_tries)); then
      echo "WARNING: Failed to pull docker image: ${image}. Retrying in ${seconds_between_tries} seconds..."
      sleep "${seconds_between_tries}"
    fi
  done
  echo "Error: Failed to pull docker image: ${image}, despite multiple (${max_tries}) attempts, exit code ${exit_code}." >&2
  return $exit_code
}
