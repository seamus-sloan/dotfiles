#!/bin/bash
# repo-code.sh — prints the short project code for the repo containing $1
# (defaults to $PWD), and prints nothing at all when that directory isn't inside
# a git repo.
#
# The code comes from ~/.claude/repo-codes when the repo has a row there, and is
# otherwise guessed from the repo name.
#
# Shared by ~/.claude/hooks/session-title.sh and
# ~/.config/opencode/plugins/session-title.js so both agents label a session
# with the same code. Documented in ~/.claude/skills/session-title/SKILL.md.

set -euo pipefail

DIR="${1:-$PWD}"
CODES="$HOME/.claude/repo-codes"

# Name of the repo containing $1, empty if it isn't a git repo. Uses
# --git-common-dir so a worktree at ~/worktrees/<repo>/<branch> resolves to
# <repo> rather than to the branch-named directory it actually sits in.
repo_name() {
  local dir="$1" gcd abs
  [ -d "$dir" ] || return 0
  gcd=$(cd "$dir" && git rev-parse --git-common-dir 2>/dev/null) || return 0
  [ -n "$gcd" ] || return 0
  abs=$(cd "$dir" && cd "$gcd" && pwd) || return 0
  basename "$(dirname "$abs")"
}

# Initials of the hyphen/underscore/dot-separated words, uppercased, capped at
# three characters: mock-controller → MC, platform → P, drone-userland → DU.
guess_code() {
  printf '%s' "$1" | tr '_.' '--' | awk -F'-' '{
    out = ""
    for (i = 1; i <= NF && length(out) < 3; i++) {
      w = $i
      gsub(/[^[:alnum:]]/, "", w)
      if (w != "") out = out toupper(substr(w, 1, 1))
    }
    print out
  }'
}

REPO=$(repo_name "$DIR")
[ -n "$REPO" ] || exit 0

PINNED=""
if [ -f "$CODES" ]; then
  PINNED=$(awk -v r="$REPO" \
    '!/^[[:space:]]*#/ && NF >= 2 && $1 == r { print $2; exit }' "$CODES")
fi

if [ -n "$PINNED" ]; then
  printf '%s\n' "$PINNED"
else
  guess_code "$REPO"
fi
