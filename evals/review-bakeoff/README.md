# review bake-off

Measures how many planted defects a review cycle finds, and how much noise it reports alongside them. Each review runs in its own fresh headless Claude Code session, so it never sees the answer key or another run's output. It compares:

- `code-review`: the built-in `/code-review` (alias `/review`) at `max`, uncapped.
- `dev-loop`: round 1 of `/dev-loop`'s review cycle, i.e. `pr-review` with dev-loop's default reviewers, judged by its own session.

## Fixtures

Each fixture is a realistic feature diff on this repo, pinned to a base commit, plus the spec it was written against.

| Fixture | Code | Seeds | Use |
|---|---|---|---|
| `commit-hook-guards` | POSIX sh git hooks | 11 (A1–A11) | tuning |
| `session-title-worktree-codes` | JS opencode plugin + bash | 9 (B1–B9) | holdout: don't tune prompts against it |
| `workspaces-session-restore` | nvim Lua, larger and sparser, with decoys | 11 (C1–C11) + 3 decoys | holdout |

`fixtures/<name>/` holds `fixture.patch`, `spec.md`, `answers.md` (the key; never give it to a reviewer), `fixture.env`, and `verify-seeds.*`, which reproduces every seed against a fixture worktree. Seeds are bucketed as bug, spec (needs the spec to see), test, or excess.

## Run

```bash
./run.sh commit-hook-guards code-review
./run.sh commit-hook-guards dev-loop
./run.sh commit-hook-guards dev-loop --src ~/worktrees/dotfiles/<branch>/home/dot_claude
./grade.sh "$TMPDIR/review-bakeoff/commit-hook-guards/<run>"
node scoreboard.mjs "$TMPDIR/review-bakeoff"
```

- `run.sh` builds the fixture on first use (`lib.sh`), and refuses to run unless it matches `fixture.patch` and is clean.
- `--src` reviews with the skills and agents of a chezmoi source tree, so a candidate can be measured before it is applied. Its agents reach the session through `claude --agents`, which overrides the installed agents of the same name.
- Output lands in `$BAKEOFF_RUNS` (default `$TMPDIR/review-bakeoff`), never in the repo.
- Runs use `--model opus --effort max --permission-mode auto --strict-mcp-config`, and `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`: without it, `-p` kills background agents 10 minutes after the main turn ends, mid-review.

## Keeping the answer out of reach

Reviewers are curious, and each of these leaked during development:

- **Shared refs.** A fixture is a standalone clone cut off at its base commit, not a worktree of this repo, so `git log --all` can't reach this harness's commits.
- **Transcripts.** The session that built a fixture describes its seeds, and a reviewer went reading `~/.claude/projects` for context. Runs deny `Read`/`Grep`/`Glob` on transcripts, this harness and earlier runs, and append the same out-of-scope note to every reviewer's system prompt. The grader runs with `--no-session-persistence`, so its transcript never lands where the next reviewer of that fixture could find it.
- **Paths.** A dev-loop reviewer sees only the fixture checkout and a fresh temp directory holding the plan, the patch and, with `--src`, a copy of the candidate's skills; nothing next to them names this eval.
- **Detection.** `extract.mjs` flags a run as contaminated if a transcript mentions the answer key or this harness, or if any tool call reached into a session transcript. A contaminated run doesn't count; rerun it.

## Scoring

`grade.sh` hands `answers.md`, the final report and any structured findings to a fresh grader session. The grader rules each seed FOUND, PARTIAL, DISMISSED (a reviewer found it, then the judge threw it out) or MISSED, and classes every other reported finding as VALID, NIT or FALSE. The scoreboard counts FOUND as 1 and PARTIAL as 0.5.

LLM reviews are noisy: compare several runs per cell before reading much into a one-seed difference.
