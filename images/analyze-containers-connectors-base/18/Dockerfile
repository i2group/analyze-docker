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

FROM registry.access.redhat.com/ubi9/nodejs-18

# Bring global-scope args into the build stage
ARG revision
ARG version

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL name="Analyze Containers Connectors Base" \
  version="${version}" \
  revision="${revision}" \
  maintainer="i2 Group" \
  summary="Image for i2 Analyze Connectors with NodeJS and Red Hat's UBI minimal." \
  description="This image contains NodeJS JavaScript runtime and a stripped down Red Hat's UBI as the base OS." \
  license="MIT"

# Use root
# hadolint ignore=DL3002
USER root

# We want latest of all packages when building the image
# hadolint ignore=DL3013,DL3041
RUN set -eux; \
  dnf -y update \
  && dnf -y install \
  jq \
  python3.12-pip \
  # Ensure symlinks are created for the correct version of Pip
  && ln -sf /usr/bin/pip3.12 /usr/bin/pip3 \
  && ln -sf /usr/bin/pip3.12 /usr/bin/pip \
  # Clean up
  && dnf clean all \
  && pip3 install --no-cache-dir s3cmd;

# Switch back to non-root
USER default

COPY environment.sh /opt/environment.sh
