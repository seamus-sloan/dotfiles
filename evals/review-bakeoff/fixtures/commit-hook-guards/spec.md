# Commit hooks: subject cap, tickets through rebases, and a skip switch

The global git hooks in `home/dot_config/private_git/exact_hooks/` need three changes.

1. **Subject length.** `commit-msg` rejects a subject longer than 72 characters; exactly 72 is fine. The error names the length and the limit. Merge, revert, `fixup!`, `squash!` and `amend!` subjects stay exempt, as today.
2. **Tickets through rebases.** HEAD is detached for the whole of a rebase, so `branch_ticket` finds nothing and `prepare-commit-msg` silently drops the `Refs:` trailer on every reworded or edited commit. While a rebase is in progress, `branch_ticket` should use the branch being rebased, which git records under the git dir as `rebase-merge/head-name` (interactive and merge backends) or `rebase-apply/head-name` (apply backend). `pre-commit` gets the same fallback through the shared helper.
3. **Skip switch.** `GIT_TICKET_SKIP=1` turns off all ticket handling for one commit, in both `pre-commit` (the prefix check) and `prepare-commit-msg` (the trailer), for a one-off commit on a misnamed branch. Gitleaks still runs.
4. **Tests.** Add `tests/git-hooks.sh`, a plain `sh` script that exercises the subject cap and the rebase fallback in a throwaway repo and exits non-zero on any failure.
