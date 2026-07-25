---
name: zmcray-kickoff
description: Wire a repo into the build system. Git + GitHub, Linear link, AGENTS.md, slim PROJECT.md. Hands off to caspian or build. No tier... flow is per-issue.
argument-hint: "[project name or feature description]"
---

# Project Kickoff

One-time setup that wires a repo into the build system, then hands off to strategy (caspian) or execution (build). Flow is NOT set here: it is a per-issue label resolved at build time. Kickoff's job is to make sure git, GitHub, Linear, and the AGENTS.md layer are in place so everything downstream just works.

## Step 1: Location Guardrail + Version Control

### 1A: Location
Confirm the working directory is under `~/Developer`. If it is under iCloud (`~/Documents`, `~/Library/Mobile Documents`) or the Work folder, **stop**. iCloud evicts `.git` and `node_modules` and corrupts repos. Tell the user to move the repo to `~/Developer/[kebab-name]` first.

### 1B: Git
Run `git rev-parse --is-inside-work-tree`. If this is not a git repo:
1. `git init` and set the default branch to `main` (`git branch -M main`).
2. Ensure a baseline `.gitignore` exists. If missing, create one with at least: `node_modules/`, `.next/`, `dist/`, `build/`, `.env`, `.env.*`, `.DS_Store`. (An ungitignored `node_modules` is exactly what corrupts iCloud-synced repos... do not skip this.)

If it is already a git repo, note the current branch and move on.

### 1C: GitHub remote
Run `git remote get-url origin`.
- **Remote exists:** print it, confirm it is the intended repo, continue.
- **No remote:** offer to create one. **Confirm name and visibility before creating** (never auto-fire). Default: `gh repo create [folder-name] --private --source=. --remote=origin --push` (name = kebab-case folder name, matching the CODE-LOCATIONS convention).
  - If `gh` is missing or not authenticated, do NOT hard-fail. Print the manual path: create the repo on GitHub, then `git remote add origin git@github.com:zmcray/[name].git && git push -u origin main`.

## Step 2: Create Working Directories

```bash
mkdir -p docs/plans/archive docs/checkpoints
```

Plans live in `docs/plans/` (visible, project-local, show up in PR diffs); `archive/` holds completed plans. Checkpoints live in `docs/checkpoints/`.

## Step 3: Resolve / Create Linear Project (Auto-Link)

Goal: link this repo to a Linear project with zero manual mapping. Run in order:

The link lives *in the repo* as `.linear-project.json` at the repo root: `{ "id", "slug", "name", "team": "MCR" }`. No central cache.

### 3A: Existing link file
If `./.linear-project.json` already exists with an `id`, the repo is linked. Confirm and skip to Step 4.

### 3B: Resolve from Linear
Query the Linear MCP for projects on `Mcraygroup`. Match this repo by a project name matching the repo folder name (normalize: lowercase, drop spaces/hyphens), or a `Local Path` of `~/Developer/[name]`. On a unique match: write `./.linear-project.json`, print **"Linked to existing Linear project: [name]."** Skip to Step 4.

### 3C: Prompt for choice
If no match, ask:

```
No Linear project is linked to this repo. What should I do?
1. Create a new Linear project for this repo
2. Link to an existing Linear project (search by name)
3. Skip Linear linkage
```

**If 1 (create new):** create a project on `Mcraygroup` with name = project name, a one-line summary, and `**Local Path:** ~/Developer/[name]` in the description. Write `./.linear-project.json` with the new project's id/slug/name. Print the URL. (Set the native status field rather than writing a `Stage:` line by hand if the workspace uses native project statuses.)

**If 2 (link existing):** search by name fragment, present top 5, let the user pick. Write `./.linear-project.json` for the chosen project, and add `Local Path: ~/Developer/[name]` to its description if missing.

**If 3 (skip):** continue without linkage. Build will fall back to free-text task arguments.

## Step 4: Wire the AGENTS.md Layer

Ensure the repo carries the canonical workflow so any tool (Claude Code, Codex, Cursor) reads the same build rules.

1. If `AGENTS.md` is missing or lacks the `<!-- BEGIN CANONICAL WORKFLOW` marker, source the canonical block from `~/Developer/dev-workflow/AGENTS.workflow.md` and write/refresh AGENTS.md (repo-context header above the marked block). The simplest path is to run the deploy script: `bash ~/Developer/dev-workflow/deploy-agents-md.sh` (it is idempotent and acts on this repo if it lives in `~/Developer`).
2. Ensure `CLAUDE.md` imports it: a thin file containing `@AGENTS.md` (plus any Claude-only path-scoped rules). The deploy script does this too.

## Step 5: Database migration auto-deploy (if the repo uses Supabase)

Detect Supabase: a `supabase/` directory (or `supabase/config.toml`), or `@supabase/supabase-js` in `package.json`. If none of these, skip this step.

