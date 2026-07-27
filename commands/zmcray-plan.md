---
name: zmcray-plan
description: Batch planning session. Decompose a PRD, feature list, or raw scope into fully-specified, execution-ready Linear issues... every decision made up front, quality-gated, dependency-linked, labeled spec-ready. Human-in-the-loop by default (taste decisions only); --auto for fully autonomous; --review to pause at every feature. Pairs with /zmcray-execute.
argument-hint: "[PRD path, Linear project/initiative, feature list, or free-text scope] [--auto | --review]"
---

# Plan

Run the McRay Batch Planning Loop. Take a body of scope (PRD, feature list, raw idea), decompose it into features, make every implementation decision now, and log each feature as a fully-specified Linear issue that /zmcray-execute can implement with zero further human input.

The contract with /zmcray-execute: **an issue is not done planning until someone with no project context could implement it from the issue body alone.** Exact files, approach, test scenarios, verification steps, and explicit non-goals. Deferred questions are allowed only in a `Deferred to Implementation` section, and only for decisions that genuinely require seeing the code mid-flight.

## Modes (HITL dial)

Resolve the mode from the argument, then state it in one line before Step 1:

- **Default (taste mode):** auto-resolve every decision using the encoded principles below and the repo's AGENTS.md. Pause ONLY for product-taste calls... naming, UX tradeoffs, scope judgment where two defensible options diverge on product opinion rather than engineering fact. Batch taste questions per feature into a single AskUserQuestion.
- **`--auto` (fully autonomous):** never pause. Every call (including taste) is made with best judgment, stated in one line, and logged in the issue body under `## Planning Decisions` so it's auditable and reversible.
- **`--review` (full HITL):** pause after each feature's draft spec for approval before logging the issue. Also pause at the Step 6 advisor pass results.

Hard stops hold in every mode: contradictory requirements in the source scope, scope that exceeds a `prd-source` PRD (kick-back rule, same as build Step 3), and anything requiring credentials or destructive migration decisions.

## Delegation & Model Policy

Apply the AGENTS.md Delegation section throughout. **Assessing the tier is mandatory, not optional:** before any step that runs more than a couple of tool calls, state **"Delegating [work] → [haiku|sonnet] ([why])"** or **"Main thread: [work] (judgment)"**, then act. Default to delegate-and-downshift — a planning pass burns main-thread context fastest on codebase reads, and that context is what the quality gate needs later.

Keep decomposition, flow triage, quality gating, and all judgment calls in the main thread (frontier tier). Fan out to subagents:

- **Mechanical / cheapest tier (haiku):** repo exploration, multi-file reads, existing-pattern discovery, duplicate-issue checks against Linear, dependency-surface mapping, Linear issue-body writes once the text is settled.
- **Moderate synthesis / mid tier (sonnet):** drafting each feature's Implementation Unit spec from the main thread's decisions, formatting issue bodies, summarizing prior art found by the mechanical pass.
- **Judgment / frontier:** stays in the main thread... never delegate the flow label, the quality score, or a taste call.
- **GitHub / `gh` reads (haiku):** any repo-history, PR, or Actions-workflow inspection this pass needs (what CI already runs, what a prior PR did) goes to a cheap-tier subagent that returns the answer, not the output.

Escalate on failure, not suspicion: re-run a weak delegated result one tier up rather than pulling it into the main thread. Dispatch independent per-feature spec drafts in parallel (single message, multiple Agent calls) once decisions are made.

## Step 1: Resolve Linear Project

Identical to /zmcray-build Step 1 (link file → monorepo per-app files → resolve-and-write → ask). Read `./.linear-project.json`; follow build's 1A-1D exactly. Planning without Linear linkage is not supported... issues are the output artifact. If the user skips linkage, stop and point them to `/zmcray-kickoff`.

## Step 2: Gather Scope

Resolve the planning input using the first matching path:

- **Path A: PRD path or `prd-source`.** Argument is a file path under `docs/strategy/` or a Linear document. Read it in full. Caspian already ran the strategy council, so skip all Think-phase work (`/office-hours`, `/plan-ceo-review`)... the PRD is the strategy. The Cagan risk block and acceptance criteria carry the per-feature contract.
- **Path B: Linear initiative or project scope.** Argument names an initiative or says "plan the backlog". Pull the project's open, unlabeled-or-underspecified issues (no `spec-ready` label) as the feature candidates.
- **Path C: Free-text scope or feature list.** Use verbatim. No strategy work exists yet, so the Think phase in Step 4 applies.
- **Path D: Nothing.** Stop: "No scope. Give me a PRD path, an initiative, or a feature list... or run /caspian first if this needs strategy."

Print: **"Scope: [source]. Strategy done: [yes (prd-source) / no]. Mode: [taste/auto/review]. Decomposing."**

**Set effort first.** Assess the planning work against the AGENTS.md Effort rubric, print **"Planning effort: [level] ([one-line rationale])."**, and set the tool's effort control. In taste/review mode ask to confirm or override; in --auto mode state it and proceed. Re-assess once at Step 4 if the features turn out much harder or easier than the scope suggested.

## Step 3: Decompose Into Features

Break the scope into features sized for one build loop each (one branch, one PR, mergeable in one session). Rules:

1. Split by deliverable seam, not by layer... "upload flow end-to-end", not "backend" + "frontend".
2. Map dependencies as you split: which features must merge before which. This becomes Linear `blocked by` relations in Step 5.
3. Dispatch a mechanical subagent to check each candidate against existing Linear issues (dedupe) and against the codebase (does part of this already exist?).
4. Present the feature list with proposed dependency order. Taste mode: proceed unless the split itself is a taste call. Review mode: confirm the list before continuing.

## Step 4: Per-Feature Planning

Loop over features in dependency order. For each:

### 4A: Think (only if no PRD, and only once per scope)
Path C scope with new surface area gets one `/office-hours` pass on the overall scope (not per feature), then `/plan-ceo-review` against the resulting design doc. Skip entirely for Path A/B.

### 4B: Flow triage
Classify by blast radius exactly as build Step 3: new surface/auth/data/hard-to-reverse → `flow:design`; meaty but known territory → `flow:standard`; small, reversible → `flow:ship`. State the call in one line.

### 4C: Spec the feature
Run `/ce-plan` with the feature (plus PRD section, if any) as input. Shape its output into the issue spec using CE's Implementation Unit schema. Every issue body must contain:

```
## Spec
[One-paragraph goal: what exists after this merges, and why]

## Implementation Units
### U1: [name]
- Goal: ...
- Files: Create: [...] / Modify: [...] / Tests: [...]
- Approach: [the decided approach... not options]
- Patterns to follow: [pointer to existing code that does it the house way]
- Test scenarios: [...]
- Verification: [how the executor proves this unit works]
[U2..Un as needed]

## Scope Boundaries
[Explicit non-goals. What this issue deliberately does NOT do.]

## CI Impact (only when applicable)
- Trigger and path scope: ...
- Repository visibility and runner class: ...
- Fast required PR checks: ...
- Full merge/manual coverage: ...
- Artifact policy (conditions, estimated size, retention): ...
- Required-check compatibility: ...
- Expected Actions usage change: ...

## Deferred to Implementation
[Only decisions that require seeing code mid-flight. Empty is the goal.]

## Planning Decisions
[Every non-obvious call made during planning, one line each, with rationale. In --auto mode this includes taste calls.]
```

For `flow:design` features, additionally run `/plan-eng-review` on the spec (architecture, failure modes, test matrix) and fold its findings into the units.

Include `## CI Impact` when the feature changes `.github/workflows/**`, test topology, artifact uploads, scheduled jobs, runner labels, or monorepo workflow routing. Apply the canonical CI cost discipline: preserve coverage while reducing redundant execution, and explicitly resolve branch-protection compatibility before proposing path filters. Omit the section when CI is genuinely unaffected.

