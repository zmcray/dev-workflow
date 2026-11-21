# Night spec check: the factory specs small flow:ship issues itself

- **Created:** 2026-11-21
- **Flow:** standard
- **Tier:** moderate
- **Linear Project:** Workflow
- **Linear Issue:** MCR-4800 (milestone Factory: hardening)
- **Linear Branch:** zack/mcr-4800-night-factory-specs-small-flowship-backlog
- **Task:** Add a `/factory` step that turns small, no-design `flow:ship` backlog issues into `spec-ready` chunks, so the same night can build them.

## Why

- The night builds only `spec-ready` issues. Only `/packets` sets `spec-ready`, and only from a `/ce-plan` plan.
- On Pulse (2026-11-21): 29 of about 350 open backlog issues are `spec-ready`. About 87 are `flow:ship` with `design:none` or `design:tweak`.
- `rules/build.md` already says `flow:ship` needs no planning ("Execute (the plan gate is the only planning)"). So these issues are buildable in principle but can never reach the night.
- D-038 (MCR-4778) let the night build `gate:human` chunks. It surfaced one more Pulse issue. Supply, not gates, is the limit.

## What changes

1. **`/factory` Step 1c: Spec check** (`commands/factory.md`), after Step 1b (asks) and before Step 2 (queue read), so tonight's queue sees what it specced.
   - Candidates: open (backlog or unstarted), unblocked `flow:ship` issues with `design:none` or `design:tweak`; no `gate:human`, `ops`, `deferred`, `needs-canvas`, `canvas:agent`, `spec-ready` or `sort:needs-answers` (unless answered since the last spec-check comment); not on a `later` shelf; no `## Build packet` yet (one with a packet but no `spec-ready` was held back on purpose by `/packets`).
   - Order: priority, then oldest first.
   - Caps: `max_specs` (default 10) specced, and at most 25 read, per night.
   - Per issue: read the issue and the code on the default branch. Skip with a one-line comment and `sort:needs-answers` when it is `already-fixed`, `obsolete`, `escalation`, `needs-person`, `vague`, `needs-decision` or `too-big`. Never close or cancel.
   - Otherwise write the packet (house format, `Spec: night spec check <run_id>`), add `tier:mechanical` or `tier:moderate` and `spec-ready`, comment one line.
   - `--dry-run` runs it read-only and prints what it would do. `--check` skips it.
2. **Ledger and report.** A new top-level `specced` array (one row per issue read, specced or skipped with reason). A `Spec check:` line in the shift plan and a `Specced:` line on the status update. Item rows for issues the night specced add `"night_specced": true`, so a few nights of results can be judged.
3. **Nothing loosens downstream.** Specced issues go through the normal queue and build rules: merge on green, one chunk per PR, escalation still bumps to the `flow:design` review, Red main still reverts.
4. **`rules/goal-runs.md`.** State that the spec check is a defined `/factory` step and the only exception to "never improvise work". A `/goal` run with a named objective does not run it.
5. **`rules/build.md`.** Under Flow routing: on the night shift a `flow:ship` issue gets its packet from the spec check.
6. **`factory/templates/build-packet.md`.** The grilling rule gets its one exception: a night spec-check packet, `flow:ship` only, where anything that would need a question is skipped instead.
7. **`factory/DISPATCH.md`** (Night budget: `max_specs`), **`factory/ARCHITECTURE.md`** (Decompose: second source of `spec-ready`), **`factory/DECISIONS.md`** (D-039).
8. **Not changed:** `AGENTS.workflow.md`. The shared core points at `rules/` and needs no edit, so there is no 23-repo sync fan-out.

## Judgment calls

- **`sort:needs-answers` for every skip.** The brief named it. It is the label the Planning board already shows as "Needs answers", and it keeps the issue out of the next night's spec check. Re-entry mirrors the sort's "Answered" rule: a reply to the spec-check comment, or the label removed.
- **`tier:judgment` is never set by the night.** An issue that needs it is `too-big` for an unplanned spec.
- **Read cap of 25** next to the spec cap of 10, so a stale backlog full of skips cannot eat the start of the night.
- **Oldest first** within a priority, matching the queue's order. It also walks the stale October backlog, turning each stale issue into one "close it?" question for Zack instead of leaving it silent.
- **Step 1c, not part of Step 2.** Step 2 is a pure read and `--dry-run` must stay safe; Step 1c writes to Linear, so it gets its own step and its own dry-run behaviour.

## Not now: flow:standard

`flow:standard` stays out. It is the next candidate once a few nights of `flow:ship` results are in (built vs failed vs reverted for `night_specced` rows). Its rule would need a plan (Plan > Execute per `rules/build.md`), so it is a bigger change than this one.

## Research decision

- Decision: none needed
- Evidence: internal workflow change; the measurement is the Pulse backlog read above and the hand-read saved with MCR-4800.
- Additional research: none

## Verification

- `deploy-skills.sh` runs clean; deployed `~/.claude/commands/factory.md` matches the source.
- A read-only hand-read of Step 1c against Pulse's backlog: how many would be specced tonight, which ones, and why each skip. Saved and summarized on MCR-4800.
