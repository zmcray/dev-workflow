<!-- Moved from the canonical AGENTS.md block (MCR-2720). Read on demand; binding when it applies. -->

# Build workflow (tool-agnostic)

This section defines how any coding agent works an issue in this repo, whether it runs on Claude Code, Codex, Cursor, or another harness. It describes *roles* first, then names the commands that fill them. If your tool has the named command, use it. If it does not, perform the role's described work natively. The workflow is the contract; the commands are conveniences.

## Two routing signals

Every issue carries up to two labels that decide how it gets built:

- `flow:*` says *how much rigor*: `flow:design`, `flow:standard`, or `flow:ship`.
- `prd-source` says *whether strategy thinking already happened* (the issue came from a Caspian PRD). If present, skip the Think phase: the strategy council already ran.

Classify by blast radius, not effort:

- `flow:design` ... new surface area, architecture, auth/data/payments, anything hard to reverse.
- `flow:standard` ... a meaty feature in known territory.
- `flow:ship` ... small, reversible, well-specced (copy change, config tweak, contained bug fix).

If an issue is unlabeled, triage it in ~30 seconds, apply the label in Linear, state the call in one line, and proceed.

## The four phases

| Phase | Role | Command implementation (use if available) | Native fallback (any tool) |
|---|---|---|---|
| **Think** | Founder/strategy lens: is this the right problem, framed the right way? | gstack `/office-hours` then `/plan-ceo-review`; or Compound Engineering `/ce-brainstorm` / `/ce-ideate` | Write a short design doc answering: problem, who it is for, the 10x version, what we are deliberately not doing. |
| **Plan** | Turn the issue (and PRD, if present) into a concrete, reviewed plan; consult the research corpus and record the research decision | CE `/ce-plan` (on `flow:design` its persona council gates the plan; on `flow:standard` skip the council and self-review, see Review depth) | Read `docs/research/INDEX.md`, write `docs/plans/[slug]-[date].md` (date at the end, never the beginning) with the metadata header below, include a Research decision (`reuse`, `extend`, or `none needed`), and self-review it against feasibility, scope, and security before writing code. |
| **Execute** | Implement through to a merged PR (CI green, then merge-on-green — see Discipline) | CE `/lfg` (plan gate > work > code review at the depth set in Review depth > apply fixes + commit > file residuals to Linear > browser test > commit/push/PR > CI watch, max 3 fix attempts), then the merge-on-green rule | Implement on a branch, write tests, run the review yourself or via `/ce-code-review`, commit, push, open the PR, watch CI to green, file any unfixed findings to Linear as issues, then merge per the merge-on-green rule. Delegate the CI watch, Actions log reduction, and per-file review passes to cheap/mid-tier subagents per Delegation; keep failure diagnosis and the merge call in the main thread. |
| **Learn** | Capture what worked and what the plan missed so the next build is easier | CE `/ce-compound` | Append a short "what worked / what the plan missed / new pattern" note to this repo's learnings (CLAUDE.md `## Compound Learnings` or a `LEARNINGS.md`). |

## Flow routing

| | has `prd-source` (Caspian-born) | no PRD (buildnote / ad hoc) |
|---|---|---|
| **flow:design** | Plan (+ architecture pass) > Execute > Learn | Think > Plan (+ architecture pass) > Execute > Learn |
| **flow:standard** | Plan > Execute > Learn | Plan > Execute > Learn |
| **flow:ship** | Execute (the plan gate is the only planning) | Execute |

## Review depth (pre-users rule, set 2026-09-04)

Review ceremony is sized to blast radius, not to habit. Until the product has retained users, the bottleneck is learning, not defects; CI already catches most of what the councils catch.

| Flow | Plan review | Code review | Wrap |
|---|---|---|---|
| `flow:design` | Full CE plan council + architecture pass | Full multi-persona council (`/ce-code-review`), all findings adjudicated | Full wrap: Linear sync, archive plan with Outcome, Learn |
| `flow:standard` | Self-review only (feasibility, scope, security, in the plan file); no persona council | **One pass**: the always-on personas only (correctness, testing, maintainability, project standards), delegated per Delegation; fix P0/P1 on-branch, file the rest to Linear without a second round | Linear sync + archive plan; Learn entry only if something non-obvious was found |
| `flow:ship` | None | One always-on pass, or none when the diff is under ~50 lines and CI is green | Linear sync only |

**Escalation stays mandatory.** Any diff on `flow:standard` or `flow:ship` that touches auth, sessions, tokens, RLS or grants, migrations, deletion or export, payments, or outbound fetch gets the full `flow:design` review regardless of label (see the escalation rule under Discipline below). Reviewers do not add persona passes on suspicion; they escalate the flow label and say why in Linear.

**No review-of-the-review.** One fix commit after the pass, then push. Do not re-run the council to validate fixes; CI and the merged-app check are the gate.

The **architecture pass** on `flow:design` only: gstack `/plan-eng-review` on the approved plan, or a native dedicated review of system design, data model, and failure modes. This is the one place a deeper architecture review still earns its cost; CE's plan council covers the rest.

## Effort (reasoning budget)

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

