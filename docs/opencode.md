# opencode

opencode is the agent I use at work; Claude Code is the one I use personally. The
goal here is one set of rules, skills, and commands driving both, so a habit
learned in one shows up in the other.

Most of that is free: opencode ships Claude Code compatibility and reads
`~/.claude` directly. The rest of this page is the parts that needed wiring, and
the parts that can't be shared at all.

## Reused as-is

opencode discovers these itself. Nothing in this repo points at them.

| What | Where | How opencode finds it |
|---|---|---|
| Global instructions | `~/.claude/CLAUDE.md` | Fallback for `~/.config/opencode/AGENTS.md` |
| Skills | `~/.claude/skills/`, `~/.agents/skills/` | Both scanned natively alongside `~/.config/opencode/skills/` |

Two things follow from that:

- **Don't create `~/.config/opencode/AGENTS.md`.** It *replaces* `~/.claude/CLAUDE.md` rather than merging with it, so the moment it exists the Claude Code instructions stop loading. Use the `instructions` array in `opencode.jsonc` if extra files are ever needed.
- **Don't symlink `skills/` into the opencode config dir.** opencode already reads `~/.claude/skills/`, and it requires skill names to be unique across every location — a second path to the same directory makes every skill a duplicate.

`~/.claude/CLAUDE.md` does carry two lines opencode ignores: `@RTK.md` and the
`@skills/open-pr/SKILL.md` reference. opencode does not expand `@` references in
instruction files, so those read as literal text there.

## Wired up in this repo

| What | Claude Code | opencode |
|---|---|---|
| Commands | `~/.claude/commands/*.md` | `symlink_commands` → `~/.claude/commands`; no native fallback, and the `$ARGUMENTS` / `$1` / `@file` / `` !`cmd` `` syntax is compatible |
| Destructive-command guard | `hooks/careful.sh` (`PreToolUse`) | `permission.bash` rules in `opencode.jsonc` |
| Session titles | `hooks/session-title.sh` (`UserPromptSubmit` + `PostToolUse`) | `plugins/session-title.js` |
| Project codes | `~/.claude/repo-codes` | same file, via the shared `hooks/repo-code.sh` |

### Destructive-command guard

Claude Code's hook returns `permissionDecision: "ask"` from `PreToolUse`.
opencode has a `permission.ask` plugin hook, but it fires *after* the config
ruleset has already decided to ask — a plugin cannot escalate an
already-allowed call. So the patterns are expressed as native
`permission.bash` rules instead.

Consequences of the swap:

- Rules are glob patterns, not regex. `*DROP TABLE*` needs a lowercase twin because the matcher is case-sensitive.
- The last matching rule wins, so ordering is load-bearing: blanket `allow`, then the destructive patterns, then the safe-list that pulls `node_modules`-style build output back out.
- No custom reason string on the prompt. opencode shows which command matched, which covers most of what the hook's reason line said.

Keep the rule list and `careful.sh` in sync when either changes.

### Session titles

Both tools aim for the same title shape:

```
<Objective> - <CODE>          →   #123 <Objective> - <CODE>   once a PR exists
```

They get there differently. Claude Code cannot rename a session from a hook, so
`session-title.sh` injects `additionalContext` asking the model to call the
`set_session_title` MCP tool. opencode already auto-generates an
objective-shaped title and exposes `session.update` over its SDK, so the plugin
waits for that title and rewrites it deterministically — no model round-trip, no
tokens.

The shared piece is the code lookup, extracted into
`~/.claude/hooks/repo-code.sh`. Given a directory it prints the repo's short
code, preferring a row in `~/.claude/repo-codes` and otherwise guessing from the
repo name's initials. It resolves `--git-common-dir`, so a worktree at
`~/worktrees/dotfiles/<branch>` still reports `dotfiles`.

## Not shared

| What | Why |
|---|---|
| `statusline-command.sh` | opencode's TUI has no statusline hook. |
| `enabledPlugins` / `extraKnownMarketplaces` | Different ecosystem. opencode takes npm packages in `plugin[]`; the Chrome DevTools and GitHub plugins map to MCP servers instead. |
| `effortLevel`, `model`, `includeCoAuthoredBy` | Claude-Code-specific settings. opencode's equivalents live in `opencode.jsonc` (`model`, and per-model `variants`). |

## Generated files

opencode writes `package.json`, `bun.lock`, `node_modules/`, and a `.gitignore`
into `~/.config/opencode` to install plugin dependencies. All four are listed in
`home/.chezmoiignore` so `chezmoi add ~/.config/opencode` can't pull them in.
`plugins/session-title.js` is deliberately plain JavaScript with a JSDoc type
annotation rather than TypeScript, so it needs none of them to run.
