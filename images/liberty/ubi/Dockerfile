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

# Inspired by: https://github.com/OpenLiberty/ci.docker
# Original copyright:
## Copyright 2022-2024 IBM Corporation and others
## This product includes software developed at
## The Open Liberty Project (https://openliberty.io/).

FROM icr.io/appcafe/open-liberty:full-java11-openj9-ubi

# Bring global-scope args into the build stage
ARG revision
ARG version

LABEL maintainer="i2 Group" \
  version="${version}" \
  name="Open Liberty" \
  summary="Image for Open Liberty with OpenJ9 JDK 11 and Red Hat's UBI" \
  revision="${revision}" \
  description="This image contains the Open Liberty runtime with OpenJ9 JDK 11 and Red Hat's UBI as the base OS.  For more information on this image please see https://github.com/OpenLiberty/ci.docker#building-an-application-image" \
  license="MIT"

COPY --chown=1001:0 docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown=1001:0 environment.sh /opt/environment.sh
COPY --chown=1001:0 cert_tools.sh /opt/cert_tools.sh

USER root

RUN dnf -y update \
  && dnf -y install \
  jq \
  # Clean up
  && dnf clean all

USER 1001

EXPOSE 9080 9443

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
CMD ["/opt/ol/wlp/bin/server", "run", "defaultServer"]