# Code

Rules for all code in any language: source, tests, scripts, and config files.

## Comments

- **Aim for no comment.** Code or config that needs one to be understood gets rewritten first: a clearer name, an extracted function, a named constant.
- **When one must stay, aim for a single line** that says why, never what: a workaround, a non-obvious constraint, a link to the bug.
- **Three lines is the hard cap**, in code and config alike. Only documentation runs longer, such as a usage block at the top of a script.
- **Doc comments are encouraged on code other code calls:** public modules, types, and functions, including shared test infrastructure such as a base class. Tests themselves need none. Use the language's doc syntax: what it does, what it returns, what a caller must know. Keep them terse, and never restate the signature.
- **Never** leave commented-out code, comments that narrate the next line, or change history (`// added retries`, `// fixed bug`). Git holds that.

```ts
// Before: a comment carries what the code doesn't say
// only retry failed jobs that are under the limit and not cancelled
if (job.status === 'failed' && job.retries < MAX_RETRIES && !job.cancelled) {

// After: the name says it
if (isRetryable(job)) {
```

## Types

- **Make illegal states unrepresentable.** Model variants as a tagged union with one discriminant field, never a bag of optional fields and booleans that allows contradictory states.
- **Build the shape so a bad value can't exist:** a non-empty list type, a start plus a duration instead of a start and an end. Strengthen a type only where the loose one forces an assertion, a cast, or a "can't happen" error.
- **Brand primitives that mean different things.** A `UserId` and an `OrderId` are both strings, but one can't be passed as the other. Only a parse function creates one.
- **Derive types from the schema that owns the shape:** OpenAPI, protobuf, GraphQL, a database migration, a validation schema. Never hand-write a parallel type that can drift.
- **Handle every variant**, so adding one is a compile error everywhere it isn't handled yet.

## Boundaries

A boundary is anything outside the process's own memory, as [testing.md](testing.md) defines it.

- **Parse where data crosses in.** Raw input becomes a domain type in one place, and a failure becomes an error there.
- **Trust types inside.** No re-validation and no defensive null checks deep in a call chain.
- **Keep business logic pure.** Boundary code reads, calls a pure function, and writes the result.
- **Stop boundary types at the adapter.** Wire, storage, and framework types never appear in the domain's signatures.

---

Types and boundaries adapted from `principle-type-system-discipline` and `principle-boundary-discipline` in [michael-denyer/pstack-claude](https://github.com/michael-denyer/pstack-claude), Copyright (c) 2026 Lauren Tan and Michael Denyer, MIT License.
