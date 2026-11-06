#!/usr/bin/env bash
# Tests for migration-class.mjs: what the class standing approval covers (rules/build.md).
set -euo pipefail
export CLASSIFIER="$(cd "$(dirname "$0")" && pwd)/migration-class.mjs"
node --input-type=module <<'NODE'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { spawnSync } from 'node:child_process'
const { classify } = await import(process.env.CLASSIFIER)

const additive = (sql, why) => {
  const r = classify(sql)
  assert.equal(r.class, 'additive', `${why}: ${r.reasons.join('; ')}`)
}
const gated = (sql, why, pattern) => {
  const r = classify(sql)
  assert.equal(r.class, 'gated', `${why} should be gated`)
  if (pattern) assert.match(r.reasons.join('\n'), pattern, why)
}

// Allowed
additive(`create table os.notes (id uuid primary key, body text not null);
alter table os.notes enable row level security;`, 'new table with RLS')
additive(`alter table os.items add column note text;`, 'nullable column')
additive(`alter table os.items add column if not exists done boolean not null default false;`, 'NOT NULL column with a default')
additive(`alter table os.items add column a int, add column b text default 'x';`, 'two added columns')
additive(`create index concurrently if not exists items_due on os.items (due_date);
create unique index items_key on os.items (key);`, 'indexes')
additive(`create or replace view public.v with (security_invoker = true) as select id from os.items;`, 'invoker view')
additive(`create view public.v as select id from os.items;
revoke all on public.v from public, anon, authenticated;
grant select on public.v to service_role;`, 'definer view locked to service_role')
additive(`create or replace function public.f(p int) returns int language sql security invoker as $$ select p $$;`, 'invoker function')
additive(`create or replace function public.f(p uuid) returns void language plpgsql security definer set search_path = '' as $fn$
begin delete from os.items where id = p; update os.items set x = 1; drop table if exists t; end $fn$;
alter function public.f(uuid) owner to postgres;
revoke all on function public.f(uuid) from public, anon, authenticated;
grant execute on function public.f(uuid) to service_role;
comment on function public.f(uuid) is 'drop table; delete';`, 'DML inside a locked definer function is code')
additive(`create policy only_mine on os.items as restrictive for select to authenticated using (owner = auth.uid());`, 'restrictive policy narrows')
additive(`alter table os.items enable row level security; alter table os.items force row level security;`, 'enabling RLS narrows')
additive(`set local lock_timeout = '5s'; begin; create schema if not exists reports; create type os.mood as enum ('a', 'b'); alter type os.mood add value if not exists 'c'; commit; notify pgrst, 'reload schema';`, 'housekeeping statements')
additive(`do $$ begin
  if to_regclass('os.items') is null then raise exception 'missing %', 'os.items'; end if;
  if exists (select 1 from pg_roles where rolname = 'x') and not has_table_privilege('anon', 'os.items', 'SELECT') then return; end if;
end $$;`, 'read-only guard block')
additive(`create table os.t (id int primary key); alter table os.t enable row level security;
insert into os.t (id) values (1), (2);
create trigger t_bu before update on os.t for each row execute function os.touch();`, 'seed rows and trigger on a new table')
additive(`-- drop table os.items;
/* delete from os.items; /* nested */ */
alter table os.items add column note text;`, 'keywords in comments are ignored')

