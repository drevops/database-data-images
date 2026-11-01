#!/usr/bin/env bats
#
# tests/bats/node_modules/.bin/bats --tap tests/bats/seed-surface.bats
#
# shellcheck disable=SC2030,SC2031

load _helper

seed_script_variables() {
  grep -oE '\$\{[A-Z_][A-Z0-9_]*' "${1}" | sed 's/^..//' | sort -u
}

@test "Seed scripts read the same variables" {
  assert_equal "$(seed_script_variables ./mariadb/seed.mariadb.sh)" "$(seed_script_variables ./mysql/seed.mysql.sh)"
}

@test "Seed script variables are listed from the script" {
  cat >"${BUILD_DIR}/script.sh" <<'EOF'
SECOND="${SECOND:-${FIRST:-${1-}}}"
[ -n "${FIRST:-}" ]
[ -n "${FIRST2:-}" ]
lowercase="${lowercase_value}"
EOF

  run seed_script_variables "${BUILD_DIR}/script.sh"
  assert_success
  assert_output "FIRST
FIRST2
SECOND"
}
