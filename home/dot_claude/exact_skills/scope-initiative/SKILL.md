---
name: scope-initiative
description: Write or update a single per-feature roadmap initiative page at <repo>/docs/roadmap/<phase>-<n>-<slug>.md. The PM "ticket-creator" workhorse. Decomposition pre-check, propose-2-3-approaches when ambiguous, forcing-question gate, structured page format with TODOs alongside. Triggers when the user asks to "scope this feature", "write up this initiative", "add this to the roadmap", "create a roadmap page", "brainstorm this feature", or "draft a ticket for X".
---

# scope-initiative

Produces one initiative page. The page is the durable artifact the user (and reviewers) come back to. Most roadmap invocations land here — `phase-roadmap` rolls these up, but this is where the work gets defined.

## File location and naming

```
<repo>/docs/roadmap/<phase>-<n>-<slug>.md
```

- `<phase>` — phase number (0, 1, 2, …). Foundations are phase 0.
- `<n>` — index within phase (1, 2, 3, …). Choose the next available `n` by listing the phase's existing files.
- `<slug>` — kebab-case feature name. `schema-refactor`, `fts5`, `kobo-sync`.

Examples: `0-1-schema-refactor.md`, `1-3-library-views.md`, `4-1-kobo-sync.md`.

## Step 0 — scope check (before anything else)

**Every initiative goes through this skill, even "simple" ones.** "This is too small to need a page" is the rationalization where unexamined assumptions cause wasted work. The page can be short — a few sentences per section is fine — but it must exist and the user must approve it before implementation starts.

### Subsystem decomposition

If the user's request describes multiple independent subsystems, **stop and decompose first**. Don't write one initiative page that spans them.

A request is multi-subsystem when:
- It names 2+ user-facing features that don't share a primary code path (e.g. "search and audiobook player and Kobo sync").
- The success criteria for each piece are testable in isolation.
- Different reviewers would care about different pieces.

When decomposing, surface back to the user:
- The candidate sub-initiatives, named.
- Their dependency order (what must ship before what).
- Which one to start with.

Then run this skill once per sub-initiative — each gets its own `<phase>-<n>-<slug>.md`.

### Implementation path obvious?

If the implementation path is obvious (one well-known pattern, no real alternatives), proceed straight to Step 1.

If multiple defensible approaches exist, do **Step 0b** before the forcing-question gate:

#### Step 0b — propose 2–3 approaches

Present each candidate approach with:
- One-line description.
- Trade-offs (what it's good at, where it hurts).
- Effort estimate (S / M / L / XL).
- Your recommendation, with reasoning.

Get the user to pick one. The chosen approach informs §Technical considerations on the page. Do **not** silently pick — that's where roadmap drift starts.

If the user can't decide between approaches, that's the conversation to have *before* the page exists.

## Step 1 — answer the forcing-question gate

Before writing the page, answer all six. If the user can't answer one, that's the conversation to have **before** the page exists.

| Question | Required form of answer |
|---|---|
| **Demand reality** — Who needs this and how do you know? | A concrete user/scenario. Not "users want X." |
| **Status quo** — What do users do today without it? | Acknowledge the workaround (or "no workaround — they bounce"). |
| **Narrowest wedge** — Smallest version that delivers the core value? | Drives §Objective. |
| **Foundational dependency** — What MUST ship before this works? | Drives §Dependencies. |
| **6-month future** — Does it look right in 6 months, or is it next quarter's nightmare? | Surfaces in §Risks. |
| **Observation** — Once shipped, how do you know it worked? | Drives observability — must appear in §Technical considerations. |

If the user invokes this skill cold, ask the questions inline (use AskUserQuestion or just plain text) before writing the file.

## Step 2 — write the page

Page template (preserve heading order — `phase-roadmap` reads these by name):

```markdown
# F<phase>.<n> — <Title Case Summary>

**Phase <N> · <Theme>** · **Priority:** P<0–4>

<one-paragraph summary>

## Objective

<2–4 sentences — what this delivers, framed by the narrowest-wedge answer>

## User / business value

Unblocks:
- **<Other initiative>** ([F<x>.<y>](<x>-<y>-<slug>.md)) — <one-line why>.
- ...

(If this initiative doesn't unblock anything, write `Standalone — no downstream initiatives gated on this.` Don't pad.)

## Technical considerations

- <Concrete engineering decision 1>.
- <Concrete engineering decision 2>.
- **Observability:** <how we'll know this is working in prod — concrete signal>.

## Dependencies

- [F<x>.<y> <Title>](<x>-<y>-<slug>.md) must land first or concurrently.

(If none: `None.`)

## Risks

- <Specific risk> — <mitigation or "accepted">.

## Open questions

**Resolved:**

- **<Question>** — <decision> — <one-line rationale>.

**Unresolved:**

- **<Question>** — <who decides, by when>.

## TODOs

(Items use the standard format: What / Why / Context / Effort / Priority / Depends-on. Sort P0 first within this section.)

### <TODO title 1>

**What:** <one-line summary>.

**Why:** <concrete problem solved>.

**Context:** <enough detail for someone resuming this in 3 months>.

**Effort:** S | M | L | XL
**Priority:** P0 | P1 | P2 | P3 | P4
**Depends on:** <other TODO or initiative, or "None">.

## Status

<Queued | In progress | Landed>. <one-line detail — commit / PR / migration / "blocked on F0.2">.

---

[← Back to roadmap summary](0-0-summary.md)
```

## Step 3 — update the master roadmap

After writing or updating an initiative page, the master `0-0-summary.md` may need updating (initiative index, phasing table). If `phase-roadmap` is needed, mention it in the response — but do not auto-invoke it. The user picks when to roll up.

## Worked example reference

The user's [Omnibus repo](../../../Repos/omnibus/docs/roadmap/) is the reference implementation. Read [`0-1-schema-refactor.md`](../../../Repos/omnibus/docs/roadmap/0-1-schema-refactor.md) as the canonical per-page format if anything in the template is unclear.

## Hard rules

- **Never** skip Step 0. "This is too small to need a page" is the rationalization that costs the most rework.
- **Never** write one page that spans multiple subsystems. Decompose first.
- **Never** silently pick between defensible approaches. Surface the choice (Step 0b) and let the user decide.
- **Never** write the page before answering all six forcing questions.
- **Never** invent dependencies — every link in §Dependencies points to a real initiative file.
- **Never** combine §Open questions resolved/unresolved into one bullet list. Keep them separated.
- **Never** put TODOs in a separate root file. They live alongside the initiative they belong to.
- **Never** mark Status as "Landed" without a commit or PR reference.
