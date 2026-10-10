---
name: pr-review
description: Review a branch or pull request with a panel of read-only finder agents (one per review angle), verify every candidate with its own verifier agent, sweep for gaps, then rule on each with evidence and report a verdict table. Report only; never edits code or posts to GitHub. Also runs each review round of dev-loop. Triggers when the user says "review my branch", "review PR 123", "review this PR", "pr-review", "self-review", "review before pushing", or "audit the diff".
argument-hint: "[<PR # | PR URL | branch>]"
---

# pr-review

The session running this skill is the **judge**. Finders report candidates, verifiers test each one, and the judge rules on every row from their evidence. Nothing here edits code or posts anywhere: the output is a verdict table. Fixing belongs to whoever called this; in `dev-loop` that's the implementer agent.

| Stage | Agent | Count |
|---|---|---|
| Find | `review-finder` | one per angle in [angles.md](angles.md), in parallel |
| Verify | `review-verifier` | one per candidate, in parallel |
| Sweep | `review-finder` with the `sweep` angle | one, after verification |

There are no levels and no caps: every review runs every angle, verifies every candidate, and reports every surviving finding.

## 0. Arguments

The target, if any:

- none → the current branch against `origin/main`, **including uncommitted changes**;
- a PR number, `#n`, or PR URL → that PR, against its base branch;
- a branch name → that branch against `origin/main`.

When `dev-loop` calls this skill it passes its run context block, the round's patch path, the plan path, the round number and the prior verdict table. Skip §1–§2. In §3 the diff file, spec and instruction files come from what it passed; still snapshot the base files (§3.2) and add the `Base files:`, `Untrusted: no` and `Round:` lines, then continue at §4.

## 1. Check out the target

