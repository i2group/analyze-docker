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

. /environment.sh

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

TMP_SECRETS="/tmp/i2acerts"
KEY="${TMP_SECRETS}/server.key"
CER="${TMP_SECRETS}/server.cer"
CA_CER="${TMP_SECRETS}/CA.cer"
KEYSTORE="${TMP_SECRETS}/keystore.p12"
TRUSTSTORE="${TMP_SECRETS}/truststore.p12"

# If ssl is configured re/create new temporary certificate stores and passwords
if [[ "${SERVER_SSL}" == "true" ]]; then
  file_env 'SSL_PRIVATE_KEY'
  file_env 'SSL_CERTIFICATE'
  file_env 'SSL_CA_CERTIFICATE'
  if [[ -z "${SSL_PRIVATE_KEY}" || -z "${SSL_CERTIFICATE}" || -z "${SSL_CA_CERTIFICATE}" || -z "${ZOO_SECURE_CLIENT_PORT}" ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE SSL_CA_CERTIFICATE ZOO_SECURE_CLIENT_PORT"
    exit 1
  fi
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
  run_quietly keytool -importcert -noprompt -alias ca -keystore "${TRUSTSTORE}" -file "${CA_CER}" -storepass:env KEYSTORE_PASS -storetype PKCS12

  # Construct the JVM flags for a secure ZK
  JVMFLAGS="${JVMFLAGS} -Dzookeeper.ssl.trustStore.password=${KEYSTORE_PASS} -Dzookeeper.ssl.keyStore.password=${KEYSTORE_PASS}"
  JVMFLAGS="${JVMFLAGS} -Dzookeeper.ssl.quorum.trustStore.password=${KEYSTORE_PASS} -Dzookeeper.ssl.quorum.keyStore.password=${KEYSTORE_PASS}"
  export JVMFLAGS
else
  if [[ -z "${ZOO_CLIENT_PORT}" ]]; then
    echo "Missing environment variables. Please check ZOO_CLIENT_PORT"
    exit 1
  fi
fi
# Generate the config only if it doesn't exist
if [[ ! -f "$ZOO_CONF_DIR/zoo.cfg" ]]; then
  CONFIG="$ZOO_CONF_DIR/zoo.cfg"
  {
    echo "dataDir=$ZOO_DATA_DIR"
    echo "dataLogDir=$ZOO_DATA_LOG_DIR"

    echo "tickTime=$ZOO_TICK_TIME"
    echo "initLimit=$ZOO_INIT_LIMIT"
    echo "syncLimit=$ZOO_SYNC_LIMIT"

    echo "autopurge.snapRetainCount=$ZOO_AUTOPURGE_SNAPRETAINCOUNT"
    echo "autopurge.purgeInterval=$ZOO_AUTOPURGE_PURGEINTERVAL"
    echo "maxClientCnxns=$ZOO_MAX_CLIENT_CNXNS"
    echo "standaloneEnabled=$ZOO_STANDALONE_ENABLED"
    echo "admin.enableServer=$ZOO_ADMINSERVER_ENABLED"

    echo "serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory"

  } >>"$CONFIG"

  if [[ "${SERVER_SSL}" == "true" ]]; then
    {
      echo "ssl.trustStore.location=${TRUSTSTORE}"
      echo "ssl.keyStore.location=${KEYSTORE}"
      echo "sslQuorum=true"
      echo "ssl.quorum.trustStore.location=${TRUSTSTORE}"
      echo "ssl.quorum.keyStore.location=${KEYSTORE}"
      echo "secureClientPort=$ZOO_SECURE_CLIENT_PORT"
      echo "admin.portUnification=true"
    } >>"$CONFIG"
  else
    echo "clientPort=$ZOO_CLIENT_PORT" >>"$CONFIG"
  fi

  for server in $ZOO_SERVERS; do
    echo "$server" >>"$CONFIG"
  done

  if [[ -n "$ZOO_4LW_COMMANDS_WHITELIST" ]]; then
    echo "4lw.commands.whitelist=$ZOO_4LW_COMMANDS_WHITELIST" >>"$CONFIG"
  fi

  for cfg_extra_entry in $ZOO_CFG_EXTRA; do
    echo "$cfg_extra_entry" >>"$CONFIG"
  done
fi

# Write myid only if it doesn't exist
if [[ ! -f "$ZOO_DATA_DIR/myid" ]]; then
  echo "${ZOO_MY_ID:-1}" >"$ZOO_DATA_DIR/myid"
fi

exec "$@"
