---
name: goal
description: Autonomous multi-issue run. Works through the repo's Linear issues via /zmcray-build in autonomous mode until the objective is met — no user prompts, judgment calls made solo, execution delegated to subagents on cheaper models.
argument-hint: "[objective, e.g. 'the whole app' or 'milestone 2' or 'MCR-12 MCR-14'. Empty = all active issues in this repo's Linear project]"
---

# Goal

Run the build loop to an objective, not an issue. This is `/zmcray-build` in a loop with the interactive contract turned off: you handle all planning and decisions yourself, execution is a handoff, and the run ends when the objective is met or a hard stop fires — never because a question is pending.

**Standing contract for the entire run:**

- **Never ask the user for input.** No AskUserQuestion, no "Ready?", no effort confirmations. Where a step would ask, make the call with your best judgment, state it in one line, and keep moving. The only exits are: objective met, or a hard stop (listed below).
- **You own planning and decisions; execution can be a handoff.** Flow triage, effort setting, plan approval, architecture calls, scope judgments, CI failure diagnosis, and merge calls stay in the main thread. Everything else goes down a tier, per the AGENTS.md Delegation section and /zmcray-build's Delegation & Model Policy: repo exploration, multi-file reads, plan-file and PROJECT.md writes, Linear comment formatting on `haiku`; mechanical implementation slices, per-file review passes, and test triage on `sonnet`. **Assess the tier before every multi-tool-call step and state it in one line** (`Delegating [work] → haiku ([why])`) — this is a decision the run must make explicitly, not a preference. A goal run's length is bounded by main-thread context, so file dumps and log tails spent here cost you issues at the end of the run.
- **GitHub and CI work runs on `haiku`.** The CI watch, check-status polling, Actions run-log fetching (reduced to the failing job/test/error lines), PR body assembly, and workflow-YAML edits all go to a cheap-tier subagent; escalate that subagent to `sonnet` only when the logs genuinely need interpretation. One-shot `gh` calls stay inline. What a red run means, and whether to merge, stays with you.
- **Decisions are auditable, not silent.** Every judgment call made in place of a question gets one line in the transcript and lands in a Linear comment on the relevant issue.

## Step 1: Resolve the objective into an issue set

Resolve the Linear project exactly as `/zmcray-build` Step 1 does (`.linear-project.json`, monorepo variant included — if the objective names an app, that picks the app; if it doesn't and the repo is a monorepo, infer from the objective, and treat a genuinely unresolvable app choice as a hard stop).

Then scope the run from the argument:

- **Empty or "the whole app" / "all milestones":** every active issue in the project (state type not Done/Cancelled).
- **A milestone or epic name:** match by milestone ID or by prefix, not exact full name (names follow `<Epic> N: <Outcome>` and get refined). An epic name (`Recipes`) selects every live milestone with that prefix, worked in milestone order; the `hardening` shelf is pulled only when named, and the `later` shelf never.
- **One or more issue IDs:** exactly those issues.
- **Free text otherwise:** treat it as the definition of done; select the active issues that serve it (state which and why in one line). If no Linear project is linked, run `/zmcray-build [text] --auto` once and wrap.

Print the run manifest once: **"Goal: [objective]. [N] issues in scope: [IDs]. Running autonomously — hard stops only."**

## Step 2: The loop

Strictly sequential, per the multi-issue rules in `/zmcray-build`: one issue → PR → merge → next. Never start issue N+1 before issue N's PR has merged.

For each iteration:

1. Re-query Linear for the scope's active issues (the board may have changed mid-run; Caspian kick-backs and residuals add issues). Pick the highest priority (Urgent > High > Normal > Low, then updatedAt desc).
2. Run `/zmcray-build [ISSUE-ID]` in **autonomous mode** (its Autonomous Mode section governs: no prompts, stated decisions, delegation on, hard stops intact). It carries the issue through pre-work, /lfg, and merge-on-green.
3. After the merge, print one progress line: **"[k/N] [ISSUE-ID] merged. [next-ID] is next."**
4. If the objective's issue set is exhausted, exit the loop.

**Checkpoint cadence:** after every merged issue, update PROJECT.md's Build Log (zmcray-build already does this). If the session is at risk of ending mid-run (context limits, long runs), write `/zmcray-checkpoint` state so `/goal` can resume; on start, if a checkpoint from a prior goal run exists, resume from it instead of restarting.

## Hard stops

These end the run immediately — surface, post a Linear comment on the stuck issue, checkpoint, and stop. Do not skip ahead to the next issue (it would branch from a base missing the stuck work):

- A PR can't merge: red CI after /lfg's fix attempts, or an unresolvable conflict after the one rebase retry.
- Red baseline tests or a dirty/diverged base when branching.
- The PRD kick-back rule fires (scope exceeds PRD — that goes back through Caspian, not around it).
- Anything destructive or irreversible that the plan doesn't cover.
- Linear or the repo state is unreachable/ambiguous in a way that judgment can't safely bridge (e.g., can't tell which monorepo app the objective means).

## Step 3: Wrap

When the loop exits (objective met or hard stop), run `/zmcray-wrap` once covering all issues in the run: list every PR, CI status, residuals filed, and — if a hard stop fired — exactly where the run halted and why, so the next `/goal` resumes from there.

Close with: **"Goal run complete: [k/N] issues merged. [PRs]. [Residuals/loose ends]."**

## Notes

- `/goal` adds no new build machinery — it is scope resolution + the loop + the autonomous contract. All build behavior (flow routing, effort, branching, merge-on-green, Linear sync) lives in `/zmcray-build` and AGENTS.md; fix behavior there, not here.
- Effort is re-assessed per issue and per phase inside each `/zmcray-build` iteration, as the AGENTS.md rubric requires. A goal run is not one effort setting.
- Auto-merge is required machinery for a goal run. If the repo sets `"automerge": false`, say so up front and stop — a goal run can't proceed if PRs queue unmerged.
