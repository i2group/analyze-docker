# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2026)
#
# SPDX short identifier: MIT

# Dynamic labels passed at build time into global-scope
# revision = CI build number or 'dev' for local builds
ARG revision
# version = image version = name of the directory this Dockerfile is in
ARG version

FROM registry.access.redhat.com/ubi9/nodejs-${version}-minimal

# Bring global-scope args into the build stage
ARG revision
ARG version

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL name="Analyze Containers Connectors Base" \
  version="${version}" \
  revision="${revision}" \
  maintainer="i2 Group" \
  summary="Image for i2 Analyze Connectors with NodeJS ${version} and Red Hat's UBI minimal." \
  description="This image contains NodeJS ${version} JavaScript runtime and a stripped down Red Hat's UBI as the base OS." \
  license="MIT"

COPY environment.sh /opt/environment.sh
