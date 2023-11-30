#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

# If user not root ensure to give correct permissions before start
if [ -n "${GROUP_ID}" ] && [ "${GROUP_ID}" != "0" ]; then
  groupmod -og "${GROUP_ID}" "${USERNAME}" >/dev/null
  usermod -u "${USER_ID}" -g "${GROUP_ID}" "${USERNAME}" >/dev/null
  chown -R "${USERNAME}" "${HOME}"
  if [[ -n "${ANALYZE_AWS_SAAS_DEPLOYMENT_ROOT_DIR}" ]]; then
    chown -R "${USER_ID}:${GROUP_ID}" "${ANALYZE_AWS_SAAS_DEPLOYMENT_ROOT_DIR}"
  fi
  if [[ -n "${ANALYZE_CONTAINERS_ROOT_DIR}" ]]; then
    chown -R "${USER_ID}:${GROUP_ID}" "${ANALYZE_CONTAINERS_ROOT_DIR}"
  fi
fi

/usr/local/share/docker-init.sh "$@"
