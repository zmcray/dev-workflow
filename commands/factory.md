---
name: factory
description: The night shift. With no arguments, drains everything spec-ready in this repo's Linear project overnight under a budget (stop time, chunk cap), skips anything that needs a human, and leaves a run ledger plus a morning report. Wraps the harness's goal mode (Claude Code, Codex, or Cursor); the build rules stay in AGENTS.md. Use for "/factory", "run the factory", "start the night shift", "drain the queue". NOT for a single issue (/lfg) or a named objective (/goal <objective>).
argument-hint: "(none) | --dry-run | --stop-at HH:MM | --max-chunks N"
---

# Factory

`/packets` fills the queue during the day. `/factory` drains it at night and stops before you wake up. It adds exactly three things on top of AGENTS.md > Autonomous runs: a queue read with no argument, a budget checked before every chunk, and a ledger the morning can read. Everything about how a chunk is built (chunk sweep, pull order, human parks, merge on green, session close, delegation by tier) is the existing goal-mode contract and is not restated here. If a build rule needs to change, change AGENTS.md, not this file.

Standing contract: **never ask the user anything.** Every would-be question is a one-line judgment call logged to the relevant Linear issue. The only exits are the four endings in `~/Developer/software-factory/DISPATCH.md`: queue empty, budget stop, human park (per chunk, run continues), hard stop.

**One file, three harnesses.** Source lives in `~/Developer/dev-workflow/commands/factory.md` and `deploy-skills.sh` ships it to Claude Code (`~/.claude/commands/`) to Codex (`~/.agents/skills/factory/`), and to Cursor (`~/.cursor/skills/factory/`). Everything harness-specific is in **Running on each harness** at the bottom; the steps above it are the same everywhere. Never edit a deployed copy.

## Step 1: Resolve the repo and the budget

