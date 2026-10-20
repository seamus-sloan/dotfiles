---
name: tdd
description: Test-driven development discipline, on by default for every behaviour change. Iron Law - no production code without its test written first. A short agreed test list (seam, layer, test names) of only the tests worth keeping, outside-in from the boundary, one vertical slice at a time, and one test run when the feature is done instead of at every step. Runs without being asked whenever implementation work starts on a new feature, bug fix, refactor, or behaviour change; also triggers when the user asks to "use TDD", "write the test first", "TDD this feature", "test-drive this", or mentions "red-green-refactor".
---

# tdd

Proactive partner to [test-failure-triage](../test-failure-triage/SKILL.md) (which handles failures *reactively*). This skill applies before code is written, and it is the default: the user opts out, never in.

## Read the standards first

Before the first test, read `~/.claude/standards/CODING_STANDARDS.md` and every file it names for the task. They decide each test's layer, name, location, and shape. This skill decides only the order the work happens in.

## Iron Law

**NO PRODUCTION CODE WITHOUT ITS TEST WRITTEN FIRST.**

If you wrote production code first → delete it, write the test, then implement fresh from the test. "Keep the old code as reference" is the rationalization that breaks this.

Violating the letter of this rule is violating the spirit.

Writing first doesn't mean running at every step: tests run once, when the feature is done (see One run at the end). A bug fix adds one red run before the fix.

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

Only behaviour worth guarding goes on the list. A test earns its place when a caller relies on the behaviour and a plausible change would break it:

| Keep a test for | Skip |
|---|---|
| a branch or decision, a parser, a business rule | message wording, log lines, formatting |
| money, security, auth, data writes | framework glue, pass-through and delegation |
| the boundaries a condition branches on | edge cases no branch in the code distinguishes |
| every bug fix (its regression test) | a second test of a path another test already covers |

Test each one at the cheapest layer that proves it: an error's variant in a unit test, never its text through a built binary.

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
- **Run under a plan** (the `dev-loop` implementer, a `writing-plans` task): the seams and layers the plan lists count as agreed. Write the list from them. If the plan lists no seams for a behaviour task, return `NEEDS_CONTEXT` rather than picking your own; a task marked `Seams: none — <why>` needs no test.

The list holds names, not tests. Tests are still written one at a time (see horizontal slicing, below), and the list grows as each slice teaches you something.

## Outside-in: start at the boundary

When a slice crosses a boundary, work in two loops:

1. **Outer:** write the test at the outermost seam first: end-to-end when the slice is a user journey the layer table sends there, integration otherwise.
2. **Inner:** drive the logic behind it with unit tests, one test → code → refactor slice each.
3. **Close:** the outer test is the one the end run must turn green. If it fails there, its failure names the missing unit.

A slice of pure logic runs only the inner loop.

## Test → code, one slice at a time

```
TEST ──▶ CODE ──▶ REFACTOR ──▶ next slice ──▶ … ──▶ feature done ──▶ RUN ONCE
                                                                       │
                                                             red? fix, re-run what failed
```

### 1. Write the test

One behaviour from the test list, at its agreed seam and layer. Name, place, and shape it as the standards' examples do. Real code, not mocks: double only the boundaries (see Test doubles in `~/.claude/standards/testing.md`).

### 2. Write the code

Smallest change that makes that test pass. No extra branches, no error paths the test doesn't exercise.

### 3. Refactor

Clean up while the slice is fresh. If the test has to change for the refactor, it was tied to the implementation, not behaviour: fix the test first, separately.

### 4. Next slice

Pick the next behaviour. Back to 1. Nothing runs between slices: a type-check that covers the test code (`cargo check --tests`, `tsc --noEmit`) is fine when it helps, a test run is not.

Work in **vertical slices**: one test → one implementation → repeat. Each test is a **tracer bullet** aimed by what writing the last slice's code taught you, not by a test run. Never write all the tests first (see horizontal slicing, below).

## One run at the end

When the feature is done, or most of it, run the tests it added or touched, once: the affected package or crate, not the whole suite. Whoever called this skill (`dev-loop`, a PR) runs the full suite before it ships.

- **Every new test is named in the output:** one that's missing never ran (a filter typo, a missing `#[test]`, a file the runner skips). Use the runner's verbose flag when it hides names (`go test -v`, `vitest --reporter=verbose`).
- **Red:** fix the code, or the test if the test was wrong, then re-run only what failed.
- **Green on the first run:** that test was never seen failing, so read it once. It must assert a value the code computes, never a constant or a mock of the unit (Shape of a test in `~/.claude/standards/testing.md`).

## Bug-fix variant — one red run

For a bug:
1. Write the regression test that reproduces the bug.
2. Run it → must FAIL with the bug present. This is the one red run the skill keeps: it proves the test catches the bug.
3. Apply the fix.
4. Run it → must PASS. This can be the end run.

If step 2 passes, the test isn't catching the bug. Tighten it.

## Anti-patterns

What makes a single test bad (coupled to the implementation, or tautological) lives under Shape of a test in `~/.claude/standards/testing.md`. The anti-patterns in the process itself:

- **Horizontal slicing**: writing all the tests first, then all the implementation. Bulk tests verify _imagined_ behavior: they test the _shape_ of things rather than what callers see, go insensitive to real changes, and lock in test structure before you understand the implementation. One slice at a time instead.
- **Running at every step**: a test run after each test, each change and each refactor. A compiled suite costs minutes per run, and the end run catches the same failures.

## Common rationalizations — reject these

| "Reason" to skip | Reality |
|---|---|
| "It's a tiny change" | If it has behaviour worth guarding (see the test list), test it. |
| "I'll add the test after" | You won't. And if you do, it'll be biased toward the code you wrote. |
| "There's nothing to test" | Then there's nothing to write. If there's behavior, there's a test. |
| "The framework guarantees this" | The framework guarantees its own behavior, not your usage. |
| "Testing this would require too much setup" | That's a design smell — the unit is too coupled. |
| "I'll keep my code as reference while writing the test" | Delete it. The test should drive the design. |

## Hard rules

- **Never** write production code before its test exists.
- **Never** run tests between slices. Run once when the feature is done; a bug fix adds its one red run.
- **Never** make a test pass by weakening the assertion. Tighten the code, not the test.
- **Never** declare a bug fix complete without seeing its regression test fail before the fix.
- **Never** test message wording, log lines or glue, or an error's text through a built binary.
- **Never** combine multiple behaviors in one test. One test, one behavior.
- **Never** mock what you're testing. Mock the boundary, not the unit.
- **Never** write a test at a new seam nobody agreed on, or before its layer is decided.
- **Never** compute a test's expected value the way the code computes it.
- **Never** write a batch of tests ahead of the code. One slice at a time.

---

Seams, horizontal and vertical slicing adapted from `tdd` in [mattpocock/skills](https://github.com/mattpocock/skills), Copyright (c) 2026 Matt Pocock, MIT License.
