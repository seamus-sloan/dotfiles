---
name: tdd
description: Test-driven development discipline. Iron Law - no production code without a failing test first. Red-Green-Refactor cycle with mandatory verify-red step. Triggers when the user asks to "use TDD", "write the test first", "TDD this feature", "test-drive this", or starts implementation work where TDD applies.
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

## Red → Green → Refactor

```
RED  ──▶ verify-red ──▶ GREEN ──▶ verify-green ──▶ REFACTOR ──▶ next
              │                          │              │
        wrong failure?               not green?      stay green
              ▼                          ▼              ▼
              RED                       GREEN         REFACTOR
```

### 1. RED — write the test

One behavior. Clear name. Real code, not mocks.

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

## Bug-fix variant — Red-Green for regression

For a bug:
1. Write the regression test that reproduces the bug.
2. Run it → must FAIL with the bug present.
3. Apply the fix.
4. Run it → must PASS.
5. **Revert the fix locally**, run again → test must FAIL again. This proves the test catches the bug.
6. Re-apply the fix. Confirm pass.

If step 5 doesn't fail, the test isn't really catching the bug. Tighten it.

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
