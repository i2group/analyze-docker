# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

ARG SQLSERVER_VERSION=2022-CU4-rhel-8.7
FROM mcr.microsoft.com/mssql/rhel/server:${SQLSERVER_VERSION}

ARG SQLSERVER_VERSION=2022-CU4-rhel-8.7
# Dynamic labels
ARG revision

LABEL name="Microsoft SQL Server" \
  maintainer="i2 Group" \
  version="${SQLSERVER_VERSION}" \
  revision="${revision}" \
  summary="SQL Server image based on Red Hat ubi." \
  description="This image contains SQL Server with Red Hat OS." \
  license="MIT"

USER root
# User mssql is created by the base image
ARG USER=mssql

# Install Full-Text Search capability
RUN curl -o /etc/yum.repos.d/mssql-server.repo https://packages.microsoft.com/config/rhel/8/mssql-server-2022.repo \
  && ACCEPT_EULA=Y dnf -y update \
  && dnf -y --nodocs install mssql-server-fts \
  # Clean up
  && dnf clean all

COPY --chown="${USER}:0" docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown="${USER}:0" environment.sh /opt/environment.sh
RUN mkdir -p /run/secrets /backup /var/i2a-data \
  && chown -R "${USER}" /var/opt/mssql /tmp /run/secrets /backup /var/i2a-data

USER "${USER}"

ENTRYPOINT ["/opt/mssql/bin/permissions_check.sh", "/opt/docker-entrypoint.sh"]
CMD ["/opt/mssql/bin/sqlservr"]
