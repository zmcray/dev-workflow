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
  const setTable = (repos, budget = 90) => fs.writeFileSync(table, JSON.stringify({ owner: 'zmcray', budget_seconds: budget, repos }))
  // One fake for every program a check may name; each call logs its program, argv and cwd.
  const fakes = path.join(root, 'fakes')
  const fakeLog = path.join(root, 'fakes.jsonl')
  fs.mkdirSync(fakes)
  const fake = path.join(fakes, 'fake')
  fs.writeFileSync(fake, `#!/usr/bin/env node
const fs = require('node:fs')
const path = require('node:path')
fs.appendFileSync(process.env.FAKE_LOG, JSON.stringify({ bin: path.basename(process.argv[1]), args: process.argv.slice(2), cwd: process.cwd() }) + '\\n')
if (process.env.FAKE_SLEEP === path.basename(process.argv[1])) setInterval(() => {}, 1000)
else process.exit(process.env.FAKE_FAIL === path.basename(process.argv[1]) ? 3 : 0)
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
  const fire = (script, cwd, { active = false, fail = '', sleep = '', input, from = root } = {}) => {
    fs.rmSync(fakeLog, { force: true })
    return spawnSync(script, [], {
      cwd: from, encoding: 'utf8', timeout: 60000, killSignal: 'SIGKILL',
      input: input ?? JSON.stringify({ cwd, stop_hook_active: active }),
      env: { ...process.env, PATH: `${fakes}:${process.env.PATH}`, FAKE_LOG: fakeLog, FAKE_FAIL: fail, FAKE_SLEEP: sleep },
    })
  }
  const cmds = () => fakeCalls().map(c => [c.bin, ...c.args])

  // The real table: each repo's entry, as the machine-wide hook will run it.
  const parsed = JSON.parse(fs.readFileSync(realTable, 'utf8'))
  assert.equal(parsed.budget_seconds, 90)
  assert.equal(parsed.owner, 'zmcray', 'the table names the GitHub owner whose repos it checks')
  for (const [name, checks] of Object.entries(parsed.repos)) {
    assert.ok(Array.isArray(checks) && checks.length, `${name} has checks`)
    assert.match(checks[0].run.join(' '), /date-last-names\.mjs --paths$/, `${name} runs the date-last guard first`)
  }
  const sonar = repoAt('sonar', 'git@github.com:ZMcRay/sonar.git')
  fs.writeFileSync(path.join(sonar, 'base.ts'), 'changed')
  let r = fire(hook, sonar)
  assert.equal(r.status, 0, r.stderr)
  assert.deepEqual(cmds(), [['npm', 'run', 'typecheck'], ['npx', 'vitest', 'related', '--run', '--passWithNoTests', './base.ts']], 'the npm-based entry runs npm and npx, never pnpm; a git@ URL matches, owner case-insensitively')
  // Someone else's repo with the same name is not ours, in either URL form.
  for (const [dir, url] of [['sonar-other-ssh', 'git@github.com:someone/sonar.git'], ['sonar-other-https', 'https://github.com/someone/sonar.git']]) {
    const foreign = repoAt(dir, url)
    fs.writeFileSync(path.join(foreign, 'base.ts'), 'changed')
    r = fire(hook, foreign)
    assert.equal(r.status, 0, r.stderr)
    assert.equal(r.stderr, '', `${url}: another owner's clone is silent`)
    assert.deepEqual(cmds(), [], `${url}: another owner's clone runs no checks`)
  }
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

  // A malformed, empty or null payload exits 0 silently, inside a table repo or anywhere else.
  for (const input of ['', 'not json', 'null', '[]', '"text"']) {
    for (const from of [saidso, root]) {
      r = fire(hook, undefined, { input, from })
      assert.equal(r.status, 0, `payload ${JSON.stringify(input)} in ${from}: ${r.stderr}`)
      assert.equal(r.stderr, '', `payload ${JSON.stringify(input)} is silent`)
    }
  }

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
  // A broken table blocks only in dev-workflow itself, where it can be fixed; every other repo is left alone.
  const selfRepo = repoAt('dev-workflow-wt', 'git@github.com:zmcray/dev-workflow.git')
  fs.writeFileSync(path.join(selfRepo, 'base.ts'), 'changed')
  const broken = [
    ['unparsable', () => fs.writeFileSync(table, '{ "repos": { "app": [ { "run": ')],
    ['without repos', () => fs.writeFileSync(table, JSON.stringify({ owner: 'zmcray', budget_seconds: 90 }))],
    ['without owner', () => fs.writeFileSync(table, JSON.stringify({ budget_seconds: 90, repos: { app: [{ run: ['pnpm', 'x'] }] } }))],
    ['missing', () => fs.rmSync(table, { force: true })],
    ['unreadable', () => { fs.rmSync(table, { force: true }); fs.mkdirSync(table) }],
  ]
  for (const [kind, breakIt] of broken) {
    breakIt()
    for (const repo of [app, other, saidso]) {
      r = fire(copy, repo)
      assert.equal(r.status, 0, `${kind} table: ${repo} is left alone: ${r.stderr}`)
      assert.equal(r.stderr, '', `${kind} table: silent outside dev-workflow`)
      assert.deepEqual(cmds(), [])
    }
    r = fire(copy, selfRepo)
    assert.equal(r.status, 2, `${kind} table: dev-workflow itself blocks`)
    assert.match(r.stderr, /fast-checks\.json/, `${kind} table: the message names the table`)
    fs.rmSync(table, { recursive: true, force: true })
  }

  // The deadline holds even when a check leaves a detached process holding its output pipe.
  const sleepers = path.join(root, 'sleepers.pids')
  const holder = path.join(root, 'pipe-holder.js')
  fs.writeFileSync(holder, `const { spawn } = require('node:child_process')
const fs = require('node:fs')
// detached: true calls setsid, so the sleeper is outside the check's process group and survives its kill.
const child = spawn(process.execPath, ['-e', 'setInterval(() => {}, 1000)'], { detached: true, stdio: ['ignore', 'inherit', 'inherit'] })
fs.appendFileSync(${JSON.stringify(sleepers)}, child.pid + '\\n')
child.unref()
console.log('holder started')
if (process.argv[2] === 'hang') setInterval(() => {}, 1000)
`)
  try {
    setTable({ app: [{ run: ['node', holder, 'hang'] }] }, 3)
    fs.writeFileSync(path.join(app, 'base.ts'), 'changed again')
    let started = performance.now()
    r = fire(copy, app)
    let elapsed = performance.now() - started
    assert.equal(r.status, 2, r.stderr)
    assert.match(r.stderr, /3-second deadline/)
    assert.ok(elapsed < 5000, `a held pipe must not outlast the 3-second budget by more than 2 s: ${elapsed}ms`)
    setTable({ app: [{ run: ['node', holder, 'exit'] }, { run: ['pnpm', 'after'] }] }, 30)
    started = performance.now()
    r = fire(copy, app)
    elapsed = performance.now() - started
    assert.equal(r.status, 0, r.stderr)
    assert.deepEqual(cmds(), [['pnpm', 'after']], 'the next check still runs')
    assert.ok(elapsed < 5000, `a check that exits 0 does not wait for a held pipe: ${elapsed}ms`)
  } finally {
    if (fs.existsSync(sleepers)) for (const pid of fs.readFileSync(sleepers, 'utf8').split('\n').filter(Boolean)) {
      try { process.kill(Number(pid), 'SIGKILL') } catch (error) { if (error.code !== 'ESRCH') throw error }
    }
  }
  setTable({ app: [{ run: ['pnpm', 'x'] }] })
  spawnSync('git', ['stash', '-u', '-q'], { cwd: app })
  r = fire(copy, app)
  assert.equal(r.status, 0, 'a clean table repo exits 0')
  assert.deepEqual(cmds(), [])

  committedCases({ copy, setTable, fire, cmds, repoAt })
  timeoutCases({ copy, setTable, fire, cmds, repoAt })
}

