# Answer key — session-title-worktree-codes

Never show this file to a reviewer. Paths are relative to the fixture worktree; `plugin` is `home/dot_config/opencode/plugins/session-title.js`, `repo-code.sh` and `session-title.sh` live in `home/dot_claude/exact_hooks/` (as `executable_*`). `verify-seeds.mjs` reproduces every row.

Buckets: **bug** (any good reviewer should find it from the code alone), **spec** (needs the spec to see), **test** (test quality), **excess** (code the change doesn't need), **unplanted** (a real issue nobody planted, found by an earlier run and verified; the pool grows as runs find more).

| ID | Bucket | Category | Location | Defect | Credit when a finding says |
|---|---|---|---|---|---|
| B1 | bug | correctness | `repo-code.sh:55-56` | one `awk` pass exits on the first matching row, so a repo-name row above a path row wins; the header comment says the path row must win | the first match wins regardless of row type / path rows don't take priority |
| B2 | bug | wrong-variable | `plugin:127` | `worktree ?? session.directory`: opencode always passes `worktree`, so the session's own directory is never used and every session gets the instance's code | the `??` operands are reversed / `worktree` always wins / per-session resolution never happens |
| B3 | bug | removed-behavior | `plugin:58` | a failed lookup is cached as `""` forever; the old code cleared the cache on failure so the next event retried | failures are cached permanently / no retry after a lookup error |
| B4 | bug | security | `plugin:75` | `execFile` with an argv array became `exec` with an interpolated string: directories with spaces split, and shell metacharacters in a path run as commands | shell injection / spaces break the path / should stay `execFile` with argv |
| B5 | bug | language-pitfall | `plugin:83-85` | `search()` returns `-1` on no match, which `!at` doesn't catch, so `slice(0, -1)` chops the last character off every unsuffixed title, and the placeholder title gets a code again | `-1` isn't handled / the last character is dropped / should check `at === -1` or `at < 0` |
| B6 | bug | cross-file | `repo-code.sh:21` | `WORKTREE="$2"` under `set -u` aborts one-argument calls, so `session-title.sh` (not in the diff) gets no code | `$2` is unbound under `set -u` / one-arg callers break |
| B7 | test | hollow-test | `tests/session-title.test.mjs:53` | the per-directory test never passes `worktree`, the case opencode always hits, so it stays green through B2 | the test omits `worktree` / it can't catch the precedence bug |
| B8 | spec | plan-gap | `session-title.sh:111` | the spec's `gh pr view` fold was only added to the plugin; Claude Code's hook still matches `gh pr create` only | `session-title.sh` wasn't updated for `gh pr view` |
| B9 | excess | dead-code | `plugin:62-68` | `CodeCache.clear()` and `.size` have no callers; a two-line `Map` would do | `clear` / `size` are unused / the class is more than it needs |
| BU1 | unplanted | removed-behavior | `plugin:130-134` | dropping the `endsWith(suffix)` guard means a fresh plugin instance (after a restart, `folded` empty) rewrites `#42 Title - D` and strips the PR prefix | a restart drops the `#N` prefix |
| BU2 | unplanted | correctness | `plugin:127-137` | every title the plugin didn't write is rebuilt with the folded number, so a user's edit to the `#N` prefix is reverted at once | user edits to the prefix are undone |
| BU3 | unplanted | correctness | `plugin:142-147` | `gh pr view <other>` folds that unrelated PR's number into this session's title | viewing any PR folds its number |
| BU4 | unplanted | correctness | `plugin:146` | `match()` takes the first PR URL anywhere in `gh pr view` output, which can come from the body or comments | the first URL may not be this PR's |
| BU5 | unplanted | correctness | `plugin:38` | `CODE_SUFFIX` matches only 1–3 capitals, so codes with digits or more letters aren't stripped and stack | digit/long codes stack |
| BU6 | unplanted | correctness | `plugin:38`, `plugin:130` | `CODE_SUFFIX` takes a real trailing acronym (` - UI`, ` - CI`) for a code and replaces it | real acronyms get stripped |
| BU7 | unplanted | correctness | `plugin:140-158` | `tool.execute.after` has no `parentID` guard, so hidden subagent sessions get retitled (and `gh pr view` widens the trigger) | subagent sessions get the fold |
| BU8 | unplanted | docs | `exact_skills/session-title/SKILL.md` | the session-title docs don't describe path rows or the `gh pr view` fold | docs not updated |
| BU9 | unplanted | excess | `repo-code.sh:21`, `plugin:75` | the plugin passes the same directory twice; `repo-code.sh` could derive the worktree root itself | the second argument is redundant |
| BU10 | unplanted | design | `repo-codes` | absolute-path pins in a shared, untemplated chezmoi file don't carry across machines and outlive their worktrees | absolute paths don't belong in the synced file |
| BU11 | unplanted | excess | `plugin:81-86` | `stripCode` reimplements `.replace(CODE_SUFFIX, "")`, and the one-liner avoids B5 entirely | `stripCode` could be a `replace` |

Not seeded but acceptable as valid extras when argued concretely: the plugin passes the same directory twice to `repo-code.sh`; `gh pr view <other-number>` folds an unrelated PR into the title; no test covers a fresh unsuffixed title.
