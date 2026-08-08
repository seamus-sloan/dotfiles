# Shared shell aliases — synced across machines via ~/Repos/dot-files.
#
# Source this from ~/.zshrc (which stays machine-local, since it holds
# per-machine PATH exports):
#
#     [ -f "$HOME/.config/shell/aliases.zsh" ] && source "$HOME/.config/shell/aliases.zsh"

# Flush the macOS DNS cache.
alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'

# Dotfiles sync — see ~/Repos/dot-files/sync.py for subcommands.
alias sync='python ~/Repos/dot-files/sync.py'

# Get up to date on a branch: fetch, hop to its worktree, fast-forward, then
# rebase any stacked branches on top.
#
#     fresh            # the repo's default branch (main or master)
#     fresh staging    # any other branch
#
# Defined as a function rather than an alias so it can take an argument and so
# it calls worktrunk's `wt` shell function (which is what makes `switch` cd).
unalias fresh 2>/dev/null   # drop the older jj-era alias if a stale ~/.zshrc still defines it
fresh() {
    # `^` is worktrunk's shortcut for the repo's default branch.
    local branch="${1:-^}"
    git fetch --prune || return
    wt switch "$branch" || return
    git pull --ff-only || return
    wt sync
}
