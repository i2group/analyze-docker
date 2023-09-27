#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

. /opt/environment.sh

# Load secrets if they exist on disk and export them as envs
file_env 'PROMETHEUS_PASSWORD'
file_env 'PROMETHEUS_USERNAME'
file_env 'LIBERTY_ADMIN_USERNAME'
file_env 'LIBERTY_ADMIN_PASSWORD'

TMP_SECRETS="/tmp/i2acerts"

if [[ "${SERVER_SSL}" == "true" ]]; then
  file_env 'SSL_PRIVATE_KEY'
  file_env 'SSL_CERTIFICATE'
  file_env 'SSL_CA_CERTIFICATE'
  if [[ -z ${SSL_PRIVATE_KEY} || -z ${SSL_CERTIFICATE} || -z ${SSL_CA_CERTIFICATE} ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE SSL_CA_CERTIFICATE"
    exit 1
  fi
  KEY="${TMP_SECRETS}/server.key"
  CER="${TMP_SECRETS}/server.cer"
  CA_CER="${TMP_SECRETS}/CA.cer"

  if [[ ! -d "${TMP_SECRETS}" ]]; then
    mkdir -p "${TMP_SECRETS}"
  fi
  echo "${SSL_PRIVATE_KEY}" >"${KEY}"
  echo "${SSL_CERTIFICATE}" >"${CER}"
  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"
fi
if [[ "${LIBERTY_SSL_CONNECTION}" == "true" ]]; then
  file_env 'SSL_OUTBOUND_CA_CERTIFICATE'
  file_env 'SSL_OUTBOUND_CERTIFICATE'
  file_env 'SSL_OUTBOUND_PRIVATE_KEY'

  OUT_CA_CER="${TMP_SECRETS}/out_CA.cer"
  OUT_KEY="${TMP_SECRETS}/out_server.key"
  OUT_CER="${TMP_SECRETS}/out_server.cer"

  # Create a directory if it doesn't exist
  if [[ ! -d "${TMP_SECRETS}" ]]; then
    mkdir -p "${TMP_SECRETS}"
  fi

  echo "${SSL_OUTBOUND_CA_CERTIFICATE}" >"${OUT_CA_CER}"
  echo "${SSL_OUTBOUND_CERTIFICATE}" >"${OUT_CER}"
  echo "${SSL_OUTBOUND_PRIVATE_KEY}" >"${OUT_KEY}"
fi

if [ -f "/tmp/prometheus/web-config.yml" ]; then
  cp /tmp/prometheus/web-config.yml /etc/prometheus/web-config.yml
else
  cp /etc/prometheus-templates/web-config.yml /etc/prometheus/web-config.yml
fi

/opt/update-prometheus-config.sh

set +e

# Call original prometheus entrypoint
exec "/bin/prometheus" "$@"
