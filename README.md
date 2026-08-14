# dotfiles

[![chezmoi](https://img.shields.io/badge/managed%20with-chezmoi-blue?logo=chezmoi&logoColor=white)](https://chezmoi.io)
[![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white)](#)
[![Neovim](https://img.shields.io/badge/Neovim-57A143?logo=neovim&logoColor=white)](#neovim)
[![zsh](https://img.shields.io/badge/shell-zsh-orange)](#shell)

My macOS dotfiles, managed with [chezmoi](https://chezmoi.io). Config is
identical on every machine — no templating, no secrets, just files.

<!-- TODO: drop a terminal screenshot at docs/assets/terminal.png and uncomment:
![terminal](docs/assets/terminal.png)
-->

## What's inside

| Tool | Config | Notes |
|---|---|---|
| **Neovim** | [`home/dot_config/exact_nvim`](home/dot_config/exact_nvim) | [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)-based; this repo is the canonical copy |
| **Git** | [`home/dot_gitconfig`](home/dot_gitconfig), [`home/dot_config/private_git`](home/dot_config/private_git) | Global hooks enforce ticket-prefixed branches and auto-link commits to GitHub issues |
| **Shell** | [`home/dot_config/shell`](home/dot_config/shell) | Shared zsh aliases, sourced from a machine-local `~/.zshrc` |
| **Worktrunk** | [`home/dot_config/worktrunk`](home/dot_config/worktrunk) | [`wt`](https://worktrunk.dev) config for worktree-per-branch workflow |
| **Claude Code** | [`home/dot_claude`](home/dot_claude) | Global instructions, skills, hooks, and statusline |

## Layout

```
.
├── .chezmoiroot          # tells chezmoi the source tree lives in home/
├── docs/
└── home/                 # mirrors $HOME in chezmoi source notation
    ├── .chezmoi.toml.tmpl        # records the clone location on init
    ├── .chezmoiscripts/          # run-once machine bootstrap
    ├── dot_gitconfig             # → ~/.gitconfig
    ├── dot_claude/               # → ~/.claude  (instructions, skills, hooks)
    └── dot_config/               # → ~/.config
        ├── exact_nvim/           #   full-mirror: deletions propagate
        ├── private_git/exact_hooks/  # global hooks (executable_ = +x)
        ├── shell/
        └── worktrunk/
```

`exact_` directories are fully mirrored — files deleted from the repo are
deleted from `$HOME` on apply. Everything else is add/update only.

## Install (new machine)

```sh
brew install chezmoi
git clone git@github.com:seamus-sloan/dotfiles.git ~/Repos/dotfiles
chezmoi init --source ~/Repos/dotfiles --apply
```

`init` writes `~/.config/chezmoi/chezmoi.toml` pointing at the clone, so every
later `chezmoi` command works without `--source`.

## Daily use

| I want to… | Run |
|---|---|
| Preview what would change | `chezmoi diff` |
| Apply the repo to this machine | `chezmoi apply` |
| Pull latest and apply | `chezmoi update` |
| Capture edits made to live files | `chezmoi re-add` |
| Start managing a new file | `chezmoi add ~/.config/foo` |
| Jump to the repo | `chezmoi cd` |

Edits can start from either end: change the source file and `chezmoi apply`,
or change the live file and `chezmoi re-add`. Commit and push from the repo
like any other project.
