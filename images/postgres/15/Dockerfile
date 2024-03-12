# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT
#
# Inspired by: https://github.com/docker-library/postgres and https://github.com/postgis/docker-postgis
# hadolint ignore=DL3049
FROM postgres:15-bullseye

ARG POSTGRES_VERSION=15
ARG POSTGIS_VERSION=3

# Dynamic labels
ARG revision

USER root

LABEL name="Postgres" \
  version="${POSTGRES_VERSION}" \
  revision="${revision}" \
  maintainer="i2 Group" \
  summary="Image for Postgres with PostGIS extension." \
  description="This image contains Postgres server with PostGIS extension in Debian OS." \
  license="MIT"

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  ca-certificates \
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
  && echo "cron.database_name = 'ISTORE'" >> /usr/share/postgresql/postgresql.conf.sample

USER "${USER}"

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
CMD ["postgres"]
