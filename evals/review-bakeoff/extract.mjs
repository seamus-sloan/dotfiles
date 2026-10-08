// Pulls a headless review run's output into files the grader can read:
//
//   node extract.mjs <run dir>
//
// Reads <run dir>/stream.jsonl (claude -p --output-format stream-json) and the
// session's transcripts, then writes:
//   report.md      the final reply
//   findings.json  every ReportFindings payload (code-review), last one last
//   usage.json     cost, turns, duration, and subagent count
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

const run = process.argv[2]
const lines = (file) =>
  readFileSync(file, "utf8")
    .split("\n")
    .filter(Boolean)
    .flatMap((l) => {
      try {
        return [JSON.parse(l)]
      } catch {
        return []
      }
    })

const stream = lines(join(run, "stream.jsonl"))
const result = stream.findLast((e) => e.type === "result")
const sessionId = stream.find((e) => e.session_id)?.session_id

// Transcripts: the main session file plus any subagent files under it.
const transcripts = []
const projects = join(homedir(), ".claude/projects")
for (const project of existsSync(projects) ? readdirSync(projects) : []) {
  const main = join(projects, project, `${sessionId}.jsonl`)
  if (existsSync(main)) transcripts.push(main)
  const subs = join(projects, project, sessionId ?? "", "subagents")
  if (sessionId && existsSync(subs))
    for (const f of readdirSync(subs).filter((f) => f.endsWith(".jsonl"))) transcripts.push(join(subs, f))
}

const toolUses = (events) =>
  events.flatMap((e) => (Array.isArray(e.message?.content) ? e.message.content : [])).filter((c) => c.type === "tool_use")

const all = [...toolUses(stream), ...transcripts.flatMap((t) => toolUses(lines(t)))]
const seen = new Set()
const findings = all
  .filter((t) => t.name === "ReportFindings" && !seen.has(t.id) && seen.add(t.id))
  .map((t) => t.input)

const agentCalls = all.filter((t) => t.name === "Agent" || t.name === "Task")

// A reviewer that wandered into the harness (a sibling worktree, `git log --all
// -p`) has seen the answer key; such a run doesn't count.
const leaks = [...new Set(transcripts.flatMap((t) => readFileSync(t, "utf8").match(/answers\.md|verify-seeds|review-bakeoff/g) ?? []))]

writeFileSync(join(run, "report.md"), `${result?.result ?? "(no result event)"}\n`)
writeFileSync(join(run, "findings.json"), `${JSON.stringify(findings, null, 2)}\n`)
writeFileSync(
  join(run, "usage.json"),
  `${JSON.stringify(
    {
      session_id: sessionId,
      cost_usd: result?.total_cost_usd,
      duration_min: result?.duration_ms && +(result.duration_ms / 60000).toFixed(1),
      turns: result?.num_turns,
      subagents: new Set(agentCalls.map((t) => t.id)).size,
      subagent_types: agentCalls.reduce((m, t) => ({ ...m, [t.input?.subagent_type ?? "?"]: (m[t.input?.subagent_type ?? "?"] ?? 0) + 1 }), {}),
      transcripts: transcripts.length,
      contaminated: leaks,
    },
    null,
    2,
  )}\n`,
)
console.log(
  `${run}: ${findings.length} ReportFindings payload(s), ${agentCalls.length} subagent call(s), $${result?.total_cost_usd?.toFixed?.(2)}${leaks.length ? `, CONTAMINATED (${leaks.join(", ")})` : ""}`,
)
