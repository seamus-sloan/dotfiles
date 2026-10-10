#!/usr/bin/env zsh
# Claude Code subagentStatusLine. Prints nothing, so every row in the agent
# panel keeps its default rendering. It only records each task's status for
# the "agents" segment of statusline-command.sh.

input=$(cat)
session_id=$(jq -r '.session_id // empty' <<<"$input")
[[ -n $session_id ]] || exit 0

dir=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-statusline
mkdir -p "$dir"
state=$dir/$session_id.agents.json
tmp=$(mktemp "$dir/.agents.XXXXXX")
trap 'rm -f "$tmp"' EXIT INT TERM

# Merge over earlier rows: the panel drops finished ones, but counts must stay.
jq -c --slurpfile prev <(cat "$state" 2>/dev/null || print '{}') \
  '($prev[0] // {}) + (.tasks // [] | map({(.id): .status}) | add // {})' \
  <<<"$input" >"$tmp" && mv "$tmp" "$state"
