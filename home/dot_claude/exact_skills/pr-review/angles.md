# pr-review angles

pr-review §4 dispatches the finders in its depth's row below, all in parallel, and pastes each finder's angle sections into its prompt; at `deep`, §7 dispatches `sweep` once the rest are verified. Every finder reads the whole diff, and its angles decide what it hunts. Two angles flagging the same line for different reasons both report it.

| Depth | Finders, one per group of angles |
|---|---|
| `quick` | `line` `pitfalls` `state` `safety` · `removed` `callers` `tests-spec` `conventions` · `excess` `cleanup` |
| `standard` | `line` `pitfalls` · `removed` `callers` · `state` `safety` · `tests-spec` `conventions` · `excess` `cleanup` |
| `deep` | each angle alone, then `sweep` |

Defect angles report `Kind: defect`; `excess` and `cleanup` report `Kind: excess`.

Every angle except `sweep` opens with a **Prevent** line: the habit that keeps its defects out of a diff in the first place. [writing-plans](../writing-plans/SKILL.md) applies them in its risk pass, `dev-loop-implementer` checks each task against them before committing, and finders hunt for the places a diff broke them.

## line — line-by-line diff scan (defect)

**Prevent:** test every boundary a condition branches on (empty, zero, exactly at the limit, one past it) and every variant of each enum or status the code handles.

Read every hunk in the diff, line by line. Then read the enclosing function of each hunk: bugs in unchanged lines of a touched function are in scope, because the change re-exposes them or fails to fix them. For every line ask what input, state, timing or platform makes it wrong. Look for:

- inverted or wrong conditions, off-by-one, a wrong default fall-through, an unhandled variant;
- null/undefined dereference, missing `await`, falsy-zero checks;
- wrong-variable copy-paste, an error swallowed in a catch;
- unescaped regex metacharacters.

## removed — removed-behaviour audit (defect)

**Prevent:** before deleting or replacing a line, name what it guaranteed and keep that guarantee somewhere, with a test.

For every line the diff deletes or replaces, name the invariant or behaviour it enforced, then search the new code for where that invariant is re-established. The base version of every touched file is under `Base files:` in the context block; read it, since a deleted comment often states the invariant. If you can't find where it's re-established, that's a candidate: a removed guard, a dropped error path, a narrowed validation, a deleted test that was covering a real case.

## callers — cross-file tracer (defect)

**Prevent:** before changing a function, type, enum value or flag, grep every caller and consumer, allowlists included, and update each one in the same change.

For each function the diff changes, find its callers (Grep the whole repo for the symbol) and check whether the change breaks any call site: a new precondition, a changed return shape, a new exception, a timing or ordering dependency. Also check callees: does a parallel change in the same diff make a call unsafe?

Completeness: for a new enum value, status string or flag, find the consumers outside the diff that weren't updated. Read each `match`, `switch` and allowlist rather than just grepping, and search for sibling values to find the allowlists.

## pitfalls — language and platform pitfalls (defect)

**Prevent:** check each line you write against the classic traps of its language, like those listed below.

Scan for the classic pitfalls of the diff's languages and frameworks and flag any instance the diff introduces, for example:

- JS falsy-zero, `==` coercion, a closure-captured loop variable;
- Python mutable default arguments, late-binding closures;
- Go nil-map writes, range-variable capture;
- SQL injection, timezone/DST drift, float equality.

Boundaries: values whose type drifts across JSON / WASM / FFI (number vs string); hash or cache-key inputs that aren't normalised; time windows that assume "today" covers 24 hours.

## state — wrappers and concurrency (defect)

**Prevent:** route every method of a wrapper to the wrapped instance, and make every check-then-write a single atomic step.

When the diff adds or modifies a type that wraps another (cache, proxy, decorator, adapter), check that every method routes to the wrapped instance and not back through a registry, session or global. For example, a caching provider that holds a `delegate` field but resolves IDs via `session.get(...)` instead of `delegate.get(...)` will re-enter the cache or recurse. Also check that the wrapper forwards every method its callers actually use.

Concurrency:

- read-check-write, or `find_or_create` without a unique constraint;
- non-atomic status transitions;
- blocking calls inside async code: sync I/O, `sleep`, a `std` mutex held across `.await`.

## safety — data safety, trust boundaries, operations (defect)

**Prevent:** never interpolate input into SQL, shell or HTML, and validate untrusted input (user, network, LLM) before it is stored, rendered, fetched or run.

