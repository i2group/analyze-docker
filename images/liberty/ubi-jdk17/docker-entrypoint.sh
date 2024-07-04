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

# shellcheck disable=SC1091
. /opt/environment.sh
# shellcheck disable=SC1091
. /opt/cert_tools.sh

DEFAULT_SERVER_DIR=/opt/ol/wlp/usr/servers/defaultServer
DB_NAME="${DB_NAME:-"ISTORE"}"

# Load secrets if they exist on disk and export them as envs
file_env 'DB_PASSWORD'
file_env 'DB_USERNAME'
file_env 'ZOO_DIGEST_PASSWORD'
file_env 'ZOO_DIGEST_USERNAME'
file_env 'SOLR_HTTP_BASIC_AUTH_USER'
file_env 'SOLR_HTTP_BASIC_AUTH_PASSWORD'
file_env 'SSL_ADDITIONAL_TRUST_CERTIFICATES'
if [[ "${SSL_ADDITIONAL_TRUST_CERTIFICATES}" == "None" ]]; then
  SSL_ADDITIONAL_TRUST_CERTIFICATES=""
fi

KEYSTORE_PASS="$(openssl rand -base64 16)"
export KEYSTORE_PASS
TMP_SECRETS="/tmp/i2acerts"
rm -rf "${TMP_SECRETS}"
mkdir "${TMP_SECRETS}"

if [[ "${SERVER_SSL}" == "true" || "${SOLR_ZOO_SSL_CONNECTION}" == "true" ||
  "${GATEWAY_SSL_CONNECTION}" == "true" || "${DB_SSL_CONNECTION}" == "true" ]]; then
  file_env 'SSL_CA_CERTIFICATE'
  if [[ -z "${SSL_CA_CERTIFICATE}" ]]; then
    echo "ERROR: Missing security environment variables. Please check SSL_CA_CERTIFICATE" >&2
    exit 1
  fi

  CA_CER="${TMP_SECRETS}/CA.cer"
  TRUSTSTORE="${TMP_SECRETS}/truststore.p12"
  add_to_pem_file "${CA_CER}" \
    SSL_CA_CERTIFICATE "${SSL_CA_CERTIFICATE}" \
    SSL_ADDITIONAL_TRUST_CERTIFICATES "${SSL_ADDITIONAL_TRUST_CERTIFICATES}"
  add_to_java_keystore "${TRUSTSTORE}" KEYSTORE_PASS \
    SSL_CA_CERTIFICATE "${SSL_CA_CERTIFICATE}" \
    SSL_ADDITIONAL_TRUST_CERTIFICATES "${SSL_ADDITIONAL_TRUST_CERTIFICATES}"
fi

file_env 'APP_SECRETS'
if [[ -n "${APP_SECRETS}" && "${APP_SECRETS}" != "None" ]]; then
  while read -r key value; do
    declare -x "$key"="$value"
  done < <(jq -r 'keys[] as $k | "\($k) \(.[$k])"' < <(echo "${APP_SECRETS}"))
fi

