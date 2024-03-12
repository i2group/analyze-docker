# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT
#
# Inspired by: https://github.com/apache/solr-docker

FROM i2group/i2eng-analyze-containers-base:ubi-jdk17

# Dynamic labels
ARG revision

ARG SOLR_VERSION="9.4.1"
# empty for the full distribution, "-slim" for the slim distribution
ARG SOLR_DIST=""
ARG SOLR_SHA512="de22de737900e792776b35f598c14d734d432fdb9147feffd41694d66c521145c024f99ff180c2486ab91d96e34db34224f7cfa72b16afbe14d740c1d429a173"
ARG SOLR_KEYS="515EA995ED1DD799FA1422E5CA7514D8385D790B"

# Override the default solr download location with a preferred mirror, e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=https://downloads.apache.org/solr/solr .
# This server must support downloading at: ${SOLR_DOWNLOAD_SERVER}/${SOLR_VERSION}/solr-${SOLR_VERSION}(-slim).tgz(.asc)
ARG SOLR_DOWNLOAD_SERVER="https://www.apache.org/dyn/closer.lua?action=download&filename=/solr/solr"

RUN set -ex; \
  microdnf -y update; \
  microdnf -y --setopt=install_weak_deps=0 install wget gpg gnupg dirmngr; \
  rm -rf /var/lib/apt/lists/*; \
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
  # Change to verbose to debug why we are hanging on download
  if ! wget -t 10 --max-redirect $MAX_REDIRECTS --retry-connrefused -v "$DOWNLOAD_URL" -O "/opt/$SOLR_BINARY"; then rm -f "/opt/$SOLR_BINARY"; fi; \
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
      wget -nv "https://downloads.apache.org/solr/KEYS" -O- | \
        gpg --batch --import --key-origin 'url,https://downloads.apache.org/solr/KEYS'; \
      # Save just the release key
      release_keys="$(gpg --batch --export -a ${SOLR_KEYS})"; \
      rm -rf "$GNUPGHOME"/*; \
      echo "${release_keys}" | gpg --batch --import; \
    fi; \
    # Do GPG Checks
    echo "downloading $DOWNLOAD_URL.asc"; \
    wget -nv "$DOWNLOAD_URL.asc" -O "/opt/$SOLR_BINARY.asc"; \
    (>&2 ls -l "/opt/$SOLR_BINARY" "/opt/$SOLR_BINARY.asc"); \
    gpg --batch --verify "/opt/$SOLR_BINARY.asc" "/opt/$SOLR_BINARY"; \
    # Cleanup GPG
    { command -v gpgconf; gpgconf --kill all || :; }; \
    rm -r "$GNUPGHOME"; \
  else \
    echo "Skipping GPG validation due to non-Apache build"; \
  fi; \
  tar -C /opt --extract --preserve-permissions --file "/opt/$SOLR_BINARY"; \
  rm "/opt/$SOLR_BINARY"*; \
  microdnf clean all;



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

# add symlink to /opt/solr, remove what we don't want.
# Remove the Dockerfile because it might not represent the dockerfile that was used to generate the image.
RUN set -ex; \
  (cd /opt; ln -s solr-*/ solr); \
  rm -Rf /opt/solr/docs /opt/solr/docker/Dockerfile;

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

# Gosu is part of the base image so we don't try to reinstall
# Netcat is ncat which is part of nmap package
# jattach needs to be manually downloaded
RUN set -ex; \
    cd /usr/local/bin; wget -nv https://github.com/jattach/jattach/releases/download/v2.2/jattach; chmod 755 jattach; \
    echo >jattach.sha512 "53a5d9b49875bc4437ac5b20440e48c66fa42df4aa42c3e50b03a3e5937a855a071a4e65c53b304a47c11353f817feac47ef6d7d86bd9641dc11d2e7d0af6a7a  jattach"; \
    sha512sum -c jattach.sha512; rm jattach.sha512; \
    microdnf update; \
    microdnf -y --setopt=install_weak_deps=0 install acl lsof procps wget nmap; \
    microdnf clean all;

VOLUME /var/solr
EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_UID

ENTRYPOINT ["/opt/solr/docker-entrypoint.sh"]
CMD ["solr-foreground"]