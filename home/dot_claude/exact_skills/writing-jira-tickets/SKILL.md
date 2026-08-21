---
name: writing-jira-tickets
description: Drafts and creates Jira tickets in Seamus's house style, then files them via the Atlassian MCP — matching epic naming conventions, a context-first description with an Acceptance Criteria block, and a five-field intake (epic, story points, sprint, assignee, labels) taken from the prompt or gathered in a short interview. Use when asked to "create a ticket", "write a Jira ticket", "file this under <epic>", "add this to the <epic> epic", or to turn a bug/idea into a ticket.
user-invocable: true
argument-hint: "[what the ticket is for] [optional: epic, points, sprint, assignee, labels]"
---

# Writing Jira Tickets

## Core Task

Turn a feature idea, bug, or chunk of work into a well-formed Jira ticket that matches
Seamus's writing style, then create it in Jira via the Atlassian MCP under the correct
epic — with the right title format, a context-first description, an Acceptance Criteria
block, the five intake fields resolved, and **real Jira issue links** (never a text
"Related Tickets" line). The output is a created Jira issue (key + URL) ready for review.

## The Five Intake Fields

Every ticket needs these resolved before it is created. Take each from the invocation
prompt when it is there; ask for whatever is left in **one batched interview** (Step 5).

| # | Field | Allowed values | Blank means |
|---|-------|----------------|-------------|
| 1 | **Epic** | Issue key (`ADA-123`), epic name to search for, or a project/space to search within | **Not allowed** — must resolve to a real epic key |
| 2 | **Story Points** | A number from the project's scale (typically 1/2/3/5/8) | **Never blank** — hard gate, see Step 5 |
| 3 | **Sprint** | Current sprint, next sprint, or blank | Backlog (field omitted) |
| 4 | **Assignee** | Seamus, another user (name/email), or blank | Unassigned (field omitted) |
| 5 | **Labels** | Any text the user gives, one or more | No labels (field omitted) |

Sprint, assignee, and labels are legitimately blank-able — but **never assume blank from
silence**. If the prompt didn't mention them, they go in the interview.

## Usage

- `/writing-jira-tickets include the region in the export filename, under ADA-201, 3 points, current sprint, assign to me`
  — everything supplied; no interview, straight to drafting and filing.
- `/writing-jira-tickets dashboard chart renders empty when filters are cleared`
  — drafts the ticket, then interviews for all five fields.
- `/writing-jira-tickets flaky login test, put it in the E2E Improvements epic`
  — resolves the epic by name, interviews for the other four.
- Invoked naturally: "create a ticket for this under the Reporting epic."

## Instructions

```
Ticket Creation Progress:
- [ ] Step 1: Parse the prompt for the work + the five fields
- [ ] Step 2: Resolve the epic
- [ ] Step 3: Read sibling tickets to lock the naming convention
- [ ] Step 4: Draft title + description in house style
- [ ] Step 5: Interview for every unresolved field (one batch)
- [ ] Step 6: Create the ticket via Atlassian MCP
- [ ] Step 7: Wire up real issue links (not text)
- [ ] Step 8: Report the key + URL + every field set
```

### Step 1: Parse the prompt

- Identify what the ticket is about. If it stems from code we just looked at, capture the
  exact symbol + file path (e.g. `buildExportFilename` in
  `apps/reporting/utils/ExportHelper.ts`).
- Scan the invocation for each of the five fields and record which are **supplied** vs
  **unresolved**. Common phrasings:
  - Epic — `under ADA-201`, `in the E2E Improvements epic`, `somewhere in ADA`
  - Points — `3 points`, `sp 5`, `size it at 2`
  - Sprint — `current sprint`, `this sprint`, `next sprint`, `backlog`, `don't sprint it`
  - Assignee — `assign to me`, `for Jane`, `unassigned`, `leave it unassigned`
  - Labels — `label it tech-debt`, `labels: flaky, e2e`, `no labels`
- An explicit "blank" (`backlog`, `unassigned`, `no labels`) **counts as supplied** — don't
  re-ask. Story points have no blank form.
- Resolve the site's cloudId with `getAccessibleAtlassianResources` on first use — don't
  hardcode it.

### Step 2: Resolve the epic

The epic is required and accepts three input shapes. Resolve to a concrete epic key:

- **Issue key given** (`ADA-201`) — `getJiraIssue` to confirm it exists and is an Epic. If
  it isn't an Epic, say so and ask.
- **Name given** (`the E2E Improvements epic`) — search:
  `issuetype = Epic AND summary ~ "E2E Improvements" ORDER BY updated DESC`.
  One hit → use it. Several → list them with key, summary, and project and ask which.
- **Only a space/project given** (`somewhere in ADA`) — list candidates:
  `project = ADA AND issuetype = Epic AND statusCategory != Done ORDER BY updated DESC`,
  then ask.
- **Nothing given** — ask. Offer recent epics the user has filed under
  (`parent IS NOT EMPTY AND reporter = currentUser() ORDER BY created DESC`) as options.

The epic may live in a **different project** than the ticket — `ADA-787` sits under the
`CTP-1258` epic. Take the child's project from the epic's project only if the user hasn't
said otherwise; when they conflict, ask.

### Step 3: Read sibling tickets to lock the naming convention

- **MUST** fetch a few of the epic's children before writing the title
  (`searchJiraIssuesUsingJql` with `parent = <EPIC> ORDER BY created ASC`).
