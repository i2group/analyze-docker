# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT
#
# Inspired by: https://github.com/apache/solr-docker/blob/aa51c522c3e74cd1b2886209ea249358a34d324a/8.11/Dockerfile

# Dynamic labels passed at build time into global-scope
# revision = CI build number or 'dev' for local builds
ARG revision
# version = image version = name of the directory this Dockerfile is in
ARG version

ARG SOLR_VERSION="8.11.4"
ARG SOLR_SHA512="828a7c3c06f3ccca852f2c3f91d72bf032cf102646283f4e603bbc3c3f3753978ce8b5c014c4263fb66c251b6726105956ad726baee63af6568637eba0416612"
ARG SOLR_KEYS="50E3EE1C91C7E0CB4DFB007B369424FC98F3F6EC"
# If specified, this will override SOLR_DOWNLOAD_SERVER and all ASF mirrors. Typically used downstream for custom builds
ARG SOLR_DOWNLOAD_URL
# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER="https://www.apache.org/dyn/closer.lua?action=download&filename=/solr/solr"
ARG JATTACH_URL="https://github.com/apangin/jattach/releases/download/v2.0/jattach"
ARG JATTACH_SHA512="a19e774600d6aa844bceb2189285848127a70130a69fb1840c10367f3360972c733b3f09e60e9672d387e2d48c750ab56acfe8f80f7c6af76f5d1123e5ad7222"



# Stage 1: Download everything we need
# Use ubuntu, because we can't untar on ubi reliably on arm64.
# (on arm64, tar reports a lot of "Cannot open: Invalid argument" errors)
FROM ubuntu:24.04 as downloader-and-unpacker

# Bring global-scope args into the build stage, and add more
ARG SOLR_VERSION
ARG SOLR_SHA512
ARG SOLR_KEYS
ARG SOLR_DOWNLOAD_URL
ARG SOLR_DOWNLOAD_SERVER
ARG JATTACH_URL
ARG JATTACH_SHA512
ENV \
    SOLR_CLOSER_URL="http://www.apache.org/dyn/closer.lua?filename=lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz&action=download" \
    SOLR_DIST_URL="https://www.apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz" \
    SOLR_ARCHIVE_URL="https://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz"

