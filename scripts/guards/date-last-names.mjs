#!/usr/bin/env node
// Fails when a change adds or renames a file whose name starts with a date.
// Ratchet: files already on the base branch never fail, so history needs no mass rename.
import { execFileSync } from 'node:child_process'
import path from 'node:path'

const DATE_FIRST = /^(19|20)\d{2}-\d{2}-\d{2}/
// Migration tools sort by a leading timestamp, so their names are date-first by design.
const EXEMPT = [/(^|\/)migrations\//]

export function dateFirst(file) {
  if (EXEMPT.some(rx => rx.test(file))) return false
  return DATE_FIRST.test(path.basename(file))
}

export function suggestion(file) {
  const base = path.basename(file)
  const ext = path.extname(base)
  const stem = base.slice(0, base.length - ext.length)
  const date = stem.match(DATE_FIRST)[0]
  const rest = stem.slice(date.length).replace(/^[-_]+/, '')
  return path.join(path.dirname(file), `${rest || 'note'}-${date}${ext}`)
}

function changedFiles(base, head) {
  const out = execFileSync('git', ['diff', '--name-only', '--diff-filter=AR', '-z', `${base}...${head}`], { encoding: 'utf8' })
  return out.split('\0').filter(Boolean)
}

function main(argv) {
  let files
  const at = flag => argv[argv.indexOf(flag) + 1]
  if (argv.includes('--paths')) files = argv.slice(argv.indexOf('--paths') + 1)
  else if (argv.includes('--base')) files = changedFiles(at('--base'), argv.includes('--head') ? at('--head') : 'HEAD')
  else {
    process.stderr.write('usage: date-last-names.mjs --base <ref> [--head <ref>] | --paths <file>...\n')
    return 64
  }
  const bad = files.filter(dateFirst)
  for (const file of bad) {
    process.stderr.write(`date-last-names: ${file} puts the date first. Rename it to ${suggestion(file)} (rule: <short-description>-YYYY-MM-DD, AGENTS.workflow.md).\n`)
  }
  return bad.length ? 1 : 0
}

if (import.meta.url === `file://${process.argv[1]}`) {
  // A crash must not look like a violation (exit 1), or a broken guard would pass its own tests.
  try { process.exitCode = main(process.argv.slice(2)) } catch (error) {
    process.stderr.write(`date-last-names: ${error.message}\n`)
    process.exitCode = 70
  }
}
