---
name: ship-pr
description: End-to-end PR pipeline — open the PR, wait for Copilot's review, resolve every comment, turn on auto-merge, fix each CI failure as it lands, then clean up after the merge. Triggers when the user asks to "ship this PR", "ship-pr", "open a PR and merge it", "take this all the way to merge", or otherwise wants the open→review→resolve→merge loop run unattended.
---

# Ship a PR (open → review → resolve → CI → merge)

Orchestrates the whole path from an unopened change to a merged PR. This skill is a **conductor** — it delegates the real work to [`open-pr`](../open-pr/SKILL.md) and [`resolve-pr-comments`](../resolve-pr-comments/SKILL.md) and never re-implements their logic. Read both before running so their hard rules (never amend a pushed commit, never reply to a person's defer/push-back without the user's OK) carry through here.

Default behaviour is **fully unattended**: open, resolve, and squash-merge with no check-ins. Stop early only when a step *needs a human* (a deferral or push-back on a person's comment / a red check that isn't auto-recoverable) or when the user explicitly said not to merge.

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
- **Issue-closing keyword.** `open-pr` is responsible for putting a `Closes #<n>` (or `Fixes #<n>`) line in the body when the PR fully resolves a tracked issue — see its "Closing keyword" section. When ship-pr was invoked *for an issue* ("ship #1186", a pasted issue URL), confirm that line made it into the body before moving on; if it's missing, add it with `gh pr edit <pr> --body-file`, running `open-pr`'s saved-copy check (§8) first. Use `Part of #<n>` (no keyword) when the PR is only one sub-task of a larger issue, so the merge doesn't wrongly close the parent. This is what makes the merge auto-close the issue.

## 2. Wait for Copilot's review

