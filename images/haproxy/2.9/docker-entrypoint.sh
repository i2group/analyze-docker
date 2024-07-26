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

TMP_SECRETS=/tmp/i2acerts

# Combined cert and key
CERTIFICATES_FILE="${TMP_SECRETS}/i2Analyze.pem"
GATEWAY_CERTIFICATES_FILE="${TMP_SECRETS}/gateway.user.pem"

# CA files
EXTERNAL_CA_FILE="${TMP_SECRETS}/externalCA.cer"
INTERNAL_CA_FILE="${TMP_SECRETS}/internalCA.cer"

if [[ -d "${TMP_SECRETS}" ]]; then
  rm -r "${TMP_SECRETS}"
fi
mkdir -p "${TMP_SECRETS}"

if [[ "${SERVER_SSL}" == "true" ]]; then
  file_env 'SSL_CERTIFICATE'
  file_env 'SSL_PRIVATE_KEY'
  if [[ -z "${SSL_PRIVATE_KEY}" || -z "${SSL_CERTIFICATE}" || -z "${SSL_CA_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE SSL_CA_CERTIFICATE" >&2
    exit 1
  fi

  echo "${SSL_CERTIFICATE}" >>"${CERTIFICATES_FILE}"
  echo "${SSL_PRIVATE_KEY}" >>"${CERTIFICATES_FILE}"
  echo "${SSL_CA_CERTIFICATE}" >>"${EXTERNAL_CA_FILE}"
fi

if [[ "${GATEWAY_SSL_CONNECTION}" == "true" ]]; then
  if [[ -z "${SSL_OUTBOUND_PRIVATE_KEY}" || -z "${SSL_OUTBOUND_CERTIFICATE}" || -z "${SSL_OUTBOUND_CA_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_OUTBOUND_PRIVATE_KEY SSL_OUTBOUND_CERTIFICATE SSL_OUTBOUND_CA_CERTIFICATE" >&2
    exit 1
  fi
  echo "${SSL_OUTBOUND_PRIVATE_KEY}" >>"${GATEWAY_CERTIFICATES_FILE}"
  echo "${SSL_OUTBOUND_CERTIFICATE}" >>"${GATEWAY_CERTIFICATES_FILE}"
  echo "${SSL_OUTBOUND_CA_CERTIFICATE}" >>"${INTERNAL_CA_FILE}"
fi

sudo chown -R haproxy /usr/local/etc/haproxy

exec /usr/local/bin/docker-entrypoint.sh "$@"
