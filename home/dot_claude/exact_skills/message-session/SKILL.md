---
name: message-session
description: Resolve a CCD display title (full or partial, e.g. "the metadata session", "#2075 Metadata Parsing Bugs") to its cross-session messaging name, then message or report on that session. Triggers when the user refers to another session by its sidebar title or subject matter rather than its ListAgents name — "message the X session", "ask my Y session", "what is the Z agent working on", "tell the session working on <topic>".
argument-hint: "<display title (full or partial)>" <question or message to deliver>
---

# Message a session by display name

## Arguments

`/message-session "<display title>" <what to ask or tell it>` — the first quoted (or clearly title-like) chunk is the session reference; everything after is the intent of the message. Titles may be partial, misspelled, or subject-matter descriptions. Write the actual message yourself from the intent — don't forward the user's words verbatim. With no arguments, list the running sessions (title → peer name) and ask which one and what to send.

The desktop app shows sessions by **display title** ("#2075 Metadata Parsing Bugs - O"), but `SendMessage`/`ListAgents` address sessions by **messaging name** (folder-derived, e.g. `omnibus-42`). There is no first-class join between the two — resolve it with this procedure.

## Resolution procedure

1. **Load the session-management tools if deferred**: `ToolSearch` with `select:mcp__ccd_session_mgmt__list_sessions,mcp__ccd_session_mgmt__get_session`.
2. **Fetch both lists in one parallel round**: `ListAgents` (peer names, started-ago, refs) and `mcp__ccd_session_mgmt__list_sessions` (titles, cwd, isRunning, PR linkage).
3. **Match the user's phrase against titles**, case-insensitive substring/topic match. Subject-matter references count ("the metadata one" matches "#2075 Metadata Parsing Bugs - O"). Prefer `isRunning: true` sessions; ignore archived ones.
4. **Map the matched session to a peer name**:
   - The peer name starts with the session's cwd folder name (`/Users/seamus/Repos/omnibus` → `omnibus-XX`; note `dot-files` vs `dotfiles` style differences — match on the actual folder name).
   - If several peers share that prefix, call `get_session` on the candidate(s) and match `createdAt` against the peer list's "started Nm ago". A ±2 min match is decisive.
   - Still ambiguous → ask the user, showing the title↔name table.
5. **Act**: `SendMessage` to the resolved peer name (append the `[ref]` only if an error demands it), or answer from `get_session` metadata alone when that suffices.

## Multi-session fan-out

When one request messages several sessions, send all messages in one parallel round, then **hold the summary until every reply has arrived** — one combined digest beats a drip of partial updates. Replies land asynchronously across turns, so after an early reply, say only that you're still waiting on the others (name them) and stop. Break the hold early only when an early reply needs Seamus's input (a decision, an approval, a blocked pipeline) — surface that part immediately and keep holding the rest.

## Answer-before-messaging rule

`list_sessions`/`get_session` metadata (title, PR number + state, cwd, model, last activity) often answers "what is that agent working on" **without spending a turn in the target session**. Message the session only when the user wants live status or needs it to act.

## Edge cases

- **Title matches a session with `isRunning: false`**: `isRunning` reflects whether a turn is active, NOT whether the session is reachable. If a matching peer still appears in `ListAgents`, its inbox is alive — message it (an idle session starts a new turn on arrival). Only when no matching peer exists is the session truly gone; then offer alternatives (the user reopens it, or `search_session_transcripts` for what it was doing).
- **A peer in `ListAgents` has no CCD row**: it's a plain terminal session (not started from the app). Address it by its peer name; there is no display title to resolve.
- **Two live sessions, same repo, similar ages**: don't guess — show the table and ask.
- **User-facing output**: always report the mapping you resolved (title → peer name) so the user learns the messaging names over time.
