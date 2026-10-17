#!/usr/bin/env bash
set -euo pipefail
export GUARD="$(cd "$(dirname "$0")" && pwd)/swift-swallowed-errors.mjs"
node <<'NODE'
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const { GUARD } = process.env

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'swift-ratchet-'))
const git = (cwd, ...args) => {
  const result = spawnSync('git', args, { cwd, encoding: 'utf8' })
  assert.equal(result.status, 0, result.stderr)
  return result.stdout.trim()
}
const write = (rel, text) => { fs.mkdirSync(path.dirname(path.join(root, rel)), { recursive: true }); fs.writeFileSync(path.join(root, rel), text) }
const commit = msg => { git(root, 'add', '-A'); git(root, 'commit', '-qm', msg); return git(root, 'rev-parse', 'HEAD') }
const guard = (base, head = 'HEAD', cwd = root) => spawnSync(process.execPath, [GUARD, '--base', base, '--head', head, '--repo', cwd], { encoding: 'utf8' })

git(root, 'init', '-q', '-b', 'main')
git(root, 'config', 'user.email', 'test@example.com')
git(root, 'config', 'user.name', 'test')
write('App/Store.swift', 'func legacy() {\n  try? context.save()\n}\n')
const base = commit('legacy try? stays allowed')

const cases = [
  ['flags an added try?', 'func a() {\n  try? context.save()\n}\n', 1],
  ['flags a guard-let try?', 'func a() {\n  guard let p = try? repo.profile() else { return }\n}\n', 1],
  ['flags a log-only catch', 'func a() {\n  do { try save() } catch {\n    logger.error("x")\n  }\n}\n', 1],
  ['flags an empty catch', 'func a() {\n  do { try save() } catch { }\n}\n', 1],
  ['allows a catch that rethrows', 'func a() throws {\n  do { try save() } catch {\n    report(error)\n    throw error\n  }\n}\n', 0],
  ['allows the decode idiom', 'func a() {\n  let v = try? JSONDecoder().decode(T.self, from: d)\n}\n', 0],
  ['allows a value parse', 'func a() {\n  let u = try? URL(validating: s)\n}\n', 0],
  ['flags a parse that is then chained', 'func a() {\n  try? Store(db).save()\n}\n', 1],
  ['allows Task.sleep pacing', 'func a() async {\n  try? await Task.sleep(for: .seconds(1))\n}\n', 0],
  ['ignores try? in a comment or string', 'func a() {\n  // try? context.save()\n  let s = "try? x"\n}\n', 0],
  ['honours the allow comment', 'func a() {\n  try? cache.clear() // ratchet:allow R1 cache miss is fine\n}\n', 0],
]
for (const [name, text, expected] of cases) {
  write('App/Feature.swift', text)
  commit(name)
  const result = guard('HEAD~1')
  assert.equal(result.status, expected, `${name}: ${result.stderr}`)
  git(root, 'reset', '-q', '--hard', 'HEAD~1')
}

write('AppTests/StoreTests.swift', 'func t() {\n  try? context.save()\n}\n')
commit('tests may swallow')
assert.equal(guard(base).status, 0, 'test files are exempt')
write('App/Store.swift', 'func legacy() {\n  try? context.save()\n}\nfunc added() {}\n')
commit('touch a file with a legacy try?')
assert.equal(guard(base).status, 0, 'an unchanged legacy try? in an edited file passes')
write('App/Store.swift', 'func legacy() {\n  try? context.save()\n}\nfunc added() {\n  try? other.save()\n}\n')
commit('add a new try? next to the legacy one')
const r = guard(base)
assert.equal(r.status, 1, 'a new try? next to legacy code fails')
assert.match(r.stderr, /App\/Store\.swift:5/, 'the error names the file and line')
assert.match(r.stderr, /typed outcome/, 'the error names the fix')
assert.equal(spawnSync(process.execPath, [GUARD, '--base', 'no-such-ref', '--repo', root]).status, 70, 'a crash is not a violation')

// Real past bugs, checked when the app repos are on this machine.
const real = [
  ['motus', '98c0fe4', /try\? SessionManager\(\)\.log/],
  ['saidso', 'e5b1d07', /try\? await center\.add\(request\)/],
  ['saidso', '880a8ca', /catch/],
]
for (const [repo, sha, line] of real) {
  const dir = path.join(os.homedir(), 'Developer', repo)
  if (!fs.existsSync(dir) || spawnSync('git', ['cat-file', '-e', `${sha}^{commit}`], { cwd: dir }).status !== 0) { console.log(`skip: ${repo} ${sha} not on this machine`); continue }
  const result = guard(`${sha}~1`, sha, dir)
  assert.equal(result.status, 1, `${repo} ${sha} is flagged`)
  assert.match(result.stderr, line, `${repo} ${sha} flags the line the later fix changed`)
}
console.log('swift-swallowed-errors: all checks passed')
NODE
