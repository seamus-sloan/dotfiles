// Scoreboard for graded runs: one row per run, seeds split by bucket.
//
//   node scoreboard.mjs <run dir | runs root> ...
//
// FOUND scores 1 and PARTIAL 0.5. A contaminated run is listed but flagged.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs"
import { basename, dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))

const runs = process.argv.slice(2).flatMap(function find(p) {
  if (existsSync(join(p, "grade.json"))) return [p]
  return statSync(p).isDirectory() ? readdirSync(p).flatMap((d) => (statSync(join(p, d)).isDirectory() ? find(join(p, d)) : [])) : []
})

// Bucket of every seed, read from each fixture's answer key.
const buckets = {}
for (const f of readdirSync(join(here, "fixtures"))) {
  const key = join(here, "fixtures", f, "answers.md")
  if (!existsSync(key)) continue
  for (const m of readFileSync(key, "utf8").matchAll(/^\| ([A-Z]+\d+) \| (\w+) \|/gm)) buckets[m[1]] = m[2]
}

const pts = { FOUND: 1, PARTIAL: 0.5 }
const rows = runs.sort().map((run) => {
  const grade = JSON.parse(readFileSync(join(run, "grade.json"), "utf8"))
  const usage = existsSync(join(run, "usage.json")) ? JSON.parse(readFileSync(join(run, "usage.json"), "utf8")) : {}
  const by = {}
  for (const s of grade.seeds) {
    const b = buckets[s.id] ?? "?"
    by[b] ??= { got: 0, of: 0, ids: [] }
    by[b].of += 1
    by[b].got += pts[s.status] ?? 0
    if (s.status !== "FOUND") by[b].ids.push(`${s.id}:${s.status[0]}`)
  }
  const extras = grade.extras ?? []
  const count = (c) => extras.filter((e) => e.class === c).length
  const cell = (b) => (by[b] ? `${by[b].got}/${by[b].of}` : "—")
  return [
    basename(dirname(run)),
    basename(run).replace(/-\d{8}-\d{6}$/, ""),
    cell("bug"),
    cell("spec"),
    cell("test"),
    cell("excess"),
    cell("unplanted"),
    count("VALID"),
    count("FALSE"),
    count("NIT"),
    usage.cost_usd != null ? `$${usage.cost_usd.toFixed(2)}` : "?",
    usage.duration_min ?? "?",
    usage.subagents ?? "?",
    [Object.values(by).flatMap((b) => b.ids).join(" "), usage.contaminated?.length ? "⚠ contaminated" : ""].filter(Boolean).join(" "),
  ]
})

const head = ["fixture", "reviewer", "bugs", "spec", "tests", "excess", "unplanted", "new valid", "false+", "nits", "cost", "min", "agents", "not FOUND"]
console.log(`| ${head.join(" | ")} |\n|${head.map(() => "---").join("|")}|`)
for (const r of rows) console.log(`| ${r.join(" | ")} |`)
