---
name: investigate
description: Root-cause-first debugging discipline. Iron Law - no fixes without root cause investigation first. Triggers when the user says "investigate", "debug this", "find the root cause", "why is X failing", "this bug is back", or asks for help diagnosing a failure.
---

# Investigate

Apply mechanically. The point is to stop fixing symptoms.

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.** Patching the symptom creates whack-a-mole debugging — the same bug surfaces again in a different place a week later. Find the root cause, then fix it.

## The 4-phase process

| Phase | Goal | Output |
|---|---|---|
| 1. Investigate | Collect symptoms, trace code paths, check recent changes (`jj log -r 'main..@'`), reproduce deterministically | A specific, testable hypothesis |
| 2. Pattern match | Recognize common signatures: race conditions, nil propagation, state corruption, stale caches, config drift, integration failures | Refined hypothesis or candidate list |
| 3. Test | Confirm with temporary logging or assertions. If wrong, gather more evidence — do **not** guess | Confirmed root cause |
| 4. Fix | Patch the root cause. Write a regression test that fails without the fix and passes with it. Run the full suite | Verified fix + test |

Do not skip ahead. If you cannot articulate the root cause in one sentence, you are still in Phase 1 or 2.

## The 3-strike rule

If three hypotheses fail without explaining the bug, **stop**. Surface back to the user with:

- The three hypotheses tried and why each failed.
- What evidence is still missing.
- Three options: keep investigating with a new angle, add observability and wait, or escalate.

The user picks. Do not silently keep guessing past strike three.

## Scope lock

Once you have a hypothesis, lock edits to the affected module. Cross-module changes need a separate justification.

If the fix touches more than **5 files**, stop and check with the user before continuing. Surface:

- The files you'd touch and why.
- Whether the bug is at the wrong layer (large blast radius often means the symptom is downstream of the real cause).
- Whether to split the work into staged changes.

## Red flags — slow down

| Signal | What it means |
|---|---|
| "Quick fix for now" | There is no "for now." Either fix it right or escalate. |
| Proposing a fix before tracing the data flow | You're guessing. Go back to Phase 1. |
| Each fix uncovers a new failure elsewhere | Wrong layer. The real cause is upstream. |
| The fix has to special-case one input | The data model or contract is broken — fix that, not the call site. |
| "It works on my machine" | Reproduce deterministically before going further. |

## Output report

When done, produce a short structured report:

```
Symptom:    <one line — what the user observed>
Root cause: <one line — the actual fault>
Fix:        <files touched + 1-line summary>
Test:       <regression test path + name>
Verified:   <command that proves the fix + result>
```

If you bailed out at strike three, replace `Fix`/`Test`/`Verified` with `Status: blocked — awaiting <decision>`.

## Hard rules

- **Never** apply a fix while the root cause is still a guess. State the hypothesis first.
- **Never** skip the regression test. The test is the proof the fix works and the trip-wire if the bug returns.
- **Never** silently expand scope past one module without a check-in.
- **Never** declare success without re-running the original failing scenario.
