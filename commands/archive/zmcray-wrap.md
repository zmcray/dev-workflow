---
name: zmcray-wrap
description: End a build session cleanly. Auto-syncs Linear, posts the project status update, runs the Linear hygiene check, captures compound, syncs PROJECT.md, commits.
argument-hint: "[done | hold | notes on what happened]"
---

# Wrap

Close out a build session. Captures learnings, syncs project status, commits work, syncs Linear, and flags loose ends.

**Argument modes:**
- `(no arg)` ... default. Moves Linear issue to **In Review**, posts session summary comment.
- `done` ... ships the issue. Moves Linear issue to **Done**, posts session summary comment.
- `hold` ... session ended but feature isn't review-ready. Leaves Linear issue in **In Progress**, posts a "paused here" comment.
- Free text ... treated as session notes. Default Linear behavior (In Review) applies.

## Delegation & Model Policy

Most of a wrap is mechanical, so most of a wrap should not run on the frontier model. Apply the AGENTS.md Delegation section: **assess the tier before each step that runs more than a couple of tool calls and state it in one line** (`Delegating [work] → haiku ([why])`).

- **`haiku`:** the Step 2 `git status` / `git diff --stat` summary, the Step 3 diff-range resolution, the Step 5 PROJECT.md and Build Log edits, the Step 6 plan-file `## Outcome` + archive move, the Step 7 Linear comment formatting, the Step 7b hygiene counts, and the Step 8 TODO/FIXME and skipped-test scans. All of these return a short summary to the main thread, never raw output.
- **`sonnet`:** applying a batch of mechanical review fixes from Step 3 once the main thread has decided each one is a fix, and drafting the compound capture text.
- **Main thread (frontier):** judging each review finding (fix vs. file to Linear), the commit-message call and its approval gate, the compound learnings themselves, and anything flagged as a loose end.
- **GitHub reads on `haiku`:** the PR link + CI status for the Step 9 summary is a delegated `gh` lookup returning two fields, not a main-thread investigation.

## Step 1: Read Flow

Read the active plan's `Flow:` metadata field (design, standard, or ship). If the plan predates flow routing, fall back to CLAUDE.md's `## Build Tier` section and map Tier 1 → design, Tier 2 → standard, Tier 3 → ship.

## Step 2: Check Uncommitted Work

Run `git status` and `git diff --stat`. If there are uncommitted changes:
- Summarize what changed in one line
- Suggest a conventional commit message. **If the active plan has a Linear Issue ID, append `[ISSUE-ID]` to the message.**
- Wait for user approval before committing

If working tree is clean, say so and move on.

## Step 3: Code Review & Fix

Always runs, every wrap — /lfg's in-pipeline review is not a substitute (in practice /ce-code-review surfaces findings /lfg's pass misses). Run `/ce-code-review` over the session's changes. Resolve the diff range first — the PR is usually already squash-merged by wrap time, so a plain branch-vs-default diff would be empty:

1. **Preferred:** read `Base Commit:` from the active plan's metadata header and review `git diff [base-commit]..HEAD` (on the default branch post-merge, this is exactly the session's work; on an unmerged feature branch it's the same range).
2. **Fallback (no Base Commit field):** on an unmerged feature branch, diff against the merge-base with the default branch (`git diff $(git merge-base [default-branch] HEAD)..HEAD`). If already merged, review the session's squash commit(s) — identify them by the `[ISSUE-ID]` tag or the session's start time in `git log`.

State the range in one line ("Reviewing [base]..[head], N files"), then run the review against it.

- Fix **every** finding it reports — don't defer to Linear from this pass; the point is to enter compound with a clean slate.
- Commit the fixes with a conventional message (append `[ISSUE-ID]` if the plan has one).
- If a finding is genuinely unfixable right now (needs a scope decision, external dependency), file it to Linear under the issue creation contract (AGENTS.md > Linear structure: project, `<Epic>: hardening` milestone, priority, `flow:*` label) and list it in Step 8's loose ends — but that's the exception, not the default.
- If the review comes back clean, say so and move on.

## Step 4: Compound (design and standard flows only)

If the flow is design or standard, and `/ce-compound` has NOT already been run in this session:
- Run `/ce-compound`
- Capture: what worked, what the plan missed, any new patterns or pitfalls
- This writes to the `## Compound Learnings` section in CLAUDE.md

If the flow is ship, skip this step.

## Step 5: Update PROJECT.md (Lightweight)

Open PROJECT.md at the project root.

1. **Current Status:** Replace with one line summarizing what shipped this session and where the project stands now. Be specific: "Upload flow implemented and tested. Next: notification system."

