---
name: zmcray-kickoff
description: Wire a repo into the McRay build system from Codex. Use when the user invokes /zmcray:kickoff, $zmcray-kickoff, asks to set up a repo for the workflow, or needs git/GitHub/Linear/AGENTS.md/PROJECT.md/docs/plans scaffolding before Caspian or build.
---

# ZMcRay Kickoff

Run the one-time repo setup workflow. Treat `/zmcray:kickoff` as an alias for this skill.

Kickoff creates the project shell. It does not create product issues; `$caspian` creates PRDs and labeled issues.

## 1. Location and Git

Confirm the working directory is under `~/Developer`. If it is under iCloud, `~/Documents`, `~/Library/Mobile Documents`, or another synced Work folder, stop and tell the user to move it to `~/Developer/[kebab-name]`.

Run `git rev-parse --is-inside-work-tree`. If not a repo, initialize git, set branch `main`, and ensure `.gitignore` covers at least:

```gitignore
node_modules/
.next/
dist/
build/
.env
.env.*
.DS_Store
```

If it is already a repo, note the current branch and continue.

## 2. GitHub Remote

Run `git remote get-url origin`.

- If present, print it and confirm it is intended.
- If missing, offer to create a private repo named after the folder using `gh repo create [folder-name] --private --source=. --remote=origin --push`. Confirm name and visibility before creating.
- If `gh` is missing or unauthenticated, print the manual remote commands instead of failing.

## 3. Directories

Ensure:

```text
docs/plans/archive/
docs/checkpoints/
```

Plans live in `docs/plans/`; completed plans move to `docs/plans/archive/`.

## 4. Linear Project

Use `.linear-project.json` at repo root as the durable link:

```json
{ "id": "...", "slug": "...", "name": "...", "team": "MCR" }
```

If the file exists with `id`, confirm and continue. Otherwise use Linear tools to find a unique Mcraygroup project by normalized repo name or `Local Path: ~/Developer/[name]`.

If no unique match, ask:

```text
1. Create a new Linear project for this repo
2. Link to an existing Linear project
3. Skip Linear linkage
```

Create/link only after the user chooses. When linked, write `.linear-project.json` and ensure the Linear project description carries the local path.

## 5. AGENTS.md Layer

Ensure the repo has the canonical workflow block. Prefer running the idempotent deploy script if present:

```bash
bash ~/Developer/dev-workflow/deploy-agents-md.sh
```

If unavailable, update `AGENTS.md` manually from `~/Developer/dev-workflow/AGENTS.workflow.md`. Ensure `CLAUDE.md` imports `@AGENTS.md`.

## 6. Database migration auto-deploy (if the repo uses Supabase)

Detect Supabase: a `supabase/` directory (or `supabase/config.toml`), or `@supabase/supabase-js` in `package.json`. If none, skip this section.

A Supabase repo MUST have an automatic path that applies migrations to the **production** database before it ships — deploying code never applies migrations (they are a separate ship), so without this the app runs ahead of its schema and every page reading a not-yet-applied column/table 500s in prod. Confirm one is in place, and set it up if not:

- **Default (no stored secrets):** Supabase dashboard → project → Integrations → GitHub → connect this repo. Set **Working directory** to the folder that *contains* `supabase/` (repo root `.`, or a subdir like `app`/`atlas` if nested — a wrong path silently applies nothing); **Deploy to production** ON → branch `main`; **Automatic branching** OFF (per-PR preview databases are billable and bypass the spend cap). This is an OAuth click-through — prompt the user through these settings and confirm.
- **Fallback:** a `supabase db push` GitHub Action on push to `main` (path-filtered to the migrations dir) with `SUPABASE_ACCESS_TOKEN` / `SUPABASE_PROJECT_ID` / `SUPABASE_DB_PASSWORD` repo secrets (set via `gh secret set`, never by scraping the keychain).

Don't consider a Supabase repo fully wired until this exists.

## 7. GitHub Actions cost and safety audit

If `.github/workflows/` is absent or empty, record "no workflows" and continue; do not create general-purpose CI by default. Otherwise inspect every workflow against the canonical **CI cost discipline** in `AGENTS.md`:

1. Record repository visibility and runner class.
2. Apply safe defaults where missing: workflow/ref concurrency with cancellation, short artifact retention, failure-only diagnostics, and secret/config preflights for scheduled or external-service jobs.
3. Identify safe docs-only or monorepo path filters, but first confirm a skipped workflow is not a required branch-protection check that would remain pending.
4. Flag expensive runner tiers, duplicated matrices, tiny fragmented jobs, large artifacts, and full suites on every push. Prefer a fast required PR gate plus full merge/manual coverage without weakening required coverage.
5. Keep scheduled workflows disabled until required secrets and configuration are confirmed.

Apply unambiguous repository-local fixes and surface topology or branch-protection choices in the handoff.

## 8. PROJECT.md

If `PROJECT.md` is missing, create the slim file:

```markdown
# [Project Name]

## Identity

| Field | Value |
|-------|-------|
| Linear | [project name or "none"] |
| GitHub | [remote URL or "none"] |

## Current Status

[Updated each build session by zmcray-wrap]

## Build Log

| Date | What happened |
|------|---------------|
| [YYYY-MM-DD] | Repo wired into build system. Linear: [project or "none"]. GitHub: [repo or "none"]. |
```

If a richer legacy file exists, preserve it and add missing Linear/GitHub identity rows.

## 9. Commit and Handoff

If setup files changed, stage and commit with:

`chore: wire repo into build system`

Push only when a remote exists and the user has approved remote creation/push. Close with the correct next step:

- No PRD/issues yet: suggest `$caspian`.
- Active issues exist: suggest `$zmcray-build`.
- One-off build: suggest `$zmcray-build [task]`.
- Linear skipped: suggest free-text `$zmcray-build [task]`.

## Success Criteria

Repo is under `~/Developer`, git exists on `main`, GitHub remote exists or manual path is printed, docs directories exist, Linear link is written or explicitly skipped, `AGENTS.md` and `CLAUDE.md` are wired, any Supabase repo has an automatic migration-to-prod path configured, `PROJECT.md` exists, and setup changes are committed when appropriate.
