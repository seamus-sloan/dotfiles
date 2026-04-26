---
name: careful
description: Documents and manages the destructive-command guardrail hook at ~/.claude/hooks/careful.sh. The hook intercepts Bash tool calls and asks for confirmation on destructive patterns (rm -rf, git push --force, DROP TABLE, etc.) with a safe-list bypass. Triggers when the user asks to "enable careful mode", "disable careful mode", "what does careful do", "add a pattern to careful", or asks about destructive-command warnings.
---

# careful

A `PreToolUse` hook on the `Bash` tool that prompts before destructive commands. Always on once installed — no per-session toggle.

## What's protected

| Pattern | Example | Why |
|---|---|---|
| `rm -rf` / `rm -r` / `rm --recursive` | `rm -rf /var/data` | Recursive delete |
| `DROP TABLE` / `DROP DATABASE` / `DROP SCHEMA` | `DROP TABLE users;` | Data loss |
| `TRUNCATE TABLE` | `TRUNCATE orders;` | Data loss |
| `git push --force` / `-f` | `git push -f origin main` | History rewrite |
| `git reset --hard` | `git reset --hard HEAD~3` | Uncommitted work loss |
| `git checkout .` / `git restore .` | `git checkout .` | Uncommitted work loss |
| `jj abandon` / `jj op restore` | `jj abandon @` | Change loss / op-log rewrite |
| `kubectl delete` | `kubectl delete pod foo` | Production impact |
| `docker rm -f` / `docker system prune` | `docker system prune -a` | Container/image loss |

## Safe-list bypasses

These match the destructive patterns above but are known-fine and pass through without prompting:

```
rm -rf (node_modules|dist|.next|build|.cache|coverage|.turbo|__pycache__|target/debug|target/release|.parcel-cache|.nuxt|.svelte-kit)
```

## Files

- `~/.claude/hooks/careful.sh` — the hook script. Reads `tool_input.command` from stdin, prints a `hookSpecificOutput` JSON to stdout when it matches.
- `~/.claude/settings.json` — registers the hook under `hooks.PreToolUse` with `matcher: "Bash"`.

## Adding a pattern

Edit `~/.claude/hooks/careful.sh` and append to either `DESTRUCTIVE` (to add a new prompted pattern) or `SAFE` (to add a new bypass). Both are POSIX-extended-regex alternations passed to `grep -E`.

After editing, no restart needed — the hook script is read on each tool call.

## Removing a pattern

Same file — remove the alternation arm. To disable the hook entirely, delete the matching `PreToolUse` entry from `~/.claude/settings.json`.

## How it works

1. Claude invokes the `Bash` tool. Claude Code's harness calls every `PreToolUse` hook whose `matcher` matches.
2. `careful.sh` receives the full tool input as JSON on stdin.
3. If the command matches `SAFE` → exit silently → command proceeds.
4. If the command matches `DESTRUCTIVE` → print `hookSpecificOutput` with `permissionDecision: "ask"` → harness shows the user a confirmation prompt with the matched pattern as the reason.
5. Otherwise → exit silently → command proceeds.

The user can always override the prompt and let the command run.

## Hard rules

- **Never** rewrite the safe-list to be permissive (`rm -rf .*` etc.). Each bypass should be a specific, well-known build artifact directory.
- **Never** add a pattern to `SAFE` to silence a real warning — fix the underlying command instead.
- **Never** disable the hook to "just get past" a single confirmation. Approve the prompt and move on.
