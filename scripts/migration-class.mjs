#!/usr/bin/env node
// Classify a Postgres migration as `additive` (covered by the class standing approval)
// or `gated` (Zack applies it). Reads the SQL itself, never the chunk's own label.
// Rules: rules/build.md > Standing approval > Class approval. Unsure means gated.
//
//   node scripts/migration-class.mjs <file.sql>...          one line per file, then the gated statements
//   node scripts/migration-class.mjs --json <file.sql>...   one JSON object per file
//
// Exit 0: every file is additive. 1: at least one is gated. 2: usage error or unreadable file.

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const ID = String.raw`(?:"[^"]+"|[a-z_][a-z0-9_$]*)`
const QN = String.raw`${ID}(?:\.${ID})?`
const SAFE_ROLES = new Set(['service_role', 'postgres', 'supabase_admin'])
const NO_ACCESS_ROLES = ['public', 'anon', 'authenticated']
const FORBIDDEN_SCHEMA = /^(auth|storage|vault|cron|realtime|net|pgsodium|extensions|pg_catalog|information_schema|graphql|graphql_public|supabase_\w+|_realtime)$/

// ---------- lexing: strip comments, hide literals and bodies, split on top-level `;` ----------

export function splitStatements(sql) {
  const out = []
  let shape = ''
  let text = ''
  let bodies = []
  let i = 0
  const n = sql.length
  const push = () => {
    const s = shape.replace(/\s+/g, ' ').trim()
    if (s) out.push({ shape: s, text: text.trim(), bodies })
    shape = ''
    text = ''
    bodies = []
  }
  while (i < n) {
    const c = sql[i]
    const next = sql[i + 1]
    if (c === '-' && next === '-') {
      while (i < n && sql[i] !== '\n') i++
      shape += ' '
      continue
    }
    if (c === '/' && next === '*') {
      let depth = 1
      i += 2
      while (i < n && depth > 0) {
        if (sql[i] === '/' && sql[i + 1] === '*') { depth++; i += 2 } else if (sql[i] === '*' && sql[i + 1] === '/') { depth--; i += 2 } else i++
      }
      if (depth > 0) throw new Error('unterminated block comment')
      shape += ' '
      continue
    }
    if (c === "'") {
      const escapes = /[eE]/.test(sql[i - 1] || '') && !/[a-zA-Z0-9_]/.test(sql[i - 2] || '')
      let j = i + 1
      let body = ''
      for (;;) {
        if (j >= n) throw new Error('unterminated string literal')
        if (escapes && sql[j] === '\\') { body += sql[j] + (sql[j + 1] || ''); j += 2; continue }
        if (sql[j] === "'") {
          if (sql[j + 1] === "'") { body += "'"; j += 2; continue }
          break
        }
        body += sql[j++]
      }
      if (escapes) shape = shape.slice(0, -1)
      shape += body === '' ? "''" : "'?'"
      text += sql.slice(i, j + 1)
      i = j + 1
      continue
    }
    if (c === '"') {
      const j = sql.indexOf('"', i + 1)
      if (j < 0) throw new Error('unterminated quoted identifier')
      const ident = sql.slice(i + 1, j)
      shape += /^[a-z_][a-z0-9_$]*$/.test(ident) ? ident : `"${ident}"`
      text += sql.slice(i, j + 1)
      i = j + 1
      continue
    }
    if (c === '$') {
      const m = /^\$([A-Za-z_][A-Za-z0-9_]*)?\$/.exec(sql.slice(i))
      if (m && !/[A-Za-z0-9_]/.test(sql[i - 1] || '')) {
        const tag = m[0]
        const end = sql.indexOf(tag, i + tag.length)
        if (end < 0) throw new Error(`unterminated dollar-quoted body ${tag}`)
        shape += ' $body$ '
        bodies.push(sql.slice(i + tag.length, end))
        text += sql.slice(i, end + tag.length)
        i = end + tag.length
        continue
      }
    }
    if (c === ';') { push(); i++; continue }
    shape += c.toLowerCase()
    text += c
    i++
  }
  push()
  return out
}

// ---------- names ----------