### 4D: Quality gate
Score the spec 1-10 against the executability bar: complete files list, single decided approach per unit, testable verification steps, real scope boundaries, near-empty deferred section, and a complete CI Impact section when applicable. **Below 7: do not log the issue.** Loop back... in taste/review mode ask the narrowing questions; in --auto mode do another research pass (subagent) and re-spec once, and if still below 7, log it as a normal (non-spec-ready) issue with a comment explaining what's missing and move on.

### 4E: Taste checkpoint (taste mode only)
If this feature raised taste calls, ask them now, batched in one AskUserQuestion. Fold answers into the spec. Review mode: present the full spec for approval instead.

## Step 5: Log Issues to Linear

For each gated spec, create (or update, for Path B) the Linear issue on the resolved project:

1. Title: imperative, one line. Body: the full spec from 4C.
2. Labels: exactly one `flow:*`, plus `spec-ready`, plus `prd-source` if Path A.
3. Priority: from the PRD/scope ordering; default Normal.
4. Relations: `blocked by` links per the Step 3 dependency map. /zmcray-execute pulls only unblocked `spec-ready` issues, so these edges ARE the execution order.
5. Estimate: skip. The spec is the estimate.

## Step 6: Advisor Pass (whole plan)

Before declaring the plan done, run a parallel advisor review across the full issue set (fresh subagents, one persona each, mid tier): **scope-guardian** (does the sum of issues exceed the source scope? any gaps against the PRD acceptance criteria?), **feasibility** (dependency order actually buildable? hidden coupling between "independent" issues?), **adversarial** (what breaks in production that no issue covers... migrations, rollback, observability?).

Confidence-gate the findings: only surface findings a persona rates high-confidence AND that another persona doesn't contradict. Apply fixes as issue edits. In review mode, present findings before applying. Material scope gaps against a `prd-source` PRD trigger the kick-back rule, not silent new issues.

## Step 7: Summary & Handoff

Print the plan summary: feature count, flow distribution, dependency chain (as an ordered list), quality scores, taste calls made or asked, advisor findings applied. Post the same summary as a comment on the Linear project (or initiative).

Close with: **"[N] issues spec-ready on [project]. Execution order: [ID → ID → ...]. Run /zmcray-execute to burn them down, or /zmcray-build [ID] for one at a time."**

## Success Criteria

- [ ] Linear project resolved from the repo link file
- [ ] Scope decomposed into one-build-loop features with dependency edges
- [ ] Every logged issue scores ≥7 on the executability gate
- [ ] Every issue has exactly one `flow:*` label plus `spec-ready`
- [ ] `blocked by` relations encode the execution order
- [ ] Advisor pass ran and high-confidence findings were applied
- [ ] Zero unresolved decisions outside `Deferred to Implementation`
- [ ] Plan summary posted to Linear

## Relationship to the Other Commands

- **/caspian** decides WHAT to build and why (strategy, PRD). /zmcray-plan decides HOW, completely, in advance. Caspian's issues are inputs here (Path B), not outputs.
- **/zmcray-build** plans-then-executes one issue interactively. /zmcray-plan front-loads the planning for a whole batch so execution needs no human.
- **/zmcray-execute** consumes the `spec-ready` issues this skill produces. The `spec-ready` label + `blocked by` edges are the entire interface between the two.
- **/ce-plan, /office-hours, /plan-ceo-review, /plan-eng-review** are the engines this skill orchestrates... it never reimplements them. If a `/ce-*` command is missing, run `/ce-update` or reinstall the plugin.

## Notes

- The plan lives in the issues, not in a plan file. `docs/plans/` files remain the per-build artifact that /lfg's gate needs; /zmcray-execute (or /lfg) derives them from the issue spec at execution time.
- Re-running /zmcray-plan on the same scope is safe: Path B pulls existing issues and upgrades them to spec-ready rather than duplicating (the Step 3 dedupe subagent enforces this).
- If Linear is unreachable mid-run, hold finished specs in memory, retry at the end, and if still down, write them to `docs/plans/pending-issues-[date].md` and tell the user to re-run Step 5 later. Never lose a gated spec.
- Escalation rule from build applies during planning too: if speccing reveals bigger blast radius, escalate the flow label, never de-escalate.
