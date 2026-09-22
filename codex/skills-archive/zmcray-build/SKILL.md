---
name: zmcray-build
description: Run the McRay flow-routed build loop in Codex. Use when the user invokes /zmcray:build, $zmcray-build, asks to build the next Linear issue, or wants the repo workflow that resolves Linear, routes by flow labels, plans as needed, branches, tests, implements, reviews, commits, pushes, opens a PR, and reports CI/residuals.
---

# ZMcRay Build

Run the build workflow defined by the repo's `AGENTS.md` canonical workflow. Treat `/zmcray:build` as an alias for this skill even though Codex skill names use hyphens.

This skill is a coordinator, not a replacement for the review skills named by the repo workflow. When `AGENTS.md` names a skill such as `$plan-ceo-review` or `$plan-eng-review`, open that skill's `SKILL.md` and execute it as a blocking sub-workflow. Do not replace named skill gates with a self-review unless the skill file is unavailable.

## Interaction Contract

Ask before moving past pre-work gates when the workflow requires confirmation. Once execution starts, stay autonomous through implementation, verification, review, commit/PR if requested by the workflow, and summary unless blocked.

Do not branch, run baseline tests, or start implementation until every required pre-work gate for the selected flow is complete and verified. A written plan alone is not a completed Plan phase for `flow:design`.

Merge on green, per `AGENTS.md`: when CI is green and the PR is mergeable, squash-merge it (`gh pr merge --squash --delete-branch`), pull the default branch, and post a merged comment to the Linear issue. Never merge a red or blocked PR. Opt out only if `.linear-project.json` has `"automerge": false` or the user said not to merge this session.

If Linear or GitHub tools are unavailable, continue with the best local equivalent and clearly report the skipped sync.

## 1. Resolve Project

Read `AGENTS.md` first. Resolve the Linear project from `./.linear-project.json` when present. If missing, use Linear tools to find a unique Mcraygroup project by `Local Path` or normalized repo name, then write `.linear-project.json`. If ambiguous, ask the user to choose; if skipped, continue without Linear auto-pull/sync.

## 2. Determine Task Source

Resolve the task in this order:

1. Argument is a Linear issue ID matching `[A-Z]{2,4}-\d+`: fetch title, description, priority, state, labels, comments, `gitBranchName`, and attachments.
2. No argument and an active `docs/plans/` file exists: read it, extract `Linear Issue:`, and confirm using that plan.
3. No argument, no active plan, repo is Linear-linked: pull highest-priority active issue in the project.
4. Free text argument: use it as the task description and skip Linear-specific sync.
5. No source: stop and ask for a task, a Linear issue, or kickoff.

## 3. Route Flow

Use exactly one `flow:*` label:

- `flow:design`: new surface area, architecture, auth/data/payments, or hard-to-reverse work.
- `flow:standard`: substantial feature in known territory.
- `flow:ship`: small, reversible, well-specced change.

If the issue is unlabeled, triage in about 30 seconds, apply the label in Linear when available, state the call, and proceed. Treat `prd-source` as "strategy already happened."

Escalate upward if the work reveals bigger blast radius. Never de-escalate mid-build. If a `prd-source` issue needs scope beyond the PRD, post the kick-back comment, move it to Backlog if Linear is available, and stop.

## 4. Pre-Work

For design and standard flows, create or confirm a plan at `docs/plans/plan-YYYY-MM-DD-short-slug.md` with:

```markdown
---
Created: [timestamp]
Flow: [design|standard|ship]
Linear Project: [name or "none"]
Linear Issue: [ID or "none"]
Linear Branch: [gitBranchName or "none"]
Task: [one-line description]
---
```

Routes:

- `flow:design` with `prd-source`: create or confirm the plan, then run `$plan-ceo-review`, then run `$plan-eng-review`, then verify both review reports before proceeding.
- `flow:design` without `prd-source`: run the Think phase first, then create or confirm the plan, then run `$plan-ceo-review`, then run `$plan-eng-review`, then verify both review reports before proceeding.
- `flow:standard`: create or confirm the plan, then run the plan gate required by `AGENTS.md`; if no named review skill is required by the repo, self-review feasibility, scope, security, failure modes, rollback, and test strategy before proceeding.
- `flow:ship`: no pre-work beyond the execution plan gate.

Think phase:

