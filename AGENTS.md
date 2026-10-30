# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

This project provides MariaDB and MySQL Docker images for Drupal that capture database data as Docker layers. Unlike traditional database containers that use volumes, these images store database files in a non-volume location (`/home/db-data`) allowing the entire database to be captured, stored, and distributed as a Docker image.

| Engine | Directory | Image | Base image | Seed script |
|---|---|---|---|---|
| MariaDB 10.11 | `mariadb/` | `drevops/db-data-mariadb-10.11` | `uselagoon/mariadb-10.11-drupal` | `mariadb/seed.mariadb.sh` |
| MySQL 8.4 | `mysql/` | `drevops/db-data-mysql-8.4` | `uselagoon/mysql-8.4` | `mysql/seed.mysql.sh` |

Until 1 March 2027, each release and canary build also pushes the MariaDB image to `drevops/mariadb-drupal-data`, and each release uploads `seed.mariadb.sh` as `seed.sh`.

**Key Innovation**: Database files are stored as Docker layers rather than volumes, enabling instant database availability without time-consuming imports.

## Architecture

### Core Components

1. **mariadb/10.11.Dockerfile** - Extends `uselagoon/mariadb-10.11-drupal` base image:
   - Sets custom data directory via `MARIADB_DATA_DIR=/home/db-data` (not a volume)
   - Replaces entrypoint script to support custom data directory
   - Overrides CMD to use `--datadir=/home/db-data`

