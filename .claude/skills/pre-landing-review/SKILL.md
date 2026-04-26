---
name: pre-landing-review
description: Self-review the current branch's diff before pushing. Two-pass severity (CRITICAL then INFORMATIONAL), Fix-First Heuristic for auto-fix vs ask, language-aware checks. Triggers when the user says "review my branch", "review before pushing", "self-review", "pre-landing review", or "audit the diff".
---

# Pre-landing review

Run on `jj diff -r 'main..@'` (or `git diff origin/main` for git repos). Two passes — critical first, informational second. Auto-fix the mechanical stuff; batch ambiguous items into a single user question.

## Output format

```
Pre-landing review: N issues (X critical, Y informational)

AUTO-FIXED:
- [file:line] Problem → fix applied

NEEDS INPUT:
- [file:line] Problem
  Recommended fix: <suggested fix>
```

If clean: `Pre-landing review: no issues found.` No preamble, no "looks good overall."

## Pass 1 — CRITICAL

### SQL & data safety
- String interpolation in SQL — even on `.to_i`/`.to_f` values. Use parameterized queries (Rails: `sanitize_sql_array`/Arel; Node: prepared statements; Python: `?`/`%s` with params; sqlx: `query!` with bind params).
- TOCTOU races: check-then-set patterns that should be a single atomic `WHERE old = ? UPDATE`.
- Bypassing model validations for direct DB writes (Rails: `update_column`; Django: `QuerySet.update()`; Prisma: raw queries).
- N+1 queries: missing eager-load (Rails: `.includes()`; SQLAlchemy: `joinedload()`; Prisma: `include`; Diesel: explicit joins).

### Race conditions & concurrency
- Read-check-write without a uniqueness constraint or duplicate-key catch+retry.
- `find_or_create` without a unique index — concurrent calls can double-insert.
- Status transitions that are not atomic `WHERE old_status = ? UPDATE SET new_status` — concurrent updates can skip or double-apply.
- Unsafe HTML rendering on user-controlled data (Rails `.html_safe`/`raw`; React `dangerouslySetInnerHTML`; Vue `v-html`; Django `|safe`).

### LLM output trust boundary
- LLM-generated values (emails, URLs, names) written to DB or passed to mailers without format validation.
- LLM tool output (arrays, hashes) accepted without shape/type checks before persisting.
- LLM-generated URLs fetched without an allowlist — SSRF risk.
- LLM output stored in vector DBs / KBs without sanitization — stored prompt injection.

### Shell injection
- `subprocess.run/call/Popen` with `shell=True` AND f-string/`.format()` interpolation.
- `os.system()` with variable interpolation.
- `eval()`/`exec()` on LLM-generated code without sandboxing.
- Bash heredocs that interpolate user input.

### Enum & value completeness
When the diff adds a new enum value, status string, tier name, or type constant:
- **Trace it through every consumer.** Read (don't just grep — READ) each switch, filter, or display site. Common miss: added to the frontend dropdown but the backend persist/compute path doesn't handle it.
- **Check allowlists** — search for sibling values (e.g., adding `"revise"` → grep every `%w[quick lfg mega]` and verify "revise" is included where needed).
- **Check `match`/`case`/`if-elsif` chains** for wrong default fall-through.

This step requires reading code **outside** the diff. Use Grep to find sibling-value references, then Read each match.

## Pass 2 — INFORMATIONAL

### Async/sync mixing
- Sync `subprocess.run`, `open`, `requests.get` inside `async def` — blocks the event loop. Use `asyncio.to_thread`, `aiofiles`, `httpx.AsyncClient`.
- `time.sleep()` in async — use `asyncio.sleep`.
- Sync DB calls in async without `run_in_executor` wrapping.
- Rust: `.await` on a `Mutex` lock that should be `tokio::sync::Mutex`.

### Column / field name safety
- ORM query column names (`.select`, `.eq`, `.order`) verified against the actual schema — wrong names silently return empty results.
- `.get()` on query results uses a column that was actually selected.

### Type coercion at boundaries
- Values crossing Ruby↔JSON↔JS / Rust↔WASM↔JS where type drifts (numeric vs string).
- Hash/digest inputs missing `.to_s` normalization — `{cores: 8}` and `{cores: "8"}` produce different hashes.

### Time-window safety
- Date-key lookups assuming "today" covers 24h — an 8am PT report only sees midnight→8am under today's key.
- Mismatched windows: one feature uses hourly buckets, another uses daily keys for the same data.

### Completeness gaps
- Shortcuts where the complete version costs <30 minutes (partial enum handling, missing edge case mirroring the happy-path).
- Negative-path / edge-case tests missing when the happy-path test exists.
- Features at 80–90% when 100% is achievable with modest extra code.

### LLM prompt issues
- 0-indexed lists in prompts (LLMs reliably return 1-indexed).
- Tool capabilities mentioned in prompt that aren't actually wired up.
- Word/token limits stated in multiple places that could drift.

### View / frontend
- Inline `<style>` blocks in partials (re-parsed every render).
- O(n*m) lookups in views (`Array#find` in a loop instead of `index_by`).
- Ruby-side `.select{}` filtering that could be a `WHERE` clause.

### CI/CD
- Workflow changes: build tool versions match project requirements, artifact paths correct, secrets via `${{ secrets.X }}` not hardcoded.
- New artifact types have a publish/release workflow.
- Version-tag format consistency: `v1.2.3` vs `1.2.3` across VERSION, git tags, publish scripts.
- Publish step idempotency (re-runs don't fail).

## Fix-First Heuristic

Each finding is either AUTO-FIX (apply silently) or ASK (batch into one user question).

| AUTO-FIX | ASK |
|---|---|
| Dead code / unused vars | Security (auth, XSS, injection) |
| N+1 (add `.includes`) | Race conditions |
| Stale comments contradicting code | Design decisions |
| Magic numbers → named constants | Large fixes (>20 lines) |
| Missing LLM output validation | Enum completeness |
| Variables assigned but never read | Removing functionality |
| Inline styles, O(n*m) view lookups | Anything changing user-visible behavior |

Rule of thumb: if a senior engineer would apply it without discussion → AUTO-FIX. If reasonable engineers could disagree → ASK.

Critical findings default toward ASK (riskier). Informational findings default toward AUTO-FIX (more mechanical).

## Suppressions — do NOT flag

- "X is redundant with Y" when the redundancy aids readability (e.g., `present?` redundant with `length > 20`).
- "Add a comment explaining why this threshold/constant" — thresholds change during tuning, comments rot.
- Consistency-only changes (wrap value in conditional to match how another constant is guarded).
- "Regex doesn't handle edge case X" when X never occurs in practice.
- "Test exercises multiple guards simultaneously" — fine.
- Eval threshold changes — tuned empirically.
- Harmless no-ops (e.g., `.reject` on an element never in the array).
- **Anything already addressed in the same diff** — read the FULL diff before commenting.

## Hard rules

- **Read the full diff before flagging anything** — half the noise comes from flagging things the diff already fixes.
- **Never** dump every finding without classifying severity and AUTO-FIX vs ASK.
- **Never** leave AUTO-FIX items unfixed — apply them in the same pass.
- **Never** ask the user one question per finding — batch ambiguous items into a single AskUserQuestion.
