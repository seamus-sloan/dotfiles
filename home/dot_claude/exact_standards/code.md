# Code

Rules for all code in any language: source, tests, and scripts.

## Comments

- **Doc comments are encouraged.** Document public modules, types, and functions in the language's doc syntax: what it does, what it returns, what a caller must know. Keep them terse, and never restate the signature.
- **An inline comment is a smell.** Code that needs one to be understood gets rewritten first: a clearer name, an extracted function, a named constant.
- **A comment that survives says why, never what:** a workaround, a non-obvious constraint, a link to the bug. One terse line.
- **Never more than three lines.** Only documentation runs longer, such as a usage block at the top of a script.
- **Never** leave commented-out code, comments that narrate the next line, or change history (`// added retries`, `// fixed bug`). Git holds that.

```ts
// Before: a comment carries what the code doesn't say
// only retry failed jobs that are under the limit and not cancelled
if (job.status === 'failed' && job.retries < MAX_RETRIES && !job.cancelled) {

// After: the name says it
if (isRetryable(job)) {
```
