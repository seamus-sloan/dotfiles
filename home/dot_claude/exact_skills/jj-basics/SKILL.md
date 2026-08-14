---
name: jj-basics
description: Core jj workflow — fetch, status, new change, describe, bookmark, push. Triggers when the user asks to commit, push, create a branch/bookmark, or perform routine version-control operations.
---

# jj basics

Use [jj](https://github.com/martinvonz/jj) instead of plain git. jj sits on top of the same git storage, so remotes, pushes, and fetches all go through `jj git ...`.

## Hard rule: never amend a pushed commit

jj **auto-snapshots the working copy into `@` on every command**. If `@` is the same commit as a bookmark that's already pushed to origin, your next edit silently rewrites that commit — and `jj git push` force-moves the bookmark sideways, which counts as a force push.

**Before any edits, run `jj new <bookmark>` to stack a new commit on top — even if the working copy is clean.** This is mandatory whenever:

- You're returning to a branch with an existing PR to address review feedback.
- A previous task pushed the bookmark and the user is asking for follow-up changes.
- You ran `jj edit <bookmark>` to inspect the commit and now want to change something.
- You rebased the bookmark and want to add fixes on top.

The cheap discipline:

```bash
jj log -r @ -T 'bookmarks ++ " " ++ commit_id.shortest(8)'   # what is @ pointing at?
jj new <bookmark>                                            # stack a new empty commit
# ...edit files...
jj describe -m "fix: ..."
jj bookmark move <bookmark> --to @
jj git push -b <bookmark>                                    # fast-forward push, no force
```

If `jj git push` ever announces `Move sideways bookmark <name> from <old> to <new>`, that means the bookmark commit hash changed — i.e. you amended a pushed commit. Stop and check whether you should have done `jj new` first.

## Branch naming

- Personal branches: `u/<last_name>/<feat_name>` (e.g. `u/sloan/fix-failing-tests`).
- Issue branches: `<issue_number>/<branch_name>` (e.g. `AE-6/add-more-things`).

## Commits

Use [conventional commits](https://www.conventionalcommits.org/) with only these prefixes: `feat`, `fix`, `chore`. No scopes like `docs(...)`, `refactor(...)`, etc.

## Daily workflow

```bash
jj git fetch                                      # pull latest
jj st                                             # check working copy
jj new main                                       # start a new change off main
jj bookmark create ADA-323/my-feature             # create the bookmark
jj describe -m "feat: add my feature"             # describe the change
# ...edit files...
jj bookmark move ADA-323/my-feature --to @        # move bookmark to current change
jj git push                                       # push to origin
```

## Multi-commit work

After each logical commit:

```bash
jj describe -m "chore: ..."
jj bookmark move ADA-323/my-feature --to @
jj new                                             # start the next change on top
```

## Continuing work on an already-pushed branch

When the user asks for changes on a branch that already has a remote (e.g. PR review fixes), the very first action is `jj new <bookmark>` — *not* editing files. Skipping this and editing directly amends the pushed commit and forces the next push.

```bash
jj git fetch                                       # pull latest origin state
jj new u/sloan/my-feature                          # stack a new empty commit on the pushed tip
# ...edit files...
jj describe -m "fix: address review"
jj bookmark move u/sloan/my-feature --to @
jj git push -b u/sloan/my-feature                  # fast-forward push
```

## Useful one-liners

```bash
jj log -r 'main..@'                                # see all changes since main
jj diff                                            # show uncommitted diff
jj --help                                          # or `jj <cmd> --help` for more
```

## Pushing rewritten history (rebases, squashes, amends)

- `jj bookmark move <name> --to @` **refuses** to move a bookmark sideways or backwards relative to the remote. For that (e.g. after rebasing a PR branch onto a new base), add `--allow-backwards`.
- `jj git push --bookmark <name>` **does not need a flag** to push sideways/backwards moves. It announces the move with output like `Changes to push to origin: Move sideways bookmark <name> from <old> to <new>` — that line IS the successful push, not a dry run. Don't re-run the command to "confirm."
- Re-running `jj git push` after a successful push reports `Bookmark <name>@origin already matches <name>. Nothing changed.` — that confirms the earlier push landed; it is not an error.

For rebase / squash / conflict resolution / undo, see [jj-advanced](../jj-advanced/SKILL.md). For parallel agent work, see [jj-workspaces](../jj-workspaces/SKILL.md).
