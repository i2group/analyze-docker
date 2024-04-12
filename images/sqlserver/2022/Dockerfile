# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

ARG SQLSERVER_VERSION=2022
FROM "mcr.microsoft.com/mssql/rhel/server:${SQLSERVER_VERSION}-latest"

ARG SQLSERVER_VERSION=2022

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Dynamic labels
ARG revision

LABEL name="Microsoft SQL Server" \
  maintainer="i2 Group" \
  version="${SQLSERVER_VERSION}" \
  revision="${revision}" \
  summary="SQL Server image based on Red Hat's UBI." \
  description="This image contains SQL Server with Red Hat OS." \
  license="MIT"

USER root
# User mssql is created by the base image
ARG USER=mssql

COPY --chown="${USER}:0" docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown="${USER}:0" environment.sh /opt/environment.sh

RUN set -eux; \
  mkdir -p /run/secrets /backup /var/i2a-data; \
  chown -R "${USER}" /tmp /run/secrets /backup /var/i2a-data; \
  # Install Full-Text Search capability
  # Gets the RedHat OS version and uses it for the mssql package download
  RHEL_VERSION="$(rpm -q --queryformat '%{VERSION}' redhat-release | cut -d. -f1)"; \
  curl -o /etc/yum.repos.d/mssql-server.repo "https://packages.microsoft.com/config/rhel/${RHEL_VERSION}/mssql-server-${SQLSERVER_VERSION}.repo"; \
  # ACCEPT_EULA=y to update mssql packages
  ACCEPT_EULA=Y dnf -y update; \
  dnf -y --nodocs install mssql-server-fts; \
  dnf clean all;

# Temporary fix until the latest image has mssql-tools v18
RUN curl https://packages.microsoft.com/config/rhel/9/prod.repo \
  | tee /etc/yum.repos.d/mssql-release.repocurl https://packages.microsoft.com/config/rhel/9/prod.repo \
  | tee /etc/yum.repos.d/mssql-release.repo; \
  dnf remove mssql-tools unixODBC-utf16 unixODBC-utf16-devel; \
  ACCEPT_EULA=Y dnf -y --nodocs install mssql-tools18 unixODBC-devel; \
  dnf clean all; \
  rm -rf /opt/mssql-tools && ln -s /opt/mssql-tools18 /opt/mssql-tools;

USER "${USER}"

ENTRYPOINT ["/opt/mssql/bin/permissions_check.sh", "/opt/docker-entrypoint.sh"]
CMD ["/opt/mssql/bin/sqlservr"]
