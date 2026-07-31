#!/usr/bin/env bash
#
# refxchange — convert bibliographic reference files between citation formats.
#
# This is a scaffold: argument handling, format resolution, and back-end
# discovery are wired up; the conversion dispatch itself is a stub.

set -uo pipefail

REFXCHANGE_VERSION="0.1.0"
readonly REFXCHANGE_VERSION

# Resolve this script's real directory, following symlinks. `readlink -f` isn't
# portable (macOS ships the BSD one), so walk the chain by hand.
_rx_self="${BASH_SOURCE[0]}"
while [[ -L $_rx_self ]]; do
    _rx_dir="$(cd -- "$(dirname -- "$_rx_self")" && pwd)"
    _rx_self="$(readlink "$_rx_self")"
    [[ $_rx_self != /* ]] && _rx_self="$_rx_dir/$_rx_self"
done
_rx_bin_dir="$(cd -- "$(dirname -- "$_rx_self")" && pwd)"

# Find the tree holding lib/ and locale/. In a checkout that's alongside the
# script; once installed, the script lives in <prefix>/bin and the rest in
# <prefix>/share/refxchange. REFXCHANGE_ROOT in the environment wins.
_rx_find_root() {
    local candidate
    for candidate in \
        ${REFXCHANGE_ROOT-} \
        "$_rx_bin_dir" \
        "$_rx_bin_dir/../share/refxchange" \
        "${XDG_DATA_HOME:-$HOME/.local/share}/refxchange" \
        "/usr/local/share/refxchange" \
        "/usr/share/refxchange"
    do
        if [[ -r "$candidate/lib/formats.sh" ]]; then
            (cd -- "$candidate" && pwd)
            return 0
        fi
    done
    return 1
}

if ! REFXCHANGE_ROOT="$(_rx_find_root)"; then
    printf 'error: cannot locate the RefXChange lib/ directory\n' >&2
    printf 'hint: reinstall, or set REFXCHANGE_ROOT to the checkout\n' >&2
    exit 3
fi
readonly REFXCHANGE_ROOT
unset _rx_self _rx_dir _rx_bin_dir

# shellcheck source=lib/i18n.sh
source "$REFXCHANGE_ROOT/lib/i18n.sh"
# shellcheck source=lib/formats.sh
source "$REFXCHANGE_ROOT/lib/formats.sh"
# shellcheck source=lib/backends.sh
source "$REFXCHANGE_ROOT/lib/backends.sh"

# Exit codes (see README).
readonly EX_OK=0
readonly EX_USAGE=1
readonly EX_FORMAT=2
readonly EX_BACKEND=3
readonly EX_INPUT=4
readonly EX_CONVERT=5

from_fmt=""
to_fmt=""
input=""
output=""
batch=0
encoding="utf-8"
keys=""
force=0
quiet=0
verbose=0

die() { # die <exit-code> <message>
    local code=$1; shift
    printf 'error: %s\n' "$*" >&2
    exit "$code"
}

info() {
    (( quiet )) && return 0
    printf '%s\n' "$*"
}

trace() {
    (( verbose )) && printf '+ %s\n' "$*" >&2
    return 0
}

usage() {
    cat <<EOF
$(_ "RefXChange") $REFXCHANGE_VERSION — $(_ "convert bibliographic reference files")

$(_ "Usage:") refxchange [OPTIONS] -f <FROM> -t <TO> -i <INPUT> [-o <OUTPUT>]

  -f, --from FORMAT      $(_ "Source format (auto-detected from the extension if omitted)")
  -t, --to FORMAT        $(_ "Target format (required)")
  -i, --input PATH       $(_ "Input file, directory, or - for stdin (required)")
  -o, --output PATH      $(_ "Output file or directory (default: stdout)")
  -b, --batch            $(_ "Treat --input as a directory/glob")
  -e, --encoding ENC     $(_ "Character encoding for I/O (default: utf-8)")
  -k, --keys STYLE       $(_ "Normalize BibTeX citation keys (e.g. author_year)")
  -F, --force            $(_ "Overwrite existing output files without prompting")
  -q, --quiet            $(_ "Suppress progress output")
  -v, --verbose          $(_ "Print each back-end command as it runs")
      --version          $(_ "Print version and exit")
  -h, --help             $(_ "Show this help and exit")

$(_ "Formats:") $(supported_formats)
EOF
}

parse_args() {
    while (( $# )); do
        case "$1" in
            -f|--from)     from_fmt="${2-}"; shift 2 || die $EX_USAGE "$(_ "--from requires a value")" ;;
            -t|--to)       to_fmt="${2-}";   shift 2 || die $EX_USAGE "$(_ "--to requires a value")" ;;
            -i|--input)    input="${2-}";    shift 2 || die $EX_USAGE "$(_ "--input requires a value")" ;;
            -o|--output)   output="${2-}";   shift 2 || die $EX_USAGE "$(_ "--output requires a value")" ;;
            -e|--encoding) encoding="${2-}"; shift 2 || die $EX_USAGE "$(_ "--encoding requires a value")" ;;
            -k|--keys)     keys="${2-}";     shift 2 || die $EX_USAGE "$(_ "--keys requires a value")" ;;
            -b|--batch)    batch=1;   shift ;;
            -F|--force)    force=1;   shift ;;
            -q|--quiet)    quiet=1;   shift ;;
            -v|--verbose)  verbose=1; shift ;;
            --version)     printf 'refxchange %s\n' "$REFXCHANGE_VERSION"; exit $EX_OK ;;
            -h|--help)     usage; exit $EX_OK ;;
            -)             input="-"; shift ;;
            --)            shift; break ;;
            -*)            die $EX_USAGE "$(_ "unknown option:") $1" ;;
            *)             [[ -z $input ]] && input="$1"; shift ;;
        esac
    done
}

main() {
    parse_args "$@"

    [[ -n $to_fmt ]] || { usage >&2; die $EX_USAGE "$(_ "--to is required")"; }
    [[ -n $input  ]] || { usage >&2; die $EX_USAGE "$(_ "--input is required")"; }

    if [[ -z $from_fmt ]]; then
        [[ $input == "-" ]] && die $EX_USAGE "$(_ "--from is required when reading from stdin")"
        from_fmt="$(detect_format "$input")" \
            || die $EX_FORMAT "$(_ "could not auto-detect the input format; pass --from")"
    fi

    from_fmt="$(normalize_format "$from_fmt")" || die $EX_FORMAT "$(_ "unsupported format:") $from_fmt"
    to_fmt="$(normalize_format "$to_fmt")"     || die $EX_FORMAT "$(_ "unsupported format:") $to_fmt"

    if [[ $input != "-" && ! -r $input ]]; then
        die $EX_INPUT "$(_ "input not found or unreadable:") $input"
    fi

    local backend
    backend="$(select_backend "$from_fmt" "$to_fmt")" \
        || die $EX_BACKEND "$(_ "no back end can convert") $from_fmt -> $to_fmt"
    require_backend "$backend" || die $EX_BACKEND "$(_ "back end not found:") $backend"

    trace "backend=$backend from=$from_fmt to=$to_fmt encoding=$encoding batch=$batch"

    # TODO: dispatch to the back end (single-file, batch, and stdin paths).
    die $EX_CONVERT "$(_ "conversion is not implemented yet")"
}

main "$@"
