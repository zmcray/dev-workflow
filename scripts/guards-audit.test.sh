#!/usr/bin/env bash
set -euo pipefail
export SCRIPT="$(cd "$(dirname "$0")" && pwd)/guards-audit.mjs"
node <<'NODE'
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'guards-audit-'))
const USES = 'zmcray/dev-workflow/.github/workflows/guards.yml@main'
const wf = (repo, body, name = 'ci.yml') => {
  const dir = path.join(root, repo, '.github', 'workflows')
  fs.mkdirSync(dir, { recursive: true })
  fs.writeFileSync(path.join(dir, name), body)
}
const gateJob = needs => `  ci:\n    runs-on: ubuntu-latest\n${needs}    steps:\n      - run: echo ok\n`
const call = (extra = '') => `  guards:\n    uses: ${USES}\n${extra}`
const head = 'name: ci\non: pull_request\njobs:\n'

wf('wired', head + call('    with:\n      swift: true\n') + gateJob('    needs: [build, guards]\n'))
wf('nocall', head + gateJob('    needs: [build]\n'))
wf('noneed', head + call() + gateJob('    needs: [build]\n'))
wf('noswift', head + call('    with:\n      runs_on: \'"x"\'\n') + gateJob('    needs: [guards]\n'))
wf('multiline', head + call() + gateJob('    needs:\n      - build   # first\n      - guards\n'))
wf('scalar', head + call() + gateJob('    needs: guards\n'))
wf('otherfile', 'name: other\non: push\njobs:\n  x:\n    runs-on: ubuntu-latest\n', 'other.yml')
wf('otherfile', head + call() + gateJob('    needs: [guards]\n'), 'pr.yaml')
wf('garbage', 'jobs:\n  ci\n    broken\n')
wf('nogate', head + call())

const table = {
  owner: 'zmcray',
  repos: {
    wired: { gate: 'ci', swift: true },
    nocall: { gate: 'ci' },
    noneed: { gate: 'ci' },
    noswift: { gate: 'ci', swift: true },
    multiline: { gate: 'ci' },
    scalar: { gate: 'ci' },
    otherfile: { gate: 'ci' },
    garbage: { gate: 'ci' },
    nogate: { gate: null },
    absent: { gate: null },
  },
}
const cfg = path.join(root, 'repos.json')
fs.writeFileSync(cfg, JSON.stringify(table))
const run = (config, ...args) => spawnSync(process.execPath, [process.env.SCRIPT, '--dir', root, '--config', config, ...args], { encoding: 'utf8' })

let r = run(cfg)
assert.equal(r.status, 1, 'any missing repo exits 1')
const line = repo => r.stdout.split('\n').find(l => l.startsWith(`${repo}:`))
assert.equal(line('wired'), 'wired: wired')
assert.match(line('nocall'), /MISSING: no job calls guards\.yml/)
assert.match(line('noneed'), /MISSING: gate "ci" does not need "guards"/)
assert.match(line('noswift'), /MISSING: call does not pass swift: true/)
assert.equal(line('multiline'), 'multiline: wired', 'multi-line needs list is read')
assert.equal(line('scalar'), 'scalar: wired', 'scalar needs is read')
assert.equal(line('otherfile'), 'otherfile: wired', 'a call in any workflow file counts')
assert.match(line('garbage'), /MISSING: .*cannot parse/, 'unparseable is missing')
assert.equal(line('nogate'), 'nogate: wired', 'no gate named means only the call is needed')
assert.match(line('absent'), /MISSING: could not read workflows/, 'a repo with no files is missing')

const good = path.join(root, 'good.json')
fs.writeFileSync(good, JSON.stringify({ owner: 'zmcray', repos: { wired: table.repos.wired, multiline: table.repos.multiline } }))
r = run(good)
assert.equal(r.status, 0, r.stdout + r.stderr)
assert.equal(r.stdout.trim().split('\n').length, 2, 'one line per repo')
console.log('guards-audit.test.sh ok')
NODE
