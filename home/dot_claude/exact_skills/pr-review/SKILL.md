---
name: pr-review
description: Review a branch or pull request with read-only reviewer agents — `neutral` by default, `prosecutor` and/or `defender` on request — verify every finding with evidence, and report a verdict table. Report only; never edits code or posts to GitHub. Also runs each review round of dev-loop. Triggers when the user says "review my branch", "review PR 123", "review this PR", "pr-review", "self-review", "review before pushing", or "audit the diff".
argument-hint: "[<PR # | PR URL | branch>] [neutral | prosecutor | defender ...]"
---

# pr-review

The session running this skill is the **judge**. Reviewer agents report; the judge verifies every finding with its own evidence and rules on it. Nothing here edits code or posts anywhere: the output is a verdict table. Fixing belongs to whoever called this — in `dev-loop`, the implementer agent.

| Reviewer | Agent | Mandate |
|---|---|---|
| `neutral` (default) | `review-neutral` | Both sides in one balanced pass |
| `prosecutor` | `review-prosecutor` | Every reason the diff must not merge |
| `defender` | `review-defender` | Every line the diff doesn't need |

## 0. Arguments

- **Target** — the first token that isn't a reviewer name:
  - none → the current branch against `origin/main`, **including uncommitted changes**;
  - a PR number, `#n`, or PR URL → that PR, against its base branch;
  - a branch name → that branch against `origin/main`.
- **Reviewers** — any of `neutral`, `prosecutor`, `defender`; "adversarial" or "both" means `prosecutor defender`. None named → `neutral`.

