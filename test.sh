#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
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

  if docker run --rm "${extra_args[@]}" "${image_name}" bash -c "set -e; ${test_command}"; then
    echo "  PASSED"
  else
    local exit_code="$?"
    echo "ERROR: Tests failed, exit code ${exit_code}" >&2
    return "${exit_code}"
  fi
}

function sql_client_run_container() {
  local docker_network_name="$1"
  shift
  local image_name="$1"
  shift
  local sql_db_scripts_host_path="$1"
  shift
  local sql_db_scripts_container_path="$1"
  shift
  local server_network_alias="$1"
  shift
  local sa_password="$1"
  shift
  local sql_db_script="$1"
  shift
  local test_command="${1:-"/opt/mssql-tools/bin/sqlcmd -S ${server_network_alias} -U sa -P ${sa_password} -N -C -i '${sql_db_script}'"}"

  local client_container_name="sql-client"

  # Create and run SQL client container
  docker run \
    "--rm" \
    "--platform=linux/amd64" \
    "--network=${docker_network_name}" \
    "--name=${client_container_name}" \
    -v "${sql_db_scripts_host_path}:${sql_db_scripts_container_path}" \
    "${image_name}" \
    bash -c "set -e; ${test_command}"
}

function sql_server_run_container() {
  local server_network_alias="$1"
  shift
  local docker_network_name="$1"
  shift
  local sa_password="$1"
  shift
  local image_name="$1"
  shift
  server_container_name="$1"

  # Create and run SQL Server container
  docker run \
    "-d" \
    "--rm" \
    "--platform=linux/amd64" \
    "--network-alias=${server_network_alias}" \
    "--name=${server_container_name}" \
    "--network=${docker_network_name}" \
    "--env=ACCEPT_EULA=Y" \
    "--env=SA_PASSWORD=${sa_password}" \
    "--env=MSSQL_PID=Developer" \
    "--env=MSSQL_AGENT_ENABLED=true" \
    "${image_name}"
}

