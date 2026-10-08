# Answer key — workspaces-session-restore

Never show this file to a reviewer. Paths are relative to `home/dot_config/exact_nvim/lua/custom/plugins/` in the fixture worktree; `ws` is `workspaces.lua` and `spec` is `workspaces_spec.lua`. `verify-seeds.sh` reproduces every row.

Buckets: **bug** (any good reviewer should find it from the code alone), **spec** (needs the spec to see), **test** (test quality), **excess** (code the change doesn't need), **unplanted** (a real issue nobody planted, found by an earlier run and verified; the pool grows as runs find more).

| ID | Bucket | Category | Location | Defect | Credit when a finding says |
|---|---|---|---|---|---|
| C1 | bug | language-pitfall | `ws:37-39` | `vim.fn.filereadable()` returns `0`, which is truthy in Lua, so with no state file (the first run) `io.open` returns nil and `f:read` errors; the picker, `M.open` and the quit autocmd all crash | `0` is truthy / the guard never fires / `f` is nil with no state file |
| C2 | bug | correctness | `ws:70-72` | the cap trims with `table.remove(state.recent, 1)`, which drops the entry just inserted at the front, so once 10 are recorded the newest open is lost and recency freezes | trims the wrong end / removes the newest instead of the oldest |
| C3 | bug | removed-behavior | `ws:310-317` | the rewrite of `M.close` dropped the last-tab guard, so `<leader>wq` on the only tab raises `E784`; the spec says it must keep refusing | the last-tab check was removed / `tabclose` on the last tab errors |
| C4 | bug | language-pitfall | `ws:312` vs `ws:331` | `M.close` calls `tab_modified`, a `local function` defined further down the file, so the name resolves to an undefined global and `<leader>wq` always errors | `tab_modified` isn't in scope / it's nil at that point / forward reference to a later local |
| C5 | bug | language-pitfall | `ws:249-257` | `restore` sets missing paths to `nil` in place, and the second `ipairs` (and `#paths`) stops at the first hole, so one deleted repo early in the list blocks restoring the rest | nil holes break `ipairs` / `#` on a table with holes / later tabs aren't restored |
| C6 | bug | language-pitfall | `ws:267` | `name:find(query)` treats the query as a Lua pattern: `-` is a quantifier and `.` matches anything, so a partial name with a hyphen never matches and dotted names over-match | Lua pattern magic characters / should pass `plain = true` |
| C7 | bug | concurrency | `ws:63-74`, `ws:257` | each `record_recent` reads the state synchronously and saves asynchronously, so `restore` opening several tabs in one tick reads the same stale state each time and the saves clobber each other (and share one `.tmp` path); only the last open survives | lost updates / read-modify-write race across async saves / shared temp file |
| C8 | bug | cross-file | `spec` (whole file), `init.lua:7-12` | the test lives in `lua/custom/plugins/`, and `custom/plugins/init.lua` (not in the diff) requires every `.lua` file there at startup, so every nvim launch runs the suite, which rewrites `$HOME` and calls `os.exit` | the plugins loader requires every file in that directory / the test runs at startup / `os.exit` kills nvim |
| C9 | spec | plan-gap | `ws` keymaps | the spec's `<leader>wr` keymap is missing; only `:WorkspaceRestore` exists | no `<leader>wr` mapping |
| C10 | test | hollow-test | `spec:76-81` | the cap test asserts only `#recent <= 10`, so it passes through C2 (and through C7, which leaves one entry) | the test checks length only / it never checks which entries are kept |
| C11 | excess | speculative-scope | `ws:26-34` | `STATE_VERSION` and `migrate()` for a format that has only ever had one version | the migration hook is unneeded / dead code |
| CU1 | unplanted | correctness | `ws:380-387` | `VimLeavePre` always overwrites `tabs`, so any quit without repo tabs (a commit-message nvim, a quick `nvim file`) erases the restore list | quitting without repo tabs wipes the saved tabs / last quit wins |
| CU2 | unplanted | correctness | `ws:219-223` | jumping to an already-open repo returns before `record_recent`, so re-picking it doesn't bump its recency | an already-open repo isn't moved to the front |
| CU3 | unplanted | correctness | `ws:52-58` | write and close errors are ignored and the temp file is renamed regardless, so a failed or short write replaces the state file | write errors are swallowed / a partial temp file is renamed in |
| CU4 | unplanted | correctness | `ws:313` | `&Close` and `&Cancel` share the hotkey `c`, so pressing `c` always picks Close | the two choices share an accelerator |
| CU5 | unplanted | correctness | `ws:219-226`, `ws:257` | restoring the repo nvim was launched in matches the startup tab by its global cwd and jumps to it without a `:tcd`, so that repo drops out of the next save | the launch repo isn't re-`:tcd`'d / falls out of later saves |
| CU6 | unplanted | correctness | `ws:236-243` | a plugin's own tab-local `:tcd` (neo-tree's, for one) counts as a repo tab, so it's saved and reopened on restore | any `:tcd` is treated as a repo tab |
| CU7 | unplanted | correctness | `ws:222-224` | `M.open` records the normalised path but tabs report a symlink-resolved `getcwd`, so a symlinked project leaves a recent entry that never matches | symlinked paths don't match `getcwd` |
| CU8 | unplanted | correctness | `ws:398-402` | completion offers prefix matches only, while `:Workspace` matches substrings | completion and matching disagree |
| CU9 | unplanted | test | `spec:83` | `os.exit` skips cleanup, so every test run leaves its temp HOME behind | the temp dir leaks |
| CU10 | unplanted | test | `spec:64-70` | the exact-name test passes even with the exact-match branch deleted, so it doesn't pin the precedence | the test can't tell exact from partial matching |
| CU12 | unplanted | concurrency | `ws:52-58` | overlapping saves open the same `.tmp` path, so their writes interleave and the renamed file can be corrupt JSON (separate from C7's lost update) | the shared temp file can end up corrupt |
| CU13 | unplanted | correctness | `ws:41-45` | a JSON `null` decodes to `vim.NIL`, which is truthy, so `state.recent or {}` keeps it and `ipairs` crashes on a hand-edited file | `vim.NIL` survives the `or {}` default |
| CU11 | unplanted | excess | `ws:51-59` | the async callback chain buys nothing here; a synchronous write removes C7 and the spec's `settle()` waits | the save could be synchronous |

## Decoys

Correct code that looks suspicious. A finding that calls one of these a defect is FALSE.

- `ws:66-68`: removing from `state.recent` while looping is safe, because the loop runs backwards.
- `ws:52-57`: renaming the temp file over the state file is atomic, because both sit in the same directory.
- `ws:240`: `haslocaldir(-1, tabnr) == 1` is the documented way to test for a tab-local `:tcd`.

Not seeded but acceptable as valid extras when argued concretely: the `fs_open` error is swallowed silently; `find_tab` compares a normalised path with a `getcwd` that resolves symlinks.
