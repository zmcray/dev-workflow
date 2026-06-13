---
name: zmcray:kickoff
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

### 3A: Read the cache
Look for `~/Documents/Work/.linear-projects.json`. Compute the repo path relative to `~/Documents/Work/` (note: repos now live in `~/Developer`, so the cache key is the `~/Developer/[name]` path). If the key exists, use the cached project. Skip to Step 4.

### 3B: Query Linear by Local Path
On cache miss, query the Linear MCP for projects on the `Mcraygroup` team and scan each description for a `Local Path:` line matching this repo's path. On a unique match: use it, append to the cache, print **"Linked to existing Linear project: [name]."** Skip to Step 4.

### 3C: Prompt for choice
If no match, ask:

```
No Linear project is linked to this repo. What should I do?
1. Create a new Linear project for this repo
2. Link to an existing Linear project (search by name)
3. Skip Linear linkage
```

**If 1 (create new):** create a project on `Mcraygroup` with name = project name, description carrying `**Owner:** [from user]` and `**Local Path:** [repo path]`, and a one-line summary. Append to the cache. Print the URL. (Do not write a `Stage:` line by hand if the workspace has moved to native project statuses... set the status field instead.)

**If 2 (link existing):** search by name fragment, present top 5, let the user pick. Update the chosen project's description to add the `Local Path:` field if missing (so future auto-linking works). Append to the cache.

**If 3 (skip):** continue without linkage. Build will fall back to free-text task arguments.

## Step 4: Wire the AGENTS.md Layer

Ensure the repo carries the canonical workflow so any tool (Claude Code, Codex, Cursor) reads the same build rules.

1. If `AGENTS.md` is missing or lacks the `<!-- BEGIN CANONICAL WORKFLOW` marker, source the canonical block from `~/Developer/dev-workflow/AGENTS.workflow.md` and write/refresh AGENTS.md (repo-context header above the marked block). The simplest path is to run the deploy script: `bash ~/Developer/dev-workflow/deploy-agents-md.sh` (it is idempotent and acts on this repo if it lives in `~/Developer`).
2. Ensure `CLAUDE.md` imports it: a thin file containing `@AGENTS.md` (plus any Claude-only path-scoped rules). The deploy script does this too.

## Step 5: Initialize PROJECT.md (Slim)

If `PROJECT.md` does not exist at the repo root, create it:

```markdown
# [Project Name]

## Identity

| Field | Value |
|-------|-------|
| Linear | [project name from Step 3, or "none"] |
| GitHub | [remote URL, or "none"] |

## Current Status

[Updated each build session by zmcray:wrap]

## Build Log

| Date | What happened |
|------|---------------|
| [YYYY-MM-DD] | Repo wired into build system. Linear: [project or "none"]. GitHub: [repo or "none"]. |
```

No Tier row (flow is per-issue). No Strategy section (lives in the Linear project + the PRD). No Milestones table (Linear projects/cycles or plan files). If a legacy rich PROJECT.md exists, leave its existing rows alone and just add the `Linear` / `GitHub` rows if missing.

## Step 6: Initial Commit

If Step 1 created the repo (or there are setup files uncommitted), stage and commit the scaffold: `chore: wire repo into build system (AGENTS.md, PROJECT.md, docs/plans)`. If a remote was created in 1C with `--push`, the branch is already pushed; otherwise `git push -u origin main`.

## Step 7: Handoff

Close with the right next step based on what Step 3 found:

- **New or empty Linear project, no issues/PRD yet:** offer to launch strategy now. *"Repo wired and linked to [project]. No PRD or issues yet. Run `/caspian` to produce the PRD and labeled issues against this project, then `/zmcray:build` to start. Want me to launch caspian now?"* (caspian assumes the project already exists from this step, so the order is correct.)
- **Project already has active issues:** *"Repo wired and linked to [project]. [N] active issues. Run `/zmcray:build` to pick up the highest-priority one."*
- **Quick build, no strategy needed:** *"Repo wired. For a one-off, just `/zmcray:build [task]`."*
- **Linear skipped:** *"Repo wired, no Linear link. Use `/zmcray:build [task]` with free-text."*

If caspian is not yet available in this environment, the offer degrades to a pointer rather than an invocation.

## Success Criteria

- [ ] Repo is under `~/Developer`, is a git repo on `main`, with a `.gitignore` covering `node_modules`/build/`.env*`
- [ ] GitHub remote exists (created/linked) or the manual path was printed
- [ ] `docs/plans/archive/` and `docs/checkpoints/` exist
- [ ] Linear linkage resolved (created, linked, or explicitly skipped) and cache updated
- [ ] AGENTS.md carries the canonical block; CLAUDE.md imports it
- [ ] Slim PROJECT.md exists with Linear + GitHub rows
- [ ] Scaffold committed; handoff step printed

## Notes

- **No tier, by design.** Flow is a per-issue label (`flow:design/standard/ship`) set by caspian at issue creation or by build's triage at pickup. A repo holds a mix of flows, so there is no repo-level default to set here.
- The cache file is a performance shortcut; Linear's `Local Path:` field is the source of truth. Wrong cache entry? Delete it and re-run.
- Kickoff is one-time per repo. Re-running is safe (idempotent checks throughout) and useful to repair a half-wired repo.
- Creating a GitHub repo is a real external action: always confirm name + visibility first, never auto-create.
