#!/bin/bash
# careful.sh — PreToolUse hook for the Bash tool.
# Returns permissionDecision "ask" when a Bash command matches a destructive
# pattern AND is not on the safe list. Otherwise stays silent (allow).
#
# Patterns and rationale documented in ~/.claude/skills/careful/SKILL.md.

set -euo pipefail

COMMAND=$(jq -r '.tool_input.command // ""' < /dev/stdin)

# Empty command → nothing to check.
[ -z "$COMMAND" ] && exit 0

# SAFE list — known-OK destructive-looking patterns. Skip confirmation.
SAFE='rm -rf (node_modules|dist|\.next|build|\.cache|coverage|\.turbo|__pycache__|target/(debug|release)|\.parcel-cache|\.nuxt|\.svelte-kit)(/|$| )'

if echo "$COMMAND" | grep -qE "$SAFE"; then
  exit 0
fi

# DESTRUCTIVE patterns that need confirmation.
DESTRUCTIVE='(\brm -rf?\b|\brm --recursive\b|DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)\b|TRUNCATE[[:space:]]+TABLE\b|git[[:space:]]+push[[:space:]]+(-f\b|--force\b)|git[[:space:]]+reset[[:space:]]+--hard\b|git[[:space:]]+(checkout|restore)[[:space:]]+\.|kubectl[[:space:]]+delete\b|docker[[:space:]]+(rm[[:space:]]+-f\b|system[[:space:]]+prune\b)|jj[[:space:]]+(abandon\b|op[[:space:]]+restore\b))'

if echo "$COMMAND" | grep -qiE "$DESTRUCTIVE"; then
  REASON=$(echo "$COMMAND" | grep -oiE "$DESTRUCTIVE" | head -1)
  jq -n --arg reason "Destructive pattern matched: $REASON" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $reason
    }
  }'
fi

exit 0
