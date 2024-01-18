#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -euo pipefail

USAGE="""
Usage:
  test.sh <full_image_name>
  test.sh -h

Options:
  -h Display the help.
"""

function print() {
  echo ""
  echo "#----------------------------------------------------------------------"
  echo "# $1"
  echo "#----------------------------------------------------------------------"
}

function usage() {
  echo -e "${USAGE}" >&2
  exit 1
}

function print_error_and_exit() {
  print_error "$1"
  exit 1
}

function print_error() {
  printf "\n\e[31mERROR: %s\n" "$1" >&2
  printf "\e[0m" >&2
}

function print_error_and_usage() {
  print_error "$1"
  usage
}

function help() {
  echo -e "${USAGE}"
  exit 0
}

function parse_arguments() {
  while getopts ":h" flag; do
    case "${flag}" in
    h)
      help
      ;;
    \?)
      usage
      ;;
    :)
      print_error_and_usage "Invalid option: ${OPTARG} requires an argument"
      ;;
    esac
  done

  IMAGE="$1"
  if [[ -z "${IMAGE:-""}" ]]; then
    print_error_and_usage "Full image name needs to be passed to be able to test"
  fi
}

function test_image() {
  local image_name="$1"
  local test_command="$2"
  local default_args=()
  local -n extra_args="${3:-default_args}"

  if docker run "${extra_args[@]}" "${image_name}" bash -c "set -e; ${test_command}"; then
    echo "  PASSED"
  else
    local exit_code="$?"
    echo "ERROR: Tests failed, exit code ${exit_code}" >&2
    return "${exit_code}"
  fi
}

function main() {
  parse_arguments "$@"

  local test_cmd server_path docker_args

  print "Testing ${IMAGE}"
  case "${IMAGE}" in
  "i2group/i2eng-analyze-containers-dev"*)
    test_cmd="java -version; \
      javac -version; \
      mvn --version; \
      curl --version; \
      sed --version; \
      uuidgen --version; \
      xmlstarlet --version; \
      jq --version; \
      shasum --version; \
      diff --version; \
      bc --version;"
    if [[ "${IMAGE}" != "i2group/i2eng-analyze-containers-dev:1.0"* ]]; then
      test_cmd+="check-jsonschema --version; \
      gh version; \
      python --version; \
      jf --version; \
      npm -v; \
      node -v;"
    fi
    test_image "${IMAGE}" "${test_cmd}"
    ;;
  "i2group/i2eng-solr"*)
    test_image "${IMAGE}" "openssl version; \
    solr -e cloud -noprompt;"
    ;;
  "i2group/i2eng-zookeeper"*)
    docker_args=("-e" "ZOO_CLIENT_PORT=2181")
    test_image "${IMAGE}" "openssl version; \
    zkServer.sh version;" docker_args
    ;;
  "i2group/i2eng-liberty"*)
    if [[ "${IMAGE}" == "i2group/i2eng-liberty:22-"* ]]; then
      server_path="/opt/ibm/wlp"
    else
      server_path="/opt/ol/wlp"
    fi
    test_image "${IMAGE}" "openssl version; \
      jq --version; \
     ${server_path}/bin/server version;
     [[ -f '${server_path}/usr/servers/defaultServer/configDropins/defaults/keystore.xml' ]] \
      && echo 'ERROR: Default keystore exists' && exit 1 || echo 'Default keystore not in image';"
    ;;
  "i2group/i2eng-postgres"*)
    docker_args=("--entrypoint=")
    test_image "${IMAGE}" "postgres --version; \
      cat /usr/share/postgresql/postgresql.conf.sample | grep 'pg_cron'" docker_args
    ;;
  "i2group/i2eng-prometheus"*)
    docker_args=("-e" "PROMETHEUS_USERNAME=prom" "-e" "PROMETHEUS_PASSWORD=prom" "--entrypoint=")
    test_image "${IMAGE}" "prometheus -h;" docker_args
    ;;
  "i2group/i2eng-grafana"*)
    docker_args=("--entrypoint=")
    test_image "${IMAGE}" "grafana -h;" docker_args
    ;;
  "i2group/i2eng-sqlserver"*)
    docker_args=("--entrypoint=")
    test_image "${IMAGE}" "/opt/mssql-tools/bin/sqlcmd -?;" docker_args
    ;;
  *)
    print_error_and_exit "No tests for image: ${IMAGE}"
    ;;
  esac
}

main "$@"
