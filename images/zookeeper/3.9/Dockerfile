# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT
#
# Inspired by: https://github.com/31z4/zookeeper-docker

FROM eclipse-temurin:17-ubi9-minimal

# Dynamic labels
ARG revision

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG ZK_VERSION="3.9.1"
ARG GOSU_VERSION=1.17

LABEL name="Apache ZooKeeper" \
  maintainer="i2 Group" \
  version="${ZK_VERSION}" \
  revision="${revision}" \
  summary="Apache ZooKeeper image based on Red Hat ubi." \
  description="Apache ZooKeeper is a software project of the Apache Software Foundation, \
  providing an open source distributed configuration service, synchronization service, \
  and naming registry for large distributed systems." \
  license="MIT"

ENV JAVA_HOME="/opt/java/openjdk" \
  PATH="/opt/java/openjdk/bin:$PATH" \
  ZOO_CONF_DIR=/conf \
  ZOO_DATA_DIR=/data \
  ZOO_DATA_LOG_DIR=/datalog \
  ZOO_LOG_DIR=/logs \
  ZOO_TICK_TIME=2000 \
  ZOO_INIT_LIMIT=5 \
  ZOO_SYNC_LIMIT=2 \
  ZOO_AUTOPURGE_PURGEINTERVAL=0 \
  ZOO_AUTOPURGE_SNAPRETAINCOUNT=3 \
  ZOO_MAX_CLIENT_CNXNS=60 \
  ZOO_STANDALONE_ENABLED=true \
  ZOO_ADMINSERVER_ENABLED=true

# Install required packages
RUN set -eux; \
  microdnf -y install \
  ca-certificates \
  dirmngr \
  gnupg \
  nmap \
  tar \
  gzip \
  wget \
  shadow-utils \
  openssl; \
  microdnf clean all; \
  ARCH="$(uname -m)"; \
  if [ "${ARCH}" != "aarch64" ]; then \
  wget -nv "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64" -O /usr/local/bin/gosu; \
  else wget -nv "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-arm64" -O /usr/local/bin/gosu; fi; \
  chmod +x /usr/local/bin/gosu; \
  # Verify that the binary works
  gosu nobody true;

# Add a user with an explicit UID/GID and create necessary directories
RUN set -eux; \
  groupadd -r zookeeper --gid=1000; \
  useradd -r -g zookeeper --uid=1000 zookeeper; \
  mkdir -p "$ZOO_DATA_LOG_DIR" "$ZOO_DATA_DIR" "$ZOO_CONF_DIR" "$ZOO_LOG_DIR"; \
  chown zookeeper:zookeeper "$ZOO_DATA_LOG_DIR" "$ZOO_DATA_DIR" "$ZOO_CONF_DIR" "$ZOO_LOG_DIR"

ARG GPG_KEY=3F7A1D16FA4217B1DC75E1C9FFE35B7F15DFA1BA
ARG SHORT_DISTRO_NAME=zookeeper-${ZK_VERSION}
ARG DISTRO_NAME=apache-zookeeper-${ZK_VERSION}-bin

# Download Apache Zookeeper, verify its PGP signature, untar and clean up
RUN set -eux; \
  ddist() { \
  local f="$1"; shift; \
  local distFile="$1"; shift; \
  local success=; \
  local distUrl=; \
  for distUrl in \
  'https://www.apache.org/dyn/closer.cgi?action=download&filename=' \
  https://www-us.apache.org/dist/ \
  https://www.apache.org/dist/ \
  https://archive.apache.org/dist/ \
  ; do \
  if wget -q -O "$f" "$distUrl$distFile" && [ -s "$f" ]; then \
  success=1; \
  break; \
  fi; \
  done; \
  [ -n "$success" ]; \
  }; \
  ddist "$DISTRO_NAME.tar.gz" "zookeeper/$SHORT_DISTRO_NAME/$DISTRO_NAME.tar.gz"; \
  ddist "$DISTRO_NAME.tar.gz.asc" "zookeeper/$SHORT_DISTRO_NAME/$DISTRO_NAME.tar.gz.asc"; \
  export GNUPGHOME="$(mktemp -d)"; \
  gpg --keyserver hkps://keyserver.pgp.com --recv-key "$GPG_KEY" || \
  gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "$GPG_KEY" || \
  gpg --keyserver hkps://pgp.mit.edu --recv-keys "$GPG_KEY"; \
  gpg --batch --verify "$DISTRO_NAME.tar.gz.asc" "$DISTRO_NAME.tar.gz"; \
  tar -zxf "$DISTRO_NAME.tar.gz"; \
  mv "$DISTRO_NAME/conf/"* "$ZOO_CONF_DIR"; \
  rm -rf "$GNUPGHOME" "$DISTRO_NAME.tar.gz" "$DISTRO_NAME.tar.gz.asc"; \
  chown -R zookeeper:zookeeper "/$DISTRO_NAME"; \
  ln -s "/$DISTRO_NAME" /apache-zookeeper-bin

WORKDIR $DISTRO_NAME
VOLUME ["$ZOO_DATA_DIR", "$ZOO_DATA_LOG_DIR", "$ZOO_LOG_DIR"]

EXPOSE 2181 2888 3888 8080

ENV PATH=$PATH:/$DISTRO_NAME/bin \
  ZOOCFGDIR=$ZOO_CONF_DIR

COPY docker-entrypoint.sh /
COPY --chown=zookeeper:zookeeper environment.sh /

USER zookeeper

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["zkServer.sh", "start-foreground"]
