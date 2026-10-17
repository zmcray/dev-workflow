#!/usr/bin/env node
// Branch protection as data. `audit` reads every repo and reports drift from
// config/branch-protection.json; `apply` makes GitHub match it (Zack approves first: it changes settings).
//
// usage: branch-protection.mjs audit [repo...]
//        branch-protection.mjs apply [repo...]
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'

const OWNER = 'zmcray'
const CONFIG = path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'config', 'branch-protection.json')

function gh(args, input) {
  try {
    return execFileSync('gh', args, { encoding: 'utf8', input, stdio: ['pipe', 'pipe', 'pipe'] })
  } catch (error) {
    if (/Branch not protected|404/.test(String(error.stderr))) return null
    throw new Error(`gh ${args.join(' ')} failed: ${error.stderr || error.message}`)
  }
}
const json = (args, input) => { const out = gh(args, input); return out === null ? null : JSON.parse(out) }

export function desired(config, repo) {
  const want = { ...config.defaults, ...config.repos[repo] }
  return { strict: want.strict, enforce_admins: want.enforce_admins, require_pull_request: want.require_pull_request, required: [...want.required].sort() }
}

export function actual(protection) {
  if (!protection) return null
  return {
    strict: protection.required_status_checks?.strict ?? false,
    enforce_admins: protection.enforce_admins?.enabled ?? false,
    require_pull_request: protection.required_pull_request_reviews != null,
    required: [...(protection.required_status_checks?.contexts ?? [])].sort(),
  }
}

export function drift(want, have) {
  if (!have) return ['branch is not protected']
  const out = []
  for (const key of ['strict', 'enforce_admins', 'require_pull_request']) {
    // GitHub only stores strict alongside required checks, so it has no meaning without them.
    if (key === 'strict' && !want.required.length) continue
    if (want[key] !== have[key]) out.push(`${key} is ${have[key]}, want ${want[key]}`)
  }
  const missing = want.required.filter(c => !have.required.includes(c))
  const extra = have.required.filter(c => !want.required.includes(c))
  if (missing.length) out.push(`missing required checks: ${missing.join(', ')}`)
  if (extra.length) out.push(`required checks not in config: ${extra.join(', ')}`)
  return out
}

// A required check that the last merged PR never reported means PRs can't merge, or the name drifted.
function unreported(repo, required) {
  if (!required.length) return []
  const prs = json(['pr', 'list', '-R', `${OWNER}/${repo}`, '--state', 'merged', '--limit', '1', '--json', 'headRefOid']) ?? []
  if (!prs.length) return []
  const runs = json(['api', `repos/${OWNER}/${repo}/commits/${prs[0].headRefOid}/check-runs?per_page=100`])
  const seen = new Set((runs?.check_runs ?? []).map(r => r.name))
  return required.filter(c => !seen.has(c))
}

function body(want, protection) {
  const reviews = protection?.required_pull_request_reviews
  return JSON.stringify({
    required_status_checks: want.required.length ? { strict: want.strict, contexts: want.required } : null,
    enforce_admins: want.enforce_admins,
    required_pull_request_reviews: want.require_pull_request
      ? { required_approving_review_count: reviews?.required_approving_review_count ?? 0, dismiss_stale_reviews: reviews?.dismiss_stale_reviews ?? false }
      : null,
    restrictions: null,
  })
}

function main(argv) {
  const [mode, ...only] = argv
  if (!['audit', 'apply'].includes(mode)) {
    process.stderr.write('usage: branch-protection.mjs audit|apply [repo...]\n')
    return 64
  }
  const config = JSON.parse(fs.readFileSync(CONFIG, 'utf8'))
  let failing = 0
  for (const repo of only.length ? only : Object.keys(config.repos)) {
    const branch = json(['api', `repos/${OWNER}/${repo}`]).default_branch
    const endpoint = `repos/${OWNER}/${repo}/branches/${branch}/protection`
    const protection = json(['api', endpoint])
    const want = desired(config, repo)
    const problems = drift(want, actual(protection))
    const missingRuns = unreported(repo, want.required)
    if (mode === 'apply' && problems.length) {
      json(['api', '-X', 'PUT', endpoint, '--input', '-'], body(want, protection))
      process.stdout.write(`${repo}: applied (${problems.join('; ')})\n`)
    } else {
      process.stdout.write(`${repo}: ${problems.length ? problems.join('; ') : 'ok'}\n`)
      if (problems.length) failing++
    }
    if (missingRuns.length) { process.stdout.write(`${repo}: required checks the last merged PR never reported: ${missingRuns.join(', ')}\n`); failing++ }
    if (config.repos[repo].gap) process.stdout.write(`${repo}: gap: ${config.repos[repo].gap}\n`)
  }
  return failing ? 1 : 0
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try { process.exitCode = main(process.argv.slice(2)) } catch (error) {
    process.stderr.write(`branch-protection: ${error.message}\n`)
    process.exitCode = 70
  }
}
