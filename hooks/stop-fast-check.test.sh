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

// The table: which repos get checked, how, and what happens when the table itself is broken.
function tableCases() {
  const realTable = path.join(path.dirname(hook), '..', 'config', 'fast-checks.json')
  const dw = path.join(root, 'dev-workflow')
  fs.mkdirSync(path.join(dw, 'hooks'), { recursive: true })
  fs.mkdirSync(path.join(dw, 'config'))
  fs.copyFileSync(hook, path.join(dw, 'hooks', 'stop-fast-check.sh'))
  fs.chmodSync(path.join(dw, 'hooks', 'stop-fast-check.sh'), 0o755)
  fs.cpSync(path.join(path.dirname(hook), '..', 'scripts', 'guards'), path.join(dw, 'scripts', 'guards'), { recursive: true })
  const copy = path.join(dw, 'hooks', 'stop-fast-check.sh')
  const table = path.join(dw, 'config', 'fast-checks.json')
  const setTable = repos => fs.writeFileSync(table, JSON.stringify({ budget_seconds: 90, repos }))
  // One fake for every program a check may name; each call logs its program, argv and cwd.
  const fakes = path.join(root, 'fakes')
  const fakeLog = path.join(root, 'fakes.jsonl')
  fs.mkdirSync(fakes)
  const fake = path.join(fakes, 'fake')
  fs.writeFileSync(fake, `#!/usr/bin/env node
const fs = require('node:fs')
const path = require('node:path')
fs.appendFileSync(process.env.FAKE_LOG, JSON.stringify({ bin: path.basename(process.argv[1]), args: process.argv.slice(2), cwd: process.cwd() }) + '\\n')
process.exit(process.env.FAKE_FAIL === path.basename(process.argv[1]) ? 3 : 0)
`)
  fs.chmodSync(fake, 0o755)
  for (const name of ['pnpm', 'npm', 'npx', 'swift']) fs.symlinkSync(fake, path.join(fakes, name))
  const fakeCalls = () => fs.existsSync(fakeLog) ? fs.readFileSync(fakeLog, 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse) : []
  const repoAt = (name, remote) => {
    const dir = path.join(root, name)
    fs.mkdirSync(dir, { recursive: true })
    const g = (...args) => assert.equal(spawnSync('git', args, { cwd: dir, encoding: 'utf8' }).status, 0)
    g('init', '-q', '-b', 'main')
    g('config', 'user.name', 'Hook fixture')
    g('config', 'user.email', 'hook@example.test')
    if (remote) g('remote', 'add', 'origin', remote)
    fs.writeFileSync(path.join(dir, 'base.ts'), 'base')
    g('add', '.')
    g('commit', '-qm', 'base')
    return dir
  }
  const fire = (script, cwd, { active = false, fail = '' } = {}) => {
    fs.rmSync(fakeLog, { force: true })
    return spawnSync(script, [], {
      cwd: root, encoding: 'utf8', timeout: 60000, killSignal: 'SIGKILL',
      input: JSON.stringify({ cwd, stop_hook_active: active }),
      env: { ...process.env, PATH: `${fakes}:${process.env.PATH}`, FAKE_LOG: fakeLog, FAKE_FAIL: fail },
    })
  }
  const cmds = () => fakeCalls().map(c => [c.bin, ...c.args])

  // The real table: each repo's entry, as the machine-wide hook will run it.
  const parsed = JSON.parse(fs.readFileSync(realTable, 'utf8'))
  assert.equal(parsed.budget_seconds, 90)
  for (const [name, checks] of Object.entries(parsed.repos)) {
    assert.ok(Array.isArray(checks) && checks.length, `${name} has checks`)
    assert.match(checks[0].run.join(' '), /date-last-names\.mjs --paths$/, `${name} runs the date-last guard first`)
  }
  const sonar = repoAt('sonar-fork', 'git@github.com:someone/sonar.git')
  fs.writeFileSync(path.join(sonar, 'base.ts'), 'changed')
  let r = fire(hook, sonar)
  assert.equal(r.status, 0, r.stderr)
  assert.deepEqual(cmds(), [['npm', 'run', 'typecheck'], ['npx', 'vitest', 'related', '--run', '--passWithNoTests', './base.ts']], 'the npm-based entry runs npm and npx, never pnpm; a fork matches by repo name')
  const argus = repoAt('argus', 'https://github.com/zmcray/argus')
  fs.writeFileSync(path.join(argus, 'base.ts'), 'changed')
  r = fire(hook, argus)
  assert.equal(r.status, 0, r.stderr)
  assert.deepEqual(cmds(), [['npx', 'vitest', 'related', '--run', '--passWithNoTests', '--dir', 'routines', './base.ts']])
  const pulse = repoAt('pulse-wt', 'https://github.com/zmcray/PULSE.git')
  fs.writeFileSync(path.join(pulse, 'base.ts'), 'changed')
  r = fire(hook, pulse)
  assert.equal(r.status, 0, r.stderr)
  assert.deepEqual(cmds()[0], ['npx', 'vitest', 'related', '--run', '--passWithNoTests', './base.ts'], 'the GitHub name matches case-insensitively')
  assert.ok(!cmds().some(c => c[0] === 'swift'), 'swift checks wait for a change under their folder')
  const saidso = repoAt('saidso', 'https://github.com/zmcray/saidso.git')
  fs.mkdirSync(path.join(saidso, 'App'))
  fs.writeFileSync(path.join(saidso, 'App', 'Store.swift'), 'func a() {\n  try? context.save()\n}\n')
  r = fire(hook, saidso)
  assert.equal(r.status, 2, 'saidso blocks a new swallowed error in an uncommitted file')
  assert.match(r.stderr, /swift-swallowed-errors.*App\/Store\.swift:2/)
  fs.rmSync(path.join(saidso, 'App'), { recursive: true })
  fs.writeFileSync(path.join(saidso, '2026-11-18-notes.md'), 'x')
  r = fire(hook, saidso)
  assert.equal(r.status, 2, 'the date-last guard blocks a new date-first file')
  assert.match(r.stderr, /notes-2026-11-18\.md/)

  // Not ours: a repo outside the table and a folder outside git never block and print nothing.
  const other = repoAt('other', 'https://github.com/someone/unrelated.git')
  fs.writeFileSync(path.join(other, 'base.ts'), 'changed')
  setTable({ telos: [{ run: ['pnpm', 'typecheck'] }] })
  r = fire(copy, other)
  assert.equal(r.status, 0, r.stderr)
  assert.equal(r.stderr, '', 'a repo outside the table is silent')
  assert.deepEqual(cmds(), [])
  const noRemote = repoAt('no-remote', null)
  fs.writeFileSync(path.join(noRemote, 'base.ts'), 'changed')
  r = fire(copy, noRemote)
  assert.equal(r.status, 0, r.stderr)
  assert.equal(r.stderr, '')
  const plain = path.join(root, 'plain folder')
  fs.mkdirSync(plain)
  fs.writeFileSync(path.join(plain, 'x.ts'), 'x')
  r = fire(copy, plain)
  assert.equal(r.status, 0, r.stderr)
  assert.equal(r.stderr, '', 'a folder outside git is silent')
  r = fire(copy, path.join(root, 'no such folder'))
  assert.equal(r.status, 0, r.stderr)

  // `when`, `cwd` and `files` relative to the check's folder.
  const app = repoAt('app', 'https://github.com/zmcray/app.git')
  fs.mkdirSync(path.join(app, 'pkg', 'src'), { recursive: true })
  setTable({ app: [
    { run: ['pnpm', 'root-check'] },
    { run: ['swift', 'test'], cwd: 'pkg', when: ['pkg/'], files: true },
    { run: ['npm', 'docs-only'], when: ['docs/', 'README'] },
  ] })
  fs.writeFileSync(path.join(app, 'base.ts'), 'changed')
  r = fire(copy, app)
  assert.equal(r.status, 0, r.stderr)
  assert.deepEqual(cmds(), [['pnpm', 'root-check']], 'checks whose `when` matches no changed file are skipped')
  fs.writeFileSync(path.join(app, 'pkg', 'src', 'a.swift'), 'new')
  fs.writeFileSync(path.join(app, 'README.md'), 'new')
  r = fire(copy, app)
  assert.equal(r.status, 0, r.stderr)
  assert.deepEqual(cmds(), [['pnpm', 'root-check'], ['swift', 'test', './src/a.swift'], ['npm', 'docs-only']], '`when` matches by path prefix; files are relative to the check cwd')
  assert.equal(fs.realpathSync(fakeCalls()[1].cwd), fs.realpathSync(path.join(app, 'pkg')), 'the check runs in its cwd')
  assert.equal(fs.realpathSync(fakeCalls()[0].cwd), fs.realpathSync(app))
  r = fire(copy, app, { fail: 'swift' })
  assert.equal(r.status, 2)
  assert.match(r.stderr, /swift test/, 'the failed check is named')
  assert.equal(cmds().length, 2, 'checks stop at the first failure')

  // Fail closed for a table repo.
  setTable({ app: [{ run: ['definitely-not-a-program-3307', '--flag'] }] })
  r = fire(copy, app)
  assert.equal(r.status, 2, 'a missing program blocks')
  assert.match(r.stderr, /definitely-not-a-program-3307/)
  assert.match(r.stderr, /not found/i)
  assert.match(r.stderr, /PATH/, 'the message names the fix')
  r = fire(copy, app, { active: true })
  assert.equal(r.status, 0, 'stop_hook_active: report, then let the turn end')
  assert.match(r.stderr, /definitely-not-a-program-3307/)
  setTable({ app: [{ run: ['pnpm', 'x'], cwd: 'gone/away' }] })
  r = fire(copy, app)
  assert.equal(r.status, 2, 'a missing cwd blocks')
  assert.match(r.stderr, /gone\/away/)
  setTable({ app: [{ run: [] }] })
  r = fire(copy, app)
  assert.equal(r.status, 2, 'a check without a program blocks')
  assert.match(r.stderr, /fast-checks\.json/)
  fs.writeFileSync(table, '{ "repos": { "app": [ { "run": ')
  r = fire(copy, app)
  assert.equal(r.status, 2, 'an unparsable table blocks a table repo')
  assert.match(r.stderr, /fast-checks\.json/)
  assert.deepEqual(cmds(), [])
  r = fire(copy, other)
  assert.equal(r.status, 0, 'an unparsable table still leaves repos it never names alone')
  fs.rmSync(table)
  r = fire(copy, app)
  assert.equal(r.status, 2, 'a missing table blocks: the checkout is broken')
  assert.match(r.stderr, /fast-checks\.json/)
  fs.mkdirSync(table)
  r = fire(copy, app)
  assert.equal(r.status, 2, 'an unreadable table blocks')
  assert.match(r.stderr, /fast-checks\.json/)
  fs.rmSync(table, { recursive: true })
  setTable({ app: [{ run: ['pnpm', 'x'] }] })
  spawnSync('git', ['stash', '-u', '-q'], { cwd: app })
  r = fire(copy, app)
  assert.equal(r.status, 0, 'a clean table repo exits 0')
  assert.deepEqual(cmds(), [])
}

try {
  git('init', '-q', '-b', 'fixture')
  git('config', 'user.name', 'Hook fixture')
  git('config', 'user.email', 'hook@example.test')
  // The machine-wide hook only runs checks for repos in config/fast-checks.json; this fixture is telos.
  git('remote', 'add', 'origin', 'https://github.com/zmcray/telos.git')
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
  assert.deepEqual(related.slice(0, 5), ['exec', 'vitest', 'related', '--run', '--passWithNoTests'])
  assert.deepEqual(related.slice(5).sort(), ['ordinary.ts', 'staged.ts', 'deleted.ts', 'renamed name.ts', 'new space.ts', '--option.ts', 'line\nbreak.ts'].map(file => `./${file}`).sort())
  assert.equal(calls().length, 2)
  reset()
  fs.rmSync(cwdLog, { force: true })
  const nested = path.join(repo, 'src', 'nested')
  fs.mkdirSync(nested, { recursive: true })
  result = run('pass', false, { cwd: nested })
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual(calls()[1].slice(5).sort(), related.slice(5).sort(), 'nested sessions retain tracked and untracked root paths')
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
  tableCases()
  console.log('stop-fast-check: all contract checks passed, including the real shared 90-second deadline and the table')
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
