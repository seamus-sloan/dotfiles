---
name: test-failure-triage
description: When tests fail before push, classify each failure as pre-existing (also fails on main) or in-branch (introduced by this branch). Pre-existing don't block; in-branch do. Triggers when tests fail and the user asks "are these new failures", "triage these test failures", "what broke", or before pushing a branch.
---

# Test failure triage

Don't push a branch with mystery test failures. Classify each one first.

## 1. Run tests on the branch

Run the project's test command (check `CLAUDE.md` for the canonical recipe — e.g. `cargo test`, `bun test`, `npx playwright test`). Capture the failing test names.

## 2. Classify each failure

Two buckets:

| Bucket | How to tell | What to do |
|---|---|---|
| **Pre-existing** | Same test also fails on the base branch | Don't block. Report it to the user. |
| **In-branch** | Passes on base, fails on this branch | Block. Investigate before pushing. |

To check, run the same test against the base branch. Under worktrunk the base branch already has its own worktree, so there is nothing to stash — switch, run, switch back:

```bash
wt switch ^                                              # ^ = the default-branch worktree
<run failing test command>                               # capture pass/fail
wt switch -                                              # - = back to the previous worktree
```

If you're in a plain checkout rather than a worktree:

```bash
git stash
git checkout main && <run failing test>
git checkout - && git stash pop
```

If the same test fails on `main` → pre-existing. If it passes on `main` → in-branch, you broke it.

## 3a. In-branch failure flow

Block the push. Drive a fix via the `investigate` skill — root cause first, then a regression test.

Once fixed:
- Re-run the full suite on the branch.
- Commit the fix as part of the same branch (or a follow-up change before push).

## 3b. Pre-existing failure flow

Don't fix opportunistically — that's scope creep. Instead:

1. **Report it to the user** — each test name plus a one-line note ("fails on main, tracked in #123 / not yet tracked"). It never goes into the PR description.
2. **Offer a ticket** when the failure isn't already tracked, via [write-ticket](../write-ticket/SKILL.md).

## 4. Regression-test mandate

Every in-branch fix lands with a test that:

- Fails without the fix.
- Passes with the fix.
- Lives in the same crate/package/spec dir as the code it covers.

Verify both halves: revert the fix locally, re-run the test, confirm it fails. Then re-apply.

No regression test → not done.

## Final triage report

```
Test failure triage: N failures (P pre-existing, B in-branch)

In-branch (BLOCKING):
  - <test name> (<file>): <one-line cause if known>

Pre-existing (reported, not blocking):
  - <test name> (<file>): also fails on main [<ticket-ref or "untracked">]
```

## Hard rules

- **Never** push with in-branch failures. Pre-existing only.
- **Never** silently fix a pre-existing failure as part of an unrelated branch — file it separately or call it out explicitly.
- **Never** declare a fix complete without the regression test.
- **Never** skip the comparison run on the base branch — "I think this was already broken" is not triage, it's a guess.
