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

  // Wait for the real title, not opencode's "New session - <timestamp>" seed.
  const PLACEHOLDER = /^New session - \d{4}-\d{2}-\d{2}T[\d:.]+Z$/

  // node:child_process, not `$`: the desktop app runs on Node, where `$` is undefined.
  const script = `${process.env.HOME}/.claude/hooks/repo-code.sh`
  let codePromise

  /** Short project code for this worktree, or "" when it isn't in a git repo. */
  const repoCode = () => {
    codePromise ??= new Promise((resolve, reject) => {
      execFile(script, [worktree ?? directory], { encoding: "utf8" }, (error, stdout) =>
        error ? reject(error) : resolve(stdout.trim()),
      )
    }).catch(() => {
      // Drop the failed promise, or every later event re-awaits the rejection.
      codePromise = undefined
      return ""
    })
    return codePromise
  }

  // Titles we wrote, so our own session.updated events don't loop.
  const written = new Map()

  // PR numbers already folded in, so a retried `gh pr create` can't nest prefixes.
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

      // Subagent sessions never show in the sidebar.
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

    // Fold an opened PR's number into the title; scan all output in case its shape shifts.
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
