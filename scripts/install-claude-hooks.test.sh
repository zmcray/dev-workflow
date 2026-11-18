#!/usr/bin/env bash
set -euo pipefail
export SCRIPT="$(cd "$(dirname "$0")" && pwd)/install-claude-hooks.mjs"
node <<'NODE'
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'install-claude-hooks-'))
const STOP = '"$HOME/Developer/dev-workflow/hooks/stop-fast-check.sh"'
const PRE = '"$HOME/Developer/dev-workflow/hooks/pretooluse-date-last.sh"'
const run = (file, ...args) => spawnSync(process.execPath, [process.env.SCRIPT, '--settings', file, ...args], { encoding: 'utf8' })
const backups = dir => fs.readdirSync(dir).filter(f => f.startsWith('settings.backup-'))
const ours = settings => ({
  stop: settings.hooks.Stop.flatMap(g => g.hooks).filter(h => h.command === STOP),
  pre: settings.hooks.PreToolUse.filter(g => g.matcher === 'Write|Edit|MultiEdit').flatMap(g => g.hooks).filter(h => h.command === PRE),
})
try {
  // An empty file becomes a settings file with just the two hooks; nothing to back up but the empty file.
  const empty = path.join(root, 'empty', 'settings.json')
  fs.mkdirSync(path.dirname(empty))
  fs.writeFileSync(empty, '')
  let r = run(empty)
  assert.equal(r.status, 0, r.stderr)
  let s = JSON.parse(fs.readFileSync(empty, 'utf8'))
  assert.deepEqual(s, {
    hooks: {
      Stop: [{ hooks: [{ type: 'command', command: STOP }] }],
      PreToolUse: [{ matcher: 'Write|Edit|MultiEdit', hooks: [{ type: 'command', command: PRE }] }],
    },
  })
  assert.equal(backups(path.dirname(empty)).length, 1, 'a backup is written before any change')

  // A real-looking file: unrelated hooks, permissions and plugin settings survive unchanged in meaning.
  const full = path.join(root, 'full', 'settings.json')
  fs.mkdirSync(path.dirname(full))
  const before = {
    permissions: { allow: ['Bash(git status)'], deny: ['Read(.env)'] },
    enabledPlugins: { 'compound-engineering@compound-engineering-plugin': true },
    hooks: {
      Stop: [{ hooks: [{ type: 'command', command: 'say done', timeout: 5 }] }],
      PreToolUse: [
        { matcher: 'Bash', hooks: [{ type: 'command', command: 'guard-bash' }] },
        { matcher: 'Write|Edit|MultiEdit', hooks: [{ type: 'command', command: 'format-on-write' }] },
      ],
      SessionStart: [{ hooks: [{ type: 'command', command: 'echo hi' }] }],
    },
    model: 'default',
  }
  const original = JSON.stringify(before, null, 2) + '\n'
  fs.writeFileSync(full, original)
  r = run(full, '--dry-run')
  assert.equal(r.status, 0, r.stderr)
  assert.match(r.stdout, /would add the Stop hook/)
  assert.equal(fs.readFileSync(full, 'utf8'), original, '--dry-run changes nothing')
  assert.equal(backups(path.dirname(full)).length, 0, '--dry-run writes no backup')
  r = run(full)
  assert.equal(r.status, 0, r.stderr)
  s = JSON.parse(fs.readFileSync(full, 'utf8'))
  const strip = settings => {
    const copy = structuredClone(settings)
    copy.hooks.Stop = copy.hooks.Stop.filter(g => !g.hooks.some(h => h.command === STOP))
    copy.hooks.PreToolUse = copy.hooks.PreToolUse.map(g => ({ ...g, hooks: g.hooks.filter(h => h.command !== PRE) })).filter(g => g.hooks.length)
    return copy
  }
  assert.deepEqual(strip(s), before, 'everything that was there is still there, unchanged')
  assert.deepEqual(Object.keys(s), Object.keys(before), 'top-level key order is kept')
  assert.equal(ours(s).stop.length, 1)
  assert.equal(ours(s).pre.length, 1)
  const [backup] = backups(path.dirname(full))
  assert.match(backup, /^settings\.backup-.*\d{4}-\d{2}-\d{2}.*\.json$/, 'the backup name carries a timestamp')
  assert.doesNotMatch(backup, /^\d{4}-\d{2}-\d{2}/, 'the date is not first')
  assert.equal(fs.readFileSync(path.join(path.dirname(full), backup), 'utf8'), original, 'the backup is the file as it was')

  // Second run: both present, nothing written, no new backup.
  const after = fs.readFileSync(full, 'utf8')
  const mtime = fs.statSync(full).mtimeMs
  r = run(full)
  assert.equal(r.status, 0, r.stderr)
  assert.match(r.stdout, /already/)
  assert.equal(fs.readFileSync(full, 'utf8'), after, 'a second run is a no-op')
  assert.equal(fs.statSync(full).mtimeMs, mtime)
  assert.equal(backups(path.dirname(full)).length, 1, 'a no-op writes no backup')

  // Half installed: only the missing hook is added.
  const half = path.join(root, 'half', 'settings.json')
  fs.mkdirSync(path.dirname(half))
  fs.writeFileSync(half, JSON.stringify({ hooks: { Stop: [{ hooks: [{ type: 'command', command: STOP }] }] } }))
  r = run(half)
  assert.equal(r.status, 0, r.stderr)
  s = JSON.parse(fs.readFileSync(half, 'utf8'))
  assert.equal(ours(s).stop.length, 1, 'the Stop hook is not added twice')
  assert.equal(ours(s).pre.length, 1)

  // Missing file: created, with the folder.
  const missing = path.join(root, 'new', 'dir', 'settings.json')
  r = run(missing)
  assert.equal(r.status, 0, r.stderr)
  assert.equal(ours(JSON.parse(fs.readFileSync(missing, 'utf8'))).stop.length, 1)

  // A 0600 file stays 0600, and so does its backup.
  const priv = path.join(root, 'private', 'settings.json')
  fs.mkdirSync(path.dirname(priv))
  fs.writeFileSync(priv, '{"model":"default"}\n', { mode: 0o600 })
  fs.chmodSync(priv, 0o600)
  r = run(priv)
  assert.equal(r.status, 0, r.stderr)
  assert.equal(fs.statSync(priv).mode & 0o777, 0o600, 'the merged file keeps mode 0600')
  assert.equal(fs.statSync(path.join(path.dirname(priv), backups(path.dirname(priv))[0])).mode & 0o777, 0o600, 'the backup has the same mode')
  assert.equal(ours(JSON.parse(fs.readFileSync(priv, 'utf8'))).stop.length, 1)

  // A symlinked settings file stays a symlink; its target gets the change.
  const linkDir = path.join(root, 'linked')
  fs.mkdirSync(path.join(linkDir, 'dotfiles'), { recursive: true })
  const target = path.join(linkDir, 'dotfiles', 'claude-settings.json')
  fs.writeFileSync(target, '{"model":"default"}\n', { mode: 0o600 })
  fs.chmodSync(target, 0o600)
  const link = path.join(linkDir, 'settings.json')
  fs.symlinkSync(path.join('dotfiles', 'claude-settings.json'), link)
  r = run(link)
  assert.equal(r.status, 0, r.stderr)
  assert.ok(fs.lstatSync(link).isSymbolicLink(), 'the settings file is still a symlink')
  assert.equal(fs.readlinkSync(link), path.join('dotfiles', 'claude-settings.json'), 'the link still points at the same target')
  assert.equal(ours(JSON.parse(fs.readFileSync(target, 'utf8'))).stop.length, 1, 'the target got the change')
  assert.equal(fs.statSync(target).mode & 0o777, 0o600, 'the target keeps its mode')
  r = run(link)
  assert.match(r.stdout, /already/, 'a second run through the link is a no-op')

  // Malformed JSON, or hooks that are not an object: abort, write nothing.
  for (const [name, text] of [['malformed', '{ "hooks": { "Stop": [ }'], ['badhooks', '{ "hooks": [] }'], ['badevent', '{ "hooks": { "Stop": {} } }']]) {
    const bad = path.join(root, name, 'settings.json')
    fs.mkdirSync(path.dirname(bad))
    fs.writeFileSync(bad, text)
    r = run(bad)
    assert.equal(r.status, 1, `${name} aborts`)
    assert.match(r.stderr, /settings\.json/, `${name}: the error names the file`)
    assert.equal(fs.readFileSync(bad, 'utf8'), text, `${name}: the file is untouched`)
    assert.deepEqual(fs.readdirSync(path.dirname(bad)), ['settings.json'], `${name}: no backup or temp file is left`)
  }
  assert.equal(spawnSync(process.execPath, [process.env.SCRIPT, '--settings'], { encoding: 'utf8' }).status, 64, '--settings needs a path')
  console.log('install-claude-hooks: all checks passed')
} finally {
  fs.rmSync(root, { recursive: true, force: true })
}
NODE
