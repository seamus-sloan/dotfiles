---
name: dev-loop
description: Agentic development loop — branch → plan → implement → opposing self-reviews (prosecutor vs minimalist, every finding verified by the orchestrator) → fix → test → draft PR. Triggers when the user says "/dev-loop <issue # or spec>", "dev-loop this", "run the dev loop on #123", "take this issue end to end".
argument-hint: "<issue # | issue URL | spec text> [ready] [merge] [no-pr] [rounds=N] [branch=<name>] [plan=<path>] [skip=prosecutor|minimalist]"
---

# dev-loop (branch → plan → implement → opposing reviews → fix → test → PR)

The session running this skill is the **orchestrator**. It plans, dispatches, judges, and reports. It delegates the real work to existing skills and three custom agents and never re-implements them:

| Step | Owner |
|---|---|
| Plan | [`writing-plans`](../writing-plans/SKILL.md) via a fresh subagent |
| Implement, fix | `dev-loop-implementer` agent (runs [`tdd`](../tdd/SKILL.md)) |
| Review | `dev-loop-prosecutor` + `dev-loop-minimalist` agents, in parallel |
| Judge findings | **the orchestrator itself** — there is no referee |
| Verify | [`verify-before-claim`](../verify-before-claim/SKILL.md), [`test-failure-triage`](../test-failure-triage/SKILL.md) |
| Ship | [`open-pr`](../open-pr/SKILL.md), or [`ship-pr`](../ship-pr/SKILL.md) with `merge` |

Two invariants hold for the whole run:

1. **The orchestrator never edits the worktree.** Every source change comes from the implementer. The orchestrator writes only to its scratchpad.
2. **The orchestrator is the only judge.** Reviewers report; nothing is acted on until the orchestrator has produced its own evidence for it.

Read `ship-pr` and `verify-before-claim` before running so their hard rules carry through.

## 0. Arguments

Parse `$ARGUMENTS`. The first token that is an integer, `#n`, or an issue URL names a GitHub issue; otherwise the leading text is the spec. Then honour these tokens anywhere in the arguments:

| Token | Effect |
|---|---|
| *(none)* | open a **draft** PR at §7 and stop |
| `ready` | open a non-draft PR |
| `merge` | implies `ready`; run `ship-pr` fully at §7 |
| `no-pr` | stop after §6 (green tests); push nothing |
| `rounds=N` | review-round cap (default **2**, hard max 5) |
| `branch=<name>` | the branch and worktree already exist; skip §2's create |
| `plan=<path>` | the plan is already written; skip §3 |
| `skip=prosecutor` / `skip=minimalist` | run one reviewer only; recorded in the report as a degraded run |

Natural-language forms are accepted ("and merge", "but don't open a PR", "not a draft", "three rounds") and normalised to the tokens above. A run must never depend on an undocumented phrase — if the user asks for something not in this table, ask once, then proceed.

## 1. Resolve the input; decide whether code is needed

For an issue: `gh issue view <n> --json title,body,labels,comments`. For a spec: use it verbatim.

Look at the code first. If no change is actually required (already fixed, not reproducible, a docs-only misunderstanding), say so and **stop here** — no branch is created.

## 2. Branch and worktree

1. Branch name: read `~/.config/git/issue-prefixes`. Issue work in a listed repo → `<PREFIX>-<n>/<slug>`. Otherwise ask for a ticket with one `AskUserQuestion`; if there is none, `u/sloan/<slug>`.
2. `git fetch origin && wt switch -c <branch> -b origin/main`. Capture `WORKTREE=$(git rev-parse --show-toplevel)` and confirm `git branch --show-current`.
3. Read the repo's instruction files in this order, whichever exist at the worktree root: `CLAUDE.md`, `AGENTS.md`, `RULES.md`, then every `*.md` under `.claude/rules/`. Extract `TEST_CMD` and `LINT_CMD` (omnibus: `just test`, `just lint`). If neither file names them, ask once.
4. Build the **run context block**. Every dispatch below receives it verbatim — subagents inherit nothing from this session:

```
Worktree (absolute): <WORKTREE>
Branch: <branch>     Base: origin/main
Test: <TEST_CMD>     Lint: <LINT_CMD>
Diff command: git -C <WORKTREE> diff origin/main...HEAD
Plan: <PLAN_PATH>
Instruction files: <the ones found, in read order>
Issue/spec: <#n title | first line of the spec>
```

