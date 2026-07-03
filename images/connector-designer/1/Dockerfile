# syntax=docker/dockerfile:1.3
#To be able to access the Connector Designer software component you must set the
#environment variable "ACCEPT_EULA" to "Y". In doing so you confirm that you hold a
#valid and current license for one of the following i2 products: Analysis Studio or
#Analysis Hub.
#
#Additionally, you agree that your use of the Connector Designer software component
#will be governed by the terms and conditions of the i2 License Agreement, available
#at https://i2group.com/legal.
#
#As with all Docker images, these likely also contain other software which may be
#under other licenses (such as Bash, etc from the base distribution).

# Dynamic labels passed at build time into global-scope
# revision = CI build number or 'dev' for local builds
ARG revision
# version = image version = name of the directory this Dockerfile is in
ARG version

ARG NODEJS_VERSION=22

FROM i2group/i2eng-analyze-containers-base:ubi-jdk17-${revision} as containers-base

FROM i2group/i2eng-analyze-containers-connectors-base:${NODEJS_VERSION}-${revision} as build-our-dependencies

# Install app dependencies
# npm install will install the dependencies defined in npm-shrinkwrap.json if it exists, otherwise in package-lock.json if it exists or if neither the latest dependencies
COPY --chown=default app/package*.json app/npm-shrinkwrap.json* /opt/app-root/src/

# Install our dependencies
RUN npm install --production --maxsockets 1

FROM i2group/i2eng-analyze-containers-connectors-base:${NODEJS_VERSION}-${revision} as build-template-dependencies

# Install app dependencies
# npm install will install the dependencies defined in npm-shrinkwrap.json if it exists, otherwise in package-lock.json if it exists or if neither the latest dependencies
COPY --chown=default app/connector_template/package*.json app/connector_template/npm-shrinkwrap.json* /opt/app-root/src/

# Install our dependencies for the connector template. This cannot be production because it will not install devDependencies needed to build connectors
RUN npm install --maxsockets 1

FROM i2group/i2eng-analyze-containers-connectors-base-minimal:${NODEJS_VERSION}-${revision}

# Bring global-scope args into the build stage
ARG revision
ARG version

LABEL name="i2 Connector Designer" \
  maintainer="i2 Group" \
  version="${version}" \
  revision="${revision}" \
  summary="i2 Connector Designer" \
  description="The connector designer to publish a connector to Analyze Containers." \
  license="MIT"

ARG USERNAME=i2analyze
ARG USER_UID=1001
ARG USER_GID=$USER_UID

ENV USER="${USERNAME}"

USER root
COPY docker-redhat.sh /tmp/library-scripts/docker-redhat.sh
COPY --from=containers-base /usr/local/bin/gosu /usr/local/bin/gosu
COPY docker-entrypoint.sh /opt/docker-entrypoint.sh

RUN set -eux; \
  microdnf -y --refresh install sudo; \
  microdnf clean all; \
  useradd "$USERNAME"; \
  groupmod --gid "$USER_GID" "$USERNAME"; \
  usermod --uid "$USER_UID" --gid $USER_GID "$USERNAME"; \
  echo "${USERNAME} ALL=\(root\) NOPASSWD:ALL" >"/etc/sudoers.d/$USERNAME"; \
  chmod 0440 "/etc/sudoers.d/$USERNAME"; \
  /bin/bash /tmp/library-scripts/docker-redhat.sh "true" "/var/run/docker-host.sock" "/var/run/docker.sock" "$USERNAME"

USER "${USERNAME}"
# Install app dependencies
COPY --from=build-our-dependencies --chown="${USERNAME}" /opt/app-root/src/node_modules /opt/app-root/src/node_modules

# Copy our application code
COPY --chown="${USERNAME}" app/. /opt/app-root/src

# Install template dependencies
COPY --from=build-template-dependencies --chown="${USERNAME}" /opt/app-root/src/node_modules /opt/app-root/src/connector_template/node_modules

WORKDIR /opt/app-root/src

ENV WORKSPACE=/opt/app-root/src

RUN mkdir -p /opt/app-root/src/logs \
  /opt/app-root/src/data/connectorStorage \
  /opt/app-root/src/dist/custom_functions

EXPOSE 3000 3443

# Use root but change at runtime with GOSU
# hadolint ignore=DL3002
USER root

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
# The lifecycle of the connector will be attached to node app
CMD [ "npm", "run", "start" ]