2. **Build Log:** Append a row with today's date and a brief summary of the session. Example: "Day 6 upload flow shipped. 55 tests passing. Plan archived. Linear: MCR-123 → In Review."

Skip milestones-update logic. Milestones live in Linear as project milestones (AGENTS.md > Linear structure); PROJECT.md no longer carries them.

If PROJECT.md doesn't exist, note it in the session summary and move on. Don't block the wrap.

## Step 6: Archive Plan

Find the most recent plan file in `docs/plans/` (not in archive/).
- Add a `## Outcome` section at the bottom: shipped, partially shipped, or abandoned
- Move it to `docs/plans/archive/`

## Step 7: Sync Linear

Read the (now-archived) plan file's metadata header. Look for `Linear Issue:` value.

**If no Linear issue is linked**, skip this step entirely.

**If a Linear issue ID is present**, update Linear based on the argument mode:

### Default mode (no arg or free-text notes)
1. Move the issue's state to **In Review**.
2. Post a comment in this format:

   ```
   Session wrapped — In Review.
   
   **Shipped:** [one-line current status from PROJECT.md]
   **PR:** [link from /lfg, or "none"] (CI: [green/red])
   **Commits:** [N] this session ([latest hash])
   **Tests:** [passing/failing/skipped count]
   **Files touched:** [count]
   **Residuals filed to Linear:** [N or none]
   **Loose ends:** [none, or short list]
   
   Plan archived: docs/plans/archive/[plan-filename]
   ```

### `done` mode
1. Move the issue's state to **Done**.
2. Post the same comment format but lead with `Session wrapped — Shipped to Done.`

### `hold` mode
1. Leave the issue in **In Progress**.
2. Post a comment: `Session paused. [User-provided notes if any]. Picking up here next session.`

If Linear is unreachable, log the failure inline in the chat and append it to PROJECT.md's Build Log row so you can retry manually.

## Step 7a: Project Status Update (the human's glance)

Runs in default and `done` modes whenever the repo has a `.linear-project.json`, even if no issue is linked. Post a Linear **project status update** on the project (`save_status_update`), not an issue comment. Three to six lines, plain words, no jargon:

```
Shipped: [what a user can now do, with issue IDs]
Next: [the next 1-3 issues in order, from the milestone's Order line]
Blocked: [none, or what and why]
Needs Zack: [none, or the specific decision/action]
```

Set health to on track / at risk / off track by whether the current milestone's next issue is unblocked. If the session changed the order of work, update the milestone description's `Order:` line in the same step. In `hold` mode, skip the update unless something is blocked or needs Zack.

## Step 7b: Linear Hygiene Check

Read-only query over the project's open issues (delegate to `haiku`; it returns five numbers and the offending IDs, never the issue bodies). Counts per AGENTS.md > Linear structure, targets all zero:

```
Linear hygiene: no-milestone [N] | no-priority [N] | no-flow [N] | in-historical [N] | milestones missing Outcome/Order [N]
```

If any count is non-zero: fix every offender **this session created** (residuals, follow-ups), then list the remaining IDs in Step 8's loose ends. Do not bulk-edit issues from other sessions without saying so.

## Step 8: Flag Loose Ends

Check for:
- Any `TODO` or `FIXME` comments added during this session (search git diff)
- Any review findings that were deferred (not resolved)
- Any tests that are skipped or failing

If any exist, list them in a short summary. If none, say "Clean session, nothing outstanding."

## Step 9: Session Summary

Print a brief wrap-up:
```
Session: [what was built]
Flow: [design|standard|ship]
PR: [link + CI status + merged/unmerged, or none]
Commits: [number of commits this session]
Review: [N findings fixed / clean / skipped]
Compound: [captured / skipped]
PROJECT.md: [updated / not found]
Linear: [ISSUE-ID → In Review | Done | In Progress (held) | none]
Status update: [posted / skipped (hold) / failed]
Hygiene: [all zero | no-milestone N, no-priority N, no-flow N, in-historical N, milestones N]
Loose ends: [none | list]
```

## Notes

- Never auto-commit without user approval.
- Never merge or push to remote from wrap. Wrap is local-state only unless the user explicitly asks to push. (Merging happens in /zmcray-build Step 8's auto-merge, gated on green CI — by wrap time the PR is usually already merged. If auto-merge was skipped or failed, note the unmerged PR as a loose end; don't merge it here.)
- If the user provides notes in the argument (and it isn't `done` or `hold`), include them in the compound capture and the Linear comment.
- Keep the summary under 12 lines. The user is done for the day.
- The Linear sync is the piece that prevents board drift. If you skip it, you defeat the purpose of the linkage. Surface any sync failures loudly.
