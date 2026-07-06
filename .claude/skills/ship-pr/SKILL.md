---
name: ship-pr
description: End-to-end PR pipeline — open the PR, wait for Copilot's review, resolve every comment, wait for CI to go green, then squash-merge. Triggers when the user asks to "ship this PR", "ship-pr", "open a PR and merge it", "take this all the way to merge", or otherwise wants the open→review→resolve→merge loop run unattended.
---

# Ship a PR (open → review → resolve → CI → merge)

Orchestrates the whole path from an unopened change to a merged PR. This skill is a **conductor** — it delegates the real work to [`open-pr`](../open-pr/SKILL.md) and [`resolve-pr-comments`](../resolve-pr-comments/SKILL.md) and never re-implements their logic. Read both before running so their hard rules (never amend a pushed commit, never resolve a defer/push-back thread) carry through here.

Default behaviour is **fully unattended**: open, resolve, and squash-merge with no check-ins. Stop early only when a step *needs a human* (deferrals / push-backs / a red check that isn't auto-recoverable) or when the user explicitly said not to merge.

## 0. Read the invocation for overrides

Before starting, honor anything the user said in the same message:

- **"…but don't merge" / "just get it green" / "stop before merge"** → run every step *except* the final merge; end at green CI and hand back.
- **A named merge method** ("rebase merge", "merge commit") → use it instead of the squash default.
- **"PR is already open" / a PR number/URL** → skip step 1, resolve the PR they named, and go straight to step 2.

## 1. Open the PR

Invoke the **`open-pr`** skill. It picks the title, fills the body from the repo template, assigns `@me`, and adds labels. Do not duplicate its steps here.

- After it runs, capture the PR number and `<owner>/<repo>`:

  ```bash
  gh pr view --json number,url,headRepository,headRepositoryOwner
  ```
- **Label gate for E2E.** If the diff touches rendered markup (`ui_tests/playwright/`, `frontend/src/components/`, `frontend/src/pages/`, or anything that changes SSR/WASM output), make sure the PR carries the `run_ui_tests` label — without it the Playwright check is gated out and "green CI" would be a false pass. Add it if `open-pr` didn't:

  ```bash
  gh pr edit <pr> --add-label run_ui_tests
  ```
- **Never request Copilot as a reviewer.** It's auto-attached by repo settings on this repo. No `--reviewer Copilot`, no `requested_reviewers` POST.

## 2. Wait for Copilot's review

Copilot is auto-added and posts its review a minute or two after open (and again after each new push). Poll for a **completed review whose commit matches the current PR head** — an older review from a previous push doesn't count.

```bash
# Current head SHA
gh pr view <pr> --json headRefOid --jq .headRefOid

# Reviews, newest last — look for a Copilot review at the head SHA
gh api "repos/<owner>/<repo>/pulls/<pr>/reviews" --paginate \
  --jq '.[] | select(.user.login | test("[Cc]opilot")) | {state, sha: .commit_id, submitted_at}'
```

Poll roughly every 30–60s. Consider the review "landed" once a Copilot review exists whose `commit_id` equals the current head SHA. If after ~5 minutes there's still no Copilot review (it doesn't always comment on trivial diffs), treat the review as **clean** and move on — don't block forever.

Also read any inline comments it left (the review can be `COMMENTED`/`CHANGES_REQUESTED` with diff-anchored notes) — those are what step 3 acts on.

## 3. Resolve every comment

Invoke the **`resolve-pr-comments`** skill against the PR. It collects all three comment surfaces, triages each into fix-now / defer / push-back, applies + replies + resolves the fix-now items on a fresh stacked commit, and reports the rest.

Then branch on its outcome:

- **All comments were fix-now (zero deferrals, zero push-backs):** the fixes pushed new commits. **Loop back to step 2** — Copilot re-reviews the new head, and you resolve any fresh comments. Repeat until a review round produces no new fix-now items.
- **Any deferrals or push-backs exist:** these are the user's calls by definition (see `resolve-pr-comments` §3b/§3c). **Stop the pipeline and hand back** the skill's summary. Do **not** merge — even in auto-merge mode — because unresolved reviewer feedback is outstanding. The user decides; they may then tell you to merge anyway, defer them to a follow-up, or send a reply.

Convergence guard: if the fix→re-review loop runs more than ~3 rounds without settling, stop and surface what's still churning rather than looping indefinitely.

## 4. Wait for CI to go green

Once comments are settled and the branch is stable, wait on the checks:

```bash
gh pr checks <pr> --watch --fail-fast
```

- `--watch` blocks until every required check finishes; exit code `0` means all passed.
- **A `SKIPPED` Playwright check is not a pass** if the diff touches UI — it means the `run_ui_tests` label is missing (step 1). Add the label, which re-triggers the workflow, then re-watch.
- **On a red check:** read the failing job's log (`gh run view <run-id> --log-failed`). If it's a genuine failure in this branch's code (fmt, clippy, a broken test), that's real work — **fix it** on a fresh stacked commit exactly like a fix-now review comment (`jj new <bookmark>` first — never amend the pushed tip), push, and loop back to step 2 so the new commit gets reviewed and re-checked. If it's plainly a flake or infra blip, re-run (`gh run rerun <run-id> --failed`) once; if it fails again the same way, stop and surface it — don't merge over red.

## 5. Merge

When CI is green **and** step 3 left no deferrals/push-backs **and** the user didn't say "don't merge":

```bash
gh pr merge <pr> --squash --delete-branch
```

Squash is the default (one commit per PR, matching the conventional-commit-title convention). Use `--merge` or `--rebase` only if the user asked for it in step 0. `--delete-branch` cleans up the remote head branch after merge.

After merging, sync local state so the next change starts from the merged tip:

```bash
jj git fetch    # jj repos — then `jj new <trunk-bookmark>` for the next change
git fetch && git checkout main && git pull   # git repos
```

## 6. Final report

Print a compact end-state summary: PR URL, merge status (merged / stopped-before-merge / handed-back), how many review rounds ran, comment tallies (fixed / deferred / pushed-back), and the final CI verdict. If the pipeline stopped early, state exactly what's blocking and what you need from the user to continue.

## Hard rules

- **Never amend or force-push a pushed commit.** Every fix — review-driven or CI-driven — stacks a fresh commit (`jj new <bookmark>` *before* editing). A `jj git push` that says `Move sideways bookmark` means this rule was broken; back out and redo. (Same invariant as `resolve-pr-comments` §0.)
- **Never merge with an open deferral or push-back.** Those are the user's decisions; auto-merge is suspended until they're cleared.
- **Never merge over a red or falsely-skipped required check.** A `SKIPPED` E2E check on a UI diff is a missing label, not a pass.
- **Never request Copilot as a reviewer** — it's auto-attached.
- **Never invent a review or CI state.** Poll the real API; if a signal never arrives within the timeout, say so and act on the documented fallback, don't assume.
