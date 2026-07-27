---
name: zmcray-plan
description: Run the McRay batch planning loop from Codex. Use when the user invokes /zmcray:plan, $zmcray-plan, asks to plan a PRD or feature list into execution-ready issues, or wants all implementation decisions made up front before an autonomous execution run.
---

# ZMcRay Plan

Run the batch planning workflow defined by the canonical source at `~/Developer/dev-workflow/commands/zmcray-plan.md`. Read that file and execute it faithfully; this twin only maps tool differences. Treat `/zmcray:plan` as an alias for this skill.

This skill is a coordinator. When the workflow names a skill (`$ce-plan`, `$office-hours`, `$plan-ceo-review`, `$plan-eng-review`), open that skill's SKILL.md and execute it as a blocking sub-workflow. Do not replace named skill gates with a self-review unless the skill file is unavailable... in that case run the native fallback from `AGENTS.md` and say so.

## Codex mappings

- **Modes:** default = taste mode (pause only for product-taste calls, batched); `--auto` = never pause, log every call in the issue's `## Planning Decisions`; `--review` = pause per feature spec.
- **Delegation:** where the canonical file dispatches subagents, use Codex's equivalent (parallel tasks / spawned sessions). Keep flow triage, quality gating, and taste calls in the main thread. Map tiers by intent: mechanical → cheapest, spec drafting → mid, judgment → main thread.
- **Effort:** map effort levels to Codex's reasoning control.
- **Linear:** use the Linear MCP. If unavailable, hold gated specs and write them to `docs/plans/pending-issues-[date].md` per the canonical Notes... never lose a gated spec.

## Non-negotiables (same as canonical)

- Every logged issue scores ≥7 on the executability gate or does not get `spec-ready`.
- Exactly one `flow:*` label + `spec-ready` per issue; `blocked by` relations encode execution order.
- Advisor pass (scope-guardian / feasibility / adversarial, confidence-gated) runs before the plan is declared done.
- PRD kick-back rule: scope beyond a `prd-source` PRD goes back to $caspian, never silently expanded.
- Issues that change workflows, test topology, artifacts, schedules, runner labels, or monorepo CI routing include the canonical `## CI Impact` section and pass its required-check compatibility gate.
