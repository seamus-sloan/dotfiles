---
name: subagent-pattern
description: Execute an implementation plan in the current session by dispatching one fresh subagent per task, with two-stage review (spec compliance, then code quality). Triggers when the user asks to "execute this plan with subagents", "delegate the tasks", "subagent-drive this", "parallelize the implementation", or has a checkbox plan ready to run.
---

# subagent-pattern

Plan in hand → run it through fresh subagents, one per task, with two-stage review after each.

Pairs with [writing-plans](../writing-plans/SKILL.md) (which produces the plan) and [verify-before-claim](../verify-before-claim/SKILL.md) (gate after each subagent finishes).

## When to use

| Condition | Use |
|---|---|
| Plan exists, tasks mostly independent, want to stay in this session | **subagent-pattern** (this skill) |
| Plan exists, want a separate session per task (worktree-style) | One `wt switch -c <branch>` worktree per task, each in its own session |
| No plan yet | [writing-plans](../writing-plans/SKILL.md) first |
| Tasks tightly coupled, can't be parallelized | Manual execution by you |

## Why subagents

You delegate to specialized subagents with **isolated context**. By precisely crafting their instructions, you keep them focused. They don't inherit your session history — you construct exactly what they need. This also preserves your own context for coordination.

**Core principle:** fresh subagent per task + two-stage review (spec → quality) = high quality, fast iteration.

## Process

```
read plan → TodoWrite all tasks
   │
   ▼
┌─[ per task ]────────────────────────────────────────┐
│  dispatch implementer subagent                       │
│   ├─ asks questions? → answer, re-dispatch          │
│   └─ implements + tests + commits + self-reviews    │
│        │                                             │
│        ▼                                             │
│  dispatch spec-reviewer subagent                    │
│   ├─ matches spec? → next stage                     │
│   └─ gaps?         → implementer fixes, re-review   │
│        │                                             │
│        ▼                                             │
│  dispatch code-quality-reviewer subagent            │
│   ├─ approves? → mark task complete in TodoWrite    │
│   └─ issues?   → implementer fixes, re-review       │
└──────────────────────────────────────────────────────┘
   │
   ▼ (more tasks?)
   │
   ▼
final code review across whole implementation
   │
   ▼
finishing the branch (git push + open-pr)
```

## Model selection

Use the cheapest model that can handle each role.

| Task signal | Model |
|---|---|
| 1–2 files, complete spec, mechanical | Haiku (cheap, fast) |
| Multi-file integration, pattern matching | Sonnet (default) |
| Architecture, design, review judgment | Opus |
| BLOCKED retry needs more reasoning | Bump up one tier |

Most implementation tasks are mechanical when the plan is well-specified — start with the cheap tier and only escalate if the subagent reports BLOCKED.

## Implementer status protocol

Implementer subagents report exactly one of these:

| Status | Meaning | What to do |
|---|---|---|
| **DONE** | Work complete, self-review passed | Proceed to spec review |
| **DONE_WITH_CONCERNS** | Done but flagged doubts | Read concerns. If correctness/scope → address before review. If observations ("file getting large") → note + proceed |
| **NEEDS_CONTEXT** | Missing info that wasn't provided | Provide it, re-dispatch (same model) |
| **BLOCKED** | Cannot complete | Triage: context problem (re-dispatch), reasoning problem (bump model), task too large (split), plan wrong (escalate to user) |

**Never** ignore a BLOCKED. **Never** retry the same model on the same task without changing inputs — something has to change.

## Subagent prompt structure

Each subagent gets a self-contained prompt. They have no memory of your session.

### Implementer prompt skeleton

```
You are implementing task <N> of <plan-path>.

Task spec (verbatim from plan):
<full task text: files, seams, acceptance criteria, verify command, decisions, commit line>

Repo context:
- Working dir: <path>
- VCS: git (`git add .` + `git commit -m "<the task's Commit line>"`; never amend or rebase)
- Test command: <command from CLAUDE.md>
- Lint: <command>

Constraints:
- Test only at the task's listed seams — they count as agreed for tdd.
- Apply tdd skill: red → verify red → green → verify green → commit. Never skip verify-red.
- Run the task's Verify command before committing; meet every acceptance criterion.
- Don't re-decide anything under Decisions.
- If unsure about anything, return NEEDS_CONTEXT — don't guess.

Return one of: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED.
Include the SHA of your final commit.
```

### Spec-reviewer prompt skeleton

```
You are reviewing whether implementation matches spec.

Plan task: <full task text>
Implementer's commit: <sha>
Diff: <git show <sha>>

Check:
1. Every acceptance criterion → met, and verifiable in the diff?
2. Tests → present at the task's seams, and asserting the criteria?
3. Decisions the task pins (types, schemas, signatures) → implemented as written?
4. Commit message → matches the task's Commit line?

Return APPROVE or REQUEST_CHANGES with a numbered list of gaps.
Be terse. Don't comment on style — that's the next reviewer's job.
```

### Code-quality reviewer

Dispatch the `review-neutral` agent (`subagent_type: review-neutral`) on the task's commit: save `git show <sha>` to the scratchpad as the diff file and build its context block per [pr-review](../pr-review/SKILL.md) §3, with the plan task as the spec. Verify and rule on its findings as `pr-review` §6–§7 does. Any CONFIRMED CRITICAL or MAJOR row → REQUEST_CHANGES; otherwise APPROVE.

## After all tasks pass

Run a **final reviewer subagent** across the *entire* implementation (not per-task). Catches integration issues that per-task reviews miss — broken cross-references, dead code introduced halfway through, inconsistent patterns.

Then push with `git push` and hand off to [open-pr](../open-pr/SKILL.md) (PR).

## Report back

After the loop completes, summarize:

```
Subagent run: <N> tasks, <M> rounds of review
Tasks: <N> DONE | <N> DONE_WITH_CONCERNS | <N> escalated
Final reviewer findings: <count> | resolved: <count>
Commits: <sha-1>..<sha-N>
```

## Hard rules

- **Never** let a subagent inherit your session history. Construct exactly what they need.
- **Never** skip spec review to "save a step" — that's where most drift is caught.
- **Never** trust a subagent's self-report. Verify via `git show <sha>`.
- **Never** retry a BLOCKED task on the same model with no input changes.
- **Never** combine the two review stages. Spec compliance ≠ code quality. Different reviewers, different prompts.
- **Never** skip the final-pass reviewer at the end. Per-task review misses cross-task issues.
