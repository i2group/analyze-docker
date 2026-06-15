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

ARG POSTGRES_VERSION=17
ARG POSTGIS_VERSION=3

# Inspired by: https://github.com/docker-library/postgres and https://github.com/postgis/docker-postgis
# hadolint ignore=DL3049
FROM postgres:${POSTGRES_VERSION}-bookworm

# Bring global-scope args into the build stage
ARG revision
ARG version
ARG POSTGRES_VERSION
ARG POSTGIS_VERSION

USER root

LABEL name="Postgres" \
  version="${POSTGRES_VERSION}" \
  revision="${revision}" \
  maintainer="i2 Group" \
  summary="Image for Postgres with PostGIS extension." \
  description="This image contains Postgres server with PostGIS extension in Debian OS." \
  license="MIT"

# bookworm-updates causes apt to fail with "getline (12: Cannot allocate memory)"
# when running under QEMU arm64 emulation on Ubuntu 24.04 CI hosts. The root
# cause is in QEMU user-mode emulation's virtual address space handling; no
# upstream fix has been identified. bookworm-updates only provides non-security
# stability patches (e.g. tzdata); security fixes remain in bookworm-security.
# Supports both classic (/etc/apt/sources.list) and DEB822 format
# (/etc/apt/sources.list.d/debian.sources) as postgres base images use DEB822.
# To check if the upstream issue is resolved, remove these two sed lines,
# push to a branch, and verify CI passes consistently. See OPS-2264.
RUN { [ -f /etc/apt/sources.list ] && sed -i '/bookworm-updates/d' /etc/apt/sources.list; } || true \
  && { [ -f /etc/apt/sources.list.d/debian.sources ] && sed -i 's/ bookworm-updates//' /etc/apt/sources.list.d/debian.sources; } || true \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  postgresql-${POSTGRES_VERSION}-postgis-${POSTGIS_VERSION} \
  postgresql-${POSTGRES_VERSION}-postgis-${POSTGIS_VERSION}-scripts \
  postgresql-${POSTGRES_VERSION}-cron \
  && rm -rf /var/lib/apt/lists/*

# User postgres is created by the base image
ARG USER=postgres
ENV USER="${USER}"

COPY --chown="${USER}:0" docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown="${USER}:0" environment.sh /opt/environment.sh
RUN mkdir -p /run/secrets /backup /var/i2a-data \
  && chown -R "${USER}" /tmp /run/secrets /backup /var/i2a-data \
  && ln -s /usr/lib/postgresql/${POSTGRES_VERSION}/bin /usr/lib/postgresql/bin \
  && sed -i "s/#shared_preload_libraries = ''/shared_preload_libraries = 'pg_cron'/" /usr/share/postgresql/postgresql.conf.sample \
  && echo "cron.database_name = 'postgres'" >> /usr/share/postgresql/postgresql.conf.sample

USER "${USER}"

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
CMD ["postgres"]
