# shellcheck shell=bash
# Called by top-level test.sh file to test the Docker image
# All functions in the top-level test.sh file are available for use.
# $IMAGE is the name of the Docker image under test, including the tag
# $IMAGE_NAME is the name of the folder in the images/ directory for the image under test
# $VERSION is the name of the folder in the IMAGE_NAME folder for the image under test

function test_image_runs_as_non_root_user() {
  local expected_user_id="$1"
  # Note: Container Designer is a funny case because it is a Node.js app, but it is not a connector.
  # It's also odd in that it starts itself as root before switching to a non-root user.
  # This switch breaks our "fd 3" trick for getting debug out of a container command without breaking it,
  # so we have to do the docker run ourselves.
  # First we verify that the image is running as the expected user, which is 1001 for all connector images.
  local image_user_id
  # shellcheck disable=SC2016 # we need id -u to run in the container, not here
  image_user_id="$(set -x; docker run --rm "${IMAGE}" bash -c 'id -u')"
  if [[ "${image_user_id}" != "${expected_user_id}" ]]; then
    echo "ERROR: Expected image to be running as user ID ${expected_user_id}, but got ${image_user_id}" >&2
    return 1
  fi
}

function test_node_engine_compatibility() {
  (
    set -x;
    # connector-designer is not shrinkwrapped or package-locked, so we can't do npm ci.
    docker run --rm "${IMAGE}" bash -c '\
      npm_config_engine_strict=true npm install --ignore-scripts --dry-run; \
      '
  )
}

function run_connector_designer_image_tests() {
  local return_code=0
  test_image_runs_as_non_root_user 1001 || return_code="$?"
  test_node_engine_compatibility || return_code="$?"
  return "${return_code}"
}

run_connector_designer_image_tests
