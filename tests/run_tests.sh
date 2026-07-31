#!/usr/bin/env bash
#
# Smoke tests. These exercise the CLI plumbing (usage, version, exit codes,
# format resolution) — not conversion, which is still a stub.

set -uo pipefail

TESTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RX="$TESTS_DIR/../refxchange.sh"

pass=0
fail=0

expect_status() { # expect_status <expected> <description> -- <command...>
    local expected="$1" desc="$2"; shift 3
    "$@" >/dev/null 2>&1
    local got=$?
    if [[ $got == "$expected" ]]; then
        printf 'ok   %s\n' "$desc"
        (( pass++ ))
    else
        printf 'FAIL %s (expected exit %s, got %s)\n' "$desc" "$expected" "$got"
        (( fail++ ))
    fi
}

expect_status 0 "--version exits 0"                  -- bash "$RX" --version
expect_status 0 "--help exits 0"                     -- bash "$RX" --help
expect_status 1 "missing --to is a usage error"      -- bash "$RX" -i "$TESTS_DIR/fixtures/sample.ris"
expect_status 1 "missing --input is a usage error"   -- bash "$RX" -t bibtex
expect_status 1 "unknown option is a usage error"    -- bash "$RX" --nope
expect_status 2 "unsupported format exits 2"         -- bash "$RX" -f ris -t quux -i "$TESTS_DIR/fixtures/sample.ris"
expect_status 4 "missing input file exits 4"         -- bash "$RX" -f ris -t bibtex -i "$TESTS_DIR/fixtures/nope.ris"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
