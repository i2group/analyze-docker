# shellcheck shell=bash
# Called by top-level test.sh file to test the Docker image
# All functions in the top-level test.sh file are available for use.
# $IMAGE is the name of the Docker image under test, including the tag
# $IMAGE_NAME is the name of the folder in the images/ directory for the image under test
# $VERSION is the name of the folder in the IMAGE_NAME folder for the image under test

SERVER_CONTAINER_NAME='sql-server'
CLIENT_CONTAINER_NAME='sql-client'
DOCKER_NETWORK_NAME='eia'

# Inspects the Docker image history and checks that our Dockerfile added one ENTRYPOINT to the parent
# which prepends our entrypoint script to whatever the base image's ENTRYPOINT was, and that we've
# preserved the base image's CMD exactly as it was.
# i.e. that we've preserved the base image's ENTRYPOINT and CMD and just inserted our script at the start.
# This test will fail if the parent image's ENTRYPOINT or CMD changes and we don't update our Dockerfile
# to match.
function test_our_entrypoint_and_cmd_wraps_parent_values() {
  docker inspect "${IMAGE}" >/dev/null 2>&1 || docker pull "${IMAGE}"
  local history_json_text
  history_json_text=$(docker image history --no-trunc --format '{{json .}}' "${IMAGE}")

  local history_entrypoint_json_text
  history_entrypoint_json_text=$(jq -cr '
    select(.CreatedBy | test("ENTRYPOINT \\[")) |
    (
      .CreatedBy |
      capture("ENTRYPOINT \\[(?<args>.*)\\]").args |
      [match("\\\"((?:[^\\\"\\\\\\\\]|\\\\\\\\.)*)\\\""; "g").captures[0].string]
    )
  ' <<< "${history_json_text}") || return 1
  local history_cmd_json_text
  history_cmd_json_text=$(jq -cr '
    select(.CreatedBy | test("CMD \\[")) |
    (
      .CreatedBy |
      capture("CMD \\[(?<args>.*)\\]").args |
      [match("\\\"((?:[^\\\"\\\\\\\\]|\\\\\\\\.)*)\\\""; "g").captures[0].string]
    )
  ' <<< "${history_json_text}") || return 1
  local history_entrypoint_json_array=()
  mapfile -t history_entrypoint_json_array <<< "${history_entrypoint_json_text}"
  if (( ${#history_entrypoint_json_array[@]} < 2 )); then
    echo "ERROR: Unable to find at least two ENTRYPOINT commands in docker image history for '${IMAGE}'." >&2
    echo "ERROR: This test needs the latest ENTRYPOINT and the immediately previous ENTRYPOINT to compare appending behavior." >&2
    return 1
  fi
  local history_cmd_json_array=()
  mapfile -t history_cmd_json_array <<< "${history_cmd_json_text}"
  if (( ${#history_cmd_json_array[@]} < 2 )); then
    echo "ERROR: Unable to find at least two CMD commands in docker image history for '${IMAGE}'." >&2
    echo "ERROR: This test needs the latest CMD and the immediately previous CMD to compare preservation behavior." >&2
    return 1
  fi

  local our_image_entrypoint_json
  our_image_entrypoint_json="${history_entrypoint_json_array[0]}"
  echo "INFO: Our image's ENTRYPOINT: ${our_image_entrypoint_json}"
  local base_image_entrypoint_json
  base_image_entrypoint_json="${history_entrypoint_json_array[1]}"
  echo "INFO: Base image's ENTRYPOINT: ${base_image_entrypoint_json}"
  local our_image_cmd_json
  our_image_cmd_json="${history_cmd_json_array[0]}"
  echo "INFO: Our image's CMD: ${our_image_cmd_json}"
  local base_image_cmd_json
  base_image_cmd_json="${history_cmd_json_array[1]}"
  echo "INFO: Base image's CMD: ${base_image_cmd_json}"

  # This test ensures that we've simply made an additive change to the base image
  # and not accidentally broken the existing base-image functionality.
  local prepended_entrypoint_element
  if ! prepended_entrypoint_element=$(jq -ern \
    --argjson current_entrypoint "${our_image_entrypoint_json}" \
    --argjson previous_entrypoint "${base_image_entrypoint_json}" \
    'if ($current_entrypoint | type) != "array" then
      error("Our image ENTRYPOINT is not a JSON array")
    elif ($previous_entrypoint | type) != "array" then
      error("Base image ENTRYPOINT is not a JSON array")
    elif ($current_entrypoint | length) != (($previous_entrypoint | length) + 1) then
      error("Our image ENTRYPOINT length is not previous ENTRYPOINT length plus one")
    elif ($current_entrypoint[1:] != $previous_entrypoint) then
      error("Our image ENTRYPOINT tail does not match previous image ENTRYPOINT")
    else
      $current_entrypoint[0]
    end'
  ); then
    echo "ERROR: ENTRYPOINT mismatch for image '${IMAGE}'." >&2
    echo "ERROR: Expected our ENTRYPOINT to be exactly one prepended element plus previous image ENTRYPOINT." >&2
    echo "ERROR: Our image ENTRYPOINT:  ${our_image_entrypoint_json}" >&2
    echo "ERROR: Base image ENTRYPOINT: ${base_image_entrypoint_json}" >&2
    return 1
  fi
  echo "INFO: ENTRYPOINT wrapper is correct for image '${IMAGE}'"
  # Note: This test does not have any opinion on what the prepended element should be,
  # it just checks that it is prepended to the previous image's ENTRYPOINT.
  # Other tests can check that, whatever has been prepended, is working correctly.
  echo "INFO: Prepended ENTRYPOINT element: ${prepended_entrypoint_element}"

  # This test ensures that we've made no change to the base image
  # and not accidentally broken the existing base-image functionality.
  # This is necessary because Docker resets CMD to "" when ENTRYPOINT is set, so our
  # Dockerfile needs to explicitly set CMD back to the same value used by the base image.
  if [[ "${our_image_cmd_json}" != "${base_image_cmd_json}" ]]; then
    echo "ERROR: CMD mismatch for image '${IMAGE}'." >&2
    echo "ERROR: Expected our CMD to be exactly the same as previous image CMD." >&2
    echo "ERROR: Our image CMD:  ${our_image_cmd_json}" >&2
    echo "ERROR: Base image CMD: ${base_image_cmd_json}" >&2
    return 1
  fi
  echo "INFO: CMD preserved correctly for image '${IMAGE}'"
  echo "INFO: Both base image and our image set it to the same CMD: ${our_image_cmd_json}"
}

function sql_client_run_container() {
  local sql_db_scripts_host_path="$1"
  shift
  local sql_db_scripts_container_path="$1"
  shift
  local test_command="$1"
  shift
  local extra_args=(
    --platform=linux/amd64
    --network="${DOCKER_NETWORK_NAME}"
    --name="${CLIENT_CONTAINER_NAME}"
    -v "${sql_db_scripts_host_path}:${sql_db_scripts_container_path}"
  )
  # set -x logging goes to a temp fd 3 that's going to stdout, so that we can see the debug output
  # without it interfering with the actual output of the commands.
  local container_command=(
    bash -c "\
exec 3>/proc/self/fd/1; \
BASH_XTRACEFD=3; \
set -euxo pipefail; \
${test_command}"
  )

  # Create and run SQL client container
  (
    BASH_XTRACEFD=1
    set -x
    docker run \
      --rm \
      "${extra_args[@]}" \
      "${IMAGE}" \
      "${container_command[@]}"
  )
}

function sql_server_run_container() {
  local server_network_alias="$1"
  shift
  local sa_password="$1"

  # Create and run SQL Server container
  (
    BASH_XTRACEFD=1
    export MSSQL_SA_PASSWORD="${sa_password}"
    set -x
    docker run \
      -d \
      --platform=linux/amd64 \
      --network-alias="${server_network_alias}" \
      --name="${SERVER_CONTAINER_NAME}" \
      --network="${DOCKER_NETWORK_NAME}" \
      --env ACCEPT_EULA=Y \
      --env MSSQL_SA_PASSWORD \
      --env MSSQL_PID=Developer \
      --env MSSQL_AGENT_ENABLED=true \
      "${IMAGE}"
    docker ps -a --filter "name=${SERVER_CONTAINER_NAME}"
  )
}

function test_password_env_var_forwarding() {
  local expected_sa="sa-pass-$$"
  local expected_mssql_sa="mssql-sa-pass-$$"

  # Verify entrypoint leaves both variables unset when caller does not set either.
  docker run --rm --entrypoint /opt/docker-entrypoint.sh "${IMAGE}" bash -lc '
    [[ -z "${SA_PASSWORD+x}" ]] && [[ -z "${MSSQL_SA_PASSWORD+x}" ]]
  '

  # Verify SA_PASSWORD is forwarded on its own without creating MSSQL_SA_PASSWORD.
  docker run --rm --entrypoint /opt/docker-entrypoint.sh \
    --env SA_PASSWORD="${expected_sa}" \
    --env EXPECTED_SA="${expected_sa}" \
    "${IMAGE}" bash -lc '
      [[ "${SA_PASSWORD}" == "${EXPECTED_SA}" ]] &&
      [[ -z "${MSSQL_SA_PASSWORD+x}" ]]
    '

  # Verify MSSQL_SA_PASSWORD is forwarded on its own without creating SA_PASSWORD.
  docker run --rm --entrypoint /opt/docker-entrypoint.sh \
    --env MSSQL_SA_PASSWORD="${expected_mssql_sa}" \
    --env EXPECTED_MSSQL_SA="${expected_mssql_sa}" \
    "${IMAGE}" bash -lc '
      [[ "${MSSQL_SA_PASSWORD}" == "${EXPECTED_MSSQL_SA}" ]] &&
      [[ -z "${SA_PASSWORD+x}" ]]
    '

  # Verify both variables are preserved when both are set, even with different values.
  docker run --rm --entrypoint /opt/docker-entrypoint.sh \
    --env SA_PASSWORD="${expected_sa}" \
    --env MSSQL_SA_PASSWORD="${expected_mssql_sa}" \
    --env EXPECTED_SA="${expected_sa}" \
    --env EXPECTED_MSSQL_SA="${expected_mssql_sa}" \
    "${IMAGE}" bash -lc '
      [[ "${SA_PASSWORD}" == "${EXPECTED_SA}" ]] &&
      [[ "${MSSQL_SA_PASSWORD}" == "${EXPECTED_MSSQL_SA}" ]]
    '
}

function test_sql_server() {
  # Note: For ease of use in bash code, we do not use any bash-special characters in the password,
  # so that we don't have to escape them in bash code.
  # This is not a security concern because this password is only used for testing and is not a real password.
  # We're using uppercase, lowercase, numbers (our PID), and a symbol (a dash),
  # which is enough complexity to satisfy SQL Server's password complexity requirements for testing purposes.
  local sa_password="my-SA-$$-password"
  local sql_db_scripts_container_path='/tmp/database-scripts/static'
  local server_network_alias="sqlserver.${DOCKER_NETWORK_NAME}"
  local sql_select_1_success='(1 rows affected)'
  local sql_tcp_provider_error='TCP Provider: Error code 0x68'

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
  test_command='/opt/mssql-tools/bin/sqlcmd -?'

  # Create and run client container to verify SQL tools are installed
  sql_client_run_container "${sql_db_scripts_host_path}" "${sql_db_scripts_container_path}" "${test_command}"

  # Create and run server container
  sql_server_run_container "${server_network_alias}" "${sa_password}"

  # Wait for SQL Server to be operational
  echo "INFO: Waiting for SQL Server to be operational..."
  local max_tries=30
  local retry_counter=${max_tries}
  local sleep_period='0.5s'
  while (( retry_counter > 0 )); do
    # if the server container has exited then we can stop waiting and fail immediately to get the container logs for debugging
    if docker ps -a --filter "status=exited" --format '{{.Names}}' | grep -q "^${SERVER_CONTAINER_NAME}\$"; then
      echo "ERROR: SQL Server container has exited unexpectedly." >&2
      return 1
    fi
    local operational_output
    operational_output=$(sql_client_run_container "${sql_db_scripts_host_path}" "${sql_db_scripts_container_path}" "/opt/mssql-tools/bin/sqlcmd -S '${server_network_alias}' -U sa -P '${sa_password}' -N -C -i '${sql_db_script_filepath}'" || true)
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
    echo "ERROR: Tests failed, SQL Server did not become operational after ${max_tries} attempts." >&2
    return 1
  fi

  # Create an array of .sql files
  local sql_db_scripts_host_filepath_host_array=()
  mapfile -t sql_db_scripts_host_filepath_host_array < <(find "${sql_db_scripts_host_path}" -name '*.sql' | sort)

  local sql_db_scripts_host_filepath
  for sql_db_scripts_host_filepath in "${sql_db_scripts_host_filepath_host_array[@]}"; do
    # Get filename from filepath
    local sql_db_script_file
    sql_db_script_file=$(basename "${sql_db_scripts_host_filepath}")
    # Construct container path to connectivity SQL script
    sql_db_script_filepath="${sql_db_scripts_container_path}/${sql_db_script_file}"
    # Run SQL Client and try to connect to SQL Server
    local connectivity_output
    connectivity_output=$(sql_client_run_container "${sql_db_scripts_host_path}" "${sql_db_scripts_container_path}" "/opt/mssql-tools/bin/sqlcmd -S '${server_network_alias}' -U sa -P '${sa_password}' -N -C -i '${sql_db_script_filepath}'" || true)
    if grep -qF "${sql_tcp_provider_error}" <<< "${connectivity_output}"; then
      echo "ERROR: Test failed, string '${sql_tcp_provider_error}' found in output for SQL script '${sql_db_script_filepath}'"
      return 1
    fi
    echo "INFO: String '${sql_tcp_provider_error}' NOT found in output for SQL script '${sql_db_script_filepath}', continuing..."
  done
}

function test_dockerfile_contains_exactly_one() {
  local instruction="$1"
  local dockerfile_path="images/${IMAGE_NAME}/${VERSION}/Dockerfile"
  if [[ ! -f "${dockerfile_path}" ]]; then
    echo "ERROR: Dockerfile not found at '${dockerfile_path}'" >&2
    return 1
  fi
  local count
  count=$(grep -c "^${instruction} " "${dockerfile_path}")
  if [[ "${count}" -ne 1 ]]; then
    echo "ERROR: Expected exactly one ${instruction} in '${dockerfile_path}', but found ${count}." >&2
    grep "^${instruction} " "${dockerfile_path}" >&2
    return 1
  fi
}

function run_all_tests() {
  local return_code=0
  test_dockerfile_contains_exactly_one ENTRYPOINT || return_code=$?
  test_dockerfile_contains_exactly_one CMD || return_code=$?
  test_password_env_var_forwarding || return_code=$?
  test_our_entrypoint_and_cmd_wraps_parent_values || return_code=$?
  test_sql_server || return_code=$?
  return "${return_code}"
}

docker rm -f "${SERVER_CONTAINER_NAME}" >/dev/null 2>&1 || true
docker rm -f "${CLIENT_CONTAINER_NAME}" >/dev/null 2>&1 || true
if run_all_tests; then
  echo '  PASSED'
  docker rm -f "${SERVER_CONTAINER_NAME}" >/dev/null || true
  docker rm -f "${CLIENT_CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker network rm "${DOCKER_NETWORK_NAME}" >/dev/null || true
else
  return_code=$?
  rm -rf /tmp/server_container_var_opt_mssql_log_errorlog
  (
    BASH_XTRACEFD=1
    set -x
    docker ps -a || true
    # We can only inspect the logs if the container exists.
    # ... and there's no guarantee the errorlog exists either.
    docker inspect "${SERVER_CONTAINER_NAME}" && \
    docker logs "${SERVER_CONTAINER_NAME}" && \
    docker cp "${SERVER_CONTAINER_NAME}":/var/opt/mssql/log/errorlog /tmp/server_container_var_opt_mssql_log_errorlog && cat /tmp/server_container_var_opt_mssql_log_errorlog || true
    docker rm -f "${SERVER_CONTAINER_NAME}" >/dev/null || true
    docker rm -f "${CLIENT_CONTAINER_NAME}" >/dev/null 2>&1 || true
    docker network rm "${DOCKER_NETWORK_NAME}" >/dev/null || true
  )
  echo "ERROR: Tests failed for image ${IMAGE}" >&2
  return "${return_code}"
fi