- If the repo workflow or user names a strategy skill, execute that skill.
- If no strategy skill is available, write a concise design doc covering problem, user, 10x version, and deliberate non-goals.
- `prd-source` means Caspian already did the strategy thinking; it skips Think only. It does not skip `$plan-ceo-review` or `$plan-eng-review` when the design flow requires reviewed planning.

Plan phase:

- Write or update the plan file at the path above.
- The plan file is draft until the required review skills have appended a terminal `## GSTACK REVIEW REPORT` and the review dashboard has been updated.
- Do not treat `update_plan` or a plan file write as a substitute for `$plan-ceo-review` or `$plan-eng-review`.

Required review-skill gates for `flow:design`:

1. Open and read the current `$plan-ceo-review` skill file before running it.
2. Execute `$plan-ceo-review` against the active plan. Honor its STOP points, AskUserQuestion gates, TODO handling, review log writes, and `## GSTACK REVIEW REPORT` exit gate.
3. Open and read the current `$plan-eng-review` skill file before running it.
4. Execute `$plan-eng-review` against the CEO-reviewed plan. Honor its STOP points, AskUserQuestion gates, test-plan artifact, review log writes, and `## GSTACK REVIEW REPORT` exit gate.
5. Verify the plan file's last `## ` heading is `## GSTACK REVIEW REPORT`.
6. Verify the report includes CEO Review and Eng Review rows with status not missing, a VERDICT line, and the required unresolved-decisions final line.
7. If any required review is blocked, stale, missing, or has unresolved decisions, stop and report the blocker. Do not proceed to branch, baseline, or implementation.

Fallback rule:

- Use native Codex review only when the named review skill file is missing or unreadable. In that case, state the missing path, perform the closest native review, write the same `## GSTACK REVIEW REPORT` shape into the plan, and mark the relevant review status as fallback. Do not silently downgrade.

CI impact gate:

- If the task changes `.github/workflows/**`, test topology, artifacts, schedules, runner labels, or monorepo workflow routing, require the plan's canonical `## CI Impact` section before branching.
- Resolve trigger/path scope, repository visibility and runner class, fast required PR checks versus full merge/manual coverage, artifact conditions/size/retention, required-check compatibility, and expected usage change.
- Apply the canonical CI cost discipline from `AGENTS.md`; preserve required coverage while removing redundant execution.

After each pre-work gate, print the gate completed, the next required gate, and ask "Ready to proceed?" only when the workflow requires confirmation. If the next gate is mandatory and not yet run, do not phrase implementation as the next step.

## 5. Branch, Baseline, Sync

Create a feature branch using Linear `gitBranchName` when present, else `feat/[short-slug]` unless repo instructions specify another prefix. Run the existing baseline tests before implementation. If tests fail, stop and surface failures.

If Linear is linked, move the issue to In Progress and post a start comment. Update `PROJECT.md` current status and build log if it exists; if the workflow requires it and it is missing, tell the user to run kickoff.

## 6. Execute

Implement within the plan scope. For design and standard flows, write failing tests before implementation for API, data, auth, DB, or other meaningful logic. Follow repo code standards, review your diff, run focused tests plus build/typecheck as appropriate, and fix review findings instead of filing residuals unless the finding is genuinely out of scope. Run focused verification locally before the first push, batch coherent CI fixes, and do not rerun unchanged failures unless evidence points to transient infrastructure.

For work touching 3+ files, split the work into independent subtasks mentally or with available subagent tooling; in Codex, use main-thread execution unless a real multi-agent tool is available.

## 7. Complete

Confirm tests, PR/CI state if a PR was opened, and any residual Linear issues filed. Post Linear completion comment when available:

`Build complete. PR: [link]. CI: [green/red]. Residuals filed: [N or none].`

Every residual follows the issue creation contract in AGENTS.md > Linear structure: project, the `<Epic>: hardening` milestone of the parent issue's epic (create if missing), a priority mapped from severity, and one `flow:*` label. Search open issues on the same file first and extend rather than duplicate. Verify each filed residual has all four before posting the comment.

If CI is green, apply the merge-on-green rule from the Interaction Contract before closing. Close by telling the user the PR/CI/merge state and that `$zmcray-wrap` closes the session. If auto-merge is opted out or the PR is blocked, say the PR awaits merge instead — never merge a red or blocked PR.
