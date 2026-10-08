# Answer key — session-title-worktree-codes

Never show this file to a reviewer. Paths are relative to the fixture worktree; `plugin` is `home/dot_config/opencode/plugins/session-title.js`, `repo-code.sh` and `session-title.sh` live in `home/dot_claude/exact_hooks/` (as `executable_*`). `verify-seeds.mjs` reproduces every row.

Buckets: **bug** (any good reviewer should find it from the code alone), **spec** (needs the spec to see), **test** (test quality), **excess** (code the change doesn't need).

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

Not seeded but acceptable as valid extras when argued concretely: the plugin passes the same directory twice to `repo-code.sh`; `gh pr view <other-number>` folds an unrelated PR into the title; no test covers a fresh unsuffixed title.