`<SCRATCH>` is the session scratchpad directory from the system prompt (fall back to `$TMPDIR/dev-loop`). Run artifacts live at `<SCRATCH>/dev-loop/<branch>/` and are never committed.

## 3. Plan

Dispatch a fresh `general-purpose` subagent on Opus: "Apply `~/.claude/skills/writing-plans/SKILL.md` to the spec below. Write the plan to `<SCRATCH>/dev-loop/<branch>/plan.md` — **not** the skill's default `docs/plans/` location. Return the header, the file-structure pass, the task titles, and any open questions." Include the issue body or spec and the run context block.

Then:

- Read the plan once. Answer its open questions yourself from the issue, the repo, and the instruction files where you can; batch the remainder into **one** `AskUserQuestion`. Append the answers to the plan file.
- If the file-structure pass exceeds the global stacking thresholds (over 500 lines or 20 files), stop and ask the user to split the spec. v1 does not auto-stack.

## 4. Implement

Dispatch `dev-loop-implementer` (`model: sonnet`) with the run context block, `Mode: initial`, and the plan path. Handle its status:

| Status | Action |
|---|---|
| `DONE` | verify independently (below) |
| `DONE_WITH_CONCERNS` | read them; correctness or scope concerns become the first rows of the round-1 verdict table; observations are noted |
| `NEEDS_CONTEXT` | answer from the issue / plan / repo; batch what you cannot into one `AskUserQuestion`; re-dispatch with the answers appended. Two round-trips per phase, then treat as `BLOCKED` |
| `BLOCKED` | context problem → re-dispatch with more; reasoning problem → re-dispatch on Opus; plan wrong → back to §3 once; otherwise hand back to the user |

Never trust the self-report. On `DONE`: `git -C <WORKTREE> status --porcelain` must be empty, `git log origin/main..HEAD --oneline` must show the commits, and you run the plan's per-task test targets yourself (not the full suite yet). Red here means the report was wrong: re-dispatch in `Mode: fix` with the failing output as the brief. That re-dispatch does not count as a review round.

## 5. Review loop

Let `r = 1`, `cap` from §0 (default 2). Each round:

1. **Snapshot.** Refuse to start on a dirty tree. `git -C <WORKTREE> diff origin/main...HEAD > <SCRATCH>/dev-loop/<branch>/round-<r>.patch`; keep `--stat` for the report. Both reviewers read this one file, so they see an identical diff.
2. **Dispatch both reviewers in parallel** — two `Agent` calls in one message, `subagent_type: dev-loop-prosecutor` and `dev-loop-minimalist`. Each gets the run context block, the patch path, the plan path, `Round: <r>`, and (round 2+) the prior verdict table. Full diff every round: the minimalist's mandate is about the whole shape, and a round-2 fix can create a round-1 problem.
3. **Merge** both lists into one table, IDs `P<n>` / `M<n>`.
4. **Dedupe.** Same range and same claim → one row, both sources noted. Same range and opposing mandates (prosecutor wants a guard, minimalist wants it deleted) → mark the pair a **conflict** and keep both rows linked.
5. **Verify every row yourself**, evidence in the same message — `verify-before-claim` applied to review findings:
   - correctness / security / data-safety / concurrency → run the finding's verify command from `<WORKTREE>`;
   - missing-test → grep for the test, read its assertion;
   - repo-rule → read the cited section and the code;
   - plan-gap → check the task against `git log`;
   - duplicate-helper → Read both definitions, compare signatures and semantics;
   - over-engineering / speculative-scope / beyond-plan → read the plan; the simpler alternative must still satisfy it and no rule may mandate the extra;
   - hollow-test → read the assertion; confirmed if it cannot fail.
6. **Verdict per row**, with a one-line reason:
   - **CONFIRMED** — evidence supports it; goes in the fix brief.
   - **DISMISSED** — evidence contradicts it, or it is unverifiable and the reviewer gave no runnable check.
   - **JUDGMENT** — the evidence is real but the answer is a call, not a fact: a fix over ~20 lines that departs from the plan, a conflict with no repro either way, a MINOR trade-off. **Decide it.** Apply the decision as CONFIRMED or DISMISSED and record the rationale under "Judgment calls" in the report and PR body, so the user can overrule at review. Do not defer these.
   - **DEFERRED_TO_USER** — only three cases: removing or changing user-visible behaviour the issue did not ask for; a change to the security or auth model; a question the issue itself explicitly leaves open. Never blocks the loop; always in the report and PR body; blocks a `merge` run exactly like a `ship-pr` deferral.
