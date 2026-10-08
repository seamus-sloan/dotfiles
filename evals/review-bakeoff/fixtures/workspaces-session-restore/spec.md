# workspaces: recent-first picker, session restore, and `:Workspace <name>`

`lua/custom/plugins/workspaces.lua` gives every repo its own tab. Four additions:

1. **Recent first.** The `<leader>ww` picker lists the 10 most recently opened projects first, most recent at the top, then the rest alphabetically. Recency persists across restarts in a state file under `stdpath('state')`.
2. **Restore.** On quit, remember which repo tabs were open, in tab order. `:WorkspaceRestore` and `<leader>wr` reopen them, each in its own tab and without the file picker, skipping any that no longer exist.
3. **`:Workspace <name>`.** Open a project by its picker name, with completion. A unique partial name also works; an unknown or ambiguous name is an error.
4. **Safer close.** `<leader>wq` asks before closing a tab with unsaved changes, and keeps refusing to close the last tab.

State writes go to a temp file that's renamed into place, so a crash can't leave a truncated state file. Add headless tests that run with `nvim --headless -l <file>`.
