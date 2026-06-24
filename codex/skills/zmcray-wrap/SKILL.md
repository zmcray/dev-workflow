---
name: zmcray-wrap
description: End a McRay build session cleanly in Codex. Use when the user invokes /zmcray:wrap, $zmcray-wrap, says wrap, close the session, mark done or hold, or asks to sync Linear/PROJECT.md/plan archive/learnings after a build.
---

# ZMcRay Wrap

Close a build session using the repo's `AGENTS.md` session-close contract. Treat `/zmcray:wrap` as an alias for this skill.

## Modes

- No argument: move linked Linear issue to In Review and post a session summary.
- `done`: move linked Linear issue to Done and post a shipped summary.
- `hold`: leave linked Linear issue In Progress and post a paused summary.
- Free text: treat it as session notes and use default In Review behavior.

Never auto-merge. Never auto-commit without explicit user approval.

## 1. Read Flow

Find the active plan in `docs/plans/` or the most recent archived plan for this session. Read `Flow:` from the metadata. If missing, fall back to `AGENTS.md` or legacy `CLAUDE.md` build tier mapping: Tier 1 design, Tier 2 standard, Tier 3 ship.

## 2. Check Worktree

Run `git status` and `git diff --stat`. If changes are uncommitted, summarize them in one line, suggest a conventional commit message, append `[ISSUE-ID]` when the active plan has a Linear issue, and wait for user approval before committing.

If the tree is clean, say so and continue.

## 3. Capture Learning

For design and standard flows, run the native equivalent of `/ce-compound` if it has not already run: append a concise note to the repo learning location specified by `AGENTS.md` or `CLAUDE.md` covering what worked, what the plan missed, and any reusable pattern. Skip for ship flow.

## 4. Update PROJECT.md

If `PROJECT.md` exists, update:

- `## Current Status`: one specific line describing what shipped or where the project stands.
- `## Build Log`: append today's date and a short session row with tests, PR/CI, plan archive, and Linear issue when known.

If missing, note it in the summary and continue.

## 5. Archive Plan

Find the active plan file in `docs/plans/` excluding `archive/`. Add `## Outcome` at the bottom with shipped, partially shipped, held, or abandoned. Move it to `docs/plans/archive/`.

## 6. Sync Linear

Read the archived plan metadata for `Linear Issue:`. If none, skip Linear.

If linked and tools are available:

- Default/free-text: move to In Review.
- `done`: move to Done.
- `hold`: leave In Progress.

Post a concise comment with shipped summary, PR, CI, commit count, tests, files touched, residuals, loose ends, and archived plan path. If Linear is unreachable, append the failure to `PROJECT.md` build log and report it.

## 7. Flag Loose Ends

Search the session diff for newly added `TODO` or `FIXME`, deferred review findings, skipped tests, and failing tests. File residuals to Linear when appropriate. If none, say the session is clean.

## 8. Final Summary

Keep the closeout under 10 lines:

```text
Session: [what was built]
Flow: [design|standard|ship]
PR: [link + CI status, or none]
Commits: [count]
Compound: [captured/skipped]
PROJECT.md: [updated/not found]
Linear: [ISSUE-ID -> In Review|Done|In Progress|none]
Loose ends: [none|list]
```