# Dependencies for downloading and verifying Solr.
# Subset of those used in the official Solr image.
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      ca-certificates \
      dirmngr \
      gnupg \
      wget \
    && \
    rm -rf /var/lib/apt/lists/*

# Download jattach and put it into /jattach for easy copying later.
RUN set -ex; \
  mkdir /jattach && \
  cd /jattach && \
  wget --progress=dot:mega --tries=3 --timeout=10 --waitretry=10 --retry-connrefused "${JATTACH_URL}" -O jattach && \
  chmod 755 jattach && \
  echo "${JATTACH_SHA512}  jattach" >jattach.sha512 && \
  sha512sum -c jattach.sha512 && \
  rm jattach.sha512 && \
  ls -al /jattach

# Download, verify, and extract Solr
# Code from official image's Dockerfile...
RUN set -ex; \
  export GNUPGHOME="/tmp/gnupg_home"; \
  mkdir -p "$GNUPGHOME"; \
  chmod 700 "$GNUPGHOME"; \
  echo "disable-ipv6" >> "$GNUPGHOME/dirmngr.conf"; \
  for key in $SOLR_KEYS; do \
    found=''; \
    for server in \
      ha.pool.sks-keyservers.net \
      hkp://keyserver.ubuntu.com:80 \
      hkp://p80.pool.sks-keyservers.net:80 \
      pgp.mit.edu \
    ; do \
      echo "  trying $server for $key"; \
      gpg --batch --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break; \
      gpg --batch --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch $key from several disparate servers -- network issues?" && exit 1; \
  done; \
  exit 0

# Code from official image's Dockerfile...
# ... truncated after the 'tar' step, with the 'tar' going into '/solr' instead of '/opt/'
# ... with wget told --progress=dot:mega --tries=3 --timeout=10 --waitretry=10 --retry-connrefused for robustness.
RUN set -ex; \
  export GNUPGHOME="/tmp/gnupg_home"; \
  MAX_REDIRECTS=1; \
  if [ -n "$SOLR_DOWNLOAD_URL" ]; then \
    # If a custom URL is defined, we download from non-ASF mirror URL and allow more redirects and skip GPG step
    # This takes effect only if the SOLR_DOWNLOAD_URL build-arg is specified, typically in downstream Dockerfiles
    MAX_REDIRECTS=4; \
    SKIP_GPG_CHECK=true; \
  elif [ -n "$SOLR_DOWNLOAD_SERVER" ]; then \
    SOLR_DOWNLOAD_URL="$SOLR_DOWNLOAD_SERVER/$SOLR_VERSION/solr-$SOLR_VERSION.tgz"; \
  fi; \
  for url in $SOLR_DOWNLOAD_URL $SOLR_CLOSER_URL $SOLR_DIST_URL $SOLR_ARCHIVE_URL; do \
    if [ -f "/opt/solr-$SOLR_VERSION.tgz" ]; then break; fi; \
    echo "downloading $url"; \
    if wget --progress=dot:mega --tries=3 --timeout=10 --waitretry=10 --max-redirect $MAX_REDIRECTS --retry-connrefused "$url" -O "/opt/solr-$SOLR_VERSION.tgz"; then break; else rm -f "/opt/solr-$SOLR_VERSION.tgz"; fi; \
  done; \
  if [ ! -f "/opt/solr-$SOLR_VERSION.tgz" ]; then echo "failed all download attempts for solr-$SOLR_VERSION.tgz"; exit 1; fi; \
  if [ -z "$SKIP_GPG_CHECK" ]; then \
    echo "downloading $SOLR_ARCHIVE_URL.asc"; \
    wget --progress=dot:mega --tries=3 --timeout=10 --waitretry=10 --retry-connrefused "$SOLR_ARCHIVE_URL.asc" -O "/opt/solr-$SOLR_VERSION.tgz.asc"; \
    echo "$SOLR_SHA512 */opt/solr-$SOLR_VERSION.tgz" | sha512sum -c -; \
    (>&2 ls -l "/opt/solr-$SOLR_VERSION.tgz" "/opt/solr-$SOLR_VERSION.tgz.asc"); \
    gpg --batch --verify "/opt/solr-$SOLR_VERSION.tgz.asc" "/opt/solr-$SOLR_VERSION.tgz"; \
  else \
    echo "Skipping GPG validation due to non-Apache build"; \
  fi; \
  mkdir -p /solr && \
  tar -C /solr --extract --file "/opt/solr-$SOLR_VERSION.tgz" && \
  { command -v gpgconf; gpgconf --kill all || :; } && \
  rm -rf "$GNUPGHOME" "/opt/solr-$SOLR_VERSION.tgz" "/opt/solr-$SOLR_VERSION.tgz.asc" && \
  ls -al /solr



# Stage 2: Create the final image
FROM eclipse-temurin:11-ubi9-minimal

# Bring global-scope args into the build stage
ARG revision
ARG version
ARG SOLR_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL name="Apache Solr" \
  maintainer="i2 Group" \
  version="${SOLR_VERSION}" \
  revision="${revision}" \
  summary="Apache Solr image based on Red Hat's UBI." \
  description="Solr is the popular, blazing fast, open source NoSQL search platform from the Apache Lucene project." \
  license="MIT"

RUN set -eux; \
    microdnf -y install \
      acl \
      lsof \
      procps \
      openssl \
      gzip \
      findutils \
    && \
    microdnf clean all

# Copy jattach from the downloader-and-unpacker stage.
# Original Dockerfile downloaded it as part of the previous RUN step.
COPY --from=downloader-and-unpacker /jattach/jattach /usr/local/bin/jattach

