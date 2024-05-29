#!/bin/bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)

# Adds certificates to a Java trust store using keytool
# $1 = where the certificates came from
# $2 = the certificate data in PEM format
# $3 = the filename of the Java keystore
# $4 = the environment variable holding the Java keystore's storepass
function add_trusted_certificates() {
  local name="$1"
  local pem_data="$2"
  local trust_store="$3"
  local storepass_env_name="$4"
  local cert_count
  cert_count=$(grep -c -- '-----END ' <<<"${pem_data}")
  # For every cert in the PEM file, extract it and import into the JKS keystore
  # awk command: step 1, if line is in the desired cert, print the line
  #              step 2, increment counter when last line of cert is found
  local N alias this_cert
  for N in $(seq 0 $(("${cert_count}" - 1))); do
    alias="${name}-${N}"
    this_cert=$(awk "n==$N { print }; /-----END / { n++ }" <<<"${pem_data}")
    run_quietly keytool -noprompt -import -trustcacerts \
      -alias "${alias}" -keystore "${trust_store}" -storepass:env "${storepass_env_name}" -storetype PKCS12 \
      <<<"${this_cert}"
  done
}

# Adds PEMs to a Java trust store so that the certificates will be trusted in future.
# $1 = filename of the Java keystore to add the certificate to
# $2 = name of the env var containing the Java keystore's password.
# $3+$4 onwards = pairs of arguments: internal name for PEM data, PEM data
# Note: pairs with empty PEM data will be skipped.
function add_to_java_keystore() {
  local -r keystore_file="$1"
  local -r storepass_env_name="$2"
  shift 2
  local name pem_data
  while [[ "$#" -gt 0 ]]; do
    name="$1"
    pem_data="$2"
    shift 2
    if [[ -n "${pem_data}" ]]; then
      add_trusted_certificates "${name}" "${pem_data}" "${keystore_file}" "${storepass_env_name}"
    fi
  done
}

# Outputs zero or more certificates in PEM format into a file.
# $1 = the file to output to
# $2+$3 onwards = pairs of arguments: internal name for PEM data, PEM data
# Note: pairs with empty PEM data will be skipped.
function add_to_pem_file() {
  local pem_file="$1"
  shift
  local name pem_data
  while [[ "$#" -gt 0 ]]; do
    name="$1"
    pem_data="$2"
    shift 2
    if [[ -n "${pem_data}" ]]; then
      echo "# ${name}" >>"${pem_file}"
      echo "${pem_data}" >>"${pem_file}"
    fi
  done
}