if [[ "${GATEWAY_SSL_CONNECTION}" == "true" ]]; then
  file_env 'SSL_OUTBOUND_PRIVATE_KEY'
  file_env 'SSL_OUTBOUND_CERTIFICATE'
  file_env 'SSL_OUTBOUND_CA_CERTIFICATE'

  if [[ -z "${SSL_OUTBOUND_PRIVATE_KEY}" || -z "${SSL_OUTBOUND_CERTIFICATE}" ]]; then
    echo "ERROR: Missing security environment variables. Please check SSL_OUTBOUND_PRIVATE_KEY SSL_OUTBOUND_CERTIFICATE" >&2
    exit 1
  fi
  OUT_KEY="${TMP_SECRETS}/out_server.key"
  OUT_CER="${TMP_SECRETS}/out_server.cer"
  OUT_CA_CER="${TMP_SECRETS}/out_CA.cer"
  OUT_KEYSTORE="${TMP_SECRETS}/out_keystore.p12"
  OUT_TRUSTSTORE="${TMP_SECRETS}/out_truststore.p12"

  add_to_pem_file "${OUT_KEY}" SSL_OUTBOUND_PRIVATE_KEY "${SSL_OUTBOUND_PRIVATE_KEY}"
  add_to_pem_file "${OUT_CER}" SSL_OUTBOUND_CERTIFICATE "${SSL_OUTBOUND_CERTIFICATE}"

  if [[ -n "${SSL_OUTBOUND_CA_CERTIFICATE}" ]]; then
    add_to_pem_file "${OUT_CA_CER}" \
      SSL_OUTBOUND_CA_CERTIFICATE "${SSL_OUTBOUND_CA_CERTIFICATE}" \
      SSL_ADDITIONAL_TRUST_CERTIFICATES "${SSL_ADDITIONAL_TRUST_CERTIFICATES}"
    add_to_java_keystore "${OUT_TRUSTSTORE}" KEYSTORE_PASS \
      SSL_OUTBOUND_CA_CERTIFICATE "${SSL_OUTBOUND_CA_CERTIFICATE}" \
      SSL_ADDITIONAL_TRUST_CERTIFICATES "${SSL_ADDITIONAL_TRUST_CERTIFICATES}"
    LIBERTY_OUT_TRUSTSTORE_LOCATION="${OUT_TRUSTSTORE}"
  else
    LIBERTY_OUT_TRUSTSTORE_LOCATION="${TRUSTSTORE}"
  fi
  export LIBERTY_OUT_TRUSTSTORE_LOCATION

  run_quietly openssl pkcs12 -export -in "${OUT_CER}" -inkey "${OUT_KEY}" -certfile "${CA_CER}" -passout env:KEYSTORE_PASS -out "${OUT_KEYSTORE}"

  export LIBERTY_OUT_KEYSTORE_LOCATION="${OUT_KEYSTORE}"
  export LIBERTY_OUT_TRUSTSTORE_PASSWORD="${KEYSTORE_PASS}"
  export LIBERTY_OUT_KEYSTORE_PASSWORD="${KEYSTORE_PASS}"
  export LIBERTY_TRUSTSTORE_LOCATION="${TRUSTSTORE}"
  export LIBERTY_TRUSTSTORE_PASSWORD="${KEYSTORE_PASS}"
fi

if [[ "${SERVER_SSL}" == "true" || "${SOLR_ZOO_SSL_CONNECTION}" == "true" ]]; then
  file_env 'SSL_PRIVATE_KEY'
  file_env 'SSL_CERTIFICATE'
  file_env 'SSL_CA_CERTIFICATE'
  if [[ -z "${SSL_PRIVATE_KEY}" || -z "${SSL_CERTIFICATE}" || -z "${SSL_CA_CERTIFICATE}" ]]; then
    echo "ERROR: Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE SSL_CA_CERTIFICATE" >&2
    exit 1
  fi
  KEY="${TMP_SECRETS}/server.key"
  CER="${TMP_SECRETS}/server.cer"
  KEYSTORE="${TMP_SECRETS}/keystore.p12"

  add_to_pem_file "${KEY}" SSL_PRIVATE_KEY "${SSL_PRIVATE_KEY}"
  add_to_pem_file "${CER}" SSL_CERTIFICATE "${SSL_CERTIFICATE}"

  run_quietly openssl pkcs12 -export -in "${CER}" -inkey "${KEY}" -certfile "${CA_CER}" -passout env:KEYSTORE_PASS -out "${KEYSTORE}"

  export LIBERTY_TRUSTSTORE_LOCATION="${TRUSTSTORE}"
  export LIBERTY_KEYSTORE_LOCATION="${KEYSTORE}"
  export LIBERTY_TRUSTSTORE_PASSWORD="${KEYSTORE_PASS}"
  export LIBERTY_KEYSTORE_PASSWORD="${KEYSTORE_PASS}"
fi

file_env 'JWT_CERTIFICATE'
file_env 'JWT_PRIVATE_KEY'

