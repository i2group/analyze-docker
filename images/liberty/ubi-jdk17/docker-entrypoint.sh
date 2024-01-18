#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -eo pipefail

. /opt/environment.sh

# Load secrets if they exist on disk and export them as envs
file_env 'DB_PASSWORD'
file_env 'DB_USERNAME'
file_env 'ZOO_DIGEST_PASSWORD'
file_env 'ZOO_DIGEST_USERNAME'
file_env 'SOLR_HTTP_BASIC_AUTH_USER'
file_env 'SOLR_HTTP_BASIC_AUTH_PASSWORD'
file_env 'APP_SECRETS'
file_env 'SSL_OUTBOUND_PRIVATE_KEY'
file_env 'SSL_OUTBOUND_CERTIFICATE'
file_env 'SSL_OUTBOUND_CA_CERTIFICATE'
file_env 'SSL_CA_CERTIFICATE'
file_env 'SSL_PRIVATE_KEY'
file_env 'SSL_CERTIFICATE'
file_env 'SSL_ADDITIONAL_TRUST_CERTIFICATES'
if [[ "${SSL_ADDITIONAL_TRUST_CERTIFICATES}" == "None" ]]; then
  SSL_ADDITIONAL_TRUST_CERTIFICATES=""
fi
if [[ "${APP_SECRETS}" == "None" ]]; then
  APP_SECRETS=""
fi

# Parses a PEM and extracts information
# stdin = cert in pem format
# sets variables cert_content, cert_hash, cert_subject, cert_sanitized_subject and cert_summary
function get_cert_details() {
  cert_content="$(cat)"
  cert_hash="$( openssl x509 -noout -hash <<<"${cert_content}" 2>/dev/null | tr -d '\n' )"
  cert_subject="$( openssl x509 -noout -subject <<<"${cert_content}" 2>/dev/null | sed 's,^subject=,,' | tr -d '\n' | tr --complement -d '[:print:]' )"
  cert_sanitized_subject="$( tr -d '\n' <<<"${cert_subject}" | tr --complement '[:alnum:].-=' '_' )"
  local synopsis=""
  if [[ -n "${cert_subject}" ]]; then
    synopsis+=" with certificate subject ${cert_subject}"
  fi
  if [[ -n "${cert_hash}" ]]; then
    synopsis+=" with certificate hash ${cert_hash}"
  fi
  if [[ -n "${cert_content}" ]]; then
    synopsis+=" starting $(head -2 <<<"${cert_content}" | awk '{printf "%s\\n", $0}' | sed 's,\\n$,,')"
    synopsis+=" ending $(tail -2 <<<"${cert_content}" | awk '{printf "%s\\n", $0}' | sed 's,\\n$,,')"
  fi
  cert_summary="${synopsis}"
}

# Adds a PEM to a Java trust store so that the certificate will be trusted in future.
# stdin = cert in pem format
# $1 = filename of the Java keystore to add the certificate to
# $2 = name of the env var containing the Java keystore's password.
function make_java_trust_cert() {
  local -r java_keystore_filename="${1}"
  local -r java_keystore_keypass_env_name="${2}"
  local cert_content cert_hash cert_subject cert_sanitized_subject cert_summary
  get_cert_details
  local -r cert_alias="${cert_sanitized_subject}.${cert_hash}"
  local keytool_output
  keytool_output="$(keytool \
    -importcert \
    -noprompt \
    -alias "${cert_alias}" \
    -keystore "${java_keystore_filename}" \
    -storepass:env "${java_keystore_keypass_env_name}" \
    -storetype PKCS12 \
    <<<"${cert_content}" \
    2>&1)"
  if [[ "${keytool_output}" != "Certificate was added to keystore" ]]; then
    echo "ERROR: Failed to import PEM${cert_summary} as alias ${cert_alias} into trust store ${java_keystore_filename}:"
    echo "${keytool_output}"
    return 1
  fi >&2
}

# Runs a command for every PEM it is given.
# Each command will have one PEM piped into its stdin.
# stdin = zero or more pems
# $@ = command to be run for each pem
function for_all_pems() {
  local -a what_to_do=( "$@" )
  (
    set -eo pipefail
    local -a pem=()
    local line
    while read -r line; do
      pem+=( "${line}" )
      if [[ "${line}" == "-----END "*"-----" ]]; then
        (
          for L in "${pem[@]}"; do
            echo "${L}";
          done \
        ) | "${what_to_do[@]}"
        pem=()
      fi
    done
  )
}

# Adds PEMs to a Java trust store so that the certificates will be trusted in future.
# stdin = zero or more pems
function make_java_trust_certs() {
  for_all_pems make_java_trust_cert "$@"
}

# Echos all non-empty args to stdout
# $* = things to output
# stdout = all non-empty args, one per line
function concatenate() {
  local arg
  for arg; do
    if [[ -n "${arg}" ]]; then
      echo "${arg}"
    fi
  done
}

DEFAULT_SERVER_DIR=/opt/ol/wlp/usr/servers/defaultServer
DB_NAME="${DB_NAME:-"ISTORE"}"

TMP_SECRETS=/tmp/i2acerts
rm -rf "${TMP_SECRETS}"
mkdir "${TMP_SECRETS}"
KEYSTORE_PASS="$(openssl rand -base64 16)"
export KEYSTORE_PASS

CA_CER="${TMP_SECRETS}/CA.cer"
concatenate \
  "${SSL_OUTBOUND_CA_CERTIFICATE}" \
  "${SSL_CA_CERTIFICATE}" \
  "${SSL_ADDITIONAL_TRUST_CERTIFICATES}" \
  >"${CA_CER}"

