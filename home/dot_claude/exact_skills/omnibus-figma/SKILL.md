---
name: omnibus-figma
description: House rules for working in the Omnibus Figma files through the figma-console MCP — auditing or cleaning up a file, renaming frames, checking a design's status against what shipped, building a comp or proposal section, and archiving or unpublishing a file or library. Use it whenever a task touches Omnibus DS · Foundations / Components, or any Omnibus Web · * file, even when the user only says "the Figma", "clean up the screens", "is this comp shipped", or "archive that file".
---

# Omnibus Figma

The Omnibus design lives in Figma, and its conventions live only inside those files. Agents that skip this page re-derive them, and they get them wrong: one audit flagged five "bad habits" and had to retract three, because summary-depth reads hid the very components that disproved them.

## The files

- **Omnibus DS · Foundations**: tokens, styles, icons and the Docs kit (`Docs/Header`, `Docs/Status`, `Docs/Note`, `Docs/Cover`). A published library.
- **Omnibus DS · Components**: every UI component. A published library.
- **Omnibus Web · Library & Shelves**, **Books & Browse**, **Reading**, **Account & Admin**: one page per surface. Each page holds a `Header`, a `Desktop · 1440` section, and `Tablet · 768` / `Phone · 390` sections where they apply.
- **Omnibus UI**: the pre-split original, deleted on 2026-10-27. Everything it held lives in the files above.

Map a file name to its key with `grep -aoE '"path":"/(file|design)/[A-Za-z0-9]{22}"[^}]{0,200}"title":"Omnibus[^"]*"' ~/.config/Figma/settings.json`.

## Reading vs writing

- **Reads never need the bridge.** `figma_get_file_data` reads any file over REST. `depth: 2` stops at sections; use `depth: 3`, or pass section `nodeIds`, to see frame names. Use `verbosity: "full"` on a node to see its instance and style references.
- **Writes need the Desktop Bridge plugin running in that exact file** (`figma_list_open_files`). Pass `fileKey` to `figma_execute` to target a connected file without moving the user's active file.
- Connecting the bridge is keyboard-only; the steps and the stop rule are in the `figma-bridge-restart` memory. If Actions won't open after one retry, stop and read over REST.

## House conventions

- **Frame names:** `Screen / State / Width`, e.g. `Library / Busy Household / 1440`. `Screen` is the page name (`Series Detail`, not `Series`). States are Title Case (`Default`, `Empty`, `Nothing In Progress`).
- **Page Header** (`Docs/Header` instance) carries the route as the eyebrow, a `Docs/Status` badge, a description, and a meta line: `<code path> · captured from main on <date>`, or `redesigned in #<PR>, updated <date>`. The meta line is a component property: edit it with `setProperties({[key]: value})`, where `key` is the `Meta#…` property. Don't edit the text node.
- **Status badges:** `Shipped` matches main, `In Review` waits on a decision, `Proposal` is an unbuilt exploration, `Draft` is in progress, and `Deprecated` is kept for reference. A deprecated proposal stays in the file on purpose.
- **Proposals** go in a `Proposal <n> · <name>` section on the surface's own page, under a `Proposals Header`. They never go in the `Desktop · 1440` section.
- **Two web clients ship:** Dioxus (`frontend/`) and React (`frontend-js/`). Each Header's code path says which one it captures, so a `Shipped` claim names its client.
- **Everything sits in a section.** Only sections, `Header` / `Proposals Header`, and `Cover` / `About` belong at a page's root.

## Audit checklist

An absence claim ("no capture record", "screens aren't componentized") needs a positive search, because summary reads drop exactly the fields that would disprove it. Before reporting a gap:

1. Read every page's `Header`: the code path, the capture date and the status badge.
2. Count instances and where their main components come from (`scripts/library-usage.js` with an empty key set lists them all). Layer names like `atrium`, `app-shell` or `span` are wrapper frames captured from the DOM; the design-system instances sit inside them.
3. Run `scripts/page-root-sweep.js` in every connected file.
4. Check frame names against the pattern in **all four** web files, not just one.
5. Only then name a gap, and say which of these steps found it.

## Status reconciliation

Before reporting or changing a design's status, check what has merged for that surface: `git -C ~/Repos/omnibus log --oneline origin/main --grep=<surface>`, along with its code path. If a proposal shipped, add the PR and date to the Proposals Header meta. Flip the badge only when the shipped client is the one the page captures. Otherwise say which client it shipped in, and leave the flip to the user.

## Renaming

Before dropping a name segment, read what it told the reader. A sample-data note such as `· Le Guin shown` can go. A real state (`menu open`, `all finished`) becomes the `State` segment. A storyboard's step numbers (`B1`, `B2`) stay when labels beside the frames cite them. Renaming has no downstream links to break, but it does change what reviewers search for, so list the renames in your reply.

## After a build or a failed `figma_execute`

A build that fails partway leaves its nodes at the page root, stacked at `0,0` on top of the `Header`. After any multi-node build, and after every failed one:

1. Run `scripts/page-root-sweep.js`. It returns IDs only and deletes nothing.
2. Look at what it found: confirm each node is debris (the finished frame holds its own copy).
3. Delete exactly the IDs you checked: `for (const id of IDS) (await figma.getNodeByIdAsync(id))?.remove()`. Don't re-select by a filter, or the check and the delete can cover different nodes.
4. Screenshot the page (`figma_capture_screenshot`) to confirm the Header is clear.

## What needs the user

The plugin API and REST can't rename a file, move it to a project, publish or unpublish a library, or change sharing. These are file-browser actions, so hand them to the user straight away, with the exact clicks, rather than connecting the bridge to try.

## Archiving a file or library

1. List what it publishes: `figma_get_library_components` with its `libraryFileKey`.
2. In every connected consumer file, run `scripts/library-usage.js` with those keys (`figma_execute_across_files` runs it in all of them at once). Name any consumer you couldn't reach.
3. Hand the user the steps, in this order:
   - Unpublish the library (Assets → Libraries → Unpublish). Figma warns if a file still links to it, which also covers any consumer you couldn't check and any styles from it.
   - Rename the file `[Archived] <name>`.
   - Optionally move it to an Archive project.
4. If the user says "page" rather than "file", ask which one they mean before acting.
