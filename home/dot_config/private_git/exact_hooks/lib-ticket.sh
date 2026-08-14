#!/bin/sh
# Shared helpers for the global git hooks. Sourced, never run as a hook itself
# (git only invokes hooks by their exact well-known names).
#
# Branch names carry a ticket in front of the slug: <PREFIX>-<number>/<slug>.
# For repos listed in ../issue-prefixes the ticket is a GitHub issue in that
# repo — DOT-12 is dot-files#12. Every other prefix is a Jira-style key this
# machine can't validate, so the hooks leave it alone.

PREFIX_MAP="${XDG_CONFIG_HOME:-$HOME/.config}/git/issue-prefixes"

# This repo's GitHub prefix, or nothing when it isn't in the map. Identity comes
# from origin's URL rather than the working directory: worktrees live at
# ~/worktrees/<repo>/<branch>, where the directory name is the branch.
repo_prefix() {
    [ -f "$PREFIX_MAP" ] || return 1
    url=$(git config --get remote.origin.url 2>/dev/null)
    [ -n "$url" ] || return 1
    name=${url##*/}
    name=${name%.git}
    awk -v repo="$name" '
        /^[[:space:]]*(#|$)/ { next }
        $1 == repo { print $2; found = 1; exit }
        END { exit !found }
    ' "$PREFIX_MAP"
}

# Every prefix the map knows about, one per line.
known_prefixes() {
    [ -f "$PREFIX_MAP" ] || return 1
    awk '/^[[:space:]]*(#|$)/ { next } { print $2 }' "$PREFIX_MAP"
}

# The <PREFIX>-<number> ticket leading the current branch name, if there is one.
# Fails on detached HEAD and on unticketed branches (main, u/sloan/foo, ...).
branch_ticket() {
    branch=$(git branch --show-current 2>/dev/null)
    [ -n "$branch" ] || return 1
    ticket=${branch%%/*}
    printf '%s' "$ticket" | grep -Eq '^[A-Z]+-[0-9]+$' || return 1
    printf '%s' "$ticket"
}
