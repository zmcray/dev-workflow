---
name: zmcray-status
description: Quick, read-only status of the current build session. Reads flow, plan state, and Linear state.
argument-hint: ""
---

# Status

Show where things stand in the current build session, sliced by the issue's flow. Read-only: run no tools that mutate, make no changes.

## Step 1: Resolve the Linear Project (For This Repo)

Read `./.linear-project.json` at the repo root. If present, use its `id` and `name`. If absent, the repo isn't linked yet (run `/zmcray-build` or `/zmcray-kickoff` to link); omit the Linear lines and continue read-only. Status never writes the file or scans Linear to create it.

## Step 2: Find the Active Plan

Look in `docs/plans/` (not `archive/`) for the most recent plan file. If found, read its metadata header and extract `Flow`, `Linear Issue`, and which phases are done. If no active plan, say: *"No active plan. Start with `/zmcray-build [task]` or `/zmcray-build` to auto-pull from Linear."*

## Step 3: Read Flow + Linear State

Resolve the flow from, in order: the plan's `Flow:` field; else the linked issue's `flow:*` label; else "unresolved (build will triage)". Also note the `prd-source` label (strategy already done in caspian).

If the plan has a Linear Issue ID, fetch the issue's current state, priority, and the `flow:*` / `prd-source` labels in one call. If Linear is unreachable, print `Linear: [ID] (unreachable)` and continue.

## Step 4: Phase Checklist (By Flow)

Show the phase sequence for the resolved flow, matching the AGENTS.md build workflow. Mark `[x]` done, `[>]` in progress, `[ ]` pending, based on the plan's recorded progress and git/PR state.

### flow:design
```
Project: [name] | Flow: design  [prd-source: yes/no]
Task: [from plan]
Issue: [ID] [title] -> [state] | Priority: [X]      (omit if unlinked)

[ ] Think (office-hours + plan-ceo-review)   <- skipped if prd-source
[ ] Plan (ce-plan council)
[ ] Architecture pass (plan-eng-review)
[ ] Execute (/lfg: work > review > test > PR > CI)
[ ] Review (ce-code-review)
[ ] Learn (ce-compound)
```

### flow:standard
```
Project: [name] | Flow: standard  [prd-source: yes/no]
Task: [from plan]
Issue: [ID] [title] -> [state] | Priority: [X]      (omit if unlinked)

[ ] Plan (ce-plan council)
[ ] Execute (/lfg: work > review > test > PR > CI)
[ ] Review (ce-code-review)
[ ] Learn (ce-compound)
```

### flow:ship
```
Project: [name] | Flow: ship
Task: [from plan]
Issue: [ID] [title] -> [state] | Priority: [X]      (omit if unlinked)

[ ] Execute (/lfg: plan gate > work > review > test > PR > CI)
```

If flow is unresolved, say so and note build will triage at pickup.

## Step 5: Git State

One line: `Git: [X] uncommitted files, [Y] commits since last plan, branch: [name]`

## Step 6: Outstanding Items

Check for: unresolved review findings or residuals filed to Linear, TODO/FIXME added since the plan started, failing or skipped tests, and Linear/local state mismatch (e.g. issue is In Progress in Linear but the plan is archived). List any; if none, say "Nothing outstanding."

## Notes

- Keep the whole output under ~22 lines. A glance, not a report.
- Read-only. Run no mutating tools, make no edits.
- **This whole command is cheap-tier work.** Steps 1-3 and 5-6 are file reads, one Linear fetch, and a `git status` — delegate the gathering to a single `haiku` subagent that returns the fields the report needs, and render the output from that. Nothing here requires the frontier model; only the Step 6 flow-vs-work mismatch flag is a judgment call, and it's a one-line one.
- If flow and the work disagree (e.g. a ship issue is clearly touching auth), flag it as an outstanding item... build's escalation rule should bump it up a flow.
- If Linear says Done but the plan is not archived, surface it.
