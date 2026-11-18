#!/usr/bin/env bash
# Stop hook, installed once per Mac. Runs the current repo's fast check from config/fast-checks.json.
# Exit 2 blocks the turn end and feeds stderr back to the agent. Repos outside the table (or owned by
# someone else), folders outside git, and an unreadable payload always exit 0. For a table repo every
# internal error blocks (fail closed). A broken table blocks only in dev-workflow itself.
# Changed files include the branch's commits since its merge-base with origin's default branch. A timed-out
# check earns one real retry on the next stop; never more than two blocked stops in a row (see hooks/README.md).
# Preserve the hook payload while Node reads its program from the heredoc.
exec node - "$(cd "$(dirname "$0")/.." && pwd)" 3<&0 <<'NODE'
const fs = require('node:fs')
const path = require('node:path')
const { spawn, spawnSync } = require('node:child_process')
const DEV_WORKFLOW = process.argv[2]
const TABLE = path.join(DEV_WORKFLOW, 'config', 'fast-checks.json')
let budget = 90
let deadline = performance.now() + budget * 1000
let active = false
let label = 'Stop fast check'
// A timed-out check leaves this marker in the worktree's own git dir; the next stop runs the checks once more.
let marker = null
let retry = false
// More branch files than this and only the HEAD commit is passed (vitest related on hundreds of files is slow).
const CAP = 150
const tail = text => text.slice(-1024 * 1024)
const show = argv => argv.map(a => /^[\w./@:=+-]+$/.test(a) ? a : JSON.stringify(a)).join(' ')
const list = out => out.split('\0').filter(Boolean)
const unique = (...lists) => [...new Set(lists.flat())]
// A timeout is not a failure: the check never got to say pass or fail.
const timeout = (message, name) => Object.assign(new Error(message), { timedOut: true, check: name })

function run(command, args, cwd, name = `${command} ${args[0] ?? ''}`) {
  return new Promise((resolve, reject) => {
    const remaining = deadline - performance.now()
    if (remaining <= 0) return reject(timeout(`${name} did not start: the shared ${budget}-second deadline was used up.`, name))
    let child, timer, force, stdout = '', stderr = '', timedOut = false, settled = false
    const done = (fn, value) => { if (!settled) { settled = true; clearTimeout(timer); clearTimeout(force); fn(value) } }
    const killGroup = signal => {
      if (!child?.pid) return
      try { process.kill(-child.pid, signal) } catch (error) {
        if (error.code !== 'ESRCH') stderr = tail(`${stderr}\nProcess cleanup failed: ${error.message}`)
      }
    }
    try {
      child = spawn(command, args, { cwd, detached: true, stdio: ['ignore', 'pipe', 'pipe'] })
    } catch (error) { reject(error); return }
    child.stdout.setEncoding('utf8')
    child.stderr.setEncoding('utf8')
    child.stdout.on('data', chunk => { stdout = command === 'git' ? stdout + chunk : tail(stdout + chunk) })
    child.stderr.on('data', chunk => { stderr = tail(stderr + chunk.toString()) })
    child.on('error', error => {
      if (error.code === 'ENOENT' && !child.pid) {
        done(reject, new Error(`${name} failed: program not found: ${command}.\nFix: install ${command}, or make it reachable on the PATH that Claude Code hooks run with (PATH=${process.env.PATH}).`))
      } else stderr = tail(`${stderr}\n${error.message}`)
    })
    // A process outside the group (a setsid daemon) can hold the pipes open; never wait on it.
    const release = () => { child.stdout.destroy(); child.stderr.destroy() }
    let exited = null
    // The whole process group belongs to this check, including pnpm's children.
    child.on('exit', (code, signal) => {
      killGroup('SIGKILL')
      exited = { code, signal }
      setTimeout(release, 250).unref()
    })
    timer = setTimeout(() => {
      timedOut = true
      killGroup('SIGTERM')
      force = setTimeout(() => {
        killGroup('SIGKILL')
        setTimeout(() => {
          release()
          done(reject, timeout(`${name} failed (shared ${budget}-second deadline exceeded).\n${stdout}${stderr}`, name))
        }, 250).unref()
      }, 250)
    }, Math.max(0, remaining - 250))
    child.on('close', (closeCode, closeSignal) => {
      killGroup('SIGKILL')
      const code = exited ? exited.code : closeCode, signal = exited ? exited.signal : closeSignal
      if (timedOut) done(reject, timeout(`${name} failed (shared ${budget}-second deadline exceeded).\n${stdout}${stderr}`, name))
      else if (code !== 0) done(reject, new Error(`${name} failed (exit ${code}${signal ? `, signal ${signal}` : ''}).\n${stdout}${stderr}`))
      else done(resolve, stdout)
    })
  })
}

