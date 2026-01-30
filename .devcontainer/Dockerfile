# Maintenance note: If the version of node changes, update the version used by the CI build too.
FROM mcr.microsoft.com/devcontainers/javascript-node:24

RUN sudo ln -s /usr/bin/gpg /usr/local/bin/gpg

# Install maven
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y update \
    && apt-get -y install --no-install-recommends \
      maven \
    && apt-get -y autoremove \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g '@vscode/dev-container-cli'