if [[ -n "${JWT_CERTIFICATE}" || -n "${JWT_PRIVATE_KEY}" ]]; then
  JWT_KEY="${TMP_SECRETS}/jwt_sign.key"
  JWT_CER="${TMP_SECRETS}/jwt_sign.cer"
  JWT_TRUSTSTORE="${TMP_SECRETS}/jwt_truststore.p12"
  JWT_KEYSTORE="${TMP_SECRETS}/jwt_keystore.p12"
  add_to_pem_file "${JWT_CER}" JWT_CERTIFICATE "${JWT_CERTIFICATE}"
  add_to_pem_file "${JWT_KEY}" JWT_PRIVATE_KEY "${JWT_PRIVATE_KEY}"
  run_quietly openssl pkcs12 -export -inkey "${JWT_KEY}" -in "${JWT_CER}" -passout env:KEYSTORE_PASS -out "${JWT_KEYSTORE}"
  add_to_java_keystore "${JWT_TRUSTSTORE}" KEYSTORE_PASS \
    JWT_CERTIFICATE "${JWT_CERTIFICATE}"

  export JWT_KEYSTORE_LOCATION="${JWT_KEYSTORE}"
  export JWT_KEYSTORE_PASSWORD="${KEYSTORE_PASS}"
  export JWT_TRUSTSTORE_LOCATION="${JWT_TRUSTSTORE}"
  export JWT_TRUSTSTORE_PASSWORD="${KEYSTORE_PASS}"
fi

if [[ "${SERVER_SSL}" == "true" ]]; then
  LIBERTY_SSL="true"
  HTTP_PORT="-1"
  HTTPS_PORT="9443"
else
  LIBERTY_SSL="false"
  HTTP_PORT="9080"
  HTTPS_PORT="-1"
fi

export LIBERTY_SSL
export HTTP_PORT
export HTTPS_PORT

if [[ "${DB_SSL_CONNECTION}" == "true" ]]; then
  # Ensure the database-client code knows where to find the certificates
  if [[ "${DB_DIALECT}" == "postgres" ]]; then
    # Postgres expects a filename of a certificate as the truststore location
    # (see i2 docs for details).
    export DB_TRUSTSTORE_LOCATION="${CA_CER}"
  else
    # The others need a Java truststore + password.
    export DB_TRUSTSTORE_LOCATION="${TRUSTSTORE}"
    export DB_TRUSTSTORE_PASSWORD="${KEYSTORE_PASS}"
  fi
fi

BOOTSTRAP_FILE="${DEFAULT_SERVER_DIR}/bootstrap.properties"
{
  echo "ApolloServerSettingsResource=ApolloServerSettingsConfigurationSet.properties"
  echo "APOLLO_DATA=${APOLLO_DATA_DIR}"
  echo "apollo.log.dir=${LOG_DIR}"
} >"${BOOTSTRAP_FILE}"

mkdir -p "${DEFAULT_SERVER_DIR}/apps/opal-services.war/WEB-INF/classes"
DISCO_FILESTORE_LOCATION="${DEFAULT_SERVER_DIR}/apps/opal-services.war/WEB-INF/classes/DiscoFileStoreLocation.properties"
{
  echo "FileStoreLocation.chart-store=${APOLLO_DATA_DIR}/chart/main"
  echo "FileStoreLocation.job-store=${APOLLO_DATA_DIR}/job/main"
  echo "FileStoreLocation.recordgroup-store=${APOLLO_DATA_DIR}/recordgroup/main"
} >"${DISCO_FILESTORE_LOCATION}"

export DB_NAME

rm -f /opt/ol/wlp/usr/servers/defaultServer/server.env

for file in /opt/entrypoint.d/*; do
  if [ -f "${file}" ]; then
    if [ ! -x "${file}" ]; then
      chmod +x "${file}"
    fi
    # shellcheck disable=SC1090
    . "${file}"
  fi
done

# Pass on to the real server run
exec "$@"