// Gated
gated(`drop table os.items;`, 'drop', /not on the additive list: drop table/)
gated(`alter table os.items drop column note;`, 'drop column', /drop column/)
gated(`alter table os.items rename column a to b;`, 'rename', /rename/)
gated(`alter table os.items rename to things;`, 'rename table', /rename/)
gated(`alter table os.items alter column due type timestamptz;`, 'type change', /alter column/)
gated(`alter table os.items alter column due set not null;`, 'NOT NULL on an existing column', /set not null/)
gated(`alter table os.items add column must text not null;`, 'NOT NULL column with no default', /NOT NULL/)
gated(`update os.items set status = 'done';`, 'row update')
gated(`delete from os.items where id = 1;`, 'row delete')
gated(`truncate os.items;`, 'truncate')
gated(`insert into os.items (id) values (1);`, 'insert into an existing table', /existing table/)
gated(`grant select on os.items to authenticated;`, 'grant to authenticated', /widens access to authenticated/)
gated(`grant execute on function public.f(int) to chief_of_staff;`, 'grant to a custom role', /chief_of_staff/)
gated(`grant usage on schema os to anon;`, 'schema grant to anon', /anon/)
gated(`create policy everyone on os.items for select to anon using (true);`, 'permissive policy widens', /permissive/)
gated(`alter policy p on os.items using (true);`, 'policy change')
gated(`alter table os.items disable row level security;`, 'disable RLS', /disable row level security/)
gated(`create table os.t (id int);`, 'new table without RLS', /enable row level security/)
gated(`create or replace function public.f() returns void language sql security definer as $$ select 1 $$;`, 'definer without search_path', /search_path/)
gated(`create or replace function public.f() returns void language sql security definer set search_path = '' as $$ select 1 $$;`, 'definer still executable by anon', /keeps execute/)
gated(`create view public.v as select id from os.items;`, 'definer view left open to anon', /security_invoker/)
gated(`create view public.v with (security_invoker = true) as select email from auth.users;`, 'view over auth.users', /protected schema/)
gated(`create table auth.extra (id int); alter table auth.extra enable row level security;`, 'auth schema', /auth schema/)
gated(`insert into storage.buckets (id) values ('x');`, 'storage write')
gated(`create extension if not exists pg_cron;`, 'extension')
gated(`create role reporter;`, 'role')
gated(`revoke select on os.items from authenticated;`, 'revoke on an existing object', /does not create/)
gated(`do $$ begin alter table os.items drop constraint c; end $$;`, 'DDL inside a do block', /do block/)
gated(`do $$ begin execute format('grant select on os.items to %I', 'anon'); end $$;`, 'dynamic SQL inside a do block', /execute/)
gated(`do $$ begin perform os.backfill(); end $$;`, 'perform inside a do block', /perform/)
gated(`create trigger t after insert on os.items for each row execute function os.f();`, 'trigger on an existing table', /existing table/)
gated(`alter table os.items add constraint c check (x > 0);`, 'constraint on an existing table', /constraint/)
gated(`select cron.schedule('x', '* * * * *', 'select 1');`, 'top-level select', /not on the additive list/)
gated(`create function f() returns int language sql begin atomic select 1; end;`, 'begin atomic body', /begin atomic/)
gated(`alter table os.items add column note text; 'unterminated`, 'unparseable file', /could not parse/)

// Labels never count: a comment claiming the file is additive changes nothing.
gated(`-- class: additive
drop table os.items;`, 'a label in a comment')

// CLI: exit codes and output.
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'migration-class-'))
const a = path.join(dir, 'a.sql'); fs.writeFileSync(a, 'create index i on os.t (x);')
const g = path.join(dir, 'g.sql'); fs.writeFileSync(g, 'drop table os.t;')
const run = (...args) => spawnSync(process.execPath, [process.env.CLASSIFIER, ...args], { encoding: 'utf8' })
assert.equal(run(a).status, 0, 'additive file exits 0')
assert.match(run(a).stdout, /^additive/)
assert.equal(run(a, g).status, 1, 'any gated file exits 1')
assert.match(run(g).stdout, /gated .*\n.*drop table/)
assert.equal(JSON.parse(run('--json', g).stdout).class, 'gated', '--json prints one object per file')
assert.equal(run().status, 2, 'no file is a usage error')
assert.equal(run(path.join(dir, 'missing.sql')).status, 2, 'missing file exits 2')
console.log('migration-class: all tests passed')
NODE
