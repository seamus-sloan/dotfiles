---
name: delegated-review
description: Hand the current diff to an independent GPT-5.6 reviewer subagent, then triage its findings into fix-now / defer / reject. Fixes CRITICAL findings automatically and batches the rest into one question. Triggers when the user asks for a "second opinion", "delegated review", "independent review", "fresh eyes on this", "have GPT review this", "get a review of my changes", or "code review this branch".
---

# Delegated review

Send the diff to a reviewer that is **not you**, running on a **different model family**, then decide what to act on. The value is the disagreement: a reviewer sharing your context and your model shares your blind spots.

You own the triage. The reviewer advises; it does not get a veto.

## Pick the right skill

Three review skills overlap. Choose deliberately:

| Skill | Who reviews | Cost | Use when |
|---|---|---|---|
| `pr-review` | Claude reviewer agents (`neutral` by default; `prosecutor` + `defender` on request), every finding verified by you | 1–2 subagents | Routine review of your branch or a PR |
| **`delegated-review`** (this) | One GPT-5.6 subagent | 1 subagent | You want an independent model's read before shipping |
| `review-work` | 5 parallel agents (goal/QA/code/security/context) | 5 subagents | High-stakes work, PR handoff, or a security-sensitive change |

If the user just said "review my branch" with no hint of independence, that is `pr-review`. This skill is for when they want a *different model family* to look.

---

## Phase 1 — Establish the review base

The reviewer needs to know exactly what to review. Get this right or the whole review is aimed at the wrong lines.

```bash
git branch --show-current
git status --short
BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
echo "base: $BASE"
git diff --stat "$BASE"...HEAD          # committed work on this branch
git diff --stat                          # uncommitted working-tree changes
```

Resolution rules:

