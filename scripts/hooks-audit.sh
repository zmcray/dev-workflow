#!/usr/bin/env bash
# Proves the Stop hook blocks a red turn and lets a green one end, per repo in config/fast-checks.json.
# For each repo (or the ones named), using the checkout at ~/Developer/<name>:
#   - adds a temp worktree at origin's default branch (no fetch, no network install; the checkout's
#     node_modules, or a worktree's, is symlinked in; a Swift package is built once to warm it)
#   - green: an innocuous new file, the hook must exit 0
#   - uncommitted red: one deliberate break the repo's check covers, the hook must exit 2 for that break
#   - committed red: the same break, committed, on a clean tree: the hook must exit 2 for it
#   - cold red (motus only): a second fresh worktree with no warm-up and a committed broken test:
#     the first run must exit 2 (timeout or failure); after a timeout, a run with stop_hook_active: true
#     must exit 2 on the real failure. Prints which path it took and how long each run took.
#   - removes the worktrees and temp files, even on failure
# pnpm's pre-run dependency check is turned off for the audit (it would try to install over the symlink).
# Prints one line per repo naming each case proven, e.g. "blocks uncommitted red, blocks committed red,
# passes green", or "FAILED: <what>" or "SKIPPED: <why>". Exits 1 on any FAILED.
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

// A temp worktree at ref, removed with its temp folder and SwiftPM's lock files whatever happens.
function withWorktree(dir, ref, name, fn) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `hooks-audit-${name}-`))
  const wt = path.join(tmp, name)
  try {
    const add = git(dir, 'worktree', 'add', '-q', '--detach', wt, ref)
    if (add.status !== 0) throw new Fail(`worktree add: ${firstLine(add.stderr)}`)
    return fn(wt, tmp)
  } finally {
    git(dir, 'worktree', 'remove', '--force', wt)
    // SwiftPM leaves lock files named after the build path in the temp folder.
    const locks = fs.realpathSync(tmp).replaceAll('/', '_')
    for (const f of fs.readdirSync(os.tmpdir())) if (f.startsWith(locks)) fs.rmSync(path.join(os.tmpdir(), f), { force: true })
    fs.rmSync(tmp, { recursive: true, force: true })
    git(dir, 'worktree', 'prune')
  }
}

// The worktree's changes, leaving out the node_modules symlinks the audit borrowed (scaffolding, never committed).
const changes = (wt, borrowed = []) => git(wt, 'status', '--porcelain', '-z').stdout.split('\0').filter(Boolean)
  .filter(line => !borrowed.includes(line.slice(3).replace(/\/$/, '')))

// Commit one file in the temp worktree (detached HEAD, discarded with it); never run the repo's git hooks.
function commitFile(wt, file, message, borrowed) {
  const add = git(wt, 'add', '--', file)
  const commit = git(wt, '-c', 'user.name=hooks-audit', '-c', 'user.email=hooks-audit@example.test', '-c', 'commit.gpgsign=false', 'commit', '-q', '--no-verify', '-m', message)
  if (add.status !== 0 || commit.status !== 0) throw new Fail(`commit in the temp worktree: ${firstLine(add.stderr || commit.stderr)}`)
  const left = changes(wt, borrowed)
  if (left.length) throw new Fail(`the tree is not clean after the commit: ${left[0]}`)
}