function normName(qn, defaultSchema = 'public') {
  const parts = []
  const re = new RegExp(ID, 'g')
  let m
  while ((m = re.exec(qn))) parts.push(m[0].replace(/^"|"$/g, ''))
  if (parts.length === 1) parts.unshift(defaultSchema)
  return parts.join('.')
}
const schemaOf = (name) => name.split('.')[0]
const forbidden = (name) => FORBIDDEN_SCHEMA.test(schemaOf(name))

function splitTop(s) {
  const parts = []
  let depth = 0
  let cur = ''
  for (const ch of s) {
    if (ch === '(') depth++
    if (ch === ')') depth--
    if (ch === ',' && depth === 0) { parts.push(cur.trim()); cur = ''; continue }
    cur += ch
  }
  if (cur.trim()) parts.push(cur.trim())
  return parts
}

// `function a.f(int), table t, v` -> [{ kind, name }]
function objectList(s) {
  const lead = s.match(/^(all (?:tables|functions|sequences|routines|procedures) in schema)\b/)
  if (lead) return [{ kind: 'bulk', name: s }]
  let kind = 'table'
  return splitTop(s).map((item) => {
    const m = item.match(/^(function|procedure|routine|table|sequence|view|schema|type|materialized view) (.*)$/)
    if (m) { kind = m[1]; item = m[2] }
    const name = item.replace(/\(.*\)$/s, '').trim()
    return { kind, name: kind === 'schema' ? name.replace(/"/g, '') : normName(name) }
  })
}

const roleList = (s) => splitTop(s).map((r) => r.replace(/^group /, '').replace(/"/g, '').trim())

// ---------- guard blocks ----------

// A `do $$ ... $$` block is allowed only when it is a read-only guard: it reads the
// catalog and raises an exception when the database is not in the expected state.
const GUARD_DENY = /\b(insert|update|delete|truncate|drop|alter|create|grant|revoke|execute|copy|merge|call|perform|lock|set|reset|comment|notify|listen|refresh|vacuum|cluster|reindex|analyze|security|commit|rollback|savepoint|import|load|discard|prepare)\b/
const GUARD_CALLS = new Set([
  'if', 'elsif', 'and', 'or', 'not', 'in', 'exists', 'any', 'all', 'array', 'when', 'then', 'else', 'case', 'values', 'select', 'from', 'where', 'on', 'join', 'over', 'filter', 'return', 'returns', 'loop', 'into', 'by', 'is', 'as', 'with', 'distinct', 'cast', 'row',
  'to_regclass', 'to_regprocedure', 'to_regproc', 'to_regtype', 'to_regrole', 'to_regnamespace', 'to_regoper',
  'md5', 'coalesce', 'nullif', 'greatest', 'least', 'format', 'concat', 'concat_ws', 'lower', 'upper', 'length', 'char_length', 'trim', 'replace', 'position', 'substring', 'left', 'right', 'split_part', 'regexp_replace', 'starts_with',
  'count', 'string_agg', 'array_agg', 'array_length', 'cardinality', 'unnest', 'min', 'max', 'bool_and', 'bool_or', 'sum',
  'pg_get_constraintdef', 'pg_get_viewdef', 'pg_get_functiondef', 'pg_get_indexdef', 'pg_get_triggerdef', 'pg_get_function_arguments', 'pg_get_function_identity_arguments', 'pg_get_function_result', 'pg_get_expr', 'pg_get_userbyid', 'aclexplode', 'format_type', 'obj_description', 'col_description',
  'has_table_privilege', 'has_column_privilege', 'has_function_privilege', 'has_schema_privilege', 'has_sequence_privilege', 'has_any_column_privilege', 'has_database_privilege', 'pg_has_role',
  'current_setting', 'current_user', 'session_user', 'current_schema', 'version', 'quote_ident', 'quote_literal',
])

function guardBlock(body) {
  let shape
  try {
    shape = splitStatements(body).map((s) => s.shape).join('; ')
  } catch {
    return 'block body could not be parsed'
  }
  const deny = shape.match(GUARD_DENY)
  if (deny) return `block does "${deny[1]}"`
  for (const m of shape.matchAll(/([a-z_][a-z0-9_$]*(?:\.[a-z_][a-z0-9_$]*)?)\s*\(/g)) {
    if (!GUARD_CALLS.has(m[1]) && !/^pg_catalog\./.test(m[1])) return `block calls ${m[1]}()`
  }
  return null
}

// ---------- classification ----------

const ok = (reason = null) => ({ verdict: 'additive', reason })
const gate = (reason) => ({ verdict: 'gated', reason })

export function classify(sql) {
  let stmts
  try {
    stmts = splitStatements(sql)
  } catch (e) {
    return { class: 'gated', statements: [], reasons: [`could not parse: ${e.message}`] }
  }
  if (stmts.some((s) => /\bbegin atomic\b/.test(s.shape))) {
    return { class: 'gated', statements: [], reasons: ['could not parse: SQL-standard function body (begin atomic)'] }
  }

  // Pass 1: what this file creates.
  const created = { table: new Set(), view: new Set(), function: new Set(), schema: new Set(), sequence: new Set(), type: new Set() }
  const rlsOn = new Set()
  for (const { shape: s } of stmts) {
    let m
    if ((m = s.match(new RegExp(`^create (?:unlogged |temp |temporary )?table (?:if not exists )?(${QN})`)))) created.table.add(normName(m[1]))
    if ((m = s.match(new RegExp(`^create (?:or replace )?(?:temp |temporary )?(?:recursive )?view (${QN})`)))) created.view.add(normName(m[1]))
    if ((m = s.match(new RegExp(`^create (?:or replace )?(?:function|procedure) (${QN})\\s*\\(`)))) created.function.add(normName(m[1]))
    if ((m = s.match(new RegExp(`^create schema (?:if not exists )?(${ID})`)))) created.schema.add(m[1].replace(/"/g, ''))
    if ((m = s.match(new RegExp(`^create sequence (?:if not exists )?(${QN})`)))) created.sequence.add(normName(m[1]))
    if ((m = s.match(new RegExp(`^create (?:type|domain) (${QN})`)))) created.type.add(normName(m[1]))
    if ((m = s.match(new RegExp(`^alter table (?:if exists )?(?:only )?(${QN}) (.*)$`)))) {
      if (splitTop(m[2]).some((a) => /^(enable|force) row level security$/.test(a))) rlsOn.add(normName(m[1]))
    }
  }
  const isCreated = (o) => o.kind !== 'bulk' && Object.values(created).some((set) => set.has(o.name))

  // Revokes collected for the file-level checks: object name -> roles revoked.
  const revoked = new Map()
  const definers = []
  const exposedViews = []

  const results = stmts.map(({ shape: s, text, bodies }, index) => {
    const r = classifyOne(s, bodies)
    return { index: index + 1, verdict: r.verdict, reason: r.reason, text: text.length > 160 ? `${text.slice(0, 157)}...` : text }
  })

  function classifyOne(s, bodies) {
    let m
    if (/^do (language plpgsql )?\$body\$( language plpgsql)?$/.test(s)) {
      const why = guardBlock(bodies[0])
      return why ? gate(`do block is not a read-only guard: ${why}`) : ok()
    }
    if (/^lock (table )?(only )?.+ in [a-z ]+ mode( nowait)?$/.test(s)) return ok()
    if (/^(begin|commit|end|start transaction)( work| transaction)?$/.test(s)) return ok()
    if (/^set (local |session )?(lock_timeout|statement_timeout|idle_in_transaction_session_timeout|check_function_bodies|client_min_messages)\b/.test(s)) return ok()
    if (/^notify pgrst\b/.test(s) || /^select pg_notify\('\?'(, ('\?'|''))?\)$/.test(s)) return ok()
    if (/^comment on /.test(s)) return ok()

    if ((m = s.match(new RegExp(`^create (unlogged |temp |temporary )?table (?:if not exists )?(${QN})(.*)$`)))) {
      const name = normName(m[2])
      if (forbidden(name)) return gate(`creates a table in the ${schemaOf(name)} schema`)
      if (/^\s*(\([^)]*\)\s*)?as\b/.test(m[3])) return gate('create table as select copies existing data')
      if (!m[1]?.startsWith('temp') && !rlsOn.has(name)) return gate(`new table ${name} has no "enable row level security" in this file`)
      return ok()
    }
    if ((m = s.match(new RegExp(`^create (?:unique )?index (?:concurrently )?(?:if not exists )?(?:${ID} )?on (?:only )?(${QN})`)))) {
      const t = normName(m[1])
      return forbidden(t) ? gate(`index on ${t}`) : ok()
    }
    if ((m = s.match(new RegExp(`^create (?:or replace )?(?:temp |temporary )?(?:recursive )?view (${QN})(.*?) as (.*)$`)))) {
      const name = normName(m[1])
      if (forbidden(name)) return gate(`creates a view in the ${schemaOf(name)} schema`)
      if (/\b(auth|storage|vault|cron)\.(?!(uid|jwt|role|email)\s*\()[a-z_]+/.test(m[3])) return gate(`view ${name} reads a protected schema`)
      if (!/security_invoker\s*(=\s*)?(true|on|1)\b/.test(m[2])) exposedViews.push(name)
      return ok()
    }
    if ((m = s.match(new RegExp(`^create (?:or replace )?(?:function|procedure) (${QN})\\s*\\((.*)$`)))) {
      const name = normName(m[1])
      if (forbidden(name)) return gate(`creates a function in the ${schemaOf(name)} schema`)
      if (/\bsecurity definer\b/.test(m[2])) {
        if (!/\bset search_path (=|to) ''/.test(m[2])) return gate(`security definer function ${name} without set search_path = ''`)
        definers.push(name)
      }
      return ok()
    }
    if ((m = s.match(new RegExp(`^create (?:or replace )?(?:constraint )?trigger ${ID} .*? on (${QN})`)))) {
      const t = normName(m[1])
      return created.table.has(t) ? ok() : gate(`trigger changes writes on existing table ${t}`)
    }
    if ((m = s.match(new RegExp(`^create schema (?:if not exists )?(${ID})`)))) return forbidden(m[1].replace(/"/g, '')) ? gate('protected schema') : ok()
    if ((m = s.match(new RegExp(`^create sequence (?:if not exists )?(${QN})`)))) return forbidden(normName(m[1])) ? gate('protected schema') : ok()
    if ((m = s.match(new RegExp(`^create (?:type (${QN}) as (?:enum )?\\(|type (${QN}) as range\\b|domain (${QN}) )`)))) {
      return forbidden(normName(m[1] || m[2] || m[3])) ? gate('protected schema') : ok()
    }
    if ((m = s.match(new RegExp(`^alter type (${QN}) add value\\b`)))) return forbidden(normName(m[1])) ? gate('protected schema') : ok()

    if ((m = s.match(new RegExp(`^alter table (?:if exists )?(?:only )?(${QN}) (.*)$`)))) {
      const t = normName(m[1])
      if (forbidden(t)) return gate(`alters ${t}`)
      for (const a of splitTop(m[2])) {
        if (/^(enable|force) row level security$/.test(a)) continue
        if (/^owner to (postgres|supabase_admin)$/.test(a)) continue
        if (/^add (constraint|primary key|unique|check|foreign key|exclude)\b/.test(a)) return gate(`adds a constraint to ${t}: ${a.slice(0, 60)}`)
        if (/^add (column )?(if not exists )?/.test(a)) {
          if (/\bprimary key\b/.test(a)) return gate(`adds a primary key column to ${t}`)
          if (/\bnot null\b/.test(a) && !/\bdefault\b/.test(a)) return gate(`adds a NOT NULL column with no default to ${t}`)
          continue
        }
        return gate(`alter table ${t}: ${a.slice(0, 60)}`)
      }
      return ok()
    }
    if ((m = s.match(new RegExp(`^alter (?:function|procedure|routine) (${QN})\\s*(?:\\([^)]*\\))? (.*)$`)))) {
      if (/^(owner to (postgres|supabase_admin)|set search_path (=|to) .*|reset search_path|security invoker)$/.test(m[2])) return ok()
      return gate(`alter function ${normName(m[1])}: ${m[2].slice(0, 60)}`)
    }
    if ((m = s.match(new RegExp(`^alter view (?:if exists )?(${QN}) (.*)$`)))) {
      if (/^(owner to (postgres|supabase_admin)|set \(security_invoker\s*=\s*(true|on)\))$/.test(m[2])) return ok()
      return gate(`alter view ${normName(m[1])}: ${m[2].slice(0, 60)}`)
    }
    if ((m = s.match(new RegExp(`^alter sequence (?:if exists )?(${QN}) (owned by ${QN}(?:\\.${ID})?|owner to (?:postgres|supabase_admin))$`)))) return ok()

    if ((m = s.match(/^revoke (?:grant option for )?(.+?) on (.+?) from (.+?)(?: cascade| restrict)?$/))) {
      const objs = objectList(m[2])
      const notOurs = objs.filter((o) => !isCreated(o))
      if (notOurs.length) return gate(`revokes on ${notOurs.map((o) => o.name).join(', ')}, which this file does not create`)
      for (const o of objs) {
        const set = revoked.get(o.name) || new Set()
        roleList(m[3]).forEach((r) => set.add(r))
        revoked.set(o.name, set)
      }
      return ok()
    }
    if ((m = s.match(/^grant (.+?) on (.+?) to (.+?)$/))) {
      if (/ with grant option$/.test(m[3])) return gate('grant with grant option')
      const wide = roleList(m[3]).filter((r) => !SAFE_ROLES.has(r))
      return wide.length ? gate(`grant widens access to ${wide.join(', ')}`) : ok()
    }
    if ((m = s.match(new RegExp(`^create policy ${ID} on (${QN})(.*)$`)))) {
      const t = normName(m[1])
      if (forbidden(t)) return gate(`policy on ${t}`)
      if (/\bas restrictive\b/.test(m[2])) return ok()
      const to = m[2].match(/\bto (.+?)(?: using\b| with check\b|$)/)
      if (to && roleList(to[1]).every((r) => SAFE_ROLES.has(r))) return ok()
      return gate(`permissive policy on ${t} widens access (only "as restrictive" narrows)`)
    }
    if ((m = s.match(new RegExp(`^insert into (${QN})`)))) {
      const t = normName(m[1])
      if (!created.table.has(t)) return gate(`writes rows to existing table ${t}`)
      if (/\bon conflict\b.*\bdo update\b/.test(s)) return gate('insert ... on conflict do update changes rows')
      return ok()
    }
    return gate(`not on the additive list: ${s.split(' ').slice(0, 4).join(' ')}`)
  }

  // File-level checks: implicit grants Supabase adds to new objects in exposed schemas.
  const reasons = []
  const covers = (name, roles) => {
    const set = revoked.get(name)
    return set && (set.has('all') || roles.every((r) => set.has(r)))
  }
  for (const f of definers) {
    if (!covers(f, NO_ACCESS_ROLES)) reasons.push(`security definer function ${f} keeps execute for public, anon or authenticated: revoke it in this file`)
  }
  for (const v of exposedViews) {
    if (!covers(v, ['anon', 'authenticated'])) reasons.push(`view ${v} is not security_invoker and is not revoked from anon and authenticated`)
  }
  const gatedStmts = results.filter((r) => r.verdict === 'gated')
  const klass = gatedStmts.length || reasons.length ? 'gated' : 'additive'
  return { class: klass, statements: results, reasons: [...gatedStmts.map((r) => `#${r.index}: ${r.reason}`), ...reasons] }
}

// ---------- CLI ----------

function main(argv) {
  const json = argv.includes('--json')
  const files = argv.filter((a) => a !== '--json')
  if (!files.length) {
    process.stderr.write('usage: migration-class.mjs [--json] <file.sql>...\n')
    return 2
  }
  let anyGated = false
  for (const file of files) {
    let sql
    try {
      sql = fs.readFileSync(file, 'utf8')
    } catch (e) {
      process.stderr.write(`${file}: ${e.message}\n`)
      return 2
    }
    const r = classify(sql)
    if (r.class === 'gated') anyGated = true
    if (json) {
      process.stdout.write(`${JSON.stringify({ file, class: r.class, reasons: r.reasons, statements: r.statements.length })}\n`)
    } else {
      process.stdout.write(`${r.class.padEnd(8)} ${file}\n`)
      for (const reason of r.reasons) process.stdout.write(`         ${reason}\n`)
    }
  }
  return anyGated ? 1 : 0
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(main(process.argv.slice(2)))
}
