---
name: writing-jira-tickets
description: Drafts and creates Jira tickets in Seamus's house style, then files them via the Atlassian MCP — matching epic naming conventions, a context-first description with an Acceptance Criteria block, sensible defaults (parent epic, Medium priority, right issue type), and real Jira issue links instead of text references. Use when asked to "create a ticket", "write a Jira ticket", "file this under <epic>", "add this to the <epic> epic", or to turn a bug/idea into a ticket.
user-invocable: true
argument-hint: "[what the ticket is for] [optional: epic key]"
---

# Writing Jira Tickets

## Core Task

Turn a feature idea, bug, or chunk of work into a well-formed Jira ticket that matches
Seamus's writing style, then create it in Jira via the Atlassian MCP under the correct
epic — with the right title format, a context-first description, an Acceptance Criteria
block, sensible field defaults, and **real Jira issue links** (never a text "Related
Tickets" line). The output is a created Jira issue (key + URL) ready for review.

## Usage

- `/writing-jira-tickets adjust the serial hash to include the agency URL, under ADA-201`
  — drafts and files a ticket under the ADA-201 epic.
- `/writing-jira-tickets video feed missing when running mock controller via npm`
  — drafts a ticket; asks which epic/project if not obvious from context.
- Invoked naturally: "create a ticket for this under the Mock Controller epic."

## Instructions

```
Ticket Creation Progress:
- [ ] Step 1: Gather the work + target epic/project
- [ ] Step 2: Read sibling tickets to lock the naming convention
- [ ] Step 3: Draft title + description in house style
- [ ] Step 4: Pick field defaults (type, priority, parent)
- [ ] Step 5: Create the ticket via Atlassian MCP
- [ ] Step 6: Wire up real issue links (not text)
- [ ] Step 7: Report the key + URL
```

### Step 1: Gather the work and target

- Identify what the ticket is about. If it stems from code we just looked at, capture the
  exact symbol + file path (e.g. `buildStableHardwareSerial` in
  `fe/apps/e2e/mockControllerServer_v3/utils/HardwareGenerator.ts`).
- Determine the **epic** and **project**. If the user named an epic (e.g. ADA-201), use it
  as the `parent`. If neither epic nor project is clear, ask — do not guess the project.

### Step 2: Read sibling tickets to lock the naming convention

- **MUST** fetch the epic and a few of its children before writing the title
  (`searchJiraIssuesUsingJql` with `parent = <EPIC> ORDER BY created ASC`).
- Infer the title pattern from siblings. In this user's epics it is almost always:

  **`<Component/Feature> - <Title Case summary>`**

  e.g. `Mock Controller - Include Computer Hostname in Serial Number`,
  `Mock Controller - Randomize Laser Distance for Dynamic Telemetry`.
  Match the existing component prefix exactly (spacing, casing).
- Also note the siblings' default issue type and priority to stay consistent.

### Step 3: Draft title + description in house style

**Title:** follow the locked convention from Step 2. Title Case, no trailing period,
no Jira key prefix in the summary itself.

**Description** uses this shape (Jira/Atlassian Markdown):

1. **Context first.** One or two paragraphs describing the *current* state and the problem.
   Reference real code with backticks and full file paths. Drop in a fenced code block
   when it sharpens the point (e.g. the current hash input).
2. A `---` horizontal divider.
3. An **Acceptance Criteria** block, bolded, with each criterion on its own line as
   `**AC1:**`, `**AC2:**`, … Keep them concrete and testable. Mark optional work as
   `(Extra Credit)`.
4. Optionally another `---` then `**Notes for QA:**` when there's QA-specific guidance.

**Do NOT** add a text `**Related Tickets:**` line — relationships go in real Jira links
(Step 6).

See [reference/ticket-template.md](reference/ticket-template.md) for the exact skeleton
and a worked example.

### Step 4: Pick field defaults

- **parent**: the epic key.
- **priority**: `Medium` unless the user says otherwise (the house default).
- **issueTypeName**:
  - `Story` — a feature or user-facing capability (matches sibling features).
  - `Task` — a small, distinct, well-scoped piece of work.
  - `Bug` — a defect / something broken.
  - When in doubt, match what the closest sibling tickets use.
- Leave `components` empty unless siblings consistently set one.

### Step 5: Create the ticket via Atlassian MCP

- Use `createJiraIssue` (cloudId `flocksafety.atlassian.net`, contentFormat markdown).
- Pass `priority` via `additional_fields`: `{"priority": {"name": "Medium"}}`.
- Capture the returned key + URL.

### Step 6: Wire up real issue links

- For any ticket the user mentions as related/blocking/duplicated, create an actual link
  with `createIssueLink` — **do not** describe the relationship in prose.
- Default relationship is `Relates` unless the user implies blocking/duplicate.
  Mind direction: for "A is blocked by B" → `inwardIssue: B`, `outwardIssue: A`.

### Step 7: Report

- Return the new key as a clickable URL (`https://flocksafety.atlassian.net/browse/<KEY>`),
  the epic it landed under, type/priority, and any links created.

## Key Principles

1. **Match the epic, don't invent a style.** Always read siblings before titling.
2. **Context before criteria.** Explain the current state and *why*, then list ACs.
3. **Cite real code.** Backticked symbols + full file paths beat vague descriptions.
4. **Links are fields, not prose.** Use `createIssueLink`; never a "Related Tickets" line.
5. **Sane defaults, stated.** Parent epic, Medium priority, type matched to siblings —
   mention what you chose.
6. **Concrete, testable ACs.** Number them `AC1/AC2/…`; flag stretch work as Extra Credit.
7. **Ask only when blocked.** Project/epic when genuinely unknown — otherwise proceed.
