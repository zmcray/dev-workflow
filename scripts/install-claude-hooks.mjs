#!/usr/bin/env node
// Merges the two machine-wide hooks into Claude Code's user settings, leaving everything else as it is:
//   Stop        → hooks/stop-fast-check.sh (each repo's fast check from config/fast-checks.json)
//   PreToolUse  → hooks/pretooluse-date-last.sh, matcher Write|Edit|MultiEdit
// Idempotent: a no-op when both are present. Writes a timestamped backup next to the file before any change.
// Aborts without writing when the file is not valid JSON or its hooks are not the expected shape.
//
//   node scripts/install-claude-hooks.mjs [--settings <path>] [--dry-run]
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const HOOKS = '$HOME/Developer/dev-workflow/hooks'
export const WANTED = [
  { event: 'Stop', matcher: undefined, command: `"${HOOKS}/stop-fast-check.sh"`, label: 'Stop hook (stop-fast-check.sh)' },
  { event: 'PreToolUse', matcher: 'Write|Edit|MultiEdit', command: `"${HOOKS}/pretooluse-date-last.sh"`, label: 'PreToolUse hook (pretooluse-date-last.sh)' },
]

const fail = message => { const e = new Error(message); e.exit = 1; throw e }

export function merge(settings, file) {
  if (!settings || typeof settings !== 'object' || Array.isArray(settings)) fail(`${file}: the top level must be a JSON object`)
  if (settings.hooks !== undefined && (typeof settings.hooks !== 'object' || settings.hooks === null || Array.isArray(settings.hooks))) fail(`${file}: "hooks" must be an object`)
  const added = [], present = []
  for (const want of WANTED) {
    const groups = settings.hooks?.[want.event]
    if (groups !== undefined && !Array.isArray(groups)) fail(`${file}: "hooks.${want.event}" must be a list`)
    const has = (groups ?? []).some(g => (g?.matcher || undefined) === want.matcher && Array.isArray(g?.hooks) && g.hooks.some(h => h?.command === want.command))
    if (has) { present.push(want.label); continue }
    settings.hooks ??= {}
    settings.hooks[want.event] ??= []
    settings.hooks[want.event].push({ ...(want.matcher ? { matcher: want.matcher } : {}), hooks: [{ type: 'command', command: want.command }] })
    added.push(want.label)
  }
  return { settings, added, present }
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
  const { settings, added, present } = merge(parsed, file)
  for (const label of present) console.log(`  ok    ${label} already in ${file}`)
  if (!added.length) return 0
  for (const label of added) console.log(`  ${dry ? 'would' : 'doing'} add the ${label} to ${file}`)
  if (dry) return 0
  fs.mkdirSync(path.dirname(file), { recursive: true })
  if (exists) {
    // Date last in the name, per the naming rule.
    let backup = path.join(path.dirname(file), `settings.backup-${stamp()}.json`)
    for (let n = 2; fs.existsSync(backup); n++) backup = path.join(path.dirname(file), `settings.backup-${n}-${stamp()}.json`)
    fs.copyFileSync(file, backup, fs.constants.COPYFILE_EXCL)
    console.log(`  backup ${backup}`)
  }
  const temp = `${file}.tmp-${process.pid}`
  fs.writeFileSync(temp, JSON.stringify(settings, null, 2) + '\n')
  fs.renameSync(temp, file)
  return 0
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try { process.exitCode = main(process.argv.slice(2)) } catch (error) {
    process.stderr.write(`install-claude-hooks: ${error.message}\n`)
    process.exitCode = error.exit ?? 70
  }
}
