#!/usr/bin/env bash
# Proves the Stop hook blocks a red turn and lets a green one end, per repo in config/fast-checks.json.
# For each repo (or the ones named), using the checkout at ~/Developer/<name>:
#   - adds a temp worktree at origin's default branch (no fetch, no network install; the checkout's
#     node_modules, or a worktree's, is symlinked in; a Swift package is built once to warm it)
#   - green: an innocuous new file, the hook must exit 0
#   - red: one deliberate break the repo's check covers, the hook must exit 2 for that break
#   - removes the worktree and temp files, even on failure
# pnpm's pre-run dependency check is turned off for the audit (it would try to install over the symlink).
# Prints one line per repo: "blocks red, passes green", "FAILED: <what>" or "SKIPPED: <why>". Exits 1 on any FAILED.
#
#   bash scripts/hooks-audit.sh [--dev <dir>] [repo...]
exec node - "$(cd "$(dirname "$0")/.." && pwd)" "$@" <<'NODE'
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const [DW, ...argv] = process.argv.slice(2)
const HOOK = path.join(DW, 'hooks', 'stop-fast-check.sh')
const table = JSON.parse(fs.readFileSync(path.join(DW, 'config', 'fast-checks.json'), 'utf8'))
let dev = path.join(os.homedir(), 'Developer')
const at = argv.indexOf('--dev')
if (at >= 0) { dev = path.resolve(argv[at + 1]); argv.splice(at, 2) }
const names = argv.length ? argv : Object.keys(table.repos)

// The worktree borrows node_modules by symlink, which pnpm reads as stale and answers with an install
// (and with CI set, a purge of the borrowed folder). The audit never installs: skip that check, unset CI.
const ENV = { ...process.env, pnpm_config_verify_deps_before_run: 'false' }
delete ENV.CI
const sh = (cmd, args, cwd, timeout = 120000) => spawnSync(cmd, args, { cwd, env: ENV, encoding: 'utf8', timeout, killSignal: 'SIGKILL', maxBuffer: 64 * 1024 * 1024 })
const git = (cwd, ...args) => sh('git', args, cwd)
const firstLine = text => (text || '').split('\n').map(l => l.trim()).find(Boolean) ?? ''
class Skip extends Error {}
class Fail extends Error {}

// Every node_modules folder in a checkout, outside other node_modules, a few levels deep.
function nodeModules(dir, rel = '', depth = 0, out = []) {
  if (depth > 3) return out
  for (const entry of fs.readdirSync(path.join(dir, rel), { withFileTypes: true })) {
    if (!entry.isDirectory() || ['.git', '.claude', '.build', 'dist'].includes(entry.name)) continue
    const child = path.join(rel, entry.name)
    if (entry.name === 'node_modules') out.push(child)
    else nodeModules(dir, child, depth + 1, out)
  }
  return out
}

function depsSource(dir) {
  const ok = d => fs.existsSync(path.join(d, 'node_modules', '.bin', 'vitest'))
  if (ok(dir)) return dir
  const trees = path.join(dir, '.claude', 'worktrees')
  if (fs.existsSync(trees)) for (const t of fs.readdirSync(trees).sort()) if (ok(path.join(trees, t))) return path.join(trees, t)
  return null
}

