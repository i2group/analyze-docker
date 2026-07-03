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

INTERNAL_STORAGE_PATH="${WORKSPACE}/data/connectorStorage"
INTERNAL_CUSTOM_FUNCTIONS_PATH="${WORKSPACE}/dist/custom_functions"
# Add symlinks to /data and /custom-functions directory
if [[ -d "/data" ]]; then
  rm -rf "${INTERNAL_STORAGE_PATH}"
  mkdir -p "${WORKSPACE}/data"
  ln -s "/data" "${INTERNAL_STORAGE_PATH}"
fi
if [[ -d "/custom-functions" ]]; then
  TEMP_FOLDER="$(mktemp -d)"
  if [[ -d "${INTERNAL_CUSTOM_FUNCTIONS_PATH}" ]]; then
    cp -r "${INTERNAL_CUSTOM_FUNCTIONS_PATH}/." "${TEMP_FOLDER}"
    rm -rf "${INTERNAL_CUSTOM_FUNCTIONS_PATH}"
  fi
  ln -s "/custom-functions" "${INTERNAL_CUSTOM_FUNCTIONS_PATH}"
  # For loop to copy the content back to the custom-functions directory if file does not exist
  if [ "$(ls -A "${TEMP_FOLDER}")" ]; then
    for file in "${TEMP_FOLDER}"/*; do
      filename=$(basename "${file}")
      if [[ ! -f "${INTERNAL_CUSTOM_FUNCTIONS_PATH}/${filename}" ]]; then
        cp -r "${TEMP_FOLDER}/${filename}" "${INTERNAL_CUSTOM_FUNCTIONS_PATH}"
      fi
    done
  fi
  rm -rf "${TEMP_FOLDER}"
fi

TMP_SECRETS="/tmp/i2acerts"
if [[ ! -d "${TMP_SECRETS}" ]]; then
  mkdir -p "${TMP_SECRETS}"
fi

# This could be set without SSL enabled
file_env 'SSL_ADDITIONAL_TRUST_CERTIFICATES'

if [[ "${SSL_ADDITIONAL_TRUST_CERTIFICATES}" == "None" ]]; then
  SSL_ADDITIONAL_TRUST_CERTIFICATES=""
fi

NODE_EXTRA_CA_CERTS="${TMP_SECRETS}/additional-trust-certificates.cer"
echo "${SSL_ADDITIONAL_TRUST_CERTIFICATES}" >"${NODE_EXTRA_CA_CERTS}"

if [[ "${SERVER_SSL}" == "true" ]]; then
  file_env 'SSL_PRIVATE_KEY'
  file_env 'SSL_CERTIFICATE'
  file_env 'SSL_CA_CERTIFICATE'

  if [[ -z "${SSL_PRIVATE_KEY}" || -z "${SSL_CERTIFICATE}" || -z "${SSL_CA_CERTIFICATE}" ]]; then
    echo "Missing security environment variables. Please check SSL_PRIVATE_KEY SSL_CERTIFICATE SSL_CA_CERTIFICATE"
    exit 1
  fi

  KEY="${TMP_SECRETS}/server.key"
  CER="${TMP_SECRETS}/server.cer"
  CA_CER="${TMP_SECRETS}/CA.cer"

  echo "${SSL_PRIVATE_KEY}" >"${KEY}"
  echo "${SSL_CERTIFICATE}" >"${CER}"
  echo "${SSL_CA_CERTIFICATE}" >"${CA_CER}"
fi

file_env 'JWT_CERTIFICATE'

if [[ -n "${JWT_CERTIFICATE}" ]]; then
  JWT_CER="${TMP_SECRETS}/jwt_sign.cer"
  echo "${JWT_CERTIFICATE}" >"${JWT_CER}"
fi

# If user not root ensure to give correct permissions before start
if [ -n "${GROUP_ID}" ] && [ "${GROUP_ID}" != "0" ]; then
  groupmod -o -g "${GROUP_ID}" "${USER}" &>/dev/null
  usermod -u "${USER_ID}" -g "${GROUP_ID}" "${USER}" &>/dev/null
fi
chown -R "${USER_ID}:${GROUP_ID}" \
  "${WORKSPACE}/data" \
  "${INTERNAL_CUSTOM_FUNCTIONS_PATH}" \
  "${TMP_SECRETS}"
[[ -d "/data" ]] && chown -R "${USER_ID}:${GROUP_ID}" "/data"
[[ -d "/custom-functions" ]] && chown -R "${USER_ID}:${GROUP_ID}" "/custom-functions"

/usr/local/share/docker-init.sh /usr/local/bin/gosu "${USER}" "$@"
