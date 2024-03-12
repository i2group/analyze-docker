# syntax=docker/dockerfile:1.3
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT
# 
# Inspired by: https://github.com/microsoft/vscode-dev-containers/blob/main/containers/debian/.devcontainer/base.Dockerfile
FROM eclipse-temurin:17-ubi9-minimal

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
ARG S3CMD_VERSION="2.3.0"

ENV JAVA_HOME="/opt/java/openjdk" \
  PATH="/opt/java/openjdk/bin:$PATH" \
  USERNAME="${USERNAME}" \
  DEVCONTAINER="true"

COPY initShell.sh /usr/bin/initShell.sh

COPY library-scripts/*.sh /tmp/library-scripts/

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN /bin/bash /tmp/library-scripts/common-redhat.sh "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" \
  # Use Docker script from script library to set things up
  && /bin/bash /tmp/library-scripts/docker-redhat.sh "${ENABLE_NONROOT_DOCKER}" "/var/run/docker-host.sock" "/var/run/docker.sock" "${USERNAME}" \
  # Install additional OS packages.
  # jq and curl already installed by common-redhat
  && microdnf update \
  && dnf config-manager --nogpgcheck --add-repo https://cli.github.com/packages/rpm/gh-cli.repo \
  && ARCH=`uname -m` \
  # Epel 8 and 9 doesn't have the xmlstarlet package
  && yumdownloader --resolve "http://mirror.stream.centos.org/9-stream/AppStream/${ARCH}/os/Packages/xmlstarlet-1.6.1-20.el9.${ARCH}.rpm" \
  && rpm -ivh *.rpm \
  && rm *.rpm \
  # Install deps
  && microdnf -y install \
  maven \
  diffutils \
  bc \
  gh \
  python3-pip \
  npm \
  # Clean up
  && microdnf clean all \
  # Other dependencies
  && pip3 install --no-cache-dir \
    check-jsonschema \
    s3cmd \
  && curl -fL https://install-cli.jfrog.io | sh \
  && chmod 755 /usr/local/bin/jf

# Save command bash history
# hadolint ignore=SC2028
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory \
  && echo "$SNIPPET" >> "/home/$USERNAME/.bashrc" \
  && echo 'export INPUTRC=~/.inputrc' >> "/home/${USERNAME}/.bashrc" \
  && echo '"\e[B": history-search-forward' >> "/home/${USERNAME}/.inputrc" \
  && echo '"\e[A": history-search-backward' >> "/home/${USERNAME}/.inputrc" \
  && echo '. /usr/bin/initShell.sh -y' >> "/home/${USERNAME}/.bashrc"

COPY docker-entrypoint.sh /opt/docker-entrypoint.sh

# Setting the ENTRYPOINT will configure non-root access to 
# the Docker socket and file permissions.
# The script will also execute CMD if you need to alter startup behaviors.
ENTRYPOINT [ "/opt/docker-entrypoint.sh" ]
CMD [ "sleep", "infinity" ]
