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

# Shorthand for `wt switch`. Every argument carries through, so the full
# vocabulary still works:
alias sw='wt switch'

# Remove every worktree and branch worktrunk reports as integrated — its changes
# already reach the default branch, including through a squash-merge or rebase
# where the commit history differs but the content matches.
#
# Local only. `wt remove` never touches a remote; `wt sync --prune` does the same
# cleanup but follows it with `git push <remote> --delete`, which would take out
# the remote branch of anything integrated locally while its PR is still open.
_fresh_prune_integrated() {
    if ! command -v jq >/dev/null; then
        print -u2 "fresh: jq not found — skipping integrated-branch cleanup"
        return 0
    fi

    # Pin the schema: worktrunk warns that a future release flips the JSON
    # default from 1 to 2, and the field moved (.main_state -> .display.state).
    # `--branches` includes branches with no worktree, which `wt remove` deletes
    # through its branch-only path.
    local -a integrated
    integrated=(${(f)"$(wt --config-set list.json-schema=2 list --format json --branches 2>/dev/null \
        | jq -r '.items[] | select(.display.state == "integrated") | .branch')"})
    (( ${#integrated} )) || return 0

    local b
    for b in $integrated; do
        # No -D and no -f: wt re-runs its own integration checks and refuses
        # anything that would lose work, dirty worktrees included.
        wt remove "$b"
    done
}

# Get up to date on a branch: fetch, hop to its worktree, fast-forward, drop any
# branch that has already landed, then rebase the stacked branches still alive.
#
#     fresh            # the repo's default branch (main or master)
#     fresh staging    # any other branch
#
# The cleanup runs before `wt sync` on purpose. `wt sync` rebases onto the local
# default branch, so a branch that merged upstream but hasn't been pruned gets
# treated as live work and rebased — which is how a merged branch turns into a
# rebase conflict. Fast-forwarding first, then dropping it, leaves sync nothing
# to trip over.
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
    _fresh_prune_integrated
    wt sync
}
