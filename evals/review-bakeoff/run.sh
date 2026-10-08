#!/bin/bash
# Runs one review of one fixture in a fresh headless Claude Code session.
#
#   run.sh <fixture> code-review
#   run.sh <fixture> dev-loop [--src <dot_claude dir>]
#
# code-review  the built-in /code-review (alias /review) at max, uncapped
# dev-loop     round 1 of dev-loop's review cycle (pr-review with dev-loop's
#              default reviewers), judged by that session
# --src        review with the skills and agents in a chezmoi source tree
#              (e.g. a worktree's home/dot_claude) instead of the installed ones
#
# The fixture worktree is created from fixture.patch on first use and checked
# against it on every run. Output lands in $BAKEOFF_RUNS (default
# $TMPDIR/review-bakeoff), never inside the repo; grade it with grade.sh.

set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
FIXTURE=${1:?fixture name}
REVIEWER=${2:?code-review or dev-loop}
shift 2
SRC=""
while [ $# -gt 0 ]; do
  case "$1" in
    --src) SRC=$(cd "$2" && pwd); shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

FDIR="$HERE/fixtures/$FIXTURE"
[ -f "$FDIR/fixture.env" ] || { echo "no fixture: $FIXTURE" >&2; exit 2; }
# shellcheck source=/dev/null
. "$FDIR/fixture.env"

# --- fixture worktree -------------------------------------------------------
wt_path() { wt list --format=json | jq -r --arg b "$BRANCH" '.items[] | select(.branch == $b) | .worktree.path // empty'; }
WT=$(wt_path)
if [ -z "$WT" ]; then
  wt switch --create "$BRANCH" --base "$BASE" --no-cd --yes >/dev/null
  WT=$(wt_path)
  git -C "$WT" am -q "$FDIR/fixture.patch"
  git -C "$WT" branch -q --set-upstream-to=origin/main
fi
[ -z "$(git -C "$WT" status --porcelain)" ] || { echo "fixture worktree is dirty: $WT" >&2; exit 1; }
want=$(git patch-id --stable <"$FDIR/fixture.patch" | cut -d' ' -f1)
have=$(git -C "$WT" diff "$BASE"...HEAD | git patch-id --stable | cut -d' ' -f1)
[ "$want" = "$have" ] || { echo "fixture worktree doesn't match fixture.patch: $WT" >&2; exit 1; }

# --- run directory ----------------------------------------------------------
LABEL=$REVIEWER
[ -n "$SRC" ] && LABEL="$REVIEWER-src"
RUN="${BAKEOFF_RUNS:-${TMPDIR:-/tmp}/review-bakeoff}/$FIXTURE/$LABEL-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN"
# The reviewer only ever sees this directory and the worktree: nothing beside
# the plan, so no earlier run's report and no answer key is a glob away.
CTX=$(mktemp -d "${TMPDIR:-/tmp}/dev-loop.XXXXXX")
cp "$FDIR/spec.md" "$CTX/plan.md"
SESSION=$(uuidgen | tr 'A-Z' 'a-z')

ARGS=(-p --model opus --effort max --permission-mode auto --strict-mcp-config
  --output-format stream-json --verbose --session-id "$SESSION")

case "$REVIEWER" in
  code-review)
    [ -z "$SRC" ] || { echo "--src applies to dev-loop only" >&2; exit 2; }
    PROMPT="/code-review max --max-findings all"
    ;;
  dev-loop)
    SKILLS="Invoke the installed dev-loop and pr-review skills."
    if [ -n "$SRC" ]; then
      node "$HERE/agents-json.mjs" "$SRC/exact_private_agents" >"$RUN/agents.json"
      ARGS+=(--agents "$RUN/agents.json")
      SKILLS="Do not invoke the installed dev-loop or pr-review skills. Read and follow $SRC/exact_skills/dev-loop/SKILL.md and $SRC/exact_skills/pr-review/SKILL.md instead, and wherever they cite a file under ~/.claude/, read its counterpart under $SRC (agents live in exact_private_agents/, skills in exact_skills/). The agent definitions passed on the command line already override the installed ones."
    fi
    PROMPT="This is a review-only run of dev-loop's review cycle. Branch, plan and implementation are already done; do exactly what dev-loop §5 does for round 1 and nothing else: no fixing, no tests beyond what verification needs, no PR, no edits to the worktree. $SKILLS

1. Snapshot the diff: git -C $WT diff $BASE...HEAD > $CTX/round-1.patch
2. Run the round-1 review exactly as dev-loop §5 step 2 does, with dev-loop's default reviewers and Round: 1, passing this run context block, the patch path above, and the plan path:

Worktree (absolute): $WT
Branch: $BRANCH     Base: $BASE
Test: $TEST_CMD     Lint: unknown
Diff command: git -C $WT diff $BASE...HEAD
Plan: $CTX/plan.md
Instruction files: none at the worktree root
Issue/spec: $TITLE

3. Print the round's verdict table, every row, and stop."
    ;;
  *) echo "unknown reviewer: $REVIEWER" >&2; exit 2 ;;
esac

printf '%s\n' "$PROMPT" >"$RUN/prompt.txt"
echo "run: $RUN"
(cd "$WT" && claude "${ARGS[@]}" "$PROMPT") >"$RUN/stream.jsonl" 2>"$RUN/stderr.txt" || echo "claude exited $?" >&2
cp -R "$CTX" "$RUN/ctx" && rm -rf "$CTX"
node "$HERE/extract.mjs" "$RUN"
