#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

# For debug purposes only
if [[ "${DEBUG}" == "true" ]]; then
  set -x
fi

. /opt/environment.sh

if [[ "${SERVER_SSL}" == "true" ]]; then
  file_env 'SSL_CERTIFICATE'
  file_env 'SSL_PRIVATE_KEY'
  if [[ -z "${SSL_PRIVATE_KEY}" || -z "${SSL_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE" >&2
    exit 1
  fi

  TMP_SECRETS=/tmp/i2acerts
  CERTIFICATES_FILE="${TMP_SECRETS}/i2Analyze.pem"

  if [[ -d "${TMP_SECRETS}" ]]; then
    rm -r "${TMP_SECRETS}"
  fi
  mkdir -p "${TMP_SECRETS}"

  if [[ -f "${CERTIFICATES_FILE}" ]]; then
    rm "${CERTIFICATES_FILE}"
  fi
  echo "${SSL_CERTIFICATE}" >>"${CERTIFICATES_FILE}"
  echo "${SSL_PRIVATE_KEY}" >>"${CERTIFICATES_FILE}"
fi

sudo chown -R haproxy /usr/local/etc/haproxy

exec /usr/local/bin/docker-entrypoint.sh "$@"
