# Answer key — commit-hook-guards

Never show this file to a reviewer. Paths are relative to the fixture worktree; `hooks/` is `home/dot_config/private_git/exact_hooks/`. `verify-seeds.sh` reproduces every row.

Buckets: **bug** (any good reviewer should find it from the code alone), **spec** (needs the spec to see), **test** (test quality), **excess** (code the change doesn't need), **unplanted** (a real issue nobody planted, found by an earlier run and verified; the pool grows as runs find more).

| ID | Bucket | Category | Location | Defect | Credit when a finding says |
|---|---|---|---|---|---|
| A1 | bug | boundary | `hooks/executable_commit-msg:23` | `-ge` rejects a subject of exactly 72 characters; the spec allows 72 | 72 is rejected / should be `-gt` / off-by-one on the cap |
| A2 | bug | lost-anchor | `hooks/lib-ticket.sh:52` | the ticket regex lost its trailing `$`, so a slashless branch like `DOT-5-fix-thing` yields `Refs: #5-fix-thing` | the regex is no longer anchored at the end / accepts trailing text after the number |
| A3 | bug | language-pitfall | `hooks/executable_commit-msg:22` | `wc -c` counts bytes, so multibyte characters (an em dash is 3 bytes) push short subjects over the cap | `wc -c` counts bytes not characters / use `wc -m` or `${#subject}` |
| A4 | bug | language-pitfall | `hooks/executable_prepare-commit-msg:19` | unquoted `$GIT_TICKET_SKIP`: when unset, `[ = 1 ]` prints `unary operator expected` on every commit | the variable is unquoted / errors or misbehaves when unset or empty |
| A5 | bug | removed-behavior | `hooks/executable_prepare-commit-msg:36` | the `grep -v '^#'` filter was dropped, so the editor template's `# On branch ABC-123/...` comment counts as "already referenced" and Jira-ticket trailers are skipped | comment lines now match the duplicate check / the comment filter was removed |
| A6 | bug | correctness | `hooks/lib-ticket.sh:41` | `${name#refs/heads}` keeps the leading `/`, so `${branch%%/*}` is empty and the rebase fallback never returns a ticket | the strip leaves a leading slash / should strip `refs/heads/` / fallback never yields a ticket |
| A7 | spec | completeness | `hooks/lib-ticket.sh:38` | only `rebase-merge/head-name` is read; the spec also names `rebase-apply/head-name` | the apply backend / `rebase-apply` is not handled |
| A8 | bug | cross-file | `hooks/executable_pre-commit:17` | `repo_prefix` was renamed to `own_prefix` but `pre-commit` (not in the diff) still calls `repo_prefix`; it's now undefined, so `\|\| return 0` silently disables the foreign-prefix check | `pre-commit` still calls the old name / the prefix check is disabled |
| A9 | test | hollow-test | `tests/git-hooks.sh:43-44` | the rebase check asserts `$? -eq 0` after `\|\| true`, so it can't fail, and it never inspects `$ticket`; it stays green through A6 | the rebase test can't fail / `$?` is always 0 / it never checks the ticket value |
| A10 | spec | plan-gap | `hooks/executable_pre-commit` | the spec's `GIT_TICKET_SKIP` never reached `pre-commit` | `pre-commit` doesn't honour `GIT_TICKET_SKIP` |
| A11 | excess | speculative-scope | `hooks/executable_commit-msg:8` | `GIT_MAX_SUBJECT` is a configuration knob the spec never asked for | the `GIT_MAX_SUBJECT` override is unrequested or unneeded |
| AU1 | unplanted | correctness | `hooks/lib-ticket.sh:50` | once A6 is fixed, the sequencer runs `prepare-commit-msg` for every replayed pick, so each picked commit gets the rebased branch's ticket stamped on again | replayed picks get re-stamped / the fallback fires for picks, not just new commits |
| AU2 | unplanted | correctness | `hooks/executable_commit-msg:10` | the cap measures only the first line, but git's subject (`%s`) is the whole first paragraph, so a wrapped subject passes | subject is the first paragraph, not the first line |
| AU3 | unplanted | correctness | `hooks/executable_commit-msg:22` | `commit-msg` sees the message before git's cleanup, so trailing spaces or a CR count toward the cap | trailing whitespace / CR counted |
| AU4 | unplanted | correctness | `hooks/executable_commit-msg:11` | the `amend!` exemption lets an over-long subject in through `--fixup=amend:` and autosquash | `amend!` bypasses the cap |
| AU5 | unplanted | correctness | `hooks/executable_prepare-commit-msg:36` | `grep -F` is a substring match, so on `DOT-1/…` a body mentioning `#12` counts as already referencing `#1` | substring match / `#1` vs `#12` |
| AU6 | unplanted | test | `tests/git-hooks.sh:8-40` | the test inherits the caller's git config and environment (hooks path, identity) and never checks its setup steps, so checks can pass vacuously | not hermetic / setup failures ignored |
| AU7 | unplanted | test | `tests/git-hooks.sh:35-36` | no test pins the 72 boundary, the exempt subjects, or `pre-commit` | missing boundary / exemption / pre-commit tests |
| AU8 | unplanted | excess | `hooks/lib-ticket.sh:12-26` | renaming `repo_prefix` to `own_prefix` is outside the spec, and it's what breaks `pre-commit` (A8) | the rename is unrequested |
| AU9 | unplanted | performance | `hooks/lib-ticket.sh:36-56` | the rebase fallback forks extra processes on every pick of every rebase, measurable per pick | per-pick overhead |
| AU10 | unplanted | test | `tests/git-hooks.sh:10-33` | the test doesn't unset `GIT_DIR` (or `GIT_WORK_TREE`), so run from inside a hook or rebase it writes into the caller's repo | inherited `GIT_DIR` / writes into the caller's repo |
| AU11 | unplanted | correctness | `hooks/executable_pre-commit:25` | with the fallback, `pre-commit` now rejects a foreign-prefix ticket mid-rebase, but its `git branch -m` advice can't work on a detached HEAD | rename advice is wrong mid-rebase |
| AU12 | unplanted | correctness | `hooks/executable_commit-msg:10` | macOS `awk` aborts on invalid UTF-8, leaving `subject` empty, which is exempt, so the cap is skipped | invalid UTF-8 empties the subject |
| AU13 | unplanted | correctness | `hooks/executable_commit-msg:8,23` | a non-numeric `GIT_MAX_SUBJECT` makes `[ -ge ]` error, which reads as false, so the cap silently turns off | non-numeric override fails open |
| AU14 | unplanted | test | `tests/git-hooks.sh` | no test covers the skip switch or runs `prepare-commit-msg` end to end | skip switch / trailer path untested |
| AU15 | unplanted | correctness | `hooks/executable_prepare-commit-msg:36` | with `commit -v`, the diff below the scissors line is in the message file, so a ref appearing in the diff suppresses the trailer (already true on the base) | `commit -v` diff text counts as a reference |

Not seeded but acceptable as valid extras when argued concretely: no test pins the 72 boundary; `rebase_branch` reads `head-name` relative to a `--git-dir` that may be relative.
