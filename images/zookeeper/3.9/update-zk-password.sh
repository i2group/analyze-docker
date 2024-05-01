#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

set -e

# In this script we want to pass multi-line string to the zkCli.sh command
# and we use the heredoc (EOF) syntax for that, so it doesn't include command in the output.

# Set new zk digest password
/apache-zookeeper-bin/bin/zkCli.sh -server "${ZK_HOSTNAME}" <<EOF >/dev/null
addauth digest ${ZOO_DIGEST_USERNAME}:${ZOO_DIGEST_PASSWORD_OLD}
ls /is_cluster
addauth digest ${ZOO_DIGEST_USERNAME}:${ZOO_DIGEST_PASSWORD_NEW}
setAcl -R /is_cluster auth:${ZOO_DIGEST_USERNAME}:${ZOO_DIGEST_PASSWORD_NEW}:cdrwa
setAcl -R /i2 auth:${ZOO_DIGEST_USERNAME}:${ZOO_DIGEST_PASSWORD_NEW}:cdrwa
EOF

echo "Zk digest password updated successfully"