# Original Dockerfile set all these ... but we had to move the SOLR_..._URL args up to the downloader stage
ENV JAVA_HOME="/opt/java/openjdk" \
    PATH="/opt/solr/bin:/opt/docker-solr/scripts:/opt/java/openjdk/bin:$PATH" \
    SOLR_USER="solr" \
    SOLR_UID="8983" \
    SOLR_GROUP="solr" \
    SOLR_GID="8983" \
    SOLR_INCLUDE=/etc/default/solr.in.sh \
    SOLR_HOME=/var/solr/data \
    SOLR_BACKUP=$SOLR_BACKUP_DIR \
    SOLR_PID_DIR=/var/solr \
    SOLR_LOGS_DIR=/var/solr/logs \
    LOG4J_PROPS=/var/solr/log4j2.xml

# Install shadow-utils temporarily, use it, then remove it to keep image small
RUN set -eux; \
    microdnf -y install shadow-utils && \
    groupadd -r --gid "$SOLR_GID" "$SOLR_GROUP" && \
    useradd -r --uid "$SOLR_UID" --gid "$SOLR_GID" "$SOLR_USER" && \
    microdnf -y remove shadow-utils && \
    microdnf clean all

# Copy solr directory tree from the downloader-and-unpacker stage.
# Original Dockerfile had a RUN step we've had to split at the tar step.
COPY --from=downloader-and-unpacker /solr /opt/
# ... and then continue with the rest of the original RUN step after the tar step
# ... except for some tidy-up that we did earlier.
RUN set -eux; \
  ls -al /opt/; \
  (cd /opt; ln -s "solr-$SOLR_VERSION" solr); \
  rm -Rf /opt/solr/docs/ /opt/solr/dist/{solr-core-$SOLR_VERSION.jar,solr-solrj-$SOLR_VERSION.jar,solrj-lib,solr-test-framework-$SOLR_VERSION.jar,test-framework}; \
  mkdir -p /opt/solr/server/solr/lib /docker-entrypoint-initdb.d /opt/docker-solr; \
  chown -R 0:0 "/opt/solr-$SOLR_VERSION"; \
  find "/opt/solr-$SOLR_VERSION" -type d -print0 | xargs -0 chmod 0755; \
  find "/opt/solr-$SOLR_VERSION" -type f -print0 | xargs -0 chmod 0644; \
  chmod -R 0755 "/opt/solr-$SOLR_VERSION/bin" "/opt/solr-$SOLR_VERSION/contrib/prometheus-exporter/bin/solr-exporter" /opt/solr-$SOLR_VERSION/server/scripts/cloud-scripts; \
  cp /opt/solr/bin/solr.in.sh /etc/default/solr.in.sh; \
  mv /opt/solr/bin/solr.in.sh /opt/solr/bin/solr.in.sh.orig; \
  mv /opt/solr/bin/solr.in.cmd /opt/solr/bin/solr.in.cmd.orig; \
  chown root:0 /etc/default/solr.in.sh; \
  chmod 0664 /etc/default/solr.in.sh; \
  mkdir -p /var/solr/data /var/solr/logs; \
  (cd /opt/solr/server/solr; cp solr.xml zoo.cfg /var/solr/data/); \
  cp /opt/solr/server/resources/log4j2.xml /var/solr/log4j2.xml; \
  find /var/solr -type d -print0 | xargs -0 chmod 0770; \
  find /var/solr -type f -print0 | xargs -0 chmod 0660; \
  sed -i -e "s/\"\$(whoami)\" == \"root\"/\$(id -u) == 0/" /opt/solr/bin/solr; \
  sed -i -e 's/lsof -PniTCP:/lsof -t -PniTCP:/' /opt/solr/bin/solr; \
  chown -R "0:0" /opt/solr-$SOLR_VERSION /docker-entrypoint-initdb.d /opt/docker-solr; \
  chown -R "$SOLR_USER:0" /var/solr /opt/solr/example; \
  chown "$SOLR_USER:0" /opt/solr/server/resources/log4j2-console.xml

COPY --chown=0:0 scripts /opt/docker-solr/scripts

VOLUME /var/solr
EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
