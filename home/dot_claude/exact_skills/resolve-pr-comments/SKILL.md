---
name: resolve-pr-comments
description: Triage and act on every reviewer comment on a GitHub PR — fix small nits and critical issues directly (reply with just the commit SHA, then resolve the thread), dismiss bot comments you defer or push back on with a few-word reply, and bring deferrals or push-backs on human comments to the user before replying. Triggers when the user asks to "resolve PR comments", "address review feedback", "go through PR comments", "respond to reviewers", or similar.
---

# Resolve PR comments

Act as a principal engineer triaging review feedback. Every comment ends up in exactly one of three buckets — **fix now**, **defer**, or **push back** — with strict rules about which ones get a reply written by you and which come back to the user.

## 1. Collect every comment thread

PRs have three comment surfaces; you must read all of them. Resolve `<owner>/<repo>` and `<pr>` first (e.g. from `gh pr view --json url,number,headRepository,headRepositoryOwner` if not given).

```bash
# Top-level PR conversation (issue comments)
gh api -X GET "repos/<owner>/<repo>/issues/<pr>/comments" --paginate \
  --jq '.[] | {id, user: .user.login, user_type: .user.type, body, created_at}'

# Inline review comments (the diff-anchored ones, including bots like Copilot)
gh api -X GET "repos/<owner>/<repo>/pulls/<pr>/comments" --paginate \
  --jq '.[] | {id, in_reply_to: .in_reply_to_id, user: .user.login, user_type: .user.type, path, line, body, created_at}'

# Review summaries (the "Approve / Request changes / Comment" envelopes)
gh api -X GET "repos/<owner>/<repo>/pulls/<pr>/reviews" --paginate \
  --jq '.[] | {id, user: .user.login, state, body, submitted_at}'
```

For resolving threads you need their **GraphQL thread IDs** (the REST `id` is the comment, not the thread). Pull threads + their resolution state in one query:

```bash
gh api graphql -f query='
  query($owner:String!,$repo:String!,$pr:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100) {
          nodes {
            id isResolved isOutdated
            comments(first:50) {
              nodes { databaseId author{login} path line body }
            }
          }
        }
      }
    }
  }' -F owner=<owner> -F repo=<repo> -F pr=<pr>
```

Build a working list of every **unresolved** thread + every standalone issue comment that hasn't been answered. Skip threads where `isResolved=true` already.

Tag each item's author as a **bot** or a **person**. A bot has `user.type == "Bot"`, a login ending in `[bot]`, or is Copilot; everyone else is a person. The tag decides who owns a deferral or push-back (§3b).

## 2. Triage each comment as a principal engineer

For every item, decide **severity** and **correctness** before touching anything:

