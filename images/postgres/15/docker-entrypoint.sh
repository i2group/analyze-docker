#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

set -e

. /opt/environment.sh

file_env 'DB_PASSWORD'

# Outputs postgres args that will enable SSL if SERVER_SSL is true.
# These args will need to be passed to the postgres CLI just after the "postgres" command
function calculate_ssl_args() {
  if [[ "${SERVER_SSL:-}" == "true" ]]; then
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
    # postgres is fussy about file permissions on its SSL files, so ensure they're set acceptably
    if [[ "${EUID}" -ne 0 ]]; then
      chmod 0700 "${secrets_dir}"
      chmod 0400 "${server_key_file}" "${server_cert_file}"
    else
      chmod 0750 "${secrets_dir}"
      chmod 0440 "${server_key_file}" "${server_cert_file}"
    fi
    # output the args postgres will need in order to use this SSL config
    echo "-c"
    echo "ssl=on"
    echo "-c"
    echo "ssl_cert_file=${server_cert_file}"
    echo "-c"
    echo "ssl_key_file=${server_key_file}"
  fi
}

readarray -t ssl_args < <(calculate_ssl_args)
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
