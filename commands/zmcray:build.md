---
name: zmcray:build
description: Run the flow-routed build loop. Reads the issue's flow label, runs the right pre-work, then hands off to /lfg for execution through PR. Auto-pulls highest-priority Linear issue when no arg given.
argument-hint: "[Linear issue ID like MCR-123, or free-text task description]"
---

# Build

Execute the McRay Build Loop. Resolves the Linear project, picks up work from Linear (or argument), routes by the issue's `flow:*` label, runs the flow's pre-work, then hands off to `/lfg` (Compound Engineering's gated pipeline: work > plan-aware review > test > commit > push > PR > CI watch).

**Interactive contract: after every pre-work step, print the next step and ask "Ready to proceed?" Do not silently advance. The contract ends at the /lfg handoff... /lfg runs unattended through PR by design.**

## Step 1: Resolve Linear Project (For This Repo)

The repo's Linear link lives *in the repo*, in `.linear-project.json` at the repo root: `{ "id": "...", "slug": "...", "name": "...", "team": "MCR" }`. Resolve in order:

### 1A: Local link file
Read `./.linear-project.json`. If present with an `id`, use it. Skip to Step 2.

### 1B: Resolve and write (no link file)
Query Linear projects on the `Mcraygroup` team. Match this repo by, in order: (a) a project whose `Local Path` is `~/Developer/[repo-folder-name]`; (b) a project whose name matches the repo folder name (normalize: lowercase, drop spaces and hyphens). On a unique match, write `./.linear-project.json` and skip to Step 2.

### 1C: Ambiguous or no match
If several projects match or none do, ask: link to an existing project (search by name), create a new one, or skip. Once resolved, write `./.linear-project.json` so future sessions read it directly.

### 1D: No linkage
If the user skips, this repo is not Linear-linked. Build still runs via free-text arguments (Path D below) but auto-pull and Linear sync won't fire. Inform the user once.

## Step 2: Determine Task Source

Resolve what to build using the first matching path:

### Path A: Argument is a Linear issue ID

If the argument matches the pattern `[A-Z]{2,4}-\d+` (e.g., `MCR-123`):

1. Pull the issue from Linear via the Linear MCP: title, description, priority, state, **labels**, comments, `gitBranchName`, attachments.
2. Print: **"Pulled [ID] [title] (Priority: [X], State: [state], Flow: [flow label or 'unlabeled']). Ready to build?"**
3. Capture the issue ID and labels for downstream steps.
4. Continue to Step 3.

### Path B: No argument, active plan exists

If the argument is empty AND `docs/plans/` has an active plan file (not in archive/):

1. Read the plan. Extract the `Linear Issue:` field from its metadata header (if present).
2. If a Linear issue ID is present, fetch the issue's current state and labels from Linear (it may have changed since the plan was written).
3. Confirm: **"Found plan: [description]. Linear issue: [ID or 'none']. Building from this?"**
4. Continue to Step 3 once confirmed.

### Path C: No argument, no active plan, repo is Linear-linked

If the argument is empty AND no active plan exists AND Step 1 resolved a Linear project:

1. Pull active issues from that Linear project via the MCP (state type != Done/Cancelled, sorted by priority Urgent > High > Normal > Low, then by updatedAt desc).
2. Take the top result. Print: **"Highest-priority active issue: [ID] [title] (Priority: [X], Flow: [label]). Auto-building. Override with `/zmcray:build [different-id]` if wrong."**
3. Wait 2 seconds for an interrupt. If none, capture the issue ID and labels and proceed.
4. Continue to Step 3.

### Path D: Free-text argument

If the argument is free text (not a Linear ID pattern):

1. Use the argument verbatim as the task description.
2. No Linear issue is captured. Linear sync at wrap time will be skipped.
3. Continue to Step 3 (flow resolution falls to the triage rule or user statement).

### Path E: Nothing to build

If no argument AND no active plan AND repo is not Linear-linked, stop and tell the user: "No task source. Provide an argument, run `/zmcray:kickoff` to link Linear, or create a plan first."

## Step 3: Resolve Flow

Two orthogonal signals on the issue decide the route. The `flow:*` label says how much rigor. The `prd-source` label says whether strategy thinking already happened (in Caspian).

1. **Labeled:** use the issue's `flow:design`, `flow:standard`, or `flow:ship` label.
2. **User override:** if the user said "this is a [flow] task" in their message, use that for THIS task only.
3. **Unlabeled with a Linear issue:** run a 30-second triage. Classify by blast radius, not effort:
   - New surface area, architecture, auth/data/payments, hard to reverse → `flow:design`
   - Meaty feature in known territory → `flow:standard`
   - Small, reversible, well-specced → `flow:ship`
   Apply the chosen label to the issue via the MCP, state the call in one line, and proceed.
4. **No Linear issue (free text):** triage the same way; if genuinely ambiguous, ask once.
5. **Legacy fallback:** if triage is unclear and CLAUDE.md has a `## Build Tier` section, map Tier 1 → `flow:design`, Tier 2 → `flow:standard`, Tier 3 → `flow:ship`.

**Escalation rule:** if at any later point the work reveals a bigger blast radius than the label implies (touches auth, data migrations, new architecture), escalate to the higher flow, update the label, and post a one-line Linear comment explaining why. Never de-escalate mid-build.

**PRD kick-back rule:** if the issue carries `prd-source` and the work wants scope beyond what the PRD defines, do NOT expand scope here. Post a Linear comment ("Scope exceeds PRD: [reason]. Kicking back for /caspian EXPAND."), move the issue back to Backlog, and stop. Strategy changes go through Caspian, not the build loop.

## Step 4: Pre-Work (By Flow)

**Set effort first.** Assess the planning work against the AGENTS.md Effort rubric (reasoning difficulty, not blast radius) and set your tool's effort control before planning. Effort is orthogonal to flow and re-tuned per phase.

If you arrived via Path B with an approved active plan, skip to Step 5.

For `prd-source` issues, the PRD is the planning input: read it via the path in the issue description, or pull the project's Linear document if the local path is unavailable. The Cagan risk block and acceptance criteria in the issue body carry the per-feature contract.

### flow:design
1. **Think (skip entirely if the issue has `prd-source`... Caspian already ran the strategy council):** `/office-hours` to produce the design doc, then `/plan-ceo-review` against it.
2. **Plan:** `/ce-plan` with the issue (and PRD, if prd-source) as input. Its persona doc-review council (feasibility, design-lens, product-lens, scope-guardian, security-lens) gates the plan.
3. **Architecture pass:** `/plan-eng-review` on the approved plan. This is the one place the dedicated eng-manager review still runs.

### flow:standard
1. **Plan:** `/ce-plan` with the issue (and PRD, if prd-source) as input. The persona council is the only review gate... no separate eng review.

### flow:ship
No pre-work. `/lfg`'s built-in plan gate (a written plan file must exist in `docs/plans/` before work proceeds) is the only planning. Skip to Step 5.

After each pre-work skill completes, print: **"[Skill] complete. Next step: [next]. Ready?"** Wait for confirmation.

**Plan file convention (design + standard):** ensure the plan lands in `docs/plans/plan-[YYYY-MM-DD]-[short-description].md` (create `docs/plans/archive/` if missing) with this metadata header, so /lfg's gate and /zmcray:wrap can find it:

```
---
Created: [timestamp]
Flow: [design|standard|ship]
Linear Project: [name from Step 1, or "none"]
Linear Issue: [ID from Step 2, or "none"]
Linear Branch: [gitBranchName from Linear, or "none"]
Task: [one-line description]
---
```

## Step 5: Branch, Baseline, Linear Sync

1. Create the feature branch:
   - If a Linear `gitBranchName` was captured, use it: `git checkout -b [gitBranchName]`
   - Otherwise: `git checkout -b feat/[short-description]`
2. Run existing tests. Confirm green baseline. If tests fail, stop and surface failures before proceeding.
3. **If a Linear issue is linked**, update Linear:
   - Move the issue state to **In Progress**.
   - Post a comment: `Build session started. Branch: [branch-name]. Flow: [flow]. Plan: [plan-filename or "/lfg plan gate"].`
4. Update PROJECT.md (slim format): one-line Current Status + a Build Log row (date, "Build session started", plan filename, issue ID). If PROJECT.md doesn't exist, stop and tell the user to run `/zmcray:kickoff` first.
5. Print: **"Branch created, baseline green, Linear updated. Next step: hand off to /lfg (runs unattended through PR). Ready?"**

## Step 6: Execute via /lfg

**Re-assess effort.** Implementation effort can differ from planning (a hard design often plans at `max` but implements at `medium`, or vice versa). Re-assess against the AGENTS.md Effort rubric and set your tool's effort control before handing to /lfg.

This is the handoff. From here /lfg runs its gated pipeline without prompting: plan gate > work > plan-aware code review > apply fixes + commit > file unfixed findings to Linear > browser test > commit/push/PR > CI watch until green (max 3 fix attempts).

Invoke `/lfg` with a task statement that includes:

- The Linear issue ID and title (so commits get tagged and tracker-defer files residuals against the right project)
- The plan file path from Step 4 (design/standard), or the task description (ship... /lfg will write its own plan)
- **Commit convention:** conventional commits with `[ISSUE-ID]` appended, e.g. `feat: implement upload flow [MCR-123]`, so Linear auto-links
- **Test-first directive (design + standard only):** "Write the failing test before the implementation for each unit of work."
- **Constraint:** stay within the plan's scope; if the work wants more, stop and apply the kick-back rule from Step 3 instead of improvising

### Implementation rules /lfg inherits

- **Subagent isolation:** tasks touching 3+ files break into independent subtasks in fresh subagents, merged at the end.
- **Stay on the plan.** If something doesn't verify, surface it... don't route around it.

## Step 7: Post-/lfg Verification

When /lfg emits DONE (or exits with unresolved CI failures):

1. Confirm: PR exists, CI status, and whether residual findings were filed to Linear (check the PR body's residuals section).
2. If CI is red after /lfg's 3 attempts, surface the "CI Failures Unresolved" section to the user. Do not merge anything.
3. Post a Linear comment on the issue: `Build complete. PR: [link]. CI: [green/red]. Residuals filed: [N or none].`
4. Print: **"/lfg done. PR [link], CI [status]. Next: /zmcray:wrap to close the session (compound runs there for design/standard flows)."**

Merging the PR is the user's call, not the build loop's.

## Review Reference

See `30_Projects/00_Code/review-conventions.md` for the review strategy. Note: /lfg's plan-aware code review (persona council with confidence gating) replaces the old `/codex:review` step. Legacy commands (`/ultraplan`, `/codex:review`, `/codex:adversarial-review`) remain installed for manual use but are no longer part of this loop.

## Notes

- **Prompt between pre-work steps; never inside /lfg.** The interactive contract covers Steps 1-5. Step 6 is autonomous by design.
- The two routing signals are independent: `flow:*` = rigor, `prd-source` = strategy already done. A `flow:design` + `prd-source` issue skips Think but keeps the eng review.
- The plan file is the single source of truth from pre-work through wrap. /lfg's gate requires it to exist for design/standard; /lfg writes its own for ship.
- Linear updates during the session: In Progress + start comment (Step 5), /lfg residuals (Step 6), build-complete comment (Step 7). The full session summary lands at wrap.
- If Linear is unreachable when you try to update it, log the failure to the plan file's `## Linear Sync Errors` section and continue. Don't block the build on a network glitch.
- The Linear link lives in the repo's `.linear-project.json` (id + slug + name). If it's missing, Step 1B resolves it from Linear and writes it. The file travels with the repo, so the link can't go stale from a path change... no central cache.
- Compound Engineering v3 renamed commands to the `ce-` prefix (`/ce-plan`, `/lfg`, `/ce-compound`). If a command is missing, run `/ce-update` or reinstall the plugin before debugging this skill.
