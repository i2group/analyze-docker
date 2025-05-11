# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

# Dynamic labels passed at build time into global-scope
# revision = CI build number or 'dev' for local builds
ARG revision
# version = image version = name of the directory this Dockerfile is in
ARG version

ARG GRAFANA_VERSION=10.2.2
FROM "grafana/grafana-enterprise:${GRAFANA_VERSION}"

# Bring global-scope args into the build stage
ARG revision
ARG version
ARG GRAFANA_VERSION

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
