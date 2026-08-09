# dot-files

Tracked dotfiles synced between this repo and `$HOME` by `sync.py`. See the
`TRACKED` list in [sync.py](sync.py) for what's under management.

```
python sync.py install [--dry-run] [--force]   # repo -> ~
python sync.py save    [--dry-run]             # ~    -> repo
python sync.py fetch                           # git pull + dry-run install
python sync.py commit                          # save + git commit/push
```

`install` prompts before deleting anything from `~` — files present locally
but absent from the repo are usually un-`save`d work, not deletions. Declining
keeps them and still syncs everything else; `--force` skips the prompt.
Deletions toward the repo (`save`) stay unprompted since git can restore them.

## Per-machine setup

`~/.zshrc` is deliberately **not** tracked — it holds machine-specific `PATH`
exports (homebrew, nvm, Miniforge) that shouldn't be overwritten. Shared aliases
live in the tracked `.config/shell/aliases.zsh` instead, so each new machine
needs these two lines appended to its `~/.zshrc` once:

```sh
echo "\n# Claude Sync\nalias sync='python ~/Repos/dot-files/sync.py'\n" >> ~/.zshrc
echo '[ -f "$HOME/.config/shell/aliases.zsh" ] && source "$HOME/.config/shell/aliases.zsh"' >> ~/.zshrc
```

After that, `python sync.py install` keeps the aliases themselves up to date.
You don't have to remember the second line — `install` prints it as a reminder
whenever `~/.zshrc` isn't sourcing the aliases yet, and stays quiet once it is.

## Aliases

| Alias | What it does |
| --- | --- |
| `flushdns` | Flush the macOS DNS cache. |
| `sync` | Shorthand for `python ~/Repos/dot-files/sync.py`. |
| `sw [args]` | Shorthand for `wt switch`. All arguments pass through: `sw` for the picker, `sw main` for an existing worktree, `sw -c feature` to create one. |
| `fresh [branch]` | Fetch, switch to the branch's worktree, fast-forward it, remove every worktree and branch that has already landed, then `wt sync` whatever stack is left. Defaults to the repo's default branch (`main` or `master`); `fresh staging` targets any other branch. Cleanup is local only and defers to worktrunk's own integration check, so squash-merged branches are caught and anything holding unmerged work is refused. Needs `jq`; without it the cleanup step is skipped with a warning. |
