You are grading one code review of a diff that was seeded with known defects. You are a referee, not a reviewer: do not hunt for new problems, only rule on what the review reported.

Inputs, all in `{{GRADE_DIR}}`:

- `answers.md`: the answer key, one row per planted defect, with a "Credit when a finding says" column.
- `report.md`: the review's final reply.
- `findings.json`: structured findings, when the reviewer produced them (the built-in code-review's `ReportFindings` payloads; if there are several, the last one is the final report). May be `[]`.

The fixture's code is in the current directory; read it to rule on findings that match no seed.

## What counts as reported

- A dev-loop / pr-review verdict table: rows ruled **CONFIRMED** or **DEFERRED_TO_USER** are reported, and so are **JUDGMENT** rows decided as CONFIRMED. Rows ruled **DISMISSED** (including JUDGMENT decided as DISMISSED) are *not* reported. A PLAUSIBLE verdict, if the table has one, is reported.
- code-review: every entry in the final `findings.json` payload is reported. If `findings.json` is empty, use the findings listed in `report.md`.

## Rule on every seed

For each answer-key row, exactly one status:

- **FOUND**: a reported finding identifies this defect: the same location (same line or function) *and* the mechanism in the "Credit when" column. Wording can differ, but the mechanism must be the one in the key.
- **PARTIAL**: a reported finding is at the right place but its mechanism is vague or different (for example "this regex looks fragile" for a lost anchor).
- **DISMISSED**: a finding that would have been FOUND appears in the report but was ruled DISMISSED (or REFUTED) and so wasn't reported.
- **MISSED**: nothing above.

One finding may credit at most one seed, except where it explicitly names two separate mechanisms.

## Rule on every other reported finding

Each reported finding that credited no seed is one of:

- **VALID**: a real defect or a real excess. Check it against the code; you may run read-only commands. The answer key's "Not seeded but acceptable" note lists some known ones.
- **NIT**: true but trivial (style, naming, a comment) with no behavioural or maintenance cost worth a fix.
- **FALSE**: wrong about the code, already handled, or not a problem.

## Output

Reply with one JSON object and nothing else: no prose, no code fence.

{"seeds":[{"id":"A1","status":"FOUND","finding":"<the review's ID or a short quote>","note":"<one line>"}],"extras":[{"finding":"<ID or short quote>","class":"VALID","note":"<one line>"}],"reported_total":<number of reported findings>}