Out of scope here: parallel orchestration and run-persistence are separate axes, not governed by this dial (see `goal-runs.md`).


## Discipline that holds on every flow


- **Branch from a fresh base:** before creating the feature branch, check out the default branch and pull it from origin — never branch from a stale local HEAD or a leftover feature branch (that is where PR merge conflicts come from). Then use the Linear `gitBranchName` if the issue has one, else `feat/[short-slug]`. Never work on `main`.

- **Merge on green (auto-merge):** when CI is green, merge the PR (squash for a single-chunk PR, rebase for a group PR; see Landing), pull the default branch, and post a "PR merged" comment to each chunk's Linear issue. Never merge a red or blocked PR. Multi-issue runs are strictly sequential: merge landing group (or lone chunk) N before branching N+1; if a PR cannot merge, stop the run there — do not skip ahead. Opt out per-repo with `"automerge": false` in `.linear-project.json`. (PR review is not a gate in this workflow; quality gates are CI plus reviewing the live app after merge.)
- **Test-first (design + standard):** write the failing test before the implementation for each unit of work.
- **Commits:** conventional commits with the issue ID appended, e.g. `feat: implement upload flow [MCR-123]`, so Linear auto-links. One commit per chunk, even inside a group PR. Commit on the branch and leave the working tree clean before picking up the next chunk. **Planning and docs PRs name no issue ID:** Linear links a PR to every issue its branch, title, commit subjects or body names, and moves each one to In Progress when the PR opens. A plan, brief, ledger, wizard or other docs PR names no issue ID anywhere (branch `docs/circuit-player-plan`, never `docs/mcr-123-...`; nor title, commit subjects or body). After opening it, comment the PR URL on each related Linear issue. **Never write a contributing word before an issue ID** (`Part of`, `ref`, `related to`, `towards`, `updates`, `contributes to`) in any PR: Linear starts the issue on open and then never closes it on merge, even when the branch and title also carry the ID.
- **Scope is the PRD (kick-back rule):** if the issue carries `prd-source` and the work wants scope beyond what the PRD defines, do not expand scope here. Post a Linear comment ("Scope exceeds PRD: [reason]. Kicking back for Caspian EXPAND."), move the issue to Backlog, and stop. Strategy changes go through Caspian, not the build loop.
- **Escalate up only (escalation rule):** if work reveals a bigger blast radius than the label implies (auth, data migration, new architecture), escalate to the higher flow, update the label, and post a one-line Linear comment explaining why. Never de-escalate mid-build.
- **Residuals go to Linear:** any review finding you do not fix becomes a Linear issue on the Mcraygroup team, severity mapped to priority. File it under the issue creation contract (`linear.md`): project, the `<Epic>: hardening` milestone, priority, and a `flow:*` label. Do not weaken, skip, or mock a failing assertion to get CI green.
- **Migrations reach prod separately from code:** deploying code does NOT apply database migrations. The auto-migration-to-prod path (`setup.md`) must already exist; when an issue adds a migration, confirm it actually reaches the prod DB — the code deploy won't carry it. Additive migrations (new columns/tables) deploy safely alongside the code; for a destructive/renaming one, apply the migration first, confirm, then ship the code.



## Plan file convention (design + standard)

Plans live in `docs/plans/[short-description]-YYYY-MM-DD.md` (date at the end, never the beginning; if that name is taken, add a counter before the date, `[short-description]-2-YYYY-MM-DD.md`; archive completed plans to `docs/plans/archive/`) with this header so the execute phase and any wrap step can find them:

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

Every design or standard plan also includes:

```markdown
## Research decision

- Decision: [reuse | extend | none needed]
- Evidence: [linked topic claim IDs, or why no corpus evidence is required]
- Additional research: [specific gap and method, or none]
```

`extend` is reserved for a gap that could materially change the plan. Add resulting evidence to `docs/research/` before the issue closes.

## Session close

When the build session ends: move the Linear issue to **In Review** (or **Done** if shipped, or leave **In Progress** if paused), post a session-summary comment (what shipped, PR + CI status, commit count, tests, residuals filed, loose ends), archive the plan with an `## Outcome` note, and run the Learn phase for design/standard flows. Then post the project status update and print the hygiene check counts (`linear.md`). By session close the PR should already be merged via the merge-on-green rule (Discipline above); if auto-merge was skipped or blocked, flag the unmerged PR as a loose end rather than merging during close.

## Claude Code accelerators

On Claude Code the workflow runs on Compound Engineering plus two conveniences: `/ce-plan` (Plan), `/lfg` (Execute, one issue through a green PR), `/ce-code-review`, `/ce-compound` (Learn), `/packets` (plan → labeled Linear chunks), the built-in `/goal` (hands-off run across issues), and `/factory` (the night shift: `/goal` over everything `spec-ready` in the repo until 6:00 AM or 12 hours, whichever comes first, with a run ledger in `docs/factory/runs/`). `/lfg` itself never touches Linear and never merges... the rules in AGENTS.md and `~/Developer/dev-workflow/rules/` do that: after `/lfg` reports a green PR, apply merge-on-green, post the Linear comment, and run session close. These commands are conveniences layered on these rules, not a separate process. Any other harness reads this file and runs the same workflow directly.
