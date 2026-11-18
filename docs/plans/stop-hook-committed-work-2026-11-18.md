---
Created: 2026-11-18
Flow: standard
Linear Project: Workflow
Linear Issue: MCR-4664
Linear Branch: zack/mcr-4664-close-two-gaps-where-a-red-turn-slips-past-the
Task: The Stop hook checks committed work and gives a timed-out check one real retry.
---

## Research decision

- Decision: none needed
- Evidence: internal tooling; the one external fact (Claude Code's hook timeout) is read from the official docs below.
- Additional research: none

## The two gaps

- Committed work is never checked: the hook only sees uncommitted and untracked files, and agents commit before stopping.
- A cold build uses up the one block: a cold motus `swift test` takes ~112 s, the budget is 90 s, and the next stop has `stop_hook_active: true`, so it exits 0 with no real result.

## Design

- Changed files = merge-base..HEAD, plus uncommitted, plus untracked, deduplicated. Base = `git merge-base HEAD` against `origin/HEAD`, else `origin/main`, else `origin/master`; none resolves: today's behaviour, silently.
- Deleted files are passed as today (uncommitted deletions already are), committed ones too.
- Over 150 files on the branch: check only the HEAD commit plus uncommitted and untracked, with one stderr note. The note alone never blocks.
- A timeout is told apart from a failure. A timeout blocks with "timed out, likely a cold build, the work is cached, the next stop runs it again" and writes `stop-fast-check.timeout` (the check's name) in the worktree's own git dir.
- Next run with the marker: delete it first, then run for real even when `stop_hook_active` is true. Failure blocks, pass exits 0, a second timeout exits 0 with a note. No marker: `stop_hook_active: true` exits 0 as today. Marker cannot be written: as today.
- Bound: at most two blocked stops in a row.
- `install-claude-hooks.mjs` writes `timeout` = budget + 30 (120 s) on the Stop entry, and adds it to an existing entry that lacks it.

## Claude Code hook timeouts (https://code.claude.com/docs/en/hooks, read 2026-11-18)

- `timeout` is in seconds; the default for a `command` hook is 600.
- A hook that reaches its timeout is cancelled and its output discarded, so it renders no decision: on a Stop hook the stop goes through.
- `onFailure: "block"` has no effect on Stop hooks.

## Risks

- A large branch diff makes `vitest related` slow: capped at 150 files.
- A branch-wide check may surface a red that predates the session: that is the point; the agent sees it and fixes it.
- The marker could outlive a run if the hook is killed between writing it and exiting: it is deleted on the next run, which then runs for real once.

## Verification

- `hooks/stop-fast-check.test.sh`: committed-only change, default branch clean, no origin ref, over-cap, `when` on committed files, all four timeout outcomes, the timeout → failure → `stop_hook_active` → exit 0 bound, marker per worktree, read-only git dir.
- `scripts/install-claude-hooks.test.sh`: new entry has `timeout`, an existing entry without it gets it.
- `scripts/hooks-audit.sh`: adds committed red per repo and a cold motus case; run once for real.
