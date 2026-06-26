# shellcheck shell=bash
# Called by top-level test.sh file to test the Docker image
# All functions in the top-level test.sh file are available for use.
# $IMAGE is the name of the Docker image under test, including the tag
# $IMAGE_NAME is the name of the folder in the images/ directory for the image under test
# $VERSION is the name of the folder in the IMAGE_NAME folder for the image under test

. "${SCRIPT_DIR}/internal/test/connectors.sh"

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

run_ac_connector_base_image_tests