// Only for questions whose failure means "not a repo we check": never blocks.
function probe(args, cwd) {
  try {
    const result = spawnSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })
    return result.status === 0 ? result.stdout.replace(/\n$/, '') : null
  } catch { return null }
}

// The merge-base with origin's default branch: origin/HEAD, else origin/main, else origin/master.
// None resolves (no fetch yet, no remote-tracking refs): null, and only uncommitted work is checked.
function branchBase(root) {
  for (const ref of ['refs/remotes/origin/HEAD', 'refs/remotes/origin/main', 'refs/remotes/origin/master']) {
    if (!probe(['rev-parse', '--verify', '-q', `${ref}^{commit}`], root)) continue
    const base = probe(['merge-base', 'HEAD', ref], root)
    return base ? { base, ref: ref.replace('refs/remotes/', '') } : null
  }
  return null
}

// Origin's last two path segments: owner and repo, for https, ssh:// and git@host:owner/repo forms.
// Worktrees of the same repo match; someone else's clone of a same-named repo does not.
function parseOrigin(url) {
  const parts = url.replace(/\/+$/, '').split(/[/:]/)
  return { name: (parts.pop() ?? '').replace(/\.git$/i, '').toLowerCase(), owner: (parts.pop() ?? '').toLowerCase() }
}

function loadTable({ name, owner }) {
  // A broken table cannot say which repos are ours. It blocks only in dev-workflow, where it gets fixed,
  // and never anywhere else on the machine.
  const broken = why => ({ member: name === 'dev-workflow', broken: why })
  let raw, table
  try { raw = fs.readFileSync(TABLE, 'utf8') } catch (error) { return broken(`cannot read ${TABLE} (${error.code ?? error.message})`) }
  try { table = JSON.parse(raw) } catch (error) { return broken(`cannot parse ${TABLE} (${error.message})`) }
  const repos = table?.repos && typeof table.repos === 'object' && !Array.isArray(table.repos) ? table.repos : null
  if (!repos) return broken(`${TABLE} has no "repos" object`)
  if (typeof table.owner !== 'string' || !table.owner) return broken(`${TABLE} has no "owner"`)
  if (owner !== table.owner.toLowerCase()) return { member: false }
  const key = Object.keys(repos).find(k => k.toLowerCase() === name)
  if (!key) return { member: false }
  if (Number.isFinite(table.budget_seconds) && table.budget_seconds > 0) budget = table.budget_seconds
  return { member: true, key, checks: repos[key] }
}

function validate(checks, key) {
  const bad = why => { throw new Error(`${TABLE}: repos.${key} ${why}.\nFix: correct the entry (see hooks/README.md for the shape).`) }
  if (!Array.isArray(checks)) bad('must be a list of checks')
  checks.forEach((c, i) => {
    if (!c || !Array.isArray(c.run) || !c.run.length || !c.run.every(a => typeof a === 'string' && a)) bad(`[${i}].run must be a non-empty list of strings`)
    if (c.cwd !== undefined && (typeof c.cwd !== 'string' || path.isAbsolute(c.cwd))) bad(`[${i}].cwd must be a relative folder`)
    if (c.when !== undefined && !(Array.isArray(c.when) && c.when.every(w => typeof w === 'string' && w))) bad(`[${i}].when must be a list of path prefixes`)
    if (![undefined, true, false, 'new'].includes(c.files)) bad(`[${i}].files must be true, false or "new"`)
  })
}

