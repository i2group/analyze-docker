# shellcheck shell=bash
# Called by top-level test.sh file to test the Docker image
# All functions in the top-level test.sh file are available for use.
# $IMAGE is the name of the Docker image under test, including the tag
# $IMAGE_NAME is the name of the folder in the images/ directory for the image under test
# $VERSION is the name of the folder in the IMAGE_NAME folder for the image under test

function run_connector_image_tests() {
  local return_code=0
  test_docker_image_using_bash_command 'npm --version' || return_code="$?"
  # We expect node to be installed
  test_docker_image_using_bash_command 'node --version' || return_code="$?"
  return "${return_code}"
}

run_connector_image_tests
