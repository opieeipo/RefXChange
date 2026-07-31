#!/usr/bin/env bash
#
# Back-end discovery and routing. RefXChange shells out to bibutils and pandoc;
# this decides which one handles a given conversion and whether it's installed.

# Formats pandoc handles natively (as bibliography readers/writers).
readonly REFX_PANDOC_FORMATS="bibtex biblatex csljson"

_is_pandoc_format() {
    [[ " $REFX_PANDOC_FORMATS " == *" $1 "* ]]
}

select_backend() { # select_backend <from> <to> -> backend name on stdout
    local from="$1" to="$2"
    if _is_pandoc_format "$from" && _is_pandoc_format "$to"; then
        printf 'pandoc'
    else
        printf 'bibutils'
    fi
}

require_backend() { # require_backend <name>
    case "$1" in
        pandoc)   command -v pandoc >/dev/null 2>&1 ;;
        # bibutils ships a family of binaries; ris2xml is a representative probe.
        bibutils) command -v ris2xml >/dev/null 2>&1 ;;
        *)        return 1 ;;
    esac
}
