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

# Passwords have to be hashed with bcrypt for prometheus
encoded_pass=$(echo "${PROMETHEUS_PASSWORD}" | htpasswd -niBC 10 "" | tr -d ':\n')
escaped_encoded_pass=$(printf '%s\n' "$encoded_pass" | sed -e 's/[\/&]/\\&/g')
export PROMETHEUS_PASSWORD="${escaped_encoded_pass}"

# Substitute environment variables
envsubst < /etc/prometheus/prometheus.yml > /etc/prometheus/prometheus.yml.tmp

# Replace original file with the new one
mv /etc/prometheus/prometheus.yml.tmp /etc/prometheus/prometheus.yml

# Substitute environment variables
envsubst < /etc/prometheus/web-config.yml > /etc/prometheus/web-config.yml.tmp

# Replace original file with the new one
mv /etc/prometheus/web-config.yml.tmp /etc/prometheus/web-config.yml
