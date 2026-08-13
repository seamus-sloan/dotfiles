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

# Remove every worktree and branch whose commits already reach the default
# branch — through a squash-merge or rebase where the history differs but the
# content matches, or through a plain fast-forward.
#
# Local only. `wt remove` never touches a remote; `wt sync --prune` does the same
# cleanup but follows it with `git push <remote> --delete`, which would take out
# the remote branch of anything integrated locally while its PR is still open.
#
# The candidate set is deliberately wider than worktrunk's `integrated` state and
# then narrowed by reflog, because that state alone answers the wrong question.
# It asks "does this branch add anything main lacks?", so a scaffold branch — one
# `wt switch -c` created that has no commits yet — answers *no* and is reported as
# integrated the moment main advances past it and its worktree is clean. That is
# every branch an agent is mid-task on between edits, and pruning it deletes the
# worktree out from under the session. Conversely a branch merged by fast-forward
# lands on main's exact commit, which reads as `empty` rather than `integrated`,
# so the old filter left the one branch that really was finished.
#
# `git reflog` separates the two cases where the state cannot. A branch that has
# ever held a commit has a reflog entry beyond its `branch: Created from ...`
# line; a scaffold has only that one line. Expiry only ever shrinks a reflog, so
# an aged-out branch reads as a scaffold and is kept — the safe direction.
_fresh_prune_integrated() {
    if ! command -v jq >/dev/null; then
        print -u2 "fresh: jq not found — skipping integrated-branch cleanup"
        return 0
    fi

    # Pin the schema: worktrunk warns that a future release flips the JSON
    # default from 1 to 2, and the field moved (.main_state -> .display.state).
    # `--branches` includes branches with no worktree, which `wt remove` deletes
    # through its branch-only path.
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
        # Only ever consider a branch main already contains. `--is-ancestor`
        # catches the fast-forward case on its own; worktrunk's `integrated`
        # adds the squash- and rebase-merged ones, whose commits main holds
        # under different hashes.
        git merge-base --is-ancestor "$b" "$default_branch" 2>/dev/null \
            || print -r -- "$json" | jq -e --arg b "$b" \
                '.items[] | select(.branch == $b) | select(.display.state == "integrated")' >/dev/null \
            || continue

        # A branch that never held a commit is a scaffold someone is working in,
        # not finished work. Keep it.
        (( $(git reflog show "$b" 2>/dev/null | wc -l) > 1 )) || continue

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

# Pinned `z` destinations, checked before zoxide's own ranking.
#
# zoxide scores purely by frecency, so a keyword that appears in several visited
# paths lands wherever the score happens to be highest that week — `z mock`
# drifting between ~/Repos/mock-controller and platform's e2e
# mockControllerServer_v3 is exactly that. A pin makes the common ones fixed,
# and adds the short forms we say out loud (`mc`) that zoxide can't match at all,
# since it does substring matching rather than fuzzy initials.
#
# Keys must be the *entire* query, so nothing here narrows what plain zoxide can
# reach: `z mockcontrollerserver` still finds the e2e directory.
typeset -gA ZOXIDE_PINS=(
    mc          "$HOME/Repos/mock-controller"
    mock        "$HOME/Repos/mock-controller"
)

# Wraps the `z` that `zoxide init zsh` defines. That one is a thin shim over
# `__zoxide_z`, which is what this falls through to, so every non-pinned query —
# `z -`, `z foo bar`, bare `z` — behaves exactly as before. The chpwd hook zoxide
# installs still fires on the `cd` below, so pins keep earning frecency and stay
# near the top of `zi`.
#
# Must be sourced *after* `eval "$(zoxide init zsh)"` in ~/.zshrc, or init will
# clobber this definition.
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
