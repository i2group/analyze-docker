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
ARG UPGRADE_PACKAGES="true"
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
COPY semver_util.sh /usr/bin/semver_util.sh

COPY library-scripts/*.sh /tmp/library-scripts/

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN microdnf update -y \
  && /bin/bash /tmp/library-scripts/common-redhat.sh "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" \
  # Use Docker script from script library to set things up
  && /bin/bash /tmp/library-scripts/docker-redhat.sh "${ENABLE_NONROOT_DOCKER}" "/var/run/docker-host.sock" "/var/run/docker.sock" "${USERNAME}" \
  # Install additional OS packages.
  # jq and curl already installed by common-redhat
  && dnf config-manager --nogpgcheck --add-repo https://cli.github.com/packages/rpm/gh-cli.repo \
  && ARCH=`uname -m` \
  && microdnf -y remove /usr/bin/python \
  && dnf -y module enable nodejs:20 \
  && dnf -y install nodejs unzip \
  && YQ_LATEST_VERSION=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest |  jq -r '.tag_name') \
  && if [[ "${ARCH}" == "aarch64" ]]; then YQ_PACKAGE_NAME="yq_linux_arm64"; else YQ_PACKAGE_NAME="yq_linux_amd64"; fi \
  && wget "https://github.com/mikefarah/yq/releases/download/${YQ_LATEST_VERSION}/${YQ_PACKAGE_NAME}.tar.gz" -O - | tar xz && mv "${YQ_PACKAGE_NAME}" /usr/bin/yq \
  # Install AWS CLI
  && curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip" \
  && unzip awscliv2.zip \
  && ./aws/install \
  # Install session manager plugin
  && if [[ "${ARCH}" == "aarch64" ]]; then RPM_NAME="linux_arm64"; else RPM_NAME="linux_64bit"; fi \
  && curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/${RPM_NAME}/session-manager-plugin.rpm" -o "session-manager-plugin.rpm" \
  && dnf install -y session-manager-plugin.rpm \
  # Install deps
  && microdnf -y install --setopt=install_weak_deps=0 \
  maven \
  diffutils \
  bc \
  gh \
  python3.12 \
  python3.12-pip \
  nodejs \
  npm \
  libxml2 \
  libxslt \
  # Clean up
  && microdnf clean all \
  # Ensure symlinks are created for the correct version of Python
  && ln -sf /usr/bin/python3.12 /usr/bin/python3 \
  && ln -sf /usr/bin/python3.12 /usr/bin/python \
  && ln -sf /usr/bin/pip3.12 /usr/bin/pip3 \
  && ln -sf /usr/bin/pip3.12 /usr/bin/pip \
  # Other dependencies
  && pip3 install --no-cache-dir \
    check-jsonschema \
    s3cmd \
  && curl -fL https://install-cli.jfrog.io | sh \
  && chmod 755 /usr/local/bin/jf \
  && mkdir -p "/home/${USERNAME}/.docker" \
  && chown -R "${USERNAME}" "/home/${USERNAME}"

# Copy the compiled xmlstarlet binary from the base image
COPY --from=i2group/i2eng-analyze-containers-base:ubi-jdk17 /usr/local/bin/xmlstarlet /usr/local/bin/xmlstarlet

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

COPY --chmod=755 semver_util-*.tgz /opt/semver_util.tgz
COPY docker-entrypoint.sh /opt/docker-entrypoint.sh

# Setting the ENTRYPOINT will configure non-root access to 
# the Docker socket and file permissions.
# The script will also execute CMD if you need to alter startup behaviors.
ENTRYPOINT [ "/opt/docker-entrypoint.sh" ]
CMD [ "sleep", "infinity" ]
