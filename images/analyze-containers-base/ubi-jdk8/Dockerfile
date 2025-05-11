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

# Stage 1: Build xmlstarlet from source
FROM registry.access.redhat.com/ubi8/ubi as builder

ARG XMLSTARLET_VERSION="1.6.1"

# Install required dependencies
RUN dnf update -y; \
    dnf install -y \
    gcc \
    gcc-c++ \
    make \
    libxml2-devel \
    libxslt-devel \
    wget \
    && dnf clean all

# Set the include path for libxml2 headers
ENV CFLAGS="-I/usr/include/libxml2"

# Download, extract and compile xmlstarlet source code
RUN wget --progress=dot:giga "https://sourceforge.net/projects/xmlstar/files/xmlstarlet/${XMLSTARLET_VERSION}/xmlstarlet-${XMLSTARLET_VERSION}.tar.gz" -O "/opt/xmlstarlet-${XMLSTARLET_VERSION}.tar.gz"; \
    tar -xzf "/opt/xmlstarlet-${XMLSTARLET_VERSION}.tar.gz" -C "/opt"; \
    cd "/opt/xmlstarlet-${XMLSTARLET_VERSION}" || exit; \
    ./configure && make -s; \
    mv "/opt/xmlstarlet-${XMLSTARLET_VERSION}/xml" "/opt/xmlstarlet"

# Stage 2: Create the final image
FROM eclipse-temurin:8-ubi9-minimal

# Bring global-scope args into the build stage
ARG revision
ARG version

LABEL name="Analyze Containers Base" \
  version="${version}" \
  revision="${revision}" \
  maintainer="i2 Group" \
  summary="Image for Analyze Containers deployment with OpenJDK 8 and Red Hat's UBI minimal." \
  description="This image contains OpenJDK 8 Eclipse Temurin runtime and Red Hat's UBI as the base OS." \
  license="MIT"

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
  openssl \
  libxml2 \
  libxslt; \
  microdnf clean all;

# Copy the compiled xmlstarlet binary from the builder stage
COPY --from=builder /opt/xmlstarlet /usr/local/bin/xmlstarlet

# GOSU layer
RUN ARCH="$(uname -m)"; \
  if [ "${ARCH}" != "aarch64" ] && [ "${ARCH}" != "arm64" ]; then \
  curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64"; \
  else curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-arm64"; fi; \
  chmod +x /usr/local/bin/gosu; \
  # Verify that the binary works
  gosu nobody true;
