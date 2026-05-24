---
name: jj-workspaces
description: Standing jj workspaces (default + xray + yankee + zulu) for running multiple agents in parallel on one repo. Triggers when the user names a workspace ("use Zulu", "in Yankee"), asks to parallelize work, or asks to spin up a workspace.
---

# jj workspaces

For parallel agent work on a jj-driven repo, use **jj workspaces** instead of the Agent tool's `isolation: "worktree"` (which creates a git worktree). jj workspaces share the same `.jj/` store, so bookmarks and changes made in one workspace are **immediately visible** from the main workspace — no marshalling required.

## Standing workspace convention (read this first)

Every jj-driven project has four long-lived workspaces — one `default` plus three siblings:

| Workspace | Path                  |
|-----------|-----------------------|
| `default` | `<project>/`          |
| `xray`    | `<project>-xray/`     |
| `yankee`  | `<project>-yankee/`   |
| `zulu`    | `<project>-zulu/`     |

These **already exist**. They're permanent — do not create, delete, or rename them as part of normal work. Confirm with `jj workspace list` if unsure. If one is genuinely missing for a brand-new project, create with:

```bash
jj workspace add ../<project>-xray   --name xray   -r main
jj workspace add ../<project>-yankee --name yankee -r main
jj workspace add ../<project>-zulu   --name zulu   -r main
```

## When the user names a workspace

The user picks the workspace deliberately so they can run **another agent in a different workspace concurrently**. Treat the name as a hard routing instruction:

1. **`cd` into the named workspace's directory** and do all work there. Do not switch back to `default` mid-task.
   - "Use Zulu" / "in the Zulu workspace" / "do this in Yankee" → `cd ~/Repos/<project>-zulu` (or `-yankee`, etc.).
2. **Do not create a new workspace** for the task. The named one already exists; reuse it. If `jj workspace list` doesn't show it, ask before creating — it may just be stale-op or the user may have meant a different project.
3. **Do not delegate to subagents that each spawn their own workspace.** If the task fans out, all subagents must operate inside the *same* named workspace (or be told to stay out of jj entirely and only read files). The whole point of the user naming the workspace is to keep this turn's work confined to one slot so the other slots remain free for their other concurrent agents.
4. **Do not touch the other standing workspaces** unless asked. If you need to inspect them (e.g. "what is Yankee working on?"), `jj log` from the named workspace already shows `<name>@` markers for all of them — no need to cd around.

If the user does *not* name a workspace, stay in `default` unless the task explicitly calls for parallelism.

## Entering a workspace cleanly

Before starting edits, land on a fresh empty change on `main`:

```bash
cd ~/Repos/<project>-<name>
jj new main
```

If `jj` errors with **"The working copy is stale"** or **"sibling of the working copy's operation"**, the workspace's op log diverged because another workspace ran commands. Recover:

```bash
jj workspace update-stale   # fixes the common case; usually enough
# if that still complains: jj op integrate <op-id-from-hint>
```

After `update-stale`, jj prints `Shell cwd was reset to ...` — that's expected and harmless; just `cd` back if needed and continue.

## Commands

```bash
jj workspace list              # show all workspaces and their current @
jj workspace add <path> --name <name> -r <rev>   # only for brand-new projects
jj workspace forget <name>     # only for ghost workspaces (see below)
```

## Inside a workspace

`jj log` inside any workspace shows the other workspaces' working copies as `<name>@` markers, so you can see what each parallel agent is doing without leaving your workspace.

## Cleanup

The four standing workspaces are **long-lived**. Do not propose `jj workspace forget` or `rm -rf` on them as housekeeping — the user will recreate them immediately. Clean *inside* the workspace (`cargo clean`, prune caches) instead.

**Exception — orphans:** if `jj workspace list` shows a name whose directory no longer exists on disk (check with `find ~/Repos -maxdepth 3 -name .jj -type d`), it's a ghost. `jj workspace forget <name>` is the right call — confirm with the user first, then forget.
