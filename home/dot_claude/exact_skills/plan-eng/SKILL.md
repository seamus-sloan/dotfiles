---
name: plan-eng
description: Pre-flight engineering design doc for non-trivial work. Output is a checked-in markdown file at <repo>/docs/design/<slug>.md covering data flow, storage shape, failure modes, rollback, observability, and open questions. Triggers when the user asks to "design this", "write a design doc", "plan the engineering", "scope the implementation", or starts a non-trivial change that spans multiple PRs.
---

# plan-eng

Produces a one-page design doc, not code. Output lives at `<repo>/docs/design/<slug>.md` so the design survives the session.

Use this when:
- The change spans multiple PRs.
- The change touches a new data flow, schema, or external dependency.
- Reviewers will reasonably ask "why this shape" and the answer isn't obvious from the diff.

Don't use this for typo fixes, dep bumps, or single-file changes — Claude Code's plan mode is enough.

## Where the doc lives

```
<repo>/docs/design/<slug>.md
```

Slug is kebab-case, ticket-prefixed when applicable: `ADA-120-login-flow.md`, `fts5-search.md`.

## Required sections

Every design doc has these sections — in this order, no reordering. If a section doesn't apply, write `N/A` with a one-line reason. Don't drop the heading.

### 1. Context
- What problem does this solve? (1–3 sentences.)
- Link to the roadmap initiative this delivers (per `scope-initiative` skill: `<phase>-<n>-<slug>.md`).
- What's NOT in scope (kills feature creep).

### 2. Data flow
**Diagrams are mandatory.** ASCII art for every new flow.

```
client ──HTTP──▶ /api/login ──▶ AuthService.verify()
                                  │
                                  ├─ session table (INSERT)
                                  └─ events queue (publish)
```

For every flow, trace the **shadow paths** as well as the happy path:
- nil/None input
- empty/zero-length input
- upstream call returns an error
- upstream call times out

If you can't trace one of these, the data flow isn't done.

### 3. Storage shape
- Table layouts (columns + types + constraints).
- Indices (which columns, why).
- Query patterns (the 2–3 hottest queries this serves).
- Migration shape: forward + reverse.
- `COLLATE NOCASE` / case-folding decisions for searchable strings.

### 4. Failure modes
For each thing that can go wrong:

| Failure | Cause | Detection | Recovery | User sees |
|---|---|---|---|---|
| `AuthFailed` | Wrong password | Counter on session table | Lockout after 5 | "Password incorrect" |
| `DBUnavailable` | Pool exhausted | Health check + alert | Retry w/ backoff | 503 page |

No "handle errors generically." Every failure has a name, a detection, a recovery, and a user-visible behavior.

### 5. Rollback plan
- What's the undo if this ships and goes wrong?
- Are migrations reversible? If not, what's the data-recovery story?
- Feature flag? Killswitch? Revert-by-redeploy?
- If rollback is impossible, say so explicitly — that's a design decision, not an oversight.

### 6. Observability
- Logs: what gets logged, at what level, with what fields.
- Metrics: what's counted, what's timed, what's gauged.
- Alerts: which metric thresholds page someone, and who.
- Dashboards: which existing dashboard gets a new panel; if a new dashboard is needed, who builds it.

Observability is **scope**, not "we'll add it later."

### 7. Open questions
Two sub-sections:

**Resolved** — decisions made during this design pass, with one-line rationale each:
- *Cover storage* → filesystem at `$OMNIBUS_COVERS_DIR/<uuid>.<ext>` because DB is a cache.

**Unresolved** — decisions deferred, with who decides and by when:
- *Pagination size* → benchmark before launch; default 50 until then.

Don't bury unresolved questions inside other sections — they hide there.

### 8. Test plan
- Happy-path test (one).
- Each failure mode from §4 → one negative test.
- Integration test exercising at least one full data-flow path from §2.
- What's NOT tested and why.

## Quality bar

Apply across the whole doc:

- **Zero silent failures.** Every failure mode is visible — to the system, the team, or the user.
- **Every error has a name.** `RateLimited`, `SessionExpired`, `DBUnavailable` — not "an error."
- **Data flows have shadow paths.** Happy + nil + empty + upstream-error.
- **Diagrams are mandatory.** Non-trivial flows get ASCII art.
- **Optimize for 6 months.** If this solves today and creates a problem next quarter, say so.

## Verification

Before declaring the design doc done, check:

- [ ] All 8 sections present.
- [ ] Every flow in §2 has a diagram and traces all 4 shadow paths.
- [ ] §4 has at least one failure per data flow in §2.
- [ ] §5 explicitly says "rollback impossible" if rollback is impossible.
- [ ] §7 separates resolved from unresolved.

## Hard rules

- **Never** skip a section. Write `N/A — <reason>` instead.
- **Never** write the doc after the code. The doc shapes the code, not the other way round.
- **Never** bury an unresolved question inside another section. It hides.
- **Never** treat observability as a follow-up PR. Either it's in scope or the design isn't done.
