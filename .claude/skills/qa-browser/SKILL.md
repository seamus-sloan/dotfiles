---
name: qa-browser
description: Test → Fix → Verify loop against a running web app using Claude in Chrome MCP. Smoke + golden paths + edge cases + regressions, with atomic jj commits per fix and a markdown report. Triggers when the user asks to "QA the app", "qa-browser", "smoke-test the running app", "test the staging build", "run the QA suite", or "verify the feature in the browser".
---

# qa-browser

Drive a running web app through realistic flows. Find bugs, fix them, re-verify, commit. Output a structured report.

## Runtime

Uses the `mcp__Claude_in_Chrome__*` MCP tools (no separate browse server needed). Make sure they're loaded before starting:

```
ToolSearch query: "select:mcp__Claude_in_Chrome__navigate,mcp__Claude_in_Chrome__computer,mcp__Claude_in_Chrome__find,mcp__Claude_in_Chrome__form_input,mcp__Claude_in_Chrome__get_page_text,mcp__Claude_in_Chrome__read_page,mcp__Claude_in_Chrome__read_console_messages,mcp__Claude_in_Chrome__read_network_requests,mcp__Claude_in_Chrome__tabs_create_mcp,mcp__Claude_in_Chrome__tabs_close_mcp"
```

Fallback: if Claude in Chrome isn't connected (`mcp__Claude_in_Chrome__list_connected_browsers` returns empty), use `mcp__Claude_Preview__preview_*` instead — it spins up a disposable Chromium for the session.

## Setup

### 1. Resolve target URL

In order of preference:

1. The user named one in their request.
2. The repo's `CLAUDE.md` declares a dev URL (e.g. `http://127.0.0.1:3000`).
3. A dev server is running — detect via `lsof -i :3000 -i :8080 -i :5173 -i :4321 -i :8000` (common ports).
4. Ask via AskUserQuestion.

### 2. Tier select

The tier determines which severity gets fixed automatically.

| Tier | Auto-fixes | Reports only |
|---|---|---|
| **Quick** | Critical, High | Medium, Low |
| **Standard** (default) | Critical, High, Medium | Low |
| **Exhaustive** | Critical, High, Medium, Low | Cosmetic-only |

If the user didn't specify, default to Standard.

### 3. Working tree must be clean

```bash
jj st
```

If the working tree is dirty, ask: **commit current changes**, **stash**, or **abort**. Each fix needs to be its own atomic change, so a dirty tree blocks.

### 4. Output dir

```bash
mkdir -p <repo>/docs/qa/screenshots
```

## Phase 1 — Smoke (always runs)

The cheapest checks. If any of these fail the rest is meaningless.

- Landing page loads (HTTP 200, no `mcp__Claude_in_Chrome__read_console_messages` errors).
- Primary nav renders — at least one identifiable nav element via `mcp__Claude_in_Chrome__find`.
- No 4xx/5xx in `mcp__Claude_in_Chrome__read_network_requests` for the landing-page load.
- Screenshot the landing page → `<repo>/docs/qa/screenshots/initial.png`.

If smoke fails: stop. File a critical issue, report, exit. The app isn't testable.

## Phase 2 — Golden paths

Infer the user-facing happy paths from the diff (`jj diff -r 'main..@'`) and the recently-changed files. For each:

1. Plan the steps (what does a real user do?).
2. Execute via `mcp__Claude_in_Chrome__computer` / `find` / `form_input`.
3. After each step: screenshot, read console, read network. Capture any error.
4. Verify the success criterion (DOM state, URL change, text content).

If you don't know the golden path, ask. Don't guess at workflows.

## Phase 3 — Edge cases

For each golden path, exercise:

- **Empty input** — submit forms with no values.
- **Stale state** — interact, navigate away mid-action, come back.
- **Slow connection** — throttle via `mcp__Claude_in_Chrome__network` if available.
- **Double-click** — click submit twice rapidly.
- **Back button** — submit, go back, observe state.
- **Keyboard nav** — Tab through, Enter to submit (basic a11y).

## Phase 4 — Regressions

If `<repo>/docs/qa/baseline.json` exists, re-run the recorded scenarios from the prior baseline. New failures vs the baseline are regressions and rank above edge-case findings.

If no baseline exists, save the current passing scenarios as the new baseline at the end of the run.

## Found a bug — fix flow

For each bug at or above the tier's auto-fix threshold:

1. Investigate root cause via the [investigate](../investigate/SKILL.md) skill — Iron Law applies.
2. Fix in source.
3. Re-run the scenario that found it. Confirm pass.
4. `jj describe -m "fix: <one-line>"` and `jj bookmark move <branch> --to @` per [jj-basics](../jj-basics/SKILL.md). Each fix is its own atomic change.
5. Capture a before/after screenshot pair: `issue-<NNN>-before.png` / `issue-<NNN>-after.png`.

Below the threshold (e.g. Low severity in Quick tier): record only, don't fix.

## Severity rubric

| Severity | Examples |
|---|---|
| **Critical** | Crash, data loss, security hole, can't load app |
| **High** | Golden path broken, auth fails, payment fails |
| **Medium** | Edge case broken, console errors, layout broken on a primary screen |
| **Low** | Cosmetic, copy issue, focus state missing, console warning |

## Report format

```
<repo>/docs/qa/qa-report-<YYYY-MM-DD>.md
```

```markdown
# QA report — <YYYY-MM-DD>

**Target:** <URL> · **Tier:** <Quick/Standard/Exhaustive>
**Branch:** <bookmark> · **PRs in window:** <count>

## Summary

- Smoke: <pass/fail>
- Golden paths tested: <N> · pass: <N> · fail: <N>
- Edge cases tested: <N> · pass: <N> · fail: <N>
- Regressions found: <N>
- Fixed in this run: <N> · Reported only: <N>

## Issues

### #001 — <one-line title> [<severity>]

**Scenario:** <steps to reproduce>
**Expected:** <what should happen>
**Actual:** <what happened>
**Evidence:** ![](screenshots/issue-001-step-1.png)
**Status:** Fixed in <commit-sha> | Reported (out of tier)
**Before/after:** ![](screenshots/issue-001-before.png) ![](screenshots/issue-001-after.png)

### #002 — ...
```

If no issues: `## Issues\n\nNone found at <tier> tier.`

## Output structure

```
<repo>/docs/qa/
├── qa-report-<YYYY-MM-DD>.md
├── baseline.json                       # for next regression pass
└── screenshots/
    ├── initial.png
    ├── issue-001-step-1.png
    ├── issue-001-before.png
    ├── issue-001-after.png
    └── ...
```

## Hard rules

- **Never** start QA on a dirty working tree without commit/stash/abort confirmation.
- **Never** declare smoke pass while console has errors — those count.
- **Never** fix a bug below the tier's auto-fix threshold. Record and move on.
- **Never** combine multiple fixes into one commit. One bug → one atomic change.
- **Never** invent a scenario. If the golden path isn't clear from the diff or the user's request, ask.
- **Never** skip Phase 4 if a baseline exists. Regressions matter more than new edge cases.
