---
name: jj-basics
description: Core jj workflow — fetch, status, new change, describe, bookmark, push. Triggers when the user asks to commit, push, create a branch/bookmark, or perform routine version-control operations.
---

# jj basics

Use [jj](https://github.com/martinvonz/jj) instead of plain git. jj sits on top of the same git storage, so remotes, pushes, and fetches all go through `jj git ...`.

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
