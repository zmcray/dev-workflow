---
name: zmcray-execute
description: Run the McRay autonomous batch execution loop from Codex. Use when the user invokes /zmcray:execute, $zmcray-execute, asks to burn down the spec-ready queue, or wants pre-planned Linear issues implemented end to end without prompts.
---

# ZMcRay Execute

Run the batch execution workflow defined by the canonical source at `~/Developer/dev-workflow/commands/zmcray-execute.md`. Read that file and execute it faithfully; this twin only maps tool differences. Treat `/zmcray:execute` as an alias for this skill.

**Always autonomous.** Never wait for input; state one-line decisions and log them to Linear. Hard stops from the canonical file hold: red baseline, dirty tree, CI red after fix attempts, unmergeable PR after one rebase retry, 3 failed fixes on one failure, materially invalidated spec, anything destructive outside spec scope.

This skill is a coordinator. When the workflow names a skill (`$lfg` / the CE execution pipeline, `$ce-code-review`, `$ce-compound`, `$codex` cross-model review), open that skill's SKILL.md and execute it as a blocking sub-workflow. If a named skill is unavailable, run the native fallback from `AGENTS.md` (implement on branch → tests → review → PR → CI-green → squash merge) and say so.

## Codex mappings

- **Queue:** unblocked `spec-ready` issues via the Linear MCP, dependency order first. No linkage or empty queue → stop.
- **Strictly sequential across issues;** parallelism only inside an issue. Merge issue N before branching N+1.
- **Spec gate & kick-back:** minor drift → adapt and note; material invalidation → remove `spec-ready`, comment, skip. Never improvise a plan mid-run.
- **CI impact:** require and honor `## CI Impact` for workflow/test-topology/artifact/schedule/runner/routing changes; apply the canonical CI cost discipline without weakening required coverage or rerunning unchanged failures.
- **Advisor pass:** flow:design PRs get an independent cross-model review (the $codex skill, or Codex's own adversarial review if running inside Codex... use a genuinely independent pass, not self-review).
- **Delegation/effort:** map subagent tiers and effort levels to Codex's equivalents by intent, never hard-coded model IDs.
- **After the run:** $ce-compound learnings, run summary to Linear, then $zmcray-wrap covering all issues.
