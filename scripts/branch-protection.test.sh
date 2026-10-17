#!/usr/bin/env bash
set -euo pipefail
export SCRIPT="$(cd "$(dirname "$0")" && pwd)/branch-protection.mjs"
node <<'NODE'
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'branch-protection-'))
const bin = path.join(root, 'bin')
fs.mkdirSync(bin)
const state = path.join(root, 'state.json')
const log = path.join(root, 'puts.jsonl')
// A fake gh that serves protection, repo and check-run fixtures and records every PUT.
fs.writeFileSync(path.join(bin, 'gh'), `#!/usr/bin/env node
const fs = require('node:fs')
const s = JSON.parse(fs.readFileSync(process.env.STATE, 'utf8'))
const a = process.argv.slice(2)
if (a[0] === 'pr') { process.stdout.write(JSON.stringify([{ headRefOid: 'abc' }])); process.exit(0) }
const put = a.includes('PUT')
const ep = a.find(x => x.startsWith('repos/'))
if (put) { fs.appendFileSync(process.env.LOG, JSON.stringify({ ep, body: JSON.parse(fs.readFileSync(0, 'utf8')) }) + '\\n'); process.stdout.write('{}'); process.exit(0) }
const repo = ep.split('/')[2]
if (ep.endsWith('/protection')) {
  const p = s.protection[repo]
  if (!p) { process.stderr.write('Branch not protected (HTTP 404)'); process.exit(1) }
  process.stdout.write(JSON.stringify(p)); process.exit(0)
}
if (ep.includes('/check-runs')) { process.stdout.write(JSON.stringify({ check_runs: (s.runs[repo] || []).map(name => ({ name })) })); process.exit(0) }
process.stdout.write(JSON.stringify({ default_branch: 'main' }))
`)
fs.chmodSync(path.join(bin, 'gh'), 0o755)
const run = (fixture, ...args) => {
  fs.writeFileSync(state, JSON.stringify(fixture))
  fs.rmSync(log, { force: true })
  return spawnSync(process.execPath, [process.env.SCRIPT, ...args], { encoding: 'utf8', env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, STATE: state, LOG: log } })
}
const puts = () => fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim().split('\n').map(JSON.parse) : []
const good = { required_status_checks: { strict: true, contexts: ['ci'] }, enforce_admins: { enabled: true }, required_pull_request_reviews: { required_approving_review_count: 0 } }
const loose = { required_status_checks: { strict: false, contexts: ['ci'] }, enforce_admins: { enabled: false }, required_pull_request_reviews: null }

let r = run({ protection: { Pulse: good }, runs: { Pulse: ['ci'] } }, 'audit', 'Pulse')
assert.equal(r.status, 0, r.stdout + r.stderr)
assert.match(r.stdout, /Pulse: ok/, 'matching protection reads ok')

r = run({ protection: { Pulse: loose }, runs: { Pulse: ['ci'] } }, 'audit', 'Pulse')
assert.equal(r.status, 1, 'drift fails the audit')
assert.match(r.stdout, /strict is false, want true/)
assert.match(r.stdout, /enforce_admins is false, want true/)
assert.match(r.stdout, /require_pull_request is false, want true/)
assert.equal(puts().length, 0, 'audit never writes')

r = run({ protection: {}, runs: {} }, 'audit', 'mcray-os-skills')
assert.equal(r.status, 1)
assert.match(r.stdout, /mcray-os-skills: branch is not protected/, 'an unprotected repo is reported')
assert.match(r.stdout, /gap: No CI yet/, 'the config gap note is shown')

r = run({ protection: { Pulse: good }, runs: { Pulse: ['lint'] } }, 'audit', 'Pulse')
assert.equal(r.status, 1)
assert.match(r.stdout, /never reported: ci/, 'a required check the last PR never reported is caught')

r = run({ protection: { Pulse: loose }, runs: { Pulse: ['ci'] } }, 'apply', 'Pulse')
const [p] = puts()
assert.equal(p.ep, 'repos/zmcray/Pulse/branches/main/protection')
assert.deepEqual(p.body.required_status_checks, { strict: true, contexts: ['ci'] })
assert.equal(p.body.enforce_admins, true)
assert.equal(p.body.required_pull_request_reviews.required_approving_review_count, 0, 'apply requires a PR with no approvals')

r = run({ protection: {}, runs: {} }, 'apply', 'mcray-os-skills')
assert.equal(puts()[0].body.required_status_checks, null, 'a repo with no CI gets protection without required checks')

r = run({ protection: { Pulse: good }, runs: { Pulse: ['ci'] } }, 'apply', 'Pulse')
assert.equal(puts().length, 0, 'apply leaves a matching repo alone')

const noChecks = { required_status_checks: null, enforce_admins: { enabled: true }, required_pull_request_reviews: { required_approving_review_count: 0 } }
r = run({ protection: { 'mcray-os-skills': noChecks }, runs: {} }, 'audit', 'mcray-os-skills')
assert.match(r.stdout, /mcray-os-skills: ok/, 'strict is not drift when a repo has no required checks')
console.log('branch-protection: all checks passed')
NODE
