# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

ARG GRAFANA_VERSION=11.3.1
FROM grafana/grafana-enterprise:"${GRAFANA_VERSION}"

# Dynamic labels
ARG revision
ARG GRAFANA_VERSION=11.3.1

LABEL name="Grafana" \
  maintainer="i2 Group" \
  version="${GRAFANA_VERSION}" \
  revision="${revision}" \
  summary="Grafana image based on Grafana Enterprise." \
  description="Grafana is an interactive analytics and monitoring solution." \
  license="MIT"

COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY environment.sh /opt/environment.sh

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
