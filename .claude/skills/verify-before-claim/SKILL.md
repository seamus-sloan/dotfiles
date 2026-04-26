---
name: verify-before-claim
description: Gate before any completion claim. Iron Law - no claims of done/passing/fixed without fresh verification evidence in the same message. Triggers automatically before saying "done", "fixed", "passing", "complete" - or when the user asks to verify before declaring complete.
---

# verify-before-claim

A discipline gate, not a workflow. Fires every time the model is about to claim something works.

## Iron Law

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

If you haven't run the verification command **in this message**, you cannot claim it passes. A previous run does not count. Confidence does not count. "Should work" does not count.

## The gate

Before saying any of these:
- "done" / "complete" / "fixed" / "passing" / "ready"
- "should work" / "looks good" / "all green"
- expressions of satisfaction ("Great!", "Perfect!")

Run this gate:

```
1. IDENTIFY  — what command proves the claim?
2. RUN       — execute the FULL command, fresh, this turn
3. READ      — full output, exit code, count of failures
4. VERIFY    — does the output actually confirm the claim?
                NO  → state actual status with evidence
                YES → state claim WITH evidence
5. ONLY THEN — make the claim
```

Skip any step → that's lying, not verifying.

## Claim → required evidence

| Claim | Required | Not sufficient |
|---|---|---|
| Tests pass | Test command output: 0 failures, exit 0 | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors, exit 0 | Partial run, file-level check |
| Build succeeds | Build command: exit 0 | Linter passing (linter ≠ compiler) |
| Type-check clean | `tsc --noEmit` / `cargo check` exit 0 | Linter pass |
| Bug fixed | Regression test: revert fix → fails → re-apply → passes | Code changed, "assumed fixed" |
| Regression test works | Red-green cycle verified (revert → fails) | Test passes once |
| Subagent done | VCS diff shows the changes | Agent reports "success" |
| Requirements met | Line-by-line checklist against the spec | Tests passing |
| Hook fires | Sentinel file exists / observable side effect | "I added it to settings.json" |

## Red flags — STOP

If you catch yourself doing any of these, run the gate before continuing:

- Using "should", "probably", "seems to", "I think" near a status claim.
- Expressing satisfaction ("", "Done!", "Perfect!") before running the command.
- About to commit / push / open PR without a fresh test run.
- Trusting a subagent's success report without checking the diff.
- Relying on a partial verification ("the unit tests pass" — what about integration?).
- Thinking "just this once."
- Tired and wanting the work over.

**Any wording implying success without having run the verification this turn is a violation.**

## Rationalization table

| Excuse | Reality |
|---|---|
| "Should work now" | Run the verification. |
| "I'm confident" | Confidence ≠ evidence. |
| "Just this once" | No exceptions. |
| "Linter passed" | Linter ≠ compiler. |
| "Subagent said success" | Verify independently — read the diff. |
| "I'm tired" | Exhaustion ≠ excuse. |
| "Partial check is enough" | Partial proves nothing about the rest. |
| "Different words so the rule doesn't apply" | Spirit over letter. |

## Common patterns

**Tests:**
- ✅ `cargo test` → exit 0, 34/34 pass → "All tests pass."
- ❌ "Should pass now" / "Looks correct."

**Bug-fix regression test:**
- ✅ Write test → run (passes) → revert fix → run (must FAIL) → restore → run (passes) → "Regression test verified."
- ❌ "I've added a regression test." (without the revert-and-fail step)

**Build:**
- ✅ `cargo build` → exit 0 → "Build succeeds."
- ❌ "Linter passed." (linter doesn't compile)

**Subagent delegation:**
- ✅ Subagent reports done → check `jj diff` → confirm changes match the request → "Subagent's changes verified at <revid>."
- ❌ Trust subagent report.

**Requirements (multi-step plan):**
- ✅ Re-read plan → checklist each step against the diff/output → report gaps or completion.
- ❌ "Tests pass — plan complete." (tests passing ≠ plan completed)

## Composition with other skills

- After `tdd` → verify the green run before declaring the test passes.
- After `investigate` → verify the regression test fails-without-fix and passes-with-fix.
- After `pre-landing-review` → verify each AUTO-FIX actually applied before the report.
- Before `open-pr` → verify the test suite passes on `@`.
- Before `phase-roadmap` → verify the per-initiative pages it claims to roll up actually exist.

## Hard rules

- **Never** claim a status without the fresh evidence in this turn.
- **Never** treat a subagent's success report as evidence — read the diff.
- **Never** rely on partial verification when full verification is feasible.
- **Never** skip the gate because "the change is small" — small changes break things constantly.
- **Never** rephrase a claim ("looks correct" instead of "passes") to avoid the gate. Spirit > letter.
