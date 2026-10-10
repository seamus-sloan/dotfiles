# session-title: per-worktree codes, and PR numbers from `gh pr view`

Session titles end in a short project code (`Rename Sessions - D`). Three gaps:

1. **Pin a code to one worktree.** `~/.claude/repo-codes` maps repo names to codes, so every worktree of a repo gets the same code. Let a row's first column be an absolute worktree path instead. `repo-code.sh` takes an optional second argument, the worktree path; when it's given and has a path row, that row beats the repo-name row. Claude Code's `session-title.sh` calls `repo-code.sh` with one argument and must keep working unchanged.
2. **Resolve the code per session.** The opencode plugin resolves the code once per plugin instance, but one instance serves every session opened under it, and those sessions can sit in different worktrees. Resolve it per session directory instead, and cache per directory. When a title already ends in a different code (the session moved worktrees), replace that code rather than stacking a second one.
3. **`gh pr view`.** Fold a PR number into the title when `gh pr view` prints a PR URL, as well as after `gh pr create`. This applies to both Claude Code's `session-title.sh` hook and the opencode plugin.
4. **Tests.** Add `node --test` coverage for the plugin's title logic in `tests/`.
