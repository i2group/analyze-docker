# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

FROM haproxy:2.9

# Dynamic labels
ARG revision

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL name="HA Proxy" \
  version="ubi" \
  revision="${revision}" \
  maintainer="i2 Group" \
  summary="HA Proxy image." \
  description="This image contains HA Proxy" \
  license="MIT"

ARG USER=haproxy
ARG USER_UID=1000
ARG USER_GID=$USER_UID

USER root
RUN groupmod --gid $USER_GID $USER \
  && usermod --uid $USER_UID --gid $USER_GID $USER \
  && mkdir -p /opt /usr/local/etc/haproxy \
  && chown -R $USER_UID:$USER_GID /opt \
  /usr/local/etc/haproxy

RUN apt-get update \
  && apt-get -y --no-install-recommends install \
  sudo \
  && rm -rf /var/lib/apt/lists/*

# Add sudo
RUN echo "haproxy ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER ${USER}

COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY environment.sh /opt/environment.sh

VOLUME ["/usr/local/etc/haproxy"]

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]