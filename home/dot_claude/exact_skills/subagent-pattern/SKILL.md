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
| Plan exists, want a separate session per task (worktree-style) | [jj-workspaces](../jj-workspaces/SKILL.md) |
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
finishing the branch (jj-basics + open-pr)
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
<full task text including all checkbox steps and code blocks>

Repo context:
- Working dir: <path>
- VCS: jj (use jj-basics skill — describe + bookmark move + commit per step)
- Test command: <command from CLAUDE.md>
- Lint: <command>

Constraints:
- Follow each checkbox step exactly. Don't skip the verify-red / verify-green steps.
- Commit after each task per the plan's convention.
- Apply tdd skill: red → verify red → green → verify green → commit.
- If unsure about anything, return NEEDS_CONTEXT — don't guess.

Return one of: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED.
Include the change-id of your final commit.
```

### Spec-reviewer prompt skeleton

```
You are reviewing whether implementation matches spec.

Plan task: <full task text>
Implementer's commit: <change-id>
Diff: <jj diff -r <change-id>>

Check:
1. Every checkbox step in the spec → was it executed and verifiable in the diff?
2. Test from RED step → present and asserts the right behavior?
3. Code from GREEN step → matches what the spec said to write?
4. Commit message → matches the spec's commit message?

Return APPROVE or REQUEST_CHANGES with a numbered list of gaps.
Be terse. Don't comment on style — that's the next reviewer's job.
```

### Code-quality reviewer prompt skeleton

```
You are reviewing code quality of <change-id>.

Apply the pre-landing-review skill's CRITICAL pass on this diff:
- SQL & data safety
- Race conditions
- LLM output trust boundary
- Shell injection
- Enum completeness

Plus the suppression list — do NOT flag stylistic noise.

Return APPROVE or REQUEST_CHANGES with file:line citations.
```

## After all tasks pass

Run a **final reviewer subagent** across the *entire* implementation (not per-task). Catches integration issues that per-task reviews miss — broken cross-references, dead code introduced halfway through, inconsistent patterns.

Then hand off to [jj-basics](../jj-basics/SKILL.md) (push) and [open-pr](../open-pr/SKILL.md) (PR).

## Report back

After the loop completes, summarize:

```
Subagent run: <N> tasks, <M> rounds of review
Tasks: <N> DONE | <N> DONE_WITH_CONCERNS | <N> escalated
Final reviewer findings: <count> | resolved: <count>
Commits: <change-id-1>..<change-id-N>
```

## Hard rules

- **Never** let a subagent inherit your session history. Construct exactly what they need.
- **Never** skip spec review to "save a step" — that's where most drift is caught.
- **Never** trust a subagent's self-report. Verify via `jj diff` against `<change-id>`.
- **Never** retry a BLOCKED task on the same model with no input changes.
- **Never** combine the two review stages. Spec compliance ≠ code quality. Different reviewers, different prompts.
- **Never** skip the final-pass reviewer at the end. Per-task review misses cross-task issues.
