# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT
#
# Inspired by: https://github.com/prometheus/prometheus
# hadolint ignore=DL3049
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.2 as builder
ARG PROMETHEUS_VERSION="v2.45.1"

ENV PROMETHEUS_TAG="tags/${PROMETHEUS_VERSION}"
ENV PROMETHEUS="https://api.github.com/repos/prometheus/prometheus/releases/${PROMETHEUS_TAG}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN set -ex; \
  microdnf -y install gzip jq tar; \
  microdnf clean all

# The checksum file for the Prometheus project is "sha256sums.txt"
ARG SUM_FILE="sha256sums.txt"

RUN mkdir /prometheus
WORKDIR /prometheus

# Download the checksum and binary tarball, check checksum and extract
RUN ARCH=$(uname -m) \
  && if [[ "${ARCH}" == "aarch64" ]]; then TAR_NAME="linux-arm64.tar.gz"; else TAR_NAME="linux-amd64.tar.gz"; fi \
  && curl -sSLf "$(curl -sSLf "${PROMETHEUS}" -o - | jq -r --arg sum_file "${SUM_FILE}" '.assets[] | select(.name|test($sum_file)) | .browser_download_url')" -o "${SUM_FILE}" \
  && curl -sSLf -O "$(curl -sSLf "${PROMETHEUS}" -o - | jq -r --arg tar_name "${TAR_NAME}" '.assets[] | select(.name|test($tar_name)) | .browser_download_url')" \
  && sha256sum --check --ignore-missing "${SUM_FILE}" \
  && tar --extract --gunzip --no-same-owner --strip-components=1 --directory /prometheus --file ./*.tar.gz

FROM registry.access.redhat.com/ubi9/ubi:9.1.0

# Dynamic labels
ARG revision

LABEL name="Prometheus" \
  maintainer="i2 Group" \
  version="${PROMETHEUS_VERSION}" \
  revision="${revision}" \
  summary="Prometheus image based on Red Hat's UBI." \
  description="Prometheus is a systems and service monitoring system." \
  license="MIT"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG USERNAME=prometheus
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN set -eux; \
  dnf -y install \
  ca-certificates \
  httpd-tools \
  && dnf clean all

# Get the binary from the builder image
COPY --from=builder /prometheus /prometheus

WORKDIR /prometheus

# Link the binary files into the $PATH
RUN mkdir -p /etc/prometheus /tmp/prometheus \
  && ln prometheus /bin/ \
  && ln promtool /bin/ \
  && groupadd --gid $USER_GID $USERNAME \
  && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
  && chown -R $USER_UID:0 /prometheus /etc/prometheus /tmp/prometheus

USER $USERNAME

COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY update-prometheus-config.sh /opt/update-prometheus-config.sh
COPY environment.sh /opt/environment.sh
COPY web-config.yml /etc/prometheus-templates/web-config.yml
COPY prometheus.yml /etc/prometheus-templates/prometheus.yml

EXPOSE 9090
VOLUME ["/prometheus/data"]

CMD [ "--config.file=/etc/prometheus/prometheus.yml", \
  "--storage.tsdb.path=/prometheus", \
  "--web.config.file=/etc/prometheus/web-config.yml", \
  "--web.console.libraries=/prometheus/console_libraries", \
  "--web.console.templates=/prometheus/consoles", \
  "--web.enable-lifecycle"]

ENTRYPOINT ["/opt/docker-entrypoint.sh"]