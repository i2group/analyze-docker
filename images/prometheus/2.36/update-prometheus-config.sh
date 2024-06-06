#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

set -e

if [[ "${SERVER_SSL}" == "true" ]]; then
  PROMETHEUS_SCHEME="https"
else
  PROMETHEUS_SCHEME="http"
fi

if [[ "${LIBERTY_SSL_CONNECTION}" == "true" ]]; then
  LIBERTY_SCHEME="https"
else
  LIBERTY_SCHEME="http"
fi
export PROMETHEUS_SCHEME LIBERTY_SCHEME

if [ -f "/tmp/prometheus/prometheus.yml" ]; then
  cp /tmp/prometheus/prometheus.yml /etc/prometheus/prometheus.yml
else
  cp /etc/prometheus-templates/prometheus.yml /etc/prometheus/prometheus.yml
fi

NON_ENCRYPTED_PASSWORD="${PROMETHEUS_PASSWORD}"

# Substitute environment variables
envsubst < /etc/prometheus/prometheus.yml > /etc/prometheus/prometheus.yml.tmp

# Replace original file with the new one
mv /etc/prometheus/prometheus.yml.tmp /etc/prometheus/prometheus.yml

# Passwords have to be hashed with bcrypt for web-config.yml
encoded_pass=$(echo "${NON_ENCRYPTED_PASSWORD}" | htpasswd -niBC 10 "" | tr -d ':\n')
export PROMETHEUS_PASSWORD="${encoded_pass}"

# Substitute environment variables
envsubst < /etc/prometheus/web-config.yml > /etc/prometheus/web-config.yml.tmp

# Replace original file with the new one
mv /etc/prometheus/web-config.yml.tmp /etc/prometheus/web-config.yml

export PROMETHEUS_PASSWORD="${NON_ENCRYPTED_PASSWORD}"