- **Data safety:** SQL built by interpolation (even of numeric values); a TOCTOU check-then-write that should be one atomic `UPDATE … WHERE old = ?`; model validations bypassed by direct writes; ORM column names that don't exist in the schema (they silently return nothing).
- **Trust boundaries:** user, LLM or network input that is written, rendered, fetched or executed without validation: shell interpolation, `eval`, unsafe HTML rendering (`dangerouslySetInnerHTML`, `v-html`, `html_safe`), LLM-generated URLs fetched without an allowlist, LLM output persisted without a format or shape check or stored where it becomes a later prompt.
- **Performance on hot paths:** N+1 queries, O(n·m) lookups inside loops or views.
- **CI and release:** tool versions that don't match the project, wrong artifact paths, secrets not read from the secret store, inconsistent version-tag formats, publish steps that fail on re-run.
- **LLM prompts:** 0-indexed lists (models answer 1-indexed), tools the prompt mentions that aren't wired up, limits stated in two places that can drift.

## tests-spec — tests and the spec (defect)

**Prevent:** give every spec item a test that fails without the change, and never assert on a constant or on a mock of the unit under test.

- Every behaviour the spec names has a test, and every bug fix has a regression test that would fail without the fix.
- No test asserts against a mock of the unit under test, and no test cannot fail: asserting a constant, asserting on the mock, duplicating another test.
- Every spec item or plan task has a corresponding change; report the ones that don't as `plan-gap`. `Spec: none` → skip plan gaps.

## conventions — repo rules (defect)

**Prevent:** read the instruction files before the first edit, and follow their rules on naming, placement and error handling.

Read every instruction file in the context block: the user-level `~/.claude/CLAUDE.md`, the repo root's `CLAUDE.md`, `AGENTS.md`, `RULES.md` and `CONTRIBUTING.md`, `.claude/rules/*.md`, and any `CLAUDE.md` in a directory that is an ancestor of a changed file (a directory's `CLAUDE.md` applies only at or below it). Check the diff for clear violations of the rules they state: error-handling shape, file placement, naming, migrations, and so on. Flag a violation only when you can quote the exact rule and the exact line that breaks it, with no style preferences and no "spirit of the doc" inferences. Cite the file and section.

## excess — what the diff doesn't need (excess)

**Prevent:** build only what the spec asks for: no option or parameter that only ever takes one value, no abstraction with one caller, no unrequested scope.

The diff is presumed too big: find the smallest change that satisfies the spec and the repo's rules, and name every line that exceeds it.

- Abstractions with one caller; traits or generics with one implementation.
- Configuration, flags or parameters that only ever take one value.
- Error variants nothing produces; branches nothing reaches.
- Scope beyond the spec; files the plan didn't list. `Spec: none` → skip beyond-plan findings.
- Defensive checks for states the type system already excludes.
- Comments that restate the code; docs for things that didn't change.

A rule can *mandate* something that looks like excess (a required error enum, a sibling test file, a doc comment). When one stops you flagging something, say so in one line. Redundancy that preserves readability (two similar three-line functions) is fine.

## cleanup — reuse, stdlib, merge, simplification, efficiency, altitude (excess)

**Prevent:** grep for an existing helper, then the standard library and installed dependencies, before writing one, and fix the root cause instead of special-casing a symptom.

- **Reuse:** new code that re-implements something the codebase already has. Grep shared or utility modules and the files adjacent to the change, read the existing helper, and cite it by path:line.
- **Stdlib / native:** new code the standard library, the platform or an already-installed dependency does, or a new dependency added for a few lines. Name the call that replaces it.
- **Merge:** near-copies, new or next to existing code, that must change together. Name the one shape both become.
- **Simplification:** unnecessary complexity the diff adds: redundant or derivable state, copy-paste with slight variation, deep nesting, dead code left behind. Name the simpler form.
- **Efficiency:** wasted work the diff introduces: redundant computation or repeated I/O, independent operations run sequentially, blocking work added to startup or hot paths, long-lived objects built from closures that keep a large enclosing scope alive. Name the cheaper alternative.
- **Altitude:** a change that patches a symptom with a fragile bandaid instead of fixing the root cause at the right depth. Special cases layered on shared infrastructure are the sign. Name the more general change to the underlying mechanism.

In `Failure scenario`, state the concrete cost: what is duplicated, wasted, or harder to maintain.

## sweep — gaps (§7, `deep` only)

You have the verified list. Re-read the diff and the enclosing functions looking **only** for defects not already on it. Don't re-derive or re-confirm anything already listed; your job is gaps. Focus on what the first pass tends to miss:

- moved or extracted code that dropped a guard or an anchor;
- second-tier footguns: a dataclass default evaluated once, `hash()` non-determinism, a shrunken lock scope, predicate methods with side effects;
- setup/teardown asymmetry in tests;
- config defaults flipped.

If nothing new turns up, report nothing; don't pad.
