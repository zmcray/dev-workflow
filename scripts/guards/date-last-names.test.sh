#!/usr/bin/env bash
set -euo pipefail
export GUARD="$(cd "$(dirname "$0")" && pwd)/date-last-names.mjs"
export HOOK="$(cd "$(dirname "$0")/../../hooks" && pwd)/pretooluse-date-last.sh"
export REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
node <<'NODE'
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const { GUARD, HOOK, REPO_ROOT } = process.env

const guard = (args, cwd) => spawnSync(process.execPath, [GUARD, ...args], { cwd, encoding: 'utf8' })
const paths = (...files) => guard(['--paths', ...files])

assert.equal(paths('docs/plans/2026-10-10-001-fix-thing.md').status, 1, 'a date-first plan fails')
assert.match(paths('docs/plans/2026-10-10-001-fix-thing.md').stderr, /docs\/plans\/001-fix-thing-2026-10-10\.md/, 'the error names the date-last rename')
assert.equal(paths('docs/factory/runs/2026-10-16.json').status, 1, 'a bare-date ledger fails')
assert.match(paths('docs/factory/runs/2026-10-16.json').stderr, /run|note-2026-10-16\.json/, 'a bare date still gets a suggested name')
assert.equal(paths('docs/plans/fix-thing-2026-10-10.md').status, 0, 'a date-last plan passes')
assert.equal(paths('supabase/migrations/20261016120000_add_table.sql').status, 0, 'migrations are exempt')
assert.equal(paths('db/migrations/2026-10-16-add-table.sql').status, 0, 'any migrations folder is exempt')
assert.equal(paths('src/2026-ready.js').status, 0, 'a year alone is not a date')

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'date-last-'))
const git = (...args) => {
  const result = spawnSync('git', args, { cwd: root, encoding: 'utf8' })
  assert.equal(result.status, 0, result.stderr)
  return result.stdout.trim()
}
git('init', '-q', '-b', 'main')
git('config', 'user.email', 'test@example.com')
git('config', 'user.name', 'test')
fs.mkdirSync(path.join(root, 'docs'))
fs.writeFileSync(path.join(root, 'docs', '2026-01-01-legacy.md'), 'old\n')
git('add', '.')
git('commit', '-qm', 'legacy')
const base = git('rev-parse', 'HEAD')
fs.appendFileSync(path.join(root, 'docs', '2026-01-01-legacy.md'), 'edited\n')
fs.writeFileSync(path.join(root, 'docs', 'new-note-2026-10-16.md'), 'ok\n')
git('add', '.')
git('commit', '-qm', 'edit legacy, add date-last')
assert.equal(guard(['--base', base], root).status, 0, 'editing a legacy date-first file passes the ratchet')
git('mv', 'docs/new-note-2026-10-16.md', 'docs/2026-10-16-renamed.md')
git('commit', '-qm', 'rename to date-first')
assert.equal(guard(['--base', base], root).status, 1, 'renaming into a date-first name fails')

const history = (sha) => spawnSync('git', ['cat-file', '-e', `${sha}^{commit}`], { cwd: REPO_ROOT }).status === 0
for (const sha of ['18e8ae9', '280a994']) {
  if (!history(sha)) { console.log(`skip: ${sha} not in this clone`); continue }
  assert.equal(guard(['--base', `${sha}~1`, '--head', sha], REPO_ROOT).status, 1, `the real violation ${sha} fails`)
}

const hook = (payload) => spawnSync(HOOK, [], { input: JSON.stringify({ cwd: root, ...payload }), encoding: 'utf8' })
assert.equal(hook({ tool_name: 'Write', tool_input: { file_path: 'docs/2026-10-17-new.md' } }).status, 2, 'the hook blocks a new date-first file')
assert.equal(hook({ tool_name: 'Write', tool_input: { file_path: 'docs/2026-01-01-legacy.md' } }).status, 0, 'the hook allows overwriting an existing file')
assert.equal(hook({ tool_name: 'Write', tool_input: { file_path: 'docs/new-2026-10-17.md' } }).status, 0, 'the hook allows a date-last file')
assert.equal(hook({ tool_name: 'Edit', tool_input: { file_path: 'docs/2026-10-17-new.md' } }).status, 0, 'the hook ignores other tools')
// XcodeGen repos: the .pbxproj is generated from project.yml, so hand edits are lost on the next generate.
const ios = fs.mkdtempSync(path.join(os.tmpdir(), 'xcodegen-'))
spawnSync('git', ['init', '-q'], { cwd: ios })
fs.mkdirSync(path.join(ios, 'App.xcodeproj'))
fs.writeFileSync(path.join(ios, 'App.xcodeproj', 'project.pbxproj'), '// generated\n')
const pbx = path.join(ios, 'App.xcodeproj', 'project.pbxproj')
for (const tool of ['Write', 'Edit', 'MultiEdit']) {
  assert.equal(hook({ cwd: ios, tool_name: tool, tool_input: { file_path: pbx } }).status, 0, `${tool}: no project.yml, hand edits are allowed`)
}
fs.writeFileSync(path.join(ios, 'project.yml'), 'name: App\n')
for (const tool of ['Write', 'Edit', 'MultiEdit']) {
  const r = hook({ cwd: ios, tool_name: tool, tool_input: { file_path: pbx } })
  assert.equal(r.status, 2, `${tool} to a generated .pbxproj is blocked`)
  assert.match(r.stderr, /project\.yml/, 'the message names project.yml')
  assert.match(r.stderr, /xcodegen/i, 'the message says to regenerate')
}
assert.equal(hook({ cwd: root, tool_name: 'Edit', tool_input: { file_path: pbx } }).status, 2, 'the repo is found from the file, not the session folder')
assert.equal(hook({ cwd: ios, tool_name: 'Edit', tool_input: { file_path: 'App.xcodeproj/project.pbxproj' } }).status, 2, 'a relative path resolves against the session folder')
assert.equal(hook({ cwd: ios, tool_name: 'Edit', tool_input: { file_path: path.join(ios, 'project.yml') } }).status, 0, 'editing project.yml is the fix, so it passes')
assert.equal(hook({ cwd: ios, tool_name: 'Read', tool_input: { file_path: pbx } }).status, 0, 'reading is fine')
assert.equal(hook({ cwd: ios, tool_name: 'Write', tool_input: { file_path: path.join(ios, '2026-11-18-plan.md') } }).status, 2, 'the date-first rule still holds in the same repo')
fs.rmSync(ios, { recursive: true, force: true })
console.log('date-last-names: all checks passed')
NODE