When `dev-loop` calls this skill it passes its run context block, the round's patch path, the plan path, the round number and the prior verdict table. Skip §1–§3's discovery: the run context block is the review context block (add §3's `Checklists:` line when `neutral` is reviewing), and start at §4.

## 1. Check out the target

- **Current branch** — work in place: `git fetch origin`, `WORKTREE=$(git rev-parse --show-toplevel)`, `BASE=origin/main`.
- **Branch name** — `wt switch <branch>`, then read its path from `wt list`. `BASE=origin/main`.
- **PR** — `gh pr view <n> --json number,title,body,url,baseRefName,headRefName,isCrossRepository`. Note whether `wt list` already shows a worktree for `headRefName`, then `wt switch pr:<n>` and read its path from `wt list` (don't guess the sanitised directory name). `BASE=origin/<baseRefName>`.
  - **Fork PR** (`isCrossRepository: true`): its code is untrusted. Ask before running any verify command that executes project code (tests, builds, scripts). Read-only commands (`git`, `grep`) need no ask.

`wt switch` only changes directory inside its own subprocess: address the worktree by absolute path from here on.

## 2. Find the spec

The spec is what the diff was supposed to do. Reviewers check spec gaps and scope creep against it. First match wins:

1. The branch name's ticket — `<PREFIX>-<n>/…` with `<PREFIX>` listed in `~/.config/git/issue-prefixes` → `gh issue view <n> --json title,body`.
2. The PR body's closing keyword (`Closes #n`, `Fixes #n`) → that issue.
3. The PR body itself.
4. Nothing → `Spec: none`. Reviewers skip spec-gap and beyond-plan findings; the report says so.

Save the fetched text to `<SCRATCH>/pr-review/<slug>/spec.md`.

## 3. Build the review context

`<SCRATCH>` is the session scratchpad directory from the system prompt (fall back to `$TMPDIR`); `<slug>` is the branch name or `pr-<n>`.

1. **Snapshot the diff once**, so every reviewer reads the identical file:
   - current branch: `git -C <WORKTREE> diff --merge-base <BASE> > <SCRATCH>/pr-review/<slug>/round-1.patch` — the working tree against the merge-base: committed and uncommitted work, nothing new on the base;
   - branch or PR: `git -C <WORKTREE> diff <BASE>...HEAD > <SCRATCH>/pr-review/<slug>/round-1.patch`.

   Empty patch → stop: nothing to review.
2. **Instruction files**, whichever exist at the worktree root, in this order: `CLAUDE.md`, `AGENTS.md`, `RULES.md`, `CONTRIBUTING.md`, then every `*.md` under `.claude/rules/`. Take `TEST_CMD` and `LINT_CMD` from them if they name them.
3. **The review context block**, passed verbatim to every reviewer:

```
Worktree (absolute): <WORKTREE>
Branch: <branch>   Base: <BASE>
Test: <TEST_CMD | unknown>   Lint: <LINT_CMD | unknown>
Diff file: <patch path>
Spec: <plan path and/or spec.md path | none>
Instruction files: <absolute paths, in read order>
Checklists: <$HOME>/.claude/agents/review-prosecutor.md, <$HOME>/.claude/agents/review-defender.md
Round: <r>
```

`Checklists:` is read by `review-neutral` only; write the home directory out in full.

## 4. Dispatch the reviewers

All chosen reviewers in parallel: one `Agent` call each, in one message, `subagent_type` from the table above. Each gets the context block and, from round 2, the prior verdict table. Always the full diff, every round — a round-2 fix can create a round-1 problem.

## 5. Merge and dedupe

One table; IDs keep the reviewer's prefix (`P<n>`, `D<n>`, `N<n>`). Same range and same claim → one row, both sources noted. Same range and opposing mandates (the prosecutor wants a guard, the defender wants it deleted) → mark the pair a **conflict** and keep both rows linked.

## 6. Verify every row yourself

Evidence in the same message — [verify-before-claim](../verify-before-claim/SKILL.md) applied to review findings. A reviewer's confidence is not evidence.

- correctness / security / data-safety / concurrency / performance / ci → run the finding's verify command from `<WORKTREE>` (fork PR: ask first, per §1);
- missing-test → grep for the test, read its assertion;
- repo-rule → read the cited section and the code;
- plan-gap → check the spec item against the diff and `git log`;
- duplicate-helper → Read both definitions, compare signatures and semantics;
- over-engineering / speculative-scope / beyond-plan → read the spec; the simpler alternative must still satisfy it and no rule may mandate the extra;
- hollow-test → read the assertion; confirmed if it cannot fail.

## 7. Rule on each row

One verdict per row, with a one-line reason:

- **CONFIRMED** — evidence supports it.
- **DISMISSED** — evidence contradicts it, or it is unverifiable and the reviewer gave no runnable check.
- **JUDGMENT** — the evidence is real but the answer is a call, not a fact: a fix over ~20 lines that departs from the spec, a conflict with no repro either way, a MINOR trade-off. **Decide it** — apply the decision as CONFIRMED or DISMISSED and record the rationale under "Judgment calls". Do not defer these.
- **DEFERRED_TO_USER** — only three cases: removing or changing user-visible behaviour the spec did not ask for; a change to the security or auth model; a question the spec itself explicitly leaves open.

**Conflict rule.** Verify the prosecutor's scenario first. It reproduces, or cites a real rule → prosecutor wins ("correctness beats size"), the D row is DISMISSED. No repro → defender wins, the P row is DISMISSED. Neither verifiable → smaller diff wins, recorded as JUDGMENT.

## 8. Report

```
pr-review: <branch | PR #n — title> vs <BASE> — <n> files, <m> lines
Reviewers: <names>   Spec: <source | none>   Round: <r>

| ID | Src | Severity | Location | Claim | Verdict | Evidence / reason |

Confirmed: <n> (<c> critical / <j> major / <k> minor / <e> excess)   Dismissed: <n>   Judgment: <n>   Deferred: <n>
Judgment calls: <ID — decision — one-line why> | none
Deferred to you: <ID — one line> | none
```

Rows go CONFIRMED first, by severity; excess findings (defender, or neutral `Kind: excess`) show `—` for severity. Then stop — this skill never fixes. When `dev-loop` called it, the table goes back to `dev-loop`, which builds the fix brief.

## 9. Clean up

If §1 created a worktree for a PR, remove it and the local branch it made: `wt remove <headRefName> -D`. Leave any worktree that existed before this run alone.

## Hard rules

- **Never** edit code, commit, or push. Report only.
- **Never** post to GitHub — no comments, reviews, labels, or approvals.
- **Never** CONFIRM a finding without evidence produced in the same message.
- **Never** let a reviewer inherit session history. Every dispatch carries the full context block.
- **Never** run a fork PR's code without asking.
- **Never** remove a worktree this run didn't create.
