# shellcheck shell=bash
# Called by top-level test.sh file to test the Docker image
# All functions in the top-level test.sh file are available for use.
# $IMAGE is the name of the Docker image under test, including the tag
# $IMAGE_NAME is the name of the folder in the images/ directory for the image under test
# $VERSION is the name of the folder in the IMAGE_NAME folder for the image under test

SERVER_CONTAINER_NAME="sql-server"
DOCKER_NETWORK_NAME="eia"

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
  local server_container_name="$1"

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
    sa_password="Password1234" \
    sql_db_scripts_container_path="/tmp/database-scripts/static" \
    server_network_alias="sqlserver.${DOCKER_NETWORK_NAME}" \
    sql_select_1_success='(1 rows affected)' \
    sql_tcp_provider_error='TCP Provider: Error code 0x68' \
    

  # Construct host path to SQL scripts
  local sql_db_scripts_host_path
  sql_db_scripts_host_path="$(pwd)/internal/test/database-scripts/static"

  # Construct container path to operational SQL script
  local sql_db_script_filepath
  sql_db_script_filepath="${sql_db_scripts_container_path}/0000-check-operational.sql"

  # Ensure the network exists for the SQL Server and Client containers
  if ! docker network inspect "${DOCKER_NETWORK_NAME}" > /dev/null 2>&1; then
    docker network create "${DOCKER_NETWORK_NAME}"
  fi

  # Define test command to execute for SQL Client container
  local test_command
  test_command="/opt/mssql-tools/bin/sqlcmd -?"

  # Create and run client container to verify SQL tools are installed
  sql_client_run_container "${DOCKER_NETWORK_NAME}" "${image_name}" "${sql_db_scripts_host_path}" "${sql_db_scripts_container_path}" "${server_network_alias}" "${sa_password}" "${sql_db_script_filepath}" "${test_command}"

  # Create and run server container
  sql_server_run_container "${server_network_alias}" "${DOCKER_NETWORK_NAME}" "${sa_password}" "${image_name}" "${SERVER_CONTAINER_NAME}"

  # Wait for SQL Server to be operational
  echo "INFO: Waiting for SQL Server to be operational..."
  local retry_counter=30
  local sleep_period="0.5s"
  while (( retry_counter > 0 )); do
    local operational_output
    operational_output=$(sql_client_run_container "${DOCKER_NETWORK_NAME}" "${image_name}" "${sql_db_scripts_host_path}" "${sql_db_scripts_container_path}" "${server_network_alias}" "${sa_password}" "${sql_db_script_filepath}" || true)
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
  local sql_db_scripts_host_filepath_host_array=()
  mapfile -t sql_db_scripts_host_filepath_host_array < <(find "${sql_db_scripts_host_path}" -name "*.sql" | sort)

  local sql_db_scripts_host_filepath
  for sql_db_scripts_host_filepath in "${sql_db_scripts_host_filepath_host_array[@]}"; do
    # Get filename from filepath
    local sql_db_script_file
    sql_db_script_file=$(basename "${sql_db_scripts_host_filepath}")
    # Construct container path to connectivity SQL script
    sql_db_script_filepath="${sql_db_scripts_container_path}/${sql_db_script_file}"
    # Run SQL Client and try to connect to SQL Server
    local connectivity_output
    connectivity_output=$(sql_client_run_container "${DOCKER_NETWORK_NAME}" "${image_name}" "${sql_db_scripts_host_path}" "${sql_db_scripts_container_path}" "${server_network_alias}" "${sa_password}" "${sql_db_script_filepath}" || true)
    if grep -qF "${sql_tcp_provider_error}" <<< "${connectivity_output}"; then
      echo "ERROR: Test failed, string '${sql_tcp_provider_error}' found in output for SQL script '${sql_db_script_filepath}'"
      return 1
    fi
    echo "INFO: String '${sql_tcp_provider_error}' NOT found in output for SQL script '${sql_db_script_filepath}', continuing..."
  done
}

if test_sql_server "${IMAGE}"; then
  echo "  PASSED"
  docker rm -f "${SERVER_CONTAINER_NAME}" || true
  docker network delete "${DOCKER_NETWORK_NAME}" || true
else
  return_code=$?
  docker rm -f "${SERVER_CONTAINER_NAME}" || true
  docker network delete "${DOCKER_NETWORK_NAME}" || true
  echo "ERROR: Tests failed for image ${IMAGE}" >&2
  return "${return_code}"
fi
