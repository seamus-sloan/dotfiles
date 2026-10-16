---
name: web-design-guidelines
description: Review UI code against Vercel's Web Interface Guidelines (accessibility, focus, forms, motion, typography, performance, i18n). Use when asked to "review my UI", "check accessibility", "audit design", "review UX", or "check my site against best practices".
argument-hint: <file-or-pattern>
---

# Web Interface Guidelines

Review UI files against the rules in [command.md](command.md), a pinned copy of `command.md` from [vercel-labs/web-interface-guidelines](https://github.com/vercel-labs/web-interface-guidelines) at `434b7f9`.

1. Take the files or glob the user named. With none, ask which files to review.
2. Read `command.md` in this skill's directory. Its `$ARGUMENTS` stands for those files.
3. Check every file against every rule, and report in its **Output Format**: grouped by file, one `file:line - finding` per issue, and `✓ pass` for a clean file.

To update the rules, copy a newer `command.md` over this one and review the diff before committing.
