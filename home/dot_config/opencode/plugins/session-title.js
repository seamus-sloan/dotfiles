import { execFile } from "node:child_process"

/**
 * session-title.js — the opencode half of the session-title convention.
 *
 * Keeps a session title in the shape
 *
 *   "<Objective> - <CODE>"        e.g. "Rename Sessions - D"
 *
 * and folds a PR number in once one is opened:
 *
 *   "#123 Rename Sessions - D"
 *
 * Claude Code needs a hook that *asks the model* to rename the session, because
 * only the set_session_title MCP tool can move that title. opencode is easier on
 * both counts: it already auto-generates an objective-shaped title, and the SDK
 * exposes session.update. So this plugin never prompts the model — it waits for
 * opencode's own title, then rewrites it deterministically.
 *
 * The code comes from ~/.claude/hooks/repo-code.sh, the same lookup Claude Code
 * uses, so a repo is labelled identically in both tools.
 *
 * Patterns and rationale documented in ~/.claude/skills/session-title/SKILL.md.
 *
 * @type {import("@opencode-ai/plugin").Plugin}
 */
export const SessionTitle = async ({ client, directory, worktree }) => {
  const PR_URL = /https:\/\/github\.com\/[^/\s]+\/[^/\s]+\/pull\/(\d+)/
  const PR_PREFIX = /^#\d+\s+/

  // opencode seeds a session with "New session - <ISO timestamp>" and only
  // replaces it once the title agent has summarized the conversation. Appending
  // the code to that placeholder produced titles like
  // "New session - 2026-09-14T17:18:54.195Z - D", so wait for the real title.
  const PLACEHOLDER = /^New session - \d{4}-\d{2}-\d{2}T[\d:.]+Z$/

  // Resolved once per plugin instance: a plugin is loaded per directory, and the
  // repo a directory belongs to does not change under us. The path is built here
  // rather than relying on shell expansion, and passed as a single argv entry, so
  // neither `~` nor a space in the path needs quoting.
  //
  // Deliberately node:child_process and not the plugin's `$`: opencode only
  // supplies `$` when it is running under Bun (`$: typeof Bun === "undefined" ?
  // undefined : Bun.$`), and the desktop app runs its server inside Electron's
  // Node runtime, where `$` is therefore undefined and calling it threw
  // "$ is not a function" on every session.updated.
  const script = `${process.env.HOME}/.claude/hooks/repo-code.sh`
  let codePromise

  /** Short project code for this worktree, or "" when it isn't in a git repo. */
  const repoCode = () => {
    codePromise ??= new Promise((resolve, reject) => {
      execFile(script, [worktree ?? directory], { encoding: "utf8" }, (error, stdout) =>
        error ? reject(error) : resolve(stdout.trim()),
      )
    }).catch(() => {
      // Clear the cache on failure. A rejected promise left in `codePromise` is
      // re-awaited by every subsequent session.updated, which is what turned one
      // missing-script error into a flood of unhandled rejections.
      codePromise = undefined
      return ""
    })
    return codePromise
  }

  // Titles this plugin has written, keyed by session. session.update publishes
  // another session.updated, so without this the handler would chase its own
  // tail forever.
  const written = new Map()

  // PR numbers already folded in, so a retried `gh pr create` against the same
  // branch doesn't nest prefixes into "#124 #123 Rename Sessions - D".
  const folded = new Map()

  const setTitle = async (session, title) => {
    if (!title || title === session.title) return
    written.set(session.id, title)
    await client.session
      .update({
        path: { id: session.id },
        query: { directory: session.directory },
        body: { title },
      })
      .catch(() => {})
  }

  return {
    event: async ({ event }) => {
      if (event.type === "session.deleted") {
        written.delete(event.properties.info.id)
        folded.delete(event.properties.info.id)
        return
      }

      if (event.type !== "session.updated") return
      const session = event.properties.info

      // Subagent sessions are never surfaced in the sidebar, so labelling them
      // is noise the user pays for in API calls.
      if (session.parentID) return

      // Our own write coming back around.
      if (written.get(session.id) === session.title) return

      const code = await repoCode()
      if (!code) return

      const suffix = ` - ${code}`
      const base = session.title.replace(PR_PREFIX, "")
      if (PLACEHOLDER.test(base)) return
      if (base.endsWith(suffix)) return

      const number = folded.get(session.id)
      await setTitle(session, `${number ? `#${number} ` : ""}${base}${suffix}`)
    },

    // A PR was opened: fold its number into the title. Scanning the whole tool
    // output rather than a named field keeps this working if the bash result
    // shape shifts.
    "tool.execute.after": async (input, output) => {
      if (input.tool !== "bash") return
      if (!/\bgh\s+pr\s+create\b/.test(String(input.args?.command ?? ""))) return

      const number = output.output?.match(PR_URL)?.[1]
      if (!number) return
      if (folded.get(input.sessionID) === number) return
      folded.set(input.sessionID, number)

      const session = await client.session
        .get({ path: { id: input.sessionID }, query: { directory } })
        .then((res) => res.data)
        .catch(() => undefined)
      if (!session) return

      await setTitle(session, `#${number} ${session.title.replace(PR_PREFIX, "")}`)
    },
  }
}
