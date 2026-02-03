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

ARG GOSU_VERSION="1.19"
ARG GOSU_SHA="cd9719b775dbfedae53923c9b0dc792b66d42c51e0b36652ed6f747fbadc0164"
ARG XMLSTARLET_VERSION="1.6.1"
ARG XMLSTARLET_SHA="15d838c4f3375332fd95554619179b69e4ec91418a3a5296e7c631b7ed19e7ca"

ARG GOSU_URL=https://github.com/tianon/gosu/archive/refs/tags/${GOSU_VERSION}.tar.gz
ARG XMLSTARLET_URL=https://sourceforge.net/projects/xmlstar/files/xmlstarlet/${XMLSTARLET_VERSION}/xmlstarlet-${XMLSTARLET_VERSION}.tar.gz


# Stage 1: Download everything we need
# Use ubuntu, because we can't untar on ubi reliably on arm64.
# (on arm64, tar reports a lot of "Cannot open: Invalid argument" errors)
FROM ubuntu:24.04 as downloader-and-unpacker

# Bring global-scope args into this stage
ARG GOSU_VERSION
ARG GOSU_SHA
ARG GOSU_URL
ARG XMLSTARLET_VERSION
ARG XMLSTARLET_SHA
ARG XMLSTARLET_URL

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      ca-certificates \
      wget \
    && \
    rm -rf /var/lib/apt/lists/*

# Download gosu source code (to build later in builder stage)
RUN set -eux; \
    TARGET_DIR='/gosu-src'; \
    DOWNLOADED_TAR_FILE='/tmp/gosu.tar.gz'; \
    mkdir -p "${TARGET_DIR}" && \
    wget --progress=dot:mega --tries=3 --timeout=10 --waitretry=10 --retry-connrefused "${GOSU_URL}" -O "${DOWNLOADED_TAR_FILE}" && \
    ls -al "${DOWNLOADED_TAR_FILE}" && \
    ACTUAL_SHA="$(sha256sum "${DOWNLOADED_TAR_FILE}" | awk '{print $1}')" && \
    if [ "${ACTUAL_SHA}" != "${GOSU_SHA}" ]; then \
      echo "ERROR: gosu source sha256 mismatch" >&2; \
      echo "  Expected: ${GOSU_SHA}" >&2; \
      echo "  Actual:   ${ACTUAL_SHA}" >&2; \
      exit 1; \
    fi && \
    cd "${TARGET_DIR}" && \
    if tar -xzf "${DOWNLOADED_TAR_FILE}" --strip-components=1 --verbose; then \
      rm -f "${DOWNLOADED_TAR_FILE}" ; \
    else \
      echo "Tar extraction failed. Extracted contents was:" >&2; \
      find "${TARGET_DIR}" -ls >&2; \
      exit 1; \
    fi

# Download xmlstarlet source code (to build later in builder stage)
RUN set -eux; \
    TARGET_DIR='/xmlstarlet'; \
    DOWNLOADED_TAR_FILE='/tmp/xmlstarlet.tar.gz'; \
    mkdir -p "${TARGET_DIR}" && \
    wget --progress=dot:mega --tries=3 --timeout=10 --waitretry=10 --retry-connrefused "${XMLSTARLET_URL}" -O "${DOWNLOADED_TAR_FILE}" && \
    ls -al "${DOWNLOADED_TAR_FILE}" && \
    ACTUAL_SHA="$(sha256sum "${DOWNLOADED_TAR_FILE}" | awk '{print $1}')" && \
    if [ "${ACTUAL_SHA}" != "${XMLSTARLET_SHA}" ]; then \
      echo "ERROR: xmlstarlet source sha256 mismatch" >&2; \
      echo "  Expected: ${XMLSTARLET_SHA}" >&2; \
      echo "  Actual:   ${ACTUAL_SHA}" >&2; \
      exit 1; \
    fi && \
    cd "${TARGET_DIR}" && \
    if tar -xzf "${DOWNLOADED_TAR_FILE}" --strip-components=1 --verbose; then \
      rm -f "${DOWNLOADED_TAR_FILE}" ; \
    else \
      echo "Tar extraction failed. Extracted contents was:" >&2; \
      find "${TARGET_DIR}" -ls >&2; \
      exit 1; \
    fi



# Stage 2: Build xmlstarlet from source on the OS of the final image so libraries match.
FROM eclipse-temurin:17-ubi9-minimal as builder

ARG GOSU_VERSION
ARG GOSU_URL
ARG XMLSTARLET_VERSION
ARG XMLSTARLET_URL

# Install required dependencies
RUN microdnf -y update && \
    microdnf -y install \
      ca-certificates \
      coreutils-single \
      gcc \
      gcc-c++ \
      golang \
      make \
      libxml2-devel \
      libxslt-devel \
      rpm-build \
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

# Grab gosu source code from the downloader-and-unpacker stage
COPY --from=downloader-and-unpacker /gosu-src /root/gosu
# Compile gosu from the source code we just grabbed
RUN set -eux; \
  cd '/root/gosu' && \
  TARGET_FILE='/opt/gosu' && \
  go version && \
  CGO_ENABLED=0 GOFLAGS='-trimpath -mod=readonly -buildvcs=false' go build -ldflags='-s -w -buildid=' -o "${TARGET_FILE}" ./ && \
  chmod 0755 "${TARGET_FILE}" && \
  "${TARGET_FILE}" --version

# Package xmlstarlet and gosu into RPMs for installation in the final image
RUN set -eux; \
  mkdir -p \
    /root/rpmbuild/SPECS \
    /root/rpmbuild/BUILD \
    /root/rpmbuild/RPMS \
    /root/rpmbuild/SOURCES \
    /root/rpmbuild/SRPMS \
    /opt/rpms
COPY rpm_template.spec /tmp/rpm_template.spec
RUN set -eux; \
  sed \
  -e "s,%NAME%,gosu,g" \
  -e "s,%VERSION%,${GOSU_VERSION},g" \
  -e "s,%URL%,${GOSU_URL},g" \
  -e "s,%LICENSE%,MIT,g" \
  -e "s,%BUILT_FILE%,/opt/gosu,g" \
  -e "s,%INSTALLATION_TARGET_DIR%,/usr/local/bin,g" \
  -e "s,%INSTALLATION_TARGET_NAME%,gosu,g" \
  < /tmp/rpm_template.spec \
  | tee /root/rpmbuild/SPECS/gosu.spec \
  && \
  sed \
  -e "s,%NAME%,xmlstarlet,g" \
  -e "s,%VERSION%,${XMLSTARLET_VERSION},g" \
  -e "s,%URL%,${XMLSTARLET_URL},g" \
  -e "s,%LICENSE%,MIT,g" \
  -e "s,%BUILT_FILE%,/opt/xmlstarlet,g" \
  -e "s,%INSTALLATION_TARGET_DIR%,/usr/local/bin,g" \
  -e "s,%INSTALLATION_TARGET_NAME%,xmlstarlet,g" \
  < /tmp/rpm_template.spec \
  | tee /root/rpmbuild/SPECS/xmlstarlet.spec \
  && \
  rpmbuild -bb /root/rpmbuild/SPECS/gosu.spec; \
  rpmbuild -bb /root/rpmbuild/SPECS/xmlstarlet.spec; \
  cp -v /root/rpmbuild/RPMS/*/*.rpm /opt/rpms/; \
  ls -al /opt/rpms/



