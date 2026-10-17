#!/usr/bin/env bash
set -euo pipefail
export METRICS="$(cd "$(dirname "$0")" && pwd)/metrics.mjs"
node --input-type=module <<'NODE'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { spawnSync } from 'node:child_process'
const { repoMetrics, messageMetrics } = await import(process.env.METRICS)

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'pitfall-metrics-'))
const origin = path.join(root, 'origin'), work = path.join(root, 'work')
const git = (cwd, ...args) => { const r = spawnSync('git', args, { cwd, encoding: 'utf8' }); assert.equal(r.status, 0, r.stderr); return r.stdout }
fs.mkdirSync(work)
git(work, 'init', '-q', '-b', 'main')
git(work, 'config', 'user.email', 'test@example.com')
git(work, 'config', 'user.name', 'test')
const commit = (file, msg, date) => {
  fs.mkdirSync(path.dirname(path.join(work, file)), { recursive: true })
  fs.writeFileSync(path.join(work, file), msg)
  git(work, 'add', '-A')
  spawnSync('git', ['commit', '-qm', msg], { cwd: work, env: { ...process.env, GIT_AUTHOR_DATE: date, GIT_COMMITTER_DATE: date } })
}
commit('a.txt', 'feat: one\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>', '2026-10-01T12:00:00')
commit('docs/plans/2026-10-02-x.md', 'fix: two', '2026-10-02T12:00:00')
commit('supabase/migrations/20261003_x.sql', 'feat: migration', '2026-10-03T12:00:00')
commit('b.txt', 'feat: outside the window', '2026-11-01T12:00:00')
git(root, 'clone', '-q', '--bare', work, origin)
git(work, 'remote', 'add', 'origin', origin)
git(work, 'fetch', '-q', 'origin')
git(work, 'remote', 'set-head', 'origin', 'main')
assert.deepEqual(repoMetrics(work, '2026-10-01', '2026-10-31'), { commits: 3, agent: 1, fixes: 1, dateFirst: 1 }, 'counts commits, agent trailers, fix subjects and date-first adds inside the window, migrations exempt')

const msgs = path.join(root, 'messages')
fs.mkdirSync(msgs)
fs.writeFileSync(path.join(msgs, 'pulse.jsonl'), [
  { text: 'do it', prev_assistant: 'done.\n\n**Action needed:** run this' },
  { text: 'ok', prev_assistant: 'all set' },
  { text: 'hi', prev_assistant: '' },
].map(m => JSON.stringify(m)).join('\n') + '\n')
assert.deepEqual(messageMetrics(msgs), { messages: 3, replies: 2, actionNeeded: 1 }, 'counts messages and Action needed replies')
console.log('metrics: all checks passed')
NODE