TRUSTSTORE="${TMP_SECRETS}/truststore.p12"
concatenate \
  "${SSL_CA_CERTIFICATE}" \
  "${SSL_ADDITIONAL_TRUST_CERTIFICATES}" \
| make_java_trust_certs "${TRUSTSTORE}" KEYSTORE_PASS

if [[ -n "${APP_SECRETS}" ]]; then
  while read -r key value; do
    declare -x "$key"="$value"
  done < <(jq -r 'keys[] as $k | "\($k) \(.[$k])"' < <(echo "${APP_SECRETS}"))
fi

if [[ "${SERVER_SSL:-}" == "true" || "${SOLR_ZOO_SSL_CONNECTION:-}" == "true" || "${GATEWAY_SSL_CONNECTION:-}" == "true" ]]; then
  if [[ -z "${SSL_CA_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_CA_CERTIFICATE"
    exit 1
  fi
fi

if [[ "${GATEWAY_SSL_CONNECTION:-}" == "true" ]]; then
  if [[ -z "${SSL_OUTBOUND_PRIVATE_KEY}" || -z "${SSL_OUTBOUND_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_OUTBOUND_PRIVATE_KEY SSL_OUTBOUND_CERTIFICATE"
    exit 1
  fi
  OUT_KEY="${TMP_SECRETS}/out_server.key"
  OUT_CER="${TMP_SECRETS}/out_server.cer"
  OUT_CA_CER="${TMP_SECRETS}/out_CA.cer"
  OUT_KEYSTORE="${TMP_SECRETS}/out_keystore.p12"
  OUT_TRUSTSTORE="${TMP_SECRETS}/out_truststore.p12"

  echo "${SSL_OUTBOUND_PRIVATE_KEY}" >"${OUT_KEY}"
  echo "${SSL_OUTBOUND_CERTIFICATE}" >"${OUT_CER}"

  if [[ -n "${SSL_OUTBOUND_CA_CERTIFICATE}" ]]; then
    echo "${SSL_OUTBOUND_CA_CERTIFICATE}" >"${OUT_CA_CER}"
    concatenate \
      "${SSL_OUTBOUND_CA_CERTIFICATE}" \
      "${SSL_ADDITIONAL_TRUST_CERTIFICATES}" \
    | make_java_trust_certs "${OUT_TRUSTSTORE}" KEYSTORE_PASS
    LIBERTY_OUT_TRUSTSTORE_LOCATION="${OUT_TRUSTSTORE}"
  else
    LIBERTY_OUT_TRUSTSTORE_LOCATION="${TRUSTSTORE}"
  fi

  openssl pkcs12 -export -in "${OUT_CER}" -inkey "${OUT_KEY}" -certfile "${CA_CER}" -passout env:KEYSTORE_PASS -out "${OUT_KEYSTORE}"

  export LIBERTY_OUT_KEYSTORE_LOCATION="${OUT_KEYSTORE}"
  export LIBERTY_OUT_TRUSTSTORE_PASSWORD="${KEYSTORE_PASS}"
  export LIBERTY_OUT_KEYSTORE_PASSWORD="${KEYSTORE_PASS}"

  export LIBERTY_OUT_TRUSTSTORE_LOCATION

  export LIBERTY_TRUSTSTORE_LOCATION="${TRUSTSTORE}"
  export LIBERTY_TRUSTSTORE_PASSWORD="${KEYSTORE_PASS}"
fi

if [[ "${SERVER_SSL:-}" == "true" || "${SOLR_ZOO_SSL_CONNECTION:-}" == "true" ]]; then
  if [[ -z "${SSL_PRIVATE_KEY}" || -z "${SSL_CERTIFICATE}" || -z "${SSL_CA_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE SSL_CA_CERTIFICATE"
    exit 1
  fi
  KEY="${TMP_SECRETS}/server.key"
  CER="${TMP_SECRETS}/server.cer"
  KEYSTORE="${TMP_SECRETS}/keystore.p12"

  echo "${SSL_PRIVATE_KEY}" >"${KEY}"
  echo "${SSL_CERTIFICATE}" >"${CER}"

  openssl pkcs12 -export -in "${CER}" -inkey "${KEY}" -certfile "${CA_CER}" -passout env:KEYSTORE_PASS -out "${KEYSTORE}"

  export LIBERTY_TRUSTSTORE_LOCATION="${TRUSTSTORE}"
  export LIBERTY_KEYSTORE_LOCATION="${KEYSTORE}"
  export LIBERTY_TRUSTSTORE_PASSWORD="${KEYSTORE_PASS}"
  export LIBERTY_KEYSTORE_PASSWORD="${KEYSTORE_PASS}"
fi

if [[ "${SERVER_SSL:-}" == "true" ]]; then
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

if [[ "${DB_SSL_CONNECTION:-}" == "true" ]]; then
  # Ensure the database-client code knows where to find the certificates
  if [[ "${DB_DIALECT:-}" == "postgres" ]]; then
    # Postgres expects a filename of a certificate as the truststore location
    # (see i2 docs for details).
    export "DB_TRUSTSTORE_LOCATION=${CA_CER}"
  else
    # The others need a Java truststore + password.
    export "DB_TRUSTSTORE_LOCATION=${TRUSTSTORE}"
    export "DB_TRUSTSTORE_PASSWORD=${KEYSTORE_PASS}"
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
    chmod +x "${file}"
    # shellcheck disable=SC1090
    . "${file}"
  fi
done

# Pass on to the real server run
exec "$@"
