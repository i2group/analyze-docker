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



# Stage 1: Download everything we need
# Use ubuntu, because we can't untar on ubi reliably on arm64.
# (on arm64, tar reports a lot of "Cannot open: Invalid argument" errors)
FROM ubuntu:24.04 as downloader-and-unpacker

ARG GOSU_VERSION="1.19"
ARG XMLSTARLET_VERSION="1.6.1"

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      ca-certificates \
      wget \
    && \
    rm -rf /var/lib/apt/lists/*

# GOSU binary can be downloaded directly
RUN set -eux; \
    TARGET_DIR='/gosu' && \
    ARCH="$(uname -m)" && \
    mkdir -p "${TARGET_DIR}" && \
    if [ "${ARCH}" != "aarch64" ] && [ "${ARCH}" != "arm64" ]; then \
      DOWNLOAD_URL="https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64"; \
    else \
      DOWNLOAD_URL="https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-arm64"; \
    fi && \
    wget --progress=dot:mega --tries=3 --timeout=10 --waitretry=10 --retry-connrefused "${DOWNLOAD_URL}" -O "${TARGET_DIR}/gosu" && \
    chmod 0755 "${TARGET_DIR}/gosu" && \
    "${TARGET_DIR}/gosu" nobody true

RUN set -eux; \
    TARGET_DIR='/xmlstarlet'; \
    DOWNLOADED_TAR_FILE='/tmp/xmlstarlet.tar.gz'; \
    DOWNLOAD_URL="https://sourceforge.net/projects/xmlstar/files/xmlstarlet/${XMLSTARLET_VERSION}/xmlstarlet-${XMLSTARLET_VERSION}.tar.gz"; \
    mkdir -p "${TARGET_DIR}" && \
    wget --progress=dot:mega --tries=3 --timeout=10 --waitretry=10 --retry-connrefused "${DOWNLOAD_URL}" -O "${DOWNLOADED_TAR_FILE}" && \
    ls -al "${DOWNLOADED_TAR_FILE}" && \
    tar -tzf "${DOWNLOADED_TAR_FILE}" && \
    cd "${TARGET_DIR}" && \
    if tar -xzf "${DOWNLOADED_TAR_FILE}" --strip-components=1 --verbose; then \
      rm -f "${DOWNLOADED_TAR_FILE}" ; \
    else \
      echo "Tar extraction failed. Extracted contents was:" >&2; \
      find "${TARGET_DIR}" -ls >&2; \
      exit 1; \
    fi



# Stage 2: Build xmlstarlet from source on the OS of the final image so libraries match.
FROM eclipse-temurin:8-ubi9-minimal as builder

# Install required dependencies
RUN microdnf -y update && \
    microdnf -y install \
      gcc \
      gcc-c++ \
      make \
      libxml2-devel \
      libxslt-devel \
    && \
    microdnf clean all

# Set the include path for libxml2 headers
ENV CFLAGS="-I/usr/include/libxml2"

# Grab xmlstarlet source code from the downloader-and-unpacker stage
COPY --from=downloader-and-unpacker /xmlstarlet /root/xmlstarlet
# Compile xmlstarlet from the source code we just grabbed
RUN set -eux; \
    cd '/root/xmlstarlet' && \
    TARGET_FILE='/opt/xmlstarlet' && \
    find . -ls && \
    ./configure && make -s && \
    mv 'xml' "${TARGET_FILE}" && \
    chmod 0755 "${TARGET_FILE}" && \
    ls -al "${TARGET_FILE}"



# Stage 3: Create the final image
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

# Use root but change at runtime with GOSU
# hadolint ignore=DL3002
USER root

# Install shared packages
RUN set -eux; \
  microdnf -y update && \
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
    libxslt \
  && \
  microdnf clean all;

# Copy the compiled xmlstarlet binary from the builder stage
COPY --from=builder /opt/xmlstarlet /usr/local/bin/xmlstarlet

# Copy the gosu binary from the downloader-and-unpacker stage
COPY --from=downloader-and-unpacker /gosu/gosu /usr/local/bin/gosu
