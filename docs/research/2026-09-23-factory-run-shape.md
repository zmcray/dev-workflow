# Research: the right shape for `/factory` (a budgeted overnight run)

Researched 2026-09-23. Method: one web pass over vendor docs and postmortems (Claude Code docs verified directly at code.claude.com; Copilot, Cursor, Devin, community watchdogs), one internal pass over software-factory rules, house commands, link files, Argus, and the Claude Code changelog. Freshness: vendor limits and flags move monthly; re-check the "native support" table before building.

Question: a skill that, with no arguments, drains everything `spec-ready` in the current repo overnight, fans chunks out by tier, and stops cleanly before morning no matter how much was queued. What should it be built on, what must it build itself, and what shape has already failed for other people?

## Pass 1: what Claude Code gives us natively (verified)

| Primitive | What it does | Use in `/factory` |
|---|---|---|
| `/goal <condition>` | keeps the session working until the condition is met; shows elapsed time, turns, tokens; self-clears on exhausted credit, lost auth, or context overflow | the engine. `/factory` sets the condition and the rules; `/goal` supplies the keep-going loop |
| `--max-budget-usd` (headless / SDK `maxBudgetUsd`) | hard dollar cap; covers subagent spend; stops background subagents at the cap (v2.1.217+) | the spend dial. Only available when launched headless, not from an interactive `/factory` |
| `--max-turns` / `maxTurns` | turn cap for headless runs and agent frontmatter | per-worker cap so one chunk cannot eat the night |
| Typed stop reasons | `success`, `error_max_turns`, `error_max_budget_usd`, `error_during_execution` | classify the ending in the ledger without guessing |
| Stop / SubagentStop hooks | can block, return context, see background tasks; 8 consecutive blocks end the turn | backstop for the wall clock: refuse to continue past the deadline even if the skill logic drifts |
| `/schedule` (Routines) | cloud cron, laptop-independent | the eventual "one line for all repos" trigger (MCR-1412). Not needed for v1 |
| `/loop`, `ScheduleWakeup` | session-bound wakeups; machine must stay awake | not suitable for an overnight trigger; fine inside a live session |
| `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` (default 200) | fan-out ceiling | irrelevant at our scale; our ceiling is CI runner slots |

Not native, so the skill must build them: a wall-clock deadline, a chunk cap, "don't start what you can't finish", cross-chunk file-scope fencing, the ending classifier, the run ledger, the morning report.

