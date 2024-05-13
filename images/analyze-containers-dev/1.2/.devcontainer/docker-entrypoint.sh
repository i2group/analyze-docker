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

# If user not root ensure to give correct permissions before start
if [ -n "${GROUP_ID}" ] && [ "${GROUP_ID}" != "0" ]; then
  groupmod -og "${GROUP_ID}" "${USERNAME}" >/dev/null
  usermod -u "${USER_ID}" -g "${GROUP_ID}" "${USERNAME}" >/dev/null
fi

/usr/local/share/docker-init.sh "$@"
