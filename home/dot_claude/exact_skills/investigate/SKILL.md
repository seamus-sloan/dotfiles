---
name: investigate
description: Root-cause-first debugging discipline for hard bugs and performance regressions. Iron Law - no fix without a feedback loop that goes red on the bug and a confirmed root cause. Triggers when the user says "investigate", "debug this", "diagnose", "find the root cause", "why is X failing", "this bug is back", or reports something broken, throwing, failing, or slow.
---

# Investigate

Apply mechanically. The point is to stop fixing symptoms.

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.** Patching the symptom creates whack-a-mole debugging — the same bug surfaces again in a different place a week later. Find the root cause, then fix it. And no root-cause theory before a loop exists that goes **red** on this bug: a theory built by reading code is a guess.

## Redact

This skill has you show commands, outputs and captured artifacts. **Redact every secret first**: write `<REDACTED>` in its place. Build loops against env vars, so the credential stays in the environment rather than in what you show. Captured artifacts carry auth headers: quote only the lines that carry the signal.

If the redacted output is not enough to diagnose the bug, say so and ask the user.

## Phase 1: Build a feedback loop

**This is the skill.** Everything else is mechanical. If you have a **tight** pass/fail signal for the bug (one that goes red on _this_ bug), you will find the cause; bisection, hypothesis-testing, and instrumentation all just consume it. If you don't have one, no amount of staring at code will save you.

Spend disproportionate effort here. **Be aggressive. Be creative. Refuse to give up.**

### Ways to construct one, in roughly this order

1. **Failing test** at whatever seam reaches the bug: unit, integration, e2e.
2. **Curl / HTTP script** against a running dev server.
3. **CLI invocation** with a fixture input, diffing stdout against a known-good snapshot.
4. **Headless browser script** (Playwright / Puppeteer) that drives the UI and asserts on DOM/console/network.
5. **Replay a captured trace.** Save a real network request / payload / event log to disk; replay it through the code path in isolation.
6. **Throwaway harness.** Spin up a minimal subset of the system (one service, mocked deps) that exercises the bug code path with a single function call.
7. **Property / fuzz loop.** If the bug is "sometimes wrong output", run 1000 random inputs and look for the failure mode.
8. **Bisection harness.** If the bug appeared between two known states (commit, dataset, version), automate "boot at state X, check, repeat" so you can `git bisect run` it.
9. **Differential loop.** Run the same input through old-version vs new-version (or two configs) and diff outputs.
10. **HITL bash script.** Last resort. If a human must click, drive _them_ with [`scripts/hitl-loop.template.sh`](scripts/hitl-loop.template.sh) so the loop is still structured. Captured output feeds back to you.

### Tighten the loop

Treat the loop as a product. Once you have _a_ loop, **tighten** it:

- Can I make it faster? (Cache setup, skip unrelated init, narrow the test scope.)
- Can I make the signal sharper? (Assert on the specific symptom, not "didn't crash".)
- Can I make it more deterministic? (Pin time, seed RNG, isolate filesystem, freeze network.)

A 30-second flaky loop is barely better than no loop; a 2-second deterministic one is tight, a debugging superpower.

### Non-deterministic bugs

The goal is not a clean repro but a **higher reproduction rate**. Loop the trigger 100×, parallelise, add stress, narrow timing windows, inject sleeps. A 50%-flake bug is debuggable; 1% is not, so keep raising the rate until it's debuggable.

### When you genuinely cannot build a loop

Stop and say so explicitly. List what you tried. Ask the user for: (a) access to whatever environment reproduces it, (b) a redacted captured artifact (HAR file, log dump, core dump, screen recording with timestamps), or (c) permission to add temporary production instrumentation. Do **not** proceed to hypothesise without a loop.

### Done when: a tight loop that goes red

You can name **one command** (a script path, a test invocation, a curl) that you have **already run at least once** (show the invocation and its output, redacted), and that is:

- [ ] **Red-capable**: it drives the actual bug code path and asserts the **user's exact symptom**, so it can go red on this bug and green once fixed. Not "runs without erroring"; it must be able to _catch this specific bug_.
- [ ] **Deterministic**: same verdict every run (flaky bugs: a pinned, high reproduction rate, per above).
- [ ] **Fast**: seconds, not minutes.
- [ ] **Agent-runnable**: you can run it unattended; a human in the loop only via the HITL template.

If you catch yourself reading code to build a theory before this command exists, **stop: jumping straight to a hypothesis is the exact failure this skill prevents.** No red-capable command, no Phase 2.

## Phase 2: Reproduce + minimise

Run the loop. Watch it go red as the bug appears. Confirm:

- [ ] The loop produces the failure mode the **user** described, not a different failure that happens to be nearby. Wrong bug = wrong fix.
- [ ] The failure is reproducible across multiple runs (or, for non-deterministic bugs, reproducible at a high enough rate to debug against).
- [ ] You have captured the exact symptom (error message, wrong output, slow timing) so later phases can verify the fix actually addresses it.

Then shrink the repro to the **smallest scenario that still goes red**. Cut inputs, callers, config, data, and steps **one at a time**, re-running the loop after each cut, and keep only what's load-bearing for the failure. A minimal repro shrinks the hypothesis space in Phase 3 and becomes the clean regression test in Phase 5.

