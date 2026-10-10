# Coding Standards

How I want code written, in any repo, by any agent. Start here, then read only the files the task needs.

## Which rule wins

1. **The repo's written rules:** its `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, and linter or formatter config.
2. **The repo's existing layout:** where tests live, which runner and helpers it uses, whether integration tests sit in another repo. Follow it, and never restructure it unless asked.
3. **The file being edited:** a test added to an existing file matches that file's naming and shape.
4. **These standards:** everything else, including every new test file.

Between these files, a language file beats [testing.md](testing.md) on syntax: names, file locations, runners.

## What to read

| Task | Read |
|---|---|
| Writing or changing any code or config, tests included | [code.md](code.md) |
| Writing or changing any test | [testing.md](testing.md), then the language file |

| Language | File |
|---|---|
| TypeScript, JavaScript | [languages/typescript.md](languages/typescript.md) |
| Go | [languages/go.md](languages/go.md) |
| Rust | [languages/rust.md](languages/rust.md) |

A language with no file follows [testing.md](testing.md) using its ecosystem's most common runner and layout. Ask before settling anything it leaves open.

## Adding a language

Give it the same sections as the others: runner, where tests live, naming, doubles, then one complete unit example and one complete integration example. Agents copy the examples more faithfully than they follow the rules, so the examples must obey every rule.
