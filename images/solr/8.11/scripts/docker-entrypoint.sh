#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

# docker-entrypoint for docker-solr

set -e

# Clear some variables that we don't want runtime
unset SOLR_USER SOLR_UID SOLR_GROUP SOLR_GID \
  SOLR_CLOSER_URL SOLR_DIST_URL SOLR_ARCHIVE_URL SOLR_DOWNLOAD_URL SOLR_DOWNLOAD_SERVER SOLR_KEYS SOLR_SHA512

if [[ "$VERBOSE" == "yes" || "${DEBUG}" == "true" ]]; then
  set -x
fi

if [[ -v SOLR_PORT ]] && ! grep -E -q '^[0-9]+$' <<<"${SOLR_PORT:-}"; then
  SOLR_PORT=8983
  export SOLR_PORT
fi

# Essential for running Solr
init-var-solr

# when invoked with e.g.: docker run solr -help
if [ "${1:0:1}" == '-' ]; then
  set -- solr-foreground "$@"
fi

# Secrets injection
. environment.sh

# Runs a command, suppressing all output UNLESS the command fails
# If the command fails, it'll be reported to stderr.
# $@ = the command to run, including all arguments.
# On success, returns 0 and outputs nothing.
# On failure, returns the command's exit code and outputs to stderr.
function run_quietly() {
  local output exit_code
  if output=$( "$@" 2>&1 ); then
    return 0
  else
    exit_code="$?"
  fi
  echo "ERROR: $* failed, exit code ${exit_code}" >&2
  if [[ -n "${output}" ]]; then
    echo "${output}" >&2
  fi
  return "${exit_code}"
}

