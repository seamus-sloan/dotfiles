---
name: writing-plans
description: Write an implementation plan as a short list of tracer-bullet tasks — each a thin end-to-end slice with its files, the seams its tests go through, acceptance criteria, and a verify command. Saved to the session scratchpad; dev-loop's plan step uses it. Triggers when the user asks to "write a plan", "draft an implementation plan", "plan this out", "break this into tasks", or has a spec and wants tasks to execute.
---

# writing-plans

A plan pins down **what** gets built and **where**, so the implementer — the `dev-loop` implementer, a [subagent-pattern](../subagent-pattern/SKILL.md) subagent, or you tomorrow — never re-derives the design. It does not write the code: the implementer does that test-first, per [tdd](../tdd/SKILL.md).

## Where it goes

`<scratchpad>/plans/<YYYY-MM-DD>-<slug>.md` — the session scratchpad directory from the system prompt (fall back to `$TMPDIR`). When `dev-loop` asks for a plan it names its own path; use that. Plans are working files: commit one to a repo only when the user asks.

## 1. Scope check

If the spec covers more than one independent subsystem, stop and suggest one plan per subsystem. Each plan must produce working, testable software on its own.

## 2. File map

List every file the plan creates or modifies, with one line of responsibility each. This is where the decomposition gets locked in: one clear responsibility per file, and files that change together live together.

```
Create:
  src/auth/session.rs          — Session type, expiry
  tests/auth/login_test.rs     — login seam: success + each failure mode
  db/migrations/0042_sessions.sql

Modify:
  src/router.rs                — route POST /login
```

## 3. Tasks

Each task is a **tracer bullet**: a narrow but complete path through every layer it touches (schema, logic, API, UI, tests), verifiable on its own. Order them so each task can run green when it lands:

- Prefactoring first — make the change easy, then make the easy change.
- Schema before the code that uses it; anything later tasks depend on comes before them.
- A wide mechanical refactor (a rename or retype that breaks call sites everywhere at once) goes expand → migrate in batches → contract.

Every task uses this shape:

````markdown
### Task N — <what it delivers>

**Files:** Create `path`, Modify `path`
**Seams:** <the public interfaces its tests go through — `POST /login`, `Session::expires_at`>
**Acceptance criteria:**
- [ ] <observable outcome>
- [ ] <observable outcome>
**Verify:** `<command that runs only this task's tests>` → <expected result>
**Decisions:** <only when something must not be re-decided — a type, schema, public signature, or error enum, as a code block>
**Commit:** `<feat|fix|chore>: <subject>`
````

**Seams** count as agreed for `tdd`: the implementer tests there and nowhere else, and stops with `NEEDS_CONTEXT` when a task has none. A task with no behaviour (config, a rename) says `Seams: none — <why>`.

## 4. Final verification

End every plan with the full test suite, lint, and type-check commands from the repo's instruction files, each with its expected result. Pushing and opening a PR belong to the caller, not the plan.

## What a plan is not

- **Not the implementation.** No function bodies, no keystroke-level steps. A code block appears only under **Decisions**, pinning something the implementer must not choose for themselves.
- **No placeholders.** `TBD`, `TODO`, "handle edge cases", "add error handling", "similar to Task N" are plan failures: name the edge cases as acceptance criteria, the errors as a pinned enum. If a task can't name its seams, criteria, and verify command, the plan isn't ready — ask, or run a [grilling](../grilling/SKILL.md) round first.
- **No undefined references.** Every type, function, and path a task mentions is either created by some task or already exists in the repo.

## Self-check before calling it ready

- [ ] Every file in the map has a task, and every task's files are in the map.
- [ ] Every behaviour task names its seams, acceptance criteria, and a verify command.
- [ ] No placeholders, no undefined references.
- [ ] The plan ends with the final verification section.

## Hard rules

- **Never** plan more than one subsystem in one plan.
- **Never** write the implementation into the plan. Code blocks pin decisions only.
- **Never** leave a behaviour task without seams.
- **Never** end without the final verification section.

---

Tracer-bullet tasks and expand–contract ordering adapted from `to-tickets` in [mattpocock/skills](https://github.com/mattpocock/skills), Copyright (c) 2026 Matt Pocock, MIT License.
