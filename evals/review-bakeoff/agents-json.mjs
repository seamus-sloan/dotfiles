// Turns a directory of agent definitions (chezmoi source, e.g.
// home/dot_claude/exact_private_agents) into the JSON `claude --agents` takes,
// so a candidate's agents override the installed ones for one headless run.
//
//   node agents-json.mjs <agents dir> > agents.json
import { readdirSync, readFileSync } from "node:fs"
import { join } from "node:path"

const dir = process.argv[2]
const agents = {}

for (const file of readdirSync(dir).filter((f) => f.endsWith(".md"))) {
  const text = readFileSync(join(dir, file), "utf8")
  const match = text.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/)
  if (!match) throw new Error(`${file}: no frontmatter`)
  const meta = Object.fromEntries(
    match[1].split("\n").flatMap((line) => {
      const kv = line.match(/^(\w+):\s*(.*)$/)
      return kv ? [[kv[1], kv[2].trim()]] : []
    }),
  )
  if (!meta.name) throw new Error(`${file}: no name`)
  agents[meta.name] = {
    description: meta.description,
    prompt: match[2].trim(),
    ...(meta.tools && { tools: meta.tools.split(",").map((t) => t.trim()) }),
    ...(meta.model && { model: meta.model }),
    ...(meta.effort && { effort: meta.effort }),
  }
}

process.stdout.write(JSON.stringify(agents))