- Infer the title pattern from siblings. In this user's epics it is almost always:

  **`<Component/Feature> - <Title Case summary>`**

  e.g. `Golden Files - Fix the PR Template's Contradictory Title Instruction`,
  `E2E - Station Page CFS Priority Assertion Ignores the Agency Label Mapping`.
  Match the existing component prefix exactly (spacing, casing).
- While you have the siblings, note their **issue type**, **priority**, **labels**, and
  which story-points field they populate — all four feed later steps. Request them
  explicitly: `fields: ["summary", "issuetype", "priority", "labels", "customfield_10024", "customfield_10016"]`.

### Step 4: Draft title + description in house style

Draft **before** the interview — the draft is what makes a story-point estimate possible.

**Title:** follow the locked convention from Step 3. Title Case, no trailing period,
no Jira key prefix in the summary itself.

**Description** uses this shape (Jira/Atlassian Markdown):

1. **Context first.** One or two paragraphs describing the *current* state and the problem.
   Reference real code with backticks and full file paths. Drop in a fenced code block
   when it sharpens the point.
2. A `---` horizontal divider.
3. An **Acceptance Criteria** block, bolded, with each criterion on its own line as
   `**AC1:**`, `**AC2:**`, … Keep them concrete and testable. Mark optional work as
   `(Extra Credit)`.
4. Optionally another `---` then `**Notes for QA:**` when there's QA-specific guidance.

**Do NOT** add a text `**Related Tickets:**` line — relationships go in real Jira links
(Step 7).

See [reference/ticket-template.md](reference/ticket-template.md) for the exact skeleton
and a worked example.

### Step 5: Interview for every unresolved field

Ask **once**, in a single batched `AskUserQuestion` covering everything Step 1 left
unresolved. Don't drip-feed one question at a time.

- **Story Points — hard gate.** Never create a ticket without a value, and never invent
  one silently. Size the work from the ACs you just drafted, then offer the project's
  scale with your pick **first and marked `(Recommended)`**, with a one-line rationale
  tied to the ACs (e.g. "one file, one helper extracted, existing tests cover it"). The
  user can always override. If the answer somehow comes back blank, ask again — do not
  proceed.
- **Sprint** — offer `Current sprint`, `Next sprint`, `Backlog (blank)`. Resolve the
  named sprint to an ID at create time (Step 6), not now.
- **Assignee** — offer `Me (Seamus)`, `Someone else`, `Unassigned (blank)`. If they pick
  someone else, resolve with `lookupJiraAccountId`; on multiple matches, list and ask.
- **Labels** — offer the labels the siblings from Step 3 actually use as options
  (multiSelect), plus `No labels`. Free text is always available via "Other". Jira
  rejects labels containing spaces — hyphenate (`tech debt` → `tech-debt`) and say so.

Since `AskUserQuestion` takes at most 4 questions, put epic resolution (Step 2) in its own
earlier call and batch the remaining four here.

### Step 6: Create the ticket via Atlassian MCP

Use `createJiraIssue` with `contentFormat: "markdown"`.

- **projectKey / summary / description / issueTypeName** — from Steps 2–4.
- **issueTypeName**: `Story` (feature or user-facing capability), `Task` (small, distinct,
  well-scoped work), `Bug` (a defect). When in doubt, match the closest siblings.
- **parent**: the epic key.
- **assignee_account_id**: the resolved account ID; omit the parameter entirely when blank.
- **additional_fields**: priority, story points, sprint, labels — see
  [reference/field-reference.md](reference/field-reference.md) for the exact field IDs,
  value shapes, and the fallbacks for when a field isn't on the create screen.
- **priority**: `Medium` unless the user says otherwise (the house default).
- Leave `components` empty unless siblings consistently set one.

Capture the returned key + URL. If the create call rejects a field as unavailable on the
screen, create the issue without it and set it with `editJiraIssue` immediately after —
then say which fields took the second pass.

### Step 7: Wire up real issue links

- For any ticket the user mentions as related/blocking/duplicated, create an actual link
  with `createIssueLink` — **do not** describe the relationship in prose.
- Default relationship is `Relates` unless the user implies blocking/duplicate.
  Mind direction: for "A is blocked by B" → `inwardIssue: B`, `outwardIssue: A`.

### Step 8: Report

Return the new key as a clickable URL (`https://flocksafety.atlassian.net/browse/<KEY>`),
then a short table of what was set — epic, type, priority, **story points**, sprint (by
name, not ID), assignee, labels — plus any links created. Call out anything that needed a
follow-up `editJiraIssue`.

## Key Principles

1. **Five fields, every time.** Epic, points, sprint, assignee, labels — from the prompt
   or from the interview. Silence is not consent to leave one blank.
2. **Story points are never blank.** Propose an estimate from the drafted ACs; confirm it.
3. **Draft before you interview.** The ACs are what make the point estimate defensible.
4. **One batched interview.** Not five round-trips.
5. **Match the epic, don't invent a style.** Always read siblings before titling.
6. **Context before criteria.** Explain the current state and *why*, then list ACs.
7. **Cite real code.** Backticked symbols + full file paths beat vague descriptions.
8. **Links are fields, not prose.** Use `createIssueLink`; never a "Related Tickets" line.
9. **Concrete, testable ACs.** Number them `AC1/AC2/…`; flag stretch work as Extra Credit.
10. **Report what you set.** Every field, by name — so a wrong sprint is caught at a glance.
