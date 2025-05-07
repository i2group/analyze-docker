FROM mcr.microsoft.com/devcontainers/javascript-node:18
RUN sudo ln -s /usr/bin/gpg /usr/local/bin/gpg
# Install maven
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends maven \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
RUN npm install -g '@vscode/dev-container-cli'
