# Results — 2026-10-08

One round-1 review per cell (two for the old dev-loop), Claude Code 2.1.293, Opus 5.5 at `--effort max`, graded by `grade.sh` against the answer keys as they stand at this commit.

- **old dev-loop**: `pr-review` with `review-prosecutor` + `review-defender`.
- **new dev-loop**: `pr-review` with a `review-finder` per angle, a `review-verifier` per candidate, and a gap sweep.
- **code-review**: the built-in `/code-review max --max-findings all`.

## Planted seeds

Every reviewer found every planted bug. code-review never sees the spec, so it can't catch spec gaps.

| | bugs | spec | tests | excess |
|---|---|---|---|---|
| new dev-loop | 21/21 | 4/4 | 3/3 | 3/3 |
| code-review | 21/21 | 2.5/4 | 3/3 | 2.5/3 |
| old dev-loop (×2) | 42/42 | 8/8 | 6/6 | 6/6 |

## Unplanted issues (pooled)

The seeds saturate, so the separating measure is the pool of real issues nobody planted: every valid finding any run reported, verified and added to the fixture's answer key as an `unplanted` row, then every run regraded against the pool.

| Fixture | pool | new dev-loop | code-review | old dev-loop |
|---|---|---|---|---|
| commit-hook-guards | 15 | **13** | 9.5 | 2, 4 |
| session-title-worktree-codes | 16 | **14** | 11 | 6, 4 |
| workspaces-session-restore | 17 | **15** | **15** | 6, 6 |
| **total** | 48 | **42 (88%)** | 35.5 (74%) | 14 avg (29%) |

The old dev-loop's judge also dismissed real issues its prosecutor had found (`BU3`, `BU4`, `CU17`) for lack of a one-command repro; the new cycle keeps those as PLAUSIBLE.

## Noise and cost

| | false positives | cost per review | wall time |
|---|---|---|---|
| new dev-loop | 0 | $64–80 | 85–102 min |
| code-review | 0 | $54–68 | 57–78 min |
| old dev-loop | 0 | $6–9 | 16–26 min |

Cost is `total_cost_usd` as `claude -p` reports it. dev-loop runs a review every round, so `rounds=2` doubles both columns.

## Caveats

- One run per cell for the new dev-loop and code-review; the old dev-loop's two runs varied by up to 2 pooled issues, so read one-issue gaps as ties.
- The grader is an LLM: regrading the same run moved its pooled count by up to 1.
- The pool is built from these runs, so it grows with whoever finds the most; an issue no run found is invisible to every score.
- `commit-hook-guards` was meant as the tuning fixture, but the new cycle ran untuned, so all three results are held out.