const runHook = (tmp, wt, active = false) => {
  const started = performance.now()
  const r = spawnSync(HOOK, [], { cwd: tmp, env: ENV, encoding: 'utf8', timeout: 150000, killSignal: 'SIGKILL', input: JSON.stringify({ cwd: wt, stop_hook_active: active }) })
  return { ...r, seconds: Math.round((performance.now() - started) / 1000) }
}
const why = r => firstLine((r.stderr || '').replace(/^Stop fast check[^:]*: /, ''))

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

  const proven = []
  const borrowed = []
  const linkDeps = wt => {
    if (source) for (const rel of nodeModules(source)) {
      if (fs.existsSync(path.dirname(path.join(wt, rel))) && !fs.existsSync(path.join(wt, rel))) {
        fs.symlinkSync(path.join(source, rel), path.join(wt, rel))
        borrowed.push(rel)
      }
    }
  }
  withWorktree(dir, ref, name, (wt, tmp) => {
    linkDeps(wt)
    if (swiftTest) {
      // A fresh worktree's first Swift build is cold; the warm cases measure warm, incremental runs.
      const warm = sh('swift', ['build', '--build-tests'], path.join(wt, swiftTest.cwd ?? '.'), 15 * 60000)
      if (warm.status !== 0) throw new Fail(`warm-up build in ${swiftTest.cwd} failed: ${firstLine(warm.stderr || warm.stdout)}`)
    }

    const green = path.join(wt, 'hooks-audit-green-note.md')
    fs.writeFileSync(green, 'An innocuous new file.\n')
    const r = runHook(tmp, wt)
    if (r.status !== 0) throw new Fail(`green turn was blocked (exit ${r.status}): ${why(r)}`)
    fs.rmSync(green)

    // One deliberate break the repo's check covers, written into the worktree.
    let breakIt, expect
    if (vitest) {
      const runner = vitest.run.slice(0, vitest.run.indexOf('vitest') + 1)
      const dirAt = vitest.run.indexOf('--dir')
      const extra = dirAt >= 0 ? ['--dir', vitest.run[dirAt + 1]] : []
      const listed = sh(runner[0], [...runner.slice(1), 'list', '--filesOnly', ...extra], path.join(wt, vitest.cwd ?? '.'))
      const file = (listed.stdout || '').split('\n').map(l => l.trim()).find(l => /\.(test|spec)\.[cm]?[jt]sx?$/.test(l))
      if (!file) throw new Fail(`vitest list found no test file: ${firstLine(listed.stderr)}`)
      const target = path.resolve(path.join(wt, vitest.cwd ?? '.'), file)
      breakIt = () => (fs.appendFileSync(target, "\nthrow new Error('hooks-audit: deliberate red')\n"), target)
      expect = /hooks-audit: deliberate red/
    } else if (swiftTest) {
      const sources = path.join(wt, swiftTest.cwd, 'Sources')
      const file = git(sources, 'ls-files', '--', '*.swift').stdout.split('\n').find(Boolean)
      if (!file) throw new Fail(`no Swift source under ${swiftTest.cwd}/Sources`)
      breakIt = () => (fs.appendFileSync(path.join(sources, file), '\nlet hooksAuditRed: Int = "red"\n'), path.join(sources, file))
      expect = /hooksAuditRed|cannot convert/
    } else if (swiftGuard) {
      breakIt = () => (fs.writeFileSync(path.join(wt, 'HooksAuditRed.swift'), 'func hooksAuditRed() {\n  try? save()\n}\n'), path.join(wt, 'HooksAuditRed.swift'))
      expect = /swift-swallowed-errors: HooksAuditRed\.swift/
    } else {
      breakIt = () => (fs.writeFileSync(path.join(wt, '2026-01-01-hooks-audit.md'), 'x\n'), path.join(wt, '2026-01-01-hooks-audit.md'))
      expect = /date-last-names/
    }
    const expectRed = (result, what) => {
      if (result.status !== 2) throw new Fail(`${what} was not blocked (exit ${result.status}): ${why(result)}`)
      if (!expect.test(result.stderr)) throw new Fail(`${what} was blocked for another reason: ${why(result)}`)
    }

    const broken = breakIt()
    expectRed(runHook(tmp, wt), 'uncommitted red turn')
    proven.push('blocks uncommitted red')

    // Undo the break (only that file: git clean would also take the borrowed node_modules symlinks),
    // then commit it: a clean tree whose only change is the committed break.
    if (git(wt, 'checkout', '-q', '--', broken).status !== 0) fs.rmSync(broken, { force: true })
    const left = changes(wt, borrowed)
    if (left.length) throw new Fail(`undoing the uncommitted break left changes: ${left[0]}`)
    commitFile(wt, path.relative(wt, breakIt()), 'hooks-audit: deliberate committed red', borrowed)
    expectRed(runHook(tmp, wt), 'committed red turn')
    proven.push('blocks committed red')
  })

  // Cold case for motus only: its first MotusKit build (~112 s) is longer than the hook's 90-second budget.
  if (swiftTest && name.toLowerCase() === 'motus') withWorktree(dir, ref, name, (wt, tmp) => {
    // Cold: a second fresh worktree, no warm-up, a committed broken test. The first stop may time out;
    // the one retry it earns must block on the real failure even under stop_hook_active.
    const tests = path.join(wt, swiftTest.cwd, 'Tests')
    const file = git(tests, 'ls-files', '--', '*.swift').stdout.split('\n').find(Boolean)
    if (!file) throw new Fail(`no Swift test under ${swiftTest.cwd}/Tests`)
    fs.appendFileSync(path.join(tests, file), '\nlet hooksAuditColdRed: Int = "red"\n')
    commitFile(wt, path.join(swiftTest.cwd, 'Tests', file), 'hooks-audit: deliberate cold red')
    const coldExpect = /hooksAuditColdRed/
    const first = runHook(tmp, wt)
    if (first.status !== 2) throw new Fail(`cold red turn was not blocked (exit ${first.status} after ${first.seconds}s): ${why(first)}`)
    if (/timed out/.test(first.stderr)) {
      const second = runHook(tmp, wt, true)
      console.log(`${name}: cold run 1 timed out after ${first.seconds}s; run 2 (stop_hook_active) exited ${second.status} after ${second.seconds}s`)
      if (second.status !== 2) throw new Fail(`cold retry under stop_hook_active was not blocked (exit ${second.status} after ${second.seconds}s): ${why(second)}`)
      if (!coldExpect.test(second.stderr)) throw new Fail(`cold retry was blocked for another reason: ${why(second)}`)
      proven.push('blocks cold red (timeout then failure)')
    } else {
      console.log(`${name}: cold run 1 blocked on the real failure after ${first.seconds}s`)
      if (!coldExpect.test(first.stderr)) throw new Fail(`cold red turn was blocked for another reason: ${why(first)}`)
      proven.push('blocks cold red (failure on the first run)')
    }
  })
  return [...proven, 'passes green'].join(', ')
}

let failed = false
for (const name of names) {
  let line
  try { line = audit(name) } catch (error) {
    if (error instanceof Skip) line = `SKIPPED: ${error.message}`
    else { failed = true; line = `FAILED: ${error.message}` }
  }
  console.log(`${name}: ${line}`)
}
process.exitCode = failed ? 1 : 0
NODE