If the repo uses Supabase, it MUST have an automatic path that applies migrations to the **production** database before it ships. **Deploying code never applies migrations** — they are a separate ship — so without this, the app deploys ahead of its schema and every page that reads a not-yet-applied column/table 500s in prod. (Real scar: a repo can deploy green for days while its prod DB silently drifts behind; the failure only surfaces when new code reads a column prod doesn't have.) Confirm one of these is in place, and set it up if not:

**Default — Supabase's native GitHub Integration (no stored secrets):** Supabase dashboard → project → **Integrations → GitHub** → connect this repo, then set:
- **Working directory** = the folder that *contains* the `supabase/` folder (the repo root `.` if it's at the top; a subdir like `app`/`atlas` if nested — a wrong path silently applies nothing).
- **Deploy to production** ON → production branch `main`.
- **Automatic branching** OFF unless per-PR preview databases are explicitly wanted (their compute is billable and not covered by the org spend cap).

This is a dashboard OAuth click-through, so kickoff can't fully automate it — **prompt the user through these exact settings and confirm it's done** (same posture as creating the GitHub repo in 1C). It needs no secrets, which is the point.

**Fallback — `supabase db push` GitHub Action** (only if the native integration isn't viable): a workflow on push to `main` (path-filtered to the migrations dir) running `supabase link --project-ref …` + `supabase db push`, with `SUPABASE_ACCESS_TOKEN` / `SUPABASE_PROJECT_ID` / `SUPABASE_DB_PASSWORD` as repo secrets. Set secrets via `gh secret set` (stdin) or have the user set them — never scrape the keychain. **Authoring that workflow YAML is `haiku` work** — delegate it with the trigger, path filter, and step list specified, then verify the result here. The main thread's job is deciding the migration path, not typing the YAML.

Don't consider a Supabase repo fully wired until this exists.

## Step 6: Initialize PROJECT.md (Slim)

If `PROJECT.md` does not exist at the repo root, create it:

```markdown
# [Project Name]

## Identity

| Field | Value |
|-------|-------|
| Linear | [project name from Step 3, or "none"] |
| GitHub | [remote URL, or "none"] |

## Current Status

[Updated each build session by zmcray-wrap]

## Build Log

| Date | What happened |
|------|---------------|
| [YYYY-MM-DD] | Repo wired into build system. Linear: [project or "none"]. GitHub: [repo or "none"]. |
```

No Tier row (flow is per-issue). No Strategy section (lives in the Linear project + the PRD). No Milestones table (Linear projects/cycles or plan files). If a legacy rich PROJECT.md exists, leave its existing rows alone and just add the `Linear` / `GitHub` rows if missing.

## Step 7: Initial Commit

If Step 1 created the repo (or there are setup files uncommitted), stage and commit the scaffold: `chore: wire repo into build system (AGENTS.md, PROJECT.md, docs/plans)`. If a remote was created in 1C with `--push`, the branch is already pushed; otherwise `git push -u origin main`.

## Step 8: Handoff

Close with the right next step based on what Step 3 found:

- **New or empty Linear project, no issues/PRD yet:** offer to launch strategy now. *"Repo wired and linked to [project]. No PRD or issues yet. Run `/caspian` to produce the PRD and labeled issues against this project, then `/zmcray-build` to start. Want me to launch caspian now?"*
- **Project already has active issues:** *"Repo wired and linked to [project]. [N] active issues. Run `/zmcray-build` to pick up the highest-priority one."*
- **Quick build, no strategy needed:** *"Repo wired. For a one-off, just `/zmcray-build [task]`."*
- **Linear skipped:** *"Repo wired, no Linear link. Use `/zmcray-build [task]` with free-text."*

If caspian is not yet available in this environment, the offer degrades to a pointer rather than an invocation.

### Kickoff and caspian are bidirectional (not strictly kickoff-first)

Kickoff is the *infrastructure-first* entry point: you know you're building, so you wire the repo + Linear project shell, then hand off to caspian to produce the PRD and the labeled issues. But that is not the only order. Caspian runs on **lazy kickoff** ... its thinking phases need no repo or Linear at all, so an *idea-first* session can start in `/caspian` from a raw idea and only resolve infrastructure at its ship gate, where caspian runs this kickoff flow inline if no project exists yet.

So: kickoff creates the *project shell*; caspian creates the *issues*. Whichever runs first, kickoff never creates issues and caspian never creates a bare project (it routes through kickoff). Don't tell the user they must run kickoff before caspian ... they can, but starting in caspian is equally valid.

## Success Criteria

- [ ] Repo is under `~/Developer`, is a git repo on `main`, with a `.gitignore` covering `node_modules`/build/`.env*`
- [ ] GitHub remote exists (created/linked) or the manual path was printed
- [ ] `docs/plans/archive/` and `docs/checkpoints/` exist
- [ ] Linear linkage resolved (created, linked, or explicitly skipped); `.linear-project.json` written at the repo root if linked
- [ ] AGENTS.md carries the canonical block; CLAUDE.md imports it
- [ ] If the repo uses Supabase: automatic migration-to-prod path configured (native GitHub Integration, or fallback db-push Action) and confirmed
- [ ] Slim PROJECT.md exists with Linear + GitHub rows
- [ ] Scaffold committed; handoff step printed

## Notes

- **No tier, by design.** Flow is a per-issue label (`flow:design/standard/ship`) set by caspian at issue creation or by build's triage at pickup. A repo holds a mix of flows, so there is no repo-level default to set here.
- The Linear link lives in the repo as `.linear-project.json` (id + slug + name). It travels with the repo, so it never goes stale from a move. Wrong link? Delete the file and re-run, or re-link via Step 3C.
- Kickoff is one-time per repo. Re-running is safe (idempotent checks throughout) and useful to repair a half-wired repo.
- Creating a GitHub repo is a real external action: always confirm name + visibility first, never auto-create.
