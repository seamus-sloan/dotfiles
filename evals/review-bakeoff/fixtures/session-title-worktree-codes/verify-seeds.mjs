// Reproduces every planted defect in the session-title-worktree-codes fixture,
// so the answer key is evidence rather than intent. Usage:
//
//   node verify-seeds.mjs <fixture worktree>
//
// Every line should print REPRODUCED.
import { execFileSync, spawnSync } from "node:child_process"
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"

const fix = resolve(process.argv[2])
const script = join(fix, "home/dot_claude/exact_hooks/executable_repo-code.sh")
const pluginPath = join(fix, "home/dot_config/opencode/plugins/session-title.js")
const T = mkdtempSync(join(tmpdir(), "seeds-"))
process.on("exit", () => rmSync(T, { recursive: true, force: true }))

const seed = (id, reproduced, detail = "") =>
  console.log(`${reproduced ? "REPRODUCED     " : "not-reproduced "} ${id}${detail ? ` — ${detail}` : ""}`)

// A git repo named "dotfiles" plus a HOME whose repo-codes pins it two ways.
const repo = join(T, "src/dotfiles")
mkdirSync(repo, { recursive: true })
execFileSync("git", ["init", "-q", repo])
const home = join(T, "home")
mkdirSync(join(home, ".claude/hooks"), { recursive: true })
writeFileSync(join(home, ".claude/repo-codes"), `dotfiles   D\n${repo}   W\n`)
const env = { ...process.env, HOME: home }
const run = (...args) => spawnSync("bash", [script, ...args], { env, encoding: "utf8" })

// B1: the path row should beat the repo-name row, but the first match wins.
const b2 = run(repo, repo)
seed("B1 path row loses to the repo-name row", b2.stdout.trim() === "D", `got ${JSON.stringify(b2.stdout.trim())}, want "W"`)

// B6: one-argument callers (session-title.sh) die on `set -u`.
const b9 = run(repo)
seed("B6 one-arg call exits non-zero with no code", b9.status !== 0 && b9.stdout === "", b9.stderr.trim())

// Plugin harness: a stub lookup that prints the directory's last segment.
const hooksDir = join(home, ".claude/hooks")
const stub = join(hooksDir, "repo-code.sh")
const argLog = join(T, "args.log")
const writeStub = () => {
  writeFileSync(stub, `#!/bin/sh\nprintf '%s\\n' "$@" >> "${argLog}"\nbasename "$1" | tr a-z A-Z\n`)
  chmodSync(stub, 0o755)
}
process.env.HOME = home
const { SessionTitle } = await import(pluginPath)

const plugin = async ({ directory = "/w/root", worktree } = {}) => {
  const sessions = new Map()
  const titles = []
  const client = {
    session: {
      update: async ({ path, body }) => {
        titles.push(body.title)
        sessions.get(path.id).title = body.title
      },
      get: async ({ path }) => ({ data: sessions.get(path.id) }),
    },
  }
  const hooks = await SessionTitle({ client, directory, worktree })
  const updated = (s) => {
    sessions.set(s.id, s)
    return hooks.event({ event: { type: "session.updated", properties: { info: s } } })
  }
  return { hooks, titles, updated }
}

// B3: a failed lookup is cached as "" forever; the old code retried.
rmSync(stub, { force: true })
{
  const { titles, updated } = await plugin()
  await updated({ id: "s1", title: "Fix Build - X", directory: "/w/ab" })
  writeStub()
  await updated({ id: "s2", title: "Add Tests - X", directory: "/w/ab" })
  seed("B3 lookup failure cached; no code after the script appears", titles.length === 0, `titles ${JSON.stringify(titles)}`)
}

// B2: opencode always supplies `worktree`, so `worktree ?? session.directory`
// never consults the session's own directory.
{
  const { titles, updated } = await plugin({ worktree: "/w/root" })
  await updated({ id: "s1", title: "Fix Build - X", directory: "/w/ab" })
  seed("B2 session in /w/ab labelled with the instance worktree's code", titles[0] === "Fix Build - ROOT", `titles ${JSON.stringify(titles)}`)
}

// B4: exec() splits the directory on spaces and runs shell metacharacters.
{
  rmSync(argLog, { force: true })
  const { updated } = await plugin()
  await updated({ id: "s1", title: "Fix Build - X", directory: "/w/my dir" })
  const firstArg = readFileSync(argLog, "utf8").split("\n")[0]
  const pwned = join(T, "pwned")
  await updated({ id: "s2", title: "Fix Build - X", directory: `/w/x;touch ${pwned}` })
  seed("B4 directory split on spaces / shell-injected", firstArg === "/w/my" && existsSync(pwned), `first argv "${firstArg}", injected file ${existsSync(pwned)}`)
}

// B5: search() returns -1 with no suffix, `!at` misses it, slice(0, -1) eats a char.
{
  const { titles, updated } = await plugin()
  await updated({ id: "s1", title: "Rename Sessions", directory: "/w/d" })
  await updated({ id: "s2", title: "New session - 2026-09-14T17:18:54.195Z", directory: "/w/d" })
  seed("B5 fresh title loses its last char; placeholder gets a code", titles[0] === "Rename Session - D" && titles.length === 2, `titles ${JSON.stringify(titles)}`)
}

// B7: the per-directory test never passes `worktree`, so it stays green through B2.
const b10 = spawnSync("node", ["--test", "tests/session-title.test.mjs"], { cwd: fix, encoding: "utf8" })
seed("B7 'resolves the code per session directory' green despite B2", b10.status === 0)

// B8: the spec's `gh pr view` fold never reached Claude Code's hook.
const hook = readFileSync(join(fix, "home/dot_claude/exact_hooks/executable_session-title.sh"), "utf8")
seed("B8 session-title.sh still matches only gh pr create", !/view/.test(hook))

// B9: CodeCache.clear and .size have no callers.
const src = readFileSync(pluginPath, "utf8")
seed("B9 CodeCache.clear / .size unused", /clear\(dir\)/.test(src) && !/codes\.(clear|size)\b/.test(src))
