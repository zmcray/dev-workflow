---
name: zmcray-build
description: Run the flow-routed build loop. Reads the issue's flow label, runs the right pre-work, then hands off to /lfg for execution through PR, merges on green, and auto-wraps (code review + fix, compound, Linear sync). Auto-pulls highest-priority Linear issue when no arg given.
argument-hint: "[Linear issue ID like MCR-123, an app name in a monorepo (e.g. radar), or free-text task description]"
---

# Build

Execute the McRay Build Loop. Resolves the Linear project, picks up work from Linear (or argument), routes by the issue's `flow:*` label, runs the flow's pre-work, then hands off to `/lfg` (Compound Engineering's gated pipeline: work > plan-aware review > test > commit > push > PR > CI watch).

**Interactive contract: after every pre-work step, print the next step and ask "Ready to proceed?" Do not silently advance. The contract ends at the /lfg handoff... /lfg runs unattended through PR by design.**

## Autonomous Mode

Autonomous mode is ON when any of these hold: this skill was invoked by `/goal`; the argument contains `--auto`; or the user said to run without input ("don't ask me", "use your judgment", "autonomous", "hands-off"). When ON, the interactive contract above is **suspended** and these substitutions apply everywhere in this skill:

- Every "Ready to proceed?" / "Ready?" / "Confirm or override?" becomes a stated one-line decision, then continue. Never wait for input.
- Effort (Steps 4 and 6): assess against the AGENTS.md rubric, print **"[Planning|Implementation] effort: [level] ([rationale]). Proceeding."**, set the effort control, and continue.
- Anywhere a step says to ask (flow triage tie-break, monorepo app pick, Path B plan confirmation): make the best-judgment call, state it in one line, and log it in the Step 5 or Step 7 Linear comment so the decision is auditable.
- Delegation is expected, not optional: apply the Delegation & Model Policy section below, and state each tier call in one line instead of asking about it.

**Hard stops still hold** — autonomous mode never overrides these; stop and surface instead of guessing: red baseline tests (Step 5), dirty tree / failed base pull (Step 5), unmergeable PR after the retry (Step 8), the PRD kick-back rule (Step 3), CI red after /lfg's attempts (Step 7), and anything destructive or irreversible outside the plan's scope.

## Delegation & Model Policy

Applies in **both** modes, every step. This is the AGENTS.md Delegation section as it lands in this loop — read that for the full tier table.

**Assess the tier before every step that runs more than a couple of tool calls.** State the call in one line — **"Delegating [work] → [haiku|sonnet] ([why])"** or **"Main thread: [work] (judgment)"** — then act. Not assessing is the error; the default is delegate-and-downshift, and "faster to do it here" is not a reason to burn frontier context on a file dump.

- **Cheapest tier (`haiku`):** repo exploration, multi-file reads, existing-pattern discovery, the Step 1 project resolution scan, plan-file scaffolding and metadata-header writes, PROJECT.md / Build Log rows, Linear comment formatting, TODO/FIXME scans, git status/diff summarization.
- **Mid tier (`sonnet`):** per-file review passes, test-suite triage, implementation slices against a settled plan, summarizing what a `haiku` pass found, drafting the PR body.
- **Frontier (main thread, never delegated):** flow triage (Step 3), effort assessment (Steps 4 and 6), plan approval, architecture calls, the kick-back and escalation rules, CI failure diagnosis, and the Step 8 merge decision.

**GitHub and CI work is cheap-tier by default.** Every `gh` / Actions operation that loops, polls, or returns bulk output goes to a `haiku` subagent — CI watch, check-status polling, fetching Actions run logs and reducing them to the failing lines, PR body assembly, workflow-YAML edits, label and secret plumbing. Escalate that subagent to `sonnet` only when the logs need real interpretation. The main thread gets the reduced result (failing test + error), not the log. Deciding what the failure *means*, and whether to merge, stays here. A single one-shot `gh` call (`gh pr view`, `gh pr merge`) stays inline — a subagent round-trip costs more than the call.

**Escalate on failure, not suspicion:** start low, and on an incomplete or low-confidence result re-run one tier up rather than pulling the work into the main thread. Two failed tiers means it needed judgment... reclassify. Dispatch independent subtasks in parallel (one message, multiple Agent calls).

## Step 1: Resolve Linear Project (For This Repo)

The repo's Linear link lives *in the repo*, in `.linear-project.json` at the repo root: `{ "id": "...", "slug": "...", "name": "...", "team": "MCR" }`. Resolve in order:

### 1A: Local link file
Read `./.linear-project.json`. If present with an `id`, use it. Skip to Step 2.

### 1A-mono: Monorepo (no root link file, per-app link files exist)
If the repo root has no `.linear-project.json` but one or more `apps/*/.linear-project.json` exist, this is a monorepo of Linear-linked apps. Resolve the target app:
1. If the argument names an app (e.g. `radar`, `horizon` — match against `apps/*` folder names, case-insensitive) or is a Linear issue ID whose issue belongs to one of those apps' projects, use that app's link file.
2. Otherwise ask which app to work on (AskUserQuestion with the app list).
Then use `apps/<app>/.linear-project.json` as the project link, treat `apps/<app>/` as the working scope for this session (its AGENTS.md governs), and keep plans/checkpoints under `apps/<app>/docs/`. Branches, commits, and the PR still run from the repo root.

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
2. Take the top result. Print: **"Highest-priority active issue: [ID] [title] (Priority: [X], Flow: [label]). Auto-building. Override with `/zmcray-build [different-id]` if wrong."**
3. Wait 2 seconds for an interrupt. If none, capture the issue ID and labels and proceed.
4. Continue to Step 3.

### Path D: Free-text argument

If the argument is free text (not a Linear ID pattern):

1. Use the argument verbatim as the task description.
2. No Linear issue is captured. Linear sync at wrap time will be skipped.
3. Continue to Step 3 (flow resolution falls to the triage rule or user statement).

### Path E: Nothing to build

If no argument AND no active plan AND repo is not Linear-linked, stop and tell the user: "No task source. Provide an argument, run `/zmcray-kickoff` to link Linear, or create a plan first."

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

**Chunk shortcut (check first).** If the issue body carries a `## Build packet` whose `Spec:` line points at a plan unit (`docs/plans/... § U<N>`), the planning already happened in `/ce-plan` and the cut happened in `/to-chunks`. **Skip all pre-work for every flow.** Use that plan file as the plan of record, execute only the named unit, treat `File scope` as a fence (wanting to leave it = kick back with a Linear comment, do not expand), and treat `Out of scope` as binding. Read the issue's `tier:*` label and set the model for delegated implementation work from `software-factory/DISPATCH.md` (mechanical → cheapest, moderate → mid, judgment → frontier / main thread). State both calls in one line, then go to Step 5.

**Set effort first.** Assess the planning work against the AGENTS.md Effort rubric (reasoning difficulty, not blast radius). State the assessed effort level and a one-line rationale, then ask the user to confirm or override before planning. Once confirmed, set your tool's effort control. Effort is orthogonal to flow and re-tuned per phase. Print it like: **"Planning effort: [level] ([one-line rationale]). Confirm or override?"**

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

### CI impact gate (when applicable)

If the task or plan changes `.github/workflows/**`, test topology, artifact uploads, scheduled jobs, runner labels, or monorepo workflow routing, apply the canonical **CI cost discipline** before branching. The plan must state trigger/path scope, repository visibility and runner class, fast required PR checks versus full merge/manual coverage, artifact conditions/size/retention, branch-protection compatibility, and expected Actions usage change. Add the section if an older plan omitted it. Never reduce required coverage merely to save minutes.

**Plan file convention (design + standard):** ensure the plan lands in `docs/plans/plan-[YYYY-MM-DD]-[short-description].md` (create `docs/plans/archive/` if missing) with this metadata header, so /lfg's gate and /zmcray-wrap can find it:

```
---
Created: [timestamp]
Flow: [design|standard|ship]
Linear Project: [name from Step 1, or "none"]
Linear Issue: [ID from Step 2, or "none"]
Linear Branch: [gitBranchName from Linear, or "none"]
Base Commit: [filled in at Step 5 — the default-branch SHA the feature branch was cut from]
Task: [one-line description]
---
```

## Step 5: Branch, Baseline, Linear Sync

1. Sync the base branch. Always branch from fresh remote state, never from a stale local HEAD or a leftover feature branch — a stale base is where PR merge conflicts come from:
   - Detect the default branch (`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`, fall back to `main`).
   - `git checkout [default-branch] && git pull origin [default-branch]`
   - If the working tree is dirty or the pull fails (offline, diverged), stop and surface it before branching.
2. Create the feature branch from that fresh base:
   - If a Linear `gitBranchName` was captured, use it: `git checkout -b [gitBranchName]`
   - Otherwise: `git checkout -b feat/[short-description]`
   - Record the base SHA (`git rev-parse HEAD` before any commits) into the plan file's `Base Commit:` field. This is what wrap's code review diffs against — it survives the squash-merge and branch deletion.
3. Run existing tests. Confirm green baseline. If tests fail, stop and surface failures before proceeding.
4. **If a Linear issue is linked**, update Linear:
   - Move the issue state to **In Progress**.
   - Post a comment: `Build session started. Branch: [branch-name]. Flow: [flow]. Plan: [plan-filename or "/lfg plan gate"].`
5. Update PROJECT.md (slim format): one-line Current Status + a Build Log row (date, "Build session started", plan filename, issue ID). If PROJECT.md doesn't exist, stop and tell the user to run `/zmcray-kickoff` first.
6. Print: **"Branch created from fresh [default-branch], baseline green, Linear updated. Next step: hand off to /lfg (runs unattended through PR). Ready?"**

## Step 6: Execute via /lfg

**Re-assess effort.** Implementation effort can differ from planning (a hard design often plans at `max` but implements at `medium`, or vice versa). Re-assess against the AGENTS.md Effort rubric, state the implementation effort level and a one-line rationale, and ask the user to confirm or override before handing to /lfg. Once confirmed, set your tool's effort control. Print it like: **"Implementation effort: [level] ([one-line rationale]). Confirm or override?"**

This is the handoff. From here /lfg runs its gated pipeline without prompting: plan gate > work > plan-aware code review > apply fixes + commit > file unfixed findings to Linear > browser test > commit/push/PR > CI watch until green (max 3 fix attempts).

Invoke `/lfg` with a task statement that includes:

- The Linear issue ID and title (so commits get tagged and tracker-defer files residuals against the right project)
- The plan file path from Step 4 (design/standard), or the task description (ship... /lfg will write its own plan)
- **Commit convention:** conventional commits with `[ISSUE-ID]` appended, e.g. `feat: implement upload flow [MCR-123]`, so Linear auto-links
- **Residual filing contract:** the issue's milestone and its epic prefix (the part of the milestone name before the number or colon, e.g. `Recipes`), with this instruction: "Every residual you file sets project, milestone `<Epic>: hardening` (create it if missing), a priority mapped from severity (never No priority), and one `flow:*` label. Search open issues on the same file first and extend an existing one rather than filing a near-copy." Per AGENTS.md > Linear structure.
- **Test-first directive (design + standard only):** "Write the failing test before the implementation for each unit of work."
- **Constraint:** stay within the plan's scope; if the work wants more, stop and apply the kick-back rule from Step 3 instead of improvising
- **CI execution discipline:** run focused verification locally before the first push, batch coherent fixes into one push, and do not rerun an unchanged failed job unless evidence points to transient infrastructure. Workflow changes must preserve the plan's CI Impact decisions and the canonical CI cost discipline.

### Implementation rules /lfg inherits

- **Subagent isolation:** tasks touching 3+ files break into independent subtasks in fresh subagents, merged at the end.
- **Tier those subagents** per the Delegation & Model Policy above: mechanical slices and file reads on `haiku`, spec-bound implementation and per-file review passes on `sonnet`, judgment in the main thread. /lfg's CI watch and its Actions log fetching run on `haiku`; only the diagnosis of a red run comes back to the frontier model.
- **Preserve coverage while cutting waste:** cancellation, safe path scoping, job consolidation, artifact limits, and PR/merge suite separation are valid optimizations; skipping required tests is not.
- **Stay on the plan.** If something doesn't verify, surface it... don't route around it.

## Step 7: Post-/lfg Verification

When /lfg emits DONE (or exits with unresolved CI failures):

1. Confirm: PR exists, CI status, and whether residual findings were filed to Linear (check the PR body's residuals section). Delegate this gathering to a `haiku` subagent — it's `gh pr view` plus a PR-body read, and it should return a three-line summary, not the PR. If CI is red, that same subagent pulls the Actions run logs and returns only the failing job, test, and error lines.
2. If CI is red after /lfg's 3 attempts, surface the "CI Failures Unresolved" section to the user. Do not merge anything, and do not proceed to Step 8.
3. **Verify residuals landed home.** For each residual issue /lfg filed, confirm it has a milestone (`<Epic>: hardening`), a priority, and a `flow:*` label; patch any that are missing a field and say so in one line. /lfg's filer does not know the contract unless told, so this check is the backstop, not a formality. Include it in the same `haiku` gathering pass.
4. Post a Linear comment on the issue: `Build complete. PR: [link]. CI: [green/red]. Residuals filed: [N or none].`
5. If CI is green, continue directly to Step 8 (Merge & Advance).

## Step 8: Merge & Advance (auto-merge)

Runs automatically after Step 7 when CI is green. This is what keeps multi-issue runs conflict-free: each PR merges before the next issue branches, so every build starts on top of the previous one's merged code.

**Opt-out:** skip this step if `.linear-project.json` has `"automerge": false`, or the user said not to merge in this session or goal. When skipped, print **"/lfg done. PR [link], CI green. Auto-merge is off — merging is your call."** and continue to Step 9 (wrap still runs; note the unmerged PR as a loose end).

1. **Gate:** CI green and PR mergeable (`gh pr view [number] --json mergeable,mergeStateStatus`). Never merge a red or blocked PR.
2. Merge: `gh pr merge [number] --squash --delete-branch`
3. **If GitHub reports conflicts** (something else landed on the default branch mid-build): `git fetch origin && git rebase origin/[default-branch]`, resolve conflicts, `git push --force-with-lease`, wait for CI to go green again, then retry the merge once. If it still fails, stop and surface — don't loop.
4. Advance the local base: `git checkout [default-branch] && git pull origin [default-branch]`. Confirm the squash commit is present (`git log -1`).
5. Post a Linear comment on the issue: `PR merged to [default-branch]: [link].` (State stays In Review — the user reviews the live app; /zmcray-wrap handles the final state.)
6. Print: **"PR [link] merged (squash) and [default-branch] updated. The next issue will branch from this state."** Then continue to Step 9.

## Step 9: Wrap (automatic)

Build ends with a wrap — don't leave the session open. Run `/zmcray-wrap` now, **unless**:

- This build is one iteration of a multi-issue run (a `/goal` run or a batch session) that will continue to another issue — then defer to the single wrap at the end of the run (per Multi-Issue Runs below; /goal's own Step 3 handles it).
- The user explicitly said to skip the wrap this session.
- Step 7 or 8 hard-stopped (red CI, unmergeable PR) — surface the stop; the user decides whether to wrap a broken session.

The wrap carries the session's close-out machinery: the code review + fix pass, compound capture, plan archive, PROJECT.md sync, and the Linear In Review move. Running it here means a plain `/zmcray-build` invocation gets all of that without a separate command.

## Multi-Issue Runs (goals / batch builds)

When a goal or a single session works through multiple Linear issues:

- **Strictly sequential:** one issue → PR → merge (Step 8) → next issue. Never start issue N+1's branch before issue N's PR has merged.
- Each iteration re-enters at Step 2. Step 5's fresh-base rule plus Step 8's merge guarantee the new branch includes everything merged so far — this is the conflict-prevention mechanism; don't skip either half.
- If any PR can't merge (red CI, unresolvable conflict), **stop the run there** and surface. Don't skip ahead to the next issue — it would branch from a base missing the stuck work and recreate the conflict problem.
- Defer Step 9's per-issue wrap during the run; run /zmcray-wrap once at the end covering all issues (list each PR in the summary). The wrap's code-review + compound pass then covers the whole run's diff in one shot.

## Review Reference

See `30_Projects/00_Code/review-conventions.md` for the review strategy. Note: /lfg's plan-aware code review (persona council with confidence gating) replaces the old `/codex:review` step. Legacy commands (`/ultraplan`, `/codex:review`, `/codex:adversarial-review`) remain installed for manual use but are no longer part of this loop.

## Notes

- **Prompt between pre-work steps; never inside /lfg.** The interactive contract covers Steps 1-5. Step 6 is autonomous by design.
- The two routing signals are independent: `flow:*` = rigor, `prd-source` = strategy already done. A `flow:design` + `prd-source` issue skips Think but keeps the eng review.
- The plan file is the single source of truth from pre-work through wrap. /lfg's gate requires it to exist for design/standard; /lfg writes its own for ship.
- Linear updates during the session: In Progress + start comment (Step 5), /lfg residuals (Step 6), build-complete comment (Step 7), merged comment (Step 8). The full session summary lands at wrap.
- Auto-merge (Step 8) is on by default and gated on green CI. Turn it off per-repo with `"automerge": false` in `.linear-project.json`, or per-session by saying so. Squash merge is the fixed strategy — one commit per issue on the default branch.
- If Linear is unreachable when you try to update it, log the failure to the plan file's `## Linear Sync Errors` section and continue. Don't block the build on a network glitch.
- The Linear link lives in the repo's `.linear-project.json` (id + slug + name). If it's missing, Step 1B resolves it from Linear and writes it. The file travels with the repo, so the link can't go stale from a path change... no central cache.
- Compound Engineering v3 renamed commands to the `ce-` prefix (`/ce-plan`, `/lfg`, `/ce-compound`). If a command is missing, run `/ce-update` or reinstall the plugin before debugging this skill.
