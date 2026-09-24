# Dispatch map

How a chunk's labels turn into an agent run. This is the ONE place model names appear. Issues and packets never name a model; they carry a `tier:*` label, and whoever dispatches (a `/goal` run, a Cursor cloud agent, Codex) reads this table. Re-check it monthly with the D-015 audit... model names and prices move fast.

## Tier → model

**Haiku never writes code.** The cheapest tier is for reading: repo exploration, log reduction, CI polling, duplicate checks, formatting a comment. Anything that produces a diff starts at `sonnet`.

| Tier | Claude Code | Cursor cloud agent | Codex |
|---|---|---|---|
| read-only subtask (no label; inside any run) | `haiku` | cheapest fast model | default |
| `tier:mechanical` | `sonnet` | mid-tier model | default |
| `tier:moderate` | `opus` | frontier model | highest reasoning setting |
| `tier:judgment` | `fable` (Fable / Mythos class), main thread | frontier model | highest reasoning setting |

The Cursor column is intent, not verified model IDs. Cursor's cloud agents take a model choice per agent launch; fill in the exact names from Cursor's current model list when the lane is wired (MCR-1412), and keep them here only.

**Escalate on failure, not suspicion.** A chunk that fails its checks at one tier is retried once, one tier up. Two failed tiers means the chunk was mis-tiered or too big: stop, comment on the issue, send it back to a spec day.

## What may run at the same time

A **wave** is every `spec-ready` chunk that is unblocked, carries neither `gate:human` nor `ops`, and whose file scope overlaps no other chunk in the wave. `gate:human` chunks are never dispatched unattended; they run on the day shift with the person's step scheduled up front. One agent, one chunk, one isolated environment. **Build in parallel, merge one at a time:** before merging, rebase on fresh `main` and re-run the smoke gate. Practical ceiling: 6–10 concurrent. Hitting it means PRs are not merging fast enough, which is the real problem.

## Night budget

`/factory` reads these defaults, then the `factory` key in the repo's `.linear-project.json`, then invocation flags. Stop time is local. No chunk starts after `stop_at` minus 45 minutes; nothing is killed mid-PR.

| Key | Default | iOS repos (single Mac runner) |
|---|---|---|
| `stop_at` | `06:00` | `06:00` |
| `max_chunks` merged per night | 6 | 3 |
| `concurrency` | 1 (sequential until the wave dispatcher lands; then ≤ CI runner slots) | 1, later 2 |
| `max_turns_per_chunk` | 150 | 150 |

Ledger: `docs/factory/runs/YYYY-MM-DD.json` in the repo, one row per chunk, written at chunk start and end. Argus reads these for the cross-repo digest later.

## When the night ends

| Ending | Meaning | What happens |
|---|---|---|
| Queue empty | normal | stop; morning digest says so |
| Chunk cap / deadline | normal | `/factory` budget reached between chunks; remaining chunks stay `spec-ready` |
| Budget stop | normal | credits or plan headroom ran out; remaining chunks stay `spec-ready` |
| Human park | needs a human, but only for that chunk | a step needs a person (visual judgment, credentials, device, outside party); branch pushed, draft PR, `gate:human` added, comment says what to do; run continues on the next unblocked chunk |
| Hard stop | needs a human | red baseline, unmergeable PR, scope kick-back, anything destructive |

Fallback when one harness runs dry: Claude Code → Cursor → Codex → pause. Record who took a chunk with `lane:*`. Under a tight budget, spend Fable runs on `tier:judgment` chunks only... a plan that is mostly mechanical (sonnet) and moderate (opus) is what makes limited credit go furthest.

## Status (2026-09-21)

`tier:*` labels and chunk rules: live in the canonical AGENTS.md block and in `/packets` (the bridge from `/ce-plan` to Linear). A `/goal` run reads the tier as advice for its delegated model choice. Tier-aware model choice inside `/goal`: not built. Parallel waves and the Cursor lane: not built (Phase 2, MCR-1412). Until then a `/goal` run builds one chunk at a time and the tier label is advisory.
