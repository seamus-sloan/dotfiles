# Ticketing platforms

How each tracker differs. Read the row for your tracker, then its detail file; skip the others.

| | GitHub | Jira | Linear |
|---|---|---|---|
| **Detail file** | [github.md](github.md) | [jira.md](jira.md), field IDs in [jira-fields.md](jira-fields.md) | [linear.md](linear.md) — stub, not built |
| **Reached through** | `gh` CLI | Atlassian MCP (`createJiraIssue`, `editJiraIssue`, `createIssueLink`, …) | not wired up yet |
| **Where a ticket lives** | a repo (the current checkout unless the user names another) | a space (project key) | a team |
| **Fetch first** | the repo's issue forms, issue types, labels, milestones, projects | the epic and a few of its children | — |
| **Body template** | the repo's issue form for the kind of issue (`.github/ISSUE_TEMPLATE/*.yml`); plain fallback | house style: context → `---` → numbered acceptance criteria | — |
| **Title** | the form's `title:` prefix, e.g. `[Scope] ` | `<Component> - <Title Case summary>`, matched to the epic's children | — |
| **Fields to ask** | issue type, labels, assignees, parent issue, blocked-by; milestone and project only when the repo has any | space, epic, issue type, priority, story points, sprint, assignee, labels | team, project, cycle, estimate, priority, labels, assignee, parent |
| **Hard gates** | the form's required fields are filled | the epic resolves to a real epic; story points are never blank | — |
| **Parent model** | sub-issues: a parent issue with a progress rollup | the epic is the ticket's `parent` | sub-issues and projects |
| **Linking split slices** | children of one parent issue, plus native **blocked by** edges | children of the epic, linked with **Relates** | sub-issues plus blocked-by relations |
| **Quirks** | issue forms can't be submitted from the CLI: rebuild the body from the form; the dependency API takes the blocker's internal `.id`, not its number; pace batch creates ~1s apart | story-point and sprint custom-field IDs differ per site; labels can't contain spaces; a field missing from the create screen needs a second pass with `editJiraIssue` | — |

## Adding a tracker

Fill in its column above, write its detail file with the same sections as the others (fetch first, body, fields, create, link, report), and add it to the argument hint in [SKILL.md](SKILL.md).
