---
name: tdd
description: Test-driven development discipline, on by default for every behaviour change. Iron Law - no production code without a failing test first. An agreed test list (seam, layer, test names) before the first test, outside-in from the boundary, Red-Green-Refactor with a mandatory verify-red step, one vertical slice at a time. Runs without being asked whenever implementation work starts on a new feature, bug fix, refactor, or behaviour change; also triggers when the user asks to "use TDD", "write the test first", "TDD this feature", "test-drive this", or mentions "red-green-refactor".
---

# tdd

Proactive partner to [test-failure-triage](../test-failure-triage/SKILL.md) (which handles failures *reactively*). This skill applies before code is written, and it is the default: the user opts out, never in.

## Read the standards first

Before the first test, read `~/.claude/standards/CODING_STANDARDS.md` and every file it names for the task. They decide each test's layer, name, location, and shape. This skill decides only the order the work happens in.

## Iron Law

**NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.**

If you wrote production code first → delete it, write the test, watch it fail, then implement fresh from the test. "Keep the old code as reference" is the rationalization that breaks this.

Violating the letter of this rule is violating the spirit.

## When to apply

| Use TDD | Don't |
|---|---|
| New features | Throwaway prototypes (ask first) |
| Bug fixes (regression test mandatory) | Generated code |
| Refactoring (tests prove behavior preserved) | Pure config files |
| Behavior changes | Trivial one-liners with no logic |

"Skip TDD just this once" → that's the rationalization. Stop.

## Agree the test list first

A **seam** is the public interface a test goes through: where you observe behaviour without reaching inside. Tests live at seams, never against internals. You can't test everything, so agreeing the seams up front is how testing effort lands on the critical paths and complex logic instead of every edge case.

Before writing any test, write the **test list**: each seam, its layer from the standards' layer table with a one-line reason, and the behaviours to test there, already named in the language's convention.

```
POST /v1/orders (integration: builds and sends HTTP)
  contract matching
    returns created order from valid request
    sends api key as bearer token
parsePrice (unit: pure parsing, no I/O)
  validation
    rejects negative amount
```

- **Run directly** (`/tdd`, or TDD in the main session): when the list adds a new seam or a new test file, confirm it with the user before the first test, and write no test at an unconfirmed seam. Otherwise show the list and proceed.
- **Run under a plan** (the `dev-loop` implementer, a `writing-plans` task): the seams and layers the plan lists count as agreed. Write the list from them. If the plan lists no seams for a task, return `NEEDS_CONTEXT` rather than picking your own.

The list holds names, not tests. Tests are still written one at a time (see horizontal slicing, below), and the list grows as each cycle teaches you something.

## Outside-in: start at the boundary

When a slice crosses a boundary, run two loops:

1. **Outer:** write the test at the outermost seam and watch it fail: end-to-end when the slice is a user journey the layer table sends there, integration otherwise. It stays red while you work.
2. **Inner:** drive the logic behind it with unit tests, one Red → Green → Refactor cycle each.
3. **Close:** the outer test goes green once the inner work is done. While it's still red, its failure names the next unit test to write.

A slice of pure logic runs only the inner loop.

## Red → Green → Refactor

```
RED  ──▶ verify-red ──▶ GREEN ──▶ verify-green ──▶ REFACTOR ──▶ next
              │                          │              │
        wrong failure?               not green?      stay green
              ▼                          ▼              ▼
              RED                       GREEN         REFACTOR
```

### 1. RED — write the test

One behaviour from the test list, at its agreed seam and layer. Name, place, and shape it as the standards' examples do. Real code, not mocks: double only the boundaries (see Test doubles in `~/.claude/standards/testing.md`).

### 2. Verify RED — watch it fail

**Mandatory. Never skip.**

Run the test. Confirm it fails for the *right reason* (`function not defined`, `assertion: expected X, got Y` — not `compile error in unrelated file`).

If it doesn't fail, the test is wrong. Fix the test, not the code.

### 3. GREEN — minimal code to pass

Smallest possible change that makes the failing test pass. No extra branches, no error paths the test doesn't exercise.

Run the suite. Confirm exit code 0.

### 4. REFACTOR — clean up while green

Now you can refactor with the safety net of a passing test. Re-run after each change to stay green.

If a refactor breaks the test, your refactor is wrong (or the test was tied to implementation, not behavior — fix the test first, separately).

### 5. Next test

Pick the next behavior. Back to RED.

Work in **vertical slices**: one test → one implementation → repeat, each test a **tracer bullet** that responds to what the last cycle taught you. Never write all the tests first (see horizontal slicing, below).

## Bug-fix variant — Red-Green for regression

For a bug:
1. Write the regression test that reproduces the bug.
2. Run it → must FAIL with the bug present.
3. Apply the fix.
4. Run it → must PASS.
5. **Revert the fix locally**, run again → test must FAIL again. This proves the test catches the bug.
6. Re-apply the fix. Confirm pass.

If step 5 doesn't fail, the test isn't really catching the bug. Tighten it.

## Anti-patterns

What makes a single test bad (coupled to the implementation, or tautological) lives under Shape of a test in `~/.claude/standards/testing.md`. The anti-pattern in the process itself:

- **Horizontal slicing**: writing all the tests first, then all the implementation. Bulk tests verify _imagined_ behavior: they test the _shape_ of things rather than what callers see, go insensitive to real changes, and lock in test structure before you understand the implementation. One slice at a time instead.

## Common rationalizations — reject these

| "Reason" to skip | Reality |
|---|---|
| "It's a tiny change" | Tiny changes break things constantly. Test it. |
| "I'll add the test after" | You won't. And if you do, it'll be biased toward the code you wrote. |
| "There's nothing to test" | Then there's nothing to write. If there's behavior, there's a test. |
| "The framework guarantees this" | The framework guarantees its own behavior, not your usage. |
| "Testing this would require too much setup" | That's a design smell — the unit is too coupled. |
| "I'll keep my code as reference while writing the test" | Delete it. The test should drive the design. |

## Hard rules

- **Never** write production code before the failing test exists.
- **Never** skip the verify-red step. The whole point is watching the test fail.
- **Never** make a test pass by weakening the assertion. Tighten the code, not the test.
- **Never** declare a bug fix complete without the revert-and-fail-again step (regression proof).
- **Never** combine multiple behaviors in one test. One test, one behavior.
- **Never** mock what you're testing. Mock the boundary, not the unit.
- **Never** write a test at a new seam nobody agreed on, or before its layer is decided.
- **Never** compute a test's expected value the way the code computes it.
- **Never** write a batch of tests ahead of the code. One slice at a time.

---

Seams, horizontal and vertical slicing adapted from `tdd` in [mattpocock/skills](https://github.com/mattpocock/skills), Copyright (c) 2026 Matt Pocock, MIT License.
