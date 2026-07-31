#!/usr/bin/env bash
#
# Install into a throwaway prefix and check that the installed copy can still
# find its lib/ and locale/ — the failure mode that matters once the script no
# longer sits next to them.

set -uo pipefail

TESTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO="$TESTS_DIR/.."
PREFIX="$(mktemp -d "${TMPDIR:-/tmp}/refxchange-install.XXXXXX")"
trap 'rm -rf "$PREFIX"' EXIT

pass=0
fail=0

check() { # check <description> -- <command...>
    local desc="$1"; shift 2
    if "$@" >/dev/null 2>&1; then
        printf 'ok   %s\n' "$desc"; (( pass++ ))
    else
        printf 'FAIL %s\n' "$desc"; (( fail++ ))
    fi
}

bash "$REPO/install.sh" --prefix "$PREFIX" --quiet || {
    printf 'FAIL install.sh exited %d\n' $?; exit 1
}

check "binary is installed and executable"  -- test -x "$PREFIX/bin/refxchange"
check "lib/ is installed"                   -- test -r "$PREFIX/share/refxchange/lib/formats.sh"
check "locale catalog is installed"         -- test -r "$PREFIX/share/refxchange/locale/en/LC_MESSAGES/refxchange.po"

# Run from an unrelated directory so nothing resolves by accident.
check "installed copy runs --version"       -- env -u REFXCHANGE_ROOT bash -c "cd / && '$PREFIX/bin/refxchange' --version"
check "installed copy renders --help"       -- env -u REFXCHANGE_ROOT bash -c "cd / && '$PREFIX/bin/refxchange' --help"

# A symlink on PATH (the common ~/.local/bin case) must resolve too.
ln -sf "$PREFIX/bin/refxchange" "$PREFIX/refxchange-link"
check "symlinked copy resolves its lib/"    -- env -u REFXCHANGE_ROOT bash -c "cd / && '$PREFIX/refxchange-link' --version"

bash "$REPO/install.sh" --prefix "$PREFIX" --uninstall --quiet
check "uninstall removes the binary"        -- test ! -e "$PREFIX/bin/refxchange"
check "uninstall removes the data dir"      -- test ! -d "$PREFIX/share/refxchange"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
