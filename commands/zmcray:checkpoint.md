---
name: zmcray:checkpoint
description: Save or resume build state across sessions. Tool-neutral storage in docs/checkpoints/.
argument-hint: "[save|resume|list]"
---

# Checkpoint

Save and resume build context across sessions. Solves the cold-start problem when picking up work after closing a session. Storage is repo-local and tool-neutral (`docs/checkpoints/`), so a checkpoint saved on one harness resumes on another.

## Usage

- `/zmcray:checkpoint save` ... snapshot current state
- `/zmcray:checkpoint resume` ... load most recent (or a named one)
- `/zmcray:checkpoint list` ... show all saved checkpoints
- `/zmcray:checkpoint` (no arg) ... if a checkpoint exists, offer to resume; if mid-build, offer to save

## Save

Write to `docs/checkpoints/checkpoint-[YYYY-MM-DD]-[HH-MM].md`. (Create `docs/checkpoints/` if missing.)

### What to capture

```markdown
# Checkpoint: [short description]
**Saved:** [timestamp]
**Branch:** [current git branch]
**Flow:** [design|standard|ship, from the active plan's Flow field]
**Linear Project:** [from ./.linear-project.json, or "none"]
**Linear Issue:** [ID from active plan metadata, or "none"]
**Linear State:** [current state pulled from Linear, or "n/a"]

## Active Plan
[Path to current plan file in docs/plans/, or "none"]

## Build Loop Position
[Which phase was last completed, e.g. "flow:standard ... Plan done, Execute in progress (/lfg work phase)"]

## Git State
- Branch: [branch name]
- Uncommitted changes: [yes/no, summary if yes]
- Last commit: [hash + message]

## Open Items
[Unresolved review findings/residuals, TODOs, failing tests, deferred decisions]

## Context Notes
[Anything the user said to remember, or key decisions not yet in AGENTS.md/PROJECT.md]
```

After saving, print: `Checkpoint saved. Flow: [flow]. Linear: [ID -> state]. Resume with /zmcray:checkpoint resume`

## Resume

1. No argument: load the most recent checkpoint from `docs/checkpoints/`. If none there, also check the legacy path `.claude/checkpoints/` (older checkpoints predate the move).
2. If the user names a checkpoint or date, load that one.
3. Read the checkpoint file.
4. **If it has a Linear Issue ID, re-fetch the issue's current state and `flow:*` label from Linear.** Compare against saved values. Flag any drift (state changed, flow relabeled, reassigned) before resuming.
5. Present a brief summary: what was being built, where the build loop left off, Linear state (saved vs. current if drifted), open items.
6. Read the referenced plan file to restore full context.
7. Ask: "Ready to pick up from [phase]?"

Do NOT auto-resume execution. Always wait for confirmation.

## List

Scan `docs/checkpoints/` (and legacy `.claude/checkpoints/`) and print:

| Date | Branch | Flow | Linear | Description | Status |
|------|--------|------|--------|-------------|--------|

Status is "open" (unfinished build loop) or "closed" (build completed). Linear column shows the issue ID and last-saved state, or "—" if unlinked.

## Notes

- `/zmcray:wrap` should prompt to save a checkpoint if there is unfinished work.
- Checkpoints are lightweight pointers to plan files, git state, and Linear issue IDs, not full copies.
- Old checkpoints (>30 days, closed) can be cleaned up during folder cleanup.
- Never delete an open checkpoint without user approval.
- Drift detection on resume is a feature: if the issue moved while the checkpoint was cold, you want to know before resuming.
- Storage moved from `.claude/checkpoints/` to `docs/checkpoints/` so checkpoints are tool-neutral and visible in the repo. Resume/list still read the legacy path for backward compatibility.
