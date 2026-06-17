---
name: zmcray-wrap
description: End a build session cleanly. Auto-syncs Linear, captures compound, syncs PROJECT.md, commits.
argument-hint: "[done | hold | notes on what happened]"
---

# Wrap

Close out a build session. Captures learnings, syncs project status, commits work, syncs Linear, and flags loose ends.

**Argument modes:**
- `(no arg)` ... default. Moves Linear issue to **In Review**, posts session summary comment.
- `done` ... ships the issue. Moves Linear issue to **Done**, posts session summary comment.
- `hold` ... session ended but feature isn't review-ready. Leaves Linear issue in **In Progress**, posts a "paused here" comment.
- Free text ... treated as session notes. Default Linear behavior (In Review) applies.

## Step 1: Read Flow

Read the active plan's `Flow:` metadata field (design, standard, or ship). If the plan predates flow routing, fall back to CLAUDE.md's `## Build Tier` section and map Tier 1 → design, Tier 2 → standard, Tier 3 → ship.

## Step 2: Check Uncommitted Work

Run `git status` and `git diff --stat`. If there are uncommitted changes:
- Summarize what changed in one line
- Suggest a conventional commit message. **If the active plan has a Linear Issue ID, append `[ISSUE-ID]` to the message.**
- Wait for user approval before committing

If working tree is clean, say so and move on.

## Step 3: Compound (design and standard flows only)

If the flow is design or standard, and `/ce-compound` has NOT already been run in this session:
- Run `/ce-compound`
- Capture: what worked, what the plan missed, any new patterns or pitfalls
- This writes to the `## Compound Learnings` section in CLAUDE.md

If the flow is ship, skip this step.

## Step 4: Update PROJECT.md (Lightweight)

Open PROJECT.md at the project root.

1. **Current Status:** Replace with one line summarizing what shipped this session and where the project stands now. Be specific: "Upload flow implemented and tested. Next: notification system."

2. **Build Log:** Append a row with today's date and a brief summary of the session. Example: "Day 6 upload flow shipped. 55 tests passing. Plan archived. Linear: MCR-123 → In Review."

Skip milestones-update logic. Milestones now live in Linear as projects/cycles or as plan files; PROJECT.md no longer carries them.

If PROJECT.md doesn't exist, note it in the session summary and move on. Don't block the wrap.

## Step 5: Archive Plan

Find the most recent plan file in `docs/plans/` (not in archive/).
- Add a `## Outcome` section at the bottom: shipped, partially shipped, or abandoned
- Move it to `docs/plans/archive/`

## Step 6: Sync Linear

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

## Step 7: Flag Loose Ends

Check for:
- Any `TODO` or `FIXME` comments added during this session (search git diff)
- Any review findings that were deferred (not resolved)
- Any tests that are skipped or failing

If any exist, list them in a short summary. If none, say "Clean session, nothing outstanding."

## Step 8: Session Summary

Print a brief wrap-up:
```
Session: [what was built]
Flow: [design|standard|ship]
PR: [link + CI status, or none]
Commits: [number of commits this session]
Compound: [captured / skipped]
PROJECT.md: [updated / not found]
Linear: [ISSUE-ID → In Review | Done | In Progress (held) | none]
Loose ends: [none | list]
```

## Notes

- Never auto-commit without user approval.
- Never auto-merge or push to remote. Wrap is local-state only unless the user explicitly asks to push. (/lfg already pushed and opened the PR during build... wrap never merges it. Merging is the user's call.)
- If the user provides notes in the argument (and it isn't `done` or `hold`), include them in the compound capture and the Linear comment.
- Keep the summary under 10 lines. The user is done for the day.
- The Linear sync is the piece that prevents board drift. If you skip it, you defeat the purpose of the linkage. Surface any sync failures loudly.
