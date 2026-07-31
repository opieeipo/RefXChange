#!/usr/bin/env bash
#
# Format identifiers, aliases, and extension-based auto-detection.

# Canonical format -> space-separated aliases.
readonly REFX_FORMATS="ris nbib bibtex biblatex endnote endnote-xml csljson mods word"

normalize_format() { # normalize_format <name> -> canonical name on stdout
    # Case-fold portably: macOS still ships bash 3.2, which lacks ${var,,}.
    local fmt
    fmt="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    case "$fmt" in
        ris)                 printf 'ris' ;;
        nbib|medline)        printf 'nbib' ;;
        bibtex|bib)          printf 'bibtex' ;;
        biblatex)            printf 'biblatex' ;;
        endnote|enw)         printf 'endnote' ;;
        endnote-xml|endnotexml) printf 'endnote-xml' ;;
        csljson|json)        printf 'csljson' ;;
        mods)                printf 'mods' ;;
        word|docx)           printf 'word' ;;
        *)                   return 1 ;;
    esac
}

detect_format() { # detect_format <path> -> canonical name on stdout
    local ext="${1##*.}"
    [[ "$ext" == "$1" ]] && return 1   # no extension at all
    normalize_format "$ext"
}

supported_formats() {
    printf '%s' "$REFX_FORMATS"
}
