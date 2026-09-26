# GitHub Issues

Everything goes through an authenticated `gh` CLI. `<repo>` is `owner/name`: the current checkout's (`gh repo view --json nameWithOwner --jq .nameWithOwner`) unless the user named another; outside a checkout, ask.

## Fetch first

- **Issue forms**: every `.github/ISSUE_TEMPLATE/*.yml` and `*.md` — from the local checkout, or `gh api repos/<repo>/contents/.github/ISSUE_TEMPLATE` when there isn't one. `config.yml` is settings, not a form.
- **Issue types**: `gh api graphql -f query='query{repository(owner:"<owner>",name:"<name>"){issueTypes(first:20){nodes{name}}}}'`. None → skip the type question.
- **Labels**: `gh label list -R <repo> --limit 200`.
- **Milestones and projects**: `gh api repos/<repo>/milestones --jq length` and the repository's `projectsV2(first:10){nodes{title}}`. Zero → don't ask about them.
- **Assignable people**: `gh api repos/<repo>/assignees --jq '.[].login'`.

## Body

Pick the form that matches the kind of issue settled in the interview (bug report for a defect, feature request for new work). The CLI can't submit a form, so rebuild what a submission would produce:

- One `### <label>` section per field, in the form's order.
- `checkboxes` fields as `- [x]` / `- [ ]` lines, one per option, all listed.
- `dropdown` fields as the chosen option.
- Skip `type: markdown` elements: they're instructions to the person filing, not fields.
- Every field marked `required: true` gets a real value.

The form's top-level keys set defaults: `title:` is the title prefix (`[Scope] ` → `[Metadata Edit] Per-Library Precedence Setting`), `labels:` and `assignees:` are pre-filled suggestions, `type:` is the suggested issue type.

No forms → a plain body: `## Description`, `## Acceptance Criteria` (`- AC1: …`), and `## Attachments` only if there is something to attach.

Cite modules and features by name and link source files (`db/src/auth.rs`) rather than line numbers that drift.

## Fields

Ask in the §4 round, each with its suggestion:

| Field | Suggest from | Blank means |
|---|---|---|
| Issue type | the form's `type:`, else Bug for a defect and Feature/Task for work | untyped |
| Labels | the form's `labels:`, plus any from `gh label list` that fit (`security` for auth or untrusted input, a crate or area label) | the form's labels only |
| Assignees | `@me`, anyone from the assignee list | unassigned |
| Parent issue | an existing epic issue the work belongs to | standalone |
| Blocked by | existing issues that must land first | nothing |
| Milestone / project | only when the repo has any | none |

## Create

Write the body to `<scratchpad>/write-ticket/<slug>.md`, then:

```bash
gh issue create -R <repo> \
  --title "<title>" \
  --body-file <scratchpad>/write-ticket/<slug>.md \
  --type "<type>" \
  --label "<label>" --label "<label>" \
  --assignee "<login|@me>" \
  --parent <parent number>
```

Add `--milestone` / `--project` only when set; drop any flag whose field is blank.

**Blocked by** — after the issue exists, per blocker:

```bash
blocker_id=$(gh api repos/<repo>/issues/<blocker number> --jq .id)
gh api --method POST repos/<repo>/issues/<new number>/dependencies/blocked_by -F issue_id=$blocker_id
```

## Split work

No existing parent → create one first: its body summarises the whole and lists the slices once they exist. Then create each slice in dependency order (blockers first) with `--parent <parent number>`, and add its blocked-by edges. Pace creates about a second apart to stay under GitHub's secondary rate limit, and log each action so a partial run can be resumed.

Check the parent's rollup when done:

```bash
gh api graphql -f query='query{repository(owner:"<owner>",name:"<name>"){issue(number:<parent>){subIssuesSummary{total completed percentCompleted}}}}'
```

## Report

Each issue's URL, then type, labels, assignees, parent, blocked-by, and milestone/project if set. When the repo is listed in `~/.config/git/issue-prefixes`, add the branch name the work will use: `<PREFIX>-<number>/<slug>`.
