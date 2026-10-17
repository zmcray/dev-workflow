#!/usr/bin/env node
// Deterministic numbers for the pitfall study: no model judgment, so two runs compare like for like.
// usage: metrics.mjs --since YYYY-MM-DD --until YYYY-MM-DD --messages <dir> [--baseline <file>] [--json <out>]
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const REPOS = ['pulse', 'motus', 'saidso', 'pulse-ios', 'telos', 'argus', 'sonar', 'quoting', 'dev-workflow', 'mcray-os-skills']
const AGENT = /Co-Authored-By:.*(Claude|Codex|Cursor|noreply@anthropic\.com)/i
const FIX = /^(fix|revert|hotfix)\b|^Revert "/i
const DATE_FIRST = /^(19|20)\d{2}-\d{2}-\d{2}/
const ACTION_NEEDED = /\*\*Action needed/i

const arg = (argv, flag) => { const i = argv.indexOf(flag); return i >= 0 ? argv[i + 1] : undefined }
const git = (cwd, ...args) => execFileSync('git', args, { cwd, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 })

export function repoMetrics(dir, since, until) {
  const ref = git(dir, 'rev-parse', '--abbrev-ref', 'origin/HEAD').trim()
  const log = git(dir, 'log', ref, '--no-merges', `--since=${since}T00:00:00`, `--until=${until}T23:59:59`, '--format=%x1e%H%x1f%s%x1f%B', '--name-status', '--diff-filter=AR')
  let commits = 0, agent = 0, fixes = 0, dateFirst = 0
  for (const entry of log.split('\x1e').filter(Boolean)) {
    const [, subject, rest = ''] = entry.split('\x1f')
    commits++
    if (AGENT.test(rest)) agent++
    if (FIX.test(subject)) fixes++
    const added = rest.split('\n').filter(l => /^[AR]\d*\t/.test(l)).map(l => l.split('\t').pop())
    if (added.some(f => !/(^|\/)migrations\//.test(f) && DATE_FIRST.test(path.basename(f)))) dateFirst++
  }
  return { commits, agent, fixes, dateFirst }
}

export function messageMetrics(dir) {
  let messages = 0, replies = 0, actionNeeded = 0
  for (const file of fs.existsSync(dir) ? fs.readdirSync(dir).filter(f => f.endsWith('.jsonl')) : []) {
    for (const line of fs.readFileSync(path.join(dir, file), 'utf8').split('\n').filter(Boolean)) {
      const m = JSON.parse(line)
      messages++
      if (m.prev_assistant) { replies++; if (ACTION_NEEDED.test(m.prev_assistant)) actionNeeded++ }
    }
  }
  return { messages, replies, actionNeeded }
}

const pct = (a, b) => b ? `${(100 * a / b).toFixed(1)}%` : 'n/a'

function main(argv) {
  const since = arg(argv, '--since'), until = arg(argv, '--until'), messages = arg(argv, '--messages')
  if (!since || !until || !messages) {
    process.stderr.write('usage: metrics.mjs --since YYYY-MM-DD --until YYYY-MM-DD --messages <dir> [--baseline <file>] [--json <out>]\n')
    return 64
  }
  const repos = {}
  for (const r of REPOS) {
    const dir = path.join(os.homedir(), 'Developer', r)
    if (fs.existsSync(dir)) repos[r] = repoMetrics(dir, since, until)
  }
  const total = Object.values(repos).reduce((t, m) => ({ commits: t.commits + m.commits, agent: t.agent + m.agent, fixes: t.fixes + m.fixes, dateFirst: t.dateFirst + m.dateFirst }), { commits: 0, agent: 0, fixes: 0, dateFirst: 0 })
  const msg = messageMetrics(messages)
  const result = { since, until, repos, total, messages: msg }
  const baseline = arg(argv, '--baseline') ? JSON.parse(fs.readFileSync(arg(argv, '--baseline'), 'utf8')) : null
  const b = baseline?.deterministic
  const row = (name, now, then) => `| ${name} | ${now} | ${then ?? 'n/a'} |`
  const lines = [
    `# Pitfall metrics ${since} to ${until}`, '',
    '| Metric | This run | Baseline |', '|---|---|---|',
    row('Commits', total.commits, b?.total.commits),
    row('Agent-co-authored share', pct(total.agent, total.commits), b && pct(b.total.agent, b.total.commits)),
    row('Fix-subject share (fix/revert/hotfix)', pct(total.fixes, total.commits), b && pct(b.total.fixes, b.total.commits)),
    row('Commits adding a date-first file', total.dateFirst, b?.total.dateFirst),
    row('Zack messages', msg.messages, b?.messages.messages),
    row('Agent replies with "Action needed"', pct(msg.actionNeeded, msg.replies), b && pct(b.messages.actionNeeded, b.messages.replies)),
    '', '| Repo | Commits | Agent | Fix-subject | Date-first adds |', '|---|---|---|---|---|',
    ...Object.entries(repos).map(([r, m]) => `| ${r} | ${m.commits} | ${pct(m.agent, m.commits)} | ${pct(m.fixes, m.commits)} | ${m.dateFirst} |`),
  ]
  if (baseline?.judged) lines.push('', `Judged baselines (need the classifier pass in classify-prompt.md): ${Object.entries(baseline.judged).map(([k, v]) => `${k} ${v}`).join('; ')}.`)
  process.stdout.write(lines.join('\n') + '\n')
  if (arg(argv, '--json')) fs.writeFileSync(arg(argv, '--json'), JSON.stringify(result, null, 2) + '\n')
  return 0
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try { process.exitCode = main(process.argv.slice(2)) } catch (error) {
    process.stderr.write(`metrics: ${error.message}\n`)
    process.exitCode = 70
  }
}