function audit(name) {
  const checks = table.repos[Object.keys(table.repos).find(k => k.toLowerCase() === name.toLowerCase())]
  if (!checks) throw new Skip('not in config/fast-checks.json')
  const dir = path.join(dev, name)
  if (!fs.existsSync(path.join(dir, '.git'))) throw new Skip(`no checkout at ${dir}`)
  const head = git(dir, 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD')
  const ref = head.status === 0 ? head.stdout.trim() : ['origin/main', 'origin/master'].find(r => git(dir, 'rev-parse', '--verify', '-q', r).status === 0)
  if (!ref) throw new Skip('no origin default branch in the local clone')
  const programs = new Set(checks.map(c => c.run[0]))
  const vitest = checks.find(c => c.run.includes('vitest'))
  const swiftTest = checks.find(c => c.run[0] === 'swift' && c.run[1] === 'test')
  const swiftGuard = checks.find(c => c.run.some(a => a.endsWith('swift-swallowed-errors.mjs')))
  for (const p of programs) if (p !== 'node' && sh('sh', ['-c', `command -v ${p}`]).status !== 0) throw new Skip(`${p} is not on PATH`)
  const source = vitest ? depsSource(dir) : null
  if (vitest && !source) throw new Skip(`dependencies not installed (no node_modules with vitest in ${dir} or its .claude/worktrees)`)

  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `hooks-audit-${name}-`))
  const wt = path.join(tmp, name)
  try {
    const add = git(dir, 'worktree', 'add', '-q', '--detach', wt, ref)
    if (add.status !== 0) throw new Fail(`worktree add: ${firstLine(add.stderr)}`)
    if (source) for (const rel of nodeModules(source)) {
      if (fs.existsSync(path.dirname(path.join(wt, rel))) && !fs.existsSync(path.join(wt, rel))) fs.symlinkSync(path.join(source, rel), path.join(wt, rel))
    }
    if (swiftTest) {
      // A fresh worktree's first Swift build is cold; the hook's budget is for warm, incremental runs.
      const warm = sh('swift', ['build', '--build-tests'], path.join(wt, swiftTest.cwd ?? '.'), 15 * 60000)
      if (warm.status !== 0) throw new Fail(`warm-up build in ${swiftTest.cwd} failed: ${firstLine(warm.stderr || warm.stdout)}`)
    }
    const hook = () => spawnSync(HOOK, [], { cwd: tmp, env: ENV, encoding: 'utf8', timeout: 150000, killSignal: 'SIGKILL', input: JSON.stringify({ cwd: wt, stop_hook_active: false }) })

    const green = path.join(wt, 'hooks-audit-green-note.md')
    fs.writeFileSync(green, 'An innocuous new file.\n')
    let r = hook()
    if (r.status !== 0) throw new Fail(`green turn was blocked (exit ${r.status}): ${firstLine(r.stderr)}`)
    fs.rmSync(green)

    let expect
    if (vitest) {
      const runner = vitest.run.slice(0, vitest.run.indexOf('vitest') + 1)
      const dirAt = vitest.run.indexOf('--dir')
      const extra = dirAt >= 0 ? ['--dir', vitest.run[dirAt + 1]] : []
      const listed = sh(runner[0], [...runner.slice(1), 'list', '--filesOnly', ...extra], path.join(wt, vitest.cwd ?? '.'))
      const file = (listed.stdout || '').split('\n').map(l => l.trim()).find(l => /\.(test|spec)\.[cm]?[jt]sx?$/.test(l))
      if (!file) throw new Fail(`vitest list found no test file: ${firstLine(listed.stderr)}`)
      const target = path.resolve(path.join(wt, vitest.cwd ?? '.'), file)
      fs.appendFileSync(target, "\nthrow new Error('hooks-audit: deliberate red')\n")
      expect = /hooks-audit: deliberate red/
    } else if (swiftTest) {
      const sources = path.join(wt, swiftTest.cwd, 'Sources')
      const file = git(sources, 'ls-files', '--', '*.swift').stdout.split('\n').find(Boolean)
      if (!file) throw new Fail(`no Swift source under ${swiftTest.cwd}/Sources`)
      fs.appendFileSync(path.join(sources, file), '\nlet hooksAuditRed: Int = "red"\n')
      expect = /hooksAuditRed|cannot convert/
    } else if (swiftGuard) {
      fs.writeFileSync(path.join(wt, 'HooksAuditRed.swift'), 'func hooksAuditRed() {\n  try? save()\n}\n')
      expect = /swift-swallowed-errors: HooksAuditRed\.swift/
    } else {
      fs.writeFileSync(path.join(wt, '2026-01-01-hooks-audit.md'), 'x\n')
      expect = /date-last-names/
    }
    r = hook()
    if (r.status !== 2) throw new Fail(`red turn was not blocked (exit ${r.status})`)
    if (!expect.test(r.stderr)) throw new Fail(`red turn was blocked for another reason: ${firstLine(r.stderr.replace(/^Stop fast check[^:]*: /, ''))}`)
  } finally {
    git(dir, 'worktree', 'remove', '--force', wt)
    // SwiftPM leaves lock files named after the build path in the temp folder.
    const locks = fs.realpathSync(tmp).replaceAll('/', '_')
    for (const f of fs.readdirSync(os.tmpdir())) if (f.startsWith(locks)) fs.rmSync(path.join(os.tmpdir(), f), { force: true })
    fs.rmSync(tmp, { recursive: true, force: true })
    git(dir, 'worktree', 'prune')
  }
}

let failed = false
for (const name of names) {
  let line
  try { audit(name); line = 'blocks red, passes green' } catch (error) {
    if (error instanceof Skip) line = `SKIPPED: ${error.message}`
    else { failed = true; line = `FAILED: ${error.message}` }
  }
  console.log(`${name}: ${line}`)
}
process.exitCode = failed ? 1 : 0
NODE
