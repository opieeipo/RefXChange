#!/usr/bin/env bash
#
# Install RefXChange into a user-local prefix (no root required).
#
#   ./install.sh                      # -> ~/.local/bin/refxchange
#   ./install.sh --prefix /usr/local  # system-wide (needs write access)
#   ./install.sh --link               # symlink to this checkout, for development
#   ./install.sh --uninstall          # remove it again
#
# Layout created under <prefix>:
#   bin/refxchange              the executable
#   share/refxchange/lib/       sourced helper modules
#   share/refxchange/locale/    message catalogs (.mo compiled when msgfmt exists)

set -uo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
mode="install"
link=0
force=0
quiet=0

say() { (( quiet )) || printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Install RefXChange into a user-local prefix (no root required).

  ./install.sh                      # -> ~/.local/bin/refxchange
  ./install.sh --prefix /usr/local  # system-wide (needs write access)
  ./install.sh --link               # symlink to this checkout, for development
  ./install.sh --uninstall          # remove it again

Options:
  --prefix DIR   install root (default: $HOME/.local, or $PREFIX)
  --link         symlink the command at this checkout instead of copying
  --uninstall    remove a previous install from the prefix
  -f, --force    overwrite a target that isn't a RefXChange install
  -q, --quiet    suppress progress output
  -h, --help     show this help

Layout created under <prefix>:
  bin/refxchange              the executable
  share/refxchange/lib/       sourced helper modules
  share/refxchange/locale/    message catalogs (.mo compiled when msgfmt exists)
EOF
}

while (( $# )); do
    case "$1" in
        --prefix)     PREFIX="${2-}"; [[ -n $PREFIX ]] || die "--prefix requires a directory"; shift 2 ;;
        --prefix=*)   PREFIX="${1#*=}"; shift ;;
        --link)       link=1; shift ;;
        --uninstall)  mode="uninstall"; shift ;;
        --force|-f)   force=1; shift ;;
        --quiet|-q)   quiet=1; shift ;;
        --help|-h)    usage; exit 0 ;;
        *)            die "unknown option: $1 (try --help)" ;;
    esac
done

BIN_DIR="$PREFIX/bin"
DATA_DIR="$PREFIX/share/refxchange"
TARGET="$BIN_DIR/refxchange"

# Only clobber something we recognize as ours, unless --force says otherwise.
is_ours() {
    [[ -L $1 ]] && return 0
    [[ -f $1 ]] && grep -q 'REFXCHANGE_VERSION' "$1" 2>/dev/null
}

if [[ $mode == uninstall ]]; then
    removed=0
    if [[ -e $TARGET || -L $TARGET ]]; then
        is_ours "$TARGET" || (( force )) || die "$TARGET is not a RefXChange install (use --force)"
        rm -f "$TARGET" && say "removed $TARGET" && removed=1
    fi
    if [[ -d $DATA_DIR ]]; then
        rm -rf "$DATA_DIR" && say "removed $DATA_DIR" && removed=1
    fi
    (( removed )) || say "nothing to uninstall under $PREFIX"
    exit 0
fi

[[ -r "$SRC_DIR/refxchange.sh" ]] || die "run this from the RefXChange checkout"

mkdir -p "$BIN_DIR" || die "cannot create $BIN_DIR"

if [[ -e $TARGET || -L $TARGET ]]; then
    is_ours "$TARGET" || (( force )) || die "$TARGET already exists and isn't ours (use --force)"
    rm -f "$TARGET"
fi

if (( link )); then
    # The script resolves symlinks to find its own lib/, so a bare link is enough.
    ln -s "$SRC_DIR/refxchange.sh" "$TARGET" || die "cannot symlink $TARGET"
    chmod +x "$SRC_DIR/refxchange.sh"
    say "linked $TARGET -> $SRC_DIR/refxchange.sh"
else
    mkdir -p "$DATA_DIR/lib" "$DATA_DIR/locale" || die "cannot create $DATA_DIR"
    install -m 0755 "$SRC_DIR/refxchange.sh" "$TARGET" || die "cannot install $TARGET"
    install -m 0644 "$SRC_DIR"/lib/*.sh "$DATA_DIR/lib/" || die "cannot install lib/"

    # Ship the catalogs; compile them when the gettext tools are available.
    for po in "$SRC_DIR"/locale/*/LC_MESSAGES/refxchange.po; do
        [[ -r $po ]] || continue
        lang="$(basename "$(dirname "$(dirname "$po")")")"
        mkdir -p "$DATA_DIR/locale/$lang/LC_MESSAGES"
        install -m 0644 "$po" "$DATA_DIR/locale/$lang/LC_MESSAGES/"
        if command -v msgfmt >/dev/null 2>&1; then
            msgfmt -o "$DATA_DIR/locale/$lang/LC_MESSAGES/refxchange.mo" "$po" \
                || say "warning: could not compile the $lang catalog"
        fi
    done
    command -v msgfmt >/dev/null 2>&1 \
        || say "note: gettext's msgfmt not found — messages stay in English"

    say "installed $TARGET"
    say "          $DATA_DIR"
fi

case ":${PATH-}:" in
    *":$BIN_DIR:"*)
        say "$BIN_DIR is already on your PATH — run: refxchange --version" ;;
    *)
        say ""
        say "$BIN_DIR is not on your PATH. Add it:"
        case "${SHELL##*/}" in
            zsh)  say "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc && exec zsh" ;;
            bash) say "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc && exec bash" ;;
            fish) say "  fish_add_path $BIN_DIR" ;;
            *)    say "  export PATH=\"$BIN_DIR:\$PATH\"" ;;
        esac ;;
esac
