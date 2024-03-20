# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT

FROM registry.access.redhat.com/ubi9/nodejs-18-minimal

# Dynamic labels
ARG revision

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL name="Analyze Containers Connectors Base" \
  version="18" \
  revision="${revision}" \
  maintainer="i2 Group" \
  summary="Image for i2 Analyze Connectors with NodeJS and Red Hat's UBI minimal." \
  description="This image contains NodeJS JavaScript runtime and a stripped down Red Hat's UBI as the base OS." \
  license="MIT"

COPY environment.sh /opt/environment.sh
