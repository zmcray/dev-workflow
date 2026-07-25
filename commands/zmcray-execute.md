---
name: zmcray-execute
description: Autonomous batch execution loop. Pulls unblocked spec-ready Linear issues produced by /zmcray-plan and implements them end to end... branch, /lfg pipeline, CE review personas, Codex cross-model advisor on design-flow issues, merge-on-green, compound learning capture. Never prompts; every judgment call is logged to Linear. Stops on hard failures instead of guessing.
argument-hint: "[optional: Linear project/app name, issue ID to start from, or --max N issue cap]"
---

# Execute

Run the McRay Batch Execution Loop. Consume `spec-ready` issues in dependency order and implement each through PR and merge. **Always autonomous**: there is no interactive contract in this skill. Every decision is a stated one-line call, logged to Linear. The planning already happened in /zmcray-plan... if an issue turns out to need planning, that's a defect to route back, not a conversation to start.

## Autonomous Rules

- Never wait for input. Decisions are stated one line at a time and logged in the issue's Linear comments.
- Effort per phase: assess against the AGENTS.md rubric, print **"[Phase] effort: [level] ([rationale]). Proceeding."**, set the control, continue.
- Delegation is mandatory, per the AGENTS.md Delegation section and /zmcray-build's Delegation & Model Policy. **Assess the tier before every step that runs more than a couple of tool calls and state it in one line** (`Delegating [work] → haiku ([why])`); an unassessed step is a defect in the run, not a shortcut. Orchestration, spec-gate calls, failure diagnosis, and merge decisions stay in the main thread (frontier). Everything else goes down a tier: multi-file reads, repo exploration, the 2B plan transcription, PROJECT.md rows, and Linear comment formatting on `haiku`; implementation slices against a settled spec, per-file review passes, and test triage on `sonnet`. This is a long unattended run — main-thread context is the budget that decides how many issues it survives.
- **GitHub and CI work runs on `haiku`** (escalate to `sonnet` only when logs need interpretation): the CI watch, check-status polling, Actions run-log fetching reduced to the failing lines, PR body assembly, workflow-YAML edits, label plumbing. One-shot `gh` calls stay inline. What a red run *means* is a frontier call.
- Escalate on failure, not suspicion: an incomplete or low-confidence delegated result is re-run one tier up, not absorbed into the main thread. Two failed tiers on the same subtask means it needed judgment... reclassify it.
- **Hard stops** (stop the run, surface, never guess past): red baseline tests; dirty tree or failed base pull; CI red after /lfg's 3 fix attempts; unmergeable PR after one rebase retry; 3 failed fix attempts on any single failure (gstack Iron Law... investigate, don't thrash); a spec that is materially wrong against the codebase (kick-back, below); anything destructive or irreversible outside the spec's scope.

## Step 1: Resolve Linear Project & Queue

1. Resolve the project exactly as /zmcray-build Step 1 (`.linear-project.json`, monorepo per-app files). No linkage → stop; this skill has no free-text path.
2. Build the queue: issues on the project with the `spec-ready` label, state not Done/Cancelled/In Progress, **and no incomplete blocking issues**. Sort by dependency order first (blockers before blocked), then priority, then updatedAt.
3. Apply the argument: a specific issue ID starts the queue there; `--max N` caps the run at N issues; an app name scopes a monorepo.
4. Record the run's starting commit: `git rev-parse origin/[default-branch]` after a fresh fetch. Note it in the manifest — Step 3's final code review diffs `[start-sha]..HEAD` on the default branch after all merges.
5. Print the run manifest: **"Queue: [ID, ID, ...] ([N] issues, [M] deferred as blocked). Cap: [N or none]. Base: [start-sha]. Starting."** Post the manifest as a comment on the Linear project.
6. Empty queue → print "No unblocked spec-ready issues. Run /zmcray-plan or unblock the chain." and stop.

## Step 2: Per-Issue Loop

Strictly sequential, per the build skill's Multi-Issue Runs rule: issue N's PR merges before issue N+1 branches. Never parallelize across issues... the dependency edges and the fresh-base rule are the conflict-prevention mechanism. (Parallelism lives inside an issue, in /lfg's subagent fan-out, not across issues.)

For each issue:

### 2A: Spec gate
Pull the issue. Verify the spec bar: Implementation Units with files/approach/verification, Scope Boundaries present, `flow:*` label present. If the spec is missing or materially wrong against the current codebase (files moved, approach invalidated by merged work from earlier in this run):
- Minor drift (paths renamed, pattern moved): adapt, note the adaptation in a Linear comment, proceed.
- Material invalidation (approach can't work): **kick back.** Remove `spec-ready`, move the issue state to Backlog (same as the canonical kick-back rule), comment "Spec invalidated: [reason]. Needs /zmcray-plan re-pass.", skip to the next issue whose blockers are all still satisfied. Do not improvise a new plan mid-run.

### 2B: Derive the plan file
/lfg's gate requires a plan file. Write `docs/plans/plan-[YYYY-MM-DD]-[slug].md` mechanically from the issue spec (metadata header per the AGENTS.md convention: Created, Flow, Linear Project, Linear Issue, Linear Branch, Task; body = the issue's Implementation Units verbatim). This is a transcription, not planning... delegate it to a cheapest-tier subagent.

### 2C: Branch, baseline, Linear sync
Exactly /zmcray-build Step 5: fresh base pull, branch from `gitBranchName` or `feat/[slug]`, green baseline test run, issue → In Progress with a start comment, PROJECT.md build-log row. Dirty tree, failed pull, or red baseline = hard stop.

### 2D: Execute via /lfg
Hand off to `/lfg` with: the issue ID and title, the derived plan file path, conventional commits with `[ISSUE-ID]` appended, the test-first directive for design and standard flows, and the constraint to stay inside the spec's Scope Boundaries (wants more → stop and kick back per 2A, don't improvise). /lfg runs its gated pipeline: plan gate > work > plan-aware review > fixes + commit > residuals to Linear > test > push > PR > CI watch (max 3 fix attempts).

