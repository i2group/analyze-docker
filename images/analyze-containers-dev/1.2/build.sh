# shellcheck shell=bash
# Called by top-level build.sh file to prepare all files prior to building the Docker image
# All functions in the top-level build.sh file are available for use.

function package_semver_util() {
  local build_folder="$1"

  if [[ "${NO_CACHE}" == "true" ]]; then
    if ls "${build_folder}/semver_util-"*.tgz 1>/dev/null 2>&1; then
      rm -f "${build_folder}/semver_util-"*.tgz
    fi
  elif ls "${build_folder}/semver_util-"*.tgz 1>/dev/null 2>&1; then
    return
  fi

  pushd "${SCRIPT_DIR}/internal/scripts/package-shared-connectors/semver_util"
  npm install
  npm pack --pack-destination "${build_folder}"
  popd
}

package_semver_util "$(pwd)/.devcontainer"
# This container doesn't use the environment.sh util so it
# doesn't call copy_cert_tools_and_environment_scripts