# Stage 3: Create the final image
FROM eclipse-temurin:17-ubi9-minimal

# Bring global-scope args into the build stage
ARG revision
ARG version
ARG GOSU_VERSION
ARG XMLSTARLET_VERSION
ARG shared_packages="ca-certificates diffutils findutils gnupg gzip iputils jq libxml2 libxslt openssl rsync shadow-utils tar"

LABEL name="Analyze Containers Base"
LABEL version="${version}"
LABEL revision="${revision}"
LABEL maintainer="i2 Group"
LABEL summary="Image for Analyze Containers deployment with OpenJDK 17 and Red Hat's UBI minimal."
LABEL description="This image contains OpenJDK 17 Eclipse Temurin runtime and Red Hat's UBI as the base OS. Includes packages: ${shared_packages}, plus xmlstarlet v${XMLSTARLET_VERSION} and gosu v${GOSU_VERSION}."
LABEL license="MIT"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Use root but change at runtime with GOSU
# hadolint ignore=DL3002
USER root

# Install shared packages
RUN set -eux; \
  microdnf -y update && \
  microdnf -y install ${shared_packages} && \
  microdnf clean all;

# Copy built RPMs from builder stage and install them so they appear in RPM DB
# and hence also in the docker image SBOM.
COPY --from=builder /opt/rpms /opt/rpms
RUN set -eux; \
  rpm -Uvh /opt/rpms/*.rpm; \
  xmlstarlet --version; \
  gosu --version; \
  rm -rf /opt/rpms

