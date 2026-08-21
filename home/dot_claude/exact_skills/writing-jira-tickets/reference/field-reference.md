# Field Reference — flocksafety.atlassian.net

Field IDs verified against real tickets in the `ADA` project (Aviation Drones & ATA,
project id `13229`, board `4683`). Company-managed projects on this site share these IDs;
team-managed projects differ where noted.

**cloudId:** resolve with `getAccessibleAtlassianResources` rather than hardcoding. As of
this writing the site's Jira cloudId is `12c72a9d-c0f0-4904-9a39-063c1dda1717`.

## The five intake fields

| Field | ID | Where it goes on `createJiraIssue` | Value shape |
|-------|-----|-----------------------------------|-------------|
| Epic | `parent` (also mirrored to `customfield_10014` "Epic Link") | top-level `parent` param | `"ADA-201"` |
| Story Points | `customfield_10024` | `additional_fields` | number: `3` |
| Sprint | `customfield_10020` | `additional_fields` | sprint **id** as a number: `14606` |
| Assignee | `assignee` | top-level `assignee_account_id` param | account id string |
| Labels | `labels` | `additional_fields` | `["tech-debt", "e2e"]` |

Plus the house default: `additional_fields: {"priority": {"name": "Medium"}}`.

### Story Points — `customfield_10024` vs `customfield_10016`

Two similarly named fields exist on this site:

- **`customfield_10024` = "Story Points"** — the classic field used by company-managed
  projects. This is the one `ADA` populates.
- **`customfield_10016` = "Story point estimate"** — the team-managed equivalent. Null on
  every `ADA` ticket.

Don't guess. In Step 3 you already fetched siblings with both fields requested — use
whichever one is non-null on them. If both are null across every sibling (a project that
genuinely doesn't estimate), still ask the user for a value and set `customfield_10024`;
say in the report that siblings carry no points.

### Sprint — `customfield_10020`

On read it comes back as an array of sprint objects:

```json
[{"id": 14606, "name": "ADA Sprint 12", "state": "active", "boardId": 4683,
  "startDate": "2026-08-11T16:29:14.373Z", "endDate": "2026-08-25T16:29:07.000Z"}]
```

On **write**, pass the bare numeric id (`{"customfield_10020": 14606}`), not the array or
the name.

Resolve "current" and "next" by reading the field off issues already in those sprints —
there is no board/sprint listing tool in this MCP:

```
# current sprint
project = ADA AND sprint IN openSprints()   → fields: ["customfield_10020"]  → state "active"

# next sprint
project = ADA AND sprint IN futureSprints() → fields: ["customfield_10020"]  → state "future"
```

Each returned issue's sprint array can hold several entries (an issue carried across
sprints keeps its history) — pick the entry whose `state` matches what you're after.
If `futureSprints()` yields more than one distinct future sprint, choose the earliest
`startDate`; when future sprints have no start dates, choose the lowest `id` and **say
which sprint name you picked** in the report so a wrong guess is visible.

**Backlog** = omit `customfield_10020` entirely. Do not pass `null`.

Known sprint ids at time of writing (they roll over — always re-resolve):
`14606` = ADA Sprint 12 (active), `14660` = ADA Sprint 13 (future).

### Assignee

- **Seamus** — `atlassianUserInfo` returns the current account id. Don't hardcode it.
- **Someone else** — `lookupJiraAccountId` with a name or email. Multiple matches: list
  them with display name + email and ask.
- **Unassigned** — omit `assignee_account_id`. Jira will apply the project's default
  assignee rule, which may not be "nobody"; if the created issue comes back with an
  assignee the user didn't ask for, mention it in the report.

### Labels

- Shape: `additional_fields: {"labels": ["flaky", "tech-debt"]}`.
- **Jira rejects labels containing spaces.** Hyphenate (`tech debt` → `tech-debt`) and
  tell the user you did.
- Labels are free-text and global on this site — a typo silently creates a new label
  rather than erroring. Prefer offering labels the epic's siblings already use.
- No labels = omit the key.

## Other fields seen on ADA tickets

| ID | Name | Notes |
|----|------|-------|
| `customfield_10014` | Epic Link | Legacy mirror of `parent`; Jira maintains it. Don't set it by hand. |
| `customfield_10019` | Rank | Board ordering. Never set manually. |
| `customfield_10023` | [CHART] Time in Status | Read-only, plugin-generated. |
| `customfield_10486` | (approval gate, defaults "No") | Leave alone unless asked. |

Issue type ids: `10000` Epic, `10002` Task, `10004` Bug. Priority `Medium` = id `3`.
Issue link type `Relates` = id `10003`.

## When a field is rejected on create

`createJiraIssue` fails if a field isn't on the project's **create** screen — most often
Sprint or Story Points. Recover rather than dropping the value:

1. Create the issue without the offending field.
2. `editJiraIssue` with `{"fields": {"customfield_10024": 3}}` — the edit screen usually
   allows what the create screen doesn't.
3. Report which fields took the second pass.

Never silently drop story points. If both passes fail, stop and tell the user the ticket
exists but is unpointed.
