# shellcheck shell=bash
# Called by top-level test.sh file to test the Docker image
# All functions in the top-level test.sh file are available for use.
# $IMAGE is the name of the Docker image under test, including the tag
# $IMAGE_NAME is the name of the folder in the images/ directory for the image under test
# $VERSION is the name of the folder in the IMAGE_NAME folder for the image under test

function connector_designer_has_same_node_as_us() {
  # Docker has a flaw whereby, if the docker build pulled a multi-arch image (which ours would've done),
  # the architecture of the image it caches internally may not match the architecture of the host machine,
  # meaning later "docker run" commands might falsely believe that the only available image is for
  # the wrong architecture.
  # So we need to demand that the connector-designer image be run natively.
  local native_platform
  native_platform=$(docker info --format '{{.OSType}}/{{.Architecture}}')

  local our_node_version_text
  our_node_version_text="$(set -x; docker run --rm --platform "${native_platform}" "${IMAGE}" bash -c 'node --version')"
  local our_node_version
  our_node_version="$(cut -d v -f2 <<< "${our_node_version_text}")"
  echo "INFO: Our image has NodeJS version: ${our_node_version}"
  local our_node_major_version
  our_node_major_version="$( cut -d. -f1 <<< "${our_node_version}")"
  echo "INFO: Our image has NodeJS major version: ${our_node_major_version}"
  if ! [[ "${our_node_major_version}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Unable to determine our image's NodeJS major version. Image reported: '${our_node_version_text}', node version='${our_node_version}', major version='${our_node_major_version}'" >&2
    return 1
  fi

  local connector_designer_image_name="i2group/i2eng-connector-designer:${VERSION}-${REVISION}"
  local connector_designer_node_version_text
  connector_designer_node_version_text="$(set -x; docker run --rm --platform "${native_platform}" "${connector_designer_image_name}" bash -c 'node --version')"
  local connector_designer_node_version
  connector_designer_node_version="$(cut -d v -f2 <<< "${connector_designer_node_version_text}")"
  echo "INFO: Connector Designer image has NodeJS version: ${connector_designer_node_version}"
  local connector_designer_node_major_version
  connector_designer_node_major_version="$( cut -d. -f1 <<< "${connector_designer_node_version}")"
  echo "INFO: Connector Designer image has NodeJS major version: ${connector_designer_node_major_version}"
  if ! [[ "${connector_designer_node_major_version}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Unable to determine Connector Designer image's NodeJS major version. Image reported: '${connector_designer_node_version_text}', node version='${connector_designer_node_version}', major version='${connector_designer_node_major_version}'" >&2
    return 1
  fi

  if [[ "${our_node_major_version}" != "${connector_designer_node_major_version}" ]]; then
    echo "ERROR: NodeJS major version mismatch between ${connector_designer_image_name} (${connector_designer_node_major_version}) and ${IMAGE} (${our_node_major_version})" >&2
    return 1
  fi
  echo "INFO: NodeJS major version match between ${connector_designer_image_name} and ${IMAGE} (${our_node_major_version})"
  return 0
}

function run_connector_designer_base_image_tests() {
  local return_code=0
  # We expect stuff to be installed
  test_docker_image_using_bash_command '\
    openssl version; \
    node --version; \
    npm --version; \
    ' \
    || return_code="$?"
  # We expect our version of NodeJS to be consistent with the NodeJS in connector-designer itself.
  connector_designer_has_same_node_as_us || return_code="$?"
  return "${return_code}"
}

run_connector_designer_base_image_tests
