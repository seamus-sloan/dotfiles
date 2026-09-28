---
name: open-pr
description: Recipe for opening a GitHub pull request via `gh pr create` — title format derived from branch shape, a terse body from the repo's pull_request_template.md (≤ 80-char bullets, ≤ 4 per section), assignee, and labels; plus the saved-copy check any skill runs before rewriting a PR description. Triggers when the user asks to "open a PR", "push it up as a PR", "create a pull request", "open a pull request", "update the PR description", or when a stacked branch's work is complete.
---

# Open a PR

Apply mechanically — these are not preferences.

## 1. Gate

Only run when the user explicitly asks for a PR ("open a PR", "push it up as a PR", "create a pull request"). For local commits or pushes without that request, stop after the push.

## 2. Title — pick the format from the branch name

Resolve the current branch first:

```bash
git branch --show-current
```

Then pick the format:

| Branch shape | Title format | Example |
|---|---|---|
| `<TICKET>/<slug>` (e.g. `ADA-120/login-flow`) | `[<TICKET>] <Title Case Summary>` | `[ADA-120] Add login flow` |
| Single-commit branch (any name) | Use the lone commit's subject verbatim | `chore: update dependencies` |
| `u/<name>/<slug>` (personal branch, multiple commits) | Conventional prefix from the dominant commit type | `feat: add new login flow` |
| Other multi-commit branches | Conventional prefix matching the lead commit | `fix: handle empty cover path` |

Keep titles under ~70 chars. Detail goes in the body, not the title. Conventional prefixes are `feat:` / `fix:` / `chore:` only — no scopes.

## 3. Body — sourced from the repo's template

- If `.github/pull_request_template.md` (or `.github/PULL_REQUEST_TEMPLATE.md`, or any `*.md` under `.github/PULL_REQUEST_TEMPLATE/`) exists, read it and fill in every section using facts from the diff and the conversation. Preserve section order and headings exactly.
- If no template exists, fall back to a minimal default:

  ```markdown
  ## Summary
  - What changed, one line.

  ## Test plan
  - [ ] How to verify, one line.
  ```

- **Hard limits.** The diff is already in the PR; the body only gives its shape and how to verify it.
  - Every bullet is **80 characters or less** — one line, never wrapping.
  - Never hard-wrap. Each sentence or paragraph sits on one line however long — including text kept from the template, whose line breaks get joined, not copied.
  - At most **4 bullets per section**.
  - No paragraphs, sub-bullets, intro sentences, or bold lead-ins.
  - Keep the template's headings and checkboxes; drop optional sections (`Notes`, `Screenshots`, …) with nothing new to say.
  - Nothing the diff already shows: no `file.rs:123` refs, no restated commit subjects, no conversation recap.
  - No process notes — review rounds, finding tallies, test-run narration, pre-existing failures. Those go to the user in chat, never into the PR.
- Test plan: evidence as checkboxes (a command and its result, a manual check) — not a narrated list of tests.
- Never invent items to fill space. Doc-only changes: test plan is `N/A — docs only`.
- Write the body to a file and pass `--body-file` (see §8) so the text posted is exactly the text saved.

### Closing keyword — always link the issue the PR resolves

If this PR fully resolves a tracked issue, the body **must** contain a GitHub closing keyword so the merge auto-closes it: `Closes #<n>` (or `Fixes #<n>` for a bug). Put it on its own line at the end of the Summary section.

- **Fully resolves** the issue → `Closes #<n>`. This is the common case when the branch/work was scoped to one issue (e.g. a `<TICKET>/…` branch, or the user said "ship issue #N").
- **Partially addresses** it (one sub-task of a larger issue) → reference it *without* a closing keyword: `Part of #<n>` / `Sub-task of #<n>`. A closing keyword here would wrongly close the parent.
- **A bare `#<n>`** mention (no keyword) never closes anything — it only cross-links. Don't rely on it to close an issue.

A ticket in the repo's own prefix **is** a GitHub issue number: `DOT-12/slug` → `Closes #12`, `OMNI-340/slug` → `Closes #340`. The prefixes live in `~/.config/git/issue-prefixes`; a key that isn't listed there (`ADA-120`) is a Jira ticket and closes nothing on GitHub.

