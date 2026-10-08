#!/bin/bash
# Grades one run against its fixture's answer key with a fresh headless
# session, then prints the scoreboard row.
#
#   grade.sh <run dir>
#
# Writes <run dir>/grade.json. The grader reads the fixture's code to rule on
# findings that match no seed.

set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
RUN=$(cd "${1:?run dir}" && pwd)
FIXTURE=$(basename "$(dirname "$RUN")")
FDIR="$HERE/fixtures/$FIXTURE"
# shellcheck source=/dev/null
. "$FDIR/fixture.env"
WT=$(wt list --format=json | jq -r --arg b "$BRANCH" '.items[] | select(.branch == $b) | .worktree.path // empty')
[ -n "$WT" ] || { echo "no fixture worktree for $BRANCH; run run.sh first" >&2; exit 1; }

G=$(mktemp -d "${TMPDIR:-/tmp}/grade.XXXXXX")
cp "$FDIR/answers.md" "$RUN/report.md" "$RUN/findings.json" "$G/"
PROMPT=$(sed "s|{{GRADE_DIR}}|$G|g" "$HERE/grade.md")

(cd "$WT" && claude -p --model opus --permission-mode auto --strict-mcp-config --output-format json "$PROMPT") \
  | jq -r '.result' | sed -e 's/^```json//' -e 's/^```//' >"$RUN/grade.json"
rm -rf "$G"
jq -e . "$RUN/grade.json" >/dev/null || { echo "grader didn't return JSON: $RUN/grade.json" >&2; exit 1; }
node "$HERE/scoreboard.mjs" "$RUN"
