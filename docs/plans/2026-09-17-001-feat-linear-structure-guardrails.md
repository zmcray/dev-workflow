---
Created: 2026-09-17
Flow: standard
Linear Project: none (dev-workflow is not linked)
Linear Issue: none
Task: Make Linear readable by the owner... every agent-created issue lands in a milestone with a priority and a flow label, and wrap reports hygiene counts.
---

# Linear structure guardrails

Source: `telos/docs/checkpoints/2026-09-17-linear-visibility-handoff.md` (audit: 117 of 224 Telos issues had no milestone).

## Decisions (Zack, 2026-09-17)

- Grouping: stay on **one project per repo with prefixed milestones** (`<Epic> N: <Outcome>`, `<Epic>: hardening`, `<Epic>: later`). Revisit project-per-epic after the guardrails hold for a few weeks; blocker is `.linear-project.json` assuming one project.
- Rollout: two waves. Wave 1 stops new orphans; wave 2 fixes the issue writers.
- Historical milestones in Telos stay as the audit trail.

## Design

Rules live once, in a `## Linear structure` section of `AGENTS.workflow.md`. Skills point to it and add only their own lines. Enforcement is the hygiene check (counts, target zero) printed by wrap and status, not the prose.

## Wave 1 (stops new orphans)

- [x] `AGENTS.workflow.md`: add Linear structure section; tighten the Residuals bullet and Session close
- [x] `commands/zmcray-wrap.md`: project status update + hygiene check
- [x] `commands/zmcray-build.md` (+ execute by reference): residual filing contract handed to /lfg, verified after
- [x] `commands/zmcray-status.md`: hygiene readout

## Wave 2 (issue writers)

- [x] `commands/zmcray-plan.md`: issue creation contract, children inherit, order as links
- [x] `commands/caspian.md`: one initiative per product, outcome milestones, REFRESH re-homes, no mirror labels
- [x] `commands/zmcray-kickoff.md`: shelf milestones + one-time saved-view instructions
- [x] `commands/goal.md`: milestone match by prefix
- [x] Codex skill copies under `codex/skills/` mirrored (wrap, build, plan)
- [ ] `/buildnote` (claude.ai skill, not in this repo): lands in `<Epic>: later` or asks for the milestone. Needs editing in claude.ai.

## Deploy

`cp commands/*.md ~/.claude/commands/` then `bash deploy-agents-md.sh --dry-run` and apply.
