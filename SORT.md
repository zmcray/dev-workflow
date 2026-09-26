# The sort

The rulebook for Stage 0s (MANUAL §1). Two ways in:

1. **Sort on touch (primary).** Any planning step (`/ce-plan`, `/caspian`, `/packets`) that meets an issue with no `design:*` label runs Steps 2 to 4 below on that one issue before it plans (AGENTS.md > Design rung). The rung is decided the moment someone works on the issue, not the next night. The Never list does not apply here: that session goes on to plan.
2. **Nightly sweep (backup).** The scheduled job catches every issue nobody has touched, so the Planning board shows the whole backlog, and re-sorts answered or changed issues. Issues sorted on touch already carry a label and a card, so Step 1 skips them.

The rest of this page is written for the nightly job. One scheduled job, every night, across the projects on the allowlist below. It reads every open issue that has not been sorted, decides how much drawing it needs before it can be planned, and says so on the issue. It never plans, builds, or moves anything.

The job is the Claude desktop scheduled task `nightly-sort`. Its prompt only says "follow SORT.md", so **change the rules here, never in the task**. Plan and reasoning: `docs/plans/2026-09-24-001-feat-sort-stage-planning-board.md`. Issue: MCR-1797.

## Allowlist

Projects the job sorts, in Linear project names. Add the next one only after Zack has skimmed the last one's cards in a morning. This rollout is the backfill; there is no separate backfill job.

| Project | Joined | Notes |
|---|---|---|
| Pulse | 2026-09-24 | trial-sorted by hand the same day (23 issues) |

Next, smallest first: Saidso, O2 Quoting, Operating System, Argus, Sonar, telos, Motus, then the rest.

**Cap:** 60 issues per run. Anything left waits for the next night, oldest first. A big project takes a few nights to backfill; that is fine.

## Step 1: Find the work

For each allowlisted project, list open issues (state type backlog or unstarted: Backlog, Todo). An issue is **eligible** when any of these holds:

1. **Unsorted:** no `design:*` label, and it is not `spec-ready`, `deferred`, or `ops`.
2. **Answered:** its sort card has a reply (a comment whose parent is the card) created after the card's `updatedAt`. This holds with or without `sort:needs-answers`: placed issues can carry questions too.
3. **Labeled by hand:** it has a `design:*` label but no sort card, and it is not `spec-ready`, `deferred`, or `ops`. Keep the rung unless it clearly does not fit the table; if you change it, say why on the card's Design line.
4. **Changed:** it has a sort card, and the issue's `updatedAt` is more than 10 minutes after the card's `updatedAt` (the margin absorbs the job's own label writes), and it is not `spec-ready`, `deferred`, or `ops`.

The sort card is the one top-level comment whose body starts with `Sort card`. More than one is a bug: keep the newest, edit it, and say so in the run log.

Work oldest first (`createdAt`) up to the cap.

## Step 2: Read

Per issue, read: title, description, labels, milestone, parent issue, blocking/related links, comments (including every reply in the sort card's thread... those are Zack's answers and they win over the description). If it has `prd-source`, read the PRD it links. If the project's repo is on this Mac (find the `.linear-project.json` under `~/Developer` whose `name` matches the project), look at the current screens the issue touches: route or view files, component names. **Read-only on code:** no branches, no edits, no builds.

Delegate the reading to cheap read-only subagents where the harness allows (DISPATCH: haiku reads). The rung call itself is judgment and stays in the main thread on a mid or frontier model.

## Step 3: Decide the rung

Pick the **first rung that fits, from the top**. The table is the one rule; MANUAL §2 Stage 2 carries the same table with the recipes.

| Rung | Fits when |
|---|---|
| `design:product` | A new app. Nothing existing to extend. Only when there is no existing app, never for a big feature inside one |
| `design:journey` | Inside an existing app: 3+ connected new screens, a new interaction model (voice, camera, share sheet, gestures), new navigation, the core loop's screens change, or a surface users will form a habit on |
| `design:screens` | 1 or 2 new screens or panels, or more than half of one screen changes |
| `design:tweak` | A user would **see** a change on an existing screen whose layout survives: a field, a state, a button, copy, a mobile fix |
| `design:none` | Nothing a user sees changes: infra, data, API, jobs, tests, docs. **Behavior-only bug fixes are `none`**, even on a screen |

Rules learned in the trial:

- **Cannot place it confidently → `sort:needs-answers`**, with 1 to 3 specific questions a person can answer in a line each. Still set your best-guess rung if you have one at medium confidence; leave the rung off only when you truly cannot guess.
- **Questions are allowed on a placed issue** when they do not block the rung. Those issues do not get `sort:needs-answers`.
- **Cancel candidate** means another issue has overtaken this one (duplicate, superseded by a newer plan or PRD). Age alone never makes a cancel candidate; 60+ days old only earns a note in the card.
- **Owning repo:** when the work lives outside the project's main repo, name that repo in the card's Tool line.
- **Group:** issues that change the same screens are one group; they get one canvas and one design block. Name the other members by ID.

## Step 4: Write

Order matters: labels first, card last, so the card's `updatedAt` is the newest thing on the issue.

1. **Labels** (only these, only additively except as stated):
   - Set exactly one `design:*`. On a re-sort that changes the rung, remove the old one.
   - Add `sort:needs-answers` when it cannot place the issue; remove it when a re-sort places it.
   - Add one `flow:*` only if the issue has none (`flow:design` new surface, architecture, auth/data/payments or hard to reverse; `flow:standard` a meaty feature in known territory; `flow:ship` small and reversible). Never change an existing `flow:*`.
2. **Sort card.** Post it as a top-level comment, or **edit the existing card in place**. Never post a second card, never reply in the card's thread.

```
Sort card (YYYY-MM-DD, confidence: high | medium | low, weak spot: none | problem | acceptance | context | risk)
What it is: <one plain sentence a non-engineer understands>
UI: none | small visible change | new screen(s) | new journey | new app
Design: design:<rung>
Screens to mock: 1) <screen name>  2) <screen name>      (or "none")
Tool: <Claude Design (<repo> repo), one artboard each + <states>> | <before-screenshot + acceptance criteria> | none
Group: <MCR-… (same screens)> | none. Duplicate of: <MCR-…> | none
Next step: <plan: /ce-plan, then /packets> | <design block, then /ce-plan, then /packets> | <answer questions, then …> | <cancel candidate: why>
Questions: <1) … 2) …> | none
```

- **Weak spot** names the biggest readiness gap: the problem is unclear, acceptance is missing, context is missing, or the risk is unnamed.
- On a re-sort, keep the answered questions out of the new card (the thread has them) and ask only what is still open.

## Never

Plan, build, branch, or open a PR. Change an issue's status, priority, milestone, assignee, title, or description. Close or cancel anything (cancel candidates are only named). Add labels other than the ones in Step 4. Notify anyone: the morning brief and the Pulse Planning board read `sort:needs-answers` from Linear themselves. Compute Today's pick: Pulse does that.

## Step 5: Log

Append one line per project to `~/Library/Logs/software-factory/sort.log` (create it if missing):

```
2026-09-24T23:31 Pulse: eligible 14, sorted 12 (none 6, tweak 3, screens 2, journey 1, product 0), needs answers 2, re-sorted 3, left for tomorrow 0, errors 0
```

End the run with a brief for Zack in the same shape, plus the IDs that went to `sort:needs-answers` and any error in one line each. Nothing else.

## Identity

Cards should post under a Linear agent identity, not as Zack. Until that identity exists (MCR-1797 residual), the job posts through the Linear connection it has, and the `Sort card (...)` first line is what marks a card as the machine's.
