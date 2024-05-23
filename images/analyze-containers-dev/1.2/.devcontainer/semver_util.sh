#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

# Ensure NOT to add the following line in this script since it will be sourced to current terminal
# set -e

# semver_util function
function semver_util() {
  npm_config_loglevel=error npx -y -q --package /opt/semver_util.tgz semver_util "$@" 2>/dev/null
}
