#!/usr/bin/env node
// Proves which repos call the shared guards workflow. For each repo in config/guards-repos.json it reads
// every workflow file on the default branch and checks: (a) some job calls guards.yml, (b) the gate job
// lists the guards job in `needs`, (c) the call passes `swift: true` when the repo needs it.
// Unsure means MISSING: there is no YAML library, so only the small subset needed is parsed, by indentation.
//
// usage: guards-audit.mjs [--dir <path>] [--config <file>]
//   --dir <path>   read <path>/<repo>/.github/workflows/ from disk instead of GitHub (offline tests)
//   exit 1 if any repo is missing something, 0 otherwise
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'

const HERE = path.dirname(new URL(import.meta.url).pathname)
const USES = /^zmcray\/dev-workflow\/\.github\/workflows\/guards\.yml@\S+$/

const indentOf = line => line.length - line.trimStart().length
const clean = text => text.split('\n')
  .map(l => l.replace(/\s+#.*$/, '').replace(/^\s*#.*$/, '').replace(/\s+$/, ''))
  .filter(l => l.trim() !== '' && !/\t/.test(l.slice(0, indentOf(l))))
const unquote = v => v.trim().replace(/^(['"])(.*)\1$/, '$2')

// Returns { jobs: { id: { uses, swift, needs } } } or throws when the shape is not what we expect.
export function parseWorkflow(text) {
  const lines = clean(text)
  const start = lines.findIndex(l => /^jobs:\s*$/.test(l))
  if (start < 0) throw new Error('no jobs: section')
  const body = lines.slice(start + 1).filter(l => indentOf(l) > 0)
  if (!body.length) throw new Error('empty jobs')
  const jobIndent = indentOf(body[0])
  const jobs = {}
  let current = null
  let chunk = []
  const flush = () => { if (current) jobs[current] = readJob(chunk) }
  for (const line of body) {
    if (indentOf(line) === jobIndent) {
      const m = line.trim().match(/^([\w-]+):\s*$/)
      if (!m) throw new Error(`cannot read job header: ${line.trim()}`)
      flush()
      current = m[1]
      chunk = []
    } else if (indentOf(line) < jobIndent) {
      throw new Error('jobs section is not uniformly indented')
    } else chunk.push(line)
  }
  flush()
  return { jobs }
}

function readJob(chunk) {
  const job = { uses: null, swift: false, needs: [] }
  if (!chunk.length) return job
  const prop = indentOf(chunk[0])
  for (let i = 0; i < chunk.length; i++) {
    const line = chunk[i]
    if (indentOf(line) !== prop) continue
    const t = line.trim()
    let m
    if ((m = t.match(/^uses:\s*(.+)$/))) job.uses = unquote(m[1])
    else if ((m = t.match(/^needs:\s*(.*)$/))) {
      const rest = m[1].trim()
      if (rest.startsWith('[')) {
        if (!rest.endsWith(']')) throw new Error('multi-line flow list for needs')
        job.needs = rest.slice(1, -1).split(',').map(unquote).filter(Boolean)
      } else if (rest) job.needs = [unquote(rest)]
      else {
        for (let j = i + 1; j < chunk.length && indentOf(chunk[j]) >= prop; j++) {
          const item = chunk[j].trim().match(/^-\s*(.+)$/)
          if (indentOf(chunk[j]) === prop && !item) break
          if (!item) throw new Error('cannot read needs list')
          job.needs.push(unquote(item[1]))
        }
      }
    } else if (t === 'with:') {
      for (let j = i + 1; j < chunk.length && indentOf(chunk[j]) > prop; j++) {
        const m2 = chunk[j].trim().match(/^swift:\s*(.+)$/)
        if (m2 && unquote(m2[1]) === 'true') job.swift = true
      }
    }
  }
  return job
}

// Reasons this repo's workflows do not satisfy the table, [] when wired.
export function check(files, want) {
  const parsed = []
  const problems = []
  for (const [name, text] of Object.entries(files)) {
    try { parsed.push(parseWorkflow(text)) } catch (e) { problems.push(`cannot parse ${name} (${e.message})`) }
  }
  const attempts = []
  for (const wf of parsed) {
    for (const [id, job] of Object.entries(wf.jobs)) {
      if (!job.uses || !USES.test(job.uses)) continue
      const miss = []
      if (want.gate) {
        const gate = wf.jobs[want.gate]
        if (!gate) miss.push(`gate job "${want.gate}" not in the same workflow as the call`)
        else if (!gate.needs.includes(id)) miss.push(`gate "${want.gate}" does not need "${id}"`)
      }
      if (want.swift && !job.swift) miss.push('call does not pass swift: true')
      attempts.push(miss)
    }
  }
  if (!attempts.length) return ['no job calls guards.yml', ...problems]
  if (attempts.some(m => m.length === 0)) return []
  return [...attempts.sort((a, b) => a.length - b.length)[0], ...problems]
}

function ghFiles(owner, repo) {
  const gh = args => execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 16 << 20 })
  const base = `repos/${owner}/${repo}/contents/.github/workflows`
  const list = JSON.parse(gh(['api', base]))
  const files = {}
  for (const f of list.filter(x => x.type === 'file' && /\.ya?ml$/.test(x.name))) {
    files[f.name] = gh(['api', '-H', 'Accept: application/vnd.github.raw', `${base}/${f.name}`])
  }
  return files
}

function dirFiles(dir, repo) {
  const wf = path.join(dir, repo, '.github', 'workflows')
  const files = {}
  for (const name of fs.readdirSync(wf).filter(n => /\.ya?ml$/.test(n))) files[name] = fs.readFileSync(path.join(wf, name), 'utf8')
  return files
}

function main() {
  const argv = process.argv.slice(2)
  const opt = name => { const i = argv.indexOf(name); return i < 0 ? null : argv[i + 1] }
  const dir = opt('--dir')
  const config = JSON.parse(fs.readFileSync(opt('--config') ?? path.join(HERE, '..', 'config', 'guards-repos.json'), 'utf8'))
  let bad = 0
  for (const [repo, want] of Object.entries(config.repos)) {
    let problems
    try {
      const files = dir ? dirFiles(dir, repo) : ghFiles(config.owner, repo)
      problems = Object.keys(files).length ? check(files, want) : ['no workflow files']
    } catch (e) {
      problems = [`could not read workflows (${String(e.stderr || e.message).trim().split('\n')[0]})`]
    }
    if (problems.length) bad++
    console.log(`${repo}: ${problems.length ? `MISSING: ${problems.join('; ')}` : 'wired'}`)
  }
  process.exit(bad ? 1 : 0)
}

if (process.argv[1] && path.resolve(process.argv[1]) === new URL(import.meta.url).pathname) main()
