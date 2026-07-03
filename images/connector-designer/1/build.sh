# shellcheck shell=bash
# Called by top-level build.sh file to prepare all files prior to building the Docker image
# All functions in the top-level build.sh file are available for use.

# Copy and unpack the connector designer application into the app folder.
"${SCRIPT_DIR}/internal/scripts/package-shared-connectors/download-and-extract-connectors" -i "${IMAGE_NAME}"

# Copy entry-point scripts
copy_cert_tools_and_environment_scripts "$(pwd)"
cp -pf "${SCRIPT_DIR}/images/analyze-containers-dev/1.2/.devcontainer/library-scripts/docker-redhat.sh" "$(pwd)/docker-redhat.sh"