2. **mariadb/entrypoint.bash** - Modified from [upstream](https://github.com/uselagoon/lagoon-images/blob/main/images/mariadb/entrypoints/9999-mariadb-init.10.bash):
   - Supports `MARIADB_DATA_DIR` environment variable
   - Handles database initialization in custom location
   - Supports `MARIADB_COPY_DATA_DIR_SOURCE` for pre-filling data
   - Includes `MARIADB_FORCE_UPGRADE` flag for forcing upgrades, with `FORCE_MYSQL_UPGRADE` as a deprecated alias

3. **mysql/8.4.Dockerfile** - Extends `uselagoon/mysql-8.4` base image:
   - Sets custom data directory via `MYSQL_DATA_DIR=/home/db-data` (not a volume); the upstream entrypoint supports it as is
   - Sets the `drupal` database, user and password, because upstream has no Drupal variant
   - Turns off binary logging via `mysql/disable-binlog.cnf`, because the binary log doubles the size of the captured data

4. **mariadb/seed.mariadb.sh** and **mysql/seed.mysql.sh** - 3-stage database seeding scripts. They're standalone copies, because consumers download a single file, so apply a shared change to both:
   - **Stage 1**: Import SQL dump into temporary container and extract database files
   - **Stage 2**: Build new image with extracted database files using `docker buildx`
   - **Stage 3**: Verify database exists in the new image
   - Takes the destination image from `DESTINATION_IMAGE`, then the deprecated `DST_IMAGE` alias, then the second argument
   - Tags an untagged destination `latest`, looking for the tag only in the last path component so a registry port isn't read as one
   - Ends by printing the Docker Hub tags page for a Docker Hub destination (with or without a `docker.io/` prefix), or the pushed reference for any other registry; a first path component with a `.`, a `:` or an uppercase letter, or `localhost`, is a registry host, as in Docker's reference parsing
   - When `SANITIZE_PROCEED` is `1` (default `0`; `true` leaves it off), runs the SQL queries from `SANITIZE_FILE` (default `./scripts/sanitize.sql`) in a separate container and imports that container's export into the captured one; a failing query, or a dump or query that changes accounts, grants or other tables in the `mysql` system database, stops seeding before Stage 2
   - Builds images for the host platform by default; multi-platform builds (linux/amd64, linux/arm64) are opt-in via `DESTINATION_PLATFORMS`
   - Uses `docker buildx` to push directly to registry during build
   - `seed.mysql.sh` differs from `seed.mariadb.sh` in these ways: the port check uses Bash's `/dev/tcp` because the image has no `nc`; the system table check reads `performance_schema`; the checksums cover MySQL's account tables and a `NULL` checksum stops seeding; there's no `mysql_upgrade` step, because the server upgrades on start; the server stops cleanly before the data files are copied

### Important Patterns

- Database files must be in `/home/db-data` (not `/var/lib/mysql`)
- Upstream base image versions follow the [uselagoon/mariadb-10.11-drupal tags](https://hub.docker.com/r/uselagoon/mariadb-10.11-drupal/tags) and [uselagoon/mysql-8.4 tags](https://hub.docker.com/r/uselagoon/mysql-8.4/tags)
- Each engine has its own directory, with the engine version in the Dockerfile name; release assets are flat, so the seed scripts keep the engine in their file name
- The MariaDB entrypoint script is minimally modified for easy upstream updates
- Containers typically run as user `1000` (not `mysql`) in production
- Sanitization must not run in the captured container: InnoDB's redo log keeps the replaced values, and the redo log is captured with the data files

## Development Commands

### Testing

Run all BATS tests:

```bash
npm --prefix tests/bats ci
tests/bats/node_modules/.bin/bats tests/bats
```

Run specific BATS test file:

```bash
tests/bats/node_modules/.bin/bats tests/bats/image.bats --tap
tests/bats/node_modules/.bin/bats tests/bats/image-mariadb.bats --tap
tests/bats/node_modules/.bin/bats tests/bats/seed.bats --tap
tests/bats/node_modules/.bin/bats tests/bats/helper.bats --tap
```

Run tests for the MySQL image (the default is `mariadb`):

```bash
TEST_ENGINE=mysql tests/bats/node_modules/.bin/bats tests/bats
```

BATS test conventions:

- Tests in `tests/bats/` with `.bats` extension
- `TEST_ENGINE` selects the engine; `TEST_DOCKER_REPOSITORY` selects the repository the seeding tests push to (default `drevops/db-data-test`)
- Helper functions in `tests/bats/_helper.bash`
- Coverage exclusions: `# LCOV_EXCL_START` / `# LCOV_EXCL_STOP` (the region markers kcov recognizes)

Run Goss tests (structural tests):

```bash
docker build -t gosstestorg/gosstestimage:goss-test-tag -f mariadb/10.11.Dockerfile mariadb
GOSS_FILES_PATH=tests/dgoss/mariadb dgoss run -i gosstestorg/gosstestimage:goss-test-tag

docker build -t gosstestorg/gosstestimage:goss-test-tag -f mysql/8.4.Dockerfile mysql
GOSS_FILES_PATH=tests/dgoss/mysql dgoss run -i gosstestorg/gosstestimage:goss-test-tag
```

### Linting

Lint shell scripts:

```bash
shfmt -i 2 -ci -s -d mariadb/seed.mariadb.sh mysql/seed.mysql.sh tests/bats/*.bash tests/bats/*.bats
shellcheck mariadb/seed.mariadb.sh mysql/seed.mysql.sh tests/bats/*.bash tests/bats/*.bats
```

### Building and Seeding

Build images locally:

```bash
docker build -t drevops/db-data-mariadb-10.11:local -f mariadb/10.11.Dockerfile mariadb
docker build -t drevops/db-data-mysql-8.4:local -f mysql/8.4.Dockerfile mysql
```

Seed image with database (host platform by default):

```bash
./mysql/seed.mysql.sh path/to/db.sql myorg/myimage:latest
```

Seed image with database (multi-platform):

```bash
DESTINATION_PLATFORMS=linux/amd64,linux/arm64 ./mysql/seed.mysql.sh path/to/db.sql myorg/myimage:latest
```

Seed image with a sanitized database:

```bash
SANITIZE_PROCEED=1 SANITIZE_FILE=path/to/sanitize.sql ./mysql/seed.mysql.sh path/to/db.sql myorg/myimage:latest
```

Use custom base image:

```bash
BASE_IMAGE=drevops/db-data-mysql-8.4:canary ./mysql/seed.mysql.sh path/to/db.sql myorg/myimage:latest
```

`./mariadb/seed.mariadb.sh` takes the same arguments and variables.

### Platform-specific Testing

Tests run for the host platform by default. To force a specific platform, set `DOCKER_DEFAULT_PLATFORM` (the tests derive `BUILDX_PLATFORMS` from it); forcing a foreign platform requires emulation, under which MariaDB does not start reliably:

```bash
DOCKER_DEFAULT_PLATFORM=linux/arm64 tests/bats/node_modules/.bin/bats tests/bats/image.bats
```

## CI/CD

### Workflows

**test.yml** - Runs on PRs and pushes to main:
- Runs the test job for each engine on a matrix: native amd64 (`ubuntu-latest`), native arm64 (`ubuntu-24.04-arm`), and amd64 inside the `drevops/ci-runner` container (the "custom runner" jobs)
- Lints shell scripts with `shfmt` and `shellcheck` (custom runner jobs only)
- Runs Goss structural tests
- Runs BATS tests with code coverage (kcov; coverage collected on the custom runner jobs only)
- Uploads coverage to Codecov
- Pushes `canary` tag of both images to DockerHub on main branch

**release-docker.yml** - Runs on Git tags:
- Builds and pushes versioned + `latest` tags of both images to DockerHub
- Uploads `seed.mariadb.sh`, `seed.mysql.sh` and a copy of `seed.mariadb.sh` named `seed.sh` as release assets

**draft-release-notes.yml** - Runs on pushes to main and on Git tags:
- Drafts release notes using release-drafter with CalVer version when the `RELEASE_VERSION_SCHEME` variable is `calver`

**assign-author.yml** - Runs when a PR is opened or reopened:
- Assigns the PR author to the PR

### Configuration

- Multi-platform builds: `linux/amd64,linux/arm64`
- Required secrets: `DOCKER_USER` (Docker Hub username) and `DOCKER_PASS` (Docker Hub access token)
- Optional secrets: `CODECOV_TOKEN` (the Codecov upload is skipped without it)
- Required vars: `RELEASE_VERSION_SCHEME` set to `calver`
- Optional vars: `CI_LINT_IGNORE_FAILURE`, `CI_TEST_IGNORE_FAILURE` (set to '1' to ignore failures)

## Important Notes

- Always test changes by committing first (BATS tests copy code from last commit)
- The MariaDB entrypoint script should remain minimally modified for easy upstream syncing
- When updating base image version, follow upstream versioning
- The seed scripts require being logged into Docker registry (they push during buildx)
- Tests run for the host platform unless explicitly configured otherwise
- Renovate's `github-actions` manager doesn't read workflow matrix values, so a custom regex manager in `renovate.json` tracks the `drevops/ci-runner` image in the `test.yml` matrix; it only matches the `container: <image>:<tag>@<digest>` form, so keep that form when editing the matrix

## Updating from the template

This project was generated from a template and can pull the template's latest
infrastructure (CI workflows, linting and test configuration, Docker, and docs)
at any time. When you are asked to "update scaffold", fetch the updater skill
from the template repository into the local `.claude/skills/` directory, then
invoke it:

1. Create the target directory if it does not exist:

   ```bash
   mkdir -p .claude/skills/update-consumer-scaffold
   ```

2. Download the skill:

   ```bash
   curl -sSL https://raw.githubusercontent.com/AlexSkrypnyk/scaffold/main/.scaffold/skills/update-consumer-scaffold/SKILL.md -o .claude/skills/update-consumer-scaffold/SKILL.md
   ```

3. Invoke the `update-consumer-scaffold` skill and follow its steps.

The skill directory is fetched on demand and is git-ignored - it is not
committed to the project.
