# Jira

Everything goes through the Atlassian MCP. Resolve the site's `cloudId` with `getAccessibleAtlassianResources` on first use — never hardcode it. Field IDs, value shapes, and the create-screen fallback are in [jira-fields.md](jira-fields.md); read it before creating.

## Fetch first

### The space and the epic

The epic is required. Resolve it to a real epic key from whatever the user gave:

- **Key** (`PROJ-201`) — `getJiraIssue` to confirm it exists and is an Epic. Not an Epic → say so and ask.
- **Name** ("the Reporting Cleanup epic") — search `issuetype = Epic AND summary ~ "Reporting Cleanup" ORDER BY updated DESC`. One hit → use it. Several → list key, summary, and space, and ask.
- **Only a space** ("somewhere in PROJ") — list `project = PROJ AND issuetype = Epic AND statusCategory != Done ORDER BY updated DESC`, then ask.
- **Nothing** — ask, offering the epics the user filed under recently: `parent IS NOT EMPTY AND reporter = currentUser() ORDER BY created DESC`.

The epic can live in a different space than the ticket (a `PROJ-` ticket under a cross-team `PLAT-` epic). The ticket's space defaults to the epic's; when the user said otherwise, ask which wins.

### The epic's children

**Always** read a few before writing the title: `searchJiraIssuesUsingJql` with `parent = <EPIC> ORDER BY created ASC`, `fields: ["summary", "issuetype", "priority", "labels", "*all"]`, `expand: "names"`. They give you:

- the title convention — almost always **`<Component/Feature> - <Title Case summary>`** (`Reporting - Add CSV Export to Usage Dashboard`); match the component prefix exactly;
- the issue types, priorities, and labels in use — your suggestions in the field round;
- which story-points field is populated (see [jira-fields.md](jira-fields.md)).

## Body

Draft the body **before** the field round: the acceptance criteria are what make a story-point estimate defensible.

```markdown
<1–2 paragraphs of context: the current state and the problem. Reference real code
with `backtickedSymbols` and full file paths. A fenced code block when it makes the
current behaviour concrete.>

---

**Acceptance Criteria:**
**AC1:** <concrete, testable outcome>
**AC2:** <concrete, testable outcome>
**AC3:** (Extra Credit) <optional stretch>

---

**Notes for QA:**
<only when there's QA-specific guidance>
```

Title Case title, no trailing period, no key prefix. Never a "Related Tickets:" line — relationships are real links.

## Fields

Ask in the §4 round, each with its suggestion:

| Field | Suggest from | Blank |
|---|---|---|
| Space | the epic's space | not allowed |
| Epic | resolved above | **not allowed** |
| Issue type | Story (feature or user-facing capability), Task (small, well-scoped work), Bug (a defect); match the closest siblings | not allowed |
| Priority | `Medium` (the house default), or what siblings of the same kind use | Medium |
| Story points | your estimate from the ACs, marked recommended, with a one-line rationale ("one file, one helper extracted, existing tests cover it") | **never** — a hard gate; ask again if it comes back empty |
| Sprint | current sprint, next sprint, or backlog | backlog (omit the field) |
| Assignee | me, someone else (resolve with `lookupJiraAccountId`; several matches → list and ask), unassigned | unassigned (omit the field) |
| Labels | the labels the siblings use | none (omit the key) |

Leave components empty unless every sibling sets the same one.

## Create

`createJiraIssue` with `contentFormat: "markdown"`: `projectKey`, `summary`, `description`, `issueTypeName`, `parent` (the epic key), `assignee_account_id` (omit when unassigned), and `additional_fields` for priority, story points, sprint, and labels — shapes and field IDs per [jira-fields.md](jira-fields.md). A field rejected as missing from the create screen gets the second pass described there.

## Link

Every relationship the user mentions becomes a real link with `createIssueLink`. The default type is **Relates**; use Blocks or Duplicate only when the user says so, and mind the direction — "A is blocked by B" is `inwardIssue: B`, `outwardIssue: A`.

**Split work:** every slice goes under the same epic, and each slice is linked to the slices it depends on with **Relates**.

## Report

The key as a clickable URL (`https://<site>.atlassian.net/browse/<KEY>`), then epic, type, priority, story points, sprint (by name, not ID), assignee, and labels, plus any links created. Call out anything that needed a follow-up `editJiraIssue`.
