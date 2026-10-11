#!/bin/sh
# Reproduces every planted defect in the commit-hook-guards fixture, so the
# answer key is evidence rather than intent. Usage:
#
#   sh verify-seeds.sh <fixture worktree>
#
# Every line should print REPRODUCED. Run it against the base commit instead and
# the behavioural seeds (A1-A6, A8) should print not-reproduced.

set -u

FIX=$(cd "$1" && pwd)
H="$FIX/home/dot_config/private_git/exact_hooks"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

seed() {
    if eval "$2"; then echo "REPRODUCED      $1"; else echo "not-reproduced  $1"; fi
}
msg() { printf '%s\n' "$@" >"$T/msg"; }
g() { git -c core.hooksPath=/dev/null "$@"; }

mkdir -p "$T/cfg/git"
printf 'dotfiles DOT\nomnibus OMNI\n' >"$T/cfg/git/issue-prefixes"
export XDG_CONFIG_HOME="$T/cfg"
unset GIT_TICKET_SKIP GIT_MAX_SUBJECT 2>/dev/null || true

g init -q "$T/repo"
cd "$T/repo" || exit 1
g commit -q --allow-empty -m "chore: root"
g remote add origin git@github.com:someone/dotfiles.git

# A1: a subject of exactly 72 characters is rejected.
msg "feat: $(printf '%*s' 66 '' | tr ' ' x)"
seed "A1 72-char subject rejected" '! sh "$H/executable_commit-msg" "$T/msg" 2>/dev/null'

# A3: a 66-character subject with four em dashes counts as 74 bytes.
msg "feat: $(printf '%*s' 52 '' | tr ' ' x) — — — —"
seed "A3 66-char subject with em dashes rejected" '! sh "$H/executable_commit-msg" "$T/msg" 2>/dev/null'

# A2: a slashless ticket-ish branch yields a garbage trailer.
g checkout -q -b DOT-5-fix-thing
msg "feat: x"
sh "$H/executable_prepare-commit-msg" "$T/msg" message 2>/dev/null
seed "A2 branch DOT-5-fix-thing gets 'Refs: #5-fix-thing'" 'grep -q "^Refs: #5-fix-thing" "$T/msg"'

# A4: with GIT_TICKET_SKIP unset, every commit prints a test(1) error.
g checkout -q -b u/sloan/plain
msg "feat: x"
err=$(sh "$H/executable_prepare-commit-msg" "$T/msg" message 2>&1 >/dev/null)
seed "A4 stderr on every commit: $err" '[ -n "$err" ]'

# A5: an editor commit on a Jira branch never gets its trailer, because the
# template's "# On branch ABC-123/..." comment already contains the key.
g checkout -q -b ABC-123/thing
msg "feat: x" "# On branch ABC-123/thing"
sh "$H/executable_prepare-commit-msg" "$T/msg" 2>/dev/null
seed "A5 Jira trailer skipped under editor template" '! grep -q "^Refs: ABC-123" "$T/msg"'

# A6: mid-rebase the fallback strips "refs/heads" but not the slash after it.
g checkout -q -b DOT-7/thing
g commit -q --allow-empty -m "feat: a"
GIT_SEQUENCE_EDITOR="sed -i.bak s/^pick/edit/" g rebase -q -i HEAD~1 >/dev/null 2>&1
out=$(. "$H/lib-ticket.sh" && branch_ticket)
seed "A6 rebase fallback returns '$out' (want DOT-7)" '[ "$out" != "DOT-7" ]'
g rebase --abort

# A7: the rebase-apply backend is never consulted.
seed "A7 rebase-apply/head-name not read" '! grep -q rebase-apply "$H/lib-ticket.sh"'

# A8: pre-commit still calls repo_prefix, now undefined, so a foreign-prefix
# branch passes the check it should fail.
g checkout -q -b OMNI-12/thing
out=$(sh "$H/executable_pre-commit" 2>&1)
rc=$?
seed "A8 OMNI branch in dotfiles accepted (rc=$rc)" '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q "repo_prefix"'

# A9: the rebase test passes while A6 is broken — it asserts on $? after `|| true`.
seed "A9 tests/git-hooks.sh green despite A6" '(cd "$FIX" && sh tests/git-hooks.sh >/dev/null 2>&1)'

# A10: the spec's GIT_TICKET_SKIP never reached pre-commit.
seed "A10 pre-commit ignores GIT_TICKET_SKIP" '! grep -q GIT_TICKET_SKIP "$H/executable_pre-commit"'

# A11: an unrequested GIT_MAX_SUBJECT knob.
seed "A11 GIT_MAX_SUBJECT knob present" 'grep -q GIT_MAX_SUBJECT "$H/executable_commit-msg"'
