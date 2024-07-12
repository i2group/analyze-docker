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

if [ -f "/tmp/prometheus/prometheus.yml" ]; then
  cp /tmp/prometheus/prometheus.yml /etc/prometheus/prometheus.yml
else
  cp /etc/prometheus-templates/prometheus.yml /etc/prometheus/prometheus.yml
fi

# We can't use envsubst to replace variables in the prometheus.yml file because it contains $ signs
sed -ci \
  -e "s~\${PROMETHEUS_SCHEME}~${PROMETHEUS_SCHEME}~g" \
  -e "s~\${LIBERTY_SCHEME}~${LIBERTY_SCHEME}~g" \
  -e "s~\${LIBERTY_ADMIN_USERNAME}~${LIBERTY_ADMIN_USERNAME}~g" \
  -e "s~\${LIBERTY_ADMIN_PASSWORD}~${LIBERTY_ADMIN_PASSWORD}~g" \
  -e "s~\${PROMETHEUS_USERNAME}~${PROMETHEUS_USERNAME}~g" \
  -e "s~\${PROMETHEUS_PASSWORD}~${PROMETHEUS_PASSWORD}~g" \
  -e "s~\${LIBERTY1_STANZA}~${LIBERTY1_STANZA}~g" \
  -e "s~\${LIBERTY2_STANZA}~${LIBERTY2_STANZA}~g" \
  "/etc/prometheus/prometheus.yml"

# Passwords have to be hashed with bcrypt for web-config.yml
encoded_pass=$(echo "${PROMETHEUS_PASSWORD}" | htpasswd -niBC 10 "" | tr -d ':\n')
escaped_encoded_pass=$(printf '%s\n' "$encoded_pass" | sed -e 's/[\/&]/\\&/g')

sed -ci \
  -e "s/\${PROMETHEUS_USERNAME}/${PROMETHEUS_USERNAME}/g" \
  -e "s/\${PROMETHEUS_PASSWORD}/${escaped_encoded_pass}/g" \
  "/etc/prometheus/web-config.yml"
