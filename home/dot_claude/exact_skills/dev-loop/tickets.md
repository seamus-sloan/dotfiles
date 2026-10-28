# Ticket state

A run that has a ticket keeps it in step with the work. A spec with no ticket skips all of this.

| When | Do |
|---|---|
| §2, once the worktree exists | assign it to me, then move it to **In Progress** |
| §7, once the PR is open (draft or ready) | move it to **In Review** |
| the PR merges (`ship-pr` §5) | move it to **Done** |

`no-pr` runs stop at In Progress. A PR merged by hand is moved by whoever merges it; GitHub's `Closes #<n>` already closes the issue.

## Which ticket

- A GitHub issue number or URL, or a key whose prefix is this repo's row in `~/.config/git/issue-prefixes` (`DOT-123` in dotfiles is issue #123) → **GitHub**.
- An `atlassian.net` URL → **Jira**; a `linear.app` URL → **Linear**.
- Any other key (`ADA-123`), from the arguments or the `branch=` name → `getJiraIssue`; not found → the Linear MCP; neither knows it → ask once.

## Rules

- **Match state names case-insensitively.** The review state may be called "In Review", "Ready for Review" or "Code Review"; Done may be "Closed" or "Resolved". Nothing close → leave it and report the names on offer.
- **Never move a ticket backwards.** A ticket already at or past the target state stays where it is.
- **Assign only when it isn't mine.** Unassigned → assign me. Assigned to someone else → ask once before taking it over.
- **Never block the loop.** A tracker that's unreachable (MCP not authorised, a missing token scope) or a transition that fails goes in the final report's `Ticket:` line with the command that failed, and the run carries on.

## How

**GitHub** (`gh`). Assign: `gh issue edit <n> --add-assignee @me`. Done: the merge closes it (`ship-pr` confirms); also set Status below. The state lives in the Status field of any GitHub Project the issue is on; an issue on no project only gets assigned and closed. Projects need the `project` scope; without it, report "run `gh auth refresh -s project`" and skip the Status change.

```bash
gh api graphql -F o=<owner> -F r=<repo> -F n=<n> -f query='
query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){issue(number:$n){
  assignees(first:10){nodes{login}}
  projectItems(first:10){nodes{id fieldValueByName(name:"Status"){... on ProjectV2ItemFieldSingleSelectValue{name}}
    project{id field(name:"Status"){... on ProjectV2SingleSelectField{id options{id name}}}}}}}}}'
gh project item-edit --id <item id> --project-id <project id> --field-id <field id> --single-select-option-id <option id>
```

**Jira** (Atlassian MCP; resolve `cloudId` with `getAccessibleAtlassianResources`). Read: `getJiraIssue` with `fields: ["status", "assignee"]`. Assign: my account id from `atlassianUserInfo`, then `editJiraIssue` with `{"assignee": {"accountId": "<id>"}}`. Move: `getTransitionsForJiraIssue`, pick the transition whose target status matches, then `transitionJiraIssue` with its id.

**Linear** (Linear MCP). Read the issue for its state and assignee, list the team's workflow states, then update the issue with assignee `me` and the matching state.