Determine the issue number from the branch name (`<TICKET>/…`, `<n>/…`, `feat/<n>-…`), the conversation ("ship issue #N", a pasted issue URL), or the commit body. When you can't tell whether the PR *fully* resolves it, prefer `Part of #<n>` and say so — under-closing is recoverable, wrongly closing a parent epic is noise. If the template has a dedicated "Closes/Fixes" or "Related issues" field, use that instead of appending to Summary.

## 4. Assignee — always the current user

```bash
gh pr create --assignee @me ...
```

Without an assignee the PR drops out of the dashboard view. Resolving the literal login via `gh api user --jq .login` is only needed when scripting against another user.

## 5. Labels — exactly one type label, plus any repo-specific gates

| Change type | Label |
|---|---|
| New feature / behavior | `enhancement` |
| Bug fix | `bug` |
| Docs-only | `documentation` |

Refactors / dep bumps: closest fit (usually `enhancement` for behavior-affecting refactors, `documentation` for pure doc moves).

Before opening, scan the repo's `CLAUDE.md` / `.claude/` / `CONTRIBUTING.md` for additional label gates (e.g. some repos require `run_ui_tests` when E2E directories are touched) and add them.

## 6. Running `gh` from a worktree

`gh` resolves the upstream repo from the working directory. A worktrunk worktree has a `.git` *file* pointing back at the main repo, which `gh` follows fine — so run it in place, no `cd` needed.

If `gh` still can't infer the repo or the branch, pass them explicitly rather than hopping between directories:

```bash
gh pr create --repo <owner>/<repo> --base main --head <branch> --assignee @me --label <type> ...
```

Get the branch from `git branch --show-current` and the repo slug from `gh repo view --json nameWithOwner --jq .nameWithOwner`.

## 7. Draft PRs

When the invoker asks for a draft (the `dev-loop` skill does by default), add `--draft` to `gh pr create`. Everything else — title, body, assignee, labels — is unchanged. `gh pr ready <pr>` flips it to ready for review later.

## 8. Saved copy — never overwrite someone else's edits

`gh` acts as the user's account, so GitHub can't tell whether a PR description was last edited by the user or by you. A local copy of what you last wrote can:

```
${TMPDIR:-/tmp}/pr-bodies/<owner>-<repo>-<number>.md
```

- **After every write** — `gh pr create` or `gh pr edit --body-file` — save the exact body you sent to that path.
- **Before any rewrite** of an existing description, by this skill or any other (`ship-pr`, `dev-loop`, a follow-up edit), compare the live body with the saved copy:

  ```bash
  saved="${TMPDIR:-/tmp}/pr-bodies/<owner>-<repo>-<number>.md"
  gh pr view <number> --json body --jq .body > "${saved%.md}.live.md"
  diff -wB "$saved" "${saved%.md}.live.md"
  ```

  - No difference → rewrite it, then save the new body.
  - A difference, or no saved copy → someone else edited it (or you never wrote it). Show the user the live body and what you'd change, and **ask before overwriting**.

## End-to-end example

```bash
# run from inside the worktree — no cd needed
mkdir -p "${TMPDIR:-/tmp}/pr-bodies"
draft="${TMPDIR:-/tmp}/pr-bodies/draft-$(git branch --show-current | tr / -).md"
# write the filled-in template to "$draft", then:
gh pr create \
  --title "[ADA-120] Add login flow" \
  --assignee @me \
  --label enhancement \
  --body-file "$draft"
# rename the draft to the saved copy for the new PR
n=$(gh pr view --json number --jq .number)
mv "$draft" "${TMPDIR:-/tmp}/pr-bodies/$(gh repo view --json nameWithOwner --jq .nameWithOwner | tr / -)-$n.md"
```

## Sanity check before opening

- Title format matches the branch shape rule.
- Body uses the repo's template (if any), filled from the actual diff — not a stale plan.
- Every bullet is ≤ 80 characters; no section has more than 4; no process notes.
- Assignee is set.
- One type label is set; repo-specific label gates are honored.
- The body is saved to its `pr-bodies` copy once the PR exists.
