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
# The code is resolved by ~/.claude/hooks/repo-code.sh, which the opencode
# session-title plugin also calls so both agents label a session identically.
# Only a cwd that isn't a git repo at all ends up with no suffix.
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
SOURCE=$(jq -r '.hook_source // ""' <<<"$INPUT")

# opencode can't call set_session_title, and its own plugin titles sessions.
if [ "$SOURCE" = "opencode-plugin" ]; then
  exit 0
fi

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

# Project code for the repo containing $1, shared with opencode via repo-code.sh.
repo_code() {
  "$HOME/.claude/hooks/repo-code.sh" "$1" 2>/dev/null || true
}

case "$EVENT" in

  # Ask every prompt until set_session_title writes the state file.
  UserPromptSubmit)
    [ -f "$STATE" ] && exit 0
    CODE=$(repo_code "$CWD")
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

      # Save the title minus any "#123 " prefix so the PR step can rebuild it.
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

        # Scan the whole response so a change in the result's shape can't hide the URL.
        URL=$(jq -r '.tool_response | tostring' <<<"$INPUT" \
          | grep -oE 'https://github\.com/[^/]+/[^/]+/pull/[0-9]+' \
          | head -1 || true)
        [ -n "$URL" ] || exit 0
        NUM=${URL##*/}

        # Already folded in, e.g. by a retried `gh pr create`.
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
