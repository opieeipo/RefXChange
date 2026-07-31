#!/usr/bin/env bash
#
# Localization bootstrap. All user-facing strings go through _() so that
# catalogs under locale/ can translate them; there are no bare literals in
# output paths.

export TEXTDOMAIN="refxchange"
export TEXTDOMAINDIR="${TEXTDOMAINDIR:-$REFXCHANGE_ROOT/locale}"

if command -v gettext >/dev/null 2>&1; then
    _() { gettext "$1"; }
else
    # gettext isn't installed — fall back to the source language (English).
    _() { printf '%s' "$1"; }
fi
