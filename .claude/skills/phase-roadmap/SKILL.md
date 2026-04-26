---
name: phase-roadmap
description: Produce or update the master roadmap doc at <repo>/docs/roadmap/0-0-summary.md - vision, executive summary, gap table, phasing table, initiative index. Reads the per-initiative pages produced by scope-initiative and rolls them up. Triggers when the user asks to "phase the roadmap", "update the roadmap summary", "re-sequence the phases", "produce the master roadmap", or "roll up the initiatives".
---

# phase-roadmap

Operates on the **set** of initiative pages, not on a single one. Run when initiatives have been added, dropped, or re-sequenced — or when the prior plan is going stale.

Pairs with [scope-initiative](../scope-initiative/SKILL.md) (which writes individual pages) and [retro-review](../retro-review/SKILL.md) (which feeds the executive summary).

## File location

```
<repo>/docs/roadmap/0-0-summary.md
```

Always `0-0-summary.md` — phase 0, position 0. Anchors the index.

## Inputs

1. **Existing initiative pages** — every `<phase>-<n>-<slug>.md` file in `<repo>/docs/roadmap/`. Read each one to extract title, phase, theme, priority, status, dependencies.
2. **Prior `0-0-summary.md`** if it exists — preserve "What v1 got right" facts unless they've actually changed.
3. **Most recent retro file** at `<repo>/docs/roadmap/retros/<YYYY-MM-DD>-retro.md` if present — its "recommended changes" feed §2 of the new summary.

## Output structure

Strictly this order:

```markdown
# <Project> Roadmap (v<N>)

<one-line "supersedes" pointer if v<N-1> exists>

---

## 1. Vision

<one paragraph — positioning vs comparable projects, what makes this version of the project right>

---

## 2. Executive summary

<2–4 paragraphs:
 - what the prior plan got right
 - what it got wrong
 - what changes in this version
 - top-line recommendation>

---

## 3. Current state assessment

### 3.1 What v<N-1> got right

- <bullet>
- <bullet>

### 3.2 Gaps

| # | Gap | Impact |
|---|---|---|
| G1 | <gap> | <impact> |
| G2 | <gap> | <impact> |
| ... | ... | ... |

### 3.3 Ambiguities & contradictions

- **<topic>** — <the open question or contradiction>.

### 3.4 Outdated / already-changed assumptions

- v<N-1> §X said "<claim>" — <what's actually true now>.

---

## 4. Phasing

```
Phase 0  Foundations              <one-line theme>
Phase 1  <theme>                  <one-line theme>
Phase 2  <theme>                  <one-line theme>
...
```

| Phase | Theme | v<N-1> features inside | New initiatives | Target horizon |
|---|---|---|---|---|
| 0 | Foundations | — | F0.1–F0.<n> | short-term |
| 1 | <Theme> | #4 <feat>, #5 <feat> | F1.1 <new>, F1.2 <new> | short-term |
| ... | ... | ... | ... | ... |

---

## 5. Initiative index

### Phase 0 — Foundations

- [F0.1 <Title>](0-1-<slug>.md)
- [F0.2 <Title>](0-2-<slug>.md)
- ...

### Phase 1 — <Theme>

- [F1.1 <Title>](1-1-<slug>.md)
- ...

### Phase <N> — <Theme>

- ...
```

## Quality bar

Apply across the whole doc — these are the gates a roadmap must pass to count as "objective":

| Directive | What it means in practice |
|---|---|
| **Zero silent failures** | Every initiative names how a failure becomes visible. If it can't, the initiative isn't ready. |
| **Every error has a name** | No "handle errors generically" anywhere. Reject phrasing like "robust error handling." |
| **Data flows have shadow paths** | Cross-initiative flows trace happy + nil + empty + upstream-error. |
| **Observability is scope** | Each phase has at least one observability initiative or annotation. |
| **Everything deferred is written down** | Every "we'll do that later" points to either a TODO inside an initiative page or a queued initiative. |
| **Optimize for 6 months** | If a phase ordering creates a future nightmare, say so explicitly in §3.3 or §3.4. |

## Phasing rules

- **Foundations first.** Phase 0 is anything most other initiatives depend on (schema, auth, migrations, search infra, worker primitive). If an initiative has 3+ downstream dependencies, it's a Phase 0 candidate.
- **Order by dependency, not by glamour.** A search feature that depends on FTS5 indexing can't ship before FTS5 ships, even if search is more visible.
- **Group by theme within a phase.** Phase 1 is "browse," Phase 2 is "reading," etc. — themes are how the user reads the roadmap.
- **Don't number across phases.** F2.1 is the first item in phase 2 even if phase 1 had F1.7.

## Worked example reference

The user's [Omnibus roadmap summary](../../../Repos/omnibus/docs/roadmap/0-0-summary.md) is the canonical example. Mirror that structure unless the user explicitly diverges.

## Hard rules

- **Never** invent initiatives. Every entry in §5 must correspond to a real `<phase>-<n>-<slug>.md` file.
- **Never** carry forward a "got right" bullet from the prior summary if it's no longer true. Update or remove.
- **Never** silently re-sequence a phase without surfacing the change in §2 (executive summary).
- **Never** declare an initiative "shipped" in §5 — status lives on the per-initiative page.
- **Never** skip §3.2 (gaps) — even a v1 has gaps; if you can't find any, you didn't look hard enough.
