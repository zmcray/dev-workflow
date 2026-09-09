<!-- BEGIN CANONICAL WORKFLOW (managed by deploy-agents-md.sh ... edit here, not in repos) -->

## Secrets

Never ask Zack to paste a secret into chat, a file, or a command line. When a new secret is needed (local `.env` and/or a GitHub repo secret), hand him one terminal command that prompts silently with `read -rs`, writes to every destination, and unsets the variable. Template (substitute NAME, the repo path, and owner/repo):

```bash
read -rs "KEY?Paste NAME: " && echo && printf '\nNAME=%s\n' "$KEY" >> <repo>/.env && printf '%s' "$KEY" | gh secret set NAME -R <owner/repo> && unset KEY && echo "Done"
```

Then verify by name only (`gh secret list`, `grep -c '^NAME=' .env`). Never print, log, or echo a secret value.

## Issue tracker

Linear (Mcraygroup team). File all deferred findings, residuals, and follow-ups there. The board is the audit trail: move issue status as work progresses, post plan and review summaries as comments, and link the PR. A reviewer should be able to follow the whole build without opening a terminal.

## Project setup (one-time)

A repo wired into this system is:

- A git repo with a private GitHub remote, kebab-case name matching the folder, living under `~/Developer` (never iCloud), with `node_modules`, `.next`, build output, and `.env*` gitignored.
- Linked to a Linear project, recorded in a `.linear-project.json` file at the repo root (id + slug + name). The link travels with the repo... no central cache.
- Carrying this `AGENTS.md` plus a `CLAUDE.md` that imports it (`@AGENTS.md`).
- Carrying a `CONTEXT.md` at the root: the project's domain glossary and nothing else (no implementation details). Hard-to-reverse, surprising trade-offs get an ADR in `docs/adr/`. Both are maintained inline by the `domain-modeling` skill during grilling; create them lazily, on the first resolved term or first real decision. Every spec, packet, plan, and issue uses `CONTEXT.md` vocabulary.
- Carrying a research corpus at `docs/research/` with `README.md`, `INDEX.md`, `topics/`, `sources/`, and reusable templates. Initialize this structure for every new project even when it begins empty; the index is the entry point for agents and humans.
- **If it uses a deployed database (e.g. Supabase): an automatic migration-to-prod path, wired BEFORE the first production deploy.** Deploying code never applies DB migrations — they are a separate ship — so without this, shipped code runs ahead of the prod schema and every page touching it 500s. Default (Supabase): the native **GitHub Integration** (dashboard → project → Integrations → GitHub) — OAuth, no stored secrets, applies migrations on merge to the production branch; set **Working directory** to the folder that *contains* `supabase/` (the repo root `.`, or a subdir like `app`/`atlas` if it's nested), **Deploy to production** ON → `main`, **Automatic branching** OFF (per-PR preview DBs are billable, uncapped). Fallback: a `supabase db push` GitHub Action gated on `main` with the project's access-token / project-ref / db-password as repo secrets. `/zmcray-kickoff` sets this up.

**iOS repos:** the App Store Connect API key lives at `~/.appstoreconnect/private_keys/` — the conventional location, so `xcodebuild`, `fastlane`, and `altool` find it by key ID without a configured path. The `README.md` beside it records the key ID, issuer ID, and the endpoints for answering "is this build on TestFlight" and "did Xcode Cloud actually trigger". Read that file rather than hunting for credentials; never copy the `.p8` into a repo. Note that Xcode Cloud config lives in App Store Connect, not in the repo, so a TestFlight pipeline can be fully wired while nothing in `.github/workflows/` mentions it — check for an `xcode-cloud` check run on a recent commit before concluding a repo has no release automation.

Plans live in `docs/plans/` (archive completed ones in `docs/plans/archive/`); checkpoints live in `docs/checkpoints/`. Flow is never set at the repo level: it is a per-issue property (see below). On Claude Code, `/zmcray-kickoff` performs this setup once, then hands off to `/caspian` (PRD + issues) and `/zmcray-build` (per issue). The canonical sequence for a new product is **kickoff (wire the repo) > caspian (strategy: PRD + labeled issues) > build (per issue)**.

## Research corpus

Every project keeps reusable research in `docs/research/`. The corpus is the evidence layer, separate from strategy and delivery documents:

```text
docs/research/
├── README.md          # Corpus rules, evidence vocabulary, contribution workflow
├── INDEX.md           # Searchable map of topics, coverage, and open gaps
├── topics/            # Cross-source syntheses with stable claim IDs
├── sources/           # One evidence card per paper, dataset, or first-party source
└── templates/         # Required topic and source-card shapes
```

- **Sources record evidence.** Capture the method, population, exact findings, limitations, durable link, and which claim IDs the source supports. Label telemetry, experiments, surveys, qualitative work, literature reviews, first-party product statements, and vendor research distinctly.
- **Topics synthesize evidence.** State bounded findings with stable claim IDs, confidence, scope, disagreement, product implications, what the evidence does not prove, and explicit triggers for further research.
- **The index routes discovery.** Keep topic status, last-review dates, coverage, source inventory, and gaps current so an agent can find relevant work without rereading the repository.
- **PRDs and plans make decisions.** They cite topic claim IDs rather than duplicating research prose. Decision documents may interpret the evidence, but must distinguish findings from assumptions and product judgment.
- **Research is cumulative.** Before commissioning more, search the corpus and reuse what applies. Extend it only when a load-bearing claim is unknown, conflicting, materially stale, or outside the studied population/context. If the remaining question is product-specific, prefer an instrumented test with success and kill conditions.
- **New evidence returns to the corpus.** Add or update source cards, topic synthesis, and index coverage before closing research-bearing work. Do not store participant personal data, credentials, paywalled copies, or copyrighted full texts.

Every Think or Plan phase that depends on user, market, workflow, or behavioral claims begins by reading `docs/research/INDEX.md`. The resulting design doc or plan includes a short **Research decision**: `reuse`, `extend`, or `none needed`, with linked claim IDs and any additional research required. Absence of relevant corpus evidence is a signal to evaluate the gap, not an automatic mandate to research.

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
| **Plan** | Turn the issue (and PRD, if present) into a concrete, reviewed plan; consult the research corpus and record the research decision | CE `/ce-plan` (its persona council gates the plan: feasibility, design, product, scope, security) | Read `docs/research/INDEX.md`, write `docs/plans/plan-[date]-[slug].md` with the metadata header below, include a Research decision (`reuse`, `extend`, or `none needed`), and self-review it against feasibility, scope, and security before writing code. |
| **Execute** | Implement through to a merged PR (CI green, then merge-on-green — see Discipline) | CE `/lfg` (plan gate > work > plan-aware multi-persona code review > apply fixes + commit > file residuals to Linear > browser test > commit/push/PR > CI watch, max 3 fix attempts), then the merge-on-green rule | Implement on a branch, write tests, run the review yourself or via `/ce-code-review`, commit, push, open the PR, watch CI to green, file any unfixed findings to Linear as issues, then merge per the merge-on-green rule. Delegate the CI watch, Actions log reduction, and per-file review passes to cheap/mid-tier subagents per Delegation; keep failure diagnosis and the merge call in the main thread. |
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

Out of scope here: parallel orchestration and run-persistence are separate axes, not governed by this dial (see Autonomous runs below).

### Delegation (subagents and model tiers)

A third axis, orthogonal to flow and effort. Flow decides which phases run, effort decides how hard the model reasons, delegation decides *who does each piece and at what cost*.

**The tier assessment is mandatory, not optional.** Before starting any step that runs more than a couple of tool calls, assess whether a lower-tier subagent can do it and state the call in one line: **"Delegating [work] → [tier] ([why])"**, or **"Main thread: [work] ([why it needs judgment])"**. The default answer is delegate-and-downshift. Work stays in the main thread on the frontier model only when it genuinely requires judgment; "it's faster to just do it here" is not a reason. Main-thread context is the scarcest resource in a run... spend it on decisions and synthesis, never on file dumps, log tails, or status polling.

When model selection is exposed, tier by work type — **mechanical → cheapest tier, moderate synthesis → mid tier, judgment → frontier tier**:

| Work | Tier | Claude Code model |
|---|---|---|
| Repo exploration, multi-file reads, existing-pattern discovery, dependency audits, mechanical transcription (issue spec → plan file), TODO/FIXME scans, PROJECT.md / Build Log edits, Linear comment formatting, duplicate-issue checks | mechanical | `haiku` |
| **GitHub and CI work** (see the rule below) | mechanical, mid if logs need real interpretation | `haiku` → `sonnet` |
| Per-file review passes, test-suite triage, implementation slices against a settled spec, drafting a spec from decisions already made, summarizing what a mechanical pass found | moderate synthesis | `sonnet` |
| Flow triage, effort setting, plan approval, architecture calls, scope and taste judgment, root-causing a CI failure, the merge decision, anything the human will be asked to decide | judgment | frontier (main thread) |

**GitHub / CI operations run on the cheapest tier that can do them.** Delegate to `haiku` (escalating to `sonnet` only when output needs real interpretation): CI watch and check-status polling, fetching and reducing Actions run logs to the failing lines, PR body assembly, authoring or editing Actions workflow YAML, and label / secret / branch plumbing across multiple items. The main thread receives the *reduced* result — the failing test name and error, not the log. Deciding what a failure means and whether to merge stays frontier. Exception: a single one-shot `gh` call (one `gh pr view`, one `gh pr merge`) stays inline — a subagent round-trip costs more than the call. The rule targets anything that loops, polls, or returns bulk output.

Tier names are owned by the tool and change over time... map by intent to what your harness currently offers (Claude Code today: `haiku` / `sonnet` / `opus` on the subagent `model` param; Codex and Cursor: default unless exposed). Do not hard-code a tier name into a plan or an issue. If subagents are unavailable, do the work in the main thread and say so once.

**Escalate on failure, not on suspicion.** Start a delegated subtask at the lowest plausible tier. If the result comes back incomplete, low-confidence, or wrong, re-run it one tier up rather than absorbing it into the main thread. Two failed tiers on the same subtask means the work needed judgment all along... pull it back and reclassify. Never pre-emptively route to frontier because a cheaper tier *might* struggle.

**Fan out in parallel.** Independent delegated subtasks are dispatched in a single message with multiple subagent calls, never one at a time.

**Parallel tool calls:** when making multiple tool calls with no dependencies between them (independent file reads, searches, status checks), issue them in parallel rather than sequentially, using whatever batching mechanism your harness provides (e.g. Codex's `multi_tool_use.parallel`; Claude Code batches independent calls in one turn natively). Sequence calls only when a later call needs an earlier call's result.

### Autonomous runs (goal mode)

A fourth axis: does the run pause for the human? Default is interactive (confirm between pre-work steps). In **goal mode** the human sets an objective spanning one or more issues and the agent runs to completion without prompting: every would-be question becomes a stated one-line judgment call, logged to the relevant Linear issue so decisions stay auditable. Planning, flow/effort decisions, and architecture calls stay in the main thread; execution subtasks are delegated per the Delegation section above. Goal runs work issues strictly sequentially under the merge-on-green rule and end only when the objective is met or a hard stop fires: an unmergeable PR, red baseline, the kick-back rule, or anything destructive the plan doesn't cover — never skip past a stuck issue. On Claude Code this is `/goal [objective]` (which drives `/zmcray-build` in its autonomous mode); on other harnesses, apply this contract natively when the user asks for a hands-off run.

### Discipline that holds on every flow

- **Branch from a fresh base:** before creating the feature branch, check out the default branch and pull it from origin — never branch from a stale local HEAD or a leftover feature branch (that is where PR merge conflicts come from). Then use the Linear `gitBranchName` if the issue has one, else `feat/[short-slug]`. Never work on `main`.
- **CI cost discipline:** green CI is required; cost control removes redundant execution, never required coverage. When creating or changing `.github/workflows/**`, first classify repository visibility and runner class (public repositories on standard GitHub-hosted runners have different compute economics than private repositories; storage and artifacts still matter). Every applicable workflow uses `concurrency` keyed by workflow and ref with `cancel-in-progress: true`. In private repos, use safe docs-only/path-scoped triggers, keep fast required PR checks separate from expensive merge/manual suites, and consolidate tiny jobs when isolation is not valuable because billed time rounds per job. Before path-filtering a workflow, verify its check is not a required branch-protection check that would remain pending when skipped. Upload diagnostics on failure rather than every success, avoid uploads after cancellation, default retention to 1–3 days, and explicitly justify artifacts likely to exceed 50 MB. Scheduled or external-service workflows must preflight required secrets/configuration and remain disabled until configured. Run focused tests locally before pushing, batch coherent fixes, and do not rerun an unchanged failure unless evidence points to transient infrastructure.
- **Merge on green (auto-merge):** when CI is green, squash-merge the PR (`gh pr merge --squash --delete-branch`), pull the default branch, and post a "PR merged" comment to the Linear issue. Never merge a red or blocked PR. Multi-issue runs are strictly sequential: merge issue N before branching issue N+1; if a PR cannot merge, stop the run there — do not skip ahead. Opt out per-repo with `"automerge": false` in `.linear-project.json`. (PR review is not a gate in this workflow; quality gates are CI plus reviewing the live app after merge.)
- **Test-first (design + standard):** write the failing test before the implementation for each unit of work.
- **Commits:** conventional commits with the issue ID appended, e.g. `feat: implement upload flow [MCR-123]`, so Linear auto-links. Commit on the branch and leave the working tree clean before picking up the next issue.
- **Scope is the PRD (kick-back rule):** if the issue carries `prd-source` and the work wants scope beyond what the PRD defines, do not expand scope here. Post a Linear comment ("Scope exceeds PRD: [reason]. Kicking back for Caspian EXPAND."), move the issue to Backlog, and stop. Strategy changes go through Caspian, not the build loop.
- **Escalate up only (escalation rule):** if work reveals a bigger blast radius than the label implies (auth, data migration, new architecture), escalate to the higher flow, update the label, and post a one-line Linear comment explaining why. Never de-escalate mid-build.
- **Residuals go to Linear:** any review finding you do not fix becomes a Linear issue on the Mcraygroup team, severity mapped to priority. Do not weaken, skip, or mock a failing assertion to get CI green.
- **Migrations reach prod separately from code:** deploying code does NOT apply database migrations. The auto-migration-to-prod path (Project setup) must already exist; when an issue adds a migration, confirm it actually reaches the prod DB — the code deploy won't carry it. Additive migrations (new columns/tables) deploy safely alongside the code; for a destructive/renaming one, apply the migration first, confirm, then ship the code.

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

Every design or standard plan also includes:

```markdown
## Research decision

- Decision: [reuse | extend | none needed]
- Evidence: [linked topic claim IDs, or why no corpus evidence is required]
- Additional research: [specific gap and method, or none]
```

`extend` is reserved for a gap that could materially change the plan. Add resulting evidence to `docs/research/` before the issue closes.

### Session close

When the build session ends: move the Linear issue to **In Review** (or **Done** if shipped, or leave **In Progress** if paused), post a session-summary comment (what shipped, PR + CI status, commit count, tests, residuals filed, loose ends), archive the plan with an `## Outcome` note, and run the Learn phase for design/standard flows. By session close the PR should already be merged via the merge-on-green rule above; if auto-merge was skipped or blocked, flag the unmerged PR as a loose end rather than merging during close.

### Claude Code accelerators

On Claude Code, `/zmcray-build` and `/zmcray-wrap` run this exact workflow as a guided loop (flow routing, the phase sequence, Linear sync). They are conveniences layered on top of this file, not a separate process. Any other harness reads this section and runs the same workflow directly.

### shadcn registries

Every shadcn-initialized app registers the namespaced registries from `templates/components.registries.json` in the dev-workflow repo... merge the `registries` key into the app's `components.json`, never overwrite existing keys, and keep the literal `{name}` placeholder intact. Current registries: `@bklit` (https://bklit.com/r/{name}.json) and `@kokonutui` (https://kokonutui.com/r/{name}.json). On installing any component from these registries, restyle it to McRay Group brand tokens (`colors_and_type.css` semantic vars) before first use; no raw registry styling ships.

<!-- END CANONICAL WORKFLOW -->
