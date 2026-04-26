---
name: open-pr
description: Recipe for opening a GitHub pull request via `gh pr create` — title format derived from branch shape, body sourced from the repo's pull_request_template.md, assignee, and labels. Triggers when the user asks to "open a PR", "push it up as a PR", "create a pull request", or "open a pull request".
---

# Open a PR

Apply mechanically — these are not preferences.

## 1. Gate

Only run when the user explicitly asks for a PR ("open a PR", "push it up as a PR", "create a pull request"). For local commits or pushes without that request, stop after the push.

## 2. Title — pick the format from the branch name

Resolve the current branch first:

```bash
jj log -r @ --no-graph -T 'bookmarks'   # jj repos
git branch --show-current               # git repos
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
  - 1-3 bullets describing what changed and why.

  ## Test plan
  - [ ] How to verify the change.
  ```

- Never invent items to fill space. Doc-only changes: test plan is "N/A — docs only".
- Pass the body via a `cat <<'EOF' … EOF` heredoc so multi-line markdown survives shell quoting.

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

## 6. Run `gh` from the main checkout

When working from a jj workspace or git worktree, `cd` into the main repo first — `gh` resolves the upstream repo from the working directory, and a workspace path may not have one wired up the same way.

## End-to-end example

```bash
cd /Users/me/Repos/<repo>
gh pr create \
  --title "[ADA-120] Add login flow" \
  --assignee @me \
  --label enhancement \
  --body "$(cat <<'EOF'
<contents from .github/pull_request_template.md, filled in from the actual diff>
EOF
)"
```

## Sanity check before opening

- Title format matches the branch shape rule.
- Body uses the repo's template (if any), filled from the actual diff — not a stale plan.
- Assignee is set.
- One type label is set; repo-specific label gates are honored.
