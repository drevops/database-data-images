# Contributing

Thank you for considering a contribution to this project. This guide covers setting up a local environment and running the linting and tests.

## Local setup

You'll need Docker, Node.js, `shfmt` and `shellcheck`. Install the BATS test dependencies:

```shell
npm --prefix tests/bats ci
```

## Linting

```shell
shfmt -i 2 -ci -s -d mariadb/seed.mariadb.sh mysql/seed.mysql.sh tests/bats/*.bash tests/bats/*.bats
shellcheck mariadb/seed.mariadb.sh mysql/seed.mysql.sh tests/bats/*.bash tests/bats/*.bats
```

## Testing

```shell
tests/bats/node_modules/.bin/bats tests/bats
```

The tests copy the repository at its last commit, so commit your changes before running them. The seeding tests push images to `drevops/db-data-test` on Docker Hub, so run `docker login` with an account that can push there. To push to another repository, set `TEST_DOCKER_REPOSITORY`.

The 2 seed scripts are standalone copies, because consumers download a single file. Each script has its own test file, named after its engine. Apply a change to both scripts and both test files, unless it's specific to 1 engine. Both scripts must read the same variables, and `tests/bats/seed-surface.bats` fails when they differ.
