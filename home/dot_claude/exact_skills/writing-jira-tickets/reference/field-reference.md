# Field Reference

Jira exposes story points and sprint as **custom fields**, and their IDs differ per site.
Never hardcode them from this doc — discover them at runtime with the recipe below and
confirm against the epic's siblings. The IDs listed here are the values Jira Cloud
commonly assigns, useful as a first guess only.

**cloudId:** always resolve with `getAccessibleAtlassianResources`. Never hardcode.

## The five intake fields

| Field | Field key | Where it goes on `createJiraIssue` | Value shape |
|-------|-----------|-----------------------------------|-------------|
| Epic | `parent` (Jira mirrors it to the legacy "Epic Link" custom field) | top-level `parent` param | `"PROJ-201"` |
| Story Points | custom field — discover | `additional_fields` | number: `3` |
| Sprint | custom field — discover | `additional_fields` | sprint **id** as a number |
| Assignee | `assignee` | top-level `assignee_account_id` param | account id string |
| Labels | `labels` | `additional_fields` | `["tech-debt", "e2e"]` |

Plus the house default: `additional_fields: {"priority": {"name": "Medium"}}`.

## Discovering the custom field IDs

Read one sibling ticket that already has points and a sprint set, asking Jira for the
field **names** alongside the values:

```
getJiraIssue(issueIdOrKey: "<a sibling>", fields: ["*all"], expand: "names")
```

The `names` map gives `customfield_XXXXX → "Story Points"` etc. Match on the label, not on
a remembered number. Cache what you find for the rest of the session.

Labels to look for:

- **"Story Points"** — the classic field, used by company-managed projects.
  Commonly `customfield_10024`.
- **"Story point estimate"** — the team-managed equivalent. Commonly `customfield_10016`.
- **"Sprint"** — commonly `customfield_10020`.

A site usually has *both* story-point fields defined, with only one populated. Don't
guess: in Step 3 you already fetched siblings — use whichever is non-null on them. If both
are null across every sibling (a project that genuinely doesn't estimate), still ask the
user for a value, set the classic "Story Points" field, and note in the report that
siblings carry no points.

## Sprint

On read the sprint field comes back as an array of sprint objects:

```json
[{"id": 1234, "name": "Team Sprint 12", "state": "active", "boardId": 99,
  "startDate": "...", "endDate": "..."}]
```

On **write**, pass the bare numeric id (`{"customfield_XXXXX": 1234}`), not the array or
the name.

Resolve "current" and "next" by reading the field off issues already in those sprints —
this MCP has no board/sprint listing tool:

```
# current sprint
project = <KEY> AND sprint IN openSprints()   → state "active"

# next sprint
project = <KEY> AND sprint IN futureSprints() → state "future"
```

Each returned issue's sprint array can hold several entries (an issue carried across
sprints keeps its history) — pick the entry whose `state` matches what you're after.
If `futureSprints()` yields more than one distinct future sprint, choose the earliest
`startDate`; when future sprints have no start dates, choose the lowest `id` and **say
which sprint name you picked** in the report so a wrong guess is visible.

Sprint ids roll over every couple of weeks — always re-resolve, never reuse one from a
previous session.

**Backlog** = omit the sprint field entirely. Do not pass `null`.

## Assignee

- **Yourself** — `atlassianUserInfo` returns the current account id. Don't hardcode it.
- **Someone else** — `lookupJiraAccountId` with a name or email. Multiple matches: list
  them with display name + email and ask.
- **Unassigned** — omit `assignee_account_id`. Jira will apply the project's default
  assignee rule, which may not be "nobody"; if the created issue comes back with an
  assignee the user didn't ask for, mention it in the report.

## Labels

- Shape: `additional_fields: {"labels": ["flaky", "tech-debt"]}`.
- **Jira rejects labels containing spaces.** Hyphenate (`tech debt` → `tech-debt`) and
  tell the user you did.
- Labels are free-text and global — a typo silently creates a new label rather than
  erroring. Prefer offering labels the epic's siblings already use.
- No labels = omit the key.

## Other fields you'll see and should leave alone

| Field | Notes |
|-------|-------|
| Epic Link | Legacy mirror of `parent`; Jira maintains it. Don't set it by hand. |
| Rank | Board ordering. Never set manually. |
| `[CHART] …` fields | Read-only, plugin-generated. |
| Approval / compliance gates | Project-specific. Leave at their defaults unless asked. |

Issue type and priority ids vary by site — pass them by **name** (`"Task"`, `"Bug"`,
`{"name": "Medium"}`) and let Jira resolve them.

## When a field is rejected on create

`createJiraIssue` fails if a field isn't on the project's **create** screen — most often
Sprint or Story Points. Recover rather than dropping the value:

1. Create the issue without the offending field.
2. `editJiraIssue` with `{"fields": {"<story points field>": 3}}` — the edit screen usually
   allows what the create screen doesn't.
3. Report which fields took the second pass.

Never silently drop story points. If both passes fail, stop and tell the user the ticket
exists but is unpointed.
