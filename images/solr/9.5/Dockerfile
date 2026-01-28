# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT
#
# Inspired by: https://github.com/apache/solr-docker

# Dynamic labels passed at build time into global-scope
# revision = CI build number or 'dev' for local builds
ARG revision
# version = image version = name of the directory this Dockerfile is in
ARG version

ARG SOLR_VERSION="9.5.0"
# empty for the full distribution, "-slim" for the slim distribution
ARG SOLR_DIST=""
ARG SOLR_SHA512="e34b2421db8586691ff41b86beca77bcb61243ce8edfade74eda8da4b0fabde0078884db301350a0d0dfc4a6fee46320ddf059469300444da4e3693220df5e40"
ARG SOLR_KEYS="E05FDF113D89E7FB4A2DF4B2684D544160392455"

# Override the default solr download location with a preferred mirror, e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=https://downloads.apache.org/solr/solr .
# This server must support downloading at: ${SOLR_DOWNLOAD_SERVER}/${SOLR_VERSION}/solr-${SOLR_VERSION}(-slim).tgz(.asc)
ARG SOLR_DOWNLOAD_SERVER="https://www.apache.org/dyn/closer.lua?action=download&filename=/solr/solr"
ARG JATTACH_URL="https://github.com/jattach/jattach/releases/download/v2.2/jattach"
ARG JATTACH_SHA512="53a5d9b49875bc4437ac5b20440e48c66fa42df4aa42c3e50b03a3e5937a855a071a4e65c53b304a47c11353f817feac47ef6d7d86bd9641dc11d2e7d0af6a7a"



# Stage 1: Download everything we need
# Use ubuntu, because we can't untar on ubi reliably on arm64.
# (on arm64, tar reports a lot of "Cannot open: Invalid argument" errors)
FROM ubuntu:24.04 as downloader-and-unpacker

# Bring global-scope args into the build stage
ARG SOLR_VERSION
ARG SOLR_DIST
ARG SOLR_SHA512
ARG SOLR_KEYS
ARG SOLR_DOWNLOAD_SERVER
ARG JATTACH_URL
ARG JATTACH_SHA512

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
  rm jattach.sha512