7. **Conflict rule.** Verify the prosecutor's scenario first. It reproduces, or cites a real rule → prosecutor wins ("correctness beats size"), the M row is DISMISSED. No repro → minimalist wins, the P row is DISMISSED. Neither verifiable → smaller diff wins, recorded as JUDGMENT.
8. **Severity gate.** CRITICAL and MAJOR CONFIRMED items always enter the brief. MINOR enters only if the fix is under ~5 lines; otherwise it is reported, not fixed.
9. **Exit check.** Empty brief → loop done, go to §6. `r == cap` with a non-empty brief → do not fix; go to §6 with the brief listed as unresolved, and open no PR unless the user overrode (`ready` / `merge` still stop here and hand back). Convergence guard: a row CONFIRMED in two consecutive rounds after a fix attempt → the next implementer dispatch runs on Opus (`model: "opus"`); still unresolved at the cap → `BLOCKED`, hand back.
10. **Fix brief.** One block per CONFIRMED item: ID, location, what to change (the finding's suggested fix or simpler alternative), and the verify command that must pass afterwards. Append: "Do not touch DISMISSED, JUDGMENT-kept, or DEFERRED items: <ids>. Commit as `fix:` on top. Never amend."
11. **Dispatch** `dev-loop-implementer` with the run context block, `Mode: fix`, and the brief. Handle status as in §4. On `DONE`, run each item's verify command yourself; anything still failing stays CONFIRMED into the next round.
12. `r += 1`; back to step 1.

After each round print the verdict table:

```
| ID | Src | Location | Claim | Verdict | Evidence / reason |
```

## 6. Post-loop verification

Run `TEST_CMD` and `LINT_CMD` in full, fresh, in this message. Red → `test-failure-triage`:

- pre-existing (also fails on `origin/main`) → note for the PR body;
- in-branch → one more implementer dispatch in `Mode: fix` with the failing output (separate cap of 2, not a review round), then re-run both commands.

Mechanical lint fixes (`cargo fmt`, `biome format`) also go through the implementer. The orchestrator never edits the worktree, even for that.

## 7. Ship

- **Default:** invoke `open-pr` and tell it to open as a **draft**. The PR body gets a "dev-loop" section — bullets only, per the global PR rule: rounds run, counts of confirmed / dismissed / judgment / deferred findings, judgment calls with their one-line rationale, deferred items, pre-existing failures, and a one-paragraph plan summary. No Claude attribution anywhere.
- `ready` → the same, non-draft.
- `merge` → invoke `ship-pr` (non-draft). If any DEFERRED_TO_USER item exists, tell `ship-pr` "stop before merge".
- `no-pr` → end here; push nothing.

## 8. Final report

```
dev-loop: <branch> — <issue/spec title>
Plan: <path> (<n> tasks)   Implementation: <m> commits <sha..sha>, <status>
Review rounds: <r>/<cap>   [degraded: skip=<reviewer>]
  R1  P: <n> (<c> confirmed / <d> dismissed / <j> judgment / <u> deferred)   M: <n> (…)   fixes: <k> commits
  R2  …
Verification: <TEST_CMD> → exit 0, <n> passed | <LINT_CMD> → exit 0
Pre-existing failures: <list | none>
Judgment calls: <ID — decision — one-line why> | none
Deferred to you: <ID — one line> | none
PR: <url> (draft | ready | merged | not opened: <reason>)
Blocking: <what stopped the loop | nothing>
```

## Hard rules

- **Never** edit the worktree from the orchestrator. Scratchpad only. Every source change is an implementer commit.
- **Never** CONFIRM a finding without evidence the orchestrator produced in the same message. A reviewer's confidence is not evidence.
- **Never** amend, rebase, or force-push. Every fix round is new commits.
- **Never** start a review round on a dirty tree, and never claim green without a fresh full `TEST_CMD` + `LINT_CMD` run in the same message.
- **Never** exceed the round cap, and never re-dispatch identical inputs to the same model after `BLOCKED` — something must change.
- **Never** let a subagent inherit session history. Every dispatch carries the full run context block.
- **Never** merge with a DEFERRED_TO_USER item outstanding.
- **Never** investigate-then-edit on `main`. §2 precedes every implementer dispatch.
- **Never** let anything pushed — branch, commits, PR text — reference Claude.
