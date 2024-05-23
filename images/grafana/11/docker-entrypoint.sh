#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

set -e

# For debug purposes only
if [[ "${DEBUG}" == "true" ]]; then
  set -x
fi

. /opt/environment.sh

if [[ "${SSL_ENABLED}" == "true" ]]; then
  file_env 'SSL_PRIVATE_KEY'
  file_env 'SSL_CERTIFICATE'
  if [[ -z "${SSL_PRIVATE_KEY}" || -z "${SSL_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE" >&2
    exit 1
  fi

  TMP_SECRETS="/tmp/i2acerts"
  KEY="${TMP_SECRETS}/server.key"
  CER="${TMP_SECRETS}/server.cer"

  if [[ -d "${TMP_SECRETS}" ]]; then
    rm -r "${TMP_SECRETS}"
  fi
  mkdir -p "${TMP_SECRETS}"

  echo "${SSL_PRIVATE_KEY}" >"${KEY}"
  echo "${SSL_CERTIFICATE}" >"${CER}"

  export GF_SERVER_PROTOCOL="https"
  export GF_SERVER_CERT_FILE="${CER}"
  export GF_SERVER_CERT_KEY="${KEY}"
fi

# Call original grafana entrypoint
exec /run.sh "$@"
