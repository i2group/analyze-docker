# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT
# 
# Inspired by: https://github.com/microsoft/vscode-dev-containers/blob/main/containers/debian/.devcontainer/base.Dockerfile
FROM registry.access.redhat.com/ubi8/ubi:8.7

# Dynamic labels
ARG revision \
  version

# [Option] Upgrade OS packages to their latest versions
ARG UPGRADE_PACKAGES="false"
# [Option] Enable non-root Docker access in container
ARG ENABLE_NONROOT_DOCKER="true"

LABEL name="Analyze Containers Dev Container" \
  version="${version}" \
  revision="${revision}" \
  maintainer="i2 Group" \
  summary="Access your host's Docker install from inside a dev container." \
  description="Access your host's Docker install from inside a dev container." \
  license="MIT"

ARG vscode="false"
RUN test "$vscode" == "false" && (printf "\nERROR: This Dockerfile needs to be built with VS Code !" && exit 1) || printf "VS Code is detected: %s" "$vscode"

# Install needed packages and setup non-root user. Use a separate RUN statement to add your
# own dependencies. A user of "vscode" attempts to reuse an user ID if one already exists.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

COPY --from=adoptopenjdk/openjdk11:ubi-minimal "/opt/java/openjdk" "/opt/java/openjdk"
ENV JAVA_HOME="/opt/java/openjdk" \
  PATH="/opt/java/openjdk/bin:$PATH"

COPY initShell.sh /usr/bin/initShell.sh

COPY library-scripts/*.sh /tmp/library-scripts/

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN /bin/bash /tmp/library-scripts/common-redhat.sh "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" \
  # Use Docker script from script library to set things up
  && /bin/bash /tmp/library-scripts/docker-redhat.sh "${ENABLE_NONROOT_DOCKER}" "/var/run/docker-host.sock" "/var/run/docker.sock" "${USERNAME}" \
  # Install additional OS packages.
  # jq and curl already installed by common-redhat
  && dnf update \
  # Epel 8 doesn't have the xmlstarlet package
  && dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
  && dnf -y install \
  xmlstarlet \
  maven \
  && dnf -y remove https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
  && dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm \
  # Clean up
  && dnf clean all

# Source initShell.sh in bashrc
RUN echo '. /usr/bin/initShell.sh -y' >> "/home/${USERNAME}/.bashrc"

# Setting the ENTRYPOINT to docker-init.sh will configure non-root access to 
# the Docker socket if "overrideCommand": false is set in devcontainer.json. 
# The script will also execute CMD if you need to alter startup behaviors.
ENTRYPOINT [ "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]
