#!/usr/bin/env bash
# Stop hook, installed once per Mac. Runs the current repo's fast check from config/fast-checks.json.
# Exit 2 blocks the turn end and feeds stderr back to the agent. Repos outside the table (or owned by
# someone else), folders outside git, and an unreadable payload always exit 0. For a table repo every
# internal error blocks (fail closed). A broken table blocks only in dev-workflow itself.
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
const tail = text => text.slice(-1024 * 1024)
const show = argv => argv.map(a => /^[\w./@:=+-]+$/.test(a) ? a : JSON.stringify(a)).join(' ')

function run(command, args, cwd, name = `${command} ${args[0] ?? ''}`) {
  return new Promise((resolve, reject) => {
    const remaining = deadline - performance.now()
    if (remaining <= 0) return reject(new Error(`${name} did not start: the shared ${budget}-second deadline was used up.`))
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
          done(reject, new Error(`${name} failed (shared ${budget}-second deadline exceeded).\n${stdout}${stderr}`))
        }, 250).unref()
      }, 250)
    }, Math.max(0, remaining - 250))
    child.on('close', (closeCode, closeSignal) => {
      killGroup('SIGKILL')
      const code = exited ? exited.code : closeCode, signal = exited ? exited.signal : closeSignal
      if (timedOut || code !== 0) {
        const reason = timedOut ? `shared ${budget}-second deadline exceeded` : `exit ${code}${signal ? `, signal ${signal}` : ''}`
        done(reject, new Error(`${name} failed (${reason}).\n${stdout}${stderr}`))
      } else done(resolve, stdout)
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
  const tracked = await run('git', ['diff', '--name-only', '-z', 'HEAD', '--'], root)
  const untracked = await run('git', ['ls-files', '--others', '--exclude-standard', '-z'], root)
  const files = [...new Set((tracked + untracked).split('\0').filter(Boolean))]
  if (!files.length) return
  if (entry.broken) throw new Error(`${entry.broken}.\nFix: restore config/fast-checks.json in ${DEV_WORKFLOW} (git -C ${DEV_WORKFLOW} status; git -C ${DEV_WORKFLOW} pull).`)
  deadline = performance.now() + budget * 1000
  validate(entry.checks, entry.key)
  const added = (await run('git', ['diff', '--name-only', '--diff-filter=AR', '-z', 'HEAD', '--'], root)).split('\0').filter(Boolean)
  const fresh = [...new Set([...added, ...untracked.split('\0').filter(Boolean)])]
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
main().then(() => process.exit(0), error => {
  process.stderr.write(`${label}: ${error.message}\n`, () => process.exit(active ? 0 : 2))
})
NODE
