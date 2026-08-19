#!/bin/bash
# session-title.sh — keeps the CCD session title in the shape
#
#   "<Objective> - <CODE>"        e.g. "Rename Sessions - D"
#
# where <Objective> is at most four words and <CODE> is the project's short code.
# Once a PR is opened the title gains its number:
#
#   "#123 Rename Sessions - D"
#
# The code comes from ~/.claude/repo-codes when the repo has a row there, and is
# otherwise guessed from the repo name. Only a cwd that isn't a git repo at all
# ends up with no suffix.
#
# The hook never renames anything itself. In the desktop app there is no way for
# it to: /rename is a TUI-only slash command (`requires: {ink: true}`), and the
# session's messagingSocketPath ignores a rename control message — the registry
# `name` field it would set is not what the sidebar renders. The only working
# lever is the set_session_title MCP tool, which the model calls. So this hook
# injects an instruction via additionalContext and lets the model act.
#
# Patterns and rationale documented in ~/.claude/skills/session-title/SKILL.md.

set -euo pipefail

INPUT=$(cat)
EVENT=$(jq -r '.hook_event_name // ""' <<<"$INPUT")
SESSION=$(jq -r '.session_id // ""' <<<"$INPUT")
CWD=$(jq -r '.cwd // ""' <<<"$INPUT")

CODES="$HOME/.claude/repo-codes"
STATE_DIR="$HOME/.claude/session-titles"
STATE="$STATE_DIR/$SESSION"

# No session id → nothing to key state off of, so stay out of the way.
[ -n "$SESSION" ] || exit 0

# Emit a hookSpecificOutput carrying additionalContext for the current event.
inject() {
  jq -n --arg event "$EVENT" --arg ctx "$1" '{
    hookSpecificOutput: {
      hookEventName: $event,
      additionalContext: $ctx
    }
  }'
}

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

# Preferred code for $1 from the map, else the guess.
repo_code() {
  local repo="$1" pinned=""
  [ -n "$repo" ] || return 0
  if [ -f "$CODES" ]; then
    pinned=$(awk -v r="$repo" \
      '!/^[[:space:]]*#/ && NF >= 2 && $1 == r { print $2; exit }' "$CODES")
  fi
  if [ -n "$pinned" ]; then
    printf '%s' "$pinned"
  else
    guess_code "$repo"
  fi
}

case "$EVENT" in

  # First prompt of a session: ask for a title built from the objective. The
  # state file doubles as the once-only gate — it appears when the model calls
  # set_session_title, so a session that never got named asks again next prompt
  # instead of silently keeping the app's auto-generated title.
  UserPromptSubmit)
    [ -f "$STATE" ] && exit 0
    CODE=$(repo_code "$(repo_name "$CWD")")
    if [ -n "$CODE" ]; then
      SHAPE="<Objective> - $CODE"
    else
      SHAPE="<Objective>"
    fi
    inject "This session still has an auto-generated title. Summarize the \
user's request as an objective of AT MOST four words in Title Case, then call \
the set_session_title tool with session_id \"self\" and a title of exactly \
\"$SHAPE\" — for example \"Rename Sessions - D\". Keep it terse: four words is \
a ceiling, not a target. Do this now, before other work, and carry on without \
remarking on it."
    ;;

  PostToolUse)
    TOOL=$(jq -r '.tool_name // ""' <<<"$INPUT")
    case "$TOOL" in

      # Record what the title was set to, so the PR step below can rebuild the
      # full string without needing it to still be in the model's context. Any
      # "#123 " prefix is stripped first — otherwise opening a second PR would
      # nest prefixes into "#124 #123 Rename Sessions - D".
      *set_session_title)
        TITLE=$(jq -r '.tool_input.title // ""' <<<"$INPUT")
        [ -n "$TITLE" ] || exit 0
        BASE=$(sed -E 's/^#[0-9]+[[:space:]]+//' <<<"$TITLE")
        mkdir -p "$STATE_DIR"
        printf '%s\n' "$BASE" >"$STATE"
        ;;

      # A PR was opened: fold its number into the title.
      Bash)
        CMD=$(jq -r '.tool_input.command // ""' <<<"$INPUT")
        grep -qE '\bgh[[:space:]]+pr[[:space:]]+create\b' <<<"$CMD" || exit 0

        # gh prints the PR URL on success. Scanning the whole response rather
        # than a named field keeps this working if the Bash result shape shifts.
        URL=$(jq -r '.tool_response | tostring' <<<"$INPUT" \
          | grep -oE 'https://github\.com/[^/]+/[^/]+/pull/[0-9]+' \
          | head -1 || true)
        [ -n "$URL" ] || exit 0
        NUM=${URL##*/}

        # Don't re-ask when this PR number is already folded in (retried command,
        # `gh pr create` run twice against the same branch).
        [ -f "$STATE.pr" ] && [ "$(cat "$STATE.pr")" = "$NUM" ] && exit 0
        mkdir -p "$STATE_DIR"
        printf '%s\n' "$NUM" >"$STATE.pr"

        if [ -s "$STATE" ]; then
          inject "PR #$NUM was just opened. Call the set_session_title tool with \
session_id \"self\" and a title of exactly \"#$NUM $(cat "$STATE")\". Carry on \
without remarking on it."
        else
          inject "PR #$NUM was just opened. Call the set_session_title tool with \
session_id \"self\", keeping this session's current title but prefixing it with \
\"#$NUM \". Carry on without remarking on it."
        fi
        ;;
    esac
    ;;
esac

exit 0
