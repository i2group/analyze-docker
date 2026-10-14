# shellcheck shell=bash
# Called by top-level test.sh file to test the Docker image
# All functions in the top-level test.sh file are available for use.
# $IMAGE is the name of the Docker image under test, including the tag
# $IMAGE_NAME is the name of the folder in the images/ directory for the image under test
# $VERSION is the name of the folder in the IMAGE_NAME folder for the image under test
#
# Runs the same cloud example as the shared images/solr/test.sh, plus a check that the default
# command works without 'docker run --init', which needs the tini this image installs.

# Starts the image with its default command, without 'docker run --init', and checks that Solr
# comes up running under tini.
function test_default_command_starts_solr_under_tini() {
  local container_name="solr-test-default-command-$$"
  local return_code=0
  (
    set -x
    docker run \
      --detach \
      --name "${container_name}" \
      "${IMAGE}"
  ) || return_code="$?"
  if [[ "${return_code}" -eq 0 ]]; then
    (
      set -x
      docker exec "${container_name}" wait-for-solr.sh --max-attempts 60 --wait-seconds 2
    ) || return_code="$?"
  fi
  if [[ "${return_code}" -eq 0 ]]; then
    local pid_1_command
    pid_1_command="$(docker exec "${container_name}" cat /proc/1/comm)" || return_code="$?"
    if [[ "${return_code}" -eq 0 && "${pid_1_command}" != "tini" ]]; then
      echo "ERROR: Expected PID 1 to be tini but it was '${pid_1_command}'" >&2
      return_code=1
    fi
  fi
  if [[ "${return_code}" -ne 0 ]]; then
    echo "ERROR: Default command failed to start Solr. Container logs:" >&2
    docker logs "${container_name}" >&2 || true
  fi
  docker rm --force "${container_name}" >/dev/null || true
  return "${return_code}"
}

# This file is sourced in a context where 'set -e' does not apply,
# so each test's exit code is collected explicitly.
solr_tests_return_code=0
test_docker_image_using_bash_command '\
  openssl version; \
  solr -e cloud -noprompt; \
  ' || solr_tests_return_code="$?"
test_default_command_starts_solr_under_tini || solr_tests_return_code="$?"
return "${solr_tests_return_code}"
