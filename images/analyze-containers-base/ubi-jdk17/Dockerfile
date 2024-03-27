# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

FROM eclipse-temurin:17-ubi9-minimal

# Dynamic labels
ARG revision

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL name="Analyze Containers Base" \
  version="ubi" \
  revision="${revision}" \
  maintainer="i2 Group" \
  summary="Image for Analyze Containers deployment with OpenJDK 17 and Red Hat's UBI minimal." \
  description="This image contains OpenJDK 17 Eclipse Temurin runtime and Red Hat's UBI as the base OS." \
  license="MIT"

ARG GOSU_VERSION=1.17

# Use root but change at runtime with GOSU
# hadolint ignore=DL3002
USER root

# Install shared packages
RUN set -eux; \
  microdnf -y update; \
  microdnf -y install \
  shadow-utils \
  findutils \
  tar \
  gzip \
  ca-certificates \
  gnupg \
  rsync \
  openssl; \
  microdnf clean all;

# GOSU layer
RUN ARCH="$(uname -m)"; \
  if [ "${ARCH}" != "aarch64" ] && [ "${ARCH}" != "arm64" ]; then \
  curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64"; \
  else curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-arm64"; fi; \
  chmod +x /usr/local/bin/gosu; \
  # Verify that the binary works
  gosu nobody true;