Sources: [agent loop](https://code.claude.com/docs/en/agent-sdk/agent-loop), [routines](https://code.claude.com/docs/en/routines), `~/.claude/cache/changelog.md`.

## Pass 2: what the factory already says a run must do

All from `AGENTS.md` > Autonomous runs, `DISPATCH.md`, `MANUAL.md` Stage 6/7. `/factory` inherits these unchanged:

- Chunk sweep first; pull only unblocked `spec-ready` without `gate:human` or `ops`, highest priority first; empty queue ends with "plan first".
- Execute the packet, stay inside file scope, model from `tier:*` via DISPATCH.md (haiku never writes code).
- Human gate found mid-build is a park (branch pushed, draft PR, label, one-line comment), not a stop; overlapping-scope chunks skip with it.
- Merges strictly sequential, squash on green, fresh `main` before each branch.
- Four endings already named in DISPATCH.md: queue empty, budget stop, human park, hard stop.
- Session close per issue; morning checklist block per merged issue (MANUAL §7 template, emitter not built).

Constraints found in the internal pass:

- **Do not name it after a built-in.** D-022: a personal `goal.md` shadowed the built-in `/goal` and was archived. `factory` is safe today.
- **`.linear-project.json`** exists in 12 repos with `{id, slug, name, team}`. No repo has `automerge` or any run-policy key. This is the natural home for per-repo factory settings.
- **No ledger exists.** The closest is `os.job_runs` in Argus (one row per job, overwritten, liveness only, written through a SECURITY DEFINER RPC). A factory ledger needs its own table.
- **Migrations to `mcray-os` go through the db-migrations Action ledger only**, never `db push`. The owning repo was not identified in this pass.
- **Unattended runs and the `terminal` tool:** Argus's cron work found `terminal` returns `pending_approval` in cron context and had to fall back to a file sentinel. An unattended `/factory` will hit the same class of block on anything the auto-mode classifier refuses (the `apply_migration` block on MCR-1709 is the same thing).
- **`docs/research/` in software-factory has no README/INDEX** despite AGENTS.md prescribing them. This report is filed flat, matching the existing four.

## Pass 3: prior art and failure modes

**Budgets are per unit of work, with an umbrella on top.** Every vendor caps the session or item (Copilot: 59 min hard ceiling per session, non-configurable; Claude SDK: `maxBudgetUsd` per run covering children; Devin Fusion: parent sets constraints per child). Org-wide caps are layered above, never the only control. Implication: `/factory` needs a per-chunk turn/time budget and a per-night ceiling, not one number.

**Documented failure modes and the mitigations people converged on**

| Failure | Seen where | Mitigation |
|---|---|---|
| Runaway spend overnight ($1,800 in two nights) | community cron postmortem | live cost watchdog via hooks reading the transcript, plus a hard `max_budget_usd`; never an estimate |
| Long verification step misread as a hang, agent retries, duplicates side effects | Copilot ~5 min command timeout | per-item declared timeout distinct from the global cutoff; no blind retry on an ambiguous timeout |
| Two agents edit the same file, conflict found only at merge | Cursor self-hosted machines blog | file-scope fencing at dispatch (we have this from `/packets`), rebase + resolve + squash, one merge lane |
| Single self-hosted runner saturated by parallel branches | our own motus/saidso setup | cap in-flight items to runner slots; treat runner capacity as the concurrency limit, not worker count |
| Queue finishes early, orchestrator backfills from the general backlog | multiple | explicit "queue empty" stop; never refill from non-spec-ready |
| Half-finished branches at cutoff | multiple | "don't start what you can't finish": before dispatch, require time-remaining > item budget × margin; graceful stop finishes in-flight, hard stop parks the branch pushed-but-unmerged with a ledger row |
| Budget hit fails the run instead of pausing it | LifeOS issue | treat the budget as a backstop that stops and reports, not an error |

**Config conventions.** No dominant filename. Sightings: `.agents/agent-config.json`, `AGENT.md` + `agent.toml`, a `backend` key selecting the sandbox. Policy commonly stacks three levels: global default, per-repo override, per-session override. Committed to version control so the whole team shares it.

**Queue framing that fits.** Air traffic control: fixed runways (runner slots), flights with declared duration (chunk budgets), a curfew (morning). The scheduler refuses to clear a flight it cannot land before curfew. That is the whole stop rule in one sentence.

Sources: [Copilot cloud agent](https://docs.github.com/copilot/concepts/agents/coding-agent/about-coding-agent), [Copilot timeout thread](https://github.com/orgs/community/discussions/178998), [Cursor self-hosted machines](https://cursor.com/blog/self-hosted-machines), [Devin parallel sessions](https://agentmarketcap.ai/blog/2026/04/10/devin-parallel-sessions-multi-agent-concurrency), [cron watchdog postmortem](https://dev.to/runvouch/my-claude-code-cron-ran-up-1800-in-two-nights-the-watchdog-that-stops-it-at-2-3npb), [agent queues need ATC](https://clord.dev/blog/agent-queues-need-air-traffic-control-2026/), [budget as backstop](https://github.com/nbramia/LifeOS/issues/1176).

Unverified: Factory.ai's mechanics (search returned Cognition instead); Devin Fusion's per-child stop semantics are marketing-level only.

## Pass 4: proposed shape

**Name and layer.** `/factory`, a house command in `~/.claude/commands/`, no arguments. It reads the queue, sets the budget, then hands off to the built-in `/goal` with a condition of "queue drained or budget reached" and the AGENTS.md rules. It replaces typing a `/goal` line; it does not replace `/goal`.

**Queue read.** Project from `.linear-project.json`. Pull `spec-ready`, unblocked, not `gate:human`, not `ops`, not already In Progress. Order: priority, then wave from the plan's `## Chunks` table, then age. Print the shift plan (eligible, will attempt, skipped and why, deadline) and start. No confirmation.

**Budget: three dials, checked before every dispatch**

| Dial | Default | Where it lives | Enforced by |
|---|---|---|---|
| `stop_at` (local wall clock) | `06:00` | per-repo override in `.linear-project.json` under a `factory` key; defaults in software-factory `DISPATCH.md` | skill logic before each pull, Stop hook as backstop |
| `max_chunks` per night | 6 web, 3 iOS | same | skill counter |
| `max_budget_usd` | unset until headless launch exists | same | `--max-budget-usd` when launched headless; otherwise wall clock does the job |

Plus a per-chunk budget: `max_turns` on each worker, and "don't start a chunk after `stop_at` minus 45 minutes." Never kill a session mid-PR.

**Stop paths, two of them**

- Graceful (queue empty, chunk cap, deadline reached between chunks): finish in-flight, merge on green, write ledger, report.
- Hard (budget or deadline hit mid-chunk, red baseline, unmergeable PR): park the in-flight branch pushed-but-unmerged, ledger row `interrupted`, do not partial-merge, report.

**Concurrency.** v1 sequential (today's `/goal`). v2 fan out one worktree subagent per chunk in a wave, model from tier, capped at CI runner slots (hosted: 4 to 6; single Mac runner: 2). Merges stay one lane. File-scope fencing from `/packets` is the conflict guard.

**Ledger.** New table `os.factory_runs` on `mcray-os` (run id, repo, started, stopped, stop reason, budget snapshot, chunks eligible/attempted/merged/parked/retried, spend if known) plus `os.factory_run_items` (one row per chunk: issue, tier, model, status done/interrupted/skipped-budget/skipped-gate/skipped-conflict, PR, turns, wall clock). Written incrementally, not at the end, so a crash still leaves a readable morning. Reached through a SECURITY DEFINER RPC like Argus's `argus_job_ok`, applied via the db-migrations Action ledger. Until that migration lands, a local `docs/factory/runs/YYYY-MM-DD.json` in the repo is an acceptable v1 ledger.

**Morning report.** From the ledger: one Linear project status update (merged, parked with the human ask, stopped-because, spend), the per-issue checklist blocks from MANUAL §7, and the human batch list. Argus later reads `os.factory_runs` for the cross-repo digest (MANUAL build list #8).

**Unattended blockers.** Anything the auto-mode classifier refuses (`apply_migration`, prod applies, the `terminal` tool in cron) is a human gate by definition. `/packets` should mark it at spec time; a run that hits one unplanned parks, per the existing rule.

**Not in scope for v1.** Cross-repo scheduling (MCR-1412), the Cursor and Codex lanes, spend tracking from transcripts, the Argus digest.

## Open questions for the decision

1. Interactive `/factory` in a terminal you leave open, or headless launch from a Routine? Interactive gets the skill tonight and needs the Mac awake; headless gets `--max-budget-usd` and needs the approval-classifier problem solved first.
2. Ledger v1 in-repo JSON or straight to `os.factory_runs`? JSON ships this week; the table needs the migrations pipeline owner found.
3. Chunk cap defaults: 6 web / 3 iOS is a guess. One Pulse night sets the real number.