const gitIn = (dir, ...args) => {
  const result = spawnSync('git', args, { cwd: dir, encoding: 'utf8' })
  assert.equal(result.status, 0, `git ${args.join(' ')}: ${result.stderr}`)
  return result.stdout.trim()
}
const commitAll = (dir, message) => { gitIn(dir, 'add', '-A'); gitIn(dir, 'commit', '-qm', message) }

// Committed work: the branch since its merge-base with origin's default branch counts as changed.
function committedCases({ copy, setTable, fire, cmds, repoAt }) {
  setTable({ work: [
    { run: ['pnpm', 'all'], files: true },
    { run: ['swift', 'test'], cwd: 'pkg', when: ['pkg/'] },
    { run: ['npm', 'fresh'], files: 'new' },
  ] })
  const work = repoAt('work', 'https://github.com/zmcray/work.git')
  fs.writeFileSync(path.join(work, 'gone.ts'), 'gone')
  commitAll(work, 'more base')
  gitIn(work, 'update-ref', 'refs/remotes/origin/main', 'HEAD')

  // On the default branch with nothing unpushed and a clean tree: nothing runs.
  let r = fire(copy, work)
  assert.equal(r.status, 0, r.stderr)
  assert.equal(r.stderr, '')
  assert.deepEqual(cmds(), [], 'default branch, nothing unpushed, clean tree: no checks')

  // A committed-only change on a branch runs the checks; a failing one blocks.
  gitIn(work, 'checkout', '-q', '-b', 'feature')
  fs.writeFileSync(path.join(work, 'base.ts'), 'committed change')
  fs.writeFileSync(path.join(work, 'added.ts'), 'added')
  fs.rmSync(path.join(work, 'gone.ts'))
  commitAll(work, 'feature work')
  assert.equal(gitIn(work, 'status', '--porcelain'), '', 'the tree is clean')
  r = fire(copy, work)
  assert.equal(r.status, 0, r.stderr)
  assert.deepEqual(cmds().map(c => [c[0], c[1], ...c.slice(2).sort()]), [
    ['pnpm', 'all', './added.ts', './base.ts', './gone.ts'],
    ['npm', 'fresh', './added.ts'],
  ], 'committed changes, deletions included, reach `files: true`; committed additions reach `files: "new"`')
  r = fire(copy, work, { fail: 'pnpm' })
  assert.equal(r.status, 2, 'a failing check on committed-only work blocks')
  assert.match(r.stderr, /pnpm all/)

  // Unpushed commits on the default branch count too.
  gitIn(work, 'checkout', '-q', 'main')
  fs.writeFileSync(path.join(work, 'unpushed.ts'), 'x')
  commitAll(work, 'unpushed')
  r = fire(copy, work)
  assert.equal(r.status, 0, r.stderr)
  assert.deepEqual(cmds()[0], ['pnpm', 'all', './unpushed.ts'])
  gitIn(work, 'reset', '-q', '--hard', 'origin/main')
  gitIn(work, 'checkout', '-q', 'feature')

  // Committed, uncommitted and untracked are deduplicated into one list.
  fs.writeFileSync(path.join(work, 'base.ts'), 'committed change, then edited')
  fs.writeFileSync(path.join(work, 'loose.ts'), 'untracked')
  r = fire(copy, work)
  assert.equal(r.status, 0, r.stderr)
  assert.deepEqual(cmds()[0].slice(2).sort(), ['./added.ts', './base.ts', './gone.ts', './loose.ts'])
  gitIn(work, 'checkout', '-q', '--', 'base.ts')
  fs.rmSync(path.join(work, 'loose.ts'))

  // `when` sees committed files.
  fs.mkdirSync(path.join(work, 'pkg'))
  fs.writeFileSync(path.join(work, 'pkg', 'a.swift'), 'swift')
  commitAll(work, 'pkg')
  r = fire(copy, work)
  assert.equal(r.status, 0, r.stderr)
  assert.ok(cmds().some(c => c[0] === 'swift'), 'a `when` prefix matches a committed file')

  // origin/HEAD wins over origin/main when it is set.
  gitIn(work, 'update-ref', 'refs/remotes/origin/trunk', 'feature')
  gitIn(work, 'symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/trunk')
  r = fire(copy, work)
  assert.equal(r.status, 0, r.stderr)
  assert.deepEqual(cmds(), [], 'the base is origin/HEAD (here at HEAD), so nothing is changed')
  gitIn(work, 'symbolic-ref', '--delete', 'refs/remotes/origin/HEAD')
  gitIn(work, 'update-ref', '-d', 'refs/remotes/origin/main')
  gitIn(work, 'update-ref', '-d', 'refs/remotes/origin/trunk')
  gitIn(work, 'update-ref', 'refs/remotes/origin/master', 'main')
  r = fire(copy, work)
  assert.equal(r.status, 0, r.stderr)
  assert.ok(cmds()[0].includes('./added.ts'), 'origin/master is the last fallback')

  // No origin ref at all: uncommitted and untracked only, silently.
  gitIn(work, 'update-ref', '-d', 'refs/remotes/origin/master')
  r = fire(copy, work)
  assert.equal(r.status, 0, r.stderr)
  assert.equal(r.stderr, '', 'no origin ref falls back silently')
  assert.deepEqual(cmds(), [], 'without a base, a clean tree runs nothing')
  fs.writeFileSync(path.join(work, 'loose.ts'), 'untracked')
  r = fire(copy, work)
  assert.equal(r.status, 0, r.stderr)
  assert.equal(r.stderr, '')
  assert.deepEqual(cmds()[0], ['pnpm', 'all', './loose.ts'], 'without a base, uncommitted and untracked still run')
  fs.rmSync(path.join(work, 'loose.ts'))

  // Over the cap: only the HEAD commit plus uncommitted and untracked, with one note that never blocks.
  const big = repoAt('big', 'https://github.com/zmcray/work.git')
  gitIn(big, 'update-ref', 'refs/remotes/origin/main', 'HEAD')
  gitIn(big, 'checkout', '-q', '-b', 'large')
  fs.mkdirSync(path.join(big, 'many'))
  for (let i = 0; i < 151; i++) fs.writeFileSync(path.join(big, 'many', `f${i}.ts`), String(i))
  commitAll(big, 'many files')
  fs.writeFileSync(path.join(big, 'last.ts'), 'last')
  commitAll(big, 'last commit')
  fs.writeFileSync(path.join(big, 'loose.ts'), 'untracked')
  r = fire(copy, big)
  assert.equal(r.status, 0, `the over-cap note alone never blocks: ${r.stderr}`)
  assert.deepEqual(cmds()[0].slice(2).sort(), ['./last.ts', './loose.ts'], 'over the cap: the HEAD commit plus uncommitted and untracked')
  assert.equal(r.stderr.trim().split('\n').length, 1, 'one note line')
  assert.match(r.stderr, /large.*only the latest commit/i)
  r = fire(copy, big, { fail: 'pnpm' })
  assert.equal(r.status, 2, 'a real failure still blocks on a large branch')
  // At exactly the cap, every branch file is passed.
  fs.rmSync(path.join(big, 'loose.ts'))
  gitIn(big, 'reset', '-q', '--hard', 'origin/main')
  for (let i = 0; i < 150; i++) fs.writeFileSync(path.join(big, `g${i}.ts`), String(i))
  commitAll(big, '150 files')
  r = fire(copy, big)
  assert.equal(r.status, 0, r.stderr)
  assert.equal(r.stderr, '', 'at the cap: no note')
  assert.equal(cmds()[0].length - 2, 150)
}

