#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

set -eo pipefail

. /opt/environment.sh

file_env 'DB_PASSWORD'

# Outputs postgres args that will enable SSL if SERVER_SSL is true.
# These args will need to be passed to the postgres CLI just after the "postgres" command
function calculate_ssl_args() {
  if [[ "${SERVER_SSL:-}" != "true" ]]; then
    return 0
  fi
  file_env 'SSL_PRIVATE_KEY'
  file_env 'SSL_CERTIFICATE'
  if [[ -z "${SSL_PRIVATE_KEY:-}" || -z "${SSL_CERTIFICATE:-}" ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE"
    exit 1
  fi

  local -r secrets_dir="/tmp/i2acerts"
  local -r server_key_file="${secrets_dir}/server.key"
  local -r server_cert_file="${secrets_dir}/server.cer"

  mkdir -p "${secrets_dir}"
  echo "${SSL_PRIVATE_KEY}" >"${server_key_file}"
  echo "${SSL_CERTIFICATE}" >"${server_cert_file}"
  # Merely enabling SSL does not turn off (insecure) clear-text access.
  # We need to force the use of SSL by telling postgres not to accept
  # non-ssl connections over the network.
  # To do that, we replace the "host ..." line in pg_hba.conf that's allowing
  # non-localhost access (address==all) with "hostssl ..." *but* to do that,
  # we need to supply our own pg_hba.conf file, as nothing exists when we first
  # start up.
  local -r client_config_filename='pg_hba.conf'
  local -r client_config_file="${secrets_dir}/${client_config_filename}"
  (
    echo "# Created by i2 entrypoint as SERVER_SSL=${SERVER_SSL}"
    echo "hostssl    all          all  all           scram-sha-256"
  ) >"${client_config_file}"
  # postgres is fussy about file permissions on its SSL files, so ensure they're set acceptably
  if [[ "${EUID}" -ne 0 ]]; then
    chmod 0700 "${secrets_dir}"
    chmod 0400 "${server_key_file}" "${server_cert_file}" "${client_config_file}"
  else
    chmod 0750 "${secrets_dir}"
    chmod 0440 "${server_key_file}" "${server_cert_file}" "${client_config_file}"
  fi
  # output the args postgres will need in order to use this SSL config
  echo "-c"
  echo "ssl=on"
  echo "-c"
  echo "ssl_cert_file=${server_cert_file}"
  echo "-c"
  echo "ssl_key_file=${server_key_file}"
  echo "-c"
  echo "hba_file=${client_config_file}"
}

ssl_args_as_string="$(calculate_ssl_args)"
if [[ -n "${ssl_args_as_string}" ]]; then
  readarray -t ssl_args <<<"${ssl_args_as_string}"
else
  ssl_args=()
fi

if [[ "${1:0:1}" = '-' ]]; then
  # the args given are all postgres args, so we insert ours at the start
  set -- "${ssl_args[@]}" "$@"
elif [[ "${1:-}" = "postgres" ]]; then
  # someone's asked to run postgres, so subsequent args are postgres args, so we insert ours there
  postgres_arg="$1"
  shift
  set -- "${postgres_arg}" "${ssl_args[@]}" "$@"
fi
# else we're not running postgres, so we don't fiddle with args

# Pass control to the official postgres entrypoint
exec /usr/local/bin/docker-entrypoint.sh "$@"