function test_sql_server() {
  local image_name="$1"

  local \
    retry_counter=30 \
    sleep_period="0.5s" \
    docker_network_name="eia" \
    sa_password="Password1234" \
    sql_db_scripts_container_path="/tmp/database-scripts/static" \
    server_network_alias="sqlserver.eia" \
    sql_select_1_success='(1 rows affected)' \
    sql_tcp_provider_error='TCP Provider: Error code 0x68' \
    server_container_name="sql-server" \
    sql_db_scripts_host_path \
    sql_db_script_container_filepath \
    sql_db_script_file \
    operational_output \
    connectivity_output \
    sql_db_script_filepath \
    test_command

  # Construct host path to SQL scripts
  sql_db_scripts_host_path="$(pwd)/internal/test/database-scripts/static"

  # Construct container path to operational SQL script
  sql_db_script_filepath="${sql_db_scripts_container_path}/0000-check-operational.sql"

  # Create a network using the default bridge for the SQL Server and Client containers
  docker network create "${docker_network_name}"

  # Define test command to execute for SQL Client container
  test_command="/opt/mssql-tools/bin/sqlcmd -?"

  # Create and run client container to verify SQL tools are installed
  sql_client_run_container "${docker_network_name}" "${image_name}" "${sql_db_scripts_host_path}" "${sql_db_scripts_container_path}" "${server_network_alias}" "${sa_password}" "${sql_db_script_filepath}" "${test_command}"

  # Create and run server container
  sql_server_run_container "${server_network_alias}" "${docker_network_name}" "${sa_password}" "${image_name}" "${server_container_name}"

  # Wait for SQL Server to be operational
  echo "INFO: Waiting for SQL Server to be operational..."
  while (( retry_counter > 0 )); do

    operational_output=$(sql_client_run_container "${docker_network_name}" "${image_name}" "${sql_db_scripts_host_path}" "${sql_db_scripts_container_path}" "${server_network_alias}" "${sa_password}" "${sql_db_script_filepath}" || true)
    if grep -q "${sql_select_1_success}" <<< "${operational_output}"; then
      echo "INFO: SQL Server is operational, continuing with connectivity test..."
      break
    else
      echo "INFO: Waiting for SQL Server to respond... Retries left: $((retry_counter - 1))"
      ((retry_counter--))
      sleep "${sleep_period}"
    fi
  done

  if (( retry_counter == 0 )); then
    echo "ERROR: Tests failed, SQL Server did not become operational after 30 attempts." >&2
    return 1
  fi

  # Create an array of .sql files
  mapfile -t sql_db_scripts_host_filepath_host_array < <(find "${sql_db_scripts_host_path}" -name "*.sql" | sort)

  for sql_db_scripts_host_filepath in "${sql_db_scripts_host_filepath_host_array[@]}"; do
    # Get filename from filepath
    sql_db_script_file=$(basename "${sql_db_scripts_host_filepath}")
    # Construct container path to connectivity SQL script
    sql_db_script_filepath="${sql_db_scripts_container_path}/${sql_db_script_file}"
    # Run SQL Client and try to connect to SQL Server
    connectivity_output=$(sql_client_run_container "${docker_network_name}" "${image_name}" "${sql_db_scripts_host_path}" "${sql_db_scripts_container_path}" "${server_network_alias}" "${sa_password}" "${sql_db_script_filepath}" || true)
    if grep -qF "${sql_tcp_provider_error}" <<< "${connectivity_output}"; then
      echo "ERROR: Test failed, string '${sql_tcp_provider_error}' found in output for SQL script '${sql_db_script_filepath}'"
      docker rm -f "${server_container_name}"
      return 1
    fi
    echo "INFO: String '${sql_tcp_provider_error}' NOT found in output for SQL script '${sql_db_script_filepath}', continuing..."
  done
  docker rm -f "${server_container_name}"
  echo "  PASSED"
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
    test_image "${IMAGE}" "prometheus -h; \
    envsubst --version;" docker_args
    ;;
  "i2group/i2eng-grafana"*)
    docker_args=("--entrypoint=")
    test_image "${IMAGE}" "grafana -h;" docker_args
    ;;
  "i2group/i2eng-sqlserver"*)
    docker_args=("--entrypoint=" "--platform=linux/amd64")
    test_sql_server "${IMAGE}"
    ;;
  "i2group/i2eng-db2"*)
    docker_args=("--entrypoint=" "--platform=linux/amd64")
    test_image "${IMAGE}" "test -f /opt/ibm/db2/V11.5/bin/db2;" docker_args
    ;;
  "i2group/i2eng-analyze-containers-base"*)
    test_image "${IMAGE}" "openssl version; \
    tar --help; \
    xmlstarlet --version; \
    gosu nobody true; \
    jq --version;"
    ;;
  "i2group/i2eng-textchart-data-access"*)
    docker_args=("-e" "LICENSE=dev"
      "-e" "ADMIN_USER=admin"
      "-e" "ADMIN_PASSWORD=12345"
      "-e" "USER_ID=$(id -u)"
      "-e" "GROUP_ID=$(id -g)"
      "-e" "DB_DIALECT=sqlserver"
    )
    test_image "${IMAGE}" "java -version; \
      xmlstarlet --version;" docker_args
    ;;
  "i2group/i2eng-textchart-"*)
    docker_args=("-e" "LICENSE=dev"
      "-e" "ADMIN_USER=admin"
      "-e" "ADMIN_PASSWORD=12345"
      "-e" "USER_ID=$(id -u)"
      "-e" "GROUP_ID=$(id -g)"
      "-e" "DB_DIALECT=sqlserver"
    )
    test_image "${IMAGE}" "java -version; \
      jq --version;" docker_args
    ;;
  "i2group/i2eng-analyze-containers-connectors-base"*)
    test_image "${IMAGE}" "openssl version; \
    node --version; \
    npm --version;" docker_args
    ;;
  "i2group/i2eng-connector-designer-connectors-base"*)
    test_image "${IMAGE}" "openssl version; \
    node --version; \
    npm --version;" docker_args
    ;;
  "i2group/i2eng-connector-"*)
    test_image "${IMAGE}" "[[ $(id -u) == 1001 ]] && exit 0 || exit 1" docker_args
    ;;
  "i2group/i2eng-haproxy"*)
    test_image "${IMAGE}" "sudo -V" docker_args
    ;;
  *)
    print_error_and_exit "No tests for image: ${IMAGE}"
    ;;
  esac
}

main "$@"