- **Current branch**: work in place. `git fetch origin`, `WORKTREE=$(git rev-parse --show-toplevel)`, `BASE=origin/main`.
- **Branch name**: `wt switch <branch>`, then read its path from `wt list`. `BASE=origin/main`.
- **PR**: `gh pr view <n> --json number,title,body,url,baseRefName,headRefName,isCrossRepository`. Note whether `wt list` already shows a worktree for `headRefName`, then run `wt switch pr:<n>` and read its path from `wt list` (don't guess the sanitised directory name). `BASE=origin/<baseRefName>`.
  - **Fork PR** (`isCrossRepository: true`): its code is untrusted, so set `Untrusted: yes`. Verifiers then won't execute project code, and you ask before running any command that does. Read-only commands (`git`, `grep`) need no ask.

`wt switch` only changes directory inside its own subprocess, so address the worktree by absolute path from here on.

## 2. Find the spec

The spec is what the diff was supposed to do; finders check plan gaps and scope creep against it. First match wins:

1. The branch name's ticket: `<PREFIX>-<n>/…` with `<PREFIX>` listed in `~/.config/git/issue-prefixes` → `gh issue view <n> --json title,body`.
2. The PR body's closing keyword (`Closes #n`, `Fixes #n`) → that issue.
3. The PR body itself.
4. Nothing → `Spec: none`. Finders skip plan-gap and beyond-plan findings, and the report says so.

Save the fetched text to `<SCRATCH>/pr-review/<slug>/spec.md`.

## 3. Build the review context

`<SCRATCH>` is the session scratchpad directory from the system prompt (fall back to `$TMPDIR`); `<slug>` is the branch name or `pr-<n>`.

1. **Snapshot the diff once**, so every agent reads the identical file:
   - current branch: `git -C <WORKTREE> diff --merge-base <BASE> > <SCRATCH>/pr-review/<slug>/round-<r>.patch` (the working tree against the merge-base: committed and uncommitted work, nothing new on the base);
   - branch or PR: `git -C <WORKTREE> diff <BASE>...HEAD > <SCRATCH>/pr-review/<slug>/round-<r>.patch`.

   An empty patch → stop: there's nothing to review.
2. **Snapshot the base files.** For every file the diff modifies or deletes, write its merge-base version to `<SCRATCH>/pr-review/<slug>/base/<path>`, using `git -C <WORKTREE> show $(git -C <WORKTREE> merge-base <BASE> HEAD):<path>`. The `removed` angle reads them to name the invariants deleted lines enforced.
3. **Instruction files**, in this order, whichever exist: `~/.claude/CLAUDE.md`; at the worktree root `CLAUDE.md`, `AGENTS.md`, `RULES.md`, `CONTRIBUTING.md`, then every `*.md` under `.claude/rules/`; then any `CLAUDE.md` or `AGENTS.md` in a directory that is an ancestor of a changed file. Take `TEST_CMD` and `LINT_CMD` from them if they name them.
4. **The review context block**, passed verbatim to every agent:

```
Worktree (absolute): <WORKTREE>
Branch: <branch>   Base: <BASE>
Test: <TEST_CMD | unknown>   Lint: <LINT_CMD | unknown>
Diff file: <patch path>
Base files: <SCRATCH>/pr-review/<slug>/base/
Spec: <plan path and/or spec.md path | none>
Instruction files: <absolute paths, in read order>
Untrusted: <yes | no>
Round: <r>
```

## 4. Find

Dispatch one `review-finder` for **every** angle in [angles.md](angles.md) except `sweep`, all in one message and in the foreground (`run_in_background: false`), since the next step needs every result. Each gets the context block, its angle's name and full section pasted from `angles.md`, and, from round 2, the prior verdict table. Every finder gets the full diff every round, because a round-2 fix can create a round-1 problem.

## 5. Merge and dedupe

Put every candidate, including `Also noticed` blocks, in one table, with IDs keeping their angle prefix (`line-2`, `callers-1`).

- Same location and same mechanism → one row: keep the most concrete failure scenario and note every source.
- Same location, different mechanisms → separate rows.
- A defect and an excess finding on the same lines (one wants a guard, the other wants it deleted) → mark the pair a **conflict** and keep both rows, linked.

## 6. Verify every row

Dispatch one `review-verifier` per row, all in one message and in the foreground (in batches of about 25 if there are more). Each gets the context block and the row's candidate block verbatim; a conflict pair goes to one verifier together. **No row is dropped without a verifier's vote**, and "seems unlikely" is not a vote.

Then check the verifiers:

- **Every CONFIRMED CRITICAL or MAJOR defect**: re-run its `Repro` yourself, or re-read its quoted lines if the evidence is read-only. Evidence in the same message is [verify-before-claim](../verify-before-claim/SKILL.md) applied to review findings. If it doesn't reproduce, the row drops to PLAUSIBLE; if the output contradicts the claim, it's DISMISSED.
- **Every REFUTED row**: check that the quoted line or output really says what the verifier claims. A refutation you can't check stays PLAUSIBLE.
- Run `git -C <WORKTREE> status --porcelain`; it must be empty. A verifier that dirtied the tree has broken its contract: restore nothing yourself, and report it.

## 7. Sweep for gaps

Dispatch one `review-finder` in the foreground with the `sweep` angle, the context block, and the verified table so far. Dedupe its candidates against the table (§5), verify the new ones (§6), and add them.

## 8. Rule on each row

One verdict per row, with a one-line reason:

- **CONFIRMED**: the verifier showed the trigger and the wrong result, and §6's check held.
- **PLAUSIBLE**: the mechanism is real but the trigger couldn't be reproduced on demand. It is reported like a finding, with what would confirm it. It is never dismissed for lacking a repro.
- **DISMISSED**: a refutation you checked: factually wrong, provably impossible, already handled, or no observable effect.
- **JUDGMENT**: the evidence is real but the answer is a call, not a fact: an excess row the verifier left PLAUSIBLE, a fix over ~20 lines that departs from the spec, a MINOR trade-off. **Decide it**: apply the decision as CONFIRMED or DISMISSED and record the rationale under "Judgment calls". Don't defer these.
- **DEFERRED_TO_USER**: only three cases: removing or changing user-visible behaviour the spec didn't ask for; a change to the security or auth model; a question the spec itself explicitly leaves open.

**Conflict rule.** If the defect side is CONFIRMED or PLAUSIBLE, or cites a real rule, the defect wins ("correctness beats size") and the excess row is DISMISSED. If the defect side is REFUTED, the excess side wins.

## 9. Report

```
pr-review: <branch | PR #n — title> vs <BASE> — <n> files, <m> lines   Round: <r>
Spec: <source | none>   Panel: <k> finders + sweep, <v> verifiers   Candidates: <raw> → <after dedupe>

| ID | Src | Kind | Severity | Location | Claim | Verdict | Evidence / reason |

Confirmed: <n> (<c> critical / <j> major / <k> minor / <e> excess)   Plausible: <n>   Dismissed: <n>   Judgment: <n>   Deferred: <n>
Judgment calls: <ID — decision — one-line why> | none
Deferred to you: <ID — one line> | none
```

Rows go CONFIRMED first, then PLAUSIBLE, each by severity; excess rows show `—` for severity. Then stop, since this skill never fixes. When `dev-loop` called it, the table goes back to `dev-loop`, which builds the fix brief.

## 10. Clean up

If §1 created a worktree for a PR, remove it along with the local branch it made: `wt remove <headRefName> -D`. Leave any worktree that existed before this run alone.

## Hard rules

- **Never** edit code, commit, or push. Report only.
- **Never** post to GitHub: no comments, reviews, labels, or approvals.
- **Never** skip an angle, cap the candidates, or drop a row without a verifier's vote.
- **Never** CONFIRM a finding without evidence produced in this run, and never CONFIRM a CRITICAL or MAJOR defect without re-checking it yourself in the same message.
- **Never** DISMISS a row only because it couldn't be reproduced; that's PLAUSIBLE.
- **Never** let an agent inherit session history. Every dispatch carries the full context block.
- **Never** run a fork PR's code without asking.
- **Never** remove a worktree this run didn't create.
