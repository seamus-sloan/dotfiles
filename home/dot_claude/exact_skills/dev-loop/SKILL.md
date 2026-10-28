---
name: dev-loop
description: Agentic development loop — branch → plan → implement → panel review via pr-review (finders covering every review angle, verifiers, the orchestrator rules on each; later rounds review only the fixes) → fix → test → draft PR. Triggers when the user says "/dev-loop <issue # or spec>", "dev-loop this", "run the dev loop on #123", "take this issue end to end".
argument-hint: "<issue # | issue URL | ticket key | spec file | spec text> [ready] [merge] [no-pr] [rounds=N] [depth=quick|standard|deep] [branch=<name>] [base=<branch>] [plan=<path>]"
---

# dev-loop (branch → plan → implement → panel review → fix → test → PR)

The session running this skill is the **orchestrator**. It plans, dispatches, judges, and reports. It delegates the real work to existing skills and custom agents and never re-implements them:

| Step | Owner |
|---|---|
| Plan | [`writing-plans`](../writing-plans/SKILL.md) via a fresh subagent |
| Implement, fix | `dev-loop-implementer` agent (runs [`tdd`](../tdd/SKILL.md)), resumed for every fix |
| Review | [`pr-review`](../pr-review/SKILL.md) at `depth` (default `standard`) on round 1, then at `quick` on each round's fix commits |
| Judge findings | **the orchestrator itself**, by `pr-review`'s verify-and-rule steps — there is no referee |
| Verify | [`verify-before-claim`](../verify-before-claim/SKILL.md), [`test-failure-triage`](../test-failure-triage/SKILL.md) |
| Ship | [`open-pr`](../open-pr/SKILL.md), or [`ship-pr`](../ship-pr/SKILL.md) with `merge` |
| Ticket state | the orchestrator, by [`tickets.md`](tickets.md): assigned and In Progress at §2, In Review at §7, Done on merge |

Two invariants hold for the whole run:

1. **The orchestrator never edits the worktree.** Every source change comes from the implementer. The orchestrator writes only to its scratchpad. This holds after the run too: a follow-up fix to a loop's PR (a bug the user finds later) goes through the implementer plus a `quick` `pr-review` round.
2. **The orchestrator is the only judge.** Finders and verifiers report; nothing is acted on until the orchestrator has ruled on it, re-checking every CRITICAL or MAJOR defect itself.

Read `ship-pr` and `verify-before-claim` before running so their hard rules carry through.

## 0. Arguments

Parse `$ARGUMENTS`. The first token that is an integer, `#n`, or an issue URL names a GitHub issue; a Jira or Linear key or URL names that ticket ([`tickets.md`](tickets.md) says which tracker); a path to an existing file (a `grilling` summary, say) is the spec file; otherwise the leading text is the spec. Then honour these tokens anywhere in the arguments:

| Token | Effect |
|---|---|
| *(none)* | open a **draft** PR at §7 and stop |
| `ready` | open a non-draft PR |
| `merge` | implies `ready`; run `ship-pr` fully at §7 |
| `no-pr` | stop after §6 (green tests); push nothing |
| `rounds=N` | review-round cap (default **2**, hard max 5); every round, the last included, gets its fix pass |
| `depth=<d>` | round-1 review depth: `quick`, `standard` (default) or `deep` (see `pr-review`); later rounds always run `quick` on the fix commits |
| `branch=<name>` | the branch and worktree already exist; skip §2's create |
| `base=<branch>` | branch from and target `<branch>` (a feature branch, or the slice below in a stack) instead of `main`: `<BASE>` below becomes `origin/<branch>` everywhere, including `--base` at §7 |
| `plan=<path>` | the plan is already written; skip §3 |

Natural-language forms are accepted ("and merge", "but don't open a PR", "not a draft", "three rounds", "deep review") and normalised to the tokens above. A run must never depend on an undocumented phrase — if the user asks for something not in this table, ask once, then proceed.

## 1. Resolve the input; decide whether code is needed

For an issue: `gh issue view <n> --json title,body,labels,comments`. For a Jira or Linear ticket: read it through its MCP. For a spec file: read it. For a spec: use it verbatim.

Look at the code first. If no change is actually required (already fixed, not reproducible, a docs-only misunderstanding), say so and **stop here** — no branch is created.

