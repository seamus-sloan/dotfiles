---
name: write-ticket
description: Write and file tickets on GitHub Issues, Jira, or Linear after a thorough interview — the content first (problem, why, acceptance criteria), then every field the tracker has (GitHub type, labels, assignees, parent, blocked-by; Jira space, epic, type, priority, story points, sprint, assignee, labels). Splits work too big for one ticket into linked slices. Triggers when the user asks to "write a ticket", "create an issue", "file a ticket", "open a GitHub issue", "write a Jira ticket", "file this under <epic>", "break this into tickets", or to turn a bug or idea into a ticket.
argument-hint: "<github | jira | linear> [what the ticket is for] [any fields you already know: epic, points, sprint, assignee, labels, ...]"
---

# write-ticket

Turn an idea, a bug, or a chunk of work into well-formed tickets on the right tracker, then file them. The interview is the product: everything an implementer or reviewer would otherwise have to ask later gets asked now.

## 1. Pick the tracker

Use the tracker the arguments or the request name (`github`, `jira`, `linear`, "a GitHub issue", "a Jira ticket"). If none is named, **ask** — never infer it from the repo or the conversation.

Then read [PLATFORMS.md](PLATFORMS.md) and the tracker's detail file it points to. Read no other tracker's file.

## 2. Gather what's already settled

- **The request**: the work itself and any fields supplied ("under PROJ-201", "3 points", "assign to me", "label it tech-debt"). An explicit blank ("unassigned", "backlog", "no labels") counts as supplied.
- **The conversation**: decisions a `grilling` session settled, or its summary file under `<scratchpad>/grilling/`. Don't re-ask them.
- **The code**: when the ticket stems from code we looked at, the exact symbols and file paths.
- **The tracker**: whatever the detail file says to fetch first (a repo's issue forms and labels; a Jira epic and its sibling tickets). This is what your suggested answers come from.

## 3. Interview: the content

Run the interview in [grilling](../grilling/SKILL.md) rounds — the whole frontier per round, every question numbered with your recommended answer — on the ticket's content:

- The problem or capability: current behaviour and wanted behaviour.
- Why it matters, and to whom.
- Acceptance criteria: concrete, testable, numbered; which are stretch.
- Scope edges: what is explicitly out.
- Bugs: steps to reproduce, version and environment, expected vs actual.
- Anything the tracker's body template needs that the above doesn't cover.

Size the interview to the ticket: a small, well-understood bug may take one round; a feature takes as many as its tree needs. Facts you can look up (code paths, current behaviour, sibling tickets) are yours to find, not questions. Grilling's failure / rollback / signal check applies to features, not to bug tickets.

Decide here whether this is one ticket or several (§5).

## 4. Interview: the fields

One more round for every field the detail file lists that §2 didn't settle, each with a suggested value pre-filled and a one-line reason (what the siblings use, what the diff touches, the form's default). Silence is never a blank: a field nobody mentioned gets asked. The detail file's hard gates (a required epic, story points that can't be blank) are not skippable.

## 5. Too big for one ticket

Split when the work has more than one independent deliverable or won't fit one PR. Propose **tracer-bullet slices**:

- Each slice cuts a narrow but complete path through every layer (schema, API, UI, tests), and is demoable or verifiable on its own.
- Each fits one PR and one agent session.
- Prefactoring comes first: make the change easy, then make the easy change.
- A wide mechanical refactor (a rename or retype that breaks call sites everywhere at once) can't be sliced vertically: sequence it expand → migrate in batches → contract, each batch its own ticket blocked by the expand, the contract blocked by every batch.

Show the breakdown as a numbered list — title, what it delivers, which slices block it — and ask whether the granularity is right, whether each blocking edge is real, and whether any slice should merge or split. Iterate until approved. Fields in §4 are asked once for the whole set and applied to every slice unless the user says otherwise. The detail file says how the slices link.

## 6. File it

Once the interview is done, create the tickets — no draft review, no second confirmation. Follow the detail file's create steps. File blockers first so later tickets can reference real IDs. Never close or edit an existing parent beyond linking to it.

## 7. Report

Every ticket as a clickable URL, then a table of every field set, by name — so a wrong sprint or label is caught at a glance — plus each link created and anything that needed a second pass.

## Hard rules

- **Never** pick the tracker when none was named. Ask.
- **Never** leave a field blank because nobody mentioned it. Ask.
- **Never** re-ask what the conversation or a grilling summary already settled.
- **Never** describe a relationship in prose ("Related tickets: …"). Use the tracker's real links.
- **Never** file before the interview is done, and never ask for a confirmation after it.

---

Tracer-bullet slicing and expand–contract sequencing adapted from `to-tickets` in [mattpocock/skills](https://github.com/mattpocock/skills), Copyright (c) 2026 Matt Pocock, MIT License.