async function main() {
  let payload
  try { payload = JSON.parse(fs.readFileSync(3, 'utf8')) } catch { return 0 }
  // Not a hook payload: nothing to check, and nothing to say.
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) return 0
  active = payload.stop_hook_active === true
  const sessionCwd = typeof payload.cwd === 'string' && payload.cwd ? payload.cwd : process.cwd()
  if (!fs.existsSync(sessionCwd)) return
  const root = probe(['rev-parse', '--show-toplevel'], sessionCwd)
  if (!root) return
  const origin = probe(['remote', 'get-url', 'origin'], root)
  if (!origin) return
  const repo = parseOrigin(origin)
  const entry = loadTable(repo)
  if (!entry.member) return
  label = `Stop fast check (${entry.key ?? repo.name})`
  // A marker from a timed-out stop: delete it first, then run for real even under stop_hook_active.
  // If it cannot be deleted, no retry (a marker that never goes away would block forever).
  const gitDir = probe(['rev-parse', '--absolute-git-dir'], root)
  marker = gitDir ? path.join(gitDir, 'stop-fast-check.timeout') : null
  if (marker && fs.existsSync(marker)) {
    try { fs.rmSync(marker); retry = true; active = false } catch {}
  }
  const uncommitted = list(await run('git', ['diff', '--name-only', '-z', 'HEAD', '--'], root))
  const untracked = list(await run('git', ['ls-files', '--others', '--exclude-standard', '-z'], root))
  // Committed work on the branch: agents commit each chunk before they stop.
  let committed = [], committedNew = []
  const branch = branchBase(root)
  if (branch) {
    let from = branch.base
    committed = list(await run('git', ['diff', '--name-only', '-z', from, 'HEAD', '--'], root))
    if (committed.length > CAP) {
      const count = committed.length
      from = probe(['rev-parse', '--verify', '-q', 'HEAD^'], root) ?? probe(['hash-object', '-t', 'tree', '/dev/null'], root)
      committed = list(await run('git', ['diff', '--name-only', '-z', from, 'HEAD', '--'], root))
      process.stderr.write(`${label}: this branch is large (${count} files changed since ${branch.ref}, over ${CAP}); only the latest commit was checked, plus uncommitted and untracked files.\n`)
    }
    committedNew = list(await run('git', ['diff', '--name-only', '--diff-filter=AR', '-z', from, 'HEAD', '--'], root))
  }
  const files = unique(committed, uncommitted, untracked)
  if (!files.length) return
  if (entry.broken) throw new Error(`${entry.broken}.\nFix: restore config/fast-checks.json in ${DEV_WORKFLOW} (git -C ${DEV_WORKFLOW} status; git -C ${DEV_WORKFLOW} pull).`)
  deadline = performance.now() + budget * 1000
  validate(entry.checks, entry.key)
  const added = list(await run('git', ['diff', '--name-only', '--diff-filter=AR', '-z', 'HEAD', '--'], root))
  const fresh = unique(committedNew, added, untracked)
  const total = entry.checks.length
  for (const [i, check] of entry.checks.entries()) {
    if (check.when && !files.some(f => check.when.some(prefix => f.startsWith(prefix)))) continue
    const cwd = path.join(root, check.cwd ?? '.')
    const argv = check.run.map(a => a.replaceAll('{dev_workflow}', DEV_WORKFLOW))
    const name = `check ${i + 1}/${total} \`${show(argv)}\`${check.cwd ? ` in ${check.cwd}` : ''}`
    if (!fs.statSync(cwd, { throwIfNoEntry: false })?.isDirectory()) {
      throw new Error(`${name} needs the folder ${check.cwd}, which is missing in ${root}.\nFix: restore the folder, or correct repos.${entry.key}[${i}].cwd in ${TABLE}.`)
    }
    const prefix = check.cwd ? `${path.posix.normalize(check.cwd).replace(/\/$/, '')}/` : ''
    const pick = check.files === 'new' ? fresh : check.files ? files : []
    // Docs and other inputs without related tests are valid; actual test failures still fail.
    const extra = pick.filter(f => f.startsWith(prefix)).map(f => `./${f.slice(prefix.length)}`)
    const [program, ...args] = argv
    await run(program === 'node' ? process.execPath : program, [...args, ...extra], cwd, name)
  }
}
// Exit explicitly: a stray handle (a pipe a detached process still holds) must not keep Node alive.
// At most two blocked stops in a row: a timeout blocks and leaves a marker only when stop_hook_active is
// false; the retry it earns can block once more, and never leaves a marker.
main().then(() => process.exit(0), error => {
  let code = active ? 0 : 2
  let message = `${label}: ${error.message}\n`
  if (error.timedOut && retry) {
    code = 0
    message += `${label}: ${error.check} could not finish in two tries (it timed out again on the retry), so the turn may end. Run it yourself before trusting this turn.\n`
  } else if (error.timedOut && !active && marker) {
    try {
      fs.writeFileSync(marker, `${error.check}\n`)
      message = `${label}: ${error.check} timed out at the shared ${budget}-second deadline, likely a cold build. The work it did is cached; the next stop will run it again, once, and block only on a real failure.\n${message}`
    } catch {}
  }
  process.stderr.write(message, () => process.exit(code))
})
NODE