**UX changes need signed-off comps first.** If the work changes what a user sees (layout, a new screen, moved controls) and the issue has no Figma comp the user has signed off, build the comps in Figma (on the surface's existing page; never an HTML artifact), link them in the issue description, and **stop** until the user signs off. Product and layout questions go to the user with the comps rather than being settled from the spec.

## 2. Branch and worktree

1. Branch name: read `~/.config/git/issue-prefixes`. Issue work in a listed repo → `<PREFIX>-<n>/<slug>`. A Jira or Linear ticket → `<KEY>/<slug>`. Otherwise ask for a ticket with one `AskUserQuestion`; if there is none, `u/sloan/<slug>`.
2. `git fetch origin && wt switch -c <branch> -b <BASE>` (`<BASE>` is `origin/main` unless `base=` set it). `wt switch` changes directory only in its own subprocess, so read `WORKTREE` from `wt list` (a `/` in the branch name becomes `-` in the directory), then confirm `git -C <WORKTREE> branch --show-current`.
3. Read the repo's instruction files in this order, whichever exist at the worktree root: `CLAUDE.md`, `AGENTS.md`, `RULES.md`, then every `*.md` under `.claude/rules/`. Extract `TEST_CMD` and `LINT_CMD` (omnibus: `just test`, `just lint`). If neither file names them, ask once.
4. Build the **run context block**. Every dispatch below receives it verbatim — subagents inherit nothing from this session:

```
Worktree (absolute): <WORKTREE>
Branch: <branch>     Base: <BASE>
Test: <TEST_CMD>     Lint: <LINT_CMD>
Diff command: git -C <WORKTREE> diff <BASE>...HEAD
Plan: <PLAN_PATH>
Instruction files: <the ones found, in read order>
Issue/spec: <#n title | first line of the spec>
```

`<SCRATCH>` is the session scratchpad directory from the system prompt (fall back to `$TMPDIR/dev-loop`). Run artifacts live at `<SCRATCH>/dev-loop/<branch>/` and are never committed.

5. **Start the ticket**, when the run has one: assign it to me and move it to In Progress, by [`tickets.md`](tickets.md).

## 3. Plan

Dispatch a fresh `general-purpose` subagent on Opus: "Apply `~/.claude/skills/writing-plans/SKILL.md` to the spec below. Write the plan to `<SCRATCH>/dev-loop/<branch>/plan.md`. Return the file map, the task titles with their seams, the risk pass, and any open questions." Include the issue body or spec and the run context block.

Then:

- Read the plan once. Answer its open questions yourself from the issue, the repo, and the instruction files where you can; batch the remainder into **one** `AskUserQuestion`. Append the answers to the plan file.

## 4. Implement

Dispatch `dev-loop-implementer` (`model: sonnet`) with the run context block, `Mode: initial`, and the plan path.

Keep the agent ID the dispatch returns. Every later implementer run (the re-runs below, each fix round in §5, §6's fixes) **resumes** that agent with `SendMessage` (`to: <agent ID>`) instead of dispatching a fresh one, so it keeps the plan and code it already read. The message carries the mode and the brief or answers; wait for its report before going on. Dispatch fresh, with the run context block and `git log <BASE>..HEAD --oneline`, only when the model must change (`BLOCKED` on reasoning, §5's convergence guard) or the resume fails; from then on, resume the new agent.

For a run expected to pass an hour, schedule a liveness watchdog at this first dispatch (T3 `schedule_task`, about every 30 minutes, when available): it checks every background agent and worktree for a dead or stalled run. A host restart kills background agents with no completion notice, so on any resume, check each one's worktree state and resume it with `SendMessage` and a state summary. Delete the watchdog at §8.

Handle its status:

| Status | Action |
|---|---|
| `DONE` | verify independently (below) |
| `DONE_WITH_CONCERNS` | read them; correctness or scope concerns become the first rows of the round-1 verdict table; observations are noted |
| `NEEDS_CONTEXT` | answer from the issue / plan / repo; batch what you cannot into one `AskUserQuestion`; resume it with the answers. Two round-trips per phase, then treat as `BLOCKED` |
| `BLOCKED` | context problem → resume it with more; reasoning problem → a fresh dispatch on Opus; plan wrong → back to §3 once; otherwise hand back to the user |

Never trust the self-report. On `DONE`: `git -C <WORKTREE> status --porcelain` must be empty, `git log <BASE>..HEAD --oneline` must show the commits, and you run every task's Verify command yourself, once, in one go (not the full suite yet), and check its output names every test the commits added. Red here means the report was wrong: resume it in `Mode: fix` with the failing output as the brief. That run does not count as a review round.

## 5. Review loop

Let `r = 1`, `cap` from §0 (default 2). Each round:

1. **Snapshot.** Refuse to start on a dirty tree. `git -C <WORKTREE> diff <BASE>...HEAD > <SCRATCH>/dev-loop/<branch>/round-<r>.patch`; keep `--stat` for the report. From round 2, set `FIXES_FROM` to the HEAD the previous round reviewed and also write the fix commits alone: `git -C <WORKTREE> diff <FIXES_FROM>..HEAD > <SCRATCH>/dev-loop/<branch>/round-<r>-fixes.patch`. Every finder and verifier reads the same files, so they all see an identical diff.
2. **Review with `pr-review`.** Invoke the [`pr-review`](../pr-review/SKILL.md) skill on round 1 and run its §3–§9 every round, passing the run context block, the plan path, `Round: <r>`, and:
   - round 1: the round's patch and `Depth: <depth from §0>`;
   - round 2+: the fixes patch as the diff file, the round's patch as the full diff, `Delta from: <FIXES_FROM>`, `Depth: quick`, and the prior verdict table. The fixes are small and step 6 already re-ran each fixed item's verify command, so the whole branch isn't reviewed again.

   It dispatches the finders, verifies their candidates, rules on each row, and returns the verdict table. Its rulings go to the user in the final report (§8), never into the PR: judgment calls with their rationale, so the user can overrule them; DEFERRED_TO_USER items, which never block the loop but block a `merge` run exactly like a `ship-pr` deferral.
3. **Severity gate.** CRITICAL and MAJOR items, CONFIRMED or PLAUSIBLE, always enter the brief. MINOR and excess (`Kind: excess`) items enter only if the fix is under ~5 lines; otherwise they are reported, not fixed.
4. **Exit check.** Empty brief → loop done, go to §6. `r == cap` with a non-empty brief → still run steps 5–6 (the last round gets its fix pass too), but don't review again: step 6's verify commands check the fixes, then go to §6. Any item that's still failing is listed as unresolved, and no PR is opened unless the user overrode (`ready` / `merge` still stop and hand back). Convergence guard: a row CONFIRMED or PLAUSIBLE in two consecutive rounds after a fix attempt → the next implementer run is a fresh dispatch on Opus (`model: "opus"`); still unresolved at the cap → `BLOCKED`, hand back.
5. **Fix brief.** One block per CONFIRMED or PLAUSIBLE item that passed the gate (a PLAUSIBLE item carries its "what would confirm" line, and its fix is a guard against that trigger): ID, verdict, location, what to change (the finding's suggested fix or simpler alternative), and the verify command that must pass afterwards. A PLAUSIBLE item's verify command is the test the implementer writes for its "what would confirm" condition. Append: "Do not touch DISMISSED, JUDGMENT-kept, or DEFERRED items: <ids>. Commit as `fix:` on top. Never amend."
6. **Resume** the implementer with `Mode: fix` and the brief. Handle status as in §4. On `DONE`, run each CONFIRMED item's verify command yourself; anything still failing keeps its verdict into the next round. A PLAUSIBLE item's command may have passed before the fix too, so it clears only when the fix commits add a test for its "what would confirm" condition and that test passes when you run it; otherwise it stays PLAUSIBLE into the next round. If the implementer's first run of that test failed, report the item as CONFIRMED.
7. `r == cap` → go to §6. Otherwise `r += 1`; back to step 1.

Print `pr-review`'s verdict table after each round.

## 6. Post-loop verification

Run `TEST_CMD` and `LINT_CMD` in full, fresh, in this message. Red → `test-failure-triage`:

- pre-existing (also fails on `<BASE>`) → note for the final report;
- in-branch → resume the implementer once more in `Mode: fix` with the failing output (separate cap of 2, not a review round), then re-run both commands.

Mechanical lint fixes (`cargo fmt`, `biome format`) also go through the implementer. The orchestrator never edits the worktree, even for that.

## 7. Ship

- **Default:** invoke `open-pr` and tell it to open as a **draft** against `<BASE>`. The body is `open-pr`'s terse template fill and nothing else: review rounds, findings, judgment calls, deferred items, and pre-existing failures all go to the user in §8, never into the PR. No Claude attribution anywhere.
- `ready` → the same, non-draft.
- `merge` → invoke `ship-pr` (non-draft). If any DEFERRED_TO_USER item exists, tell `ship-pr` "stop before merge".
- `no-pr` → end here; push nothing.

Once a PR is open and `ship-pr` hasn't merged it, move the ticket to In Review; a merge moves it to Done (`ship-pr` §5). Both by [`tickets.md`](tickets.md).

## 8. Final report

```
dev-loop: <branch> — <issue/spec title>
Plan: <path> (<n> tasks)   Implementation: <m> commits <sha..sha>, <status>
Review rounds: <r>/<cap>   Depth: <depth> on round 1, quick on fixes
  R1  candidates <raw> → <deduped>: <c> confirmed / <p> plausible / <d> dismissed / <j> judgment / <u> deferred   fixes: <k> commits
  R2  …
Verification: <TEST_CMD> → exit 0, <n> passed | <LINT_CMD> → exit 0
Pre-existing failures: <list | none>
Judgment calls: <ID — decision — one-line why> | none
Deferred to you: <ID — one line> | none
PR: <url> (draft | ready | merged | not opened: <reason>)
Ticket: <key> — <state>, assigned <me | someone else> | none | <what failed and the fix>
Blocking: <what stopped the loop | nothing>
```

## Hard rules

- **Never** edit the worktree from the orchestrator. Scratchpad only. Every source change is an implementer commit.
- **Never** CONFIRM a finding without evidence the orchestrator produced in the same message. A reviewer's confidence is not evidence.
- **Never** amend, rebase, or force-push. Every fix round is new commits.
- **Never** start a review round on a dirty tree, and never claim green without a fresh full `TEST_CMD` + `LINT_CMD` run in the same message.
- **Never** exceed the round cap, and never send identical inputs to the same model after `BLOCKED` — something must change.
- **Never** let a subagent inherit this session's history. Every fresh dispatch carries the full run context block; a resumed implementer already has it.
- **Never** merge with a DEFERRED_TO_USER item outstanding.
- **Never** investigate-then-edit on `main`. §2 precedes every implementer dispatch.
- **Never** let anything pushed — branch, commits, PR text — reference Claude.
