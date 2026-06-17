<!-- BEGIN CANONICAL WORKFLOW (managed by deploy-agents-md.sh ... edit here, not in repos) -->

## Issue tracker

Linear (Mcraygroup team). File all deferred findings, residuals, and follow-ups there. The board is the audit trail: move issue status as work progresses, post plan and review summaries as comments, and link the PR. A reviewer should be able to follow the whole build without opening a terminal.

## Project setup (one-time)

A repo wired into this system is:

- A git repo with a private GitHub remote, kebab-case name matching the folder, living under `~/Developer` (never iCloud), with `node_modules`, `.next`, build output, and `.env*` gitignored.
- Linked to a Linear project, recorded in a `.linear-project.json` file at the repo root (id + slug + name). The link travels with the repo... no central cache.
- Carrying this `AGENTS.md` plus a `CLAUDE.md` that imports it (`@AGENTS.md`).

Plans live in `docs/plans/` (archive completed ones in `docs/plans/archive/`); checkpoints live in `docs/checkpoints/`. Flow is never set at the repo level: it is a per-issue property (see below). On Claude Code, `/zmcray-kickoff` performs this setup once, then hands off to `/caspian` (PRD + issues) and `/zmcray-build` (per issue). The canonical sequence for a new product is **kickoff (wire the repo) > caspian (strategy: PRD + labeled issues) > build (per issue)**.

## Build workflow (tool-agnostic)

This section defines how any coding agent works an issue in this repo, whether it runs on Claude Code, Codex, Cursor, or another harness. It describes *roles* first, then names the commands that fill them. If your tool has the named command, use it. If it does not, perform the role's described work natively. The workflow is the contract; the commands are conveniences.

### Two routing signals

Every issue carries up to two labels that decide how it gets built:

- `flow:*` says *how much rigor*: `flow:design`, `flow:standard`, or `flow:ship`.
- `prd-source` says *whether strategy thinking already happened* (the issue came from a Caspian PRD). If present, skip the Think phase: the strategy council already ran.

Classify by blast radius, not effort:

- `flow:design` ... new surface area, architecture, auth/data/payments, anything hard to reverse.
- `flow:standard` ... a meaty feature in known territory.
- `flow:ship` ... small, reversible, well-specced (copy change, config tweak, contained bug fix).

If an issue is unlabeled, triage it in ~30 seconds, apply the label in Linear, state the call in one line, and proceed.

### The four phases

| Phase | Role | Command implementation (use if available) | Native fallback (any tool) |
|---|---|---|---|
| **Think** | Founder/strategy lens: is this the right problem, framed the right way? | gstack `/office-hours` then `/plan-ceo-review`; or Compound Engineering `/ce-brainstorm` / `/ce-ideate` | Write a short design doc answering: problem, who it is for, the 10x version, what we are deliberately not doing. |
| **Plan** | Turn the issue (and PRD, if present) into a concrete, reviewed plan | CE `/ce-plan` (its persona council gates the plan: feasibility, design, product, scope, security) | Write `docs/plans/plan-[date]-[slug].md` with the metadata header below; self-review it against feasibility, scope, and security before writing code. |
| **Execute** | Implement through to an open PR with CI green | CE `/lfg` (plan gate > work > plan-aware multi-persona code review > apply fixes + commit > file residuals to Linear > browser test > commit/push/PR > CI watch, max 3 fix attempts) | Implement on a branch, write tests, run the review yourself or via `/ce-code-review`, commit, push, open the PR, watch CI to green, and file any unfixed findings to Linear as issues. |
| **Learn** | Capture what worked and what the plan missed so the next build is easier | CE `/ce-compound` | Append a short "what worked / what the plan missed / new pattern" note to this repo's learnings (CLAUDE.md `## Compound Learnings` or a `LEARNINGS.md`). |

### Flow routing

| | has `prd-source` (Caspian-born) | no PRD (buildnote / ad hoc) |
|---|---|---|
| **flow:design** | Plan (+ architecture pass) > Execute > Learn | Think > Plan (+ architecture pass) > Execute > Learn |
| **flow:standard** | Plan > Execute > Learn | Plan > Execute > Learn |
| **flow:ship** | Execute (the plan gate is the only planning) | Execute |

