# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

FROM eclipse-temurin:8-ubi9-minimal

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG GOSU_VERSION=1.17

# Use root but change at runtime with GOSU
# hadolint ignore=DL3002
USER root

# Install shared packages
RUN set -eux; \
  microdnf -y update; \
  microdnf -y install \
  jq \
  iputils \
  shadow-utils \
  diffutils \
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
