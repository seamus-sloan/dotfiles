---
name: retro-review
description: Backward-pass over the last N weeks of merged PRs to classify each roadmap initiative as Shipped/Slipped/Cut/New, capture lessons, and recommend changes for the next phase-roadmap update. Output goes to <repo>/docs/roadmap/retros/<YYYY-MM-DD>-retro.md. Triggers when the user asks for a "retro", "roadmap retro", "what shipped", "look back at the last sprint", or "what changed since the last roadmap".
---

# retro-review

Closes the loop. `scope-initiative` writes pages, `phase-roadmap` rolls them up, this skill looks back at what actually happened so the next `phase-roadmap` pass can be honest.

## When to run

- Before every `phase-roadmap` update.
- Periodically (default cadence: every 30 days, configurable).
- Before any milestone where the user wants to communicate progress externally.

## Inputs

1. **Window**: last N days of merged PRs. Default `30`. Override via the user's request ("last 14 days", "since v0.3").
2. **Initiative pages**: every `<phase>-<n>-<slug>.md` under `<repo>/docs/roadmap/`.
3. **Merged PRs**: `gh pr list --state merged --search "merged:>=$(date -v-30d +%Y-%m-%d)"` (or appropriate platform CLI).
4. **Most recent prior retro** at `<repo>/docs/roadmap/retros/<YYYY-MM-DD>-retro.md` if present — for delta against last pass.

## File location

```
<repo>/docs/roadmap/retros/<YYYY-MM-DD>-retro.md
```

Date is the day the retro is run. Multiple retros land in the same `retros/` directory.

## Step 1 — collect merged PRs

```bash
WINDOW_DAYS="${1:-30}"
gh pr list --state merged \
  --search "merged:>=$(date -v-${WINDOW_DAYS}d +%Y-%m-%d 2>/dev/null || date -d "-${WINDOW_DAYS} days" +%Y-%m-%d)" \
  --json number,title,mergedAt,labels,body --limit 200
```

For each PR, identify which initiative (if any) it belongs to:
- Branch name like `<TICKET>/<slug>` → match `<TICKET>` against initiative IDs (F0.1, F1.3, etc.) or against initiative titles.
- PR title or body mentioning an initiative ID.
- Files-changed hints (e.g. PRs touching `db/migrations/` likely belong to schema/migrations initiatives).

Don't guess — if no initiative is identifiable, classify the PR as "out-of-plan" (see §New below).

## Step 2 — classify each initiative

For every initiative in `<repo>/docs/roadmap/`, pick exactly one bucket:

| Bucket | Heuristic |
|---|---|
| **Shipped** | Status on the page is "Landed" AND merged PRs in window cover the work. |
| **In-progress** | Status is "In progress" with at least one merged PR in window. |
| **Slipped** | Was queued for this window per prior roadmap; no PRs landed; status unchanged. |
| **Cut** | Marked deferred or removed since prior retro. |
| **New** | Initiative file exists now but didn't in the prior retro / wasn't in the prior roadmap. |

Out-of-plan PRs (no initiative match) get their own section — they're a signal that either (a) the roadmap missed something or (b) work is happening that shouldn't.

## Step 3 — capture lessons

For each Slipped, Cut, or New initiative, ask:
- **What assumption broke?** (e.g. "F0.4 FTS5 turned out to depend on F0.1 schema refactor — wasn't visible at planning time.")
- **What surprised us?** (e.g. "Cover storage migration was 3× the estimated effort because of MIME inference.")

Brief — one bullet each. Don't editorialize.

## Step 4 — produce the retro file

```markdown
# Roadmap retro — <YYYY-MM-DD>

**Window:** last <N> days · <YYYY-MM-DD> → <YYYY-MM-DD>
**PRs merged:** <count>
**Prior retro:** [<YYYY-MM-DD>](<YYYY-MM-DD>-retro.md) | _no prior retro_

---

## 1. Status delta

| Initiative | Prior status | Current status | Bucket |
|---|---|---|---|
| F0.1 Schema refactor | Queued | Landed | **Shipped** |
| F0.4 FTS5 | Queued | Queued | **Slipped** |
| F1.3 Library views | — | In progress | **New** |
| ... | ... | ... | ... |

## 2. Lessons learned

- **F0.4 Slipped** — depended on F0.1 schema refactor; not visible at planning time. *Implication: foundation initiatives need explicit downstream-blocking analysis in `phase-roadmap`.*
- **F1.2 Thumbnails surprise** — sidecar `cover.jpg` was a 2-week detour. *Implication: filesystem conventions belong in F0, not F1.*

## 3. Out-of-plan work

PRs merged this window that don't map to any initiative:

- **#142 Refactor settings module** — janitorial. *Should this become an initiative or stay janitorial?*
- ...

## 4. Recommended changes for next phase-roadmap

Concrete, actionable. Each item is a directive `phase-roadmap` can apply.

- **Promote F2.1 Progress sync to Phase 1** — turned out to be a hard dependency for F1.3 Library views.
- **Cut F4.3 Kindle native sync** — Amazon's epub direct upload removes the need.
- **Add F0.7 Library filesystem conventions** — captured from Slipped+New analysis above.

---

[← Back to roadmap summary](../0-0-summary.md)
```

## Step 5 — update prior-initiative status

For each Shipped initiative, the per-initiative page's `## Status` section should match. If it doesn't, surface the discrepancy back to the user — don't silently rewrite the initiative page; that's `scope-initiative`'s job.

## Hard rules

- **Never** classify an initiative as Shipped without at least one merged PR in window covering it.
- **Never** invent merged PRs. If `gh` can't find them, neither can the retro.
- **Never** combine §Lessons with §Recommended changes. Lessons are observations; changes are directives.
- **Never** silently rewrite an initiative page from this skill — surface drift, let `scope-initiative` reconcile.
- **Never** skip §3 Out-of-plan work. Out-of-plan work is the most useful signal for the next planning pass.
