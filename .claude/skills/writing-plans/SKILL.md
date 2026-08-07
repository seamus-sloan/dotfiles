---
name: writing-plans
description: Write an implementation plan as a checkbox of bite-sized 2-5 minute steps, TDD baked in, with exact file paths, exact commands, and complete code in every step. Output goes to <repo>/docs/plans/YYYY-MM-DD-<slug>.md. Triggers when the user asks to "write a plan", "draft an implementation plan", "plan this out as steps", "break this into tasks", or has a design and wants tasks to execute.
---

# writing-plans

Produces an *implementation plan* — a sequence of bite-sized steps another agent (or you on a future day) can execute mechanically.

Distinct from [plan-eng](../plan-eng/SKILL.md), which produces a *design doc* (data flow, storage shape, failure modes). Plan-eng is "what and why." This skill is "what to type, in what order, with what verification."

Pairs with [subagent-pattern](../subagent-pattern/SKILL.md) (which executes these plans) and [tdd](../tdd/SKILL.md) (which dictates the per-task RED → GREEN → REFACTOR shape).

## File location

```
<repo>/docs/plans/<YYYY-MM-DD>-<slug>.md
```

Slug is kebab-case, ticket-prefixed when applicable: `2026-04-26-ada-120-login-flow.md`.

## Audience assumption

Write for a skilled developer who knows nothing about your codebase or domain. Don't assume they know good test design. Show them the test code and the production code in the plan — don't link out, don't say "similar to above."

## Scope check — first

If the spec covers multiple independent subsystems, **stop**. Suggest splitting the spec into one plan per subsystem. Each plan should produce working, testable software on its own.

Don't try to plan a whole platform in one document. The plan becomes unreadable and the agent gets lost mid-execution.

## File-structure pass — second

Before writing tasks, list every file the plan will create or modify, with a one-line responsibility for each:

```
Create:
  src/auth/login.rs            — POST /login handler + session creation
  src/auth/session.rs          — Session struct, expiry logic
  tests/auth/login_test.rs     — happy path + 3 failure-mode tests
  db/migrations/0042_sessions.sql

Modify:
  src/router.rs                — add /login route
  src/state.rs                 — add SessionStore to AppState
```

This is where decomposition gets locked in. Each file should have one clear responsibility. Files that change together live together.

## Plan header (mandatory)

Every plan starts with this header — verbatim:

```markdown
# <Feature Name> implementation plan

> **For agentic execution:** REQUIRED SUB-SKILL — use [subagent-pattern](../../skills/subagent-pattern/SKILL.md) to run these tasks. Steps use checkbox (`- [ ]`) syntax for tracking. Each task applies [tdd](../../skills/tdd/SKILL.md): RED → verify-red → GREEN → verify-green → commit.

**Goal:** <one sentence>

**Architecture:** <2–3 sentences>

**Tech stack:** <key technologies>

**Design doc:** [<slug>](../design/<slug>.md) (if applicable)

**Roadmap initiative:** [F<phase>.<n>](../roadmap/<phase>-<n>-<slug>.md) (if applicable)

---
```

## Bite-sized task structure

Each task is one logical unit. Each step inside the task is one action of 2–5 minutes:

```markdown
### Task N — <component name>

**Files:**
- Create: `exact/path/to/file.rs`
- Modify: `exact/path/to/existing.rs:123-145`
- Test: `tests/exact/path/to/test.rs`

- [ ] **Step 1: write the failing test**

```rust
#[test]
fn login_creates_session_for_valid_credentials() {
    let app = test_app();
    let resp = app.post("/login").json(&Credentials { user: "alice", pass: "hunter2" }).send();
    assert_eq!(resp.status(), 200);
    assert!(resp.headers().get("set-cookie").is_some());
}
```

- [ ] **Step 2: run test to verify it fails**

```bash
cargo test --test login_test login_creates_session_for_valid_credentials -- --nocapture
```

Expected: `FAIL — handler not found at /login`.

- [ ] **Step 3: minimal implementation**

```rust
// src/auth/login.rs
pub async fn login(State(s): State<AppState>, Json(c): Json<Credentials>) -> impl IntoResponse {
    let session = s.session_store.create(&c.user).await?;
    (StatusCode::OK, jar.add(session.cookie()))
}
```

- [ ] **Step 4: run test to verify it passes**

```bash
cargo test --test login_test login_creates_session_for_valid_credentials
```

Expected: `PASS`.

- [ ] **Step 5: commit**

```bash
git add .
git commit -m "feat: add /login handler with session creation"
```

(Don't push yet — push at end of plan.)
```

## No placeholders — ever

These are **plan failures**. Don't write them, even in draft:

| Forbidden | Why |
|---|---|
| `TBD`, `TODO`, `implement later`, `fill in details` | The plan's job is to remove the TBDs. |
| "Add appropriate error handling" | Show the named errors and their sites. |
| "Handle edge cases" | List them and write the test for each. |
| "Write tests for the above" (no test code) | Show the test code in a code block. |
| "Similar to Task N" (no repeat) | Repeat the code. The agent may execute tasks out of order. |
| Steps that describe but don't show | Code steps need code blocks. |
| References to types/functions/paths not defined in any task | Either define them or link to where they live. |

If you can't fill a step in concretely, the plan isn't ready — go back to the design doc or brainstorm pass first.

## Task ordering rules

- **Foundations first.** A task that creates a type used by 3 later tasks comes first.
- **One commit per task** by default. Multiple commits inside a task only if the task has natural sub-units (rare).
- **Test commands callable in isolation.** Each task's verify step uses a command that targets *only* that task's test, not the whole suite. The full suite runs at the end.
- **Migrations before model changes before route changes.** Schema first, then code that uses it.

## End-of-plan section

```markdown
---

## Final verification

- [ ] **Full test suite**
  ```bash
  cargo test
  ```
  Expected: all green.

- [ ] **Lint**
  ```bash
  cargo clippy --all-targets -- -D warnings
  ```

- [ ] **Type-check** (separate from tests if applicable)
  ```bash
  cargo check
  ```

- [ ] **Push**
  ```bash
  git push
  ```
  `push.autoSetupRemote` is set globally, so the first push on a new branch sets its upstream. Never `--force`.

- [ ] **Open PR**
  Per [open-pr](../../skills/open-pr/SKILL.md).
```

## Self-check before declaring the plan ready

- [ ] Every step has either code, a command, or both — not just prose.
- [ ] Every test step shows the test code AND the verify command AND the expected output.
- [ ] No `TBD`, `TODO`, `implement later`, or "similar to above."
- [ ] Every file in the file-structure pass has at least one task that creates or modifies it.
- [ ] Final verification section runs the full suite, not just the per-task tests.

## Hard rules

- **Never** write a plan that spans multiple subsystems — decompose first.
- **Never** leave a placeholder. If you can't fill it, the plan isn't ready.
- **Never** abbreviate code with "similar to above" — repeat it.
- **Never** skip the verify-red step in a TDD task. The whole TDD discipline collapses without it.
- **Never** end a plan without a "final verification" section that runs the full suite.