Done when **every remaining element is load-bearing**: removing any one of them makes the loop go green.

## Phase 3: Hypothesise

Generate **3–5 ranked hypotheses** before testing any of them. Single-hypothesis generation anchors on the first plausible idea. Feed the list from:

- Recent changes: `git log origin/main..HEAD`, and `git log -p` on the files the minimised repro still touches.
- Common signatures: race conditions, nil propagation, state corruption, stale caches, config drift, integration failures.

Each hypothesis must be **falsifiable**: state the prediction it makes.

> Format: "If <X> is the cause, then <changing Y> will make the bug disappear / <changing Z> will make it worse."

If you cannot state the prediction, the hypothesis is a vibe: discard or sharpen it.

**Show the ranked list to the user before testing.** They often have domain knowledge that re-ranks instantly ("we just deployed a change to #3"), or know hypotheses they've already ruled out. Don't block on it; proceed with your ranking if the user is AFK.

### The 3-strike rule

If three hypotheses are falsified without explaining the bug, **stop**. Surface back to the user with:

- The three hypotheses tried and why each failed.
- What evidence is still missing.
- Three options: keep investigating with a new angle, add observability and wait, or escalate.

The user picks. Do not silently keep guessing past strike three.

## Phase 4: Instrument

Each probe must map to a specific prediction from Phase 3. **Change one variable at a time.**

Tool preference:

1. **Debugger / REPL inspection** if the env supports it. One breakpoint beats ten logs.
2. **Targeted logs** at the boundaries that distinguish hypotheses.
3. Never "log everything and grep".

**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup at the end becomes a single grep. Untagged logs survive; tagged logs die.

**Perf branch.** For performance regressions, logs are usually wrong. Instead: establish a baseline measurement (timing harness, `performance.now()`, profiler, query plan), then bisect. Measure first, fix second.

Done when one hypothesis is confirmed and you can state the root cause in one sentence.

## Phase 5: Fix + regression test

### Scope lock

Lock edits to the module the root cause lives in. Cross-module changes need a separate justification.

If the fix touches more than **5 files**, stop and check with the user before continuing. Surface:

- The files you'd touch and why.
- Whether the bug is at the wrong layer (large blast radius often means the symptom is downstream of the real cause).
- Whether to split the work into staged changes.

### Regression test

Write the regression test **before the fix**, at a **correct seam**: one where the test exercises the **real bug pattern** as it occurs at the call site. A seam that is too shallow (a single-caller test when the bug needs multiple callers, a unit test that can't replicate the chain that triggered the bug) gives false confidence.

1. Turn the minimised repro into a failing test at that seam.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Revert the fix locally and watch it fail again, then re-apply (the [tdd](../tdd/SKILL.md) bug-fix variant: proof the test catches this bug).
6. Re-run the Phase 1 loop against the original (un-minimised) scenario, then the full suite.

**When it can't be tested programmatically** (no correct seam exists, or the behaviour can only be observed by a human), don't write a test that gives false confidence. Raise it with the user as soon as you hit it, in that message, not only in the final report: what can't be tested, why, and what would make it testable (often an architecture change: the missing seam is itself the finding). The report then says `Test: none, because <reason>`.

## Phase 6: Cleanup

Required before declaring done:

- [ ] Original repro no longer reproduces (re-run the Phase 1 loop)
- [ ] Regression test passes, or `none, because <reason>` was raised with the user
- [ ] All `[DEBUG-...]` instrumentation removed (`grep` the prefix)
- [ ] Throwaway harnesses and prototypes deleted (or moved to a clearly-marked debug location)
- [ ] The hypothesis that turned out correct is stated in the commit / PR message, so the next debugger learns

## Red flags — slow down

| Signal | What it means |
|---|---|
| Reading code to build a theory before the loop exists | You're guessing. Go back to Phase 1. |
| "Quick fix for now" | There is no "for now." Either fix it right or escalate. |
| Each fix uncovers a new failure elsewhere | Wrong layer. The real cause is upstream. |
| The fix has to special-case one input | The data model or contract is broken — fix that, not the call site. |
| "It works on my machine" | Your loop isn't driving the real code path. Tighten it until it goes red. |

## Output report

When done, produce a short structured report:

```
Symptom:    <one line — what the user observed>
Loop:       <the Phase 1 command>
Root cause: <one line — the actual fault>
Fix:        <files touched + 1-line summary>
Test:       <regression test path + name | none, because <reason>>
Verified:   <command that proves the fix + result>
```

If you bailed out at strike three, replace `Fix`/`Test`/`Verified` with `Status: blocked — awaiting <decision>`.

## Hard rules

- **Never** hypothesise before a red-capable loop exists, and never apply a fix while the root cause is still a guess.
- **Never** skip the regression test silently. `none, because <reason>` is only for what can't be tested programmatically, and it is raised with the user when it happens.
- **Never** silently expand scope past one module without a check-in.
- **Never** leave a `[DEBUG-...]` log behind.
- **Never** declare success without re-running the original failing scenario.

---

Phases 1–6 adapted from `diagnosing-bugs` in [mattpocock/skills](https://github.com/mattpocock/skills), Copyright (c) 2026 Matt Pocock, MIT License.
