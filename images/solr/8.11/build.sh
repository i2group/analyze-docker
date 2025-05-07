# shellcheck shell=bash
# Called by top-level build.sh file to prepare all files prior to building the Docker image
# All functions in the top-level build.sh file are available for use.

# Don't call copy_cert_tools_and_environment_scripts here
# because Solr 8.11 version has a special path
cp "${SCRIPT_DIR}/utils/environment.sh" "scripts/environment.sh"
cp "${SCRIPT_DIR}/utils/cert_tools.sh" "scripts/cert_tools.sh"