- **Committed branch work** → review `$BASE...HEAD` (three-dot: the branch's own commits, not upstream drift).
- **Uncommitted changes present** → include them. Say so in the delegation prompt, because the reviewer must diff the working tree (`git diff`) rather than a commit range.
- **Both** → review both, and tell the reviewer they are looking at two overlapping sets.
- **`$BASE` is stale** → run `git fetch origin` first. A base behind by 40 commits produces phantom findings about code the branch never touched.
- **Nothing to review** → stop. Say `Delegated review: no changes against <base>.` Do not spawn a reviewer for an empty diff.

Also capture the **goal**: what was this change supposed to accomplish? Pull it from the conversation. Without it the reviewer can check correctness but not completeness, which is where the expensive misses live.

---

## Phase 2 — Delegate

One reviewer, synchronous, on the dedicated GPT-5.6 seat:

```typescript
task(
  category="code-review",
  load_skills=[],
  run_in_background=false,
  description="Independent review of <branch>",
  prompt="<see contract below>"
)
```

Why `category="code-review"`: it is pinned to `amazon-bedrock/openai.gpt-5.6-sol` at `xhigh` in `~/.omo/omo.jsonc`, with `write`/`edit`/`task` disabled so the reviewer cannot patch the tree or fan out into sub-reviewers. It carries a review rubric in its `prompt_append`, so you do not need to restate the method — only the specifics of *this* diff.

Do **not** substitute `subagent_type="oracle"`. Oracle is also GPT-5.6 here, but it cannot read files or run commands, so you would have to inline every changed file into the prompt and it could never read the surrounding code where the real findings are.

`run_in_background=false` because you have nothing useful to do while waiting. Use `true` only for a very large diff where you intend to keep working on something genuinely independent — never to poll it.

`load_skills=[]` by default. Add a repo-relevant skill (e.g. `programming` for a strict-types codebase) when the repo has conventions the reviewer would otherwise not know.

### Delegation prompt contract

The subagent inherits **none** of your context. An under-specified prompt returns a confident review of the wrong thing.

```
TASK: Review the changes on branch <branch> against <base>. Report findings only — do not fix anything.

EXPECTED OUTCOME: CRITICAL/MINOR findings, each with file:line, what breaks, and the fix.
Close with: VERDICT: <n> CRITICAL, <m> MINOR

REQUIRED TOOLS: bash (git diff, git log, running tests), read, grep, glob.

MUST DO:
- Run `git diff <base>...HEAD` yourself to see the change. [+ `git diff` for uncommitted work, if applicable]
- Read each changed file in full, not just the diff hunks.
- Read the callers and consumers of what changed. Most real findings live outside the diff.
- Judge completeness against the stated GOAL below, not just internal consistency.
- Run the test suite / typecheck / lint if the repo has them, and report actual output.

MUST NOT DO:
- Do not modify, stage, commit, or push anything.
- Do not review files the diff does not touch, except as context for judging it.
- Do not pad the review with praise or restate the diff back.
- Do not invent findings to appear thorough. A clean diff should be reported as clean.

CONTEXT:
- GOAL: <what this change was supposed to accomplish>
- BASE: <base ref>  BRANCH: <branch>
- CHANGED FILES: <git diff --name-only output>
- UNCOMMITTED: <yes/no — and which files>
- CONVENTIONS: <language, framework, patterns this repo enforces>
- KNOWN/INTENTIONAL: <anything deliberately out of scope, so it is not re-litigated>
```

Fill `KNOWN/INTENTIONAL` honestly — it is the single highest-leverage line. It suppresses the findings you already decided about and keeps the reviewer aimed at what you have not considered.

---

## Phase 3 — Triage

The reviewer's classification is an input, not a verdict. Re-sort every finding into one of three buckets. **You have context the reviewer does not** — you know the goal, the constraints, and what was deliberately deferred.

### FIX NOW — do it without asking

- Any **CRITICAL** finding you judge to be **valid**.
- Mechanical correctness regardless of severity: a real off-by-one, a swallowed error, a wrong comparison, a missed enum consumer, a suppressed type error, a test that asserts nothing.
- Anything unsafe: injection, secret, SSRF, unvalidated trust boundary.

Fix it, then **re-verify**: `lsp_diagnostics` on every touched file, plus build/tests if the repo has them. A fix you did not verify is not a fix.

### DEFER — batch into ONE question

- Valid, but genuinely out of this change's scope (pre-existing debt the diff merely sits next to).
- Refactors or restructuring the reviewer would prefer. A bug fix is not a refactor.
- Style or naming preferences the codebase does not actually enforce.
- Anything whose fix would meaningfully widen the diff.

### REJECT — record, do not act

The reviewer read unfamiliar code without your context. It will sometimes be wrong. Push back when it is:

- The finding assumes behavior the code does not have, or misreads control flow.
- It contradicts a constraint the user set, or an intentional decision already made.
- It flags a framework guarantee as an unhandled case.
- It is speculative — "this could be a problem if X" where X cannot occur here.

Do not silently drop these. State the finding and why you rejected it, in one line each. A rejected finding the user disagrees with is exactly what this loop exists to surface.

### Re-review cap

If you fixed CRITICAL findings and want confirmation, spawn **one** fresh reviewer scoped to *the delta only* — never a follow-up to the original session, which carries stale pre-fix context.

Hard cap: **one re-review.** If you and the reviewer still disagree after that, stop and present both positions. Do not burn turns arguing with a subagent.

---

## Phase 4 — Report

```
Delegated review (GPT-5.6): N findings — X critical, Y minor
Base: <base>...<branch>

FIXED:
- [file:line] Problem → fix applied
  Verified: <lsp clean / tests pass / build ok>

REJECTED (reviewer lacked context):
- [file:line] Finding → why it does not apply

NEEDS YOUR CALL:
- [file:line] Problem
  Recommended: <fix / defer to follow-up>
```

If clean: `Delegated review (GPT-5.6): no findings against <base>.` No preamble, no "looks good overall."

If nothing landed in NEEDS YOUR CALL, do not ask a question — just report and stop.

---

## Guardrails

- **Never let the reviewer write.** `write`/`edit` are disabled on the category by design. If a finding needs a fix, *you* apply it — you are the one who can verify it.
- **Never accept a finding you have not verified against the code.** The reviewer's claim is a lead. Read the line before you change it.
- **Never present the review verbatim as your answer.** Raw findings are the reviewer's output; triage is yours. Handing over an untriaged dump is the failure mode this skill exists to prevent.
- **Never spawn more than one reviewer per pass.** Parallel reviewers on one diff is `review-work`, not this.
- **Do not commit or push.** Report and stop unless the user asked for more.
