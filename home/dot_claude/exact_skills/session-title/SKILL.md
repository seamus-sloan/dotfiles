---
name: session-title
description: Documents and manages the session auto-naming hook at ~/.claude/hooks/session-title.sh, which titles CCD sessions "<Objective> - <CODE>" (e.g. "Rename Sessions - D") and folds in a PR number once one is opened. Triggers when the user asks to "add a project code", "pin a project code", "rename this session", "why is my session called that", asks about session titles, or wants the naming scheme changed.
---

# session-title

Titles every session after what it's for and which project it's in:

```
Rename Sessions - D          new session in dotfiles
#123 Rename Sessions - D     after a PR is opened
```

Objective is at most four words in Title Case. The suffix is the project's short
code.

## Project codes

Every repo gets a code. The code is **guessed** from the repo directory name —
the initials of its hyphen, underscore, or dot-separated words, uppercased and
capped at three characters:

| Repo | Guess |
|---|---|
| `platform` | `P` |
| `infrastructure` | `I` |
| `mock-controller` | `MC` |
| `drone-userland` | `DU` |
| `my-cool-web-service` | `MCW` |

`~/.claude/repo-codes` **overrides** the guess. Preferred codes live there:

| Repo | Code |
|---|---|
| `platform` | `P` |
| `mock-controller` | `MC` |
| `mock-dock` | `MD` |
| `drone-userland` | `DU` |
| `infrastructure` | `I` |
| `dotfiles` | `D` |

Every one of those matches what the guess would produce anyway, so today the
file changes no behavior. It's still worth keeping: the rows **reserve** those
codes, so when a `mock-dashboard` shows up it gets pinned deliberately rather
than silently becoming a second `MD`.

Only a cwd that isn't a git repo at all ends up with no suffix — there's nothing
to guess from.

Codes are resolved through `git rev-parse --git-common-dir`, so a worktree at
`~/worktrees/dotfiles/u-sloan-foo` still reads as `dotfiles` and gets `- D`,
not the branch-named directory it physically lives in.

## Why it takes three hooks

The desktop app gives a hook no way to rename a session directly. `/rename` is a
TUI-only slash command (`requires: {ink: true}`), and the session's
`messagingSocketPath` accepts a connection but ignores a `rename` control
message — the registry `name` field that would set is not what the sidebar
renders. The only working lever is the `set_session_title` MCP tool, which only
the model can call. So the hooks inject instructions via `additionalContext` and
the model makes the call.

| Event | Matcher | Does |
|---|---|---|
| `UserPromptSubmit` | — | On the first prompt only, asks for `<Objective> - <CODE>` |
| `PostToolUse` | `mcp__ccd_session_mgmt__set_session_title` | Records the title to `~/.claude/session-titles/<session id>` |
| `PostToolUse` | `Bash` | On a successful `gh pr create`, asks for `#<n> <recorded title>` |

The recorded title is what makes the PR step survive a compaction — the hook
rebuilds the whole string itself instead of relying on the model still
remembering what it named the session.

## Files

- `~/.claude/hooks/session-title.sh` — the hook script, one `case` per event.
- `~/.claude/repo-codes` — preferred codes, overriding the guess.
- `~/.claude/session-titles/<session id>` — recorded base title, minus any `#<n>` prefix. `<session id>.pr` holds the PR number already folded in.
- `~/.claude/settings.json` — registers all three under `hooks`.

## Pinning a project code

Append a `<repo name>  <CODE>` row to `~/.claude/repo-codes`. Repo name is the
directory name of the main checkout. Worth doing when the guess reads badly, runs
long, or collides with a code already in the list.

## Notes

- The state file doubles as the once-only gate on `UserPromptSubmit`. A session that never got named will be asked again on the next prompt rather than quietly keeping the app's auto-generated title.
- Recording strips a leading `#<n> `, so opening a second PR replaces the number instead of nesting into `#456 #123 Rename Sessions - D`.
- Deleting `~/.claude/session-titles/<session id>` makes a session ask for a fresh title on its next prompt.
