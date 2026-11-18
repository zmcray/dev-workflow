#!/usr/bin/env node
// Merges the two machine-wide hooks into Claude Code's user settings, leaving everything else as it is:
//   Stop        → hooks/stop-fast-check.sh (each repo's fast check from config/fast-checks.json)
//   PreToolUse  → hooks/pretooluse-date-last.sh, matcher Write|Edit|MultiEdit
// The Stop entry carries an explicit timeout of the hook's budget + 30 s: Claude Code's default for a command
// hook is 600 s, and a hook it kills at its timeout renders no decision, so the stop goes through
// (https://code.claude.com/docs/en/hooks). An existing entry without it (or with a smaller one) gets it.
// Idempotent: a no-op when both are present. Writes a timestamped backup next to the file before any change.
// Aborts without writing when the file is not valid JSON or its hooks are not the expected shape.
//
//   node scripts/install-claude-hooks.mjs [--settings <path>] [--dry-run]
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const HOOKS = '$HOME/Developer/dev-workflow/hooks'
const TABLE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'config', 'fast-checks.json')
const budget = (() => {
  try { const b = JSON.parse(fs.readFileSync(TABLE, 'utf8')).budget_seconds; return Number.isFinite(b) && b > 0 ? b : 90 } catch { return 90 }
})()
export const STOP_TIMEOUT = budget + 30
export const WANTED = [
  { event: 'Stop', matcher: undefined, command: `"${HOOKS}/stop-fast-check.sh"`, timeout: STOP_TIMEOUT, label: 'Stop hook (stop-fast-check.sh)' },
  { event: 'PreToolUse', matcher: 'Write|Edit|MultiEdit', command: `"${HOOKS}/pretooluse-date-last.sh"`, label: 'PreToolUse hook (pretooluse-date-last.sh)' },
]

const fail = message => { const e = new Error(message); e.exit = 1; throw e }

export function merge(settings, file) {
  if (!settings || typeof settings !== 'object' || Array.isArray(settings)) fail(`${file}: the top level must be a JSON object`)
  if (settings.hooks !== undefined && (typeof settings.hooks !== 'object' || settings.hooks === null || Array.isArray(settings.hooks))) fail(`${file}: "hooks" must be an object`)
  const added = [], present = [], updated = []
  for (const want of WANTED) {
    const groups = settings.hooks?.[want.event]
    if (groups !== undefined && !Array.isArray(groups)) fail(`${file}: "hooks.${want.event}" must be a list`)
    const mine = (groups ?? []).filter(g => (g?.matcher || undefined) === want.matcher && Array.isArray(g?.hooks)).flatMap(g => g.hooks).filter(h => h?.command === want.command)
    if (mine.length) {
      // A larger timeout set by hand is kept.
      const short = want.timeout ? mine.filter(h => !(Number.isFinite(h.timeout) && h.timeout >= want.timeout)) : []
      for (const h of short) h.timeout = want.timeout
      ;(short.length ? updated : present).push(want.label)
      continue
    }
    settings.hooks ??= {}
    settings.hooks[want.event] ??= []
    settings.hooks[want.event].push({ ...(want.matcher ? { matcher: want.matcher } : {}), hooks: [{ type: 'command', command: want.command, ...(want.timeout ? { timeout: want.timeout } : {}) }] })
    added.push(want.label)
  }
  return { settings, added, present, updated }
}

const stamp = (d = new Date()) => {
  const p = n => String(n).padStart(2, '0')
  return `${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}-${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
}

function main(argv) {
  let file = path.join(os.homedir(), '.claude', 'settings.json')
  const i = argv.indexOf('--settings')
  if (i >= 0) {
    if (!argv[i + 1] || argv[i + 1].startsWith('--')) { process.stderr.write('usage: install-claude-hooks.mjs [--settings <path>] [--dry-run]\n'); return 64 }
    file = path.resolve(argv[i + 1])
  }
  const dry = argv.includes('--dry-run')
  const exists = fs.existsSync(file)
  const raw = exists ? fs.readFileSync(file, 'utf8') : ''
  let parsed
  try { parsed = raw.trim() ? JSON.parse(raw) : {} } catch (error) { fail(`${file} is not valid JSON (${error.message}); nothing was changed. Fix the file, then re-run.`) }
  const { settings, added, present, updated } = merge(parsed, file)
  for (const label of present) console.log(`  ok    ${label} already in ${file}`)
  if (!added.length && !updated.length) return 0
  for (const label of added) console.log(`  ${dry ? 'would' : 'doing'} add the ${label} to ${file}`)
  for (const label of updated) console.log(`  ${dry ? 'would' : 'doing'} set the timeout to ${STOP_TIMEOUT} s on the ${label} in ${file}`)
  if (dry) return 0
  // Write through a symlink to its target, so the link stays a link, and keep the file's mode (often 0600).
  const real = exists ? fs.realpathSync(file) : file
  const mode = exists ? fs.statSync(real).mode & 0o7777 : 0o600
  fs.mkdirSync(path.dirname(real), { recursive: true })
  if (exists) {
    // Date last in the name, per the naming rule.
    let backup = path.join(path.dirname(real), `settings.backup-${stamp()}.json`)
    for (let n = 2; fs.existsSync(backup); n++) backup = path.join(path.dirname(real), `settings.backup-${n}-${stamp()}.json`)
    fs.copyFileSync(real, backup, fs.constants.COPYFILE_EXCL)
    fs.chmodSync(backup, mode)
    console.log(`  backup ${backup}`)
  }
  const temp = `${real}.tmp-${process.pid}`
  fs.writeFileSync(temp, JSON.stringify(settings, null, 2) + '\n', { mode })
  fs.chmodSync(temp, mode)
  fs.renameSync(temp, real)
  return 0
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try { process.exitCode = main(process.argv.slice(2)) } catch (error) {
    process.stderr.write(`install-claude-hooks: ${error.message}\n`)
    process.exitCode = error.exit ?? 70
  }
}