0. **Preflight.** Before anything else, prove the run can finish without a person: a Linear tool answers (list one issue from the project), `gh auth status` passes, and a trial `git fetch` does not stop for approval. Any failure is a hard stop now, with the missing piece named in one line. A shift that stalls at 2am on an approval prompt is worse than one that never starts. Record which harness is running as `lane` (`claude`, `codex`, or `cursor`).
1. **Project.** Read `.linear-project.json` at the repo root (monorepo: the app's own file). No link file → stop and say to run `/zmcray-kickoff`. `"automerge": false` → stop; a factory run cannot leave PRs queued.
2. **Budget.** Merge, lowest to highest precedence: defaults from `~/Developer/software-factory/DISPATCH.md` > Night budget → the `factory` key in `.linear-project.json` → flags on this invocation.

```json
"factory": { "stop_at": "06:00", "max_chunks": 6, "concurrency": 1, "max_turns_per_chunk": 150 }
```

3. **Deadline math.** `stop_at` is local time, tomorrow if it is already past. `last_dispatch = stop_at - 45 min`. No chunk starts after `last_dispatch`. Nothing is ever killed mid-PR.
4. **Baseline.** Fresh default branch, CI green on `main`, working tree clean. Red baseline is a hard stop before anything is pulled.

## Step 2: Read the queue

Query the project's issues: `spec-ready`, state type not started/completed/canceled, not `gate:human`, not `ops`, no open `blocked by`. Then drop any issue labeled `design:screens`, `design:journey`, or `design:product` that has no canvas link (a Linear attachment, or a `Canvas: <url>` or `Artboard: <url>` line in the description). That is the AGENTS.md Spec gate: `spec-ready` without a canvas means someone skipped the design block, and the night never builds screens nobody drew. Order: priority (Urgent > High > Medium > Low), then wave from the parent plan's `## Chunks` table when the issue is a chunk, then oldest first.

Run the **chunk sweep** first, exactly as AGENTS.md describes it, so plans written today are cut before the queue is read.

Print the shift plan once and start. No confirmation.

```
Factory: <project>. <E> eligible, will attempt up to <max_chunks>, no new chunk after <last_dispatch>, stop by <stop_at>.
Skipped: <n> gate:human (<IDs>), <n> ops, <n> blocked, <n> no-canvas (<IDs>).
Order: <IDs in order>.
```

`--dry-run` prints this and stops. It is the only argument that changes behaviour beyond the budget.

## Step 3: Open the ledger

Write `docs/factory/runs/YYYY-MM-DD.json` in the repo (create the directory; it is committed with the morning docs PR, never with a chunk PR):

```json
{
  "run_id": "2026-09-24-pulse",
  "project": "Pulse",
  "lane": "claude",
  "started_at": "2026-09-23T23:40:00-05:00",
  "budget": { "stop_at": "06:00", "last_dispatch": "05:15", "max_chunks": 6, "concurrency": 1 },
  "eligible": ["MCR-1710", "MCR-1711"],
  "skipped": [{ "issue": "MCR-1714", "reason": "gate:human" }, { "issue": "MCR-1716", "reason": "no-canvas" }],
  "items": [],
  "stopped_at": null,
  "stop_reason": null
}
```

Every item row is written **when the chunk starts** and updated when it ends, so a dead session still leaves a readable file:

```json
{ "issue": "MCR-1710", "tier": "moderate", "model": "opus", "started_at": "...", "ended_at": "...",
  "status": "done | interrupted | parked | skipped-budget | skipped-conflict | failed",
  "pr": "https://github.com/...", "turns": 0, "retries": 0, "note": "one line" }
```

## Step 4: The shift

Arm the harness's goal mode (see **Running on each harness**) with this condition and let it drive:

> Goal: drain the factory queue for <project> under the budget in `docs/factory/runs/<date>.json`. Before starting any chunk: re-read the ledger, stop if `items` with status done reaches `max_chunks`, stop if the clock is past `last_dispatch`, re-query Linear for the next eligible issue (the board may have changed). Build each chunk per AGENTS.md > Autonomous runs. Update the ledger row at start and end of every chunk. Ending conditions are queue empty, chunk cap, deadline, or hard stop; write `stop_reason` and finish with Step 5.

The budget check happens **between chunks, never inside one**. A chunk that is running at `stop_at` finishes; it is the 45-minute margin's job to make that rare.

Per-chunk delegation follows DISPATCH.md: the builder gets the model (or reasoning setting) in the running harness's column for the chunk's `tier:*`, and `max_turns_per_chunk` as its turn cap. Two failed attempts on one chunk (one tier up on the retry) mark it `failed`, post the comment, and move on... a failed chunk is not a hard stop unless its branch broke `main`.

`concurrency` above 1 is reserved for the wave dispatcher (one worktree subagent per chunk in a wave, merges still one at a time). Until that lands, set it to 1 and the run is sequential.

## Step 5: Close the shift

1. Write `stopped_at` and `stop_reason` (`queue-empty | chunk-cap | deadline | budget | hard-stop`) to the ledger.
2. Post **one project status update** in Linear (health per the run: on track for queue-empty or chunk-cap, at risk for deadline with parks, off track for hard stop):

```
Factory <date> (<lane>): <k> merged, <p> parked for a human, <f> failed, stopped: <reason> at <time>.
Merged: MCR-… (PR), MCR-… (PR)
Human batch: MCR-… — <one-line ask>
Needs design first: MCR-… → brief docs/design/briefs/<file> (spec-ready but no canvas; write the brief per AGENTS.md > Design brief if none exists; omit the line at zero)
Failed: MCR-… — <one line>
Next: <first eligible issue left in the queue, or "queue empty: plan first">

## Morning review   build: <preview URL or main @ sha>
- [ ] MCR-… <title>: <criterion a person must look at or do>
Where to look: <tab / screen / URL>
```

3. **One consolidated morning checklist, never one per issue, and only what needs a person.** Go through every merged issue's acceptance criteria (MANUAL §7). A criterion that a merged test asserts is **dropped**: CI already verified it and the human does not see it. Keep only what CI cannot prove: UI or layout, a live-schema or prod read the builder could not run, anything the builder noted as "not run" or "not screenshotted", a taste call. Group what is left by issue under `## Morning review` in the status update above. Zero items left → write `Morning review: nothing needs your eyes.` Merged issues close to Done on merge (GitHub integration); the checklist is the review surface, and a kick back reopens the issue. Write the same list to the ledger as `"checklist": [{ "issue", "title", "criterion", "where" }]` so Pulse can render it. Per-issue merge comments keep the PR summary and judgment calls but **do not** carry a checklist block; they end with one line: `Morning review: see the Factory <date> status update.`
4. Open a `docs:` PR with the ledger file and any archived plans, merge on green. It is the last PR of the night.
5. Close with one line: **"Factory done: <k>/<E> merged, stopped on <reason>. Morning batch: <p> issues."**

## Notes

- **Do not shadow built-ins.** This command wraps goal mode; it must never be renamed to `goal`, `loop`, or `schedule` (D-022). Claude Code, Codex, and Cursor all ship a built-in with at least one of those names.
- **Anything the harness refuses to run unattended is a human gate.** A prod migration apply, a dashboard toggle, a command that returns pending approval (Claude's auto-mode classifier, a Codex sandbox escalation, a Cursor run prompt). Park it, do not wait on it. If `/packets` missed the gate, say so in the morning report so the packet rule improves.
- **iOS repos.** Set `max_chunks` lower (3) in the link file. One Mac runner builds one PR at a time, so land chunks in groups (AGENTS.md > Landing: group PRs): CI runs once per group, not per chunk. The deadline is what stops the run, not the cap.
- **Spend cap.** Not enforced interactively. When the factory moves to a headless Routine launch, pass `--max-budget-usd` and add `budget` as a stop reason.

## Running on each harness

Steps 1 to 5 do not change. Only three things do: how the shift is started, how goal mode is armed, and who builds each chunk.

| | Claude Code | Codex | Cursor |
|---|---|---|---|
| Start | `/factory` | `$factory`, or "run the factory" | `/factory`, or "run the factory" |
| Goal mode (Step 4) | built-in `/goal <condition>` | Codex goal mode if this build offers it; otherwise stay in this turn and loop Step 4 yourself, never ending the turn between chunks | built-in `/goal <condition>` (its `CreateGoal` tool) |
| Build one chunk | Compound Engineering `/lfg` in a builder subagent | Compound Engineering `lfg` skill, in the main thread (Codex runs CE subagents sequentially) | Compound Engineering `lfg` skill, in a subagent when the model supports it |
| Model per `tier:*` | DISPATCH "Claude Code" column | DISPATCH "Codex" column (reasoning effort) | DISPATCH "Cursor cloud agent" column |
| Unattended setup | auto mode | `approval_policy = "never"`, `sandbox_mode = "workspace-write"` with network on, for the repo | auto-run on for the repo, Linear MCP enabled |

- **Tool names.** Where a step names a Claude tool (`Agent`, `AskUserQuestion`, `Skill`), use the harness equivalent. On Codex the Compound Engineering tool map in `~/.codex/AGENTS.md` is the translation table. `AskUserQuestion` never applies here: the factory does not ask.
- **Linear.** Every harness needs its own Linear connection (MCP or connector). Step 1.0 checks it. Without it there is no queue, no ledger updates on issues, and no morning status update.
- **One harness per night per repo.** Two harnesses draining the same project race on `spec-ready` issues and on `main`. The ledger's `lane` says who ran; the fallback order is in DISPATCH.md.
