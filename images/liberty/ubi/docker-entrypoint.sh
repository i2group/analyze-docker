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
# $1 = certificate in pem format
# sets variables cert_hash, cert_subject, cert_sanitized_subject and cert_summary
# cert_hash = the certificate's hash according to openssl, or empty if the certificate is not readable
# cert_subject = the certificate's "subject" (usually including the CN) according to openssl, or empty if the certificate is not readable
# cert_sanitized_subject = cert_subject with dodgy characters turned into underscores
# cert_summary = human-readable description of the cert_content for use in error reports
function get_cert_details() {
  local -r cert_content="$1" # cert PEM
  # Ask openssl to parse it and give us its hash and subject
  # ... trimming off any newlines from the hash
  # ... and any non-printable characters from the subject
  cert_hash="$( openssl x509 -noout -hash <<<"${cert_content}" 2>/dev/null | tr -d '\n' || true )"
  if [[ -n "${cert_hash}" ]]; then
    cert_subject="$( openssl x509 -noout -subject <<<"${cert_content}" 2>/dev/null | sed 's,^subject=,,' | tr -d '\n' | tr --complement -d '[:print:]' )"
  else
    cert_subject=""
  fi
  # now turn all non-alphanumeric characters into underscores
  cert_sanitized_subject="$( tr -d '\n' <<<"${cert_subject}" | tr --complement '[:alnum:].-=' '_' )"
  # now build up a human-readable description
  local synopsis
  if [[ -n "${cert_subject}" && -n "${cert_hash}" ]]; then
    synopsis="certificate with subject ${cert_subject} and hash ${cert_hash}"
  else
    synopsis="non-x509-pem data"
  fi
  case "$(wc -l <<<"${cert_content}")" in
    0|1|2|3|4)
      synopsis+=" '$(awk '{printf "%s\\n", $0}' <<<"${cert_content}" | sed 's,\\n$,,')'"
      ;;
    *)
      synopsis+=" starting $(head -2 <<<"${cert_content}" | awk '{printf "%s\\n", $0}' | sed 's,\\n$,,')"
      synopsis+=" ending $(tail -2 <<<"${cert_content}" | awk '{printf "%s\\n", $0}' | sed 's,\\n$,,')"
      ;;
  esac
  cert_summary="${synopsis}"
}

# Adds a PEM to a Java trust store so that the certificate will be trusted in future.
# If the PEM is already there then return success.
# stdin = cert in pem format
# $1 = certificate in pem format
# $2 = filename of the Java keystore to add the certificate to
# $3 = name of the env var containing the Java keystore's password.
# Exit code 0 if the PEM is now in the truststore (or it was already there)
# Exit code 1 if the PEM is not in the truststore
function make_java_trust_cert() {
  local -r pem="${1}"
  local -r java_keystore_filename="${2}"
  local -r java_keystore_keypass_env_name="${3}"
  local cert_content cert_hash cert_subject cert_sanitized_subject cert_summary
  get_cert_details "${pem}"
  if [[ -z "${cert_hash}" ]]; then # not a valid certificate
    echo "ERROR: Unable to import ${cert_summary} into trust store ${java_keystore_filename}:"
    echo "This is not a certificate."
    return 1
  fi >&2
  local -r cert_alias="${cert_sanitized_subject}.${cert_hash}"
  # keytool can return success if it fails.
  # We need to check its output to see if it really succeeded or not.
  local keytool_output
  keytool_output="$(keytool \
    -importcert \
    -noprompt \
    -alias "${cert_alias}" \
    -keystore "${java_keystore_filename}" \
    -storepass:env "${java_keystore_keypass_env_name}" \
    -storetype PKCS12 \
    <<<"${pem}" \
    2>&1 \
    || true)"
  # If the certificate is already in the keystore then we get told something like:
  #   keytool error: java.lang.Exception: Certificate not imported, alias <...> already exists
  if [[ "${keytool_output}" = *"alias <${cert_alias}> already exists" ]]; then
    return 0 # this PEM is already trusted
  fi
  # If the certificate was added successfully, we get told:
  #   Certificate was added to keystore
  # ... so if we see anything else, that's an error.
  if [[ "${keytool_output}" != "Certificate was added to keystore" ]]; then
    echo "ERROR: Failed to import ${cert_summary} as alias ${cert_alias} into trust store ${java_keystore_filename}:"
    echo "${keytool_output}"
    return 1
  fi >&2
}

# Adds PEMs to a Java trust store so that the certificates will be trusted in future.
# $1 = filename of the Java keystore to add the certificate to
# $2 = name of the env var containing the Java keystore's password.
# $3 onwards = PEMs to be trusted
# Any empty PEM arguments will be ignored
function make_java_trust_certs() {
  local -r java_keystore_filename="${1}"
  shift
  local -r java_keystore_keypass_env_name="${1}"
  shift
  local arg
  for arg; do
    if [[ -n "${arg}" ]]; then
      make_java_trust_cert "${arg}" "${java_keystore_filename}" "${java_keystore_keypass_env_name}"
    fi
  done
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
make_java_trust_certs "${TRUSTSTORE}" KEYSTORE_PASS \
  "${SSL_CA_CERTIFICATE}" \
  "${SSL_ADDITIONAL_TRUST_CERTIFICATES}"

if [[ -n "${APP_SECRETS}" && "${APP_SECRETS}" != "None" ]]; then
  while read -r key value; do
    declare -x "$key"="$value"
  done < <(jq -r 'keys[] as $k | "\($k) \(.[$k])"' < <(echo "${APP_SECRETS}"))
fi

if [[ "${SERVER_SSL:-}" == "true" || "${SOLR_ZOO_SSL_CONNECTION:-}" == "true" || "${GATEWAY_SSL_CONNECTION:-}" == "true" ]]; then
  if [[ -z "${SSL_CA_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_CA_CERTIFICATE"
    exit 1
  fi >&2
fi

if [[ "${GATEWAY_SSL_CONNECTION:-}" == "true" ]]; then
  if [[ -z "${SSL_OUTBOUND_PRIVATE_KEY}" || -z "${SSL_OUTBOUND_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_OUTBOUND_PRIVATE_KEY SSL_OUTBOUND_CERTIFICATE"
    exit 1
  fi >&2
  OUT_KEY="${TMP_SECRETS}/out_server.key"
  OUT_CER="${TMP_SECRETS}/out_server.cer"
  OUT_CA_CER="${TMP_SECRETS}/out_CA.cer"
  OUT_KEYSTORE="${TMP_SECRETS}/out_keystore.p12"
  OUT_TRUSTSTORE="${TMP_SECRETS}/out_truststore.p12"

  echo "${SSL_OUTBOUND_PRIVATE_KEY}" >"${OUT_KEY}"
  echo "${SSL_OUTBOUND_CERTIFICATE}" >"${OUT_CER}"

  if [[ -n "${SSL_OUTBOUND_CA_CERTIFICATE}" ]]; then
    echo "${SSL_OUTBOUND_CA_CERTIFICATE}" >"${OUT_CA_CER}"
    make_java_trust_certs "${OUT_TRUSTSTORE}" KEYSTORE_PASS \
      "${SSL_OUTBOUND_CA_CERTIFICATE}" \
      "${SSL_ADDITIONAL_TRUST_CERTIFICATES}"
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
  fi >&2
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