// A timeout earns one real retry; never more than two blocked stops in a row.
function timeoutCases({ copy, setTable, fire, cmds, repoAt }) {
  setTable({ slow: [{ run: ['pnpm', 'quick'] }, { run: ['swift', 'test'], cwd: 'pkg' }] }, 2)
  const slow = repoAt('slow', 'https://github.com/zmcray/slow.git')
  fs.mkdirSync(path.join(slow, 'pkg'))
  fs.writeFileSync(path.join(slow, 'pkg', 'a.swift'), 'a')
  const gitDir = dir => fs.realpathSync(path.resolve(dir, gitIn(dir, 'rev-parse', '--git-dir')))
  const marker = path.join(gitDir(slow), 'stop-fast-check.timeout')

  // Timeout → block with the cold-build message and a marker naming the check.
  let r = fire(copy, slow, { sleep: 'swift' })
  assert.equal(r.status, 2, r.stderr)
  assert.match(r.stderr, /timed out/i)
  assert.match(r.stderr, /cold build/i)
  assert.match(r.stderr, /cached/i)
  assert.match(r.stderr, /next stop/i)
  assert.ok(fs.existsSync(marker), 'a timeout leaves a marker in the git dir')
  assert.match(fs.readFileSync(marker, 'utf8'), /swift test/, 'the marker names the check')

  // The bound: timeout → (active, marker) real failure blocks → active again exits 0.
  r = fire(copy, slow, { active: true, fail: 'swift' })
  assert.equal(r.status, 2, `with a marker, a real failure blocks even under stop_hook_active: ${r.stderr}`)
  assert.deepEqual(cmds().map(c => c[0]), ['pnpm', 'swift'], 'the retry runs the checks for real')
  assert.doesNotMatch(r.stderr, /timed out/i)
  assert.ok(!fs.existsSync(marker), 'the marker is deleted first')
  r = fire(copy, slow, { active: true, fail: 'swift' })
  assert.equal(r.status, 0, 'a third stop in a row is never blocked')
  assert.match(r.stderr, /swift test/, 'it still reports')
  assert.ok(!fs.existsSync(marker))

  // Timeout → retry passes: exit 0.
  r = fire(copy, slow, { sleep: 'swift' })
  assert.equal(r.status, 2)
  assert.ok(fs.existsSync(marker))
  r = fire(copy, slow, { active: true })
  assert.equal(r.status, 0, r.stderr)
  assert.deepEqual(cmds().map(c => c[0]), ['pnpm', 'swift'])
  assert.ok(!fs.existsSync(marker))

  // Timeout → retry times out again: exit 0 with a note, no marker left behind.
  r = fire(copy, slow, { sleep: 'swift' })
  assert.equal(r.status, 2)
  r = fire(copy, slow, { active: true, sleep: 'swift' })
  assert.equal(r.status, 0, 'never block twice in a row on timeouts')
  assert.match(r.stderr, /could not finish in two tries/i)
  assert.ok(!fs.existsSync(marker), 'a second timeout leaves no marker')

  // No marker and stop_hook_active: a timeout exits 0 as today, and writes no marker.
  r = fire(copy, slow, { active: true, sleep: 'swift' })
  assert.equal(r.status, 0, r.stderr)
  assert.match(r.stderr, /deadline/)
  assert.ok(!fs.existsSync(marker), 'only a blocking timeout writes a marker')

  // A plain failure is not a timeout: no marker, today's message.
  r = fire(copy, slow, { fail: 'swift' })
  assert.equal(r.status, 2)
  assert.doesNotMatch(r.stderr, /timed out|cold build/i)
  assert.ok(!fs.existsSync(marker), 'a failed check writes no marker')

  // The marker is per worktree: one worktree's timeout does not give another a retry.
  const tree = path.join(root, 'slow-tree')
  gitIn(slow, 'worktree', 'add', '-q', '-b', 'other', tree)
  fs.mkdirSync(path.join(tree, 'pkg'))
  fs.writeFileSync(path.join(tree, 'pkg', 'b.swift'), 'b')
  const treeMarker = path.join(gitDir(tree), 'stop-fast-check.timeout')
  assert.notEqual(treeMarker, marker)
  r = fire(copy, slow, { sleep: 'swift' })
  assert.equal(r.status, 2)
  assert.ok(fs.existsSync(marker) && !fs.existsSync(treeMarker), 'the marker lands in the timed-out worktree only')
  r = fire(copy, tree, { active: true, fail: 'swift' })
  assert.equal(r.status, 0, 'another worktree under stop_hook_active is not retried')
  assert.ok(fs.existsSync(marker), 'and it leaves the first worktree marker alone')
  r = fire(copy, slow, { active: true })
  assert.equal(r.status, 0, r.stderr)
  assert.ok(!fs.existsSync(marker))

  // A git dir the hook cannot write: block as today, with no marker and no retry promise.
  const treeGit = gitDir(tree)
  fs.chmodSync(treeGit, 0o555)
  try {
    r = fire(copy, tree, { sleep: 'swift' })
    assert.equal(r.status, 2, r.stderr)
    assert.match(r.stderr, /deadline/)
    assert.doesNotMatch(r.stderr, /next stop/i, 'no retry is promised without a marker')
    assert.ok(!fs.existsSync(treeMarker))
    r = fire(copy, tree, { active: true, fail: 'swift' })
    assert.equal(r.status, 0, 'without a marker, stop_hook_active exits 0 as today')
  } finally { fs.chmodSync(treeGit, 0o755) }
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
