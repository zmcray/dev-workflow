#!/usr/bin/env bash
set -euo pipefail
export HOOK_SCRIPT="$(cd "$(dirname "$0")" && pwd)/stop-fast-check.sh"
node <<'NODE'
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const hook = process.env.HOOK_SCRIPT
assert.ok(fs.existsSync(hook), 'stop-fast-check.sh must exist before the hook contract can pass')
assert.ok(fs.statSync(hook).mode & 0o111, 'the hook must be executable')
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'stop-fast-check-'))
const repo = path.join(root, 'repo with spaces')
const bin = path.join(root, 'bin')
const log = path.join(root, 'calls.jsonl')
const childPid = path.join(root, 'descendant.pid')
const cwdLog = path.join(root, 'check-cwds.jsonl')
const budgetGroup = path.join(root, 'budget-group.pid')
fs.mkdirSync(repo)
fs.mkdirSync(bin)
const git = (...args) => {
  const result = spawnSync('git', args, { cwd: repo, encoding: 'utf8' })
  assert.equal(result.status, 0, result.stderr)
}
const calls = () => fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse) : []
const reset = () => fs.rmSync(log, { force: true })
const run = (mode = 'pass', active = false, payload = { cwd: repo }) => spawnSync(hook, [], {
  timeout: 100000, killSignal: 'SIGKILL',
  cwd: payload.cwd ? root : repo, input: JSON.stringify({ ...payload, stop_hook_active: active }), encoding: 'utf8',
  env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, CHECK_MODE: mode, CHECK_LOG: log, CHECK_CWD: cwdLog, CHILD_PID: childPid, BUDGET_GROUP: budgetGroup },
})
fs.writeFileSync(path.join(bin, 'pnpm'), `#!/usr/bin/env node
const fs = require('node:fs')
const { spawn } = require('node:child_process')
const args = process.argv.slice(2)
fs.appendFileSync(process.env.CHECK_LOG, JSON.stringify(args) + '\\n')
fs.appendFileSync(process.env.CHECK_CWD, JSON.stringify(process.cwd()) + '\\n')
const typecheck = args[0] === 'typecheck'
const mode = process.env.CHECK_MODE
if (mode === 'budget') {
  fs.writeFileSync(process.env.BUDGET_GROUP, String(process.pid))
  if (typecheck) setTimeout(() => process.exit(0), 45000)
  else {
    const child = spawn(process.execPath, ['-e', 'process.on("SIGTERM", () => {}); setInterval(() => {}, 1000)'], { stdio: 'ignore' })
    fs.writeFileSync(process.env.CHILD_PID, String(child.pid))
    setInterval(() => {}, 1000)
  }
} else if ((mode === 'type-fail' && typecheck) || (mode === 'related-fail' && !typecheck)) {
  console.log('failure from stdout')
  console.error('failure from stderr')
  process.exit(7)
} else if (mode === 'crash') process.kill(process.pid, 'SIGTERM')
`)
fs.chmodSync(path.join(bin, 'pnpm'), 0o755)
try {
  git('init', '-q', '-b', 'fixture')
  git('config', 'user.name', 'Hook fixture')
  git('config', 'user.email', 'hook@example.test')
  for (const name of ['ordinary.ts', 'deleted.ts', 'old name.ts', 'staged.ts']) fs.writeFileSync(path.join(repo, name), name)
  fs.writeFileSync(path.join(repo, '.gitignore'), '*.ignored\n')
  git('add', '.')
  git('commit', '-qm', 'fixture')
  fs.writeFileSync(path.join(repo, 'noise.ignored'), 'ignored')
  let result = run()
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual(calls(), [], 'clean and ignored-only trees never run checks')
  fs.writeFileSync(path.join(repo, 'ordinary.ts'), 'unstaged')
  fs.writeFileSync(path.join(repo, 'staged.ts'), 'staged')
  git('add', 'staged.ts')
  fs.unlinkSync(path.join(repo, 'deleted.ts'))
  git('mv', 'old name.ts', 'renamed name.ts')
  for (const name of ['new space.ts', '--option.ts', 'line\nbreak.ts']) fs.writeFileSync(path.join(repo, name), 'new')
  result = run()
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual(calls()[0], ['typecheck'])
  const related = calls()[1]
  assert.deepEqual(related.slice(0, 6), ['exec', 'vitest', 'related', '--run', '--passWithNoTests', '--'])
  assert.deepEqual(related.slice(6).sort(), ['ordinary.ts', 'staged.ts', 'deleted.ts', 'renamed name.ts', 'new space.ts', '--option.ts', 'line\nbreak.ts'].sort())
  assert.equal(calls().length, 2)
  reset()
  fs.rmSync(cwdLog, { force: true })
  const nested = path.join(repo, 'src', 'nested')
  fs.mkdirSync(nested, { recursive: true })
  result = run('pass', false, { cwd: nested })
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual(calls()[1].slice(6).sort(), related.slice(6).sort(), 'nested sessions retain tracked and untracked root paths')
  assert.deepEqual(fs.readFileSync(cwdLog, 'utf8').trim().split('\n').map(JSON.parse), [fs.realpathSync(repo), fs.realpathSync(repo)], 'both checks execute at the repository root')
  for (const mode of ['type-fail', 'related-fail', 'crash']) {
    reset()
    result = run(mode)
    assert.equal(result.status, 2, `${mode}: ${result.stderr}`)
    assert.match(result.stderr, /failed|signal/i)
    assert.equal(result.stdout, '')
    if (mode !== 'crash') {
      assert.match(result.stderr, /failure from stdout/)
      assert.match(result.stderr, /failure from stderr/)
    }
  }
  reset()
  result = run('type-fail', true)
  assert.equal(result.status, 0, result.stderr)
  assert.match(result.stderr, /failure from stderr/)
  assert.deepEqual(calls(), [['typecheck']], 'active hooks still run and report checks')
  reset()
  result = run('pass', false, {})
  assert.equal(result.status, 0, result.stderr)
  assert.equal(calls().length, 2, 'missing payload cwd uses the current directory')
  reset()
  const started = performance.now()
  result = run('budget')
  const elapsed = performance.now() - started
  assert.equal(result.status, 2, result.stderr)
  assert.match(result.stderr, /90.*second|deadline|timed out/i)
  assert.ok(elapsed >= 89000 && elapsed < 97000, `one shared budget took ${elapsed}ms`)
  assert.equal(calls().length, 2, 'typecheck and related tests share one deadline')
  const pid = Number(fs.readFileSync(childPid, 'utf8'))
  assert.throws(() => process.kill(pid, 0), { code: 'ESRCH' }, 'timeout must kill descendants, including SIGTERM-resistant children')
  console.log('stop-fast-check: all contract checks passed, including the real shared 90-second deadline')
} finally {
  try {
    // Only the current budget fixture's group is recorded; it owns the resistant child too.
    if (fs.existsSync(budgetGroup)) {
      const group = Number(fs.readFileSync(budgetGroup, 'utf8'))
      assert.ok(Number.isInteger(group) && group > 0)
      try { process.kill(-group, 'SIGKILL') }
      catch (error) { if (error.code !== 'ESRCH') throw error }
    }
  } finally {
    fs.rmSync(root, { recursive: true, force: true })
  }
}
NODE