if [[ "${SERVER_SSL}" == "true" || "${SOLR_ZOO_SSL_CONNECTION}" == "true" ]]; then
  file_env 'SSL_PRIVATE_KEY'
  file_env 'SSL_CERTIFICATE'
  file_env 'SSL_CA_CERTIFICATE'
  if [[ -z "${SSL_PRIVATE_KEY}" || -z "${SSL_CERTIFICATE}" || -z "${SSL_CA_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE SSL_CA_CERTIFICATE"
    exit 1
  fi
  TMP_SECRETS="/tmp/i2acerts"
  KEY="${TMP_SECRETS}/server.key"
  CER="${TMP_SECRETS}/server.cer"
  CA_CER="${TMP_SECRETS}/CA.cer"
  KEYSTORE="${TMP_SECRETS}/keystore.p12"
  TRUSTSTORE="${TMP_SECRETS}/truststore.p12"
  KEYSTORE_PASS="$(openssl rand -base64 16)"
  export KEYSTORE_PASS

  if [[ -d "${TMP_SECRETS}" ]]; then
    rm -r "${TMP_SECRETS}"
  fi
  mkdir -p "${TMP_SECRETS}"

  echo "${SSL_PRIVATE_KEY}" >"${KEY}"
  echo "${SSL_CERTIFICATE}" >"${CER}"
  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"

  run_quietly openssl pkcs12 -export -in "${CER}" -inkey "${KEY}" -certfile "${CA_CER}" -passout env:KEYSTORE_PASS -out "${KEYSTORE}"

  OUTPUT=$(keytool -importcert -noprompt -alias ca -keystore "${TRUSTSTORE}" -file ${CA_CER} -storepass:env KEYSTORE_PASS -storetype PKCS12 2>&1)
  if [[ "$OUTPUT" != "Certificate was added to keystore" ]]; then
    echo "$OUTPUT"
    exit 1
  fi
fi

file_env 'ZOO_DIGEST_USERNAME'
file_env 'ZOO_DIGEST_PASSWORD'
file_env 'ZOO_DIGEST_READONLY_USERNAME'
file_env 'ZOO_DIGEST_READONLY_PASSWORD'
file_env 'SOLR_ADMIN_DIGEST_USERNAME'
file_env 'SOLR_ADMIN_DIGEST_PASSWORD'

if [[ "${SOLR_ZOO_SSL_CONNECTION}" == "true" ]]; then

  ZOO_SSL_KEY_STORE_LOCATION="${KEYSTORE}"
  ZOO_SSL_TRUST_STORE_LOCATION="${TRUSTSTORE}"
  ZOO_SSL_KEY_STORE_PASSWORD="${KEYSTORE_PASS}"
  ZOO_SSL_TRUST_STORE_PASSWORD="${KEYSTORE_PASS}"

  export ZOO_SSL_KEY_STORE_LOCATION
  export ZOO_SSL_TRUST_STORE_LOCATION
  export ZOO_SSL_KEY_STORE_PASSWORD
  export ZOO_SSL_TRUST_STORE_PASSWORD

  SECURE_ZK_FLAGS="-Dzookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty \
  -Dzookeeper.client.secure=true \
  -Dzookeeper.ssl.trustStore.location=${ZOO_SSL_TRUST_STORE_LOCATION} \
  -Dzookeeper.ssl.keyStore.location=${ZOO_SSL_KEY_STORE_LOCATION} \
  -Dzookeeper.ssl.trustStore.password=${ZOO_SSL_TRUST_STORE_PASSWORD} \
  -Dzookeeper.ssl.keyStore.password=${ZOO_SSL_KEY_STORE_PASSWORD}"

  SOLR_SSL_TRUST_STORE="${TRUSTSTORE}"
  SOLR_SSL_TRUST_STORE_PASSWORD="${KEYSTORE_PASS}"
  export SOLR_SSL_TRUST_STORE
  export SOLR_SSL_TRUST_STORE_PASSWORD
fi

if [[ "${SERVER_SSL}" == "true" ]]; then
  SOLR_SSL_ENABLED="true"
  SOLR_SSL_KEY_STORE="${KEYSTORE}"
  SOLR_SSL_KEY_STORE_PASSWORD="${KEYSTORE_PASS}"
  SOLR_SSL_TRUST_STORE="${TRUSTSTORE}"
  SOLR_SSL_TRUST_STORE_PASSWORD="${KEYSTORE_PASS}"
  export SOLR_SSL_ENABLED
  export SOLR_SSL_KEY_STORE
  export SOLR_SSL_KEY_STORE_PASSWORD
  export SOLR_SSL_TRUST_STORE
  export SOLR_SSL_TRUST_STORE_PASSWORD
fi

if [[ -f /opt/configuration/i2-tools/classes/log4j2.xml ]]; then
  cp /opt/configuration/i2-tools/classes/log4j2.xml /opt/solr/server/resources/log4j2-console.xml
fi

SOLR_ZK_CREDS_AND_ACLS="-DzkACLProvider=org.apache.solr.common.cloud.VMParamsAllAndReadonlyDigestZkACLProvider \
-DzkCredentialsProvider=org.apache.solr.common.cloud.VMParamsSingleSetCredentialsDigestZkCredentialsProvider \
-DzkDigestUsername=${ZOO_DIGEST_USERNAME} -DzkDigestPassword=${ZOO_DIGEST_PASSWORD} \
-DzkDigestReadonlyUsername=${ZOO_DIGEST_READONLY_USERNAME} -DzkDigestReadonlyPassword=${ZOO_DIGEST_READONLY_PASSWORD}"

SOLR_ZK_CREDS_AND_ACLS="${SOLR_ZK_CREDS_AND_ACLS} ${SECURE_ZK_FLAGS}"
SOLR_OPTS="${SOLR_OPTS} ${SOLR_ZK_CREDS_AND_ACLS}"
SOLR_OPTS="${SOLR_OPTS} -Dsolr.sharedLib=/opt/i2-plugin/lib"
export SOLR_OPTS
export SOLR_ZK_CREDS_AND_ACLS

# execute command passed in as arguments.
# The Dockerfile has specified the PATH to include
# /opt/solr/bin (for Solr) and /opt/docker-solr/scripts (for our scripts
# like solr-foreground, solr-create, solr-precreate, solr-demo).
# Note: if you specify "solr", you'll typically want to add -f to run it in
# the foreground.
exec "$@"
