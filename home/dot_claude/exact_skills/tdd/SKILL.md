---
name: tdd
description: Test-driven development discipline. Iron Law - no production code without a failing test first. Red-Green-Refactor cycle with mandatory verify-red step, one vertical slice at a time, tests only at agreed seams. Triggers when the user asks to "use TDD", "write the test first", "TDD this feature", "test-drive this", mentions "red-green-refactor", or starts implementation work where TDD applies.
---

# tdd

Proactive partner to [test-failure-triage](../test-failure-triage/SKILL.md) (which handles failures *reactively*). This skill applies before code is written.

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

## Agree the seams first

A **seam** is the public interface a test goes through: where you observe behaviour without reaching inside. Tests live at seams, never against internals. You can't test everything, so agreeing the seams up front is how testing effort lands on the critical paths and complex logic instead of every edge case.

Before writing any test, write down the seams under test:

- **Run directly** (`/tdd`, or TDD in the main session): confirm them with the user. Ask: "What's the public interface, and which seams should we test?" No test is written at an unconfirmed seam.
- **Run under a plan** (the `dev-loop` implementer, a `writing-plans` task): the seams the plan lists count as agreed. If the plan lists none for a task, return `NEEDS_CONTEXT` rather than picking your own.

## Red → Green → Refactor

```
RED  ──▶ verify-red ──▶ GREEN ──▶ verify-green ──▶ REFACTOR ──▶ next
              │                          │              │
        wrong failure?               not green?      stay green
              ▼                          ▼              ▼
              RED                       GREEN         REFACTOR
```

### 1. RED — write the test

One behavior, at an agreed seam. Clear name. Real code, not mocks (see [mocking.md](mocking.md) for the boundaries where a mock is right).

```rust
// Good — tests behavior, has a clear name
#[test]
fn retry_succeeds_after_two_failures() {
    let mut attempts = 0;
    let op = || { attempts += 1; if attempts < 3 { Err("fail") } else { Ok("ok") } };
    assert_eq!(retry(op, 3), Ok("ok"));
    assert_eq!(attempts, 3);
}
```

```rust
// Bad — vague name, tests the mock not the behavior
#[test]
fn retry_works() {
    let mock = Mock::new().fail().fail().succeed();
    retry(mock, 3);
    assert_eq!(mock.calls(), 3);
}
```

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

- **Implementation-coupled**: mocks internal collaborators, tests private functions, or verifies through a side channel (querying the database instead of using the interface). The tell: the test breaks when you refactor but behavior hasn't changed.
- **Tautological**: the assertion recomputes the expected value the way the code does, so it passes by construction and can never disagree with the code. Expected values come from an independent source of truth: a known-good literal, a worked example, the spec.

  ```rust
  // Bad — recomputes the expected value the same way the code does
  #[test]
  fn total_sums_line_items() {
      let items = vec![Item { price: 10 }, Item { price: 5 }];
      let expected: u32 = items.iter().map(|i| i.price).sum();
      assert_eq!(total(&items), expected);
  }

  // Good — expected value is an independent, known literal
  #[test]
  fn total_sums_line_items() {
      assert_eq!(total(&[Item { price: 10 }, Item { price: 5 }]), 15);
  }
  ```

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
- **Never** mock what you're testing. Mock the boundary, not the unit ([mocking.md](mocking.md)).
- **Never** write a test at a seam nobody agreed on.
- **Never** compute a test's expected value the way the code computes it.
- **Never** write a batch of tests ahead of the code. One slice at a time.

---

Seams, anti-patterns, vertical slicing and [mocking.md](mocking.md) adapted from `tdd` in [mattpocock/skills](https://github.com/mattpocock/skills), Copyright (c) 2026 Matt Pocock, MIT License.