| Bucket | Heuristics |
|---|---|
| **Fix now** | Real bug, security issue, broken test, undefined behavior, public API misuse, typo / nit / lint with an obvious one-line fix, or a small refactor the reviewer is right about. |
| **Defer** | Legitimate concern but out of scope for this PR (larger refactor, separate feature, needs design discussion, requires data the PR can't produce). The work *should* happen, just not here. |
| **Push back** | Reviewer is mistaken (misread the diff, missed context, suggested a regression), the comment is stylistic noise that violates repo conventions, or it's a duplicate/auto-generated suggestion that doesn't apply. |

When in doubt between *fix now* and *defer*, ask: **"Is this <30 minutes of work and does it touch only files already in the diff?"** If yes → fix now. If no → defer.

When in doubt between *defer* and *push back*, ask: **"Would a reasonable senior engineer agree this is a real issue once they see the full context?"** If yes → defer. If no → push back.

## 3a. Fix-now flow

**0. Stack a new commit before editing anything.** The PR branch is already pushed; reviewers have commented against the existing commit hashes. Amending in place rewrites those hashes and forces the next push, which is destructive and loses the comment anchors. So:

Confirm you're on the PR branch and that HEAD is at or ahead of the published tip:

```bash
git branch --show-current
git status -sb              # want [ahead N] or clean — never a divergence
```

Then make commits on top normally. Never `git commit --amend`, `git rebase`, or `git push --force` past the published tip without the user's explicit go-ahead.

If a plain `git push` is ever rejected as non-fast-forward, stop — you almost certainly amended a pushed commit. Recover with `git reset --soft origin/<branch>` (keeps your changes staged) and re-commit on top instead of reaching for `--force`.

1. Make the code change. Keep it surgical — don't sneak unrelated cleanups into a review-driven commit.
2. Run the relevant tests / lint for the touched files (`cargo test -p <crate>`, `cargo clippy`, `cargo fmt`, `npx playwright test <spec>`, etc. — whatever the repo's `CLAUDE.md` prescribes).
3. Commit + push the fix: `git add -u` → `git commit -m "fix: …"` → `git push`. The push must be a fast-forward — if git rejects it as non-fast-forward, step 0 was skipped.
4. **Reply with the commit SHA and nothing else** — no "Fixed", no summary. GitHub renders a pushed commit's SHA as a link to it, so the fix must be pushed first (step 3). Use the full SHA of the commit that fixed *this* comment; if it took several, list them space-separated.

   ```bash
   # Reply inline to a review-comment thread (use the head comment's REST id)
   gh api -X POST "repos/<owner>/<repo>/pulls/<pr>/comments" \
     -f body="<sha>" \
     -F in_reply_to=<head_comment_id>

   # Reply to a top-level issue comment (no threading; just post a new comment)
   gh api -X POST "repos/<owner>/<repo>/issues/<pr>/comments" \
     -f body="<sha>"
   ```

5. **Resolve the review thread** (issue comments don't have a resolve concept; the reply is enough):

   ```bash
   gh api graphql -f query='
     mutation($id:ID!) { resolveReviewThread(input:{threadId:$id}) { thread { isResolved } } }
   ' -F id=<thread_id>
   ```

## 3b. Defer and push-back flow

A deferral or push-back is dismissed with a reply of **as few words as it needs** — the reason, and a link if one exists — then the thread is resolved. No greeting, no apology, no restating the comment:

- Defer: `Out of scope; tracked in #412.` / `Follow-up PR.`
- Push back: `Intended: callers already validate.` / `Covered by db/src/auth.rs:88.`

Who decides depends on the author (§1):

- **Bot** → decide it yourself: post the reply and resolve the thread (same mutation as §3a step 5). No check-in.
- **Person** → do **not** reply or resolve yet. Bring it to the user with the reviewer's name, a one-line quote, why it's a defer or push-back (cite the file, function, or rule), and the exact reply you'd post. Once the user approves — or edits the wording — post it and resolve the thread. Push-back on a person is a relationship signal; the user owns it.

For a top-level issue comment there's no thread to resolve; the reply is enough.

## 4. Final report

After the pass, print a compact summary:

```
Fixed (<n>):
  - <thread_id_short> <reviewer>: <one-liner>      [commit <sha>]
  - ...

Dismissed — bot (<n>):
  - <thread_id_short> <bot>: <one-liner>      replied: "<reply>"

Awaiting you — person (<n>):
  - <thread_id_short> <reviewer>: <one-liner>      defer | push back — proposed reply: "<reply>"

Already resolved / outdated: <n> (skipped)
```

The user approves or edits each proposed reply (you then post it and resolve the thread), or moves items into the fix-now bucket.

## Hard rules

- **Never** reply to or resolve a person's comment you classified as defer or push back until the user approves the reply.
- **Never** mark a thread resolved as fixed without the fix pushed to the branch first. "Will fix later" is a defer, not a fix-now.
- **Never** pad a reply. A fix is the SHA alone; a dismissal is the fewest words that carry the reason.
- **Never** batch-resolve threads with one shared reply. Each thread gets the SHA of its own fix, or its own dismissal.
- **Never** invent a commit SHA in a reply — only reference SHAs that exist on the pushed branch.
- **Never** force-push a PR branch to land review fixes. Fixes stack as new commits on top of the pushed tip (step 0 above) — never an amend, never a rebase. If `git push` is rejected as non-fast-forward, step 0 was skipped: recover with `git reset --soft origin/<branch>` and re-commit, rather than reaching for `--force`.
