#!/usr/bin/env bats
#
# tests/bats/node_modules/.bin/bats --tap tests/bats/image-mariadb.bats
#
# These tests cover behavior that only the MariaDB image has, so they skip for
# other engines.
#
# The tests copy the source code at the last commit into the test directory,
# so uncommitted changes are not tested.
#
# shellcheck disable=SC2030,SC2031

load _helper

@test "Database upgrade is forced by MARIADB_FORCE_UPGRADE or its deprecated alias" {
  [ "${TEST_ENGINE}" = "mariadb" ] || skip "MariaDB only."

  tag="${TEST_DOCKER_TAG}"
  base_image="testorg/testimagebase:${tag}"
  data_image="${base_image}-data"

  step "Prepare an image with an initialized database."

  substep "Build base image ${base_image} and load into 'docker images'."
  docker buildx build --platform "${BUILDX_PLATFORMS}" --load -t "${base_image}" -f "${TEST_DOCKERFILE}" "${TEST_ENGINE}"

  substep "Start a container from the base image to initialize the database."
  cid="$(docker run --user 1000 -d "${base_image}" 2>&3)"
  wait_mysql "${cid}"

  substep "Stop the container and commit it as ${data_image}."
  docker stop "${cid}"
  docker commit "${cid}" "${data_image}"

  step "Assert that the upgrade follows MARIADB_FORCE_UPGRADE and its deprecated alias."

  # Columns: MARIADB_FORCE_UPGRADE, FORCE_MYSQL_UPGRADE and the expected
  # outcome. 'unset' leaves that variable unset.
  # shellcheck disable=SC2034
  TEST_CASES=(
    "unset" "unset" "upgrade=0 notice=0"
    "1" "unset" "upgrade=1 notice=0"
    "true" "unset" "upgrade=0 notice=0"
    "unset" "1" "upgrade=1 notice=1"
    "1" "0" "upgrade=1 notice=1"
    "0" "1" "upgrade=0 notice=1"
    "" "1" "upgrade=1 notice=1"
    "1" "" "upgrade=1 notice=0"
  )
  dataprovider_run "start_with_upgrade_flags" 3
}

# Starts a container from the image in 'data_image' with the given
# MARIADB_FORCE_UPGRADE and FORCE_MYSQL_UPGRADE values, then prints whether
# the upgrade ran and whether the deprecation notice was printed.
start_with_upgrade_flags() {
  local run_args=(--user 1000 -d)

  if [ "${1}" != "unset" ]; then
    run_args+=(-e "MARIADB_FORCE_UPGRADE=${1}")
  fi

  if [ "${2}" != "unset" ]; then
    run_args+=(-e "FORCE_MYSQL_UPGRADE=${2}")
  fi

  local cid
  cid="$(docker run "${run_args[@]}" "${data_image}" 2>&3)"
  wait_mysql "${cid}"

  local logs
  logs="$(docker logs "${cid}" 2>&1)"
  docker rm -f -v "${cid}" >/dev/null

  local upgrade=0
  if [[ ${logs} == *"starting mysql upgrade"* ]]; then
    upgrade=1
  fi

  local notice=0
  if [[ ${logs} == *"FORCE_MYSQL_UPGRADE is deprecated; use MARIADB_FORCE_UPGRADE instead."* ]]; then
    notice=1
  fi

  echo "upgrade=${upgrade} notice=${notice}"
}
