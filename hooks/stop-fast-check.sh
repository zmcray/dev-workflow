#!/usr/bin/env bash
# Preserve the hook payload while Node reads its program from the heredoc.
exec node - 3<&0 <<'NODE'
const fs = require('node:fs')
const { spawn } = require('node:child_process')
const deadline = performance.now() + 90000
let active = false
const tail = text => text.slice(-1024 * 1024)
function run(command, args, cwd) {
  return new Promise((resolve, reject) => {
    const remaining = deadline - performance.now()
    if (remaining <= 0) return reject(new Error('Fast check exceeded its shared 90-second deadline.'))
    let child, timer, force, stdout = '', stderr = '', timedOut = false
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
    child.on('error', error => { stderr = tail(`${stderr}\n${error.message}`) })
    // The whole process group belongs to this check, including pnpm's children.
    child.on('exit', () => killGroup('SIGKILL'))
    timer = setTimeout(() => {
      timedOut = true
      killGroup('SIGTERM')
      force = setTimeout(() => killGroup('SIGKILL'), 250)
    }, Math.max(0, remaining - 250))
    child.on('close', (code, signal) => {
      clearTimeout(timer)
      clearTimeout(force)
      killGroup('SIGKILL')
      if (timedOut || code !== 0) {
        const reason = timedOut ? 'shared 90-second deadline exceeded' : `exit ${code}${signal ? `, signal ${signal}` : ''}`
        reject(new Error(`${command} ${args[0] ?? ''} failed (${reason}).\n${stdout}${stderr}`))
      } else resolve(stdout)
    })
  })
}
async function main() {
  const payload = JSON.parse(fs.readFileSync(3, 'utf8'))
  active = payload.stop_hook_active === true
  const sessionCwd = typeof payload.cwd === 'string' && payload.cwd ? payload.cwd : process.cwd()
  const cwd = (await run('git', ['rev-parse', '--show-toplevel'], sessionCwd)).replace(/\n$/, '')
  const tracked = await run('git', ['diff', '--name-only', '-z', 'HEAD', '--'], cwd)
  const untracked = await run('git', ['ls-files', '--others', '--exclude-standard', '-z'], cwd)
  const files = [...new Set((tracked + untracked).split('\0').filter(Boolean))]
  if (!files.length) return
  await run('pnpm', ['typecheck'], cwd)
  // Docs and other inputs without related tests are valid; actual test failures still fail.
  await run('pnpm', ['exec', 'vitest', 'related', '--run', '--passWithNoTests', ...files.map(file => `./${file}`)], cwd)
}
main().catch(error => {
  process.stderr.write(`Stop fast check: ${error.message}\n`)
  process.exitCode = active ? 0 : 2
})
NODE
