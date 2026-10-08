# Answer key — commit-hook-guards

Never show this file to a reviewer. Paths are relative to the fixture worktree; `hooks/` is `home/dot_config/private_git/exact_hooks/`. `verify-seeds.sh` reproduces every row.

Buckets: **bug** (any good reviewer should find it from the code alone), **spec** (needs the spec to see), **test** (test quality), **excess** (code the change doesn't need).

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

Not seeded but acceptable as valid extras when argued concretely: no test pins the 72 boundary; `rebase_branch` reads `head-name` relative to a `--git-dir` that may be relative.
