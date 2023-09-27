#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

if [[ "${SERVER_SSL}" == "true" ]]; then
  prometheus_scheme="https"
else
  prometheus_scheme="http"
fi

if [[ "${LIBERTY_SSL_CONNECTION}" == "true" ]]; then
  liberty_scheme="https"
else
  liberty_scheme="http"
fi

if [ -f "/tmp/prometheus/prometheus.yml" ]; then
  cp /tmp/prometheus/prometheus.yml /etc/prometheus/prometheus.yml
else
  cp /etc/prometheus-templates/prometheus.yml /etc/prometheus/prometheus.yml
fi

sed -ci \
  -e "s~\${PROMETHEUS_SCHEME}~${prometheus_scheme}~g" \
  -e "s~\${LIBERTY_SCHEME}~${liberty_scheme}~g" \
  -e "s~\${LIBERTY_ADMIN_USERNAME}~${LIBERTY_ADMIN_USERNAME}~g" \
  -e "s~\${LIBERTY_ADMIN_PASSWORD}~${LIBERTY_ADMIN_PASSWORD}~g" \
  -e "s~\${PROMETHEUS_USERNAME}~${PROMETHEUS_USERNAME}~g" \
  -e "s~\${PROMETHEUS_PASSWORD}~${PROMETHEUS_PASSWORD}~g" \
  "/etc/prometheus/prometheus.yml"

# Passwords have to be hashed with bcrypt for prometheus
encoded_pass=$(echo "${PROMETHEUS_PASSWORD}" | htpasswd -niBC 10 "" | tr -d ':\n')
escaped_encoded_pass=$(printf '%s\n' "$encoded_pass" | sed -e 's/[\/&]/\\&/g')
sed -ci \
  -e "s/\${PROMETHEUS_USERNAME}/${PROMETHEUS_USERNAME}/g" \
  -e "s/\${PROMETHEUS_PASSWORD}/${escaped_encoded_pass}/g" \
  "/etc/prometheus/web-config.yml"