The **architecture pass** on `flow:design` only: gstack `/plan-eng-review` on the approved plan, or a native dedicated review of system design, data model, and failure modes. This is the one place a deeper architecture review still earns its cost; CE's plan council covers the rest.

### Effort (reasoning budget)

A separate axis from flow. Flow decides *which* phases run; effort decides *how hard the model reasons* while running them. They are orthogonal: a `flow:ship` fix can be reasoning-trivial, and a `flow:design` feature can be mostly boilerplate or a genuinely hard problem.

Effort is an ordered dial, lowest to highest:

`low` ... `medium` ... `high` ... `extra` ... `max` ... `ultracode`

Apply the chosen level with your tool's reasoning-effort control (on Claude Code, the `/effort` setting). These level names are owned by the tool and change over time, so use whatever your tool currently exposes and map by intent to the nearest step it offers. Do not hard-code a tool's effort syntax into a plan or an issue.

Pick the level by *reasoning difficulty*, not blast radius (blast radius is flow's job). Step up as these rise:

- *novelty* ... solved this shape of problem before, or net-new?
- *ambiguity* ... one obvious approach, or several plausible ones / multiple possible root causes?
- *subtlety* ... algorithmic, concurrency, security, or correctness traps?
- *simultaneity* ... how much must be held in mind at once to get it right (not files touched)?

`low` for mechanical, well-trodden work; `high` is the sensible default for real but familiar reasoning; `max`/`ultracode` for novel, subtle, or high-stakes problems where deeper reasoning earns its cost.

Set effort at pull-down, against the actual task, and re-tune per phase. Unlike flow, effort is not fixed for an issue... planning a hard design may warrant `max` while its implementation runs at `medium`. Set it at the start of the Plan phase and again at the start of Execute.

Out of scope here: parallel orchestration / auto-workflows and run-persistence (`/goal`) are separate axes, not governed by this dial.

### Discipline that holds on every flow

- **Branch:** use the Linear `gitBranchName` if the issue has one, else `feat/[short-slug]`. Never work on `main`.
- **Test-first (design + standard):** write the failing test before the implementation for each unit of work.
- **Commits:** conventional commits with the issue ID appended, e.g. `feat: implement upload flow [MCR-123]`, so Linear auto-links. Commit on the branch and leave the working tree clean before picking up the next issue.
- **Scope is the PRD (kick-back rule):** if the issue carries `prd-source` and the work wants scope beyond what the PRD defines, do not expand scope here. Post a Linear comment ("Scope exceeds PRD: [reason]. Kicking back for Caspian EXPAND."), move the issue to Backlog, and stop. Strategy changes go through Caspian, not the build loop.
- **Escalate up only (escalation rule):** if work reveals a bigger blast radius than the label implies (auth, data migration, new architecture), escalate to the higher flow, update the label, and post a one-line Linear comment explaining why. Never de-escalate mid-build.
- **Residuals go to Linear:** any review finding you do not fix becomes a Linear issue on the Mcraygroup team, severity mapped to priority. Do not weaken, skip, or mock a failing assertion to get CI green.

### Plan file convention (design + standard)

Plans live in `docs/plans/plan-[YYYY-MM-DD]-[short-slug].md` (archive completed plans to `docs/plans/archive/`) with this header so the execute phase and any wrap step can find them:

```
---
Created: [timestamp]
Flow: [design|standard|ship]
Linear Project: [name or "none"]
Linear Issue: [ID or "none"]
Linear Branch: [gitBranchName or "none"]
Task: [one-line description]
---
```

### Session close

When the build session ends: move the Linear issue to **In Review** (or **Done** if shipped, or leave **In Progress** if paused), post a session-summary comment (what shipped, PR + CI status, commit count, tests, residuals filed, loose ends), archive the plan with an `## Outcome` note, and run the Learn phase for design/standard flows. Never auto-merge the PR; merging is the human's call.

### Claude Code accelerators

On Claude Code, `/zmcray-build` and `/zmcray-wrap` run this exact workflow as a guided loop (flow routing, the phase sequence, Linear sync). They are conveniences layered on top of this file, not a separate process. Any other harness reads this section and runs the same workflow directly.

<!-- END CANONICAL WORKFLOW -->
