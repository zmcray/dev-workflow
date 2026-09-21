# Software Factory

The source of truth for how McRay Group builds software: a **two-shift factory** for iOS and web apps. Judgment happens with Zack in the loop during the day; production happens without him at night, in many small parallel agent runs that each ship a tiny diff.

This repo holds the strategy, architecture, decisions, and research behind the system. Linear holds execution state. Any agent (Claude Code, Codex, Cursor, or future harnesses) should be able to read this repo and understand what we are building, why, and how to operate inside it.

> **Status (2026-09-02):** Phase 1 in progress. Build-packet contract piloted in the argus repo; Linear labels live. This repo will eventually replace the `dev-workflow` repo as templates and docs migrate here.

## The model in one paragraph

Two shifts, one handoff artifact. **Day shift** (human in the loop): product council, mockup flows on an agent-legible canvas, specs with executable acceptance criteria, decomposition into atomic issues. **Night shift** (unattended): one agent per issue in an isolated environment, a verification ladder (tests, self-check against the approved artboard, independent cross-model review, CI), draft PRs for morning review, auto-merge on green for trusted task classes. The contract between the shifts is the **build packet** (see `templates/build-packet.md`). The factory scales by merging faster, not by adding agents.

## Repo map

| File | What it holds |
|---|---|
| `ARCHITECTURE.md` | The full system design: phases, lanes, labels, verification ladder, dispatch, iOS specifics |
| `DECISIONS.md` | Decision log: every load-bearing choice, its rationale, and what it is based on |
| `docs/research/2026-08-state-of-practice.md` | The research the design is grounded in (4 research passes, Aug 2026, with sources) |
| `MANUAL.md` | The operating manual: nine stages, the daily hour, chunks / waves / tiers, the week. **Start here for how to run it.** |
| `DISPATCH.md` | Tier → model map, parallel-wave rules, and how a night ends. The only place model names live |
| `templates/build-packet.md` | The canonical build-packet template that gates the night queue |
| `skills/` | Forked, factory-adapted agent skills (grilling, domain-modeling, code-review, wizard); provenance in `skills/UPSTREAM.md` |

## Operating rules (day one, non-negotiable)

1. **The build packet is the contract.** No issue enters the night queue without one.
2. **AGENTS.md is the single cross-harness instruction file** in every wired repo. Workflow rules live there only; harness-specific files carry tool mechanics only.
3. **Human gates at phase boundaries** (PRD, mockup canvas, decomposition, auto-merge graduation). Never mid-implementation supervision.
4. **Auto-merge is earned per task class**, starting with copy/config/contained fixes.
5. **Scale by merging faster, not by adding agents.** Merge queue and human review capacity are the ceilings.

## Execution state (Linear)

- Project: [Workflow](https://linear.app/mcraygroup/project/workflow-d5c9760515c7) (Mcraygroup team)
- Plan: [Two-Shift Factory — Implementation Plan](https://linear.app/mcraygroup/document/two-shift-factory-implementation-plan-0a82fd746c93)
- Phases: MCR-1411 (packet + gates) → MCR-1412 (supervised night lane) → MCR-1413 (auto-merge) ∥ MCR-1414 (iOS line) → MCR-1415 (best-of-N) → MCR-1416 (compounding, ongoing)
- OS roadmap objective: `os-two-shift-factory` in `os.objectives` (Supabase, mcray-os project)
- Research report (web rendering): [The Two-Shift Factory artifact](https://claude.ai/code/artifact/7c5ff443-e231-4af0-885d-a8f356c171fd)

## Harness lanes

Zack runs three harnesses deliberately, spreading tokens and learning:

| Harness | Lane |
|---|---|
| **Claude Code** | Day shift (council, design, decomposition, morning review) + the iOS line |
| **Cursor** | Web night fleet (cloud agents subscribed to the queue) |
| **Codex** | Independent cross-model review gate on all lanes + well-specced overflow |

Routing is a dispatch-time decision (`lane:*` labels); it never leaks into the packet.
