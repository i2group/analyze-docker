# shellcheck shell=bash

# Checks that the image has Node.js installed and that its version matches the expected version.
# $1 = expected Node.js version. Can be just a major version (e.g. 18), or first two components (e.g. 18.16), or a full version (e.g. 18.16.0).
function test_node_version_matches() {
  local expected_node_version="$1"
  local expected_node_version_regex
  expected_node_version_regex="$(sed -E 's/[][(){}.^$*+?|\\]/\\&/g' <<< "${expected_node_version}")"
  local installed_node_version
  if ! installed_node_version="$(docker run --rm "${IMAGE}" bash -c 'node --version' | tr -d '\r')"; then
    echo "ERROR: Failed to run 'node --version' in image '${IMAGE}'; is Node.js installed?" >&2
    return 1
  fi
  # Need to ensure that the installed version starts with the expected version, and that the next character is either a dot or the end of the string.
  if [[ ! "${installed_node_version}" =~ ^v${expected_node_version_regex}(\.|$) ]]; then
    echo "ERROR: Installed Node.js version '${installed_node_version}' does not match expected version '${expected_node_version}'" >&2
    return 1
  fi
  echo "INFO: Installed Node.js version '${installed_node_version}' matches expected version '${expected_node_version}'"
}

# Checks that the image has Node.js installed and that its version is not end-of-life.
function test_node_version_is_not_eol() {
  local installed_node_version
  if ! installed_node_version="$(docker run --rm "${IMAGE}" bash -c 'node --version' | tr -d '\r')"; then
    echo "ERROR: Failed to run 'node --version' in image '${IMAGE}'; is Node.js installed?" >&2
    return 1
  fi
  local installed_node_major
  installed_node_major="$(sed -E 's/^v([0-9]+).*/\1/' <<< "${installed_node_version}")"
  if [[ ! "${installed_node_major}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Could not parse Node.js major version from '${installed_node_version}'. Was expecting v<number>" >&2
    return 1
  fi
  local node_release_schedule_url="https://raw.githubusercontent.com/nodejs/Release/main/schedule.json"
  local node_release_schedule_json=''
  local attempt
  for attempt in {1..5}; do
    if node_release_schedule_json="$(curl --fail --silent --show-error --location "${node_release_schedule_url}")"; then
      break
    fi
    if [[ "${attempt}" == "5" ]]; then
      echo "ERROR: Failed to fetch Node.js release schedule from ${node_release_schedule_url} after ${attempt} attempts" >&2
      return 1
    fi
    echo "WARN: Failed to fetch Node.js release schedule from ${node_release_schedule_url} on attempt ${attempt}; retrying in 1 second" >&2
    sleep 1
  done
  local installed_node_cycle="v${installed_node_major}"
  local node_eol_date
  node_eol_date="$(jq -r --arg node_cycle "${installed_node_cycle}" '.[$node_cycle].end // empty' <<< "${node_release_schedule_json}")"
  if [[ -z "${node_eol_date}" ]]; then
    echo "ERROR: No end-of-life date found in the Node.js release schedule for ${installed_node_cycle}" >&2
    return 1
  fi
  local current_date
  current_date="$(date -u +%F)"
  local current_date_epoch
  current_date_epoch="$(date -u -d "${current_date}" +%s)"
  local node_eol_date_epoch
  node_eol_date_epoch="$(date -u -d "${node_eol_date}" +%s)"
  if (( current_date_epoch > node_eol_date_epoch )); then
    echo "ERROR: Installed Node.js major version '${installed_node_cycle}' reached end of life on ${node_eol_date}" >&2
    echo "ERROR: This image's version of Node ('${installed_node_version}') is obsolete and should either be upgraded or replaced." >&2
    return 1
  fi
  echo "INFO: Installed Node.js major version '${installed_node_cycle}' is still supported until ${node_eol_date}"
}

function run_ac_connector_base_image_tests() {
  local return_code=0
  # We expect npm to be installed
  test_docker_image_using_bash_command 'npm --version' || return_code="$?"
  # We expect the major node version to match the version of the image.
  test_node_version_matches "${VERSION}" || return_code="$?"
  # We expect node to be installed and not end of life
  test_node_version_is_not_eol || return_code="$?"
  return "${return_code}"
}