Some repos auto-attach Copilot as a reviewer and some don't, so first make sure it's on the PR, even when step 1 was skipped. About 30s after the PR opened (auto-attach isn't instant), check whether Copilot is already requested or has reviewed:

```bash
gh api "repos/<owner>/<repo>/pulls/<pr>/requested_reviewers" --jq '.users[].login'
gh api "repos/<owner>/<repo>/pulls/<pr>/reviews" --jq '.[].user.login'
```

If neither lists a Copilot login, request it once: `gh pr edit <pr> --add-reviewer "@copilot"`. Never request it when it's already there, since a second request starts a second review. If the request fails because the repo has no Copilot code review, skip the wait and treat the review as **clean**.

Copilot posts its review a few minutes after it's requested. **It reviews only once per PR** — it does not re-review after later pushes, so this wait applies to the *first* review only. Poll for a completed Copilot review on the PR (any commit).

```bash
# Current head SHA
gh pr view <pr> --json headRefOid --jq .headRefOid

# Reviews, newest last — look for a Copilot review at the head SHA
gh api "repos/<owner>/<repo>/pulls/<pr>/reviews" --paginate \
  --jq '.[] | select(.user.login | test("[Cc]opilot")) | {state, sha: .commit_id, submitted_at}'
```

Poll roughly every 30–60s. Consider the review "landed" once any Copilot review exists on the PR. If after ~10 minutes there's still no Copilot review (large diffs take longer), treat the review as **clean** and move on — don't block forever — and say so in the final report.

Also read any inline comments it left (the review can be `COMMENTED`/`CHANGES_REQUESTED` with diff-anchored notes) — those are what step 3 acts on.

## 3. Resolve every comment

Invoke the **`resolve-pr-comments`** skill against the PR. It collects all three comment surfaces, triages each into fix-now / defer / push-back, fixes the fix-now items on a fresh stacked commit (replying with the SHA and resolving), dismisses deferrals and push-backs on bot comments, and reports the rest.

Then branch on its outcome:

- **Nothing awaits the user** (every comment fixed, or dismissed because it came from a bot): proceed straight to step 4 — **Copilot reviews only once per PR and will not re-review the fix commits**, so there is no re-review loop to wait on.
- **A deferral or push-back on a person's comment awaits the user** (see `resolve-pr-comments` §3b): **stop the pipeline and hand back** the skill's summary. Do **not** merge — even in auto-merge mode — because a person's feedback is outstanding. The user approves the replies, moves items to fix-now, or tells you to merge anyway.

Convergence guard: comment resolution is a single round (Copilot won't re-review), but if CI-driven fixes keep churning past ~3 rounds, stop and surface what's still failing rather than looping indefinitely.

## 4. Arm auto-merge, then fix CI as each check fails

Once comments are settled, and unless the user said "don't merge", hand the merge to GitHub. On a UI diff, first confirm the PR carries `run_ui_tests` (step 1): GitHub counts a skipped required check as passed, so arming without it can merge over an E2E run that never happened.

```bash
gh pr checks <pr> --required          # must list at least one check
gh pr merge <pr> --auto --squash --delete-branch
```

Auto-merge waits only on **required** checks. On a base with none, GitHub has nothing to wait for, so `--auto` either errors or merges at once, over pending or red CI. So arm it only when `--required` lists a check. If none are required, or the repo doesn't allow auto-merge, don't arm it (and don't change the repo's settings). Run this step's loop until every check passes, then merge it yourself with the same command minus `--auto`. Use `--merge` or `--rebase` instead of `--squash` only if the user asked in step 0.

Then poll every 30–60s, and act on each failure as soon as it lands rather than waiting for the other lanes:

```bash
gh pr view <pr> --json state,headRefOid,mergeStateStatus --jq '{state, headRefOid, mergeStateStatus}'
gh pr checks <pr> --json name,bucket,link --jq '.[] | {name, bucket, link}'
```

Read every bucket, not just the failures: CI is green only when no check is `pending`, `fail` or `cancel`, and each `skipping` check really had nothing to run.

- **A new `fail` (or `cancel`):** for an Actions check, the job ID ends its `link` (`…/job/<id>`). Read that job's log right away, even while other jobs are still running: `gh api "repos/<owner>/<repo>/actions/jobs/<id>/logs" | tail -200`. `gh run view --log-failed` waits for the whole run, so don't use it here. For a check from an external app, open its `link`.
- **A genuine failure in this branch's code** (fmt, clippy, a broken test): fix it as a fresh commit on top, exactly like a fix-now review comment (never `--amend` the pushed tip), and push. Auto-merge stays armed, the push restarts CI on the new head, and you keep polling. There's no re-review wait, since Copilot only reviews once.
- **Plainly a flake or infra blip:** GitHub reruns a job only once its run has finished, so wait for that run, then `gh run rerun <run-id> --failed` once. If it fails again the same way, run `gh pr merge <pr> --disable-auto`, then stop and surface it. Don't let it merge over red.
- **A check that isn't required:** the repo chose not to block merges on it, so auto-merge won't wait, even while it's pending. Fix it if this branch broke it, but don't hold the merge for it.
- **A `SKIPPED` Playwright check is not a pass** if the diff touches UI. It means the `run_ui_tests` label is missing (step 1). Run `gh pr merge <pr> --disable-auto`, add the label, which re-triggers the workflow, and re-arm once Playwright passes.

The loop ends when `state` is `MERGED`. In "don't merge" mode nothing is armed, so it ends when CI is green; hand back there and skip step 5. If every check is green and the PR still hasn't merged a few minutes later, `mergeStateStatus` says why, most often a required approval. Stop and report it rather than waiting forever.

## 5. After the merge

After merging, sync local state so the next change starts from the merged tip:

```bash
wt remove                    # drop the merged worktree and its local branch
wt switch ^ && git pull      # default-branch worktree, updated
```

**Stacked PRs.** Merge bottom-up. When another open PR uses this PR's branch as its base, deleting that branch closes the dependent PR instead of retargeting it, so for every PR but the top of the stack:

1. Arm it without deleting: `gh pr merge <pr> --auto --squash`, and wait for it to merge.
2. Retarget the next PR: `gh pr edit <next> --base main`.
3. Only then delete the merged branch: `gh api -X DELETE "repos/<owner>/<repo>/git/refs/heads/<branch>"`.
4. Merge `main` into the next branch (a merge, never a rebase) and push, so its diff shows only its own changes. The squash leaves that branch holding older copies of lines `main` now has; resolve those conflicts toward the branch.

**A stack into a feature branch** (the bottom PR targets a feature branch, not `main`): first resolve every stack PR's review threads with `resolve-pr-comments`, since threads left on a squashed PR are orphaned. Then merge top-down, each PR squashed into its own direct base (`gh pr merge <top> --squash`, then the next one down; a feature branch rarely has required checks, so these merge by hand once green), so nothing is retargeted and nothing conflicts. Only the feature branch's PR into `main` closes issues (see `open-pr`).

**Confirm the issue closed.** If this PR was meant to resolve a tracked issue, verify the merge auto-closed it (the `Closes #<n>` line from step 1 does this):

```bash
gh issue view <n> --json state --jq .state   # want: CLOSED
```

If it's still `OPEN` and the PR *fully* resolved it (the body was missing the keyword, or a bare `#<n>` was used), close it manually with a comment pointing at the merged PR:

```bash
gh issue close <n> --comment "Shipped in #<pr>."
```

Leave it open only when the PR was a partial (`Part of #<n>`) — say so in the report.

**Move the ticket to Done.** When the PR resolved a ticket (the `Closes #<n>` issue, or the Jira or Linear key the branch is named for) and wasn't a partial, set it to Done by [`../dev-loop/tickets.md`](../dev-loop/tickets.md). A failure there is reported, never a reason to stop.

## 6. Final report

Print a compact end-state summary: PR URL, merge status (merged / stopped-before-merge / handed-back), how many review rounds ran, comment tallies (fixed / deferred / pushed-back), and the final CI verdict. If the pipeline stopped early, state exactly what's blocking and what you need from the user to continue.

## Hard rules

- **Never amend or force-push a pushed commit.** Every fix — review-driven or CI-driven — lands as a fresh commit on top. A `git push` rejected as non-fast-forward means this rule was broken; recover with `git reset --soft origin/<branch>` and redo. (Same invariant as `resolve-pr-comments` §0.)
- **Never merge, or arm auto-merge, with a deferral or push-back on a person's comment awaiting the user.** Those are the user's decisions; auto-merge stays off until they're cleared. Bot comments dismissed by `resolve-pr-comments` don't block.
- **Never merge over a red or falsely-skipped required check.** A `SKIPPED` E2E check on a UI diff is a missing label, not a pass. Auto-merge guards only the required checks, so never arm it on a base with none.
- **Never request Copilot twice.** Request it only when it's neither requested nor has reviewed (step 2); a second request starts a second review.
- **Never delete a merged branch another open PR still uses as its base.** Retarget that PR first, or GitHub closes it.
- **Never invent a review or CI state.** Poll the real API; if a signal never arrives within the timeout, say so and act on the documented fallback, don't assume.