# Download, verify, and extract Solr
# Code from official image's Dockerfile...
# ... truncated after the 'tar' step, with the 'tar' going into '/solr' instead of '/opt/'
# ... with wget told --progress=dot:mega --tries=3 --timeout=10 --waitretry=10 --retry-connrefused for robustness.
RUN set -ex; \
  export SOLR_BINARY="solr-$SOLR_VERSION$SOLR_DIST.tgz"; \
  MAX_REDIRECTS=3; \
  case "${SOLR_DOWNLOAD_SERVER}" in \
    (*"apache.org"*);; \
    (*) \
      # If a non-ASF URL is provided, allow more redirects and skip GPG step.
      MAX_REDIRECTS=4 && \
      SKIP_GPG_CHECK=true;; \
  esac; \
  export DOWNLOAD_URL="$SOLR_DOWNLOAD_SERVER/$SOLR_VERSION/$SOLR_BINARY"; \
  echo "downloading $DOWNLOAD_URL"; \
  if ! wget --progress=dot:mega --tries=3 --timeout=10 --waitretry=10 --max-redirect $MAX_REDIRECTS --retry-connrefused "$DOWNLOAD_URL" -O "/opt/$SOLR_BINARY"; then rm -f "/opt/$SOLR_BINARY"; fi; \
  if [ ! -f "/opt/$SOLR_BINARY" ]; then echo "failed download attempt for $SOLR_BINARY"; exit 1; fi; \
  echo "$SOLR_SHA512 */opt/$SOLR_BINARY" | sha512sum -c -; \
  if [ -z "$SKIP_GPG_CHECK" ]; then \
    # Setup GPG \
    export GNUPGHOME="/tmp/gnupg_home"; \
    mkdir -p "$GNUPGHOME"; \
    chmod 700 "$GNUPGHOME"; \
    echo "disable-ipv6" >> "$GNUPGHOME/dirmngr.conf"; \
    if [ -n "$SOLR_KEYS" ]; then \
      # Install all Solr GPG Keys to start
      wget --progress=dot:mega --tries=3 --timeout=10 --waitretry=10 --retry-connrefused "https://downloads.apache.org/solr/KEYS" -O- | \
        gpg --batch --import --key-origin 'url,https://downloads.apache.org/solr/KEYS'; \
      # Save just the release key
      release_keys="$(gpg --batch --export -a ${SOLR_KEYS})"; \
      rm -rf "$GNUPGHOME"/*; \
      echo "${release_keys}" | gpg --batch --import; \
    fi; \
    # Do GPG Checks
    echo "downloading $DOWNLOAD_URL.asc"; \
    wget --progress=dot:mega --tries=3 --timeout=10 --waitretry=10 --retry-connrefused "$DOWNLOAD_URL.asc" -O "/opt/$SOLR_BINARY.asc"; \
    (>&2 ls -l "/opt/$SOLR_BINARY" "/opt/$SOLR_BINARY.asc"); \
    gpg --batch --verify "/opt/$SOLR_BINARY.asc" "/opt/$SOLR_BINARY"; \
    # Cleanup GPG
    { command -v gpgconf; gpgconf --kill all || :; }; \
    rm -r "$GNUPGHOME"; \
  else \
    echo "Skipping GPG validation due to non-Apache build"; \
  fi; \
  tar -C /opt --extract --preserve-permissions --file "/opt/$SOLR_BINARY"; \
  rm "/opt/$SOLR_BINARY"*



# Stage 2: Create the final image
FROM i2group/i2eng-analyze-containers-base:ubi-jdk17-${revision}

# Bring global-scope args into the build stage
ARG revision
ARG version
ARG SOLR_VERSION

LABEL name="Apache Solr" \
  maintainer="i2 Group" \
  version="${SOLR_VERSION}" \
  revision="${revision}" \
  summary="Apache Solr image based on Red Hat's UBI." \
  description="Solr is the popular, blazing fast, open source search platform from the Apache Lucene project." \
  license="MIT"

# The Java Security Manager is disabled since it is being deprecated and subject to removal in a future release.
# https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/SecurityManager.html
ENV JAVA_HOME="/opt/java/openjdk" \
    SOLR_SECURITY_MANAGER_ENABLED="false" \
    SOLR_USER="solr" \
    SOLR_UID="8983" \
    SOLR_GROUP="solr" \
    SOLR_GID="8983" \
    PATH="/opt/solr/bin:/opt/solr/docker/scripts:/opt/solr/prometheus-exporter/bin:/opt/java/openjdk:$PATH" \
    SOLR_INCLUDE=/etc/default/solr.in.sh \
    SOLR_HOME=/var/solr/data \
    SOLR_PID_DIR=/var/solr \
    SOLR_LOGS_DIR=/var/solr/logs \
    LOG4J_PROPS=/var/solr/log4j2.xml \
    SOLR_JETTY_HOST="0.0.0.0" \
    SOLR_ZK_EMBEDDED_HOST="0.0.0.0"

RUN set -ex; \
  groupadd -r --gid "$SOLR_GID" "$SOLR_GROUP"; \
  useradd -r --uid "$SOLR_UID" --gid "$SOLR_GID" "$SOLR_USER"

# Copy extracted Solr from the downloader-and-unpacker stage
COPY --from=downloader-and-unpacker /opt/solr-${SOLR_VERSION} /opt/solr-${SOLR_VERSION}

# add symlink to /opt/solr, remove what we don't want.
# Remove the Dockerfile because it might not represent the dockerfile that was used to generate the image.
RUN set -ex; \
  (cd /opt; ln -s solr-*/ solr); \
  rm -Rf /opt/solr/docs /opt/solr/docker/Dockerfile;

# Code from official image's Dockerfile...
RUN set -ex; \
  mkdir -p /opt/solr/server/solr/lib /docker-entrypoint-initdb.d; \
  cp /opt/solr/bin/solr.in.sh /etc/default/solr.in.sh; \
  mv /opt/solr/bin/solr.in.sh /opt/solr/bin/solr.in.sh.orig; \
  mv /opt/solr/bin/solr.in.cmd /opt/solr/bin/solr.in.cmd.orig; \
  chmod 0664 /etc/default/solr.in.sh; \
  mkdir -p -m0770 /var/solr; \
  # Official code only chown's /var/solr but we need more /opt/solr/server/resources /opt/solr/example too.
  chown -R "$SOLR_USER:0" /var/solr /opt/solr/server/resources /opt/solr/example; \
  test ! -e /opt/solr/modules || ln -s /opt/solr/modules /opt/solr/contrib; \
  test ! -e /opt/solr/prometheus-exporter || ln -s /opt/solr/prometheus-exporter /opt/solr/modules/prometheus-exporter;

COPY --chown=0:0 "docker-entrypoint.sh" "/opt/solr/docker-entrypoint.sh"
COPY --chown=0:0 "environment.sh" "/opt/solr/environment.sh"

# Copy jattach from the downloader-and-unpacker stage
COPY --from=downloader-and-unpacker /jattach/jattach /usr/local/bin/jattach

# Gosu is part of the base image so we don't try to reinstall
# Netcat is ncat which is part of nmap package
RUN set -ex; \
    microdnf -y update; \
    microdnf -y --setopt=install_weak_deps=0 install acl lsof procps nmap; \
    microdnf clean all;

VOLUME /var/solr
EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_UID

ENTRYPOINT ["/opt/solr/docker-entrypoint.sh"]
CMD ["solr-foreground"]
