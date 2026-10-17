#!/usr/bin/env node
// Fails when a change adds a `try?` or an empty / log-only `catch` to non-test Swift.
// Ratchet: only added lines count, so the existing ones never block a change.
// Rule R1n from the 2026-10-16 pitfall study: it flagged the exact buggy line in 7 of 9 real fixes.
import { execFileSync } from 'node:child_process'

const TEST_PATH = /(^|\/)[^/]*(Tests?|UITests|Fixtures?|Mocks?|Previews?)(\/|\.swift$)|(^|\/)(Tools|Scripts|ci_scripts|build|docs)\//
const TRY_Q = /\btry\?/
const BARE_CATCH = /\bcatch\s*\{/
const LOGGY = /^\s*(\}?\s*)?((self\.)?(logger|log|Logger|os_log|NSLog|print|debugPrint|assertionFailure|Self\.logger)\b.*|return( nil| false| \[\]| \.none| \{\s*\})?\s*;?|break|continue|_ = .*|\}?)\s*$/
// Idioms where `try?` is the intended shape: optional decode, pacing sleeps, file reads, value parses.
const IDIOM = /Task\.sleep|\.decode\(|JSONSerialization|Data\(contentsOf|\.encode\(/
const CTOR = /try\?\s*(await\s+)?\.?[A-Z]\w*(\.\w+)?\(/
const ALLOW = /\/\/\s*ratchet:allow\s+R1\s+\S/

const git = (cwd, ...args) => execFileSync('git', args, { cwd, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 })

// Drops comments and string contents so patterns inside them never match.
export function codeLines(text) {
  const state = { ml: false, bc: false }
  return text.split('\n').map(line => {
    let out = '', i = 0
    while (i < line.length) {
      if (state.bc) { const j = line.indexOf('*/', i); if (j < 0) return out; state.bc = false; i = j + 2; continue }
      if (state.ml) { const j = line.indexOf('"""', i); if (j < 0) return out; state.ml = false; out += '""'; i = j + 3; continue }
      if (line.startsWith('//', i)) break
      if (line.startsWith('/*', i)) { state.bc = true; i += 2; continue }
      if (line.startsWith('"""', i)) { state.ml = true; i += 3; continue }
      if (line[i] === '"') {
        let j = i + 1
        while (j < line.length && line[j] !== '"') j += line[j] === '\\' ? 2 : 1
        out += '""'; i = j + 1; continue
      }
      out += line[i]; i += 1
    }
    return out
  })
}

function ctorParse(t) {
  const m = CTOR.exec(t)
  if (!m) return false
  let i = m.index + m[0].length - 1, depth = 0
  for (; i < t.length; i++) {
    if (t[i] === '(') depth++
    else if (t[i] === ')' && --depth === 0) break
  }
  return !t.slice(i + 1).trimStart().startsWith('.')
}

function loggyCatch(code, n, start) {
  let depth = 0, started = false, j = n
  const body = []
  for (; j < code.length; j++) {
    const s = j === n ? code[j].slice(start) : code[j]
    for (const ch of s) {
      if (ch === '{') { depth++; started = true } else if (ch === '}') depth--
    }
    if (j !== n) body.push(code[j])
    if (started && depth <= 0) break
  }
  const seg = code[n].slice(start)
  const inner = body.slice(0, -1).filter(b => b.trim())
  const tail = seg.includes('{') ? seg.split('{').slice(1).join('{').replace(/[}\s]+$/, '') : ''
  if (tail.trim()) inner.push(tail)
  return inner.every(b => LOGGY.test(b))
}

export function flagsInFile(text, lines) {
  const raw = text.split('\n'), code = codeLines(text), flags = []
  for (const n of lines) {
    const c = code[n - 1]
    if (c === undefined || ALLOW.test(raw[n - 1])) continue
    if (TRY_Q.test(c) && !(IDIOM.test(c) || ctorParse(c))) flags.push({ line: n, text: raw[n - 1].trim(), kind: 'try?' })
    const m = BARE_CATCH.exec(c)
    if (m && loggyCatch(code, n - 1, m.index)) flags.push({ line: n, text: raw[n - 1].trim(), kind: 'catch' })
  }
  return flags
}

export function addedLines(cwd, base, head) {
  const diff = git(cwd, 'diff', '--no-color', '-U0', '-M', '--diff-filter=AMR', `${base}...${head}`, '--', '*.swift')
  const files = new Map()
  let file = null
  for (const l of diff.split('\n')) {
    if (l.startsWith('+++ ')) {
      const p = l.slice(4)
      file = p.startsWith('b/') && !TEST_PATH.test(p.slice(2)) ? p.slice(2) : null
      if (file) files.set(file, [])
    } else if (l.startsWith('@@') && file) {
      const m = /\+(\d+)(?:,(\d+))?/.exec(l)
      const s = Number(m[1]), count = Number(m[2] ?? 1)
      for (let k = 0; k < count; k++) files.get(file).push(s + k)
    }
  }
  return files
}

export function scan(cwd, base, head) {
  const out = []
  for (const [file, lines] of addedLines(cwd, base, head)) {
    if (!lines.length) continue
    for (const f of flagsInFile(git(cwd, 'show', `${head}:${file}`), lines)) out.push({ file, ...f })
  }
  return out
}

function main(argv) {
  const at = flag => argv[argv.indexOf(flag) + 1]
  if (!argv.includes('--base')) {
    process.stderr.write('usage: swift-swallowed-errors.mjs --base <ref> [--head <ref>] [--repo <dir>]\n')
    return 64
  }
  const flags = scan(argv.includes('--repo') ? at('--repo') : process.cwd(), at('--base'), argv.includes('--head') ? at('--head') : 'HEAD')
  for (const f of flags) {
    process.stderr.write(`swift-swallowed-errors: ${f.file}:${f.line} adds a ${f.kind === 'try?' ? '`try?`' : 'log-only `catch`'} that turns a failure into success: ${f.text}\n` +
      '  Return a typed outcome (Result or an enum) or catch the named error and surface it. If swallowing is intended, end the line with `// ratchet:allow R1 <why>`.\n')
  }
  return flags.length ? 1 : 0
}

if (import.meta.url === `file://${process.argv[1]}`) {
  // A crash must not look like a violation (exit 1), or a broken guard would pass its own tests.
  try { process.exitCode = main(process.argv.slice(2)) } catch (error) {
    process.stderr.write(`swift-swallowed-errors: ${error.message}\n`)
    process.exitCode = 70
  }
}
