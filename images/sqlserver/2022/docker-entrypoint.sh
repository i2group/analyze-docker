#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

. /opt/environment.sh

file_env 'SA_PASSWORD'

MSSQL_CONF_FILE="/var/opt/mssql/mssql.conf"

if [[ ${SERVER_SSL} == true ]]; then
  file_env 'SSL_PRIVATE_KEY'
  file_env 'SSL_CERTIFICATE'
  if [[ -z ${SSL_PRIVATE_KEY} || -z ${SSL_CERTIFICATE} ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE" >&2
    exit 1
  fi

  TMP_SECRETS=/tmp/i2acerts
  KEY=${TMP_SECRETS}/server.key
  CER=${TMP_SECRETS}/server.cer

  if [[ -d ${TMP_SECRETS} ]]; then
    rm -r ${TMP_SECRETS}
  fi
  mkdir ${TMP_SECRETS}

  echo "${SSL_PRIVATE_KEY}" >"${KEY}"
  echo "${SSL_CERTIFICATE}" >"${CER}"

  if [[ -f ${MSSQL_CONF_FILE} ]]; then
    rm ${MSSQL_CONF_FILE}
  fi

  echo "[network]
tlsprotocols = 1.2
forceencryption = 1
tlscert = ${CER}
tlskey = ${KEY}
" >>${MSSQL_CONF_FILE}
fi

set +e
exec "$@"
