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