### 2E: Advisor pass (flow:design only)
After /lfg's own review, `flow:design` issues get an independent cross-model second opinion: run `/codex` in review-gate mode against the PR diff. High-confidence findings that CE's review didn't catch: apply as fixes and re-push. The advisor pass gets its **own budget of 2 fix rounds**, separate from /lfg's 3 CI fix attempts... advisor findings are review depth, not CI failure, and must never trip the CI hard stop. Findings still open after 2 rounds: file to Linear as residuals and move on. Low-confidence or conflicting findings: file to Linear as residuals, don't churn. `flow:standard` and `flow:ship` skip this... CE's persona review is sufficient at that blast radius.

### 2F: Verify, merge, advance
Exactly /zmcray-build Steps 7-8, including its `haiku` delegation of the PR/CI/residual gathering and any Actions log reduction: confirm PR + CI + residuals, post the build-complete comment, then auto-merge on green (`gh pr merge --squash --delete-branch`, one rebase retry on conflict), pull the default branch, post the merged comment. Respect `"automerge": false`... when off, leave the PR open, comment the link, and continue to the next issue ONLY if it isn't blocked by this one (a blocked successor with an unmerged blocker ends the run there).
Then remove `spec-ready` from the issue (it's consumed) and leave state In Review for the human's live-app pass.

### 2G: Advance the queue
Re-derive the unblocked set (this merge may have freed successors). Next issue re-enters at 2A. On any hard stop, end the run... don't skip ahead past a stuck blocker.

## Step 3: Review, Fix, Compound & Wrap

After the last issue (or a stopping failure):

1. **Final review pass:** run `/ce-code-review` over the run's merged work (the default branch diff from the run's starting commit). Fix **every** finding — implement the fixes, run tests, and land them (branch + PR + merge-on-green, same mechanics as 2F; a single cleanup PR covering all findings is fine). Only genuinely unfixable findings (scope decisions, external dependencies) get filed to Linear as residuals. A clean review is stated in one line and the step moves on. This pass runs before compound so learnings capture what the review actually surfaced.
2. Run `/ce-compound` once over the whole run: recurring review findings, spec-drift patterns, anything the next /zmcray-plan pass should encode. Learnings land in `docs/solutions/`.
3. Post the run summary to the Linear project: issues completed (with PR links), kicked back, deferred as blocked, open PRs awaiting manual merge (automerge off), residuals filed, learnings captured, and where/why the run stopped if it did.
4. Print the same summary in chat, ending with: **"Run complete: [N] merged, [M] kicked back, [K] still blocked. Next: review the In Review issues live, or /zmcray-plan for the kick-backs."**
5. Run /zmcray-wrap once covering all issues in the run.

## Success Criteria

- [ ] Queue built from unblocked `spec-ready` issues in dependency order
- [ ] Every issue: fresh base, green baseline, /lfg pipeline, merge-on-green
- [ ] flow:design issues got the /codex cross-model advisor pass
- [ ] Zero human prompts; every judgment call logged to Linear
- [ ] Every multi-tool-call step had a stated tier call; GitHub/CI polling and log reduction ran on `haiku`, not the main thread
- [ ] Invalidated specs kicked back, never improvised around
- [ ] No issue branched before its blockers merged
- [ ] Final /ce-code-review pass run and all findings fixed (or filed as residuals with reasons)
- [ ] /ce-compound learnings captured; run summary posted to Linear
- [ ] /zmcray-wrap closed the session

## Relationship to the Other Commands

- **/zmcray-plan** produces the `spec-ready` queue this skill consumes. The label + `blocked by` edges are the whole interface.
- **/zmcray-build** is the single-issue, interactive sibling... same Steps 5-8 mechanics, human in the loop for pre-work. Use build for one-offs; execute for burn-downs.
- **/goal** drives /zmcray-build autonomously toward an objective, planning as it goes. /zmcray-execute assumes planning is DONE and refuses to plan... that separation is the point.
- **/lfg, /ce-code-review, /ce-compound, /codex** are the engines; this skill orchestrates and never reimplements them. Missing `/ce-*` commands → `/ce-update`.

## Notes

- The spec-gate kick-back (2A) is the safety valve that keeps this skill honest: execution never silently becomes planning. Kick-backs are cheap; improvised plans in an unattended run are not.
- Linear unreachable mid-run: log to the plan file's `## Linear Sync Errors` section and continue; don't block execution on a network glitch. The wrap sync will reconcile.
- The advisor pass (2E) is deliberately asymmetric: cross-model review earns its latency only where blast radius is high. Tune by moving the line (e.g. include flow:standard) in this file, not ad hoc mid-run.
- Model names in this file are Claude Code's (`haiku` / `sonnet` / `opus` on the subagent `model` param) because this is a Claude Code command. Never write a model name into a plan file or a Linear issue — those are read by other harnesses, where tiers map by intent (mechanical / mid / frontier) instead.
