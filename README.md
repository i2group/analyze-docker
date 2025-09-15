# Analyze Docker


Welcome to the GitHub home page for the Docker image packaging for the official i2 images. The analyze-docker
repository provides Dockerfiles used in [Analyze Containers](https://github.com/i2group/analyze-deployment-tooling)
which provide a reference architecture for creating a containerized deployment of i2 Analyze.

## Table of Contents

- [Analyze Docker](#analyze-docker)
  - [Versioning](#versioning)
    - [Stable](#stable)
    - [Latest](#latest)
    - [Unique](#unique)
  - [Image Updates](#image-updates)
  - [Image Patch Updates](#image-patch-updates)
- [User Feedback](#user-feedback)
- [Related](#related)
- [Attribution](#attribution)

## Versioning

There are 3 type of versions that are supported in this project: stable, latest, unique. We attempt to follow [semver](https://semver.org/) as close to what our dependencies do.

To identify each Docker image version we use Docker tags with a naming convention for each type.

### Stable

Each stable versions/tags move with the most recent _distinct_ version release. This is the major and minor version when semver is followed.

Example 1: Solr `8` tag currently points to version `8.11.2`, later a build publishes version `8.11.3` so the `8` tag gets updated to point to the new fix pack update `8.11.3`.
Additionally, `8.11` tag was pointing to version `8.11.2` and got updated to point to `8.11.3`.

Example 2: Solr `8` tag currently points to version `8.11.3`, later a build publishes version `8.12.0` so the `8` tag gets updated to point to the new minor update `8.12.0`.
Additionally, `8.11` tag points to version `8.11.2` and a new tag `8.12` got created to point to `8.12.0`.

### Latest

The tag `latest` always points to the most recent release.

### Unique

These tags are useful for deployments since they don't move aka. once they are pushed they forever point to the same Docker image SHA.

Naming convention: `<stable_name>-<build_number>`

E.g. `8.11-234`

### Main (Dev only)

The tags with suffix `-main` are currently in development and not supported for production use.

## Image Updates

To create a new version of a Docker image (e.g., Solr):

1. **Compare versions**: Find the 'inspired by' link in the Docker image's [README.md](https://github.com/i2group/analyze-docker-internal/blob/ba94ae3eaa0bd1e8b75e5606f5751d9684777b32/images/solr/README.md?plain=1#L16). Open the linked public GitHub repository and examine the Dockerfile history between the current version and the target version. Note the changes and apply them to the Dockerfile(s) in this repository.

2. **Submit changes**: Create a PR branch with your changes (automatically tested by CircleCI). Ensure the build passes, then get the code reviewed and merge into the `main` branch.

3. **Internal testing**: Committing to the main branch triggers a Docker image build with a unique tag on Docker Hub (e.g., `i2group/i2eng-solr:9.9-57733`). Internal developers should test this tag for compatibility with all tooling (ADT).

4. **Production release**: Once developers confirm the image works correctly, add the `backport cd` label to the merged PR (found in closed PRs). This backports changes to the `cd` branch, which builds and tests the new Docker image with production tags (`<major version>`, `<major version.minor version>`, and `latest`). The process also commits changes from this repository's `cd` branch to the public `analyze-docker` repository's `main` branch.

## Image patch updates

There is a weekly scheduled build (Sun 00:00:00 UTC) which pulls latest patches of all dependencies for the images.

Given the nature of some images (hardcoded version + shasum), manual updates are required which are scheduled to be done monthly when necessary.

The list is as follows:

- Solr
- ZooKeeper
- Prometheus

---

To read more about the available versions go to:

- [Analyze Containers Dev](./images/analyze-containers-dev/README.md)
- [Grafana](./images/grafana/README.md)
- [Liberty](./images/liberty/README.md)
- [Postgres](./images/postgres/README.md)
- [Prometheus](./images/prometheus/README.md)
- [Solr](./images/solr/README.md)
- [SQL Server](./images/sqlserver/README.md)
- [ZooKeeper](./images/zookeeper/README.md)

## User Feedback

You can raise issues and questions about the i2 images [HERE](https://github.com/i2group/analyze-docker/issues).

## Related

The images in this repository can be used with the [Analyze Containers](https://i2group.github.io/analyze-deployment-tooling) environment.

## Attribution

The Dockerfiles used in this project are based off the work from:

- [vscode-dev-containers](https://github.com/microsoft/vscode-dev-containers/blob/main/containers/debian/.devcontainer/base.Dockerfile)
- [ci.docker](https://github.com/WASdev/ci.docker)
- [prometheus](https://github.com/prometheus/prometheus)
- [docker-solr](https://github.com/docker-solr/docker-solr) [ARCHIVED]
- [zookeeper-docker](https://github.com/31z4/zookeeper-docker)
