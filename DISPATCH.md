# Dispatch map

How a chunk's labels turn into an agent run. This is the ONE place model names appear. Issues and packets never name a model; they carry a `tier:*` label, and whoever dispatches (a `/goal` run, a Cursor cloud agent, Codex) reads this table. Re-check it monthly with the D-015 audit... model names and prices move fast.

## Tier → model

| Tier | Claude Code | Cursor cloud agent | Codex |
|---|---|---|---|
| `tier:mechanical` | `haiku` | cheapest fast model Cursor offers | default |
| `tier:moderate` | `sonnet` | mid-tier model | default |
| `tier:judgment` | frontier (`opus` / Fable), main thread | frontier model | highest reasoning setting |

The Cursor column is intent, not verified model IDs. Cursor's cloud agents take a model choice per agent launch; fill in the exact names from Cursor's current model list when the lane is wired (MCR-1412), and keep them here only.

**Escalate on failure, not suspicion.** A chunk that fails its checks at one tier is retried once, one tier up. Two failed tiers means the chunk was mis-tiered or too big: stop, comment on the issue, send it back to a spec day.

## What may run at the same time

A **wave** is every `spec-ready` chunk that is unblocked and whose file scope overlaps no other chunk in the wave. One agent, one chunk, one isolated environment. **Build in parallel, merge one at a time:** before merging, rebase on fresh `main` and re-run the smoke gate. Practical ceiling: 6–10 concurrent. Hitting it means PRs are not merging fast enough, which is the real problem.

## When the night ends

| Ending | Meaning | What happens |
|---|---|---|
| Queue empty | normal | stop; morning digest says so |
| Budget stop | normal | credits or plan headroom ran out; remaining chunks stay `spec-ready` |
| Hard stop | needs a human | red baseline, unmergeable PR, scope kick-back, anything destructive |

Fallback when one harness runs dry: Claude Code → Cursor → Codex → pause. Record who took a chunk with `lane:*`. Under a tight budget, spend frontier runs on `tier:judgment` chunks only... a plan that is mostly mechanical and moderate is what makes limited credit go furthest.

## Status (2026-09-21)

`tier:*` labels and chunk rules: live in the canonical AGENTS.md block and in `/to-chunks` (the bridge from `/ce-plan` to Linear). `/zmcray-build` reads the tier as advice for its delegated model choice. Tier-aware model choice inside `/goal`: not built. Parallel waves and the Cursor lane: not built (Phase 2, MCR-1412). Until then `/goal` runs one chunk at a time and the tier label is advisory.
