# Shared shell aliases — synced across machines via chezmoi (~/Repos/dotfiles).
#
# Source this from ~/.zshrc (which stays machine-local, since it holds
# per-machine PATH exports):
#
#     [ -f "$HOME/.config/shell/aliases.zsh" ] && source "$HOME/.config/shell/aliases.zsh"

# go install's default GOPATH is the same on every machine.
export PATH="$HOME/go/bin:$PATH"

# Flush the DNS cache: macOS's resolver, or systemd-resolved on Linux.
if [[ $OSTYPE == darwin* ]]; then
    alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
else
    alias flushdns='resolvectl flush-caches'
fi

alias sw='wt switch'

# Locally remove worktrees and branches already in the default branch, keeping fresh scaffolds.
_fresh_prune_integrated() {
    if ! command -v jq >/dev/null; then
        print -u2 "fresh: jq not found — skipping integrated-branch cleanup"
        return 0
    fi

    # Schema pinned ahead of worktrunk's default flip; --branches adds worktree-less ones.
    local json
    json="$(wt --config-set list.json-schema=2 list --format json --branches 2>/dev/null)" || return 0

    local default_branch
    default_branch=$(print -r -- "$json" | jq -r '.items[] | select(.display.state == "is_main") | .branch')
    [[ -n $default_branch ]] || return 0

    local -a candidates
    candidates=(${(f)"$(print -r -- "$json" \
        | jq -r --arg main "$default_branch" \
            '.items[] | select(.branch != $main) | .branch')"})

    local b
    for b in $candidates; do
        # Already in the default branch: --is-ancestor for fast-forwards, `integrated` for squash and rebase.
        git merge-base --is-ancestor "$b" "$default_branch" 2>/dev/null \
            || print -r -- "$json" | jq -e --arg b "$b" \
                '.items[] | select(.branch == $b) | select(.display.state == "integrated")' >/dev/null \
            || continue

        # Never held a commit: a scaffold someone is working in.
        (( $(git reflog show "$b" 2>/dev/null | wc -l) > 1 )) || continue

        # No -D or -f: wt refuses anything that would lose work.
        wt remove "$b"
    done
}

# Fetch, fast-forward, prune landed branches, then rebase live stacks.
#     fresh            # the repo's default branch
#     fresh staging    # any other branch
fresh() {
    # `^` is worktrunk's shortcut for the repo's default branch.
    local branch="${1:-^}"
    git fetch --prune || return
    wt switch "$branch" || return
    git pull --ff-only || return
    _fresh_prune_integrated
    wt sync
}

# Fixed `z` destinations checked before frecency; a key must match the whole query.
typeset -gA ZOXIDE_PINS=(
    mc          "$HOME/Repos/mock-controller"
    mock        "$HOME/Repos/mock-controller"
)

# Pins first, then zoxide's own z; source after `zoxide init zsh` or it's clobbered.
z() {
    if (( $# == 1 )) && [[ -n ${ZOXIDE_PINS[$1]-} ]]; then
        local dest=${ZOXIDE_PINS[$1]}
        if [[ ! -d $dest ]]; then
            print -u2 "z: pinned '$1' -> $dest (no such directory)"
            return 1
        fi
        __zoxide_cd "$dest"
        return
    fi
    __zoxide_z "$@"
}
