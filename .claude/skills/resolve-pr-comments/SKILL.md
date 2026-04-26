---
name: resolve-pr-comments
description: Triage and act on every reviewer comment on a GitHub PR — fix small nits and critical issues directly (then reply + resolve the thread), and surface deferral or pushback decisions back to the user without responding in the thread. Triggers when the user asks to "resolve PR comments", "address review feedback", "go through PR comments", "respond to reviewers", or similar.
---

# Resolve PR comments

Act as a principal engineer triaging review feedback. Every comment ends up in exactly one of three buckets — **fix now**, **defer**, or **push back** — with strict rules about which ones get a reply written by you and which come back to the user.

## 1. Collect every comment thread

PRs have three comment surfaces; you must read all of them. Resolve `<owner>/<repo>` and `<pr>` first (e.g. from `gh pr view --json url,number,headRepository,headRepositoryOwner` if not given).

```bash
# Top-level PR conversation (issue comments)
gh api -X GET "repos/<owner>/<repo>/issues/<pr>/comments" --paginate \
  --jq '.[] | {id, user: .user.login, body, created_at}'

# Inline review comments (the diff-anchored ones, including bots like Copilot)
gh api -X GET "repos/<owner>/<repo>/pulls/<pr>/comments" --paginate \
  --jq '.[] | {id, in_reply_to: .in_reply_to_id, user: .user.login, path, line, body, created_at}'

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

1. Make the code change. Keep it surgical — don't sneak unrelated cleanups into a review-driven commit.
2. Run the relevant tests / lint for the touched files (`cargo test -p <crate>`, `cargo clippy`, `cargo fmt`, `npx playwright test <spec>`, etc. — whatever the repo's `CLAUDE.md` prescribes).
3. Commit + push the fix. For jj repos, follow the existing branch's bookmark workflow (`jj describe` → `jj bookmark move` → `jj git push`).
4. **Reply to the comment thread** with a short note explaining what changed. Reference the new commit SHA when useful.

   ```bash
   # Reply inline to a review-comment thread (use the head comment's REST id)
   gh api -X POST "repos/<owner>/<repo>/pulls/<pr>/comments" \
     -f body="Fixed in <sha> — <one-line summary>." \
     -F in_reply_to=<head_comment_id>

   # Reply to a top-level issue comment (no threading; just post a new comment)
   gh api -X POST "repos/<owner>/<repo>/issues/<pr>/comments" \
     -f body="Addressed in <sha> — <one-line summary>."
   ```

5. **Resolve the review thread** (issue comments don't have a resolve concept; the reply is enough):

   ```bash
   gh api graphql -f query='
     mutation($id:ID!) { resolveReviewThread(input:{threadId:$id}) { thread { isResolved } } }
   ' -F id=<thread_id>
   ```

Reply tone: terse, factual, no apologies, no filler. "Fixed — switched to `Result<…, anyhow::Error>` per `02-error-handling`." not "Great catch! I really appreciate the feedback…".

## 3b. Defer flow

Do **not** reply on the PR. Do **not** resolve the thread. Surface it back to the user with:

- The reviewer's name and a one-line quote of the comment.
- Why you classified it as defer (scope, dependency, design discussion, data needed).
- A concrete proposal: open a follow-up issue, file a TODO, add to a roadmap doc, or punt to the next PR — and ask which.

The user makes the call on whether to defer, fix anyway, or push back. They will write the reply themselves if one is needed.

## 3c. Push-back flow

Same as defer — no reply, no resolution. Surface back with:

- The reviewer's name and a one-line quote.
- Why you think the comment is mistaken or superfluous (cite the file, function, or rule that shows otherwise).
- The exact wording you'd suggest the user reply with, so they can send it as-is or edit.

Never argue with a reviewer on the user's behalf without explicit approval — pushback is a relationship signal and the user owns it.

## 4. Final report

After the pass, print a compact summary:

```
Fixed (<n>):
  - <thread_id_short> <reviewer>: <one-liner>      [commit <sha>]
  - ...

Deferred (<n>) — awaiting user decision:
  - <thread_id_short> <reviewer>: <one-liner>      reason: <…>

Push back (<n>) — awaiting user decision:
  - <thread_id_short> <reviewer>: <one-liner>      reason: <…>

Already resolved / outdated: <n> (skipped)
```

The user reads the summary and either approves the deferrals/pushbacks (you then post their replies) or course-corrects items into the fix-now bucket.

## Hard rules

- **Never** reply to or resolve a comment you classified as defer or push back. The user owns those.
- **Never** mark a thread resolved without an actual fix landing on the branch first. "Will fix later" is a defer, not a fix-now.
- **Never** batch-resolve threads with a single boilerplate reply. Each fix gets its own targeted note.
- **Never** invent a commit SHA in a reply — only reference SHAs that exist on the pushed branch.
